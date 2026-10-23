import Testing
@testable import BubuCore

struct InputActivityTests {
    @Test func receivedKeysAreCountedWithoutKeepingTheirContents() {
        var activity = InputActivity()
        activity.record(.keyDown(code:0,isRepeat:false))
        activity.record(.keyDown(code:0,isRepeat:true))
        activity.record(.mouseDown(button:.left))
        #expect(activity.keyPresses == 1)
        #expect(activity.mouseClicks == 1)
        #expect(activity.hasReceivedInput)
    }

    @Test func demoDoesNotPretendGlobalInputWasReceived() {
        let activity = InputActivity()
        var pose = InteractionState(now: 0)
        pose.handle(.keyDown(code:0,isRepeat:false), at: 0)
        #expect(pose.snapshot(at:0).keys == [0])
        #expect(!activity.hasReceivedInput)
    }
}
