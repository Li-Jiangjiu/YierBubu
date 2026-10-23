import Testing
@testable import BubuCore

struct InputNormalizerTests {
    @Test func rightShiftReleaseKeepsLeftShiftHeld() {
        var state = InteractionState(now: 0)
        let events: [(UInt16, UInt64)] = [(56,0x20002),(60,0x20006),(60,0x20002)]
        for (code, flags) in events {
            if let input = InputNormalizer.modifier(code: code, flags: flags) { state.handle(input, at: 0) }
        }
        #expect(state.snapshot(at: 0.2).keys == [56])
    }
    @Test func capsLockTracksLockStateAndFnIsNotMapped() {
        var state = InteractionState(now: 0)
        state.handle(InputNormalizer.modifier(code: 57, flags: 0x10000)!, at: 0)
        #expect(state.snapshot(at: 1).keys == [57])
        state.handle(InputNormalizer.modifier(code: 57, flags: 0)!, at: 1)
        #expect(state.snapshot(at: 1).keys.isEmpty)
        #expect(InputNormalizer.modifier(code: 63, flags: 0x800000) == nil)
    }
    @Test func buttonNumbersDoNotTurnSideButtonsIntoMiddleClick() {
        #expect(InputNormalizer.button(number: 0) == .left)
        #expect(InputNormalizer.button(number: 1) == .right)
        #expect(InputNormalizer.button(number: 2) == .middle)
        #expect(InputNormalizer.button(number: 3) == nil)
    }
}
