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
      expect(UpdateService.compareVersions('1.0.0-beta', '1.0.0'), 0);
    });
  });

  group('ReleaseInfo.fromJson', () {
    test('正常解析 version.json', () {
      final json = {
        'version': '1.2.0',
        'build': 5,
        'apkUrl': 'https://example.com/app.apk',
        'changelog': '修复了一些 bug',
        'publishedAt': '2026-04-15T12:00:00Z',
      };
      final r = ReleaseInfo.fromJson(json);
      expect(r.version, '1.2.0');
      expect(r.build, 5);
      expect(r.apkUrl, 'https://example.com/app.apk');
      expect(r.body, '修复了一些 bug');
      expect(r.tagName, 'v1.2.0');
    });

    test('缺失字段时使用默认值', () {
      final json = {'version': '1.0.0'};
      final r = ReleaseInfo.fromJson(json);
      expect(r.version, '1.0.0');
      expect(r.build, 0);
      expect(r.apkUrl, '');
      expect(r.body, '');
    });

    test('build 字段支持 string 类型 number', () {
      final json = {'version': '1.0.0', 'build': 10};
      final r = ReleaseInfo.fromJson(json);
      expect(r.build, 10);
    });
  });
}
