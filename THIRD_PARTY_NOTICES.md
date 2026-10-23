# 来源、致谢与第三方权利

## 一二布布与黄小B

感谢黄小B创作一二布布。角色名称、形象、商标、PNG和图标等相关权利归相应权利方，本项目是非官方个人项目，不代表角色官方。素材经 AI 辅助制作或由维护者免费提供，并不意味着取得角色公开分发授权。

源码仓库不收录角色图片或原作参考图。构建工具从固定 SHA256 的既有公开 Mac 安装包提取三张运行PNG和ICNS图标；这只帮助核对既有画面，不授予素材使用或再分发权。公开分发授权尚未确认；代码 MIT 许可不涵盖上述素材和角色权利。

## BongoCat 与 ayangweb

感谢 [ayangweb/BongoCat](https://github.com/ayangweb/BongoCat) 提供桌面陪伴的交互灵感和输入、平台、窗口模块职责划分的参考。

2026-10-17 参考了当日默认分支公开的 README.md、CONTRIBUTING.md、Cargo.toml 以及 crates/bongocat-input、bongocat-platform、bongocat-overlay 中的 lib.rs。来源为当日在线版本，未固定完整上游提交 SHA。BongoCat 采用 Apache-2.0。

本项目 Swift / C# 实现独立编写，没有复制或翻译 BongoCat 实现代码，没有使用其猫咪模型、Live2D素材或第三方 SDK。此致谢不表示上游作者或角色权利方为本项目背书。

## Apple 与 Microsoft

Mac 使用系统 AppKit/CoreGraphics 和 Apple SDK 的只读 CGEventTap / 输入监控接口，不随源码分发 Apple SDK；构建中必要的 Swift 运行库按 Apple 适用条款使用。

Windows 使用 .NET、WPF、WinForms NotifyIcon 和 Win32 Raw Input，无第三方应用框架。自包含包包含 Microsoft 运行时，随包保留相应 LICENSE 与 THIRD-PARTY-NOTICES 文件，打包验证会检查这些声明。详见 [Windows 第三方说明](windows/THIRD_PARTY_NOTICES.md)。

独立应用代码采用根目录 LICENSE 中的 MIT 许可；第三方组件各遵从自身许可。
