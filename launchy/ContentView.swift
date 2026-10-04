import SwiftUI

/// Sizes measured from screenshots of macOS Spotlight (in points).
private enum Metrics {
    static let width: CGFloat = 640
    static let barHeight: CGFloat = 56
    static let cornerRadius: CGFloat = 28
    static let maxHeight: CGFloat = 467

    // Spotlight's shadow, fitted to its measured falloff: dark just below the panel, faint at the sides.
    static let shadowOpacity: Double = 0.8
    static let shadowBlur: CGFloat = 11.5
    static let shadowOffset: CGFloat = 8
    static let shadowSideInset: CGFloat = 8.5

    static let glyphSize: CGFloat = 24
    static let glyphLeading: CGFloat = 21
    static let textLeading: CGFloat = 62
    static let fontSize: CGFloat = 26
    static let barIconSize: CGFloat = 32
    static let barIconTrailing: CGFloat = 20

    static let dividerInset: CGFloat = 20
    static let listInset: CGFloat = 10
    static let rowPitch: CGFloat = 58
    static let rowHighlightHeight: CGFloat = 55
    static let rowCornerRadius: CGFloat = 14
    static let rowIconSize: CGFloat = 43
    static let rowIconLeading: CGFloat = 4.5
    static let rowTextLeading: CGFloat = 61
    static let rowFontSize: CGFloat = 17

    static let scrollerWidth: CGFloat = 11
    static let scrollerTrailing: CGFloat = 3
    static let scrollerTopInset: CGFloat = 40
    static let scrollerBottomInset: CGFloat = 47.5
}

struct ContentView: View {
    @State private var query = ""
    @State private var apps: [AppEntry] = []
    @State private var selection = 0
    @State private var scroll: ScrollGeometry?
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    /// Fill for the selected row and the autocomplete highlight. Semantic styles get muted by the glass,
    /// so this is an explicit overlay measured against Spotlight's.
    private var highlightFill: Color {
        colorScheme == .dark ? .white.opacity(0.22) : .black.opacity(0.1)
    }

    private static let maxResults = 20

    /// Transparent space around the panel so its shadow isn't clipped by the window.
    static let shadowMargin: CGFloat = 60

    private var results: [AppEntry] {
        Array(AppIndex.search(query, in: apps).prefix(Self.maxResults))
    }

    private var selectedApp: AppEntry? {
        results.indices.contains(selection) ? results[selection] : nil
    }

    /// The rest of the selected app's name, shown inline after the query like Spotlight's autocomplete.
    private var completion: String? {
        guard let name = selectedApp?.name,
              name.lowercased().hasPrefix(query.lowercased()),
              name.count > query.count
        else { return nil }
        return String(name.dropFirst(query.count))
    }

    /// The list content is a fixed pitch per row; the panel grows to fit it, up to Spotlight's maximum height.
    private var listHeight: CGFloat {
        Metrics.listInset * 2 + Metrics.rowPitch * CGFloat(results.count)
    }
 
