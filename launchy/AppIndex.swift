import AppKit
import Observation

/// Something the launcher can open: an app, or a System Settings pane.
struct AppEntry: Identifiable {
    enum Kind {
        case app
        /// Opened with its `x-apple.systempreferences:` URL.
        case settingsPane(URL)
    }

    let url: URL
    let name: String
    let icon: NSImage
    var kind = Kind.app
    /// Other words that find this entry, besides its name.
    var keywords: [String] = []

    var id: URL { url }
}

/// The installed apps, from the Spotlight index, and the System Settings panes. The query stays live, so installed and
/// removed apps show up on their own.
@Observable final class AppIndex {
    private(set) var apps: [AppEntry] = []

    /// Finder's "Applications" shows both the user-installed and built-in apps, so search both, plus the user's own.
    /// Scopes are searched recursively, so apps in subfolders (e.g. "/Applications/Python 3.14") are found too.
    private static let scopes = [
        "/Applications",
        "/System/Applications",
        // User-facing apps Apple keeps out of /Applications (Keychain Access, Archive Utility, …).
        "/System/Library/CoreServices/Applications",
        // The real home folder, since the sandbox's home directory is the app's container.
        URL(fileURLWithPath: String(cString: getpwuid(getuid()).pointee.pw_dir)).appending(path: "Applications").path,
    ]

    /// Apps that live alongside background agents in CoreServices, so they're listed individually.
    private static let extraApps = [
        URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"),
    ]

    @ObservationIgnored private let query = NSMetadataQuery()
    @ObservationIgnored private let settingsPanes = SettingsPanes.entries()

    init() {
        query.predicate = NSPredicate(format: "%K == 'com.apple.application-bundle'", NSMetadataItemContentTypeKey)
        query.searchScopes = Self.scopes
        for name in [NSNotification.Name.NSMetadataQueryDidFinishGathering, .NSMetadataQueryDidUpdate] {
            NotificationCenter.default.addObserver(forName: name, object: query, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.update() }
            }
        }
        query.start()
    }

    private func update() {
        query.disableUpdates()
        defer { query.enableUpdates() }

        let found = query.results.compactMap { ($0 as? NSMetadataItem)?.value(forAttribute: NSMetadataItemPathKey) as? String }
            .map(URL.init(fileURLWithPath:))
        let fileManager = FileManager.default
        let workspace = NSWorkspace.shared
        apps = ((found + Self.extraApps.filter { fileManager.fileExists(atPath: $0.path) })
            .map { url in
                AppEntry(
                    url: url,
                    name: fileManager.displayName(atPath: url.path), // Localised, without ".app"
                    // Some apps (e.g. Safari) are symlinks; resolve them so the icon has no alias badge.
                    icon: workspace.icon(forFile: url.resolvingSymlinksInPath().path)
                )
            }
            + settingsPanes)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Case- and diacritic-insensitive "name contains query, or a keyword starts with it", with names that start with the
    /// query first, like Spotlight. Keywords match only from the start, so "wall" doesn't find Network by "Firewall".
    static func search(_ query: String, in apps: [AppEntry]) -> [AppEntry] {
        guard !query.isEmpty else { return [] }
        // `sorted` is stable, so each group stays alphabetical.
        return apps.filter { app in
            app.name.localizedStandardContains(query) || app.keywords.contains { prefixRange(of: query, in: $0) != nil }
        }
            .sorted { prefixRange(of: query, in: $0.name) != nil && prefixRange(of: query, in: $1.name) == nil }
    }

    /// Where `name` starts with `query`, matched the same way as `search`.
    private static func prefixRange(of query: String, in name: String) -> Range<String.Index>? {
        name.range(of: query, options: [.anchored, .caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
