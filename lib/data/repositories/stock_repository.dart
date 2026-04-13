import 'package:drift/drift.dart';
import '../../models/enums.dart';
import '../database/app_database.dart';
import '../services/stock_price_service.dart';

/// 用于刷新价格的最小持仓信息
class PriceRefreshInput {
  final String symbol;
  final String market;
  PriceRefreshInput({required this.symbol, required this.market});
}

class StockRepository {
  final AppDatabase _db;
  final StockPriceService _priceService;

  StockRepository(this._db, this._priceService);

  /// 刷新行情并缓存到数据库
  Future<List<StockQuote>> refreshPrices(
      List<PriceRefreshInput> positions) async {
    if (positions.isEmpty) return [];

    final stocks = positions
        .map((p) => (
              symbol: p.symbol,
              market: StockMarket.fromName(p.market),
            ))
        .toSet()
        .toList();

    final quotes = await _priceService.fetchQuotes(stocks);

    // 写入缓存
    final entries = quotes
        .map((q) => PriceCacheCompanion(
              symbol: Value(q.symbol),
              market: Value(q.market.name),
              currentPrice: Value(q.currentPrice),
              prevClose: Value(q.prevClose),
              changePct: Value(q.changePct),
              stockName: Value(q.name),
              updatedAt: Value(DateTime.now()),
            ))
        .toList();

    await _db.upsertPrices(entries);
    return quotes;
  }

  /// 获取缓存价格
  Future<Map<String, PriceCacheData>> getCachedPrices(
      List<String> symbols) async {
    final cached = await _db.getCachedPrices(symbols);
    return {for (final c in cached) c.symbol: c};
  }

  /// 监听缓存价格变化
  Stream<List<PriceCacheData>> watchCachedPrices() =>
      _db.watchAllCachedPrices();
}
