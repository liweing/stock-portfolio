import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_portfolio/models/enums.dart';
import 'package:stock_portfolio/ui/widgets/platform_selector.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: child),
    );

void main() {
  group('PlatformSelector', () {
    testWidgets('所有平台都展示为可选项', (tester) async {
      await tester.pumpWidget(_wrap(PlatformSelector(
        selected: BrokerageType.futu,
        onChanged: (_) {},
      )));

      for (final type in BrokerageType.values) {
        expect(find.text(type.label), findsOneWidget);
      }
    });

    testWidgets('支付宝在选项中', (tester) async {
      await tester.pumpWidget(_wrap(PlatformSelector(
        selected: BrokerageType.futu,
        onChanged: (_) {},
      )));

      expect(find.text('支付宝'), findsOneWidget);
    });

    testWidgets('点击切换触发 onChanged', (tester) async {
      BrokerageType? selected;
      await tester.pumpWidget(_wrap(PlatformSelector(
        selected: BrokerageType.futu,
        onChanged: (v) => selected = v,
      )));

      await tester.tap(find.text('支付宝'));
      await tester.pumpAndSettle();
      expect(selected, BrokerageType.alipay);
    });
  });

  group('MarketSelector', () {
    testWidgets('所有市场都展示', (tester) async {
      await tester.pumpWidget(_wrap(MarketSelector(
        selected: StockMarket.sh,
        onChanged: (_) {},
      )));

      for (final market in StockMarket.values) {
        expect(find.text(market.label), findsOneWidget);
      }
    });

    testWidgets('基金在选项中', (tester) async {
      await tester.pumpWidget(_wrap(MarketSelector(
        selected: StockMarket.sh,
        onChanged: (_) {},
      )));

      expect(find.text('基金'), findsOneWidget);
    });

    testWidgets('选中基金触发 onChanged(fund)', (tester) async {
      StockMarket? selected;
      await tester.pumpWidget(_wrap(
        // SegmentedButton 可能需要宽度约束
        SizedBox(
          width: 500,
          child: MarketSelector(
            selected: StockMarket.sh,
            onChanged: (v) => selected = v,
          ),
        ),
      ));

      await tester.tap(find.text('基金'));
      await tester.pumpAndSettle();
      expect(selected, StockMarket.fund);
    });
  });
}
