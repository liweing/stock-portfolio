import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/stock_repository.dart';
import '../../models/portfolio_summary.dart';
import '../../providers/auth_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/portfolio_providers.dart';
import '../../providers/position_providers.dart';
import '../widgets/pnl_card.dart';
import '../widgets/position_tile.dart';
import 'add_position_screen.dart';

class PositionListScreen extends ConsumerStatefulWidget {
  const PositionListScreen({super.key});

  @override
  ConsumerState<PositionListScreen> createState() =>
      _PositionListScreenState();
}

class _PositionListScreenState extends ConsumerState<PositionListScreen> {
  bool _isRefreshing = false;

  Future<void> _refreshPrices() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final positions =
          await ref.read(positionRepositoryProvider).getAll();
      if (positions.isNotEmpty) {
        final inputs = positions
            .map((p) =>
                PriceRefreshInput(symbol: p.symbol, market: p.market))
            .toList();
        await ref.read(stockRepositoryProvider).refreshPrices(inputs);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('行情刷新失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    // 首次进入自动刷新行情
    Future.microtask(() => _refreshPrices());
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(portfolioSummaryProvider);
    final pnlList = ref.watch(positionPnlListProvider);

    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('持仓助手'),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshPrices,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
            onSelected: (value) async {
              if (value == 'logout') {
                await ref.read(authRepositoryProvider).signOut();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Text(
                  user?.email ?? '',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18),
                    SizedBox(width: 8),
                    Text('退出登录'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: pnlList.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _refreshPrices,
              child: ListView(
                children: [
                  PnlSummaryCard(
                    totalMarketValue: summary.totalMarketValue,
                    totalCost: summary.totalCost,
                    totalPnl: summary.totalPnl,
                    totalPnlPercent: summary.totalPnlPercent,
                  ),
                  // 按平台分组
                  ..._buildGroupedList(pnlList),
                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAdd(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            '暂无持仓',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角 + 添加持仓',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedList(List<PositionPnl> pnlList) {
    final grouped = <String, List<PositionPnl>>{};
    for (final pnl in pnlList) {
      final key = pnl.platform.label;
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(pnl);
    }

    final widgets = <Widget>[];
    for (final entry in grouped.entries) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            entry.key,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      );
      for (final pnl in entry.value) {
        widgets.add(PositionTile(
          pnl: pnl,
          onTap: () => _navigateToEdit(pnl),
        ));
        widgets.add(const Divider(height: 1, indent: 16, endIndent: 16));
      }
    }
    return widgets;
  }

  void _navigateToAdd() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddPositionScreen()),
    );
    if (result == true) {
      ref.invalidate(allPositionsProvider);
      _refreshPrices();
    }
  }

  void _navigateToEdit(PositionPnl pnl) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddPositionScreen(
          editPositionId: pnl.positionId,
          initialSymbol: pnl.symbol,
          initialName: pnl.name,
          initialMarket: pnl.market,
          initialQuantity: pnl.quantity,
          initialAvgCost: pnl.avgCost,
          initialPlatform: pnl.platform,
        ),
      ),
    );
    if (result == true) {
      ref.invalidate(allPositionsProvider);
      _refreshPrices();
    }
  }

}
