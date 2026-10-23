import AppKit

@MainActor
final class LayeredAssets {
    let scene: NSImage?
    let cleanplate: NSImage?
    let paws: NSImage?
    let issue: String?
    init(root: URL = LayeredAssets.locate()) {
        func load(_ name: String) -> NSImage? {
            guard let image=NSImage(contentsOf:root.appendingPathComponent(name)),image.isValid,
                  let cg=image.cgImage(forProposedRect:nil,context:nil,hints:nil),
                  cg.width==1536,cg.height==1024 else { return nil }
            return image
        }
        if let scene=load("compact-scene.png"),let plate=load("compact-cleanplate.png"),let paws=load("compact-paws.png") {
            self.scene=scene;cleanplate=plate;self.paws=paws;issue=nil
        } else {
            scene=nil;cleanplate=nil;paws=nil;issue="紧凑场景或动画补底缺失，请重新安装应用"
        }
    }
    static func locate() -> URL {
        if Bundle.main.bundleURL.pathExtension == "app", let root=Bundle.main.resourceURL {
            return root.appendingPathComponent("Layered")
        }
        // Unbundled developer commands run from the repository root, or pass --layer-root.
        // Avoid embedding the builder's personal absolute source path in distributed binaries.
        return URL(fileURLWithPath:FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Resources/Layered")
    }
}
