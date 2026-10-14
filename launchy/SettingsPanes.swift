import AppKit
import UniformTypeIdentifiers

/// System Settings panes, which Spotlight's index doesn't include. Each is an extension bundle that also supplies the
/// pane's identifier and its sidebar icon.
enum SettingsPanes {
    private static let directory = URL(fileURLWithPath: "/System/Library/ExtensionKit/Extensions")

    private struct Pane {
        /// As shown in the System Settings sidebar.
        let name: String
        /// The extension bundle's name, without ".appex".
        let bundle: String
        /// Other words people search for it by.
        let keywords: [String]
        /// A page within the pane, opened directly (e.g. iCloud, inside Apple Account).
        var page: String?
        /// The icon's type, for panes whose sidebar icon isn't their bundle's.
        var iconType: String?
        /// A file whose icon the sidebar uses instead, e.g. an app's.
        var iconFile: String?

        init(
            _ name: String, _ bundle: String, _ keywords: [String] = [],
            page: String? = nil, iconType: String? = nil, iconFile: String? = nil
        ) {
            (self.name, self.bundle, self.keywords, self.page) = (name, bundle, keywords, page)
            (self.iconType, self.iconFile) = (iconType, iconFile)
        }
    }

    private static let panes = [
        Pane("About", "AboutExtension"),
        Pane("Accessibility", "AccessibilitySettingsExtension"),
        Pane("AirDrop & Continuity", "AirDropHandoffExtension", ["Handoff"]),
        Pane("Appearance", "Appearance", ["Dark Mode", "Light Mode"]),
        Pane("Apple Account", "AppleIDSettings", ["Apple ID"]),
        Pane("AppleCare & Warranty", "CoverageSettings"),
        // On a Mac without a battery the sidebar says "Energy", with a bolt icon (com.apple.graphic-icon.energy).
        Pane("Battery", "PowerPreferences", ["Energy", "Power"], iconType: "com.apple.graphic-icon.battery"),
        Pane("Bluetooth", "Bluetooth"),
        Pane("Date & Time", "DateAndTime Extension", ["Clock", "Time Zone"]),
        Pane("Desktop & Dock", "DesktopSettings", ["Dock", "Mission Control", "Hot Corners", "Stage Manager"]),
        Pane("Displays", "DisplaysExt", ["Monitor", "Resolution", "Night Shift"]),
        Pane("Family", "FamilySettings"),
        Pane("Focus", "FocusSettingsExtension", ["Do Not Disturb"]),
        Pane("Game Center", "GameCenterMacOSSettingsExtension"),
        Pane("Game Controllers", "GameControllerMacSettings"),
        Pane("General", "GeneralSettings"),
        Pane("iCloud", "AppleIDSettings", ["Drive"], page: "icloud", iconType: "com.apple.application-icon.icloud"),
        Pane("Internet Accounts", "InternetAccountsSettingsExtension", ["Mail Accounts"]),
        Pane("Keyboard", "KeyboardSettings", ["Shortcuts", "Dictation"]),
        Pane("Language & Region", "Localization", ["Language", "Region"]),
        Pane("Lock Screen", "LockScreen"),
        Pane("Login Items", "LoginItems", ["Startup", "Background"]),
        Pane("Menu Bar", "ControlCenterSettings", ["Control Center"]),
        Pane("Mouse", "MouseExtension"),
        Pane("Network", "Network", ["Firewall", "Ethernet"]),
        Pane("Notifications", "NotificationsSettings"),
        Pane("Printers & Scanners", "PrinterScannerSettings", ["Printer", "Scanner"]),
        Pane("Privacy & Security", "SecurityPrivacyExtension", ["Permissions", "FileVault"]),
        Pane("Screen Time", "ScreenTimePreferencesExtension"),
        Pane("Sharing", "Sharing", ["Screen Sharing", "File Sharing", "Computer Name"]),
        // The bundle's icon is an older Siri design than the sidebar's, which is the Siri app's.
        Pane("Siri", "SiriPreferenceExtension", ["Apple Intelligence"], iconFile: "/System/Applications/Siri.app"),
        Pane("Software Update", "SoftwareUpdateSettingsExtension", ["Update"]),
        Pane("Sound", "Sound", ["Volume", "Audio"]),
        Pane("Spotlight", "SpotlightPreferenceExtension"),
        Pane("Startup Disk", "StartupDisk"),
        Pane("Storage", "Storage", ["Disk Space"]),
        Pane("Time Machine", "TimeMachineSettings", ["Backup"]),
        Pane("Touch ID & Password", "Touch ID & Password", ["Fingerprint"]),
        Pane("Trackpad", "TrackpadExtension"),
        Pane("Transfer or Reset", "TransferResetExtension", ["Erase"]),
        Pane("Users & Groups", "UsersGroups", ["Accounts"]),
        Pane("VPN", "VPN"),
        Pane("Wallet & Apple Pay", "WalletSettingsExtension"),
        Pane("Wallpaper", "Wallpaper", ["Background", "Screen Saver"]),
        Pane("Wi-Fi", "Wi-Fi", ["WiFi", "Wireless"]),
    ]

    /// The panes this Mac has. Ones missing from this version of macOS are left out.
    static func entries() -> [AppEntry] {
        let workspace = NSWorkspace.shared
        return panes.compactMap { pane in
            let url = directory.appending(path: "\(pane.bundle).appex")
            guard let identifier = Bundle(url: url)?.bundleIdentifier,
                  let settingsURL = URL(string: "x-apple.systempreferences:\(identifier)" + (pane.page.map { ":\($0)" } ?? ""))
            else { return nil }
            return AppEntry(
                url: settingsURL,
                name: pane.name,
                // The same icon System Settings draws in its sidebar, which most panes describe in their Info.plist
                // rather than ship as an image.
                icon: pane.iconType.flatMap(UTType.init).map(workspace.icon(for:))
                    ?? workspace.icon(forFile: pane.iconFile ?? url.path),
                kind: .settingsPane,
                keywords: pane.keywords
            )
        }
    }
}
