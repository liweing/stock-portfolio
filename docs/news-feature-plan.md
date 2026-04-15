# 持仓新闻 Feature 设计方案（待实现）

> 状态：**已讨论，暂缓实施**
> 最后讨论：2026-04-15

## 目标
给 App 加一个"新闻" Tab，聚合多源财经新闻，基于用户持仓做个性化推荐，实时性要求较高（15 分钟内新闻）。

---

## 整体架构

```
┌──────────────────────────────────────────┐
│  定时任务 (Cron, 每 15 分钟)              │
└─────────────┬────────────────────────────┘
              ▼
┌──────────────────────────────────────────┐
│  抓取器 (Scraper)                         │
│  - 东方财富  - 新浪财经  - 财联社        │
│  - 华尔街见闻  - 雪球  - Yahoo Finance   │
└─────────────┬────────────────────────────┘
              ▼
┌──────────────────────────────────────────┐
│  聚合器 (Aggregator)                      │
│  - 去重  - 格式统一  - 股票 tag 提取      │
│  - 情感分析 (可选)                        │
└─────────────┬────────────────────────────┘
              ▼
┌──────────────────────────────────────────┐
│  Supabase Postgres (news / news_stocks)   │
└─────────────┬────────────────────────────┘
              ▼
┌──────────────────────────────────────────┐
│  Feed API (云端排序逻辑)                  │
│  get-news-feed(userId) → 排序后的新闻列表 │
└─────────────┬────────────────────────────┘
              ▼
┌──────────────────────────────────────────┐
│  Flutter App (新增"新闻" Tab)             │
└──────────────────────────────────────────┘
```

---

## 数据库设计

```sql
-- 新闻表
CREATE TABLE news (
  id BIGSERIAL PRIMARY KEY,
  source TEXT NOT NULL,              -- 'eastmoney', 'xueqiu', 'cls', ...
  source_id TEXT NOT NULL,           -- 源站原始 ID
  title TEXT NOT NULL,
  summary TEXT,
  url TEXT NOT NULL,
  image_url TEXT,
  published_at TIMESTAMPTZ NOT NULL,
  fetched_at TIMESTAMPTZ DEFAULT NOW(),
  content_hash TEXT,                 -- 去重用：title 规范化 hash
  category TEXT,                     -- 'stock' | 'market' | 'macro' | 'policy'
  sentiment TEXT,                    -- 可选：'positive' | 'negative' | 'neutral'
  view_count INT DEFAULT 0,
  tags TEXT[],
  UNIQUE(source, source_id)
);

-- 新闻-股票关联（多对多）
CREATE TABLE news_stocks (
  news_id BIGINT REFERENCES news(id) ON DELETE CASCADE,
  stock_symbol TEXT NOT NULL,
  market TEXT NOT NULL,
  PRIMARY KEY (news_id, stock_symbol, market)
);

-- 已读状态（Phase 2）
CREATE TABLE news_read_status (
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  news_id BIGINT REFERENCES news(id) ON DELETE CASCADE,
  read_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, news_id)
);

-- 源权重配置
CREATE TABLE news_source_config (
  source TEXT PRIMARY KEY,
  display_name TEXT,
  weight NUMERIC DEFAULT 1.0,
  enabled BOOLEAN DEFAULT TRUE
);

CREATE INDEX idx_news_published ON news(published_at DESC);
CREATE INDEX idx_news_stocks_symbol ON news_stocks(stock_symbol, market);
CREATE INDEX idx_news_content_hash ON news(content_hash);
```

---

## 抓取源

### 全局财经快讯
| 源 | 说明 |
|----|------|
| 财联社电报 (cls.cn) | 最及时的快讯流 |
| 华尔街见闻 | 深度文章 |
| 新浪财经 RSS | 通用资讯 |
| Yahoo Finance RSS | 美股为主 |

### 个股新闻
- 东方财富个股新闻 API（自带股票 tag）
- 雪球股票动态
- 新浪个股公告

### 智能节流
按持仓覆盖度调整频率：
- 被多用户持有的热门股 → 每 5 分钟
- 冷门股 → 每 1 小时

---

## 去重三层

