import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stock_portfolio/data/services/stock_price_service.dart';
import 'package:stock_portfolio/models/enums.dart';

class _MockDio extends Mock implements Dio {}

/// 构造一个伪造的 Dio Response
Response<T> _res<T>(T data, {int status = 200}) => Response<T>(
      data: data,
      statusCode: status,
      requestOptions: RequestOptions(path: ''),
    );

/// 构造东方财富响应 Map
Map<String, dynamic> _em({
  required String code,
  required String name,
  required int price,
  required int prevClose,
  int changePctX100 = 0,
  int precision = 2,
}) =>
    {
      'rc': 0,
      'data': {
        'f57': code,
        'f58': name,
        'f43': price,
        'f60': prevClose,
        'f170': changePctX100,
        'f59': precision,
      },
    };

Matcher _eastMoneyUrl() => predicate<String>(
      (url) => url.contains('eastmoney.com') && url.contains('/api/qt/stock/get'),
      'is EastMoney stock URL',
    );

Matcher _fundGzUrl() => predicate<String>(
      (url) =>
          url.startsWith('/api/fund') ||
          url.contains('fundgz.1234567.com.cn'),
      'is fund URL',
    );

void main() {
  setUpAll(() {
    // mocktail 需要注册默认值
    registerFallbackValue(Options());
    registerFallbackValue(RequestOptions(path: ''));
  });

  late _MockDio dio;
  late StockPriceService service;

  setUp(() {
    dio = _MockDio();
    service = StockPriceService(dio: dio);
  });

  group('东方财富 A 股解析', () {
    test('贵州茅台: price=180000, precision=2 → 1800.00', () async {
      when(() => dio.get(any(that: _eastMoneyUrl()),
              queryParameters: any(named: 'queryParameters'),
              options: any(named: 'options')))
          .thenAnswer((_) async => _res(_em(
                code: '600519',
                name: '贵州茅台',
                price: 180000,
                prevClose: 179500,
                changePctX100: 28,
              )));

      final quote = await service.lookupStock('600519', StockMarket.sh);
      expect(quote, isNotNull);
      expect(quote!.name, '贵州茅台');
      expect(quote.currentPrice, closeTo(1800.00, 0.001));
      expect(quote.prevClose, closeTo(1795.00, 0.001));
      expect(quote.changePct, closeTo(0.28, 0.001));
    });
  });

  group('港股价格精度', () {
    test('腾讯控股: precision=1 → 489.2 而不是 4892', () async {
      when(() => dio.get(any(that: _eastMoneyUrl()),
              queryParameters: any(named: 'queryParameters'),
              options: any(named: 'options')))
          .thenAnswer((_) async => _res(_em(
                code: '00700',
                name: '腾讯控股',
                price: 4892,
                prevClose: 4800,
                changePctX100: 192,
                precision: 1, // 港股价格精度通常是 1 位小数
              )));

      final quote = await service.lookupStock('00700', StockMarket.hk);
      expect(quote!.currentPrice, closeTo(489.2, 0.001));
      expect(quote.prevClose, closeTo(480.0, 0.001));
    });
  });

  group('沪深冲突代码 fallback', () {
    test('000071: 深市失败后 fallback 沪市成功', () async {
      when(() => dio.get(any(that: _eastMoneyUrl()),
              queryParameters: any(named: 'queryParameters'),
              options: any(named: 'options')))
          .thenAnswer((invocation) async {
        final params = invocation.namedArguments[#queryParameters]
            as Map<String, dynamic>?;
        final secid = params?['secid'] as String?;
        // 深市 (0.000071) 返回 null，沪市 (1.000071) 返回数据
        if (secid == '0.000071') {
          return _res({'rc': 100, 'data': null});
        }
        if (secid == '1.000071') {
          return _res(_em(
            code: '000071',
            name: '材料等权',
            price: 544640,
            prevClose: 550567,
          ));
        }
        return _res({'rc': 100, 'data': null});
      });

      final quote = await service.lookupStock('000071', StockMarket.sz);
      expect(quote, isNotNull);
      expect(quote!.name, '材料等权');
      expect(quote.currentPrice, closeTo(5446.40, 0.001));
    });

    test('两边都没有数据返回 null', () async {
      when(() => dio.get(any(that: _eastMoneyUrl()),
              queryParameters: any(named: 'queryParameters'),
              options: any(named: 'options')))
          .thenAnswer((_) async => _res({'rc': 100, 'data': null}));

      final quote = await service.lookupStock('999999', StockMarket.sh);
      expect(quote, isNull);
    });
  });

  group('Content-Type text/plain 也能解析（APK 场景）', () {
    test('响应是 String 类型时自动 jsonDecode', () async {
      const raw = '{"rc":0,"data":{"f57":"600519","f58":"贵州茅台",'
          '"f43":180000,"f60":179500,"f170":28,"f59":2}}';
      when(() => dio.get(any(that: _eastMoneyUrl()),
              queryParameters: any(named: 'queryParameters'),
              options: any(named: 'options')))
          .thenAnswer((_) async => _res(raw));

      final quote = await service.lookupStock('600519', StockMarket.sh);
      expect(quote, isNotNull);
      expect(quote!.name, '贵州茅台');
    });

    test('String 响应不是合法 JSON 时返回 null', () async {
      when(() => dio.get(any(that: _eastMoneyUrl()),
              queryParameters: any(named: 'queryParameters'),
              options: any(named: 'options')))
          .thenAnswer((_) async => _res('not json content'));

      final quote = await service.lookupStock('600519', StockMarket.sh);
      expect(quote, isNull);
    });
  });

  group('天天基金 JSONP 解析', () {
    test('000071: 正常 jsonpgz(...) 响应', () async {
      const raw = 'jsonpgz({"fundcode":"000071","name":"华夏恒生ETF联接A",'
          '"jzrq":"2026-04-14","dwjz":"1.5337","gsz":"1.5379",'
          '"gszzl":"0.28","gztime":"2026-04-15 16:00"});';
      when(() => dio.get(any(that: _fundGzUrl()),
              options: any(named: 'options')))
          .thenAnswer((_) async => _res(raw));

      final quote = await service.lookupStock('000071', StockMarket.fund);
      expect(quote, isNotNull);
      expect(quote!.name, '华夏恒生ETF联接A');
      expect(quote.symbol, '000071');
      expect(quote.market, StockMarket.fund);
      expect(quote.currentPrice, closeTo(1.5379, 0.0001));
      expect(quote.prevClose, closeTo(1.5337, 0.0001));
      expect(quote.changePct, closeTo(0.28, 0.001));
    });

    test('025492: 国泰创业板人工智能 ETF', () async {
      const raw = 'jsonpgz({"fundcode":"025492",'
          '"name":"国泰创业板人工智能ETF发起联接A",'
          '"jzrq":"2026-04-14","dwjz":"1.3360","gsz":"1.3159",'
          '"gszzl":"-1.50","gztime":"2026-04-15 15:00"});';
      when(() => dio.get(any(that: _fundGzUrl()),
              options: any(named: 'options')))
          .thenAnswer((_) async => _res(raw));

      final quote = await service.lookupStock('025492', StockMarket.fund);
      expect(quote!.name, '国泰创业板人工智能ETF发起联接A');
      expect(quote.changePct, closeTo(-1.50, 0.001));
    });

    test('没有 gsz（估算净值）时 fallback 到 dwjz（单位净值）', () async {
      const raw = 'jsonpgz({"fundcode":"000071","name":"测试",'
          '"dwjz":"1.5000","gsz":"","gszzl":"","jzrq":"2026-04-14"});';
      when(() => dio.get(any(that: _fundGzUrl()),
              options: any(named: 'options')))
          .thenAnswer((_) async => _res(raw));

      final quote = await service.lookupStock('000071', StockMarket.fund);
      expect(quote!.currentPrice, closeTo(1.5000, 0.0001));
    });

    test('非 JSONP 格式返回 null', () async {
      when(() => dio.get(any(that: _fundGzUrl()),
              options: any(named: 'options')))
          .thenAnswer((_) async => _res('<html>Not Found</html>'));

      final quote = await service.lookupStock('999999', StockMarket.fund);
      expect(quote, isNull);
    });

    test('空响应返回 null', () async {
      when(() => dio.get(any(that: _fundGzUrl()),
              options: any(named: 'options')))
          .thenAnswer((_) async => _res(''));

      final quote = await service.lookupStock('000071', StockMarket.fund);
      expect(quote, isNull);
    });
  });

  group('fetchQuotes 批量', () {
    test('单只失败不影响其他', () async {
      // 第一只返回数据，第二只异常
      int callCount = 0;
      when(() => dio.get(any(that: _eastMoneyUrl()),
              queryParameters: any(named: 'queryParameters'),
              options: any(named: 'options')))
          .thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          return _res(_em(
            code: '600519', name: '贵州茅台',
            price: 180000, prevClose: 179500,
          ));
        }
        throw DioException(requestOptions: RequestOptions(path: ''));
      });

      final result = await service.fetchQuotes([
        (symbol: '600519', market: StockMarket.sh),
        (symbol: 'FAIL', market: StockMarket.sh),
      ]);
      expect(result.length, 1);
      expect(result.first.name, '贵州茅台');
    });

    test('空列表返回空', () async {
      final result = await service.fetchQuotes([]);
      expect(result, isEmpty);
    });
  });

  group('网络失败优雅降级', () {
    test('lookupStock 网络异常返回 null（不抛）', () async {
      when(() => dio.get(any(), options: any(named: 'options')))
          .thenThrow(DioException(requestOptions: RequestOptions(path: '')));

      final quote = await service.lookupStock('600519', StockMarket.sh);
      expect(quote, isNull);
    });
  });
}
