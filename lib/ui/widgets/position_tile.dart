import 'package:flutter/material.dart';
import '../../core/utils.dart';
import '../../models/portfolio_summary.dart';

/// 持仓列表项
class PositionTile extends StatelessWidget {
  final PositionPnl pnl;
  final VoidCallback? onTap;

  const PositionTile({
    super.key,
    required this.pnl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A股用红涨绿跌
    final pnlColor = pnl.isProfit ? Colors.red.shade700 : Colors.green.shade700;

    return ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // 做空徽章
                      if (pnl.isShort) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.green.shade700.withValues(alpha: 0.15),
                            border: Border.all(
                              color: Colors.green.shade700,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '空',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.green.shade700,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          pnl.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        pnl.symbol,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          pnl.platform.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (pnl.isEstimated) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          '估',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onTertiaryContainer,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      '${pnl.currencySymbol}${FormatUtil.formatAmount(pnl.currentPrice)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${FormatUtil.formatPnl(pnl.pnl, pnl.currencySymbol)} (${FormatUtil.formatPercent(pnl.pnlPercent)})',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: pnlColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _quantityLabel(pnl),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${pnl.isShort ? "开仓" : "成本"} ${pnl.currencySymbol}${FormatUtil.formatAmount(pnl.avgCost)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    '市值 ${pnl.currencySymbol}${FormatUtil.formatAmount(pnl.marketValue)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const Spacer(),
                  if (pnl.currency != 'CNY')
                    Text(
                      '≈ ¥${FormatUtil.formatAmount(pnl.marketValueCny)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
  }

  String _quantityLabel(PositionPnl p) {
    final qty = FormatUtil.formatInt(p.quantity);
    final unit = p.market.isFund
        ? '份'
        : p.market.isFutures
            ? '手'
            : '股';
    final action = p.isShort ? '卖空' : '持仓';
    return '$action $qty $unit';
  }
}
