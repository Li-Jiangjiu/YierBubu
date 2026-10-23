import Testing
@testable import BubuCore

struct CompactSceneLayoutTests {
    @Test func compactKeyboardContainsExactlyDigitsAndLetters() {
        let keys = CompactSceneLayout.keys
        #expect(keys.count == 36)
        #expect(Set(keys.map(\.code)).count == 36)
        #expect(Set(keys.map(\.label)) == Set("1234567890qwertyuiopasdfghjklzxcvbnm".map(String.init)))
        for code: UInt16 in [49, 55, 57, 122, 123, 65535] {
            #expect(CompactSceneLayout.key(for: code) == nil)
        }
    }
    @Test func projectedKeysFollowApprovedTablePerspective() {
        let a = CompactSceneLayout.key(for: 0)!
        let s = CompactSceneLayout.key(for: 1)!
        let q = CompactSceneLayout.key(for: 12)!
        #expect(a.center.x < s.center.x && a.center.y < s.center.y)
        #expect(q.center.y < a.center.y)
        #expect(q.center.x > a.center.x)
        #expect(CompactSceneLayout.keys.allSatisfy { key in
            key.corners.allSatisfy { $0.x > 430 && $0.x < 1380 && $0.y > 620 && $0.y < 995 }
        })
        #expect(CompactSceneLayout.key(for: 35)?.label == "p")
    }
    @Test func bottomRowKeepsVAndBWithTheLeftTypingHand() {
        for code: UInt16 in [6,7,8,9,11] {
            var state=InteractionState(now:0)
            state.handle(.keyDown(code:code,isRepeat:false),at:0)
            #expect(state.snapshot(at:0).leftKey == code)
            #expect(state.snapshot(at:0).rightKey == nil)
        }
        for code: UInt16 in [45,46] {
            #expect(CompactSceneLayout.key(for:code)?.leftPaw == false)
        }
    }
    @Test func onlyVisibleKeysChooseTheTwoYierPaws() {
        var state = InteractionState(now: 0)
        // Old screen-x split incorrectly assigns J to the left paw.
        state.handle(.keyDown(code: 38, isRepeat: false), at: 0)
        #expect(state.snapshot(at: 0).rightKey == 38)
        #expect(state.snapshot(at: 0).leftKey == nil)
        state.handle(.keyDown(code: 0, isRepeat: false), at: 0.01)
        state.handle(.keyDown(code: 55, isRepeat: false), at: 0.02)
        let both = state.snapshot(at: 1)
        #expect(both.leftKey == 0 && both.rightKey == 38)
        #expect(both.keys == [0, 38, 55])
        state.handle(.keyUp(code: 0), at: 1)
        #expect(state.snapshot(at: 1).leftKey == nil)
        #expect(state.snapshot(at: 1).rightKey == 38)
    }
}
