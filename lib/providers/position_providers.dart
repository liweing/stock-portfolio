import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/app_database.dart';
import '../data/repositories/cloud_position_repository.dart';
import '../data/repositories/stock_repository.dart';
import 'database_provider.dart';

/// 所有持仓列表 (实时流)
final allPositionsProvider = StreamProvider<List<CloudPosition>>((ref) {
  return ref.watch(positionRepositoryProvider).watchAll();
});

/// 刷新行情状态
final priceRefreshingProvider = StateProvider<bool>((ref) => false);

/// 刷新行情
final refreshPricesProvider = FutureProvider<void>((ref) async {
  final positions = await ref.watch(positionRepositoryProvider).getAll();
  if (positions.isEmpty) return;

  ref.read(priceRefreshingProvider.notifier).state = true;
  try {
    final inputs = positions
        .map((p) => PriceRefreshInput(symbol: p.symbol, market: p.market))
        .toList();
    await ref.read(stockRepositoryProvider).refreshPrices(inputs);
  } finally {
    ref.read(priceRefreshingProvider.notifier).state = false;
  }
});

/// 缓存价格 (实时流)
final cachedPricesProvider = StreamProvider<List<PriceCacheData>>((ref) {
  return ref.watch(stockRepositoryProvider).watchCachedPrices();
});
