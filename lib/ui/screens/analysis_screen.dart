import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils.dart';
import '../../data/repositories/stock_repository.dart';
import '../../models/portfolio_summary.dart';
import '../../providers/database_provider.dart';
import '../../providers/portfolio_providers.dart';
import '../widgets/pie_chart_widget.dart';
import '../widgets/pnl_card.dart';
import 'history_chart_screen.dart';

class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({super.key});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  bool _showByPlatform = false;
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
  Widget build(BuildContext context) {
    final summary = ref.watch(portfolioSummaryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('投资分析'),
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
        ],
      ),
      body: summary.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _refreshPrices,
              child: ListView(
              children: [
                // 今日盈亏大卡片（重点展示）
                _DailyPnlHeroCard(
                  dailyPnl: summary.dailyPnl,
                  dailyPnlPercent: summary.dailyPnlPercent,
                  totalMarketValue: summary.totalMarketValue,
                ),

                // 收益走势入口
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HistoryChartScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.show_chart, size: 18),
                    label: const Text('查看收益走势'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 40),
                    ),
                  ),
                ),

                // 总览卡片
                PnlSummaryCard(
                  totalMarketValue: summary.totalMarketValue,
                  totalCost: summary.totalCost,
                  totalPnl: summary.totalPnl,
                  totalPnlPercent: summary.totalPnlPercent,
                ),

                // 按平台盈亏明细
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    '按平台汇总',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ..._buildPlatformStats(summary, theme),

                const Divider(height: 32),

                // 今日涨跌排行标题
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    '今日涨跌排行',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ..._buildDailyRanking(summary, theme),

                const Divider(height: 32),

                // 切换按钮
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('按股票')),
                      ButtonSegment(value: true, label: Text('按平台')),
                    ],
                    selected: {_showByPlatform},
                    onSelectionChanged: (set) =>
                        setState(() => _showByPlatform = set.first),
                  ),
                ),

                // 饼图
                AllocationPieChart(
                  items: _showByPlatform
                      ? summary.allocationByPlatform
                      : summary.allocationByStock,
                  title: _showByPlatform ? '平台仓位分配' : '股票仓位分配',
                ),

                const Divider(height: 32),

                // 总盈亏排行
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    '累计盈亏明细',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                ..._buildPnlRanking(summary, theme),

                const SizedBox(height: 32),
              ],
            ),
          ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined,
              size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            '暂无持仓数据',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            '请先在"持仓"页面添加持仓',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPlatformStats(
      PortfolioSummary summary, ThemeData theme) {
    if (summary.platformStats.isEmpty) return const [];
    return summary.platformStats.map((stat) {
      final totalColor =
          stat.isProfit ? Colors.red.shade700 : Colors.green.shade700;
      final dailyColor =
          stat.isDailyUp ? Colors.red.shade700 : Colors.green.shade700;

      return Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    stat.platform.label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '¥${FormatUtil.formatAmount(stat.marketValue)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    label: '今日盈亏',
                    value: FormatUtil.formatPnl(stat.dailyPnl, '¥'),
                    color: dailyColor,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    label: '累计盈亏',
                    value: FormatUtil.formatPnl(stat.totalPnl, '¥'),
                    color: totalColor,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    label: '收益率',
                    value: FormatUtil.formatPercent(stat.totalPnlPercent),
                    color: totalColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildDailyRanking(PortfolioSummary summary, ThemeData theme) {
    final details = List<PositionPnl>.of(summary.positionDetails);
    // 按今日涨跌幅排序（从大到小）
    details.sort((a, b) => b.dailyChangePercent.compareTo(a.dailyChangePercent));

    return details.map<Widget>((pnl) {
      final isUp = pnl.isDailyUp;
      final color = isUp ? Colors.red.shade700 : Colors.green.shade700;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              isUp ? Icons.trending_up : Icons.trending_down,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${pnl.name} (${pnl.symbol})',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${pnl.platform.label} · 持仓 ${FormatUtil.formatInt(pnl.quantity)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  FormatUtil.formatPercent(pnl.dailyChangePercent),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  FormatUtil.formatPnl(pnl.dailyPnlCny, '¥'),
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildPnlRanking(PortfolioSummary summary, ThemeData theme) {
    final details = List<PositionPnl>.of(summary.positionDetails);
    // 按人民币盈亏排序
    details.sort((a, b) => b.pnlCny.compareTo(a.pnlCny));

    return details.map<Widget>((pnl) {
      final pnlColor =
          pnl.isProfit ? Colors.red.shade700 : Colors.green.shade700;
      return ListTile(
        dense: true,
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${pnl.name} (${pnl.symbol})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${pnl.currencySymbol}${FormatUtil.formatAmount(pnl.currentPrice)}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${pnl.platform.label} | 持仓${FormatUtil.formatInt(pnl.quantity)}股 | 成本${pnl.currencySymbol}${FormatUtil.formatAmount(pnl.avgCost)}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              FormatUtil.formatPnl(pnl.pnlCny, '¥'),
              style: TextStyle(
                color: pnlColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              FormatUtil.formatPercent(pnl.pnlPercent),
              style: TextStyle(
                color: pnlColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

/// 平台卡片中的小数据格子
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatItem({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

/// 今日盈亏大卡片（重点突出展示）
class _DailyPnlHeroCard extends StatelessWidget {
  final double dailyPnl;
  final double dailyPnlPercent;
  final double totalMarketValue;

  const _DailyPnlHeroCard({
    required this.dailyPnl,
    required this.dailyPnlPercent,
    required this.totalMarketValue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUp = dailyPnl >= 0;
    final mainColor = isUp ? Colors.red.shade600 : Colors.green.shade600;
    final bgColor = isUp
        ? Colors.red.shade50
        : Colors.green.shade50;
    final darkMode = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: darkMode
              ? [mainColor.withValues(alpha: 0.25), mainColor.withValues(alpha: 0.1)]
              : [bgColor, Colors.white],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: mainColor.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: mainColor.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isUp ? Icons.trending_up : Icons.trending_down,
                color: mainColor,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                '今日盈亏',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: mainColor,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: mainColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  FormatUtil.formatPercent(dailyPnlPercent),
                  style: TextStyle(
                    color: mainColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                dailyPnl >= 0 ? '+' : '-',
                style: TextStyle(
                  color: mainColor,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '¥',
                style: TextStyle(
                  color: mainColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                FormatUtil.formatAmount(dailyPnl.abs()),
                style: TextStyle(
                  color: mainColor,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '当前总市值 ¥${FormatUtil.formatAmount(totalMarketValue)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
