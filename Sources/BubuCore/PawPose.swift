import Foundation

/// A paw is positioned by its fingertip contact, not the sprite's center.
public struct PawPose: Equatable, Sendable {
    public let shoulder:ScenePoint
    public let contact:ScenePoint
    public let angle:Double
    public let mouse:Bool
    public var tipOffset:ScenePoint { ScenePoint(-sin(angle)*44,cos(angle)*44) }
    public var center:ScenePoint { ScenePoint(contact.x-tipOffset.x,contact.y-tipOffset.y) }
    public var tip:ScenePoint { ScenePoint(center.x+tipOffset.x,center.y+tipOffset.y) }
    public var elbow:ScenePoint {
        ScenePoint(shoulder.x+(center.x-shoulder.x)*0.50,max(shoulder.y,center.y)+16)
    }
    public static func idle(left:Bool)->PawPose {
        let center=left ? ScenePoint(835,661) : ScenePoint(1130,740)
        return PawPose(shoulder:left ? ScenePoint(905,700) : ScenePoint(1200,765),
                       contact:ScenePoint(center.x,center.y+44),angle:0,mouse:false)
    }
    public static let idleMouse=PawPose(shoulder:ScenePoint(355,539),contact:ScenePoint(352,591),angle:0,mouse:true)
    public static func typing(code:UInt16)->PawPose? {
        guard let key=CompactSceneLayout.key(for:code) else { return nil }
        return PawPose(shoulder:idle(left:key.leftPaw).shoulder,contact:key.contact,angle:0.28,mouse:false)
    }
    public static func mouse(buttons:Set<MouseButton>,scrolling:Bool)->PawPose {
        let button:MouseButton = scrolling || buttons.contains(.middle) || buttons.count>1 ? .middle : buttons.contains(.left) ? .left : .right
        return PawPose(shoulder:idleMouse.shoulder,contact:MouseSceneLayout.contact(for:button),angle:0.75,mouse:true)
    }
    func interpolated(to other:PawPose,amount:Double)->PawPose {
        func point(_ a:ScenePoint,_ b:ScenePoint)->ScenePoint { ScenePoint(a.x+(b.x-a.x)*amount,a.y+(b.y-a.y)*amount) }
        return PawPose(shoulder:point(shoulder,other.shoulder),contact:point(contact,other.contact),
                       angle:angle+(other.angle-angle)*amount,mouse:mouse)
    }
}

/// Retargets from the currently visible pose; no stale animation queue accumulates.
public struct PawMotion: Sendable {
    private var from:PawPose
    private var target:PawPose
    private var started=0.0
    private let duration=0.075
    public init(pose:PawPose) { from=pose;target=pose }
    public mutating func retarget(_ value:PawPose,at now:Double) {
        guard value != target else { return }
        from=pose(at:now);target=value;started=now
    }
    public func pose(at now:Double)->PawPose {
        let t=max(0,min(1,(now-started)/duration))
        if t>=1 { return target }
        return from.interpolated(to:target,amount:t*t*(3-2*t))
    }
    public func isAnimating(at now:Double)->Bool { from != target && now < started+duration }
}

public struct ScenePaws: Sendable {
    public let left:PawPose?
    public let right:PawPose?
    public let mouse:PawPose?
    public init(left:PawPose?,right:PawPose?,mouse:PawPose?) { self.left=left;self.right=right;self.mouse=mouse }
    public init(state:InteractionSnapshot) {
        left=state.leftKey.flatMap { PawPose.typing(code:$0) }
        right=state.rightKey.flatMap { PawPose.typing(code:$0) }
        let scrolling=state.scrollX != 0 || state.scrollY != 0
        mouse=state.buttons.isEmpty && !scrolling ? nil : PawPose.mouse(buttons:state.buttons,scrolling:scrolling)
    }
}
