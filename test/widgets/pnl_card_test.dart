import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_portfolio/ui/widgets/pnl_card.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: child),
    );

void main() {
  group('PnlSummaryCard', () {
    testWidgets('显示总市值/总成本/总盈亏/收益率 4 个数据点', (tester) async {
      await tester.pumpWidget(_wrap(const PnlSummaryCard(
        totalMarketValue: 12000,
        totalCost: 10000,
        totalPnl: 2000,
        totalPnlPercent: 20.0,
      )));

      expect(find.text('总市值'), findsOneWidget);
      expect(find.text('总成本'), findsOneWidget);
      expect(find.text('总盈亏'), findsOneWidget);
      expect(find.text('收益率'), findsOneWidget);
    });

    testWidgets('金额带 ¥ 符号', (tester) async {
      await tester.pumpWidget(_wrap(const PnlSummaryCard(
        totalMarketValue: 12000,
        totalCost: 10000,
        totalPnl: 2000,
        totalPnlPercent: 20.0,
      )));

      expect(find.text('¥12,000.00'), findsOneWidget);
      expect(find.text('¥10,000.00'), findsOneWidget);
    });

    testWidgets('盈利时显示红色（A股红涨绿跌）', (tester) async {
      await tester.pumpWidget(_wrap(const PnlSummaryCard(
        totalMarketValue: 12000,
        totalCost: 10000,
        totalPnl: 2000,
        totalPnlPercent: 20.0,
      )));

      final pnlText = tester.widget<Text>(find.text('+¥2,000.00'));
      expect(pnlText.style?.color, Colors.red.shade700);

      final pctText = tester.widget<Text>(find.text('+20.00%'));
      expect(pctText.style?.color, Colors.red.shade700);
    });

    testWidgets('亏损时显示绿色 + - 号', (tester) async {
      await tester.pumpWidget(_wrap(const PnlSummaryCard(
        totalMarketValue: 8000,
        totalCost: 10000,
        totalPnl: -2000,
        totalPnlPercent: -20.0,
      )));

      // 负数显示为 -¥2,000.00（显式 - 号 + 绿色）
      final pnlText = tester.widget<Text>(find.text('-¥2,000.00'));
      expect(pnlText.style?.color, Colors.green.shade700);

      final pctText = tester.widget<Text>(find.text('-20.00%'));
      expect(pctText.style?.color, Colors.green.shade700);
    });

    testWidgets('显示"以 ¥ 人民币计"标签', (tester) async {
      await tester.pumpWidget(_wrap(const PnlSummaryCard(
        totalMarketValue: 12000,
        totalCost: 10000,
        totalPnl: 2000,
        totalPnlPercent: 20.0,
      )));

      expect(find.text('以 ¥ 人民币计'), findsOneWidget);
    });

    testWidgets('空持仓显示零值', (tester) async {
      await tester.pumpWidget(_wrap(const PnlSummaryCard(
        totalMarketValue: 0,
        totalCost: 0,
        totalPnl: 0,
        totalPnlPercent: 0,
      )));

      expect(find.text('¥0.00'), findsNWidgets(2)); // 总市值 + 总成本
      expect(find.text('+¥0.00'), findsOneWidget); // 总盈亏
    });
  });
}
