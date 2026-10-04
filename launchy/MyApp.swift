import SwiftUI
import Carbon.HIToolbox
import ServiceManagement

@main struct MyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some Scene {
        // The launcher window is an NSPanel owned by AppDelegate, so there's no WindowGroup here.
        MenuBarExtra("Launchy", systemImage: "magnifyingglass") {
            Button("Toggle Launchy") { appDelegate.panel?.toggle() }
                .keyboardShortcut(.space, modifiers: .option)
            Divider()
            Toggle("Launch at Login", isOn: Binding(
                get: { launchAtLogin },
                set: { setLaunchAtLogin($0) }
            ))
            Divider()
            Button("Quit Launchy") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Couldn't change launch at login: \(error)")
        }
        // Read back the real state, since registering can fail or need approval in System Settings.
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var panel: LauncherPanel?
    private var hotKey: GlobalHotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = LauncherPanel(rootView: ContentView())
        // Show on the next run loop pass, once SwiftUI has attached the view's key-window observers.
        DispatchQueue.main.async { self.panel?.show() }

        // ⌥Space, since Spotlight already has ⌘Space.
        hotKey = GlobalHotKey(keyCode: kVK_Space, modifiers: optionKey) { [weak self] in
            self?.panel?.toggle()
        }
    }

    // Opening the app again (e.g. from Finder) also brings the launcher back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        panel?.show()
        return true
    }
}

/// A borderless, floating panel that can still take keyboard focus.
/// Plain SwiftUI windows are borderless NSWindows, which refuse key status, so text fields can't be typed into.
final class LauncherPanel: NSPanel {
    init(rootView: some View) {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true // Also sets the floating window level.
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false // ContentView draws Spotlight's shadow itself.
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hostingView = NSHostingView(rootView: rootView)
        contentView = hostingView
        setContentSize(hostingView.fittingSize)
    }

    override var canBecomeKey: Bool { true }

    // Esc hides the launcher.
    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }

    // Clicking anywhere outside the launcher hides it, like Spotlight.
    override func resignKey() {
        super.resignKey()
        orderOut(nil)
    }

    func show() {
        center()
        makeKeyAndOrderFront(nil)
    }

    func toggle() {
        if isVisible { orderOut(nil) } else { show() }
    }
}
