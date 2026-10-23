import AppKit
import BubuCore

@MainActor
final class PetWindow: NSPanel {
    private let defaultSize = NSSize(width: 300, height: 200)
    private(set) var scale: Double = 1

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        title = "一二布布"
        resetPosition()
    }

    func setScale(_ value: Double) {
        guard [0.75, 1, 1.25].contains(value) else { return }
        scale = value
        setContentSize(NSSize(width: defaultSize.width * value, height: defaultSize.height * value))
        resetPosition()
    }

    func resetPosition() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        setFrame(WindowPlacement.bottomRight(screen: screen.visibleFrame,
                                              size: frame.size, margin: 24), display: true)
    }

    func setClickThrough(_ enabled: Bool) { ignoresMouseEvents = enabled }
}
