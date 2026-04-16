import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// GitHub Releases 返回的版本信息
class ReleaseInfo {
  final String tagName; // 如 "v1.2.0"
  final String name; // 发布标题
  final String body; // changelog markdown
  final String htmlUrl; // GitHub release 页面
  final String? apkDownloadUrl; // APK 直链下载
  final DateTime publishedAt;

  ReleaseInfo({
    required this.tagName,
    required this.name,
    required this.body,
    required this.htmlUrl,
    required this.apkDownloadUrl,
    required this.publishedAt,
  });

  /// 去掉 v 前缀的纯版本号 "1.2.0"
  String get version => tagName.startsWith('v') ? tagName.substring(1) : tagName;

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    final assets = (json['assets'] as List? ?? []).cast<Map>();
    final apkAsset = assets
        .where((a) => (a['name'] as String?)?.endsWith('.apk') ?? false)
        .firstOrNull;
    return ReleaseInfo(
      tagName: json['tag_name'] as String,
      name: json['name'] as String? ?? json['tag_name'] as String,
      body: json['body'] as String? ?? '',
      htmlUrl: json['html_url'] as String,
      apkDownloadUrl: apkAsset?['browser_download_url'] as String?,
      publishedAt:
          DateTime.tryParse(json['published_at'] as String? ?? '') ??
              DateTime.now(),
    );
  }
}

/// 检查升级结果
class UpdateCheckResult {
  final String currentVersion; // 本地版本（不带 v）
  final String currentBuild; // 本地 build number
  final ReleaseInfo? latest; // GitHub 最新 release（无网/无发布时为 null）
  final bool hasUpdate;

  UpdateCheckResult({
    required this.currentVersion,
    required this.currentBuild,
    required this.latest,
    required this.hasUpdate,
  });
}

/// App 升级检查服务
class UpdateService {
  final Dio _dio;
  static const String _repo = 'liweing/stock-portfolio';

  UpdateService({Dio? dio}) : _dio = dio ?? Dio();

  /// 获取本地版本信息
  Future<({String version, String build})> getLocalVersion() async {
    final info = await PackageInfo.fromPlatform();
    return (version: info.version, build: info.buildNumber);
  }

  /// 检查 GitHub Releases 上是否有新版本
  Future<UpdateCheckResult> checkForUpdate() async {
    final local = await getLocalVersion();

    ReleaseInfo? latest;
    try {
      final response = await _dio.get(
        'https://api.github.com/repos/$_repo/releases/latest',
        options: Options(
          headers: {'Accept': 'application/vnd.github+json'},
          responseType: ResponseType.json,
          // 防止 GitHub 的 404（无 release）抛异常
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      if (response.statusCode == 200 && response.data is Map) {
        latest = ReleaseInfo.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (_) {
      // 网络失败：返回无更新
    }

    final hasUpdate = latest != null &&
        compareVersions(latest.version, local.version) > 0;

    return UpdateCheckResult(
      currentVersion: local.version,
      currentBuild: local.build,
      latest: latest,
      hasUpdate: hasUpdate,
    );
  }

  /// 语义化版本比较：返回 1 / 0 / -1
  /// 1.2.0 > 1.1.9, 1.0.10 > 1.0.9
  static int compareVersions(String a, String b) {
    final pa = _parseVersion(a);
    final pb = _parseVersion(b);
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final na = i < pa.length ? pa[i] : 0;
      final nb = i < pb.length ? pb[i] : 0;
      if (na > nb) return 1;
      if (na < nb) return -1;
    }
    return 0;
  }

  static List<int> _parseVersion(String v) {
    return v
        .replaceAll(RegExp(r'^v'), '')
        .split('.')
        .map((s) => int.tryParse(s.split('-').first) ?? 0)
        .toList();
  }
}
