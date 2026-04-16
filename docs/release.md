# 发布新版本指南

App 内置升级检查，依赖 **Vercel 上的 `/version.json`** 作为版本源（不是 GitHub）。
APK 也托管在 Vercel `/downloads/app-release.apk`。

## 1. 修改版本号

编辑 `pubspec.yaml`：
```yaml
version: 1.1.0+3
#       ↑     ↑
#    版本号  build 号（每次自增）
```

**SemVer 规则**：
- 重大改动：`1.0.0 → 2.0.0`
- 新功能：`1.0.0 → 1.1.0`
- Bug 修复：`1.0.0 → 1.0.1`

## 2. 构建 APK

```bash
export JAVA_HOME=/Users/bytedance/jdks/jdk-17.0.13+11/Contents/Home
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
export PATH=$JAVA_HOME/bin:$PATH:$ANDROID_HOME/cmdline-tools/latest/bin

flutter build apk --release
```

## 3. 复制 APK 到 Vercel 部署目录

```bash
cp build/app/outputs/flutter-apk/app-release.apk web/downloads/app-release.apk
cp build/app/outputs/flutter-apk/app-release.apk build/web/downloads/app-release.apk
```

## 4. 更新 `web/version.json`

```json
{
  "version": "1.1.0",
  "build": 3,
  "apkUrl": "https://stockportfolio.company/downloads/app-release.apk",
  "publishedAt": "2026-05-01T00:00:00Z",
  "changelog": "## 新功能\n- xxx\n\n## Bug 修复\n- yyy"
}
```

```bash
cp web/version.json build/web/version.json
```

## 5. 提交推送

```bash
git add -f web/downloads web/version.json build/web
git commit -m "Release v1.1.0"
git push
```

Vercel 自动部署（约 30 秒）。

## 6. 验证

```bash
curl https://stockportfolio.company/version.json
curl -I https://stockportfolio.company/downloads/app-release.apk
```

打开旧版 App：
- 右上角头像 → "检查更新"
- 应弹出 "发现新版本 1.1.0" 对话框
- 点"立即下载" → 跳浏览器下载新 APK

## 自动化（一行脚本，可选）

把上面 2-5 步打包成脚本：

```bash
# scripts/release.sh
#!/usr/bin/env bash
set -euo pipefail

VERSION=$1  # 如 1.1.0
BUILD=$2    # 如 3
CHANGELOG=$3  # 如 "新功能 xxx"

# 1. bump pubspec
sed -i '' "s/^version: .*/version: ${VERSION}+${BUILD}/" pubspec.yaml

# 2. build apk
flutter build apk --release

# 3. copy to web
mkdir -p web/downloads build/web/downloads
cp build/app/outputs/flutter-apk/app-release.apk web/downloads/app-release.apk
cp build/app/outputs/flutter-apk/app-release.apk build/web/downloads/app-release.apk

# 4. update version.json
cat > web/version.json <<EOF
{
  "version": "${VERSION}",
  "build": ${BUILD},
  "apkUrl": "https://stockportfolio.company/downloads/app-release.apk",
  "publishedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "changelog": ${CHANGELOG@Q}
}
EOF
cp web/version.json build/web/version.json

# 5. git
git add -f web/downloads web/version.json pubspec.yaml build/web
git commit -m "Release v${VERSION}"
git push
echo "✅ Released v${VERSION}+${BUILD}"
```

用法：
```bash
./scripts/release.sh 1.1.0 3 "修复了 xxx，新增 yyy"
```

## 注意事项

1. **APK 文件大小**：现在约 57MB。GitHub 推送对 50MB+ 文件会 warning（已忽略），100MB 是硬上限。
2. **版本号必须递增**：App 内对比是字符串比较，新版本号必须大于本地。
3. **publishedAt** 用 UTC 时间，ISO 8601 格式。
4. **changelog** 支持 markdown，但 App 内是纯文本展示（暂时）。

## 用户安装新 APK 流程

下载后：
1. 打开下载的 APK 文件
2. 系统弹出 "未知来源安装" 警告 → 允许
3. 替换安装（无需先卸载，签名相同）
4. 数据保留（持仓在云端）

## TODO

- [ ] App 内直接下载 APK + 触发安装（用 `app_installer` 包，需要 `REQUEST_INSTALL_PACKAGES` 权限）
- [ ] 启动时自动后台检查（每周一次）
- [ ] 强制升级标记（重大 Bug 时）
- [ ] CI 自动发布（push tag 触发）