    private var isScrolling: Bool {
        Metrics.barHeight + 1 + listHeight > Metrics.maxHeight
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            if !results.isEmpty {
                Rectangle()
                    .fill(.primary.opacity(0.15))
                    .frame(height: 1)
                    .padding(.horizontal, Metrics.dividerInset)
                resultsList
            }
        }
        .frame(width: Metrics.width)
        // Liquid Glass adapts to light/dark, the Liquid Glass slider and Reduce Transparency on its own,
        // as do semantic styles (.primary, .secondary).
        .glassEffect(.regular, in: .rect(cornerRadius: Metrics.cornerRadius, style: .continuous))
        .background { panelShadow }
        // The window is sized for the tallest panel; the space below stays transparent when it's shorter.
        .frame(height: Metrics.maxHeight, alignment: .top)
        .padding(Self.shadowMargin)
        .onChange(of: query) { selection = 0 }
        // Spotlight hides the caret while autocompleting.
        .onChange(of: completion == nil) { _, showCaret in setCaretHidden(!showCaret) }
        // The panel keeps this view alive while hidden, so reset it on hide and refocus on show.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { note in
            guard note.object is LauncherPanel else { return }
            query = ""
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { note in
            guard note.object is LauncherPanel else { return }
            apps = AppIndex.load() // Re-scan on every show so newly installed apps appear.
            isFocused = true
        }
    }

    /// The panel draws its own shadow: the window server only gives this never-activating panel the hard-edged
    /// inactive-window shadow. It's masked to outside the panel so it doesn't darken the glass.
    private var panelShadow: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
        return shape
            .fill(.black.opacity(Metrics.shadowOpacity))
            .padding(.horizontal, Metrics.shadowSideInset)
            .offset(y: Metrics.shadowOffset)
            .blur(radius: Metrics.shadowBlur)
            .mask {
                Rectangle()
                    .padding(-Self.shadowMargin)
                    .overlay { shape.blendMode(.destinationOut) }
                    .compositingGroup()
            }
            .allowsHitTesting(false)
    }

    private var searchBar: some View {
        ZStack(alignment: .leading) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: Metrics.glyphSize, weight: .regular))
                .foregroundStyle(.primary.opacity(0.7))
                .padding(.leading, Metrics.glyphLeading)

            completionOverlay
                .padding(.leading, Metrics.textLeading)

            TextField("Search", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: Metrics.fontSize))
                .focused($isFocused)
                .onSubmit(openSelection)
                .onKeyPress(.downArrow) { moveSelection(by: 1) }
                .onKeyPress(.upArrow) { moveSelection(by: -1) }
                .padding(.leading, Metrics.textLeading)
                .padding(.trailing, Metrics.barIconTrailing + Metrics.barIconSize + 12)

            if let app = selectedApp {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: Metrics.barIconSize, height: Metrics.barIconSize)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, Metrics.barIconTrailing)
            }
        }
        .frame(height: Metrics.barHeight)
    }

    /// Draws the autocompleted remainder ("ari — Open") right after the typed text, behind the text field.
    @ViewBuilder
    private var completionOverlay: some View {
        if let completion {
            HStack(spacing: 0) {
                Text(query).hidden()
                Text(completion + " — Open")
                    .foregroundStyle(.primary.opacity(0.85))
                    .padding(.trailing, 7)
                    .frame(height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(highlightFill)
                    )
            }
            .font(.system(size: Metrics.fontSize))
            .lineLimit(1)
            .allowsHitTesting(false)
        }
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    // Rows are identified by index, which is what `scrollTo(selection)` targets.
                    ForEach(results.indices, id: \.self) { index in
                        row(results[index], isSelected: index == selection)
                    }
                }
                .padding(EdgeInsets(
                    top: Metrics.listInset - 1,
                    leading: Metrics.listInset,
                    bottom: Metrics.listInset,
                    // Spotlight leaves room for its scroller when the list overflows.
                    trailing: isScrolling ? 27.5 : Metrics.listInset
                ))
            }
            // The system scroller looks and behaves differently, so draw Spotlight's instead.
            .scrollIndicators(.never)
            .onScrollGeometryChange(for: ScrollGeometry.self, of: { $0 }) { scroll = $1 }
            .overlay(alignment: .topTrailing) {
                if isScrolling, let scroll {
                    scroller(scroll)
                }
            }
            .frame(height: min(listHeight, Metrics.maxHeight - Metrics.barHeight - 1))
            .onChange(of: selection) { proxy.scrollTo(selection) }
        }
    }

    /// An always-visible scroller measured from Spotlight's: a solid track with a proportional thumb.
    private func scroller(_ scroll: ScrollGeometry) -> some View {
        let viewport = scroll.containerSize.height
        let content = max(scroll.contentSize.height, viewport)
        let track = max(viewport - Metrics.scrollerTopInset - Metrics.scrollerBottomInset, 0)
        let thumb = max(track * viewport / content, 20)
        let progress = content > viewport ? min(max(scroll.contentOffset.y / (content - viewport), 0), 1) : 0
        let isDark = colorScheme == .dark
        let shape = Capsule()

        return ZStack(alignment: .top) {
            shape.fill(Color(white: isDark ? 20 / 255 : 0.85))
            shape.fill(Color(white: isDark ? 124 / 255 : 0.55))
                .frame(height: thumb)
                .offset(y: (track - thumb) * progress)
        }
        .frame(width: Metrics.scrollerWidth, height: track)
        .padding(.top, Metrics.scrollerTopInset)
        .padding(.trailing, Metrics.scrollerTrailing)
        .allowsHitTesting(false)
    }

    private func row(_ app: AppEntry, isSelected: Bool) -> some View {
        ZStack(alignment: .leading) {
            if isSelected {
                RoundedRectangle(cornerRadius: Metrics.rowCornerRadius, style: .continuous)
                    .fill(highlightFill)
                    .frame(height: Metrics.rowHighlightHeight)
            }
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: Metrics.rowIconSize, height: Metrics.rowIconSize)
                .padding(.leading, Metrics.rowIconLeading)
            Text(app.name)
                .font(.system(size: Metrics.rowFontSize))
                .lineLimit(1)
                .padding(.leading, Metrics.rowTextLeading)
        }
        .frame(maxWidth: .infinity, minHeight: Metrics.rowPitch, maxHeight: Metrics.rowPitch, alignment: .leading)
    }

    private var panel: NSWindow? {
        NSApp.windows.first { $0 is LauncherPanel }
    }

    /// SwiftUI has no API for the caret colour, so set it on the AppKit field editor that's editing the text field.
    private func setCaretHidden(_ hidden: Bool) {
        guard let editor = panel?.firstResponder as? NSTextView else { return }
        editor.insertionPointColor = hidden ? .clear : .textColor
    }

    private func moveSelection(by offset: Int) -> KeyPress.Result {
        guard !results.isEmpty else { return .ignored }
        selection = min(max(selection + offset, 0), results.count - 1)
        return .handled
    }

    private func openSelection() {
        guard let app = selectedApp else { return }
        NSWorkspace.shared.openApplication(at: app.url, configuration: .init())
        panel?.orderOut(nil)
    }
}

#Preview {
    ContentView()
}
