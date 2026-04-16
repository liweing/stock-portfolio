import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/services/update_service.dart';
import '../../providers/update_provider.dart';

/// 存在 SharedPreferences 里的 key：用户已选择"稍后"的版本 build 号
const _kDismissedBuildKey = 'update_dismissed_build';

/// 检查升级并根据情况弹窗
///
/// [manual] = true 时为用户主动点"检查更新"：
///   - 已是最新：SnackBar 提示
///   - 网络失败：SnackBar 提示
///   - 无视用户之前的"稍后"选择，发现新版就弹窗
///
/// [manual] = false 时为启动时自动检查：
///   - 静默失败（网络/已是最新）
///   - 用户之前点过"稍后"的同一 build 不再提示
Future<void> checkForUpdateWithDialog(
  BuildContext context,
  WidgetRef ref, {
  required bool manual,
}) async {
  // 手动检查时显示 loading dialog
  if (manual) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
  }

  UpdateCheckResult? result;
  try {
    result = await ref.read(updateServiceProvider).checkForUpdate();
  } catch (_) {
    // 网络错误等
  }

  if (!context.mounted) return;

  if (manual) {
    Navigator.of(context).pop(); // 关 loading dialog
  }

  // 检查失败
  if (result == null || result.latest == null) {
    if (manual) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('检查失败，请检查网络后重试')),
      );
    }
    return;
  }

  // 已是最新
  if (!result.hasUpdate) {
    if (manual) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已是最新版本 ${result.currentVersion}+${result.currentBuild}',
          ),
        ),
      );
    }
    return;
  }

  final latest = result.latest!;

  // 自动检查时尊重用户已跳过的版本
  if (!manual) {
    final prefs = await SharedPreferences.getInstance();
    final dismissedBuild = prefs.getInt(_kDismissedBuildKey) ?? 0;
    if (latest.build <= dismissedBuild) {
      // 用户已对该 build 或更新 build 点过"稍后"，不再打扰
      return;
    }
  }

  if (!context.mounted) return;
  final shouldUpdate = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('发现新版本 ${latest.version}+${latest.build}'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('当前版本：${result!.currentVersion}+${result.currentBuild}'),
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
    final url = latest.apkDownloadUrl ?? latest.htmlUrl;
    if (url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  } else {
    // 用户选择"稍后"：记住这个 build 号，下次启动不再打扰（直到有更新 build）
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kDismissedBuildKey, latest.build);
  }
}
