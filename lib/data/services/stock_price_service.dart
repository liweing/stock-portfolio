import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../models/enums.dart';

/// 股票实时报价
class StockQuote {
  final String symbol;
  final String name;
  final StockMarket market;
  final double currentPrice;
  final double prevClose;
  final double changePct;

  StockQuote({
    required this.symbol,
    required this.name,
    required this.market,
    required this.currentPrice,
    required this.prevClose,
    required this.changePct,
  });
}

/// 行情服务 - 东方财富 API（返回 UTF-8 JSON，无乱码问题）
class StockPriceService {
  final Dio _dio;

  StockPriceService({Dio? dio}) : _dio = dio ?? Dio();

  /// 查询单只股票信息（用于自动补全名称）
  Future<StockQuote?> lookupStock(String symbol, StockMarket market) async {
    try {
      final quotes = await fetchQuotes([(symbol: symbol, market: market)]);
      return quotes.isNotEmpty ? quotes.first : null;
    } catch (_) {
      return null;
    }
  }

  /// 批量获取行情 - 根据市场路由到不同 API
  Future<List<StockQuote>> fetchQuotes(
      List<({String symbol, StockMarket market})> stocks) async {
    if (stocks.isEmpty) return [];

    final results = <StockQuote>[];
    for (final stock in stocks) {
      try {
        final quote = stock.market.isFund
            ? await _fetchFromTianTianFund(stock.symbol)
            : await _fetchFromEastMoney(stock.symbol, stock.market);
        if (quote != null) results.add(quote);
      } catch (_) {
        // 单只失败不影响其他
      }
    }
    return results;
  }

  /// 天天基金 API（支持场外开放式基金）
  /// Web 平台因 CORS 走 Vercel 代理，APK 直连
  /// 返回格式（JSONP）:
  /// jsonpgz({"fundcode":"000071","name":"华夏恒生ETF联接A",
  ///   "jzrq":"2026-04-14","dwjz":"1.5337","gsz":"1.5379",
  ///   "gszzl":"0.28","gztime":"2026-04-15 16:00"})
  Future<StockQuote?> _fetchFromTianTianFund(String code) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    // Web 走代理，APK 直连
    final url = kIsWeb
        ? '/api/fund?code=$code&rt=$timestamp'
        : 'https://fundgz.1234567.com.cn/js/$code.js?rt=$timestamp';

    final response = await _dio.get(
      url,
      options: Options(responseType: ResponseType.plain),
    );

    final raw = response.data as String?;
    if (raw == null || raw.isEmpty) return null;

    // 提取 jsonpgz(...) 里的 JSON
    final match = RegExp(r'jsonpgz\((.*)\)').firstMatch(raw);
    if (match == null) return null;
    final jsonStr = match.group(1);
    if (jsonStr == null || jsonStr.isEmpty) return null;

    Map<String, dynamic> data;
    try {
      data = jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }

    final name = data['name'] as String? ?? '';
    final fundCode = data['fundcode'] as String? ?? code;

    // 单位净值（昨日收盘）
    final dwjz = double.tryParse(data['dwjz']?.toString() ?? '') ?? 0;
    // 估算净值（实时）
    final gsz = double.tryParse(data['gsz']?.toString() ?? '') ?? 0;
    // 估算涨跌幅
    final changePct = double.tryParse(data['gszzl']?.toString() ?? '') ?? 0;

    // 当前价用估算净值（无则退回单位净值）
    final currentPrice = gsz > 0 ? gsz : dwjz;
    if (currentPrice <= 0) return null;

