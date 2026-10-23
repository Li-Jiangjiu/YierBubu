import AppKit

if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--validate-sprites" {
    let loader = SpriteLoader(resourceRoot: URL(fileURLWithPath: CommandLine.arguments[2]))
    if let issue = loader.issue {
        fputs("Sprite validation failed: \(issue)\n", stderr)
        exit(1)
    }
    print("Validated all 6 sprite frames and their canvas sizes.")
    exit(0)
}

if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--validate-layers" {
    let assets=LayeredAssets(root:URL(fileURLWithPath:CommandLine.arguments[2]))
    if let issue=assets.issue { fputs("Layer validation failed: \(issue)\n",stderr);exit(1) }
    print("Validated approved compact scene and animation cleanplate at 1536×1024.")
    exit(0)
}

let application = NSApplication.shared
let controller = AppController()
application.delegate = controller
application.setActivationPolicy(.accessory)
application.run()
