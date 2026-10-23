# 一二布布 Windows 版

个人非营利、免费、非官方的 Windows 桌面陪伴程序。目标 Windows 10 / Windows 11 x64，Intel 与 AMD 使用同一便携 ZIP。建议已更新的 Windows 10 22H2 或 Windows 11；不承诺全部历史 Windows 10 版本。ARM64/32位不在首版范围。

保持批准的左布布鼠标、右一二键盘构图，36个主区数字和字母键随物理位置反馈；支持多键/键鼠并行、左右中键/双轴滚动、75/100/125%大小、拖动、穿透、显示/隐藏、恢复位置、演示、状态计数和退出。入口在右下角托盘，默认不显示任务栏主窗口。

## 使用与验证范围

[直接下载 Windows ZIP](https://github.com/Li-Jiangjiu/YierBubu/releases/download/v0.5.0-beta.1-windows/YierBubu-Windows-x64-v0.5.0-beta.1.zip) · [双平台下载与主说明](../README.md) · [完整开发指南](../DEVELOPMENT.md)

维护者随后已在自己的 Windows 台式机运行并反馈可用，具体系统和 CPU 未补充；这是原有云端记录之外的后续反馈。

下载和打开步骤见 [INSTALL.md](INSTALL.md)。运行包完整包含.NET运行时，用户不需要开发环境。未商业签名，可能出现发布者/SmartScreen提示；不建议关闭安全保护。

WindowsServer2022/2025及Windows11 ARM上的x64模拟运行均已通过云端检查，包含68项核心测试、50项固定桌面/绘图检查通过（另1项焦点按环境记录通过或未验证）。这些不能替代Windows10/11实体输入、DPI多屏、睡眠唤醒或Intel/AMD分别验收。详细技术路线见 [分步执行文档](../docs/windows/technical-route.md)。以 [验证记录](../docs/windows/verification.md) 和每个包的RELEASE-INFO为准；开发分支不意味着稳定发布。

## 源码与构建

C# / .NET 10 LTS / WPF / Win32 Raw Input / WinForms NotifyIcon，无第三方应用框架。核心状态、键位、几何和姿势在`YierBubu.Core`，Windows窗口和系统适配在`YierBubu.Windows`。输入只读、不拦截，不读取输入文字、不保存输入历史、不联网；演示仅驱动内部模型，不发送系统输入。

开发者需要.NET10 SDK和Python3。核心测试可在macOS/Linux/Windows执行：

```sh
dotnet run --project windows/YierBubu.Tests -c Release
python -m unittest discover -s windows/tests -v
```

Windows PowerShell7构建（从仓库根目录）：

```powershell
./windows/scripts/build.ps1 -Output windows/artifacts/publish
$env:SOURCE_COMMIT = git rev-parse HEAD
dotnet run --project windows/YierBubu.Smoke -c Release -- windows/artifacts/evidence
./windows/scripts/package.ps1 -PublishDir windows/artifacts/publish -Output windows/artifacts/release -SmokeResult windows/artifacts/evidence/result.json -SourceCommit $env:SOURCE_COMMIT
```

输出目录必须全新。打包检查真实x64 PE、运行库、素材、桌面检查报告，再解压ZIP逐文件比对并执行资源验证。桌面冒烟生成PNG及JSON；不会模拟全局键鼠输入，不能当作物理输入成功。

素材准备脚本从固定的已公开macOS beta.3 ZIP下载，核对ZIP及三张运行PNG的SHA256，只提取白名单资源。从已批准ICNS的256px PNG图块直接派生Windows ICO，不重画角色。构建时需要网络，应用运行不联网。

## 许可与致谢

独立代码MIT；角色形象、名称、图标和PNG不在MIT内，角色素材分发授权尚未确认。公开源码不包含角色图和原作参考图。[完整来源与素材说明](THIRD_PARTY_NOTICES.md)。感谢 [ayangweb/BongoCat](https://github.com/ayangweb/BongoCat) 的交互思路和职责划分参考，角色原作黄小B。
