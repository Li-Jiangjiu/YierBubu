# macOS 14 Universal 测试版发布流程

首版目标：macOS 14 及以上、arm64 + x86_64、免费未公证测试版。使用者无需开发环境。构建者需要支持 Swift 6 的 Apple 工具链和 Python 3 标准库；现有 CLT 已完成实际双架构链接，无需为了此目标安装完整 Xcode。

先按 [开发指南](../DEVELOPMENT.md) 准备运行素材。下列 beta.3/build7 命令是历史发布范例，继续开发请使用自己的版本、构建号和全新输出目录；不要覆盖现有发布包。

## 生成真实 Universal App

所有输出使用 output/releases 内的新目录，禁止覆盖已有目录或使用软链接。不要为了发布运行会覆盖日常 dist 的旧 build-app.sh。

```bash
bash scripts/swift-tool.sh test
python3 -m unittest discover -s scripts/tests -p 'test_release.py' -v
bash scripts/check-release-toolchain.sh
bash scripts/build-universal.sh --work-dir output/releases/build-beta
bash scripts/package-release.sh --version 0.4.0-beta.3 --build 7 \
  --bundle-id local.yierbubu.desktop \
  --binary output/releases/build-beta/bin/BubuDesktop \
  --output output/releases/app-beta --unnotarized-beta
bash scripts/verify-release.sh output/releases/app-beta/BETA-UNNOTARIZED/YierBubu.app
```

最低系统由 Package、编译 triple、Mach-O 校验与 plist 一致约束为 14.0。预检实际编译链接两个架构，不检查不再需要的 macOS 11 回部署库。构建在项目下隔离所有缓存和 SwiftPM 配置，避免受限环境写入用户缓存失败后误报 SDK 错误。

Developer ID 渠道的 Bundle ID 沿用传入标识；免费 beta 渠道把传入标识作为基础，在签名前生成基于构建号和包内容指纹的独立 Bundle ID，签名使用同一新标识。不自动启动候选包，不修改原有输入监控授权。版本 build 7；完整 beta 标识另存于 YierBubuReleaseVersion。ad-hoc 签名没有跨版本稳定的开发者身份，用户更新后可能需要重新授权。

不传 --unnotarized-beta 时，ad-hoc 包仍为 INTERNAL，不能通过测试版分发入口。传 Developer ID identity 的流程独立保留，当前测试版不使用它。

## 验证和下载包

```bash
arch -arm64 output/releases/app-beta/BETA-UNNOTARIZED/YierBubu.app/Contents/MacOS/BubuDesktop \
  --smoke-test --smoke-output output/releases/verify-beta/arm64
arch -x86_64 output/releases/app-beta/BETA-UNNOTARIZED/YierBubu.app/Contents/MacOS/BubuDesktop \
  --smoke-test --smoke-output output/releases/verify-beta/x86_64
bash scripts/make-beta-release.sh output/releases/app-beta/BETA-UNNOTARIZED/YierBubu.app \
  --output output/releases/v0.4.0-beta.3
```

原生窗口测试需要 macOS 图形会话；--smoke-test 不申请真实输入权限。Rosetta 是 Intel 二进制兼容运行验证，不代表实体 Intel 或 macOS 14 已测试。真实输入验收需用户在对应机器按实际键鼠并观察计数。

make-beta-release 会复制完整 App，附安装/隐私/素材说明，制作并解压验证 ZIP，制作并验证 DMG。--zip-only 可用于无磁盘镜像能力的自动检查，实际交付同时提供 ZIP 和 DMG。输出 App、说明、校验值及 RELEASE-INFO.json 均明确未公证。挂载 DMG 后仍要验证实际镜像内容，不能只验证输入文件夹。

## 对应源码

```bash
bash scripts/export-public-source.sh --output output/releases/source-code-only
bash scripts/export-public-source.sh --output output/releases/source-with-artwork --include-artwork
```

默认不含角色图；第二条会复制三张本地运行 PNG 及主图和 ICNS 图标，便于核对完整对应源码，但不会授予或宣称拥有角色再分发权。原作参考图、内部交接、完整历史、个人路径、构建缓存不导出。包含素材的源码可以独立构建并加载完整角色；纯代码导出会显示素材缺失，不能伪装成完整成品。

源码代码 MIT，素材权利独立。角色原作黄小B，非官方；当前角色公开分发授权尚未确认。本地生成安装文件不代表已获得公开素材授权，不自动上传文件。

## GitHub 组织方式

仓库放整理后的源码和文档，Releases 放 App ZIP、DMG、源码 ZIP（按许可范围选择）和 SHA256。用户无需先登录 GitHub，才能在本地制作这些文件；实际上传需维护者登录并选择目标仓库。

正式 Developer ID 签名公证仍可用 package-release.sh --identity 和 notarize-release.sh；那是后续独立发布方式，不是本免费测试版已完成的能力。

## App 图标

`Resources/Icon/app-icon.png` 为 1024 像素主图，运行 `bash scripts/build-icon.sh` 重建多尺寸 `YierBubu.icns`。发布打包会将 ICNS 放入 App 的 Contents/Resources，并设置 CFBundleIconFile；图标缺失或容器损坏会阻止校验通过。图标在签名前复制，源码导出仅在 --include-artwork 时包含角色图标。

## 免费 beta 权限身份规则（beta.3 起）

禁止用同一共用 Bundle ID 分发内容不同的 ad-hoc beta；macOS TCC 可能继续用旧 CDHash 校验。打包先使用基础 ID 写入 plist、复制全部资源和运行库、修正二进制，再对完整内容清单求 SHA256，实际 ID 为基础 ID + .beta.b构建号.h指纹前32位；之后才写入最终 ID 并签名。因此相同构建号但程序变化也不会复用旧授权身份。校验要求策略元数据、独立 ID 格式、两架构签名 Identifier 与 plist 一致；元数据写入发布说明和 RELEASE-INFO。未来更改派生算法必须更新策略版本。

这是一种要求重新授权的测试版隔离策略，不是稳定签名替代品；每次发布提醒退出旧版、安装新版本后单独授权。正式签名渠道保持固定 ID，由签名证书维护身份，未更改指定要求。不要使用只校验名称的宽松指定要求伪造稳定签名。
