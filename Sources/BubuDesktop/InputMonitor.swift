import AppKit
import BubuCore
import CoreGraphics

enum InputStatus: Equatable {
    case notAuthorized, listening, failed(String), stopped

    var title: String {
        switch self {
        case .notAuthorized: "未授权 · 可先体验动作演示"
        case .listening: "监听中 · 仅触发动作"
        case .failed(let reason): "监听失败 · \(reason)"
        case .stopped: "监听已停止"
        }
    }
}

/// Registered exclusively on the main run loop. The callback does not read
/// typed characters or input history, and never changes or posts system events.
@MainActor
final class InputMonitor {
    private(set) var status: InputStatus = .stopped {
        didSet { if oldValue != status { onStatusChange?(status) } }
    }
    var onInput: ((DeviceInput) -> Void)?
    var onStatusChange: ((InputStatus) -> Void)?
    var onReset: (() -> Void)?
    var onActivityChange: ((InputActivity) -> Void)?
    private(set) var activity = InputActivity()
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    func start() {
        stop()
        guard CGPreflightListenEventAccess() else {
            status = .notAuthorized
            return
        }
        let mask = [CGEventType.keyDown, .keyUp, .flagsChanged,
                    .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
                    .otherMouseDown, .otherMouseUp, .scrollWheel]
            .reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        let callback: CGEventTapCallBack = { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let owner = Unmanaged<InputMonitor>.fromOpaque(context).takeUnretainedValue()
            // The event tap's source is attached only to CFRunLoopGetMain().
            MainActor.assumeIsolated { owner.receive(type, event: event) }
            return Unmanaged.passUnretained(event)
        }
        guard let created = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .tailAppendEventTap,
            options: .listenOnly, eventsOfInterest: mask, callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            status = .failed("请重新检测权限或重新打开应用")
            return
        }
        guard let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, created, 0) else {
            CFMachPortInvalidate(created)
            status = .failed("无法创建输入事件源")
            return
        }
        tap = created
        source = runLoopSource
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: created, enable: true)
        status = .listening
        reconcileCapsLock()
    }

    func stop() {
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap { CFMachPortInvalidate(tap) }
        source = nil
        tap = nil
        status = .stopped
        onReset?()
    }

    func requestPermission() {
        _ = CGRequestListenEventAccess()
        start()
    }

    func checkPermission() {
        let allowed = CGPreflightListenEventAccess()
        if !allowed && status != .notAuthorized {
            stop()
            status = .notAuthorized
        } else if allowed && (tap == nil || status != .listening) {
            start()
        } else if let tap, !CGEvent.tapIsEnabled(tap: tap) {
            onReset?()
            CGEvent.tapEnable(tap: tap, enable: true)
            if !CGEvent.tapIsEnabled(tap: tap) {
                stop()
                status = .failed("系统已暂停监听，请重新检测")
            } else { reconcileCapsLock() }
        }
    }

    private func receive(_ type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            onReset?()
            guard CGPreflightListenEventAccess(), let tap else {
                stop()
                status = .notAuthorized
                return
            }
            if type == .tapDisabledByTimeout {
                CGEvent.tapEnable(tap: tap, enable: true)
                if CGEvent.tapIsEnabled(tap:tap) { reconcileCapsLock() }
            } else {
                stop()
                status = .failed("系统已暂停监听，请重新检测")
            }
            return
        }
        let code = UInt16(clamping: event.getIntegerValueField(.keyboardEventKeycode))
        switch type {
        case .keyDown:
            deliver(.keyDown(code: code, isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0))
        case .keyUp:
            deliver(.keyUp(code: code))
        case .flagsChanged:
            if let input = InputNormalizer.modifier(code: code, flags: event.flags.rawValue) { deliver(input) }
        case .leftMouseDown: deliver(.mouseDown(button: .left))
        case .leftMouseUp: deliver(.mouseUp(button: .left))
        case .rightMouseDown: deliver(.mouseDown(button: .right))
        case .rightMouseUp: deliver(.mouseUp(button: .right))
        case .otherMouseDown, .otherMouseUp:
            if let button = InputNormalizer.button(number: event.getIntegerValueField(.mouseEventButtonNumber)) {
                deliver(type == .otherMouseDown ? .mouseDown(button: button) : .mouseUp(button: button))
            }
        case .scrollWheel:
            deliver(.scroll(dx: event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2),
                            dy: event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)))
        default: break
        }
    }

    private func reconcileCapsLock() {
        // State reconciliation is not a new physical press and must not affect counts.
        if let event=InputNormalizer.modifier(code:57,flags:CGEventSource.flagsState(.combinedSessionState).rawValue) {
            onInput?(event)
        }
    }

    private func deliver(_ event: DeviceInput) {
        activity.record(event)
        onActivityChange?(activity)
        onInput?(event)
    }
}
