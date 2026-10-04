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
    static let textTrailing: CGFloat = 20

    static let dividerInset: CGFloat = 20
    static let listInset: CGFloat = 10
    static let rowPitch: CGFloat = 58
    static let rowHighlightHeight: CGFloat = 55
    static let rowCornerRadius: CGFloat = 14
    static let rowIconSize: CGFloat = 43
    static let rowIconLeading: CGFloat = 4.5
    static let rowTextLeading: CGFloat = 61
    static let rowFontSize: CGFloat = 17
}

struct ContentView: View {
    @State private var query = ""
    @State private var index = AppIndex()
    @State private var selection = 0
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var activeState

    /// Fill for the selected row. Semantic styles get muted by the glass,
    /// so this is an explicit overlay measured against Spotlight's.
    private var highlightFill: Color {
        colorScheme == .dark ? .white.opacity(0.22) : .black.opacity(0.1)
    }

    private static let maxResults = 20

    /// Transparent space around the panel so its shadow isn't clipped by the window.
    static let shadowMargin: CGFloat = 60

    private var results: [AppEntry] {
        Array(AppIndex.search(query, in: index.apps).prefix(Self.maxResults))
    }

    private var selectedApp: AppEntry? {
        results.indices.contains(selection) ? results[selection] : nil
    }

    private static let maxListHeight = Metrics.maxHeight - Metrics.barHeight - 1

    private var rowsHeight: CGFloat {
        Metrics.rowPitch * CGFloat(results.count)
    }

    /// The padding is trimmed when the rows fit but the full padding wouldn't, so the list doesn't scroll just for it.
    private var tightInset: CGFloat? {
        let slack = Self.maxListHeight - rowsHeight
        return (0..<Metrics.listInset * 2).contains(slack) ? slack / 2 : nil
    }

    /// The list content is a fixed pitch per row; the panel grows to fit it, up to Spotlight's maximum height.
    private var listHeight: CGFloat {
        min(rowsHeight + (tightInset ?? Metrics.listInset) * 2, Self.maxListHeight)
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            if !results.isEmpty {
                Divider()
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
        // The panel keeps this view alive while hidden, so reset it on hide and refocus on show.
        .onChange(of: activeState, initial: true) {
            if activeState == .key { isFocused = true } else { query = "" }
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

            TextField("Search", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: Metrics.fontSize))
                .focused($isFocused)
                .onSubmit(openSelection)
                .onKeyPress(.downArrow) { moveSelection(by: 1) }
                .onKeyPress(.upArrow) { moveSelection(by: -1) }
                .padding(.leading, Metrics.textLeading)
                .padding(.trailing, Metrics.textTrailing)
        }
        .frame(height: Metrics.barHeight)
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            // The system scroller follows System Settings › Appearance › Show scroll bars, like Spotlight's.
            ScrollView {
                VStack(spacing: 0) {
                    // Rows are identified by index, which is what `scrollTo(selection)` targets.
                    ForEach(results.indices, id: \.self) { index in
                        row(results[index], isSelected: index == selection)
                    }
                }
                .padding(EdgeInsets(
                    top: tightInset ?? Metrics.listInset - 1,
                    leading: Metrics.listInset,
                    bottom: tightInset ?? Metrics.listInset,
                    trailing: Metrics.listInset
                ))
            }
            .frame(height: listHeight)
            .onChange(of: selection) { proxy.scrollTo(selection) }
        }
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
        // Read each row as one element, so VoiceOver says the app's name and whether it's selected.
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var panel: NSWindow? {
        NSApp.windows.first { $0 is LauncherPanel }
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