    return StockQuote(
      symbol: fundCode,
      name: name,
      market: StockMarket.fund,
      currentPrice: currentPrice,
      prevClose: dwjz,
      changePct: changePct,
    );
  }

  /// 东方财富 API - 返回 UTF-8 JSON
  /// A股/港股: http://push2.eastmoney.com/api/qt/stock/get
  /// 字段: f43=最高,f44=最低,f46=开盘,f58=名称,f170=涨跌幅,f60=昨收,f43=现价
  Future<StockQuote?> _fetchFromEastMoney(
      String symbol, StockMarket market) async {
    // 期货：依次尝试各交易所前缀
    if (market == StockMarket.futures) {
      // 115=郑商所, 113=上期所, 114=大商所, 8=中金所, 142=能交所
      for (final prefix in ['115', '113', '114', '8', '142']) {
        final quote = await _queryEastMoneyWithSecid(
          '$prefix.$symbol',
          market,
        );
        if (quote != null) return quote;
      }
      return null;
    }

    // 优先用推断的 market 查询
    final quote = await _queryEastMoney(symbol, market);
    if (quote != null) return quote;

    // 如果失败，尝试沪深对调（处理 000xxx 号段同时存在于沪市指数和深市股票的情况）
    if (market == StockMarket.sz) {
      return await _queryEastMoney(symbol, StockMarket.sh);
    } else if (market == StockMarket.sh) {
      return await _queryEastMoney(symbol, StockMarket.sz);
    }
    return null;
  }

  /// 执行单次东方财富 API 调用
  Future<StockQuote?> _queryEastMoney(
      String symbol, StockMarket market) async {
    final secid = _toEastMoneySecId(symbol, market);
    if (secid == null) return null;
    return _queryEastMoneyWithSecid(secid, market);
  }

  /// 用指定 secid 查询（供期货多交易所尝试使用）
  Future<StockQuote?> _queryEastMoneyWithSecid(
      String secid, StockMarket market) async {

    final response = await _dio.get(
      'https://push2delay.eastmoney.com/api/qt/stock/get',
      queryParameters: {
        'secid': secid,
        // f59 是价格精度（小数位数），用于动态计算除数
        'fields': 'f57,f58,f43,f170,f60,f59,f44,f45,f46,f47',
        'ut': 'fa5fd1943c7b386f172d6893dbbd1d0c',
      },
      options: Options(
        // 强制按 JSON 解析（东财返回 text/plain，Dio 原生 HTTP 默认不会解析）
        responseType: ResponseType.json,
      ),
    );

    // 防御性处理：如果返回的是 String（某些平台/content-type 下），手动 decode
    final raw = response.data;
    Map<String, dynamic>? data;
    if (raw is Map<String, dynamic>) {
      data = raw;
    } else if (raw is String) {
      try {
        data = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }
    if (data == null || data['data'] == null) return null;

    final d = data['data'] as Map<String, dynamic>;
    final name = d['f58'] as String? ?? '';
    // 从 f57 或 secid 后缀拿到原始代码
    final code = d['f57'] as String? ??
        (secid.contains('.') ? secid.split('.').last : secid);
    final rawPrice = d['f43'];
    final rawPrevClose = d['f60'];
    final rawChangePct = d['f170'];
    final rawPrecision = d['f59'];

    if (rawPrice == null || rawPrice == '-') return null;

    // 价格精度：f59 = 小数位数 (A股/美股通常为 2，港股通常为 3)
    // 实际除数 = 10^precision
    final precision = rawPrecision is int
        ? rawPrecision
        : (rawPrecision is num ? rawPrecision.toInt() : 2);
    final priceFactor = _powInt(10, precision).toDouble();

    double parseValue(dynamic v) {
      if (v == null || v == '-') return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    final currentPrice = parseValue(rawPrice) / priceFactor;
    final prevClose = rawPrevClose != null && rawPrevClose != '-'
        ? parseValue(rawPrevClose) / priceFactor
        : currentPrice;
    // 涨跌幅精度固定为 2 位小数（除以 100）
    final changePct = parseValue(rawChangePct) / 100.0;

    if (currentPrice <= 0) return null;

    return StockQuote(
      symbol: code,
      name: name,
      market: market,
      currentPrice: currentPrice,
      prevClose: prevClose,
      changePct: changePct,
    );
  }

  /// 整数次方
  int _powInt(int base, int exp) {
    var result = 1;
    for (var i = 0; i < exp; i++) {
      result *= base;
    }
    return result;
  }

  /// 将股票代码转换为东方财富 secid 格式
  /// A股沪市: 1.600519  深市: 0.000858
  /// 港股: 116.00700
  /// 美股: 105.AAPL
  String? _toEastMoneySecId(String symbol, StockMarket market) {
    switch (market) {
      case StockMarket.sh:
        return '1.$symbol';
      case StockMarket.sz:
        return '0.$symbol';
      case StockMarket.hk:
        return '116.$symbol';
      case StockMarket.us:
        return '105.${symbol.toUpperCase()}';
      case StockMarket.fund:
        return null; // 基金不走东财 API
      case StockMarket.futures:
        return null; // 期货在 _fetchFromEastMoney 里直接尝试多个 secid
    }
  }
}
