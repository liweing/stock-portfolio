import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/stock_repository.dart';
import '../../models/portfolio_summary.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/services/update_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/portfolio_providers.dart';
import '../../providers/position_providers.dart';
import '../../providers/update_provider.dart';
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
              switch (value) {
                case 'logout':
                  await ref.read(authRepositoryProvider).signOut();
                  break;
                case 'check_update':
                  await _checkForUpdate();
                  break;
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
              PopupMenuItem<String>(
                enabled: false,
                child: FutureBuilder<({String version, String build})>(
                  future:
                      ref.read(updateServiceProvider).getLocalVersion(),
                  builder: (ctx, snap) {
                    final v = snap.data;
                    final text = v == null
                        ? '版本 ...'
                        : '版本 ${v.version} (${v.build})';
                    return Text(
                      text,
                      style: const TextStyle(fontSize: 12),
                    );
                  },
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'check_update',
                child: Row(
                  children: [
                    Icon(Icons.system_update, size: 18),
                    SizedBox(width: 8),
                    Text('检查更新'),
                  ],
                ),
              ),
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

  /// 检查更新（点菜单触发）
  Future<void> _checkForUpdate() async {
    // 转圈提示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    UpdateCheckResult? result;
    try {
      result = await ref.read(updateServiceProvider).checkForUpdate();
    } catch (_) {
      // 网络错
    }

    if (!mounted) return;
    Navigator.of(context).pop(); // 关 loading

    if (result == null || result.latest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('检查失败，请检查网络后重试')),
      );
      return;
    }

    if (!result.hasUpdate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已是最新版本 ${result.currentVersion}+${result.currentBuild}',
          ),
        ),
      );
      return;
    }

    final latest = result.latest!;
    final shouldUpdate = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('发现新版本 ${latest.version}+${latest.build}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('当前版本：${result?.currentVersion}+${result?.currentBuild}'),
              const SizedBox(height: 12),
              const Text(
                '更新内容：',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                latest.body.isEmpty ? '（无详细说明）' : latest.body,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('稍后'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('立即下载'),
          ),
        ],
      ),
    );

    if (shouldUpdate == true) {
      // 优先 APK 直链，否则跳 GitHub release 页面
      final url = latest.apkDownloadUrl ?? latest.htmlUrl;
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }
}
