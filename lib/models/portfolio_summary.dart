import 'enums.dart';

/// 汇率转换（相对人民币）
/// 后续可接入实时汇率 API，现在先使用固定值
class ExchangeRate {
  static const double usdToCny = 7.20;
  static const double hkdToCny = 0.92;
  static const double cnyToCny = 1.0;

  /// 将指定货币金额转为人民币
  static double toCny(double amount, String currency) {
    switch (currency) {
      case 'USD':
        return amount * usdToCny;
      case 'HKD':
        return amount * hkdToCny;
      case 'CNY':
      default:
        return amount;
    }
  }
}

/// 单个持仓的盈亏详情
class PositionPnl {
  final int positionId;
  final String symbol;
  final String name;
  final StockMarket market;
  final BrokerageType platform;
  final double quantity;
  final double avgCost;
  final double currentPrice;
  final double prevClose;
  final String currency;
  final PositionDirection direction;

  PositionPnl({
    required this.positionId,
    required this.symbol,
    required this.name,
    required this.market,
    required this.platform,
    required this.quantity,
    required this.avgCost,
    required this.currentPrice,
    required this.prevClose,
    required this.currency,
    this.direction = PositionDirection.long,
  });

  /// 方向系数：做多 +1，做空 -1
  double get _directionMultiplier => direction.isLong ? 1.0 : -1.0;

  /// 今日盈亏 = (当前价 - 昨收) × 数量 × 方向
  double get dailyPnl => prevClose > 0
      ? (currentPrice - prevClose) * quantity * _directionMultiplier
      : 0;

  /// 我的今日涨跌幅（按方向，做空时反转）
  double get dailyChangePercent => prevClose > 0
      ? ((currentPrice - prevClose) / prevClose) * 100 * _directionMultiplier
      : 0;

  /// 今日盈亏（人民币）
  double get dailyPnlCny => ExchangeRate.toCny(dailyPnl, currency);

  /// 今日是否上涨（赚钱）
  bool get isDailyUp => dailyPnl >= 0;

  /// 成本金额（开仓占用资金，永远正数）
  double get costValue => quantity * avgCost;

  /// 市值（名义价值，按现价计算，永远正数；做空时也算正"名义"）
  double get marketValue => quantity * currentPrice;

  /// 累计盈亏（考虑方向）
  /// 做多: (现价 - 成本) × 数量
  /// 做空: (成本 - 现价) × 数量
  double get pnl =>
      (currentPrice - avgCost) * quantity * _directionMultiplier;

  /// 盈亏百分比（按成本算）
  double get pnlPercent => costValue == 0 ? 0 : (pnl / costValue) * 100;

  /// 是否盈利
  bool get isProfit => pnl >= 0;

  /// 是否是做空持仓
  bool get isShort => direction.isShort;

  /// 基金的当前价是估算净值（gsz ≠ dwjz）
  bool get isEstimated =>
      market.isFund && (currentPrice - prevClose).abs() > 0.00001;

  /// 货币符号（如 $, HK$, ¥）
  String get currencySymbol => market.currencySymbol;

  /// 市值（人民币）
  double get marketValueCny => ExchangeRate.toCny(marketValue, currency);

  /// 成本（人民币）
  double get costValueCny => ExchangeRate.toCny(costValue, currency);

  /// 盈亏（人民币）
  double get pnlCny => marketValueCny - costValueCny;
}

/// 单个平台的盈亏统计（全部以人民币计）
class PlatformStat {
  final BrokerageType platform;
  final double marketValue;   // 总市值
  final double cost;          // 总成本
  final double totalPnl;      // 累计盈亏
  final double totalPnlPercent; // 累计收益率 %
  final double dailyPnl;      // 今日盈亏

  PlatformStat({
    required this.platform,
    required this.marketValue,
    required this.cost,
    required this.totalPnl,
    required this.totalPnlPercent,
    required this.dailyPnl,
  });

  bool get isProfit => totalPnl >= 0;
  bool get isDailyUp => dailyPnl >= 0;
}

/// 饼图分配项
class AllocationItem {
  final String label;
  final double value;
  final double percentage;

  AllocationItem({
    required this.label,
    required this.value,
    required this.percentage,
  });
}

/// 整体投资组合汇总
class PortfolioSummary {
  final double totalMarketValue;
  final double totalCost;
  final double totalPnl;
  final double totalPnlPercent;
  final double dailyPnl;
  final double dailyPnlPercent;
  final List<AllocationItem> allocationByStock;
  final List<AllocationItem> allocationByPlatform;
  final List<PlatformStat> platformStats;
  final List<PositionPnl> positionDetails;

  PortfolioSummary({
    required this.totalMarketValue,
    required this.totalCost,
    required this.totalPnl,
    required this.totalPnlPercent,
    required this.dailyPnl,
    required this.dailyPnlPercent,
    required this.allocationByStock,
    required this.allocationByPlatform,
    required this.platformStats,
    required this.positionDetails,
  });

  factory PortfolioSummary.empty() => PortfolioSummary(
        totalMarketValue: 0,
        totalCost: 0,
        totalPnl: 0,
        totalPnlPercent: 0,
        dailyPnl: 0,
        dailyPnlPercent: 0,
        allocationByStock: [],
        allocationByPlatform: [],
        platformStats: [],
        positionDetails: [],
      );

  bool get isEmpty => positionDetails.isEmpty;
}
