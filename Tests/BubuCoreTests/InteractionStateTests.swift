import Testing
@testable import BubuCore

struct InteractionStateTests {
    @Test func physicalKeysHaveDistinctLabeledPositions() {
        #expect(KeyboardLayout.key(for: 0)?.label == "A")
        #expect(KeyboardLayout.key(for: 1)?.label == "S")
        #expect(KeyboardLayout.key(for: 2)?.label == "D")
        #expect(KeyboardLayout.key(for: 0)!.x < KeyboardLayout.key(for: 1)!.x)
        #expect(KeyboardLayout.key(for: 1)!.x < KeyboardLayout.key(for: 2)!.x)
        #expect(KeyboardLayout.key(for: 49)?.label == "space")
        #expect(KeyboardLayout.key(for: 65535) == nil)
        #expect(Set(KeyboardLayout.keys.map(\.code)).count == KeyboardLayout.keys.count)
        #expect(KeyboardLayout.keys.filter { $0.label.count == 1 && $0.label.first!.isLetter }.count == 26)
        #expect(KeyboardLayout.keys.allSatisfy { $0.x >= 0 && $0.x + $0.width <= 600 && $0.y + $0.height <= 400 })
    }
    @Test func shortTapIsVisibleThenReleased() {
        var state = InteractionState(now: 0)
        state.handle(.keyDown(code: 0, isRepeat: false), at: 0)
        state.handle(.keyUp(code: 0), at: 0.01)
        #expect(state.snapshot(at: 0.099).keys == [0])
        #expect(state.snapshot(at: 0.101).keys.isEmpty)
    }
    @Test func heldKeyDoesNotExpireUntilRelease() {
        var state = InteractionState(now: 0)
        state.handle(.keyDown(code: 49, isRepeat: false), at: 0)
        #expect(state.snapshot(at: 20).keys == [49])
        #expect(!state.snapshot(at: 20).resting)
        #expect(state.nextTransition(after: 20) == nil)
        state.handle(.keyUp(code: 49), at: 20)
        #expect(state.snapshot(at: 20).keys.isEmpty)
    }
    @Test func combinationsAndMouseAreIndependent() {
        var state = InteractionState(now: 0)
        state.handle(.keyDown(code: 55, isRepeat: false), at: 0)
        state.handle(.keyDown(code: 8, isRepeat: false), at: 0.01)
        state.handle(.mouseDown(button: .right), at: 0.02)
        let snapshot = state.snapshot(at: 1)
        #expect(snapshot.keys == [55, 8])
        #expect(snapshot.buttons == [.right])
        state.handle(.keyUp(code: 8), at: 1)
        #expect(state.snapshot(at: 1).keys == [55])
        #expect(state.snapshot(at: 1).buttons == [.right])
    }
    @Test func repeatDoesNotMovePawToDifferentKey() {
        var state = InteractionState(now: 0)
        state.handle(.keyDown(code: 0, isRepeat: false), at: 0)
        state.handle(.keyDown(code: 0, isRepeat: true), at: 0.2)
        #expect(state.snapshot(at: 0.3).leftKey == 0)
        state.handle(.keyDown(code: 65535, isRepeat: false), at: 0.3)
        #expect(state.snapshot(at: 0.3).keys == [0])
    }
    @Test func mouseButtonsAndReleaseAreDistinct() {
        var state = InteractionState(now: 0)
        for button in [MouseButton.left, .right, .middle] { state.handle(.mouseDown(button: button), at: 0) }
        state.handle(.mouseUp(button: .right), at: 0.01)
        #expect(state.snapshot(at: 0.1).buttons == [.left, .right, .middle])
        #expect(state.snapshot(at: 0.13).buttons == [.left, .middle])
        state.handle(.mouseUp(button: .left), at: 0.2)
        state.handle(.mouseUp(button: .middle), at: 0.2)
        #expect(state.snapshot(at: 0.2).buttons.isEmpty)
    }
    @Test func scrollMergesBothAxesAndExpires() {
        var state = InteractionState(now: 0)
        state.handle(.scroll(dx: 2, dy: -3), at: 0)
        state.handle(.scroll(dx: 4, dy: -1), at: 0.1)
        #expect(state.snapshot(at: 0.2).scrollX == 6)
        #expect(state.snapshot(at: 0.2).scrollY == -4)
        #expect(state.snapshot(at: 0.281).scrollX == 0)
        state.handle(.scroll(dx: -2, dy: 0), at: 1)
        #expect(state.snapshot(at: 1).scrollX == -2)
    }
    @Test func resetAndBackwardClockClearHeldInputs() {
        var state = InteractionState(now: 0)
        state.handle(.keyDown(code: 0, isRepeat: false), at: 1)
        state.handle(.mouseDown(button: .left), at: 1)
        state.handle(.scroll(dx: 1, dy: 1), at: 1)
        #expect(state.snapshot(at: 0).keys.isEmpty)
        #expect(state.snapshot(at: 0).buttons.isEmpty)
        state.handle(.keyDown(code: 0, isRepeat: false), at: 1)
        state.reset(at: 2)
        #expect(state.snapshot(at: 2).keys.isEmpty)
        #expect(state.snapshot(at: 17).resting)
    }
    @Test func realCountsSeparateMouseButtonsAndScroll() {
        var counts = InputActivity()
        counts.record(DeviceInput.keyDown(code: 0, isRepeat: false))
        counts.record(DeviceInput.keyDown(code: 0, isRepeat: true))
        counts.record(DeviceInput.keyUp(code: 0))
        for button in [MouseButton.left, .right, .middle] {
            counts.record(DeviceInput.mouseDown(button: button))
            counts.record(DeviceInput.mouseUp(button: button))
        }
        counts.record(DeviceInput.scroll(dx: 0, dy: 1))
        #expect(counts.keyPresses == 1)
        #expect(counts.leftClicks == 1 && counts.rightClicks == 1 && counts.middleClicks == 1)
        #expect(counts.scrollEvents == 1)
    }
    @Test func scrollReversalShowsLatestDirectionImmediately() {
        var state = InteractionState(now:0)
        state.handle(.scroll(dx:0,dy:3),at:0)
        state.handle(.scroll(dx:0,dy:-1),at:0.05)
        #expect(state.snapshot(at:0.05).scrollY < 0)
    }
    @Test func capsLockCanStayLitWhilePetRests() {
        var state = InteractionState(now:0)
        state.handle(.keyDown(code:57,isRepeat:false),at:0)
        #expect(state.snapshot(at:16).keys == [57])
        #expect(state.snapshot(at:16).resting)
    }

}
