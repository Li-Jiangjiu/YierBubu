import AppKit
import BubuCore

@MainActor
final class AppController: NSObject, NSApplicationDelegate {
    let petWindow = PetWindow()
    let petView = PetView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
    let input = InputMonitor()
    private var state = InteractionState(now: ProcessInfo.processInfo.systemUptime)
    private var statusItem: NSStatusItem?
    private var transitionTimer: Timer?
    private var permissionTimer: Timer?
    private var permissionItem = NSMenuItem()
    private var visibilityItem = NSMenuItem()
    private var passThroughItem = NSMenuItem()
    private var sizeItems: [NSMenuItem] = []
    private var inputSetup: InputSetupWindow?
    private var demoTimers: [Timer] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var sessionActive = true
    private var hidden = false
    private let smoke = CommandLine.arguments.contains("--smoke-test")

    func applicationDidFinishLaunching(_ notification: Notification) {
        petView.autoresizingMask = [.width, .height]
        if let index = CommandLine.arguments.firstIndex(of: "--layer-root"),
           CommandLine.arguments.indices.contains(index + 1) {
            petView.layeredAssets = LayeredAssets(root: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
        }
        petWindow.contentView = petView
        makeMenu()
        input.onInput = { [weak self] event in
            if self?.demoTimers.isEmpty == false { self?.cancelDemo(); self?.resetActions() }
            self?.handle(event)
        }
        input.onReset = { [weak self] in self?.resetActions() }
        input.onStatusChange = { [weak self] value in
            self?.permissionItem.title = value.title
            self?.updateInputSetup()
        }
        input.onActivityChange = { [weak self] _ in self?.updateInputSetup() }
        petWindow.orderFrontRegardless()
        petView.setSuspended(false)
        refresh()
        if smoke {
            runSmokeChecks()
        } else {
            input.start()
            if input.status != .listening { showInputSetup() }
            permissionTimer = Timer.commonModesTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { if self?.sessionActive == true { self?.input.checkPermission() } }
            }
            let center = NSWorkspace.shared.notificationCenter
            for name in [NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
                workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.sessionActive = true
                        self?.resetActions()
                        self?.input.start()
                    }
                })
            }
            workspaceObservers.append(center.addObserver(
                forName: NSWorkspace.willSleepNotification, object:nil, queue:.main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.sessionActive=false; self?.input.stop(); self?.resetActions() }
                })
            workspaceObservers.append(center.addObserver(
                forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.sessionActive=false; self?.input.stop(); self?.resetActions() }
                })
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        if !smoke && sessionActive { input.checkPermission() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        transitionTimer?.invalidate()
        permissionTimer?.invalidate()
        cancelDemo()
        input.onReset = nil
        input.stop()
        petView.setSuspended(true)
        for token in workspaceObservers { NSWorkspace.shared.notificationCenter.removeObserver(token) }
        workspaceObservers.removeAll()
    }

    private func makeMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "ʕ•ᴥ•ʔ"
        item.button?.toolTip = "一二布布 · 桌面陪伴"
        let menu = NSMenu()
        let title = NSMenuItem(title: "一二布布 · 陪你敲键盘", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        permissionItem = NSMenuItem(title: input.status.title, action: nil, keyEquivalent: "")
        menu.addItem(permissionItem)
        let assets = petView.layeredAssets.scene != nil ? "分层角色 · 键鼠独立联动" : "角色身体图层缺失"
        menu.addItem(NSMenuItem(title: assets, action: nil, keyEquivalent: ""))
        if let issue = petView.layeredAssets.issue {
            menu.addItem(NSMenuItem(title: issue, action: nil, keyEquivalent: ""))
        }
        menu.addItem(NSMenuItem(title: "布局：Mac ANSI QWERTY · 显示数字与字母36键", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        visibilityItem = add("隐藏小熊", #selector(toggleVisibility), to: menu)
        passThroughItem = add("鼠标穿透", #selector(togglePassThrough), to: menu)
        let sizeMenu = NSMenu()
        for (tag, label) in [(75, "75%"), (100, "100%"), (125, "125%")] {
            let row = add(label, #selector(changeScale(_:)), to: sizeMenu)
            row.tag = tag
            row.state = tag == 100 ? .on : .off
            sizeItems.append(row)
        }
        let sizeRow = NSMenuItem(title: "小熊大小", action: nil, keyEquivalent: "")
        sizeRow.submenu = sizeMenu
        menu.addItem(sizeRow)
        add("恢复到屏幕右下角", #selector(resetPosition), to: menu)
        add("动作演示", #selector(demonstrate), to: menu)
        menu.addItem(.separator())
        add("连接键盘与查看状态…", #selector(showInputSetup), to: menu)
        add("启用输入监听…", #selector(requestPermission), to: menu)
        add("打开输入监控设置…", #selector(openPrivacy), to: menu)
        add("重新检测权限", #selector(recheckPermission), to: menu)
        menu.addItem(NSMenuItem(title: "授权后若无反应，请退出再打开应用", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        let quit = add("退出一二布布", #selector(quit), to: menu)
        quit.keyEquivalent = "q"
        item.menu = menu
        statusItem = item
    }

    @discardableResult
    private func add(_ title: String, _ action: Selector, to menu: NSMenu) -> NSMenuItem {
        let row = NSMenuItem(title: title, action: action, keyEquivalent: "")
        row.target = self
        menu.addItem(row)
        return row
    }

    private func handle(_ event: DeviceInput) {
        state.handle(event, at: ProcessInfo.processInfo.systemUptime)
        refresh()
    }

    private func resetActions() {
        cancelDemo()
        state.reset(at: ProcessInfo.processInfo.systemUptime)
        refresh()
    }

    private func refresh() {
        transitionTimer?.invalidate()
        transitionTimer = nil
        let now = ProcessInfo.processInfo.systemUptime
        let snapshot = state.snapshot(at:now)
        petView.setInteraction(hidden ? InteractionSnapshot() : snapshot)
        guard let next = state.nextTransition(after: now) else { return }
        transitionTimer = Timer.commonModesTimer(withTimeInterval: max(0.001, next - now), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    @objc func toggleVisibility() {
        hidden.toggle()
        visibilityItem.title = hidden ? "显示小熊" : "隐藏小熊"
        petView.setSuspended(hidden)
        if hidden {
            let wasDemonstrating = !demoTimers.isEmpty
            cancelDemo()
            if wasDemonstrating { state.reset(at:ProcessInfo.processInfo.systemUptime) }
            refresh()
            petWindow.orderOut(nil)
        } else {
            petWindow.orderFrontRegardless()
            refresh()
        }
    }

    @objc func togglePassThrough() {
        let enabled = !petWindow.ignoresMouseEvents
        petWindow.setClickThrough(enabled)
        passThroughItem.state = enabled ? .on : .off
    }

    @objc private func changeScale(_ sender: NSMenuItem) {
        petWindow.setScale(Double(sender.tag) / 100)
        for item in sizeItems { item.state = item === sender ? .on : .off }
    }

    @objc private func resetPosition() { petWindow.resetPosition() }

    @objc func demonstrate() {
        cancelDemo()
        if hidden { toggleVisibility() }
        resetActions()
        let events: [(Double, DeviceInput)] = [
            (0.2,.keyDown(code:0,isRepeat:false)),(0.45,.keyUp(code:0)),
            (0.6,.keyDown(code:1,isRepeat:false)),(0.85,.keyUp(code:1)),
            (1.0,.keyDown(code:2,isRepeat:false)),(1.25,.keyUp(code:2)),
            (1.5,.keyDown(code:55,isRepeat:false)),(1.55,.keyDown(code:8,isRepeat:false)),
            (1.9,.keyUp(code:8)),(1.95,.keyUp(code:55)),
            (2.2,.mouseDown(button:.left)),(2.5,.mouseUp(button:.left)),
            (2.8,.mouseDown(button:.right)),(3.1,.mouseUp(button:.right)),
            (3.4,.mouseDown(button:.middle)),(3.7,.mouseUp(button:.middle)),
            (4.0,.scroll(dx:0,dy:4)),(4.4,.scroll(dx:0,dy:-4)),
            (4.8,.scroll(dx:4,dy:0)),(5.2,.scroll(dx:-4,dy:0))
        ]
        for (delay,event) in events {
            demoTimers.append(Timer.commonModesTimer(withTimeInterval:delay,repeats:false) { [weak self] _ in
                MainActor.assumeIsolated { self?.handle(event) }
            })
        }
        demoTimers.append(Timer.commonModesTimer(withTimeInterval:5.6,repeats:false) { [weak self] _ in
            MainActor.assumeIsolated { self?.cancelDemo(); self?.resetActions() }
        })
    }

    private func cancelDemo() {
        demoTimers.forEach { $0.invalidate() }
        demoTimers.removeAll()
    }

    @objc private func showInputSetup() {
        if inputSetup == nil {
            let setup = InputSetupWindow()
            setup.onRequest = { [weak self] in self?.input.requestPermission() }
            setup.onOpenSettings = { [weak self] in self?.openPrivacy() }
            setup.onRecheck = { [weak self] in self?.input.start() }
            setup.onRestart = { [weak self] in self?.restartApplication() }
            inputSetup = setup
        }
        updateInputSetup()
        inputSetup?.present()
    }

    private func updateInputSetup() {
        inputSetup?.update(status: input.status, activity: input.activity)
    }

    private func restartApplication() {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
            if error == nil {
                DispatchQueue.main.async { NSApplication.shared.terminate(nil) }
            }
        }
    }

    @objc private func requestPermission() { input.requestPermission() }
    @objc private func recheckPermission() { input.start() }
    @objc private func openPrivacy() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }
    @objc private func quit() { NSApplication.shared.terminate(nil) }

    private func runSmokeChecks() {
        DispatchQueue.main.asyncAfter(deadline:.now()+0.4) { [self] in
            var checks:[String:Bool]=[:]
            checks["preciseDeviceScene"] = (petView.accessibilityValue() as? String)?.contains("ANSI QWERTY") == true
            checks["layeredBodiesLoaded"] = petView.layeredAssets.scene != nil
            if CommandLine.arguments.contains("--allow-missing-layer") { checks.removeValue(forKey:"layeredBodiesLoaded") }
            checks["transparent"] = !petWindow.isOpaque && petWindow.backgroundColor == .clear
            checks["floating"] = petWindow.level == .floating
            checks["nonactivating"] = !petWindow.canBecomeKey
            checks["defaultSize"] = petWindow.frame.size == NSSize(width:300,height:200)
            togglePassThrough(); checks["passThroughEnabled"] = petWindow.ignoresMouseEvents
            togglePassThrough(); checks["passThroughRestored"] = !petWindow.ignoresMouseEvents
            toggleVisibility(); checks["hidden"] = !petWindow.isVisible && petView.interaction.keys.isEmpty
            toggleVisibility(); checks["shown"] = petWindow.isVisible
            for scale in [0.75,1.25,1.0] {
                petWindow.setScale(scale)
                checks["scale\(scale)"] = abs(petWindow.frame.width - 300*scale) < 0.1
            }
            resetActions()
            handle(.keyDown(code:0,isRepeat:false));handle(.keyUp(code:0))
            let trackingEnd=Date(timeIntervalSinceNow:0.18)
            while Date()<trackingEnd { _=RunLoop.main.run(mode:.eventTracking,before:trackingEnd) }
            checks["actionExpiresDuringMenuTracking"] = petView.interaction.keys.isEmpty
            func runTimers(_ duration:TimeInterval) {
                let end=Date(timeIntervalSinceNow:duration)
                while Date()<end { _=RunLoop.main.run(mode:.default,before:end) }
            }
            demonstrate();runTimers(0.25)
            checks["demoReallyReachedHeldKey"] = petView.interaction.keys == [0]
            toggleVisibility();toggleVisibility()
            checks["hideCancelsDemoHeldInputs"] = petView.interaction.keys.isEmpty
            demonstrate();resetActions();runTimers(0.3)
            checks["resetCancelsPendingDemoEvents"] = petView.interaction.keys.isEmpty
            cancelDemo();resetActions()
            handle(.keyDown(code:0,isRepeat:false));toggleVisibility()
            checks["hiddenViewClearsKeyCodes"] = petView.interaction.keys.isEmpty
            handle(.keyUp(code:0));runTimers(0.15)
            checks["hiddenCleanupSchedulesIdleWake"] = (transitionTimer?.fireDate.timeIntervalSinceNow ?? -1) > 14
            toggleVisibility()
            input.stop();input.stop();checks["stopIdempotent"] = input.status == .stopped
            let frames:[(String,[DeviceInput])]=[
                ("idle",[]),("hidden-command",[.keyDown(code:55,isRepeat:false)]),("key-J",[.keyDown(code:38,isRepeat:false)]),("key-A",[.keyDown(code:0,isRepeat:false)]),
                ("key-S",[.keyDown(code:1,isRepeat:false)]),("key-D",[.keyDown(code:2,isRepeat:false)]),
                ("command-C",[.keyDown(code:55,isRepeat:false),.keyDown(code:8,isRepeat:false)]),
                ("mouse-left",[.mouseDown(button:.left)]),("mouse-right",[.mouseDown(button:.right)]),
                ("mouse-middle",[.mouseDown(button:.middle)]),("scroll-up",[.scroll(dx:0,dy:3)]),
                ("scroll-down",[.scroll(dx:0,dy:-3)]),("scroll-left",[.scroll(dx:3,dy:0)]),
                ("scroll-right",[.scroll(dx:-3,dy:0)]),
                ("simultaneous",[.keyDown(code:0,isRepeat:false),.mouseDown(button:.right)]),
                ("two-hands",[.keyDown(code:0,isRepeat:false),.keyDown(code:38,isRepeat:false)]),
                ("mouse-both",[.mouseDown(button:.left),.mouseDown(button:.right)]),
                ("key-1",[.keyDown(code:18,isRepeat:false)]),("key-0",[.keyDown(code:29,isRepeat:false)]),
                ("key-Q",[.keyDown(code:12,isRepeat:false)]),("key-P",[.keyDown(code:35,isRepeat:false)]),
                ("key-L",[.keyDown(code:37,isRepeat:false)]),("key-Z",[.keyDown(code:6,isRepeat:false)]),
                ("key-M",[.keyDown(code:46,isRepeat:false)])
            ]
            var output:URL?
            if let index=CommandLine.arguments.firstIndex(of:"--smoke-output"),CommandLine.arguments.indices.contains(index+1) {
                output=URL(fileURLWithPath:CommandLine.arguments[index+1])
            }
            do {
                if let output { try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true) }
                var descriptions:[String:String]=[:]
                var hashes:[String:Data]=[:]
                for (name,events) in frames {
                    resetActions()
                    for event in events { handle(event) }
                    runTimers(0.09)
                    petView.displayIfNeeded()
                    descriptions[name]=petView.accessibilityValue() as? String
                    if let bitmap=petView.bitmapImageRepForCachingDisplay(in:petView.bounds) {
                        petView.cacheDisplay(in:petView.bounds,to:bitmap)
                        if let data=bitmap.representation(using:.png,properties:[:]) {
                            hashes[name]=data
                            if let output { try data.write(to:output.appendingPathComponent(name+".png")) }
                        }
                    }
                }
                // High-resolution exports make patch seams and generated glyph remnants inspectable.
                if let output {
                    let large=PetView(frame:NSRect(x:0,y:0,width:1536,height:1024))
                    large.layeredAssets=petView.layeredAssets
                    for (name,events) in frames where ["idle","key-A","key-J","key-1","key-0","key-Z","key-M","two-hands","mouse-left","mouse-right"].contains(name) {
                        var model=InteractionState(now:0)
                        for event in events { model.handle(event,at:0) }
                        large.setInteraction(model.snapshot(at:0))
                        if let bitmap=large.bitmapImageRepForCachingDisplay(in:large.bounds) {
                            large.cacheDisplay(in:large.bounds,to:bitmap)
                            try bitmap.representation(using:.png,properties:[:])?.write(to:output.appendingPathComponent(name+"-large.png"))
                        }
                    }
                }
                var allKeyFrames=Set<Data>()
                var allContactsVisible=true
                for key in CompactSceneLayout.keys {
                    resetActions();handle(.keyDown(code:key.code,isRepeat:false));runTimers(0.09)
                    if let bitmap=petView.bitmapImageRepForCachingDisplay(in:petView.bounds) {
                        petView.cacheDisplay(in:petView.bounds,to:bitmap)
                        if let data=bitmap.representation(using:.png,properties:[:]) {
                            allKeyFrames.insert(data)
                            if let pose=PawPose.typing(code:key.code) {
                                let color=bitmap.colorAt(x:Int(pose.center.x*Double(bitmap.pixelsWide)/1536),
                                                         y:Int(pose.center.y*Double(bitmap.pixelsHigh)/1024))?.usingColorSpace(.deviceRGB)
                                allContactsVisible = allContactsVisible && (color?.blueComponent ?? 0)>0.97 && (color?.greenComponent ?? 0)>0.97
                            } else { allContactsVisible=false }
                            if let output { try data.write(to:output.appendingPathComponent("physical-"+key.label+".png")) }
                        }
                    }
                }
                checks["all36PawsVisiblyReachKeyTargets"] = allContactsVisible
                checks["all36PhysicalKeysHaveUniqueFeedback"] = allKeyFrames.count == 36
                func sample(_ name:String,_ point:ScenePoint)->NSColor? {
                    guard let data=hashes[name],let bitmap=NSBitmapImageRep(data:data) else { return nil }
                    return bitmap.colorAt(x:Int(point.x*Double(bitmap.pixelsWide)/1536),
                                          y:Int(point.y*Double(bitmap.pixelsHigh)/1024))?.usingColorSpace(.deviceRGB)
                }
                for (name,code) in [("key-A",UInt16(0)),("key-S",1),("key-J",38)] {
                    let color=PawPose.typing(code:code).flatMap { sample(name,$0.center) }
                    checks["\(name)PawAtTarget"] = (color?.blueComponent ?? 0)>0.97 && (color?.greenComponent ?? 0)>0.97
                }
                checks["leftMouseIsBubusLeft"] = (sample("mouse-left",ScenePoint(335,636))?.blueComponent ?? 1) < (sample("mouse-right",ScenePoint(335,636))?.blueComponent ?? 0)-0.08
                checks["rightMouseIsBubusRight"] = (sample("mouse-right",ScenePoint(245,623))?.blueComponent ?? 1) < (sample("mouse-left",ScenePoint(245,623))?.blueComponent ?? 0)-0.08
                checks["hiddenKeyDoesNotLightDifferentCap"] = hashes["hidden-command"] == hashes["idle"] && hashes["idle"] != nil
                checks["twoTypingPawsHaveDistinctFrames"] = hashes["key-J"] != hashes["key-A"] && hashes["key-J"] != nil
                checks["middleButtonDistinctPixels"] = hashes["mouse-middle"] != hashes["mouse-left"] && hashes["mouse-middle"] != hashes["mouse-right"]
                checks["bothScrollAxesDistinct"] = hashes["scroll-left"] != hashes["scroll-right"] && hashes["scroll-left"] != hashes["scroll-up"]
                checks["AAndSDistinctPixels"] = hashes["key-A"] != hashes["key-S"] && hashes["key-A"] != nil
                checks["leftAndRightDistinctPixels"] = hashes["mouse-left"] != hashes["mouse-right"] && hashes["mouse-left"] != nil
                checks["scrollDirectionsDistinctPixels"] = hashes["scroll-up"] != hashes["scroll-down"] && hashes["scroll-up"] != nil
                checks["physicalAIsExposed"] = descriptions["key-A"]?.contains("按键：A；") == true
                checks["combinationExposed"] = descriptions["command-C"]?.contains("C + cmd") == true
                checks["simultaneousExposed"] = descriptions["simultaneous"]?.contains("按键：A；鼠标：right") == true
                checks["demoDoesNotCountAsRealInput"] = input.activity.keyPresses == 0 && input.activity.mouseClicks == 0 && input.activity.scrollEvents == 0
                if let output {
                    @MainActor func exportMotion(_ label:String,down:DeviceInput,up:DeviceInput) throws {
                        resetActions();runTimers(0.1);handle(down)
                        for (phase,event) in [("reach",Optional<DeviceInput>.none),("return",Optional(up))] {
                            if let event { handle(event) }
                            for step in 0...4 {
                                if step>0 { runTimers(0.025) }
                                if let bitmap=petView.bitmapImageRepForCachingDisplay(in:petView.bounds) {
                                    petView.cacheDisplay(in:petView.bounds,to:bitmap)
                                    try bitmap.representation(using:.png,properties:[:])?.write(to:output.appendingPathComponent("\(phase)-\(label)-\(step).png"))
                                }
                            }
                        }
                    }
                    try exportMotion("A",down:.keyDown(code:0,isRepeat:false),up:.keyUp(code:0))
                    try exportMotion("mouse",down:.mouseDown(button:.left),up:.mouseUp(button:.left))
                }
                resetActions();runTimers(0.1);petView.blink();petView.displayIfNeeded()
                if let output,let bitmap=petView.bitmapImageRepForCachingDisplay(in:petView.bounds) {
                    petView.cacheDisplay(in:petView.bounds,to:bitmap)
                    try bitmap.representation(using:.png,properties:[:])?.write(to:output.appendingPathComponent("blink.png"))
                }
                if let output {
                    try JSONSerialization.data(withJSONObject:checks,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("smoke.json"))
                    try JSONSerialization.data(withJSONObject:descriptions,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("states.json"))
                }
            } catch { fputs("Smoke output failed: \(error)\n",stderr);exit(1) }
            print("Desktop smoke checks: \(checks)")
            if checks.values.contains(false) { exit(1) }
            NSApplication.shared.terminate(nil)
        }
    }
}
