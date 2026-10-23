import AppKit
import BubuCore

@MainActor
final class InputSetupWindow: NSWindowController {
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private let countLabel = NSTextField(wrappingLabelWithString: "")
    private let helpLabel = NSTextField(wrappingLabelWithString: "")
    var onRequest: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onRecheck: (() -> Void)?
    var onRestart: (() -> Void)?

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 540),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "一二布布 · 连接键盘"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        let title = NSTextField(labelWithString: "让一二布布跟着你打字")
        title.font = .systemFont(ofSize: 23, weight: .semibold)
        let explanation = NSTextField(wrappingLabelWithString:
            "macOS 需要你允许“一二布布”监控其他应用中的键盘输入。仅用当前按键位置、鼠标按钮和滚动方向驱动动画，不读取或保存输入文字，不保存按键历史。画面使用 Mac ANSI QWERTY 物理布局。")
        let settingsName: String
        let privacyPath: String
        if #available(macOS 13, *) {
            settingsName = "系统设置"
            privacyPath = "系统设置 → 隐私与安全性 → 输入监控"
        } else {
            settingsName = "系统偏好设置"
            privacyPath = "系统偏好设置 → 安全性与隐私 → 隐私 → 输入监控"
        }
        let steps = NSTextField(wrappingLabelWithString:
            "1. 点击“申请输入监控”。\n2. 在\(privacyPath)中打开“一二布布”。若列表为空，点 ＋ 添加下面的应用。\n3. 回来点“重新检测”；系统要求时，点“重新打开应用”。")
        let path = NSTextField(wrappingLabelWithString: Bundle.main.bundleURL.path)
        path.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        path.isSelectable = true
        path.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        countLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        helpLabel.textColor = .secondaryLabelColor
        let buttons = NSStackView(views: [
            button("申请输入监控", #selector(request)),
            button("打开\(settingsName)", #selector(settings)),
            button("重新检测", #selector(recheck)),
            button("重新打开应用", #selector(restart))
        ])
        buttons.spacing = 8
        let stack = NSStackView(views: [title, explanation, steps, path, statusLabel, countLabel, helpLabel, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView?.addSubview(stack)
        if let content = window.contentView {
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
                stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
                stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
                stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -20)
            ])
            for label in [explanation, steps, path, statusLabel, countLabel, helpLabel] {
                label.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func update(status: InputStatus, activity: InputActivity) {
        statusLabel.stringValue = status.title
        countLabel.stringValue = "实际收到：键盘 \(activity.keyPresses) 次\n鼠标：左键 \(activity.leftClicks) · 右键 \(activity.rightClicks) · 中键 \(activity.middleClicks) · 滚动 \(activity.scrollEvents)"
        switch status {
        case .listening:
            helpLabel.stringValue = activity.keyPresses > 0
                ? "已收到真实键盘事件。切换到其他软件继续打字，对应键帽会同步亮起；左右键与滚动分别显示。"
                : "监听已启动。请切换到其他软件打几个字，检查上方键盘计数是否增加。"
        case .notAuthorized:
            helpLabel.stringValue = "尚未获得系统授权。动作演示能播放，并不代表键盘已经连接。"
        case .failed:
            helpLabel.stringValue = "请检查系统开关；若已打开但无反应，重新打开应用。"
        case .stopped:
            helpLabel.stringValue = "输入监听已停止，点击重新检测可重试。"
        }
    }

    func present() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func button(_ title: String, _ action: Selector) -> NSButton {
        NSButton(title: title, target: self, action: action)
    }
    @objc private func request() { onRequest?() }
    @objc private func settings() { onOpenSettings?() }
    @objc private func recheck() { onRecheck?() }
    @objc private func restart() { onRestart?() }
}
