import Foundation

/// The mouse nose points lower-left, away from BuBu. Handedness is character-relative.
public enum MouseSceneLayout {
    public static let wheel=ScenePoint(280,601)
    public static let forward=ScenePoint(-1,1)
    public static func region(for button:MouseButton)->[ScenePoint] {
        switch button {
        case .left: [ScenePoint(356,553),ScenePoint(395,564),ScenePoint(407,591),ScenePoint(350,637),ScenePoint(286,653),ScenePoint(307,601)]
        case .right: [ScenePoint(250,577),ScenePoint(314,553),ScenePoint(356,553),ScenePoint(307,601),ScenePoint(224,633)]
        case .middle: [ScenePoint(254,619),ScenePoint(295,578),ScenePoint(306,587),ScenePoint(265,628)]
        }
    }
    public static func contact(for button:MouseButton)->ScenePoint {
        switch button {
        case .left: ScenePoint(324,622)
        case .right: ScenePoint(255,592)
        case .middle: wheel
        }
    }
    public static func contains(_ point:ScenePoint,button:MouseButton)->Bool {
        let points=region(for:button)
        var inside=false
        for i in points.indices {
            let a=points[i],b=points[(i+1)%points.count]
            if (a.y>point.y) != (b.y>point.y), point.x < (b.x-a.x)*(point.y-a.y)/(b.y-a.y)+a.x { inside.toggle() }
        }
        return inside
    }
}
