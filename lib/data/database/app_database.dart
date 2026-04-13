import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Positions, PriceCache])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'stock_portfolio',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.dart.js'),
      ),
    );
  }

  // ===== Positions CRUD =====

  /// 获取所有持仓（Stream）
  Stream<List<Position>> watchAllPositions() {
    return (select(positions)
          ..orderBy([
            (t) => OrderingTerm(expression: t.platform),
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// 获取所有持仓
  Future<List<Position>> getAllPositions() => select(positions).get();

  /// 插入持仓
  Future<int> insertPosition(PositionsCompanion entry) =>
      into(positions).insert(entry);

  /// 更新持仓
  Future<bool> updatePosition(Position entry) =>
      update(positions).replace(entry);

  /// 删除持仓
  Future<int> deletePosition(int id) =>
      (delete(positions)..where((t) => t.id.equals(id))).go();

  /// 获取所有不重复的股票代码
  Future<List<String>> getDistinctSymbols() async {
    final query = selectOnly(positions, distinct: true)
      ..addColumns([positions.symbol]);
    final results = await query.get();
    return results.map((row) => row.read(positions.symbol)!).toList();
  }

  // ===== PriceCache =====

  /// 获取缓存价格
  Future<PriceCacheData?> getCachedPrice(String symbol) =>
      (select(priceCache)..where((t) => t.symbol.equals(symbol)))
          .getSingleOrNull();

  /// 获取多个缓存价格
  Future<List<PriceCacheData>> getCachedPrices(List<String> symbols) =>
      (select(priceCache)..where((t) => t.symbol.isIn(symbols))).get();

  /// 监听所有缓存价格
  Stream<List<PriceCacheData>> watchAllCachedPrices() =>
      select(priceCache).watch();

  /// 更新或插入缓存价格
  Future<void> upsertPrice(PriceCacheCompanion entry) =>
      into(priceCache).insertOnConflictUpdate(entry);

  /// 批量更新价格
  Future<void> upsertPrices(List<PriceCacheCompanion> entries) async {
    await batch((batch) {
      for (final entry in entries) {
        batch.insert(priceCache, entry, onConflict: DoUpdate((_) => entry));
      }
    });
  }
}
