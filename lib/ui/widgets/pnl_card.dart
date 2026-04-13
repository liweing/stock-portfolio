import 'package:flutter/material.dart';
import '../../core/utils.dart';

/// 盈亏汇总卡片
class PnlSummaryCard extends StatelessWidget {
  final double totalMarketValue;
  final double totalCost;
  final double totalPnl;
  final double totalPnlPercent;

  const PnlSummaryCard({
    super.key,
    required this.totalMarketValue,
    required this.totalCost,
    required this.totalPnl,
    required this.totalPnlPercent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pnlColor = totalPnl >= 0 ? Colors.red.shade700 : Colors.green.shade700;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '投资组合总览',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '以 ¥ 人民币计',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _InfoItem(
                    label: '总市值',
                    value: '¥${FormatUtil.formatAmount(totalMarketValue)}',
                  ),
                ),
                Expanded(
                  child: _InfoItem(
                    label: '总成本',
                    value: '¥${FormatUtil.formatAmount(totalCost)}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _InfoItem(
                    label: '总盈亏',
                    value: FormatUtil.formatPnl(totalPnl, '¥'),
                    valueColor: pnlColor,
                  ),
                ),
                Expanded(
                  child: _InfoItem(
                    label: '收益率',
                    value: FormatUtil.formatPercent(totalPnlPercent),
                    valueColor: pnlColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoItem({
    required this.label,
    required this.value,
    this.valueColor,
  });

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
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
