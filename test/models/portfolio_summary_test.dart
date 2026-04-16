import 'package:flutter_test/flutter_test.dart';
import 'package:stock_portfolio/models/enums.dart';
import 'package:stock_portfolio/models/portfolio_summary.dart';

PositionPnl _p({
  double cost = 100,
  double price = 100,
  double qty = 100,
  double prev = 100,
  StockMarket market = StockMarket.sh,
  String currency = 'CNY',
  PositionDirection direction = PositionDirection.long,
}) =>
    PositionPnl(
      positionId: 1,
      symbol: 'X',
      name: 'Test',
      market: market,
      platform: BrokerageType.futu,
      quantity: qty,
      avgCost: cost,
      currentPrice: price,
      prevClose: prev,
      currency: currency,
      direction: direction,
    );

void main() {
  group('ExchangeRate 转换', () {
    test('USD → CNY 按 7.20 换算', () {
      expect(ExchangeRate.toCny(100, 'USD'), closeTo(720, 0.001));
    });

    test('HKD → CNY 按 0.92 换算', () {
      expect(ExchangeRate.toCny(100, 'HKD'), closeTo(92, 0.001));
    });

    test('CNY 不变', () {
      expect(ExchangeRate.toCny(100, 'CNY'), 100);
    });

    test('未知货币按 CNY 处理', () {
      expect(ExchangeRate.toCny(100, 'JPY'), 100);
      expect(ExchangeRate.toCny(100, ''), 100);
    });

    test('0 金额返回 0', () {
      expect(ExchangeRate.toCny(0, 'USD'), 0);
    });
  });

  group('PositionPnl 基础盈亏', () {
    test('盈利：cost=100, price=120, qty=100 → pnl=2000', () {
      final p = _p(cost: 100, price: 120, qty: 100);
      expect(p.costValue, 10000);
      expect(p.marketValue, 12000);
      expect(p.pnl, 2000);
      expect(p.isProfit, isTrue);
    });

    test('亏损：cost=100, price=80, qty=100 → pnl=-2000', () {
      final p = _p(cost: 100, price: 80, qty: 100);
      expect(p.pnl, -2000);
      expect(p.isProfit, isFalse);
    });

    test('持平：cost=price → pnl=0 (isProfit 为 true)', () {
      final p = _p(cost: 100, price: 100, qty: 100);
      expect(p.pnl, 0);
      expect(p.isProfit, isTrue);
    });

    test('盈亏百分比计算', () {
      expect(_p(cost: 100, price: 120, qty: 100).pnlPercent, closeTo(20, 0.001));
      expect(_p(cost: 100, price: 80, qty: 100).pnlPercent, closeTo(-20, 0.001));
    });

    test('成本为 0 时 pnlPercent 返回 0（不抛异常）', () {
      final p = _p(cost: 0, price: 100, qty: 100);
      expect(p.pnlPercent, 0);
    });
  });

  group('PositionPnl 人民币换算', () {
    test('美股持仓: USD 1000 市值 ≈ 7200 CNY 市值', () {
      final p = _p(
        cost: 10, price: 10, qty: 100,
        market: StockMarket.us, currency: 'USD',
      );
      expect(p.marketValue, 1000);
      expect(p.marketValueCny, closeTo(7200, 0.001));
    });

    test('港股持仓: HKD 1000 ≈ 920 CNY', () {
      final p = _p(
        cost: 10, price: 10, qty: 100,
        market: StockMarket.hk, currency: 'HKD',
      );
      expect(p.marketValueCny, closeTo(920, 0.001));
    });

    test('A 股持仓 CNY 不换算', () {
      final p = _p(cost: 10, price: 10, qty: 100, currency: 'CNY');
      expect(p.marketValueCny, 1000);
    });

    test('pnlCny = marketValueCny - costValueCny', () {
      // 美股 cost=10, price=12, qty=100 → pnl=200 USD → 1440 CNY
      final p = _p(
        cost: 10, price: 12, qty: 100,
        market: StockMarket.us, currency: 'USD',
      );
      expect(p.pnlCny, closeTo(1440, 0.001));
    });
  });

  group('PositionPnl 今日盈亏', () {
    test('上涨: (price - prev) * qty', () {
      // 昨收 100, 现价 105, 持仓 100 股 → 今日 +500
      final p = _p(cost: 90, price: 105, qty: 100, prev: 100);
      expect(p.dailyPnl, 500);
      expect(p.isDailyUp, isTrue);
      expect(p.dailyChangePercent, closeTo(5, 0.001));
    });

    test('下跌: 负值', () {
      final p = _p(cost: 90, price: 95, qty: 100, prev: 100);
      expect(p.dailyPnl, -500);
      expect(p.isDailyUp, isFalse);
      expect(p.dailyChangePercent, closeTo(-5, 0.001));
    });

    test('prevClose=0 时返回 0（避免除零）', () {
      final p = _p(cost: 90, price: 95, qty: 100, prev: 0);
      expect(p.dailyPnl, 0);
      expect(p.dailyChangePercent, 0);
    });

    test('今日盈亏 CNY 换算', () {
      // 美股昨收 10, 现价 12, 持仓 100 → 今日 +200 USD ≈ +1440 CNY
      final p = _p(
        cost: 9, price: 12, qty: 100, prev: 10,
        market: StockMarket.us, currency: 'USD',
      );
      expect(p.dailyPnlCny, closeTo(1440, 0.001));
    });
  });

  group('PositionPnl 货币符号', () {
    test('沪市 = ¥', () => expect(_p().currencySymbol, '¥'));
    test('美股 = \$', () {
      expect(
        _p(market: StockMarket.us).currencySymbol,
        '\$',
      );
    });
    test('港股 = HK\$', () {
      expect(
        _p(market: StockMarket.hk).currencySymbol,
        'HK\$',
      );
    });
    test('基金 = ¥', () {
      expect(
        _p(market: StockMarket.fund).currencySymbol,
        '¥',
      );
    });
  });

  group('做空盈亏', () {
    test('做空且价格下跌 → 盈利', () {
      // 开仓 800（做空）, 现价 750, 量 10手 → 赚 (800-750)*10 = 500
      final p = _p(
        cost: 800, price: 750, qty: 10, prev: 760,
        market: StockMarket.futures,
        direction: PositionDirection.short,
      );
      expect(p.pnl, 500);
      expect(p.isProfit, isTrue);
      expect(p.isShort, isTrue);
    });

    test('做空且价格上涨 → 亏损', () {
      final p = _p(
        cost: 800, price: 850, qty: 10, prev: 840,
        market: StockMarket.futures,
        direction: PositionDirection.short,
      );
      expect(p.pnl, -500);
      expect(p.isProfit, isFalse);
    });

    test('做空今日盈亏 = (昨收 - 现价) × 数量', () {
      // 昨收 760, 现价 750（跌了），做空赚 100
      final p = _p(
        cost: 800, price: 750, qty: 10, prev: 760,
        market: StockMarket.futures,
        direction: PositionDirection.short,
      );
      expect(p.dailyPnl, 100);
      expect(p.isDailyUp, isTrue);
    });

    test('做空今日涨跌幅按方向反转', () {
      // 价格涨了 1.32%（750→760），做空亏 1.32%
      final p = _p(
        cost: 800, price: 760, qty: 10, prev: 750,
        market: StockMarket.futures,
        direction: PositionDirection.short,
      );
      expect(p.dailyChangePercent, closeTo(-1.333, 0.01));
    });

    test('做空成本 = 名义市值（同做多公式）', () {
      final p = _p(
        cost: 800, price: 850, qty: 10,
        direction: PositionDirection.short,
      );
      expect(p.costValue, 8000);
      expect(p.marketValue, 8500); // 名义价值（不是真实持仓）
    });

    test('做空收益率', () {
      // 开仓 800, 现价 720（跌 10%）, 做空盈利 10%
      final p = _p(
        cost: 800, price: 720, qty: 10,
        direction: PositionDirection.short,
      );
      expect(p.pnlPercent, closeTo(10, 0.001));
    });
  });

  group('PortfolioSummary.empty', () {
    test('所有字段归零', () {
      final s = PortfolioSummary.empty();
      expect(s.totalMarketValue, 0);
      expect(s.totalCost, 0);
      expect(s.totalPnl, 0);
      expect(s.dailyPnl, 0);
      expect(s.isEmpty, isTrue);
      expect(s.allocationByStock, isEmpty);
      expect(s.allocationByPlatform, isEmpty);
    });
  });
}
