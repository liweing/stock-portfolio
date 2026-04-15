import 'package:flutter_test/flutter_test.dart';
import 'package:stock_portfolio/models/enums.dart';

void main() {
  group('StockMarket.guessFromSymbol', () {
    test('6 开头的 6 位数字 → 沪市', () {
      expect(StockMarket.guessFromSymbol('600519'), StockMarket.sh);
      expect(StockMarket.guessFromSymbol('601318'), StockMarket.sh);
      expect(StockMarket.guessFromSymbol('688111'), StockMarket.sh);
    });

    test('0 开头的 6 位数字 → 深市', () {
      expect(StockMarket.guessFromSymbol('000001'), StockMarket.sz);
      expect(StockMarket.guessFromSymbol('000858'), StockMarket.sz);
      expect(StockMarket.guessFromSymbol('002594'), StockMarket.sz);
    });

    test('3 开头的 6 位数字 → 深市（创业板）', () {
      expect(StockMarket.guessFromSymbol('300750'), StockMarket.sz);
      expect(StockMarket.guessFromSymbol('301048'), StockMarket.sz);
    });

    test('5 位数字 → 港股', () {
      expect(StockMarket.guessFromSymbol('00700'), StockMarket.hk);
      expect(StockMarket.guessFromSymbol('09988'), StockMarket.hk);
      expect(StockMarket.guessFromSymbol('03690'), StockMarket.hk);
    });

    test('字母开头 → 美股', () {
      expect(StockMarket.guessFromSymbol('AAPL'), StockMarket.us);
      expect(StockMarket.guessFromSymbol('TSLA'), StockMarket.us);
      expect(StockMarket.guessFromSymbol('BRK.B'), StockMarket.us);
    });

    test('小写字母也可识别为美股', () {
      expect(StockMarket.guessFromSymbol('aapl'), StockMarket.us);
    });

    test('空字符串或空白返回 null', () {
      expect(StockMarket.guessFromSymbol(''), isNull);
      expect(StockMarket.guessFromSymbol('   '), isNull);
    });

    test('无法识别的代码返回 null', () {
      expect(StockMarket.guessFromSymbol('123'), isNull);
      expect(StockMarket.guessFromSymbol('1234567'), isNull);
      expect(StockMarket.guessFromSymbol('@#\$'), isNull);
    });

    test('前后空格应被 trim', () {
      expect(StockMarket.guessFromSymbol('  600519  '), StockMarket.sh);
      expect(StockMarket.guessFromSymbol(' AAPL '), StockMarket.us);
    });
  });

  group('StockMarket 属性', () {
    test('各市场货币正确', () {
      expect(StockMarket.sh.currency, 'CNY');
      expect(StockMarket.sz.currency, 'CNY');
      expect(StockMarket.hk.currency, 'HKD');
      expect(StockMarket.us.currency, 'USD');
      expect(StockMarket.fund.currency, 'CNY');
    });

    test('各市场货币符号正确', () {
      expect(StockMarket.sh.currencySymbol, '¥');
      expect(StockMarket.hk.currencySymbol, 'HK\$');
      expect(StockMarket.us.currencySymbol, '\$');
      expect(StockMarket.fund.currencySymbol, '¥');
    });

    test('isFund 只有 fund 为 true', () {
      expect(StockMarket.fund.isFund, isTrue);
      expect(StockMarket.sh.isFund, isFalse);
      expect(StockMarket.hk.isFund, isFalse);
    });

    test('tencentPrefix 映射正确', () {
      expect(StockMarket.sh.tencentPrefix, 'sh');
      expect(StockMarket.sz.tencentPrefix, 'sz');
      expect(StockMarket.hk.tencentPrefix, 'hk');
      expect(StockMarket.us.tencentPrefix, 'us');
    });
  });

  group('StockMarket.fromName', () {
    test('存在的名称返回对应枚举', () {
      expect(StockMarket.fromName('sh'), StockMarket.sh);
      expect(StockMarket.fromName('fund'), StockMarket.fund);
    });

    test('不存在的名称 fallback 到 us', () {
      expect(StockMarket.fromName('unknown'), StockMarket.us);
      expect(StockMarket.fromName(''), StockMarket.us);
    });
  });

  group('BrokerageType.fromName', () {
    test('存在的名称返回对应枚举', () {
      expect(BrokerageType.fromName('futu'), BrokerageType.futu);
      expect(BrokerageType.fromName('alipay'), BrokerageType.alipay);
    });

    test('不存在的名称 fallback 到 other', () {
      expect(BrokerageType.fromName('unknown'), BrokerageType.other);
      expect(BrokerageType.fromName(''), BrokerageType.other);
    });

    test('所有平台标签都非空', () {
      for (final type in BrokerageType.values) {
        expect(type.label, isNotEmpty);
      }
    });
  });
}
