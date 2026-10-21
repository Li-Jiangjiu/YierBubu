# 一二布布桌面陪伴

跟随键盘和鼠标动作的 macOS 桌面陪伴应用，非官方个人项目。

## 下载

当前版本：**0.4.0-beta.3 免费测试版**。支持 **macOS 14 及以上**，同一个安装包支持 **Apple 芯片（M 系列）和 Intel**。Windows x64 首个测试版正在开发，源码与构建方法见 [Windows 开发说明](windows/README.md)。

- [推荐：下载 DMG 安装包](https://github.com/Li-Jiangjiu/YierBubu/releases/download/v0.4.0-beta.3/YierBubu-macOS-Universal-v0.4.0-beta.3.dmg)
- [下载 ZIP 安装包](https://github.com/Li-Jiangjiu/YierBubu/releases/download/v0.4.0-beta.3/YierBubu-macOS-Universal-v0.4.0-beta.3.zip)
- [查看版本说明和校验文件](https://github.com/Li-Jiangjiu/YierBubu/releases/tag/v0.4.0-beta.3)

DMG 和 ZIP 二选一即可。macOS beta.3 标签下自动生成的 Source code 压缩包只有当时的说明文件，不是安装包。**本分支公开 Windows 实现代码（MIT，仅代码），macOS 源码尚未整理公开；角色素材不适用 MIT。**

## Windows 开发与测试包

Windows 首版目标为 Windows 10 / Windows 11 x64，Intel 与 AMD 使用同一份便携 ZIP。保持现有角色构图、36键反馈和鼠标互动，使用右下角托盘控制。

- [Windows 源码、构建与使用说明](windows/README.md)
- [开发与测试 PR](https://github.com/Li-Jiangjiu/YierBubu/pull/2)
- [Windows 自动化验证记录](docs/windows/verification.md)

云端构建包通过 Actions artifacts 提供，需登录 GitHub，保留30天；尚未作为正式 Releases 版本发布。Windows Server 与 Windows11 ARM上的x64模拟验证不代替 Windows10/11 实体键鼠或 Intel/AMD 分别实机验收。

## macOS 安装与首次打开

1. 更新前，从屏幕顶部小熊菜单选择“退出一二布布”。
2. 打开 DMG，将 YierBubu.app 拖入 Applications（应用程序），完成后弹出镜像。ZIP 用户先解压，再将 App 拖入应用程序。
3. 从“应用程序”打开 App。本版未经过 Apple 公证，确认来源后，若系统阻止打开，可进入“系统设置 → 隐私与安全性”，按系统提供的“仍要打开”流程确认。不要关闭系统安全保护。
4. 点击顶部菜单栏的小熊符号 `ʕ•ᴥ•ʔ`，选择“连接键盘与查看状态…”，申请输入监控。在系统输入监控列表中，用 ＋ 选择应用程序中的本版 App 并开启授权。
5. 按系统提示重新打开，切换到其他软件打字、点击和滚动，确认显示“监听中”且真实计数增加。

免费测试版每次内容更新使用独立权限标识，需要为新版本重新授权；旧条目已经打开不能代替本次授权。动作演示能播放不代表已获得输入权限。

## 本版修复与使用范围

beta.3 修复了旧版本签名与输入监控授权规则冲突的问题。用户已反馈，在 MacBook Air 2020（Intel Core i5、8GB、macOS 15.7.9）上，重新授权后键盘和鼠标输入恢复正常。

核心测试33项、发布回归21项通过；本机 Apple 芯片与 Rosetta 的窗口/动画检查各38项通过。用户实机反馈不代表所有设备、系统或长期场景都经过验收。

仅显示主区数字和字母36键，按物理 Mac ANSI QWERTY 位置反馈。其他布局、媒体键、多屏、全屏、安全输入模式及长期稳定性未全面验证。

## 隐私与卸载

App 仅用当前物理键位、鼠标按钮和滚动方向驱动动画，不读取输入文字、不记录输入历史、不联网。仅在运行期间维护临时状态和次数。

卸载：先从顶部小熊菜单退出，再将“应用程序”中的 YierBubu.app 移至废纸篓；可按需移除输入监控条目。当前没有开机自启。

## 角色素材与使用说明

角色原作黄小B，本项目非官方。角色形象、名称、商标及素材的公开分发授权尚未确认；免费提供应用不代表获得角色权利人的授权，也不授予素材再分发许可。

Windows 独立实现代码适用 [MIT 许可](LICENSE)。macOS 安装包及角色素材不在该代码许可范围内，角色素材权利边界见 [Windows 来源与素材说明](windows/THIRD_PARTY_NOTICES.md)。

反馈问题时，请提供 macOS版本、芯片、App版本、监听状态和复现步骤，不需要提供输入文字或其他私人内容。


## 项目来源与致谢

本项目基于 [ayangweb/BongoCat](https://github.com/ayangweb/BongoCat) 的桌面陪伴交互思路，在其产品设计以及输入、平台、窗口模块职责划分的参考基础上开展一二布布的开发工作。感谢 ayangweb 和 BongoCat 项目的分享与启发。

本项目的 macOS Swift 实现独立编写，没有复制或翻译 BongoCat 的实现代码，也没有使用其猫咪模型或 Live2D 素材。

## 支持与赞赏

每一份认可我都心怀感激。欢迎赞赏，但绝不强求——感谢喜欢一二布布的你❤️

<img src="sponsor.jpg" alt="大昆的微信赞赏码" width="320" />
