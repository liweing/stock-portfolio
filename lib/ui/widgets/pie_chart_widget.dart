import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../models/portfolio_summary.dart';

/// 仓位分配饼图（点击扇区可放大并显示详情）
class AllocationPieChart extends StatefulWidget {
  final List<AllocationItem> items;
  final String title;

  const AllocationPieChart({
    super.key,
    required this.items,
    required this.title,
  });

  @override
  State<AllocationPieChart> createState() => _AllocationPieChartState();
}

class _AllocationPieChartState extends State<AllocationPieChart> {
  /// 当前选中的扇区索引（-1 表示未选中）
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.items.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('暂无数据')),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                widget.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '点击扇区查看详情',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 240,
          child: Row(
            children: [
              // 饼图（含中心标签）
              Expanded(
                flex: 3,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sections: _buildSections(),
                        centerSpaceRadius: 50,
                        sectionsSpace: 2,
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            // 只响应真正的点击确认事件：
                            // FlTapUpEvent（抬手结束点击）或 FlPanEndEvent（拖动结束）
                            // 忽略 hover / down 等中间事件，选中状态保持
                            final isConfirmTap =
                                event is FlTapUpEvent ||
                                event is FlPanEndEvent ||
                                event is FlLongPressEnd;
                            if (!isConfirmTap) return;

                            final idx =
                                response?.touchedSection?.touchedSectionIndex;
                            if (idx == null || idx < 0) return;

                            setState(() {
                              // 再次点同一块则取消，否则切换到新块
                              _touchedIndex =
                                  _touchedIndex == idx ? -1 : idx;
                            });
                          },
                        ),
                      ),
                    ),
                    // 中心展示选中扇区的详细信息
                    _buildCenterLabel(theme),
                  ],
                ),
              ),
              // 图例
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildLegend(theme),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildSections() {
    return widget.items.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final isTouched = index == _touchedIndex;
      // 选中扇区放大 + 字号变大 + 加阴影
      final radius = isTouched ? 64.0 : 50.0;
      final fontSize = isTouched ? 13.0 : 11.0;

      return PieChartSectionData(
        color: ChartColors.getColor(index),
        value: item.value,
        title: '${item.percentage.toStringAsFixed(1)}%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: const [Shadow(color: Colors.black45, blurRadius: 2)],
        ),
        titlePositionPercentageOffset: 0.6,
      );
    }).toList();
  }

  /// 中心区域：未选中显示提示，选中显示该扇区的详情
  Widget _buildCenterLabel(ThemeData theme) {
    if (_touchedIndex < 0 || _touchedIndex >= widget.items.length) {
      return const SizedBox.shrink();
    }
    final item = widget.items[_touchedIndex];
    final color = ChartColors.getColor(_touchedIndex);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      constraints: const BoxConstraints(maxWidth: 100),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            '¥${FormatUtil.formatAmount(item.value)}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
          ),
          Text(
            '${item.percentage.toStringAsFixed(1)}%',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildLegend(ThemeData theme) {
    return widget.items.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final isSelected = index == _touchedIndex;
      return InkWell(
        onTap: () => setState(() {
          _touchedIndex = isSelected ? -1 : index;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? ChartColors.getColor(index).withValues(alpha: 0.15)
                : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: ChartColors.getColor(index),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}
