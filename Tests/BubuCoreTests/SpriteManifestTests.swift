import Foundation
import Testing
@testable import BubuCore

struct SpriteManifestTests {
    private func data(width: Int = 1536, height: Int = 1024,
                      idle: String = "idle.png", missing: String? = nil) throws -> Data {
        var poses = ["idle": idle, "leftTap": "leftTap.png", "rightTap": "rightTap.png",
                     "mouseTap": "mouseTap.png", "blink": "blink.png", "resting": "resting.png"]
        if let missing { poses.removeValue(forKey: missing) }
        return try JSONSerialization.data(withJSONObject: [
            "canvasWidth": width, "canvasHeight": height, "poses": poses])
    }

    @Test func validManifestResolvesAllAnimationStates() throws {
        let manifest = try SpriteManifest(data: data())
        #expect(manifest.canvasWidth == 1536)
        #expect(manifest.fileName(for: "resting") == "resting.png")
        #expect(manifest.fileName(for: "unknown") == nil)
    }

    @Test func incompleteAnimationSetIsRejected() throws {
        let json = try data(missing: "blink")
        #expect(throws: (any Error).self) { try SpriteManifest(data: json) }
    }

    @Test func pathsCannotEscapeSpriteDirectory() throws {
        for filename in ["../idle.png", "/tmp/idle.png", "sub/idle.png", "idle.jpg"] {
            let json = try data(idle: filename)
            #expect(throws: (any Error).self) { try SpriteManifest(data: json) }
        }
    }

    @Test func invalidCanvasCannotDistortAnimation() throws {
        for (width, height) in [(0, 1024), (1536, -1), (100, 100), (30_000, 20_000)] {
            let json = try data(width: width, height: height)
            #expect(throws: (any Error).self) { try SpriteManifest(data: json) }
        }
    }
}
