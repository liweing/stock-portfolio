import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/app_database.dart';
import '../data/repositories/cloud_position_repository.dart';
import '../data/repositories/snapshot_repository.dart';
import '../data/repositories/stock_repository.dart';
import '../data/repositories/transaction_repository.dart';
import '../data/services/stock_price_service.dart';
import 'auth_provider.dart';

/// 本地数据库实例（仅用于价格缓存）
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// 行情服务
final stockPriceServiceProvider = Provider<StockPriceService>((ref) {
  return StockPriceService();
});

/// 持仓 Repository（云端 Supabase）
final positionRepositoryProvider = Provider<CloudPositionRepository>((ref) {
  return CloudPositionRepository(ref.watch(supabaseClientProvider));
});

/// 股票 Repository（行情刷新 + 本地缓存）
final stockRepositoryProvider = Provider<StockRepository>((ref) {
  return StockRepository(
    ref.watch(databaseProvider),
    ref.watch(stockPriceServiceProvider),
  );
});

/// 快照 Repository（每日收益记录）
final snapshotRepositoryProvider = Provider<SnapshotRepository>((ref) {
  return SnapshotRepository(ref.watch(supabaseClientProvider));
});

/// 交易记录 Repository
final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(supabaseClientProvider));
});
