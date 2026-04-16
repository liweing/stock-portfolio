import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 远端版本元数据（从 Vercel 上的 version.json 拉取）
class ReleaseInfo {
  final String version; // 如 "1.0.0"
  final int build;
  final String apkUrl;
  final String changelog;
  final DateTime publishedAt;

  ReleaseInfo({
    required this.version,
    required this.build,
    required this.apkUrl,
    required this.changelog,
    required this.publishedAt,
  });

  /// 兼容字段（用于显示）
  String get tagName => 'v$version';
  String get name => 'v$version';
  String get body => changelog;
  String get htmlUrl => apkUrl;
  String? get apkDownloadUrl => apkUrl;

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) => ReleaseInfo(
        version: json['version'] as String,
        build: (json['build'] as num?)?.toInt() ?? 0,
        apkUrl: json['apkUrl'] as String? ?? '',
        changelog: json['changelog'] as String? ?? '',
        publishedAt:
            DateTime.tryParse(json['publishedAt'] as String? ?? '') ??
                DateTime.now(),
      );
}

/// 检查升级结果
class UpdateCheckResult {
  final String currentVersion; // 本地版本（不带 v）
  final String currentBuild; // 本地 build number
  final ReleaseInfo? latest;
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
  static const String _versionUrl =
      'https://stock-portfolio-topaz.vercel.app/version.json';

  UpdateService({Dio? dio}) : _dio = dio ?? Dio();

  /// 获取本地版本信息
  Future<({String version, String build})> getLocalVersion() async {
    final info = await PackageInfo.fromPlatform();
    return (version: info.version, build: info.buildNumber);
  }

  /// 检查 Vercel 上 version.json 是否有新版本
  Future<UpdateCheckResult> checkForUpdate() async {
    final local = await getLocalVersion();

    ReleaseInfo? latest;
    try {
      final response = await _dio.get(
        '$_versionUrl?t=${DateTime.now().millisecondsSinceEpoch}',
        options: Options(
          responseType: ResponseType.json,
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
