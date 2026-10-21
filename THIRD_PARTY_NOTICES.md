# 参考来源

## BongoCat

项目：https://github.com/ayangweb/BongoCat

本项目在 2026-10-17 阅读了默认分支的以下公开文件，参考其产品交互和输入、平台、窗口职责划分：

- `README.md`
- `CONTRIBUTING.md`
- `Cargo.toml`
- `crates/bongocat-input/src/lib.rs`
- `crates/bongocat-platform/src/lib.rs`
- `crates/bongocat-overlay/src/lib.rs`

来源是当日 raw.githubusercontent.com/master 在线版本；由于 Git 下载网络失败，未能固定完整提交 SHA，不能声称已逐行分析上游具体 macOS 监听实现。

BongoCat 采用 Apache-2.0。本项目目前没有复制或翻译上游实现代码，也没有使用其猫咪模型、Live2D 素材或第三方 SDK；Swift 实现独立编写。

## Apple SDK

macOS 监听接口依据本机 SDK 的 `CoreGraphics.framework/Headers/CGEvent.h` 和 `CGEventTypes.h`，包括 `CGEventTapCreate`、`kCGEventTapOptionListenOnly`、`CGPreflightListenEventAccess` 和 `CGRequestListenEventAccess`。监听回调在登记的主线程 run loop 中执行。

## 角色

一二布布角色名称与形象属于其原权利方，角色原作黄小B。本项目为个人兴趣开发，非官方作品。当前程序使用用户确认的紧凑构图、局部补底和透明爪片三张分层素材，配合程序绘制设备反馈与手臂动作。角色视觉来源、保留原样的署名参考图与生成说明分别记录在 `Resources/References/README.md` 和 `Resources/Layered/PROMPTS.md`；参考原图不包含在应用包内。旧六张整帧动作图已在阶段收尾中移除。