1. **源内去重**：`UNIQUE(source, source_id)` 约束
2. **跨源去重**：标题归一化（去空格/标点/小写）→ MD5 hash，8 小时窗口内同 hash 只保留最早一条
3. **语义去重（可选）**：embedding + cosine，相似度 > 0.85 视为同一条

---

## 股票 tag 打标

| 方法 | 说明 | 准确性 |
|------|------|--------|
| A. 源自带 tag | 东方财富/雪球自带股票关联 | ⭐⭐⭐⭐⭐ |
| B. 关键词匹配 | 维护 `stock_aliases` 表，标题扫描 | ⭐⭐⭐⭐ |
| C. LLM 打 tag | 喂给 AI 读 + 输出涉及股票 | ⭐⭐⭐⭐⭐ 但贵 |

**MVP 用 A + B 即可。**

---

## Feed API 排序（在云端实现！）

### 位置：Supabase Edge Function（TypeScript）

**不在 SQL 里**（复杂评分难维护），**不在客户端**（算法调整要发版）。

### 评分公式
```
score = 0.4 × relevance          // 相关性（按持仓权重）
      + 0.3 × freshness          // 新鲜度（时间衰减）
      + 0.2 × importance         // 源权威性 + 标题信号词
      + 0.1 × popularity         // 全站浏览量
      - 0.5 × (isRead ? 1 : 0)   // 已读降权
```

### 相关性计算（按仓位加权）
```typescript
// 每支股占用户总市值的比例
const weights = positions.reduce((w, p) => {
  w[`${p.market}:${p.symbol}`] = p.value / totalValue;
  return w;
}, {});

// 新闻的相关性 = 涉及股票的权重之和
relevance = news.stocks.reduce(
  (s, sym) => s + (weights[sym] ?? 0), 0
);
```

### 新鲜度
```typescript
freshness = Math.exp(-hoursSincePublished / 12);
// 12h 半衰期：发布 12h 后分数减半
```

---

## Edge Function 伪代码

```typescript
// supabase/functions/get-news-feed/index.ts
Deno.serve(async (req) => {
  const { userId } = await getUserFromJWT(req);

  // 1. 读用户持仓（带权重）
  const positions = await db.query(`
    SELECT symbol, market, quantity * avg_cost as value
    FROM positions WHERE user_id = $1
  `, [userId]);

  const totalValue = positions.reduce((s, p) => s + p.value, 0);
  const weights = Object.fromEntries(
    positions.map(p => [`${p.market}:${p.symbol}`, p.value / totalValue])
  );

  // 2. 候选池：近 48h 新闻
  const candidates = await db.query(`
    SELECT n.*, array_agg(ns.stock_symbol) as stocks
    FROM news n LEFT JOIN news_stocks ns ON ns.news_id = n.id
    WHERE n.published_at > NOW() - INTERVAL '48 hours'
    GROUP BY n.id
    LIMIT 500
  `);

  // 3. 排序算法
  const scored = candidates.map(news => {
    const relevance = news.stocks.reduce((s, sym) => s + (weights[sym] ?? 0), 0);
    const ageHours = (Date.now() - new Date(news.published_at)) / 3_600_000;
    const freshness = Math.exp(-ageHours / 12);
    const importance = SOURCE_WEIGHTS[news.source] ?? 1.0;
    const score = 0.4*relevance + 0.3*freshness + 0.2*importance;
    return { ...news, score };
  });

  scored.sort((a, b) => b.score - a.score);

  // 4. 返回前 30 条
  return Response.json({ items: scored.slice(0, 30) });
});
```

---

## 缓存策略

两层：
- **L1 用户 Feed 缓存**：key=`feed:{userId}`，TTL 5 分钟，存已排序的 news_id 列表
- **L2 候选池物化视图**：Postgres materialized view，每 5 分钟刷新

**失效条件**：
- TTL 过期
- 用户持仓变动
- 有新新闻入库

免费版 Supabase 没 Redis，可用 Postgres 表 `user_feed_cache` 模拟 L1。

---

## 云端部署选项对比

