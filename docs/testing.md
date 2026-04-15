# 测试指南

## 本地运行

### 一次跑所有测试
```bash
flutter test        # Flutter 单元 + Widget 测试（约 78 个）
npm test            # Vercel API 函数测试（约 6 个）
```

### 跑单个文件
```bash
flutter test test/models/enums_test.dart
node --test api/fund.test.js
```

### 跑单个测试 case
```bash
flutter test --plain-name "600519 应识别为沪市"
```

### 生成覆盖率报告
```bash
flutter test --coverage
# 结果在 coverage/lcov.info
# 可用 lcov 工具查看：
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## 测试层级

| 层级 | 位置 | 内容 |
|------|------|------|
| **单元测试** | `test/models/`, `test/core/` | 纯逻辑：枚举、汇率、盈亏计算、格式化 |
| **Service 测试** | `test/data/` | 行情解析（mocktail mock Dio）|
| **Widget 测试** | `test/widgets/` | UI 组件渲染、交互 |
| **API 测试** | `api/*.test.js` | Vercel serverless 函数 |

## 关键测试 case 索引

### 股票行情
- `test/data/stock_price_service_test.dart`
  - 东方财富 A 股价格精度 (precision=2)
  - 港股精度 1 位小数（489.2 不是 4892）
  - 沪深冲突代码 fallback（000071）
  - Android 上 Content-Type=text/plain 的 JSON 解析
  - 天天基金 JSONP 解析
  - 批量查询单只失败不影响其他
  - 网络失败优雅降级

### 市场推断
- `test/models/enums_test.dart`
  - 600xxx → 沪市
  - 0xxxxx / 3xxxxx → 深市
  - 5 位数字 → 港股
  - 字母 → 美股

### 盈亏计算
- `test/models/portfolio_summary_test.dart`
  - 基础盈亏、盈亏百分比
  - USD/HKD → CNY 换算
  - 今日盈亏（cur - prev）
  - 货币符号映射
  - 空状态

## CI

每次 push 到 main 或提 PR 时，GitHub Actions 自动执行：

`.github/workflows/test.yml`:
- **flutter-tests**: `flutter analyze` + `flutter test --coverage`
- **api-tests**: `node --test api/*.test.js`

两个 job 全绿才允许合并。

## 添加新测试时

1. **纯逻辑** → `test/models/` 或 `test/core/`
2. **依赖网络/DB 的 Service** → `test/data/`，用 `mocktail` mock
3. **UI 组件** → `test/widgets/`，用 `testWidgets`
4. **Vercel API** → `api/xxx.test.js`，用 Node.js 自带 `node:test`

## 暂不覆盖（后续可加）

- **E2E 测试**：需要测试 Supabase 实例 + 测试账号，先跳过
- **集成测试**：涉及 Supabase 真实调用，成本较高
- **Riverpod provider 集成测试**：依赖多个 mock，先保持单元测试覆盖关键逻辑
