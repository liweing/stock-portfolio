// Vercel Cron Function: 每日收盘后自动快照所有用户持仓
// 触发时间: 16:30 北京时间（08:30 UTC），仅工作日
// 流程: 读所有用户持仓 → 批量拉收盘价 → 计算市值/盈亏 → 写入快照

const { createClient } = require('@supabase/supabase-js');

// 汇率（和 Flutter 端保持一致）
const EXCHANGE_RATES = { USD: 7.20, HKD: 0.92, CNY: 1.0 };

// 东财 secid 前缀映射
const MARKET_PREFIXES = {
  sh: ['1'],
  sz: ['0'],
  hk: ['116'],
  us: ['105'],
  futures: ['115', '113', '114', '8', '142'],
};

module.exports = async function handler(req, res) {
  // 安全校验：只允许 Vercel Cron 或带正确 secret 的请求
  const authHeader = req.headers['authorization'];
  const cronSecret = process.env.CRON_SECRET;
  if (cronSecret && authHeader !== `Bearer ${cronSecret}`) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseKey = process.env.SUPABASE_SERVICE_KEY;
  if (!supabaseUrl || !supabaseKey) {
    res.status(500).json({ error: 'Missing SUPABASE_URL or SUPABASE_SERVICE_KEY' });
    return;
  }

  const supabase = createClient(supabaseUrl, supabaseKey);

  try {
    // 1. 读取所有持仓（service_role 绕过 RLS）
    const { data: positions, error: posErr } = await supabase
      .from('positions')
      .select('user_id, symbol, market, quantity, avg_cost, currency, direction');

    if (posErr) throw posErr;
    if (!positions || positions.length === 0) {
      res.status(200).json({ message: 'No positions found', snapshots: 0 });
      return;
    }

    // 2. 收集所有不重复的 symbol+market（批量拉价格）
    const uniqueStocks = new Map();
    for (const p of positions) {
      const key = `${p.market}:${p.symbol}`;
      if (!uniqueStocks.has(key)) {
        uniqueStocks.set(key, { symbol: p.symbol, market: p.market });
      }
    }

    // 3. 批量拉取价格
    const priceMap = {};
    const stockList = Array.from(uniqueStocks.values());

    // 分成 stock/index 类 和 fund 类
    const fundSymbols = stockList.filter(s => s.market === 'fund');
    const nonFundSymbols = stockList.filter(s => s.market !== 'fund');

    // 3a. 东财 API 拉股票/期货价格
    for (const stock of nonFundSymbols) {
      const price = await fetchEastMoneyPrice(stock.symbol, stock.market);
      if (price) {
        priceMap[`${stock.market}:${stock.symbol}`] = price;
      }
    }

    // 3b. 天天基金 API 拉基金净值
    for (const fund of fundSymbols) {
      const price = await fetchFundPrice(fund.symbol);
      if (price) {
        priceMap[`fund:${fund.symbol}`] = price;
      }
    }

    // 4. 按用户分组计算
    const userMap = new Map();
    for (const p of positions) {
      if (!userMap.has(p.user_id)) {
        userMap.set(p.user_id, []);
      }
      userMap.get(p.user_id).push(p);
    }

    const today = new Date().toISOString().substring(0, 10);
    const snapshots = [];

    for (const [userId, userPositions] of userMap) {
      let totalMarketValue = 0;
      let totalCost = 0;
      let dailyPnl = 0;
      let positionCount = userPositions.length;

      for (const p of userPositions) {
        const key = `${p.market}:${p.symbol}`;
        const price = priceMap[key];
        const currentPrice = price?.currentPrice ?? p.avg_cost;
        const prevClose = price?.prevClose ?? currentPrice;
        const rate = EXCHANGE_RATES[p.currency] ?? 1.0;
        const directionMultiplier = p.direction === 'short' ? -1 : 1;

        const marketValueCny = currentPrice * p.quantity * rate;
        const costValueCny = p.avg_cost * p.quantity * rate;
        const dailyPnlCny = (currentPrice - prevClose) * p.quantity * directionMultiplier * rate;

        totalMarketValue += marketValueCny;
        totalCost += costValueCny;
        dailyPnl += dailyPnlCny;
      }

      const totalPnl = totalMarketValue - totalCost;

      snapshots.push({
        user_id: userId,
        snapshot_date: today,
        total_market_value: Math.round(totalMarketValue * 100) / 100,
        total_cost: Math.round(totalCost * 100) / 100,
        total_pnl: Math.round(totalPnl * 100) / 100,
        daily_pnl: Math.round(dailyPnl * 100) / 100,
        position_count: positionCount,
      });
    }

    // 5. 批量写入（upsert）
    if (snapshots.length > 0) {
      const { error: upsertErr } = await supabase
        .from('portfolio_snapshots')
        .upsert(snapshots, { onConflict: 'user_id,snapshot_date' });

      if (upsertErr) throw upsertErr;
    }

    res.status(200).json({
      message: 'Snapshots saved',
      date: today,
      users: snapshots.length,
      pricesFetched: Object.keys(priceMap).length,
    });
  } catch (err) {
    console.error('daily-snapshot error:', err);
    res.status(500).json({ error: err.message });
  }
};

// ========== 价格拉取工具函数 ==========

async function fetchEastMoneyPrice(symbol, market) {
  const prefixes = MARKET_PREFIXES[market];
  if (!prefixes) return null;

  for (const prefix of prefixes) {
    try {
      const secid = `${prefix}.${symbol}`;
      const url = `https://push2delay.eastmoney.com/api/qt/stock/get?secid=${secid}&fields=f43,f60,f59,f170&ut=fa5fd1943c7b386f172d6893dbbd1d0c`;

      const resp = await fetch(url);
      const json = await resp.json();
      if (!json.data || json.data.f43 == null || json.data.f43 === '-') continue;

      const precision = json.data.f59 ?? 2;
      const factor = Math.pow(10, precision);

      return {
        currentPrice: json.data.f43 / factor,
        prevClose: (json.data.f60 ?? json.data.f43) / factor,
      };
    } catch {
      continue;
    }
  }
  return null;
}

async function fetchFundPrice(symbol) {
  try {
    const url = `https://fundgz.1234567.com.cn/js/${symbol}.js?rt=${Date.now()}`;
    const resp = await fetch(url, {
      headers: { 'User-Agent': 'Mozilla/5.0', Referer: 'https://fund.eastmoney.com/' },
    });
    const text = await resp.text();
    const match = text.match(/jsonpgz\((.*)\)/);
    if (!match) return null;

    const data = JSON.parse(match[1]);
    const gsz = parseFloat(data.gsz) || 0;
    const dwjz = parseFloat(data.dwjz) || 0;

    return {
      currentPrice: gsz > 0 ? gsz : dwjz,
      prevClose: dwjz,
    };
  } catch {
    return null;
  }
}
