import AppKit
import BubuCore

@MainActor
final class PetView: NSView {
    private(set) var interaction = InteractionSnapshot()
    private var blinking = false
    private var blinkTimer: Timer?
    private var blinkEnd: Timer?
    private var suspended = true
    private var motionTimer:Timer?
    private var leftMotion=PawMotion(pose:.idle(left:true))
    private var rightMotion=PawMotion(pose:.idle(left:false))
    private var mouseMotion=PawMotion(pose:.idleMouse)
    var layeredAssets = LayeredAssets()
    override var isFlipped: Bool { true }
    override var mouseDownCanMoveWindow: Bool { true }

    func setInteraction(_ value: InteractionSnapshot) {
        guard interaction != value else { return }
        interaction = value
        let now=ProcessInfo.processInfo.systemUptime
        let left=value.leftKey.flatMap { PawPose.typing(code:$0) } ?? .idle(left:true)
        let right=value.rightKey.flatMap { PawPose.typing(code:$0) } ?? .idle(left:false)
        let scrolling=value.scrollX != 0 || value.scrollY != 0
        let mouse=value.buttons.isEmpty && !scrolling ? PawPose.idleMouse : .mouse(buttons:value.buttons,scrolling:scrolling)
        if suspended {
            leftMotion=PawMotion(pose:left);rightMotion=PawMotion(pose:right);mouseMotion=PawMotion(pose:mouse)
        } else {
            leftMotion.retarget(left,at:now);rightMotion.retarget(right,at:now);mouseMotion.retarget(mouse,at:now)
            startMotionTimer()
        }
        needsDisplay = true
    }
    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .image }
    override func accessibilityLabel() -> String? { "一二布布 · 键盘和鼠标" }
    override func accessibilityValue() -> Any? {
        let keys = interaction.keys.sorted().compactMap { KeyboardLayout.key(for:$0)?.label }.joined(separator:" + ")
        let buttons = interaction.buttons.map(\.rawValue).sorted().joined(separator:", ")
        return "\(KeyboardLayout.title)；按键：\(keys.isEmpty ? "无" : keys)；鼠标：\(buttons.isEmpty ? "无" : buttons)；滚动 x=\(interaction.scrollX) y=\(interaction.scrollY)"
    }
    func setSuspended(_ value: Bool) {
        guard suspended != value else { return }
        suspended = value
        motionTimer?.invalidate();motionTimer=nil
        leftMotion=PawMotion(pose:.idle(left:true));rightMotion=PawMotion(pose:.idle(left:false));mouseMotion=PawMotion(pose:.idleMouse)
        blinkTimer?.invalidate();blinkTimer=nil;blinkEnd?.invalidate();blinkEnd=nil;blinking=false
        if !value {
            blinkTimer = Timer.commonModesTimer(withTimeInterval:4,repeats:true) { [weak self] _ in
                MainActor.assumeIsolated { self?.blink() }
            }
        }
        needsDisplay=true
    }
    private func startMotionTimer() {
        guard motionTimer==nil else { return }
        motionTimer=Timer.commonModesTimer(withTimeInterval:1.0/60,repeats:true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.needsDisplay=true
                let now=ProcessInfo.processInfo.systemUptime
                if !self.leftMotion.isAnimating(at:now) && !self.rightMotion.isAnimating(at:now) && !self.mouseMotion.isAnimating(at:now) {
                    self.motionTimer?.invalidate();self.motionTimer=nil
                }
            }
        }
    }
    private var renderedPaws:ScenePaws {
        if suspended { return ScenePaws(state:interaction) }
        let now=ProcessInfo.processInfo.systemUptime
        let scrolling=interaction.scrollX != 0 || interaction.scrollY != 0
        return ScenePaws(
            left:interaction.leftKey != nil || leftMotion.isAnimating(at:now) ? leftMotion.pose(at:now) : nil,
            right:interaction.rightKey != nil || rightMotion.isAnimating(at:now) ? rightMotion.pose(at:now) : nil,
            mouse:!interaction.buttons.isEmpty || scrolling || mouseMotion.isAnimating(at:now) ? mouseMotion.pose(at:now) : nil)
    }
    func blink() {
        guard !suspended, interaction.keys.isEmpty, interaction.buttons.isEmpty else { return }
        blinking=true;needsDisplay=true
        blinkEnd?.invalidate()
        blinkEnd=Timer.commonModesTimer(withTimeInterval:0.12,repeats:false) { [weak self] _ in
            MainActor.assumeIsolated { self?.blinking=false;self?.needsDisplay=true }
        }
    }
    override func draw(_ dirtyRect:NSRect) {
        NSColor.clear.setFill();bounds.fill(using:.copy)
        guard let context=NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.scaleBy(x:bounds.width/1536,y:bounds.height/1024)
        SceneRenderer().draw(scene:layeredAssets.scene,cleanplate:layeredAssets.cleanplate,paws:layeredAssets.paws,state:interaction,blinking:blinking,poses:renderedPaws)
        context.restoreGState()
    }
}
