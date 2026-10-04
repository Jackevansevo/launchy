import SwiftUI
import Carbon.HIToolbox
import ServiceManagement

@main struct MyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @AppStorage(LauncherShortcut.defaultsKey) private var shortcut = LauncherShortcut.optionSpace

    var body: some Scene {
        // The launcher window is an NSPanel owned by AppDelegate, so there's no WindowGroup here.
        MenuBarExtra("Launchy", systemImage: "magnifyingglass") {
            Button("Toggle Launchy") { appDelegate.panel?.toggle() }
                .keyboardShortcut(.space, modifiers: shortcut.eventModifiers)
            Divider()
            // Shown as a submenu with a checkmark on the current choice.
            Picker("Shortcut", selection: Binding(
                get: { shortcut },
                set: { newValue in
                    shortcut = newValue
                    appDelegate.registerHotKey(newValue)
                    if newValue.isTakenBySystem { appDelegate.explainSpotlightConflict() }
                }
            )) {
                ForEach(LauncherShortcut.allCases, id: \.self) { Text($0.title) }
            }
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

        registerHotKey(.current)
    }

    /// Makes `shortcut` toggle the launcher from anywhere, replacing the previous one.
    func registerHotKey(_ shortcut: LauncherShortcut) {
        hotKey = nil // Unregister first, since both shortcuts share a hot key ID.
        hotKey = GlobalHotKey(keyCode: kVK_Space, modifiers: shortcut.carbonModifiers) { [weak self] in
            self?.panel?.toggle()
        }
    }

    /// System shortcuts take priority and apps can't change them, so the user has to turn Spotlight's off, as with Raycast and Alfred.
    func explainSpotlightConflict() {
        let alert = NSAlert()
        alert.messageText = "Turn Off Spotlight's Shortcut"
        alert.informativeText = "Spotlight also uses ⌘Space. To use it for Launchy, go to Keyboard Shortcuts → Spotlight and turn off “Show Spotlight search”."
        alert.addButton(withTitle: "Open Keyboard Settings")
        alert.addButton(withTitle: "Later")
        NSApp.activate() // Menu bar apps aren't frontmost, so bring the alert forward.
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!)
        }
    }

    // Opening the app again (e.g. from Finder) also brings the launcher back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        panel?.show()
        return true
    }
}

/// The global shortcuts the launcher can use, stored in user defaults.
enum LauncherShortcut: String, CaseIterable {
    case optionSpace
    case commandSpace

    static let defaultsKey = "launcherShortcut"

    static var current: LauncherShortcut {
        UserDefaults.standard.string(forKey: defaultsKey).flatMap(LauncherShortcut.init) ?? .optionSpace
    }

    var title: String {
        switch self {
        case .optionSpace: "⌥ Space"
        case .commandSpace: "⌘ Space"
        }
    }

    var carbonModifiers: Int {
        switch self {
        case .optionSpace: optionKey
        case .commandSpace: cmdKey
        }
    }

    /// Whether an enabled system shortcut (e.g. Spotlight's ⌘Space) already uses this key combination, and so would win.
    var isTakenBySystem: Bool {
        var hotKeys: Unmanaged<CFArray>?
        // If the system won't say, assume it's taken so the user still gets the explanation.
        guard CopySymbolicHotKeys(&hotKeys) == noErr, let hotKeys else { return true }
        return (hotKeys.takeRetainedValue() as NSArray).contains { entry in
            guard let entry = entry as? [String: Any] else { return false }
            return entry[kHISymbolicHotKeyCode] as? Int == kVK_Space
                && entry[kHISymbolicHotKeyModifiers] as? Int == carbonModifiers
                && entry[kHISymbolicHotKeyEnabled] as? Bool == true
        }
    }

    var eventModifiers: SwiftUI.EventModifiers {
        switch self {
        case .optionSpace: .option
        case .commandSpace: .command
        }
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
        centreOnScreen()
        makeKeyAndOrderFront(nil)
    }

    func toggle() {
        if isVisible { orderOut(nil) } else { show() }
    }

    /// Centred horizontally, with its top edge where Spotlight's sits (measured at ~21.8% down the screen).
    private func centreOnScreen() {
        guard let screen = NSScreen.main?.frame else { return }
        // AppKit's origin is bottom-left, so measure down from the top of the screen.
        setFrameOrigin(NSPoint(
            x: screen.midX - frame.width / 2,
            // The content is inset by the shadow margin, so shift the window up by it.
            y: screen.maxY - screen.height * 0.218 - frame.height + ContentView.shadowMargin
        ))
    }
}
