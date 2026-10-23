import Foundation

public enum MouseButton: String, CaseIterable, Sendable { case left, right, middle }
public enum DeviceInput: Sendable {
    case keyDown(code: UInt16, isRepeat: Bool)
    case keyUp(code: UInt16)
    case mouseDown(button: MouseButton)
    case mouseUp(button: MouseButton)
    case scroll(dx: Double, dy: Double)
}

public struct InteractionSnapshot: Equatable, Sendable {
    public var keys: Set<UInt16> = []
    public var buttons: Set<MouseButton> = []
    public var scrollX: Double = 0
    public var scrollY: Double = 0
    public var leftKey: UInt16?
    public var rightKey: UInt16?
    public var resting = false
    public init() {}
}

/// Only current held inputs and short visual pulses live here, never an input log.
public struct InteractionState: Sendable {
    private struct Press: Sendable {
        var held = true
        let until: TimeInterval
        let order: Int
        func visible(at now: TimeInterval) -> Bool { held || until > now }
    }
    private var keys: [UInt16: Press] = [:]
    private var buttons: [MouseButton: Press] = [:]
    private var scrollX = 0.0
    private var scrollY = 0.0
    private var scrollUntil = 0.0
    private var order = 0
    private var lastActivity: TimeInterval
    private var lastTime: TimeInterval

    public init(now: TimeInterval) { lastActivity = now; lastTime = now }
    public mutating func handle(_ input: DeviceInput, at now: TimeInterval) {
        normalize(now)
        switch input {
        case .keyDown(let code, let repeatKey):
            guard KeyboardLayout.key(for: code) != nil else { return }
            lastActivity = now
            guard !repeatKey, keys[code]?.held != true else { return }
            order += 1
            keys[code] = Press(until: now + 0.1, order: order)
        case .keyUp(let code):
            if keys[code] != nil { keys[code]?.held = false; lastActivity = now }
        case .mouseDown(let button):
            lastActivity = now
            guard buttons[button]?.held != true else { return }
            order += 1
            buttons[button] = Press(until: now + 0.12, order: order)
        case .mouseUp(let button):
            if buttons[button] != nil { buttons[button]?.held = false; lastActivity = now }
        case .scroll(let dx, let dy):
            guard dx.isFinite, dy.isFinite, dx != 0 || dy != 0 else { return }
            if now >= scrollUntil { scrollX = 0; scrollY = 0 }
            scrollX = max(-100, min(100, scrollX * dx < 0 ? dx : scrollX + dx))
            scrollY = max(-100, min(100, scrollY * dy < 0 ? dy : scrollY + dy))
            scrollUntil = now + 0.18
            lastActivity = now
        }
        prune(now)
    }
    public mutating func snapshot(at now: TimeInterval) -> InteractionSnapshot {
        normalize(now)
        prune(now)
        var value = InteractionSnapshot()
        value.keys = Set(keys.keys)
        value.buttons = Set(buttons.keys)
        value.scrollX = now < scrollUntil ? scrollX : 0
        value.scrollY = now < scrollUntil ? scrollY : 0
        let ordered = keys.filter { $0.key != 57 || $0.value.until > now }.sorted { $0.value.order > $1.value.order }
        value.leftKey = ordered.first { CompactSceneLayout.key(for: $0.key)?.leftPaw == true }?.key
        value.rightKey = ordered.first { CompactSceneLayout.key(for: $0.key)?.leftPaw == false }?.key
        value.resting = keys.keys.allSatisfy { $0 == 57 } && buttons.isEmpty && now >= scrollUntil && now - lastActivity >= 15
        return value
    }
    public func nextTransition(after now: TimeInterval) -> TimeInterval? {
        var deadlines = keys.values.filter { !$0.held && $0.until > now }.map(\.until)
        deadlines += buttons.values.filter { !$0.held && $0.until > now }.map(\.until)
        if let caps=keys[57],caps.until>now { deadlines.append(caps.until) }
        if scrollUntil > now { deadlines.append(scrollUntil) }
        if !keys.contains(where: { $0.key != 57 && $0.value.held }) && !buttons.values.contains(where: \.held) && lastActivity + 15 > now {
            deadlines.append(lastActivity + 15)
        }
        return deadlines.min()
    }
    public mutating func reset(at now: TimeInterval) {
        keys.removeAll(); buttons.removeAll(); scrollX = 0; scrollY = 0; scrollUntil = now
        order = 0; lastActivity = now; lastTime = now
    }
    private mutating func normalize(_ now: TimeInterval) {
        if now < lastTime { reset(at: now) }
        lastTime = now
    }
    private mutating func prune(_ now: TimeInterval) {
        keys = keys.filter { $0.value.visible(at: now) }
        buttons = buttons.filter { $0.value.visible(at: now) }
        if now >= scrollUntil { scrollX = 0; scrollY = 0 }
    }
}