| 方案 | 定时 | 抓取 | 国内访问 | 免费额度 | 推荐度 |
|------|------|------|---------|---------|--------|
| **Supabase Edge Function + pg_cron** | ✅ | ✅ | 中（取决 Region） | 500k 调用/月 | ⭐⭐⭐⭐⭐ |
| Vercel Cron + Functions | ✅ | ✅ | 中（全球 CDN） | 100 GB-h/月 | ⭐⭐⭐⭐ |
| Cloudflare Workers + Cron Triggers | ✅ | ✅ | 国内 CDN 快 | 100k 请求/天 | ⭐⭐⭐⭐ |
| GitHub Actions schedule | ✅ 最小 5 分钟 | ✅ | 海外 | 2000 分钟/月 | ⭐⭐⭐ |
| 阿里云函数计算 / 腾讯云 SCF | ✅ | ✅ | **国内最快** | 100 万次/月 | ⭐⭐⭐⭐ |

**推荐**：**Supabase Edge Function + pg_cron**，一体化，和已有架构无缝衔接。

### ⚠️ Supabase Region 注意
- 当前项目若为 **US** Region，抓取国内源可能延迟/不稳定
- 建议 **Singapore 或 Tokyo**
- 已创建项目 Region 不可改，需新建迁移
- 降级方案：抓取放国内云（腾讯 SCF），Feed API 保留 Supabase

---

## UI 设计

### 底部导航新增第 3 个 Tab：新闻
```
持仓 | 分析 | 新闻
```

### 新闻 Tab 内容
- 顶部：下拉刷新
- 列表项：标题 / 来源 + 时间 / 相关股票 tag（可点进该股详情）
- 点击整条 → App 内 WebView 展示原文
- 右滑标记已读 / 左滑不感兴趣

### 个股详情页新增"相关新闻"栏
点持仓列表某支股 → 详情页 → 该股相关新闻列表

---

## 渐进式实施计划

### Phase 1（MVP，1-2 天）
- [ ] Supabase 建 news + news_stocks 表
- [ ] 写 1 个抓取 Edge Function（先抓 东方财富 + 财联社）
- [ ] pg_cron 每 15 分钟触发
- [ ] Feed API（SQL `ORDER BY published_at DESC`，暂不做评分）
- [ ] Flutter 加"新闻" Tab（列表 + 外链跳转）

### Phase 2（智能排序，3-5 天）
- [ ] Edge Function 评分算法
- [ ] 已读状态
- [ ] L1 缓存（Postgres 表）
- [ ] 相关股票 tag 展示

### Phase 3（体验增强，可选）
- [ ] WebView 内嵌阅读
- [ ] AI 摘要（"今日你持仓要闻"）
- [ ] 情感分析标签（利好/利空）
- [ ] 推送通知（APK 原生 / Web PWA）

---

## 潜在坑点

1. **反爬**：财联社、雪球高频会封 IP。对策：UA 池、降频、多源冗余
2. **地理限制**：US Supabase 访问国内源有概率失败
3. **法律合规**：只存标题 + 摘要 + 链接，不存全文
4. **数据增长**：news 表会很快到几十万行。对策：定期清理保留 30 天
5. **Edge Function 超时**：单次 400s 上限，多源要分批/并发控制
6. **去重质量**：多源容易漏去重，会看到重复新闻

---

## 客户端改动预览

```dart
// 新增 Repository
class NewsRepository {
  Future<NewsFeed> getFeed({String? cursor}) async {
    final res = await supabase.functions.invoke(
      'get-news-feed',
      body: {'cursor': cursor, 'limit': 30},
    );
    return NewsFeed.fromJson(res.data);
  }

  Future<void> markAsRead(int newsId) async {
    await supabase.functions.invoke(
      'news-read',
      body: {'newsId': newsId},
    );
  }
}

// 新增 Screen
class NewsFeedScreen extends ConsumerWidget { ... }
```

---

## 决策未定项（实施前确认）

1. 排序权重配比（相关性 vs 重要性）
2. 已读状态是否 Phase 1 就做
3. 冷启动用户（无持仓）看什么
4. 云端部署位置（建议 Supabase，但要看 Region）
5. Phase 3 是否接 LLM 做摘要（月成本几十）

---

## 相关上下文

- 已决定：**新闻源由云端聚合**（不做客户端直接抓取）
- 已决定：**查询策略在云端实现**（Edge Function，非 SQL 非客户端）
- 项目位置：`/Users/bytedance/cc/stock_portfolio/`
- Supabase 项目：`zbxpmrvwybqqwbruskqr`
- Vercel 部署：https://stock-portfolio-topaz.vercel.app/
