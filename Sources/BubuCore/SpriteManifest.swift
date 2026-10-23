import Foundation

public struct SpriteManifest: Decodable, Sendable {
    public static let poseNames = ["idle", "leftTap", "rightTap", "mouseTap", "blink", "resting"]
    public let canvasWidth: Int
    public let canvasHeight: Int
    private let poses: [String: String]

    public init(data: Data) throws {
        self = try JSONDecoder().decode(Self.self, from: data)
        guard (1...8192).contains(canvasWidth), (1...8192).contains(canvasHeight),
              canvasWidth * 2 == canvasHeight * 3 else { throw InvalidManifest.canvas }
        for name in Self.poseNames {
            guard let file = poses[name], file.hasSuffix(".png"),
                  file.range(of: "^[A-Za-z0-9_-]+\\.png$", options: .regularExpression) != nil
            else { throw InvalidManifest.pose(name) }
        }
    }

    public func fileName(for pose: String) -> String? { poses[pose] }

    private enum InvalidManifest: Error {
        case canvas, pose(String)
    }
}
