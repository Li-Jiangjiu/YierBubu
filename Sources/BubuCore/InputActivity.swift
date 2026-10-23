/// Session-only counts from the OS input adapter. Demo actions never call this
/// type, so animation playback cannot masquerade as a successful connection.
public struct InputActivity: Sendable {
    public private(set) var keyPresses = 0
    public private(set) var mouseClicks = 0
    public private(set) var leftClicks = 0
    public private(set) var rightClicks = 0
    public private(set) var middleClicks = 0
    public private(set) var scrollEvents = 0
    public var hasReceivedInput: Bool { keyPresses > 0 || mouseClicks > 0 || scrollEvents > 0 }

    public init() {}

    public mutating func record(_ event: DeviceInput) {
        switch event {
        case .keyDown(_, false): keyPresses += 1
        case .mouseDown(let button):
            mouseClicks += 1
            switch button {
            case .left: leftClicks += 1
            case .right: rightClicks += 1
            case .middle: middleClicks += 1
            }
        case .scroll(let dx, let dy):
            if dx.isFinite && dy.isFinite && (dx != 0 || dy != 0) { scrollEvents += 1 }
        default: break
        }
    }
}
