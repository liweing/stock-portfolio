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
  });

  /// 今日盈亏 = (当前价 - 昨收) × 数量
  double get dailyPnl =>
      prevClose > 0 ? (currentPrice - prevClose) * quantity : 0;

  /// 今日涨跌幅
  double get dailyChangePercent =>
      prevClose > 0 ? ((currentPrice - prevClose) / prevClose) * 100 : 0;

  /// 今日盈亏（人民币）
  double get dailyPnlCny => ExchangeRate.toCny(dailyPnl, currency);

  /// 今日是否上涨
  bool get isDailyUp => dailyPnl >= 0;

  /// 成本金额
  double get costValue => quantity * avgCost;

  /// 市值
  double get marketValue => quantity * currentPrice;

  /// 盈亏金额
  double get pnl => marketValue - costValue;

  /// 盈亏百分比
  double get pnlPercent => costValue == 0 ? 0 : (pnl / costValue) * 100;

  /// 是否盈利
  bool get isProfit => pnl >= 0;

  /// 货币符号（如 $, HK$, ¥）
  String get currencySymbol => market.currencySymbol;

  /// 市值（人民币）
  double get marketValueCny => ExchangeRate.toCny(marketValue, currency);

  /// 成本（人民币）
  double get costValueCny => ExchangeRate.toCny(costValue, currency);

  /// 盈亏（人民币）
  double get pnlCny => marketValueCny - costValueCny;
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
        positionDetails: [],
      );

  bool get isEmpty => positionDetails.isEmpty;
}
