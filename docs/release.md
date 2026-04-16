# 发布新版本指南

App 内置升级检查功能，依赖 **GitHub Releases** 作为版本源。每次发新版本，需要：

## 1. 修改版本号

编辑 `pubspec.yaml`：
```yaml
version: 1.1.0+3
#       ↑     ↑
#    版本号  build 号（每次自增）
```

**版本号规则**（语义化版本 SemVer）：
- 主版本号.次版本号.修订号
- 重大改动：`1.0.0 → 2.0.0`
- 新功能：`1.0.0 → 1.1.0`
- Bug 修复：`1.0.0 → 1.0.1`

## 2. 构建 APK

```bash
export JAVA_HOME=/Users/bytedance/jdks/jdk-17.0.13+11/Contents/Home
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
export PATH=$JAVA_HOME/bin:$PATH:$ANDROID_HOME/cmdline-tools/latest/bin

flutter build apk --release
# 产出：build/app/outputs/flutter-apk/app-release.apk
```

## 3. 创建 GitHub Release（关键步骤）

### 方式 A：网页操作（推荐新手）

1. 访问 https://github.com/liweing/stock-portfolio/releases/new
2. **Tag**: `v1.1.0`（必须以 `v` 开头，且和 pubspec 版本号一致）
3. **Title**: `v1.1.0` 或 `1.1.0 - 功能更新`
4. **Description**: 写本版本的更新内容（用户在 App 里能看到）
   ```markdown
   ## 新功能
   - 新增按平台汇总盈亏
   - 持仓页支持下拉刷新

   ## Bug 修复
   - 修复港股价格精度问题
   - 修复基金 API 偶发 500 错误

   ## 性能优化
   - 优化首页加载速度
   ```
5. **Attach binary**: 上传 `build/app/outputs/flutter-apk/app-release.apk`
6. 点 **Publish release**

### 方式 B：命令行（gh CLI）

需要先安装 GitHub CLI：`brew install gh` 然后 `gh auth login`。

```bash
gh release create v1.1.0 \
  build/app/outputs/flutter-apk/app-release.apk \
  --title "v1.1.0" \
  --notes "## 新功能
- xxx
## Bug 修复
- yyy"
```

## 4. 验证

发布后，打开旧版 App：
- 右上角头像 → "检查更新"
- 应弹出 "发现新版本 1.1.0" 对话框
- 显示你写的 changelog
- 点"立即下载" → 跳到浏览器下载 APK

## 注意事项

1. **Tag 格式**：必须 `v1.1.0`（带 `v`）。App 会自动 strip 掉 `v` 比对版本号。
2. **APK 文件名**：必须以 `.apk` 结尾。App 会自动找 release 里的第一个 `.apk` 文件作为下载地址。
3. **多个 APK**：如果上传了多个 APK（如不同 ABI），App 只下载第一个。
4. **Pre-release**：勾选 "Set as a pre-release" 后，**App 不会检测到这个 release**（GitHub API `latest` 接口跳过 pre-release）。如果想推预发版，需要改 App 代码请求 `releases` 列表第一个。
5. **私有仓库**：不支持。GitHub API 对私有 release 需要 token，App 暂未实现。

## 升级机制工作原理

```
App 启动 / 用户点检查更新
  ↓
HTTP GET https://api.github.com/repos/liweing/stock-portfolio/releases/latest
  ↓
解析 tag_name (v1.1.0) 和 assets[*.apk].browser_download_url
  ↓
对比本地 PackageInfo.version (1.0.0)
  ↓
有新版 → 弹出 dialog → 用户点击 → 浏览器打开 APK 直链 → 用户手动安装
```

## 用户安装新 APK 流程

下载新 APK 后用户需要：
1. 打开下载的 APK 文件
2. 系统弹出 "未知来源安装" 警告 → 允许
3. 替换安装（无需先卸载旧版本，因签名相同）
4. 数据保留（持仓在云端，不受影响）

## TODO（未来改进）

- [ ] App 内直接下载 APK + 触发安装（用 `app_installer` 包，需要 `REQUEST_INSTALL_PACKAGES` 权限）
- [ ] 启动时自动后台检查（每周一次，避免烦扰）
- [ ] 强制升级标记（重大 Bug 时强制用户升级）
- [ ] 增量更新 / 热更新（用 Shorebird 等方案）
