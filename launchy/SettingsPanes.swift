import AppKit

/// System Settings panes, which Spotlight's index doesn't include. Each is an extension bundle that also supplies the
/// pane's identifier and its sidebar icon.
enum SettingsPanes {
    private static let directory = URL(fileURLWithPath: "/System/Library/ExtensionKit/Extensions")

    /// Names as shown in the System Settings sidebar, the pane's bundle, and other words people search for it by.
    private static let panes: [(name: String, bundle: String, keywords: [String])] = [
        ("About", "AboutExtension", []),
        ("Accessibility", "AccessibilitySettingsExtension", []),
        ("AirDrop & Continuity", "AirDropHandoffExtension", ["Handoff"]),
        ("Appearance", "Appearance", ["Dark Mode", "Light Mode"]),
        ("Apple Account", "AppleIDSettings", ["Apple ID", "iCloud"]),
        ("AppleCare & Warranty", "CoverageSettings", []),
        ("Battery", "PowerPreferences", ["Energy", "Power"]),
        ("Bluetooth", "Bluetooth", []),
        ("Date & Time", "DateAndTime Extension", ["Clock", "Time Zone"]),
        ("Desktop & Dock", "DesktopSettings", ["Dock", "Mission Control", "Hot Corners", "Stage Manager"]),
        ("Displays", "DisplaysExt", ["Monitor", "Resolution", "Night Shift"]),
        ("Family", "FamilySettings", []),
        ("Focus", "FocusSettingsExtension", ["Do Not Disturb"]),
        ("Game Center", "GameCenterMacOSSettingsExtension", []),
        ("Game Controllers", "GameControllerMacSettings", []),
        ("General", "GeneralSettings", []),
        ("Internet Accounts", "InternetAccountsSettingsExtension", ["Mail Accounts"]),
        ("Keyboard", "KeyboardSettings", ["Shortcuts", "Dictation"]),
        ("Language & Region", "Localization", ["Language", "Region"]),
        ("Lock Screen", "LockScreen", []),
        ("Login Items", "LoginItems", ["Startup", "Background"]),
        ("Menu Bar", "ControlCenterSettings", ["Control Center"]),
        ("Mouse", "MouseExtension", []),
        ("Network", "Network", ["Firewall", "Ethernet"]),
        ("Notifications", "NotificationsSettings", []),
        ("Printers & Scanners", "PrinterScannerSettings", ["Printer", "Scanner"]),
        ("Privacy & Security", "SecurityPrivacyExtension", ["Permissions", "FileVault"]),
        ("Screen Time", "ScreenTimePreferencesExtension", []),
        ("Sharing", "Sharing", ["Screen Sharing", "File Sharing", "Computer Name"]),
        ("Siri", "SiriPreferenceExtension", ["Apple Intelligence"]),
        ("Software Update", "SoftwareUpdateSettingsExtension", ["Update"]),
        ("Sound", "Sound", ["Volume", "Audio"]),
        ("Spotlight", "SpotlightPreferenceExtension", []),
        ("Startup Disk", "StartupDisk", []),
        ("Storage", "Storage", ["Disk Space"]),
        ("Time Machine", "TimeMachineSettings", ["Backup"]),
        ("Touch ID & Password", "Touch ID & Password", ["Fingerprint"]),
        ("Trackpad", "TrackpadExtension", []),
        ("Transfer or Reset", "TransferResetExtension", ["Erase"]),
        ("Users & Groups", "UsersGroups", ["Accounts"]),
        ("VPN", "VPN", []),
        ("Wallet & Apple Pay", "WalletSettingsExtension", []),
        ("Wallpaper", "Wallpaper", ["Background", "Screen Saver"]),
        ("Wi-Fi", "Wi-Fi", ["WiFi", "Wireless"]),
    ]

    /// The panes this Mac has. Ones missing from this version of macOS are left out.
    static func entries() -> [AppEntry] {
        let workspace = NSWorkspace.shared
        return panes.compactMap { pane in
            let url = directory.appending(path: "\(pane.bundle).appex")
            guard let identifier = Bundle(url: url)?.bundleIdentifier,
                  let settingsURL = URL(string: "x-apple.systempreferences:\(identifier)")
            else { return nil }
            return AppEntry(
                url: url,
                name: pane.name,
                // The same icon System Settings draws in its sidebar, which most panes describe in their Info.plist
                // rather than ship as an image.
                icon: workspace.icon(forFile: url.path),
                kind: .settingsPane(settingsURL),
                keywords: pane.keywords
            )
        }
    }
}
