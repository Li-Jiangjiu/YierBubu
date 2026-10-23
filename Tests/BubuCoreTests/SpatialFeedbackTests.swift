import Testing
@testable import BubuCore

struct SpatialFeedbackTests {
    @Test func mouseButtonsFollowBubusOwnHands() {
        let left=MouseSceneLayout.contact(for:.left)
        let right=MouseSceneLayout.contact(for:.right)
        // BuBu faces the lower-left front of the mouse: its own left lies lower-right on screen.
        #expect(left.x+left.y > MouseSceneLayout.wheel.x+MouseSceneLayout.wheel.y)
        #expect(right.x+right.y < MouseSceneLayout.wheel.x+MouseSceneLayout.wheel.y)
        #expect(MouseSceneLayout.contains(left,button:.left))
        #expect(MouseSceneLayout.contains(right,button:.right))
        #expect(!MouseSceneLayout.contains(left,button:.right))
        #expect(MouseSceneLayout.contact(for:.middle) == MouseSceneLayout.wheel)
    }
    @Test func raisedKeycapsHaveThicknessAndCompressOnPress() {
        for key in CompactSceneLayout.keys {
            #expect(key.baseY > key.surfaceCenter(pressed:false).y)
            #expect(key.surfaceCenter(pressed:true).y > key.surfaceCenter(pressed:false).y)
            #expect(key.baseY > key.surfaceCenter(pressed:true).y)
        }
    }
    @Test func eachPawActuallyTouchesItsSelectedKey() {
        var endpoints=Set<String>()
        for key in CompactSceneLayout.keys {
            let pose=PawPose.typing(code:key.code)!
            #expect(key.containsSurface(pose.contact,pressed:true))
            #expect(abs(pose.tip.x-pose.contact.x) < 0.001)
            #expect(abs(pose.tip.y-pose.contact.y) < 0.001)
            #expect(pose.shoulder == PawPose.idle(left:key.leftPaw).shoulder)
            #expect(pose.center.x > 450 && pose.center.x < 1380)
            #expect(pose.center.y > 580 && pose.center.y < 995)
            endpoints.insert("\(pose.contact.x),\(pose.contact.y)")
        }
        #expect(endpoints.count == 36)
        #expect(PawPose.typing(code:0)?.contact != PawPose.typing(code:1)?.contact)
        #expect(PawPose.typing(code:55) == nil)
    }
    @Test func heldKeyFallbackAndTwoHandsStayIndependent() {
        var state=InteractionState(now:0)
        state.handle(.keyDown(code:0,isRepeat:false),at:0)
        state.handle(.keyDown(code:1,isRepeat:false),at:0.2)
        state.handle(.keyDown(code:38,isRepeat:false),at:0.21)
        state.handle(.mouseDown(button:.left),at:0.22)
        #expect(state.snapshot(at:0.4).leftKey == 1)
        #expect(state.snapshot(at:0.4).rightKey == 38)
        state.handle(.keyUp(code:1),at:0.5)
        #expect(state.snapshot(at:0.5).leftKey == 0)
        #expect(state.snapshot(at:0.5).rightKey == 38)
        #expect(state.snapshot(at:0.5).buttons == [.left])
    }
    @Test func returnEndpointsMatchTheUnrotatedApprovedPaws() {
        #expect(PawPose.idle(left:true).angle == 0)
        #expect(PawPose.idle(left:false).angle == 0)
        #expect(PawPose.idleMouse.angle == 0)
        #expect(PawPose.idle(left:true).center == ScenePoint(835,661))
        #expect(PawPose.idle(left:false).center == ScenePoint(1130,740))
    }
    @Test func rapidRetargetStartsAtCurrentPoseAndEventuallySettles() {
        var motion=PawMotion(pose:PawPose.idle(left:true))
        motion.retarget(PawPose.typing(code:0)!,at:0)
        let halfway=motion.pose(at:0.035)
        motion.retarget(PawPose.typing(code:1)!,at:0.035)
        #expect(motion.pose(at:0.035) == halfway)
        #expect(motion.pose(at:1) == PawPose.typing(code:1)!)
        #expect(!motion.isAnimating(at:1))
        motion.retarget(PawPose.idle(left:true),at:1)
        #expect(motion.pose(at:2) == PawPose.idle(left:true))
    }
}
