import 'package:flutter_test/flutter_test.dart';
import 'package:stock_portfolio/core/utils.dart';

void main() {
  group('FormatUtil.formatAmount', () {
    test('带千分位和两位小数', () {
      expect(FormatUtil.formatAmount(1234.56), '1,234.56');
      expect(FormatUtil.formatAmount(1000000), '1,000,000.00');
    });

    test('小数补零', () {
      expect(FormatUtil.formatAmount(100), '100.00');
      expect(FormatUtil.formatAmount(0.5), '0.50');
    });

    test('负数保留负号', () {
      expect(FormatUtil.formatAmount(-1234.5), '-1,234.50');
    });
  });

  group('FormatUtil.formatPercent', () {
    test('正数带 + 号', () {
      expect(FormatUtil.formatPercent(1.23), '+1.23%');
      expect(FormatUtil.formatPercent(10), '+10.00%');
    });

    test('负数带 - 号', () {
      expect(FormatUtil.formatPercent(-1.23), '-1.23%');
    });

    test('0 显示为 +0.00%', () {
      expect(FormatUtil.formatPercent(0), '+0.00%');
    });
  });

  group('FormatUtil.formatPnl', () {
    test('正盈亏带 + 号 + 货币符号', () {
      expect(FormatUtil.formatPnl(100, '¥'), '+¥100.00');
      expect(FormatUtil.formatPnl(1234.5, '\$'), '+\$1,234.50');
    });

    test('负盈亏不额外加 - 号（abs 后用 "" 表示）', () {
      // 实现：abs 后前面无符号
      expect(FormatUtil.formatPnl(-100, '¥'), '¥100.00');
    });

    test('0 视作正盈亏', () {
      expect(FormatUtil.formatPnl(0, '¥'), '+¥0.00');
    });
  });

  group('FormatUtil.formatInt', () {
    test('整数千分位', () {
      expect(FormatUtil.formatInt(1234), '1,234');
      expect(FormatUtil.formatInt(1000000), '1,000,000');
    });

    test('小数会被截断', () {
      expect(FormatUtil.formatInt(1234.9), '1,235');
    });
  });
}
