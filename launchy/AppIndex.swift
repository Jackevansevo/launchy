import AppKit

struct AppEntry: Identifiable {
    let url: URL
    let name: String
    let icon: NSImage

    var id: URL { url }
}

/// Finds the apps in the Applications folders.
enum AppIndex {
    /// Finder's "Applications" shows both the user-installed and built-in apps, so scan both.
    private static let folders = [
        "/Applications",
        "/Applications/Utilities",
        "/System/Applications",
        "/System/Applications/Utilities",
        // User-facing apps Apple keeps out of /Applications (Keychain Access, Archive Utility, …).
        "/System/Library/CoreServices/Applications",
    ]

    /// Apps that live alongside background agents in CoreServices, so they're listed individually.
    private static let extraApps = [
        "/System/Library/CoreServices/Finder.app",
    ]

    static func load() -> [AppEntry] {
        let fileManager = FileManager.default
        let workspace = NSWorkspace.shared

        let folderApps = folders.flatMap { folder in
            let folderURL = URL(fileURLWithPath: folder)
            let contents = (try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)) ?? []
            return contents.filter { $0.pathExtension == "app" }
        }
        let extras = extraApps.map(URL.init(fileURLWithPath:)).filter { fileManager.fileExists(atPath: $0.path) }

        return (folderApps + extras)
            .map { url in
                AppEntry(
                    url: url,
                    name: fileManager.displayName(atPath: url.path), // Localised, without ".app"
                    // Some apps (e.g. Safari) are symlinks; resolve them so the icon has no alias badge.
                    icon: workspace.icon(forFile: url.resolvingSymlinksInPath().path)
                )
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Case-insensitive "name contains query", with names that start with the query first, like Spotlight.
    static func search(_ query: String, in apps: [AppEntry]) -> [AppEntry] {
        guard !query.isEmpty else { return [] }
        let prefix = query.lowercased()
        // `sorted` is stable, so each group stays alphabetical.
        return apps.filter { $0.name.localizedCaseInsensitiveContains(query) }
            .sorted { $0.name.lowercased().hasPrefix(prefix) && !$1.name.lowercased().hasPrefix(prefix) }
    }
}
