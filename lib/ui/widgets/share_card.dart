import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils.dart';
import '../../models/portfolio_summary.dart';

/// 分享持仓卡片 Widget（用于截图生成图片）
class ShareCardContent extends StatelessWidget {
  final PortfolioSummary summary;

  const ShareCardContent({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy/MM/dd').format(DateTime.now());
    final pnlColor =
        summary.totalPnl >= 0 ? const Color(0xFFFF6B6B) : const Color(0xFF51CF66);
    final dailyPnlColor =
        summary.dailyPnl >= 0 ? const Color(0xFFFF6B6B) : const Color(0xFF51CF66);

    // Top 5 positions by market value
    final topPositions = List<PositionPnl>.from(summary.positionDetails)
      ..sort((a, b) => b.marketValueCny.compareTo(a.marketValueCny));
    final displayPositions = topPositions.take(5).toList();

    return Container(
      width: 380,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F1429), Color(0xFF1A1E3A), Color(0xFF0D1B2A)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.show_chart, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                const Text(
                  '持仓助手',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                ),
                const Spacer(),
                Text(
                  dateStr,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    fontWeight: FontWeight.normal,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Total market value
            const Text(
              '总市值 (CNY)',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
                fontWeight: FontWeight.normal,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '¥${FormatUtil.formatAmount(summary.totalMarketValue)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 16),

            // P&L row
            Row(
              children: [
                Expanded(
                  child: _MetricBlock(
                    label: '累计盈亏',
                    value: FormatUtil.formatPnl(summary.totalPnl, '¥'),
                    sub: FormatUtil.formatPercent(summary.totalPnlPercent),
                    color: pnlColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _MetricBlock(
                    label: '今日盈亏',
                    value: FormatUtil.formatPnl(summary.dailyPnl, '¥'),
                    sub: FormatUtil.formatPercent(summary.dailyPnlPercent),
                    color: dailyPnlColor,
                  ),
                ),
              ],
            ),

            if (displayPositions.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(height: 1, color: const Color(0xFF1E293B)),
              const SizedBox(height: 16),

              // Holdings header
              Row(
                children: [
                  const Text(
                    '持仓明细',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '共 ${summary.positionDetails.length} 只',
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Holdings list
              ...displayPositions.map((p) => _HoldingRow(pnl: p)),

              if (summary.positionDetails.length > 5)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: Text(
                      '... 等 ${summary.positionDetails.length} 只持仓',
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
            ],

            const SizedBox(height: 20),
            Container(height: 1, color: const Color(0xFF1E293B)),
            const SizedBox(height: 16),

            // Footer
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.show_chart, color: Colors.white, size: 14),
                ),
                const SizedBox(width: 8),
                const Text(
                  'stockportfolio.company',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    decoration: TextDecoration.none,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF1E293B)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '扫码下载',
                    style: TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 11,
                      fontWeight: FontWeight.normal,
                      decoration: TextDecoration.none,
                    ),
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

class _MetricBlock extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;

  const _MetricBlock({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 12,
            fontWeight: FontWeight.normal,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          sub,
          style: TextStyle(
            color: color.withAlpha(180),
            fontSize: 13,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}

class _HoldingRow extends StatelessWidget {
  final PositionPnl pnl;

  const _HoldingRow({required this.pnl});

  @override
  Widget build(BuildContext context) {
    final pnlColor =
        pnl.isProfit ? const Color(0xFFFF6B6B) : const Color(0xFF51CF66);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pnl.name,
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  pnl.symbol,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 11,
                    fontWeight: FontWeight.normal,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                FormatUtil.formatPnl(pnl.pnlCny, '¥'),
                style: TextStyle(
                  color: pnlColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: pnlColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  FormatUtil.formatPercent(pnl.pnlPercent),
                  style: TextStyle(
                    color: pnlColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 显示分享卡片预览弹窗
Future<void> showShareCardBottomSheet(
    BuildContext context, PortfolioSummary summary) async {
  final screenshotController = ScreenshotController();

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ShareCardSheet(
      summary: summary,
      screenshotController: screenshotController,
    ),
  );
}

class _ShareCardSheet extends StatelessWidget {
  final PortfolioSummary summary;
  final ScreenshotController screenshotController;

  const _ShareCardSheet({
    required this.summary,
    required this.screenshotController,
  });

  Future<void> _shareImage(BuildContext context) async {
    try {
      final Uint8List? imageBytes = await screenshotController.capture(
        pixelRatio: 3.0,
        delay: const Duration(milliseconds: 100),
      );
      if (imageBytes == null) return;

      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/portfolio_share_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(imageBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '我的持仓收益 — 持仓助手 stockportfolio.company',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF374151),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Screenshot target
          Screenshot(
            controller: screenshotController,
            child: ShareCardContent(summary: summary),
          ),
          const SizedBox(height: 24),

          // Share button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _shareImage(context),
              icon: const Icon(Icons.share, size: 20),
              label: const Text('分享到...', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
