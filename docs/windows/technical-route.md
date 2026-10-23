# Windows 版技术路线与执行记录

首版：0.5.0-beta.1，Windows 10 / Windows 11 x64，Intel / AMD 共用便携包。免费、非官方、无开机自启。设计于2026-10-21，持续验证至2026-10-22。

## 1. 技术选型与结构

采用 C# + .NET 10 LTS + WPF。窗口、透明绘图和托盘使用Windows桌面接口；输入使用Win32 Raw Input，应用只接收事件，不拦截或发送键鼠。相较Tauri省去WebView2依赖与网页透明窗口兼容链，相较C++便于维护绘图与状态模型。

| 路径 | 职责 | 如何验证 |
| --- | --- | --- |
| `windows/YierBubu.Core/Input.cs` | 扫描码、重复归一化、真实计数 | 主区36键、扩展键/小键盘、自动重复、计数断言 |
| `InteractionState.cs` | 当前按住和短暂反馈 | 100/120/180ms期限、多键/键鼠并行、重置与休息 |
| `RawInputDecoder.cs`、`RawInputSession.cs` | x64原始数据、按设备聚合 | 数据边界、左右中键、带符号滚动、两个键盘/鼠标释放顺序 |
| `SceneLayout.cs`、`PawPose.cs` | 批准布局与爪尖几何、75ms连续转向 | 全36键接触点在键顶、鼠标左右区域、转向连续和回弹角度 |
| `windows/YierBubu.Windows/InputMonitor.cs` | 独立消息窗口注册键鼠，WM_INPUT解码 | 云端真实注册/停止、隐藏后仍有注册、退出后解除 |
| `PetWindow.cs`、`PetView.cs` | 透明置顶非激活窗口、短期动画 | 真实HWND样式、三档缩放、穿透、隐藏恢复 |
| `SceneRenderer.cs`、`Assets.cs` | 局部补底、程序键帽、手臂与爪片、资源校验 | 36键实际像素、鼠标按钮正确区域、缺素材拒绝、人工看截图 |
| `AppController.cs`、`StatusWindow.cs` | 托盘、状态、演示、会话/睡眠、退出清理 | 运行Dispatcher验证演示、隐藏、监听、释放 |
| `windows/scripts` | 白名单素材准备、编译、便携包 | 固定来源与SHA256、真实PE、自包含运行库、ZIP往返逐文件比对 |

所有场景坐标均为1536×1024源图坐标；窗口默认300×200 DIP。Windows使用物理扫描码转为平台无关可见键标识，再进入动画状态，不把macOS keyCode直接当Windows键码。

## 2. 分步执行方法与通过条件

1. **保存需求与实施计划**：记录批准外观、36键、隐私约定、兼容目标及不覆盖原Mac包的约束。以独立Windows目录和开发分支实施。
2. **先写核心测试**：添加可执行断言并观察缺失行为失败；实现状态、键码、滚动、期限和计数；全部测试通过才继续。初始17项在云端确认失败，实现后转绿；后续扩展到68项。
3. **移植几何与姿势**：使用批准Swift模块的坐标与时长，测试36个爪尖实际接触点、布布自身视角、连续转向和负坐标工作区。图形栅格化/字体允许系统差异，不重画角色。
4. **实现Windows适配与UI**：先定义窗口/渲染/监听检查，再实现WPF、独立Raw Input消息窗口、托盘、状态和会话生命周期。普通权限运行，不要求安装开发工具。
5. **准备素材**：从已发布macOS beta.3 ZIP下载，核对固定SHA256，仅提取三张运行PNG和ICNS。核对三图SHA256/尺寸，从原ICNS的256px PNG图块生成ICO。不上传原作参考图，不把角色素材授权混入MIT。
6. **真实Windows构建和渲染**：GitHub WindowsServer2022/2025 x64执行核心测试、构建、窗口/渲染/监听检查。Windows11 ARM另运行发布后的x64程序，通过系统模拟补充客户端兼容证据。每次保留PNG、result.json、工作流日志。
7. **独立审查与修复**：审查发现多设备共享按住状态和样式更新缺少明确不激活标志；补上设备聚合回归、SWP_NOACTIVATE。云端无法激活前台哨兵时，焦点检查记为未验证，不伪装成功。
8. **制作普通用户包**：`dotnet publish -r win-x64 --self-contained true`，验证真实Windows x64 PE与includedFrameworks；附使用/隐私/素材说明，压缩后实际重新解压逐文件校验并执行资源验证。输出ZIP、SHA256、RELEASE-INFO。
9. **交付与开源**：以远端main为基线导入筛选Windows源码、MIT和CI，保留原README下载入口、赞赏图片、原文附言及BongoCat致谢。开发分支和PR公开可审阅；不强推本地历史或覆盖Mac发布包。测试包与正式发布区分。

## 3. 开发与重跑命令

核心（跨平台）：

```sh
dotnet run --project windows/YierBubu.Tests -c Release
python -m unittest discover -s windows/tests -v
```

Windows PowerShell7（从仓库根目录执行，输出目录必须全新）：

```powershell
./windows/scripts/build.ps1 -Output windows/artifacts/publish
$env:SOURCE_COMMIT = git rev-parse HEAD
dotnet publish windows/YierBubu.Smoke -c Release -r win-x64 --self-contained true -o windows/artifacts/smoke-x64
./windows/artifacts/smoke-x64/YierBubu.Smoke.exe windows/artifacts/evidence
./windows/scripts/package.ps1 -PublishDir windows/artifacts/publish -Output windows/artifacts/release -SmokeResult windows/artifacts/evidence/result.json -SourceCommit $env:SOURCE_COMMIT
```

## 4. 测试渠道能证明什么

云端能证明真实Windows构建/启动、实际窗口样式、Raw Input注册、程序绘图、包内容和退出清理。Windows11 ARM x64模拟是客户端系统证据；不是ARM64原生版本，也不是Intel/AMD实体硬件验收。

当前没有Windows10/11实体键鼠非零计数，未验证混合DPI多屏、长期睡眠恢复和安全桌面，不能写成全面兼容所有设备/所有历史Windows10版本。交互式焦点验证可能受托管桌面限制，结果中明确列出。后续可通过自有虚拟机、远程客户端测试机或自愿测试者补验；本轮不购买云资源或注册付费服务。

应用运行期间不联网、不读取输入文字、不记录输入历史、不发送模拟输入。构建工具下载素材和依赖不等于应用运行联网。
