# 一二布布桌面陪伴 🐻

**想让小熊陪你上班？先选电脑系统，点击下面的链接下载：**

| 你的电脑 | 点击下载 | 版本与要求 |
| --- | --- | --- |
| 🍎 **Mac** | **[下载 Mac 安装包 DMG（推荐）](https://github.com/Li-Jiangjiu/YierBubu/releases/download/v0.4.0-beta.3/YierBubu-macOS-Universal-v0.4.0-beta.3.dmg)** · [备用 ZIP](https://github.com/Li-Jiangjiu/YierBubu/releases/download/v0.4.0-beta.3/YierBubu-macOS-Universal-v0.4.0-beta.3.zip) | v0.4.0-beta.3 · macOS 14及以上 · Apple M系列 / Intel 通用 |
| 🪟 **Windows** | **[下载 Windows 便携包 ZIP](https://github.com/Li-Jiangjiu/YierBubu/releases/download/v0.5.0-beta.1-windows/YierBubu-Windows-x64-v0.5.0-beta.1.zip)** | v0.5.0-beta.1 · Windows 10 / 11 · Intel / AMD 64位 |

**使用 App 不需要下载源码，不需要安装开发环境。** 请下载上表中的安装包，GitHub 的绿色 Code 按钮和自动生成的 Source code 压缩包是给开发者的。

这是跟随键盘和鼠标动作的桌面陪伴应用，**个人非营利、非官方项目，目前免费提供测试**。两个平台分别维护版本号，Windows 版本号更高不表示 Mac 需要升级。

## Windows：3步接小熊回家

1. **下载**：点击上面的“下载 Windows 便携包 ZIP”。
2. **解压**：右键压缩包，选择“全部解压”，保留完整的 `YierBubu` 文件夹。
3. **打开**：双击文件夹里的 `YierBubu.exe`，小熊就会出现在桌面上！

无需安装 .NET、Python，无需管理员权限，也无需像 Mac 一样设置输入监控授权。**不要只复制 EXE，也不要在压缩包里直接运行。**

右下角托盘的小熊图标（可能收在向上箭头里）可调整大小、显示/隐藏、鼠标穿透、恢复位置、播放演示、查看状态和退出。切到其他软件敲字母/数字、点击鼠标或滚动，小熊会跟着动作。

Windows 版未商业代码签名，可能出现发布者或 SmartScreen 提醒，请核对下载来源与校验值，不要关闭安全软件。建议使用已更新的 Windows 10/11；首版不提供32位或原生ARM64版本，不承诺所有历史 Windows 10 版本。[详细安装说明](windows/INSTALL.md)

## Mac：安装后开启输入监控

1. **安装**：打开 DMG，把 `YierBubu.app` 拖入“Applications / 应用程序”，再弹出镜像。ZIP 用户先解压，再把 App 移入应用程序。
2. **打开**：从“应用程序”启动。本测试版未经过 Apple 公证；确认来源后，如系统阻止打开，可在“系统设置 → 隐私与安全性”按系统提供的“仍要打开”流程确认，不要关闭系统安全保护。
3. **授权**：点击顶部菜单栏的小熊 `ʕ•ᴥ•ʔ` →“连接键盘与查看状态…”，按提示在“输入监控”中用 ＋ 添加应用程序里的本版 App 并开启授权，随后按提示重新打开。

切到其他软件输入，确认状态显示“监听中”且真实计数增加。免费测试版更新后需要为新版本重新授权，旧条目不能替代新版本授权；动作演示能播放不代表监听已连接。升级前请先从小熊菜单退出旧版。[Mac 详细安装说明](INSTALL.md)

## 小熊能做什么

- 左侧布布操作鼠标，右侧一二操作键盘；36个主区字母/数字键按物理位置反馈。
- 支持键鼠同时动作、鼠标左/右/中键、滚动、拖动、三档大小、穿透和隐藏。
- 只用当前物理键位、按钮、滚动方向驱动画面，不读取输入文字、不记录输入历史、不联网、不发送模拟输入；次数仅在运行期间保留。
- 当前没有开机自启；隐藏画面不等于退出。Windows 从托盘退出后删除整个文件夹即可卸载；Mac 从菜单退出后移除应用，并可移除输入监控条目。

两个版本仍是测试版，多屏、混合DPI、不同键盘布局、长期睡眠唤醒及系统安全输入等场景未全面验收。用户已反馈 Windows 台式机可用、Mac Intel 授权问题解决，不能据此推定全部设备实测通过。[验证范围与发行版对应关系](docs/source-and-releases.md) · [隐私说明](PRIVACY.md)

## 发布说明与文件校验

[Mac 发布说明 / SHA256](https://github.com/Li-Jiangjiu/YierBubu/releases/tag/v0.4.0-beta.3) · [Windows 发布说明 / SHA256](https://github.com/Li-Jiangjiu/YierBubu/releases/tag/v0.5.0-beta.1-windows)

| 安装文件 | SHA256 |
| --- | --- |
| Mac DMG | `904c8f71ef050caae2c1f0fe4660b12ac6d6e9c8336caf24aeea04a3f82f22ee` |
| Mac ZIP | `e4aa6030330ec0fdbb31bd63d6739793f1086cacf82b4eea1e4187ed8ddaed6b` |
| Windows ZIP | `8e1fff251fbd729a51b8ebca08f756f1ff59fd13d51fc7d9ce53d1deb98a2695` |

## 源码已公开，欢迎继续开发

**Mac 和 Windows 的独立实现、测试与构建脚本均在本仓库主分支公开。** 希望这段小小的开发经历，能成为感兴趣的一二布布粉丝继续探索的起点。欢迎 Fork、交流想法、修复问题或提交 Pull Request！

| 内容 | 位置 | 技术 |
| --- | --- | --- |
| Mac 核心与桌面程序 | [Sources](Sources)、[Tests](Tests)、[Package.swift](Package.swift) | Swift 6 / AppKit / CoreGraphics |
| Windows 核心与桌面程序 | [windows](windows) | C# / .NET 10 / WPF / Win32 Raw Input |
| 构建、测试、打包 | [Mac 脚本](scripts)、[Windows 脚本](windows/scripts)、[CI](.github/workflows) | 详见开发指南 |

**开发者从这里开始：[开发与构建指南](DEVELOPMENT.md) · [参与贡献](CONTRIBUTING.md) · [源码与已发布安装包的对应关系](docs/source-and-releases.md)**

独立编写的**代码采用 [MIT 许可证](LICENSE)**，允许按许可修改、使用和再分发，包括商业使用；维护者当前免费、非营利地提供本应用。**角色形象、名称、图标、PNG、商标和第三方素材不在代码 MIT 许可范围内。** 源码仓库不包含角色图片和原作参考图；开发工具可从固定校验的已公开安装包恢复运行所需素材，这不授予素材再分发权。

角色原作黄小B，本项目非官方，角色素材的公开分发授权尚未确认。请勿把本项目、代码开源或自愿赞赏理解为官方授权。[素材与第三方说明](THIRD_PARTY_NOTICES.md) · [许可边界](LICENSE-DECISION.md)

反馈问题请注明 Mac 或 Windows、系统版本、芯片/CPU、App版本、监听状态及复现步骤，不需要提供输入文字或其他私人内容。

## 谢谢每一位喜欢小熊的你 ❤️

感谢大家的喜爱、耐心和热情反馈！你们的支持，让这个利用下班时间一点点做出来的小项目，有了 Mac 版，也有了 Windows 版。现在把两端源码一起分享出来，希望小熊能陪伴更多人，也期待感兴趣的朋友继续完善它。

特别感谢 **[ayangweb](https://github.com/ayangweb)** 和 **[BongoCat 项目](https://github.com/ayangweb/BongoCat)**，为本项目提供了桌面陪伴的交互思路，以及输入、平台和窗口职责划分的参考。两端的 Swift / C# 实现独立编写，没有复制或翻译其实现代码，也没有使用其猫咪模型或 Live2D 素材。

感谢**黄小B**创作了一二布布，带来这么多可爱、快乐与陪伴。角色及相关形象权利归原权利方所有。

## 支持与赞赏

每一份认可我都心怀感激。欢迎赞赏，但绝不强求——感谢喜欢一二布布的你❤️

<img src="sponsor.jpg" alt="大昆的微信赞赏码" width="320" />
