import AppKit
import Observation

/// Something the launcher can open: an app, or a System Settings pane.
struct AppEntry: Identifiable {
    enum Kind {
        case app
        case settingsPane
    }

    /// The app's bundle, or the pane's `x-apple.systempreferences:` URL.
    let url: URL
    let name: String
    let icon: NSImage
    let kind: Kind
    /// Other words that find this entry, besides its name.
    let keywords: [String]

    /// The name and keywords without case or accents, folded once so each search is a plain comparison.
    let foldedName: String
    let foldedKeywords: [String]

    init(url: URL, name: String, icon: NSImage, kind: Kind = .app, keywords: [String] = []) {
        (self.url, self.name, self.icon, self.kind, self.keywords) = (url, name, icon, kind, keywords)
        foldedName = Self.fold(name)
        foldedKeywords = keywords.map(Self.fold)
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

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
    /// The last search, since the view reads its results several times for each change.
    @ObservationIgnored private var lastSearch: (query: String, results: [AppEntry])?

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
        lastSearch = nil
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

    /// `search(_:in:)` over the installed apps, remembering the last query's results.
    func search(_ query: String) -> [AppEntry] {
        if let lastSearch, lastSearch.query == query { return lastSearch.results }
        let results = Self.search(query, in: apps)
        lastSearch = (query, results)
        return results
    }

    /// Case- and diacritic-insensitive "name contains query, or a keyword starts with it", with names that start with the
    /// query first, like Spotlight. Keywords match only from the start, so "wall" doesn't find Network by "Firewall".
    static func search(_ query: String, in apps: [AppEntry]) -> [AppEntry] {
        guard !query.isEmpty else { return [] }
        let query = AppEntry.fold(query)
        // `sorted` is stable, so each group stays alphabetical.
        return apps.filter { app in
            app.foldedName.contains(query) || app.foldedKeywords.contains { $0.hasPrefix(query) }
        }
            .sorted { $0.foldedName.hasPrefix(query) && !$1.foldedName.hasPrefix(query) }
    }
}
