import 'package:intl/intl.dart';

class FormatUtil {
  static final _numFormat = NumberFormat('#,##0.00');
  static final _percentFormat = NumberFormat('+0.00;-0.00');
  static final _intFormat = NumberFormat('#,##0');

  /// 格式化金额: 1,234.56
  static String formatAmount(double value) => _numFormat.format(value);

  /// 格式化百分比: +1.23% / -1.23%
  static String formatPercent(double value) =>
      '${_percentFormat.format(value)}%';

  /// 格式化整数: 1,234
  static String formatInt(double value) => _intFormat.format(value);

  /// 格式化盈亏显示（正数带 +，负数带 -，都带货币符号）
  /// 示例：+¥1,234.56 / -¥1,234.56
  static String formatPnl(double pnl, String currencySymbol) {
    final sign = pnl >= 0 ? '+' : '-';
    return '$sign$currencySymbol${formatAmount(pnl.abs())}';
  }
}
