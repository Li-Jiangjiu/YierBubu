import AppKit
import BubuCore

@MainActor
final class SpriteLoader {
    private var images: [String: NSImage] = [:]
    private(set) var missing: [String] = []
    private(set) var issue: String?
    let resourceRoot: URL

    init(resourceRoot: URL) {
        self.resourceRoot = resourceRoot
        do {
            let manifest = try SpriteManifest(data: Data(contentsOf: resourceRoot.appendingPathComponent("manifest.json")))
            for name in SpriteManifest.poseNames {
                guard let file = manifest.fileName(for: name),
                      let image = NSImage(contentsOf: resourceRoot.appendingPathComponent(file)),
                      image.isValid,
                      let bitmap = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
                      bitmap.width == manifest.canvasWidth, bitmap.height == manifest.canvasHeight
                else { missing.append(name); continue }
                images[name] = image
            }
            if !missing.isEmpty {
                // Never switch between a production sprite and a differently
                // aligned placeholder when only part of a sprite set is present.
                images.removeAll()
                issue = "动作素材缺失或尺寸不一致：" + missing.joined(separator: "、")
            }
        } catch {
            missing = SpriteManifest.poseNames
            issue = "动作清单缺失或格式不正确"
        }
    }

    func image(for name: String) -> NSImage? { images[name] }

    static func locate() -> URL {
        if let resources = Bundle.main.resourceURL,
           Bundle.main.bundleURL.pathExtension == "app" {
            return resources.appendingPathComponent("Sprites", isDirectory: true)
        }
        // Stable source-relative fallback; development does not depend on cwd.
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Sprites", isDirectory: true)
    }
}
