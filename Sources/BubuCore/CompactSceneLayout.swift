import Foundation

public struct ScenePoint: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
}

/// Keycap projections in the approved 1536×1024 scene, not OS keyboard coordinates.
public struct CompactKey: Sendable {
    public let code: UInt16
    public let label: String
    public let center: ScenePoint
    public let across: ScenePoint
    public let depth: ScenePoint
    public let leftPaw: Bool
    public var corners: [ScenePoint] {
        [(-1.0,-1.0),(1,-1),(1,1),(-1,1)].map { u,v in
            ScenePoint(center.x + u*across.x + v*depth.x,
                       center.y + u*across.y + v*depth.y)
        }
    }
}

public enum CompactSceneLayout {
    public static let width = 1536.0
    public static let height = 1024.0
    public static let keys: [CompactKey] = {
        let rows: [(String, [UInt16], ScenePoint, ScenePoint)] = [
            ("1234567890",[18,19,20,21,23,22,26,28,25,29],ScenePoint(632,655),ScenePoint(72.5,22.0)),
            ("qwertyuiop",[12,13,14,15,17,16,32,34,31,35],ScenePoint(597,693),ScenePoint(77.0,22.7)),
            ("asdfghjkl",[0,1,2,3,5,4,38,40,37],ScenePoint(575,731),ScenePoint(80.0,24.3)),
            ("zxcvbnm",[6,7,8,9,11,45,46],ScenePoint(600,782),ScenePoint(86.0,26.5))
        ]
        return rows.enumerated().flatMap { rowIndex, row in
            let (labels,codes,origin,step) = row
            return zip(Array(labels),codes).enumerated().map { index,pair in
                let (label,code) = pair
                let scale = 1 + Double(rowIndex)*0.045
                return CompactKey(code:code,label:String(label),
                    center:ScenePoint(origin.x+Double(index)*step.x,origin.y+Double(index)*step.y),
                    across:ScenePoint(32.5*scale,9.8*scale),depth:ScenePoint(-17.5*scale,13.8*scale),
                    leftPaw:index < 5)
            }
        }
    }()
    private static let index = Dictionary(uniqueKeysWithValues:keys.map { ($0.code,$0) })
    public static func key(for code: UInt16) -> CompactKey? { index[code] }
}

public extension CompactKey {
    /// Cap sidewall stays fixed; only the top surface and lettering travel down.
    var baseY: Double { center.y+8 }
    func surfaceCenter(pressed:Bool)->ScenePoint { ScenePoint(center.x,center.y+(pressed ? 2 : -6)) }
    func surfaceCorners(pressed:Bool)->[ScenePoint] {
        let offset=surfaceCenter(pressed:pressed).y-center.y
        return corners.map { ScenePoint($0.x,$0.y+offset) }
    }
    func containsSurface(_ point:ScenePoint,pressed:Bool)->Bool {
        let center=surfaceCenter(pressed:pressed),x=point.x-center.x,y=point.y-center.y
        let determinant=across.x*depth.y-across.y*depth.x
        let u=(x*depth.y-y*depth.x)/determinant
        let v=(across.x*y-across.y*x)/determinant
        return abs(u)<=1 && abs(v)<=1
    }
    var contact:ScenePoint {
        let top=surfaceCenter(pressed:true)
        return ScenePoint(top.x-depth.x*0.72,top.y-depth.y*0.72)
    }
}
