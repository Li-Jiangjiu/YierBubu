# 开发与构建指南

普通用户直接从 [README 顶部](README.md) 下载安装包。以下只面向想修改程序的开发者。

## 获取源码

```sh
git clone https://github.com/Li-Jiangjiu/YierBubu.git
cd YierBubu
```

Mac 实现在根目录 `Sources` / `Tests` / `Package.swift`；Windows 在 `windows`。它们共享相同画面与交互目标，但分别使用原生系统接口，不是同一二进制跨平台运行。源码不含私人开发历史、诊断报告和角色图片。

## Mac：Swift 6 + AppKit

需要 macOS 14或更新、支持 Swift 6 的 Xcode 或 Command Line Tools，以及 Python 3 标准库。所有命令在仓库根目录执行：

```sh
# 核心测试及编译（不需要角色素材）
bash scripts/swift-tool.sh test
# 准备画面：下载固定 Mac 测试版 ZIP，先校验 SHA256，再只提取三张 PNG 和 ICNS
python3 scripts/prepare-macos-assets.py
# 已经下载过 ZIP 时可离线提取
# python3 scripts/prepare-macos-assets.py --archive /path/to/YierBubu-macOS-Universal-v0.4.0-beta.3.zip
python3 -m unittest discover -s scripts/tests -p 'test_*.py' -v
bash scripts/check-release-toolchain.sh
bash scripts/build-universal.sh --work-dir output/releases/my-build
bash scripts/package-release.sh --version 0.4.0-beta.4 --build 8 \
  --bundle-id local.yierbubu.desktop \
  --binary output/releases/my-build/bin/BubuDesktop \
  --output output/releases/my-app --unnotarized-beta
bash scripts/verify-release.sh output/releases/my-app/BETA-UNNOTARIZED/YierBubu.app
```

示例 beta.4/build8 只是你自己的下一次构建，并非已发布新版。生成的 App 位于 `output/releases/my-app/BETA-UNNOTARIZED/YierBubu.app`，复制到应用程序后，按安装说明开启输入监控。免费签名构建使用内容独立的权限标识，每次内容变化需重新授权。

输出目录必须全新；重复执行请换目录名称。不要用旧 `build-app.sh` 覆盖日常使用的 `dist` App，它是早期本机开发入口。Universal 发布、窗口冒烟和制作下载包见 [Mac 发布流程](docs/release-process.md)。图形冒烟不验证真实全局输入，真实监听仍须人工按键并查看计数。

原图标的1024px制作源图未放入 Git；固定 ICNS 足够正常打包。`build-icon.sh` 是制作自有图标的可选工具，需要自己提供 `Resources/Icon/app-icon.png`，普通构建不需要执行它。

## Windows：.NET 10 + WPF

构建 WPF 程序需要 Windows、.NET 10 SDK、Python 3、PowerShell 7。核心测试可以在 macOS/Linux/Windows 上运行：

```sh
dotnet run --project windows/YierBubu.Tests -c Release
python -m unittest discover -s windows/tests -v
```

在 Windows 的 PowerShell 7 中，从仓库根目录执行：

```powershell
# 自动下载、校验并准备素材与 ICO，再发布自包含 win-x64 程序
./windows/scripts/build.ps1 -Output windows/artifacts/publish
# 独立发布 x64 桌面冒烟程序，ARM64 主机也使用同一个 x64 程序进行验证
dotnet publish windows/YierBubu.Smoke -c Release -r win-x64 --self-contained true -o windows/artifacts/smoke-x64
$env:SOURCE_COMMIT = git rev-parse HEAD
& ./windows/artifacts/smoke-x64/YierBubu.Smoke.exe windows/artifacts/evidence
if ($LASTEXITCODE -ne 0) { throw 'Desktop smoke failed' }
./windows/scripts/package.ps1 -PublishDir windows/artifacts/publish -Output windows/artifacts/release -SmokeResult windows/artifacts/evidence/result.json -SourceCommit $env:SOURCE_COMMIT
```

输出的 ZIP 包含运行时，使用者不需 .NET SDK。打包前需要可用图形桌面；焦点检查受托管桌面限制时会明确记录未验证，不能代替实体键鼠验收。详见 [Windows 开发说明](windows/README.md) 和 [验证记录](docs/windows/verification.md)。

## 素材、测试与发布

两端素材工具只从固定版本的公开 Mac ZIP 恢复资源，并检查 SHA256，不执行下载的 App；应用本身运行时不联网。角色素材与图标不属于 MIT。若改成自己的角色，需同时调整素材校验、相应尺寸/布局和测试，不能简单更换为任意大小图片。

GitHub Actions 分别测试 Mac 双架构构建和 Windows 桌面程序。CI 通过不代表所有用户系统、DPI、芯片和真实输入均已验收。打包脚本会保留未签名/未公证标识；不得把测试包冒充官方或稳定版。

历史 `export-public-source.sh` 是 Mac 代码导出工具，不是完整双平台仓库备份。继续开发请使用 Git 克隆或 GitHub 主分支源码归档，并保留本指南、Windows 目录和各自 CI。现有发布标签的自动源码归档早于本次整理，具体对应关系见 [说明](docs/source-and-releases.md)。
