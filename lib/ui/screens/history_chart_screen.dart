import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/utils.dart';
import '../../data/repositories/snapshot_repository.dart';
import '../../providers/database_provider.dart';

/// 时间范围
enum ChartRange {
  week('7D', 7),
  month('1M', 30),
  quarter('3M', 90),
  halfYear('6M', 180),
  year('1Y', 365),
  all('全部', 0);

  final String label;
  final int days;
  const ChartRange(this.label, this.days);
}

/// 显示指标
enum ChartMetric {
  marketValue('总市值'),
  pnl('累计盈亏'),
  returnPct('收益率 %'),
  dailyPnl('每日盈亏');

  final String label;
  const ChartMetric(this.label);
}

class HistoryChartScreen extends ConsumerStatefulWidget {
  const HistoryChartScreen({super.key});

  @override
  ConsumerState<HistoryChartScreen> createState() =>
      _HistoryChartScreenState();
}

class _HistoryChartScreenState extends ConsumerState<HistoryChartScreen> {
  ChartRange _range = ChartRange.month;
  ChartMetric _metric = ChartMetric.pnl;
  List<PortfolioSnapshot> _snapshots = [];
  bool _loading = true;
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(snapshotRepositoryProvider);
      List<PortfolioSnapshot> data;
      if (_range == ChartRange.all) {
        data = await repo.getAllSnapshots();
      } else {
        final now = DateTime.now();
        final from = now.subtract(Duration(days: _range.days));
        data = await repo.getSnapshots(from: from, to: now);
      }
      if (mounted) setState(() => _snapshots = data);
    } catch (_) {
      // 静默
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _getValue(PortfolioSnapshot s) {
    switch (_metric) {
      case ChartMetric.marketValue:
        return s.totalMarketValue;
      case ChartMetric.pnl:
        return s.totalPnl;
      case ChartMetric.returnPct:
        return s.returnPercent;
      case ChartMetric.dailyPnl:
        return s.dailyPnl;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('收益走势'),
      ),
      body: Column(
        children: [
          // 指标切换
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<ChartMetric>(
              showSelectedIcon: false,
              segments: ChartMetric.values
                  .map((m) => ButtonSegment(value: m, label: Text(m.label)))
                  .toList(),
              selected: {_metric},
              onSelectionChanged: (s) => setState(() => _metric = s.first),
            ),
          ),

          // 时间范围
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: ChartRange.values.map((r) {
                final selected = r == _range;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: ChoiceChip(
                    label: Text(r.label),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _range = r);
                      _loadData();
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),

          // 选中点的数据卡
          if (_touchedIndex >= 0 && _touchedIndex < _snapshots.length)
            _buildSelectedInfo(theme),

          // 图表
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _snapshots.length < 2
                    ? _buildEmptyState(theme)
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 24, 16),
                        child: _buildChart(theme),
                      ),
          ),

          // 底部汇总
          if (_snapshots.isNotEmpty) _buildSummary(theme),
        ],
      ),
    );
  }

  Widget _buildSelectedInfo(ThemeData theme) {
    final s = _snapshots[_touchedIndex];
    final value = _getValue(s);
    final isPositive = value >= 0;
    final color =
        _metric == ChartMetric.marketValue
            ? null
            : isPositive
                ? Colors.red.shade700
                : Colors.green.shade700;
    final dateStr = DateFormat('yyyy-MM-dd').format(s.date);

    String valueStr;
    if (_metric == ChartMetric.returnPct) {
      valueStr = FormatUtil.formatPercent(value);
    } else {
      valueStr = '¥${FormatUtil.formatAmount(value)}';
      if (_metric != ChartMetric.marketValue) {
        valueStr = '${value >= 0 ? "+" : "-"}¥${FormatUtil.formatAmount(value.abs())}';
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(dateStr, style: theme.textTheme.bodySmall),
          const Spacer(),
          Text(
            valueStr,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(ThemeData theme) {
    final spots = _snapshots.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), _getValue(e.value));
    }).toList();

    final values = spots.map((s) => s.y).toList();
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final range = (maxY - minY).abs();
    final padding = range * 0.1;

    // 判断整体走势颜色
    final isUp = spots.last.y >= spots.first.y;
    final lineColor = isUp ? Colors.red.shade400 : Colors.green.shade400;
    final gradientColor = isUp
        ? [Colors.red.shade400.withValues(alpha: 0.3), Colors.red.shade400.withValues(alpha: 0)]
        : [Colors.green.shade400.withValues(alpha: 0.3), Colors.green.shade400.withValues(alpha: 0)];

    return LineChart(
      LineChartData(
        minY: minY - padding,
        maxY: maxY + padding,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: range > 0 ? range / 4 : 1,
          getDrawingHorizontalLine: (v) => FlLine(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            strokeWidth: 0.5,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (v, meta) {
                if (_metric == ChartMetric.returnPct) {
                  return Text(
                    '${v.toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 10),
                  );
                }
                if (v.abs() >= 10000) {
                  return Text(
                    '${(v / 10000).toStringAsFixed(1)}万',
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return Text(
                  v.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: (_snapshots.length / 5).ceilToDouble().clamp(1, 999),
              getTitlesWidget: (v, meta) {
                final idx = v.toInt();
                if (idx < 0 || idx >= _snapshots.length) {
                  return const SizedBox.shrink();
                }
                return Text(
                  DateFormat('MM/dd').format(_snapshots[idx].date),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchCallback: (event, response) {
            if (event is FlTapUpEvent || event is FlPanEndEvent) {
              final idx = response?.lineBarSpots?.first.spotIndex;
              if (idx != null) {
                setState(() => _touchedIndex = idx);
              }
            }
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Colors.transparent,
            getTooltipItems: (_) => [null],
          ),
          getTouchedSpotIndicator: (data, indices) {
            return indices.map((i) {
              return TouchedSpotIndicatorData(
                FlLine(color: lineColor, strokeWidth: 1, dashArray: [4, 4]),
                FlDotData(
                  show: true,
                  getDotPainter: (spot, pct, bar, i) => FlDotCirclePainter(
                    radius: 5,
                    color: lineColor,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  ),
                ),
              );
            }).toList();
          },
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.2,
            color: lineColor,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: gradientColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(ThemeData theme) {
    final first = _snapshots.first;
    final last = _snapshots.last;
    final periodReturn = last.totalPnl - first.totalPnl;
    final periodReturnPct = first.totalMarketValue > 0
        ? (periodReturn / first.totalMarketValue) * 100
        : 0.0;
    final isUp = periodReturn >= 0;
    final color = isUp ? Colors.red.shade700 : Colors.green.shade700;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.dividerColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          _SummaryItem(
            label: '区间盈亏',
            value: FormatUtil.formatPnl(periodReturn, '¥'),
            color: color,
          ),
          _SummaryItem(
            label: '区间收益率',
            value: FormatUtil.formatPercent(periodReturnPct),
            color: color,
          ),
          _SummaryItem(
            label: '数据天数',
            value: '${_snapshots.length} 天',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.show_chart, size: 64, color: Colors.grey.shade500),
          const SizedBox(height: 16),
          Text(
            '数据不足',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          Text(
            '每天刷新行情会自动记录快照\n至少需要 2 天数据才能绘制曲线',
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _SummaryItem({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
