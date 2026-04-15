import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/enums.dart';
import '../models/portfolio_summary.dart';
import 'position_providers.dart';

/// 持仓盈亏详情列表
final positionPnlListProvider = Provider<List<PositionPnl>>((ref) {
  final positionsAsync = ref.watch(allPositionsProvider);
  final pricesAsync = ref.watch(cachedPricesProvider);

  final positions = positionsAsync.valueOrNull ?? [];
  final prices = pricesAsync.valueOrNull ?? [];

  if (positions.isEmpty) return [];

  final priceMap = {for (final p in prices) p.symbol: p};

  return positions.map((pos) {
    final cached = priceMap[pos.symbol];
    final currentPrice = cached?.currentPrice ?? pos.avgCost;
    final prevClose = cached?.prevClose ?? 0;

    return PositionPnl(
      positionId: pos.id,
      symbol: pos.symbol,
      name: cached?.stockName ?? pos.name,
      market: StockMarket.fromName(pos.market),
      platform: BrokerageType.fromName(pos.platform),
      quantity: pos.quantity,
      avgCost: pos.avgCost,
      currentPrice: currentPrice,
      prevClose: prevClose,
      currency: pos.currency,
    );
  }).toList();
});

/// 整体投资组合汇总
final portfolioSummaryProvider = Provider<PortfolioSummary>((ref) {
  final pnlList = ref.watch(positionPnlListProvider);

  if (pnlList.isEmpty) return PortfolioSummary.empty();

  // 所有金额统一转为人民币
  final totalMarketValue =
      pnlList.fold(0.0, (sum, p) => sum + p.marketValueCny);
  final totalCost = pnlList.fold(0.0, (sum, p) => sum + p.costValueCny);
  final totalPnl = totalMarketValue - totalCost;
  final totalPnlPercent = totalCost == 0 ? 0.0 : (totalPnl / totalCost) * 100;

  // 今日盈亏（人民币）
  final dailyPnl = pnlList.fold(0.0, (sum, p) => sum + p.dailyPnlCny);
  // 今日盈亏百分比 = 今日盈亏 / (总市值 - 今日盈亏) = 今日盈亏 / 昨日总市值
  final yesterdayValue = totalMarketValue - dailyPnl;
  final dailyPnlPercent =
      yesterdayValue == 0 ? 0.0 : (dailyPnl / yesterdayValue) * 100;

  // 按股票分配（人民币）
  final stockMap = <String, double>{};
  final stockNameMap = <String, String>{};
  for (final p in pnlList) {
    stockMap[p.symbol] = (stockMap[p.symbol] ?? 0) + p.marketValueCny;
    stockNameMap[p.symbol] = p.name;
  }
  final allocationByStock = stockMap.entries.map((e) {
    return AllocationItem(
      label: '${stockNameMap[e.key]} (${e.key})',
      value: e.value,
      percentage: totalMarketValue == 0 ? 0 : (e.value / totalMarketValue) * 100,
    );
  }).toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  // 按平台分配（人民币）
  final platformMap = <BrokerageType, double>{};
  for (final p in pnlList) {
    platformMap[p.platform] =
        (platformMap[p.platform] ?? 0) + p.marketValueCny;
  }
  final allocationByPlatform = platformMap.entries.map((e) {
    return AllocationItem(
      label: e.key.label,
      value: e.value,
      percentage: totalMarketValue == 0 ? 0 : (e.value / totalMarketValue) * 100,
    );
  }).toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  // 按平台聚合：总市值/总成本/累计盈亏/今日盈亏（都转为人民币）
  final platformAgg = <BrokerageType, List<PositionPnl>>{};
  for (final p in pnlList) {
    platformAgg.putIfAbsent(p.platform, () => []).add(p);
  }
  final platformStats = platformAgg.entries.map((e) {
    final list = e.value;
    final mv = list.fold(0.0, (s, p) => s + p.marketValueCny);
    final cost = list.fold(0.0, (s, p) => s + p.costValueCny);
    final pnl = mv - cost;
    final pct = cost == 0 ? 0.0 : (pnl / cost) * 100;
    final daily = list.fold(0.0, (s, p) => s + p.dailyPnlCny);
    return PlatformStat(
      platform: e.key,
      marketValue: mv,
      cost: cost,
      totalPnl: pnl,
      totalPnlPercent: pct,
      dailyPnl: daily,
    );
  }).toList()
    ..sort((a, b) => b.marketValue.compareTo(a.marketValue));

  return PortfolioSummary(
    totalMarketValue: totalMarketValue,
    totalCost: totalCost,
    totalPnl: totalPnl,
    totalPnlPercent: totalPnlPercent,
    dailyPnl: dailyPnl,
    dailyPnlPercent: dailyPnlPercent,
    allocationByStock: allocationByStock,
    allocationByPlatform: allocationByPlatform,
    platformStats: platformStats,
    positionDetails: pnlList,
  );
});
