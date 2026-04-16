import 'package:flutter_test/flutter_test.dart';
import 'package:stock_portfolio/data/services/update_service.dart';

void main() {
  group('UpdateService.compareVersions', () {
    test('相等返回 0', () {
      expect(UpdateService.compareVersions('1.0.0', '1.0.0'), 0);
      expect(UpdateService.compareVersions('v1.0.0', '1.0.0'), 0);
    });

    test('a > b 返回 1', () {
      expect(UpdateService.compareVersions('1.2.0', '1.1.9'), 1);
      expect(UpdateService.compareVersions('2.0.0', '1.9.9'), 1);
      expect(UpdateService.compareVersions('1.0.10', '1.0.9'), 1);
    });

    test('a < b 返回 -1', () {
      expect(UpdateService.compareVersions('1.0.0', '1.0.1'), -1);
      expect(UpdateService.compareVersions('1.0.9', '1.0.10'), -1);
    });

    test('支持 v 前缀', () {
      expect(UpdateService.compareVersions('v1.2.0', 'v1.1.9'), 1);
    });

    test('段数不同时正确比较', () {
      expect(UpdateService.compareVersions('1.0', '1.0.0'), 0);
      expect(UpdateService.compareVersions('1.0', '1.0.1'), -1);
      expect(UpdateService.compareVersions('1.1', '1.0.9'), 1);
    });

    test('支持预发布标签（- 后视为同版本）', () {
      // 1.0.0-beta 视为 1.0.0
      expect(UpdateService.compareVersions('1.0.0-beta', '1.0.0'), 0);
    });
  });

  group('ReleaseInfo.fromJson', () {
    test('解析含 APK asset 的 release', () {
      final json = {
        'tag_name': 'v1.2.0',
        'name': '1.2.0 Release',
        'body': '修复了一些 bug',
        'html_url': 'https://github.com/foo/bar/releases/tag/v1.2.0',
        'published_at': '2026-04-15T12:00:00Z',
        'assets': [
          {
            'name': 'app-release.apk',
            'browser_download_url':
                'https://github.com/foo/bar/releases/download/v1.2.0/app-release.apk',
          },
        ],
      };
      final r = ReleaseInfo.fromJson(json);
      expect(r.tagName, 'v1.2.0');
      expect(r.version, '1.2.0');
      expect(r.body, '修复了一些 bug');
      expect(r.apkDownloadUrl, contains('app-release.apk'));
    });

    test('无 APK 时 apkDownloadUrl 为 null', () {
      final json = {
        'tag_name': 'v1.0.0',
        'name': '1.0.0',
        'body': '',
        'html_url': 'https://github.com/foo/bar/releases/tag/v1.0.0',
        'published_at': '2026-04-15T12:00:00Z',
        'assets': [],
      };
      final r = ReleaseInfo.fromJson(json);
      expect(r.apkDownloadUrl, isNull);
    });

    test('忽略非 APK 的 asset', () {
      final json = {
        'tag_name': 'v1.0.0',
        'name': '1.0.0',
        'body': '',
        'html_url': 'https://github.com/foo/bar/releases/tag/v1.0.0',
        'published_at': '2026-04-15T12:00:00Z',
        'assets': [
          {
            'name': 'source.zip',
            'browser_download_url': 'https://example.com/source.zip',
          },
        ],
      };
      final r = ReleaseInfo.fromJson(json);
      expect(r.apkDownloadUrl, isNull);
    });
  });
}
