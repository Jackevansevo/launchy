import SwiftUI

/// Sizes measured from screenshots of macOS Spotlight (in points).
private enum Metrics {
    static let width: CGFloat = 640
    static let cornerRadius: CGFloat = 28
    static let maxHeight: CGFloat = 467
    static let iconSize: CGFloat = 44

    // Spotlight's shadow, fitted to its measured falloff below the panel.
    static let shadowOpacity: Double = 0.8
    static let shadowBlur: CGFloat = 11.5
    static let shadowOffset: CGFloat = 8
}

struct ContentView: View {
    @State private var query = ""
    @State private var index = AppIndex()
    @State private var selection = 0
    @FocusState private var isFocused: Bool
    @Environment(\.controlActiveState) private var activeState

    private static let maxResults = 20

    /// Transparent space around the panel so its shadow isn't clipped by the window.
    private static let shadowMargin: CGFloat = 60

    private var results: [AppEntry] {
        Array(AppIndex.search(query, in: index.apps).prefix(Self.maxResults))
    }

    private var selectedApp: AppEntry? {
        results.indices.contains(selection) ? results[selection] : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            if !results.isEmpty {
                Divider()
                    .padding(.horizontal)
                resultsList
            }
        }
        .frame(width: Metrics.width)
        // Liquid Glass adapts to light/dark, the Liquid Glass slider and Reduce Transparency on its own,
        // as do semantic styles (.primary, .secondary).
        .glassEffect(.regular, in: .rect(cornerRadius: Metrics.cornerRadius, style: .continuous))
        // The panel draws its own shadow: the window server only gives this never-activating panel the hard-edged
        // inactive-window shadow. The glass casts it, so the text and icons on it don't get one.
        .shadow(color: .black.opacity(Metrics.shadowOpacity), radius: Metrics.shadowBlur, y: Metrics.shadowOffset)
        // The window is sized for the tallest panel; the space below stays transparent when it's shorter.
        .frame(height: Metrics.maxHeight, alignment: .top)
        .padding(Self.shadowMargin)
        .onChange(of: query) { selection = 0 }
        // The panel keeps this view alive while hidden, so reset it on hide and refocus on show.
        .onChange(of: activeState, initial: true) {
            if activeState == .key { isFocused = true } else { query = "" }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search", text: $query)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onSubmit(openSelection)
                .onKeyPress(.downArrow) { moveSelection(by: 1) }
                .onKeyPress(.upArrow) { moveSelection(by: -1) }
        }
        .font(.largeTitle)
        .padding()
    }

    /// A system list, which brings the scroll bar with it. It fills the panel, so the panel is full height whenever there
    /// are results.
    private var resultsList: some View {
        ScrollViewReader { proxy in
            List(results.indices, id: \.self) { index in
                // A button, so clicking selects the row without taking focus from the search field. Like Spotlight, a
                // click selects and a double-click opens.
                Button {
                    selection = index
                    if NSApp.currentEvent?.clickCount == 2 { openSelection() }
                } label: {
                    HStack(spacing: 14) {
                        Image(nsImage: results[index].icon)
                            .resizable()
                            .frame(width: Metrics.iconSize, height: Metrics.iconSize)
                        Text(results[index].name)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect) // The whole row is clickable, not just the icon and name.
                }
                .buttonStyle(.plain)
                .font(.title2)
                .padding(.vertical, 2)
                .listRowSeparator(.hidden) // Spotlight has none.
                // The list's own selection needs the list to have focus, which would take it from the search field, so the
                // selected row draws its own highlight.
                .listRowBackground(index == selection ? selectionHighlight : nil)
                .accessibilityAddTraits(index == selection ? .isSelected : [])
            }
            .scrollContentBackground(.hidden)
            // Inset so the scroll bar sits clear of the divider and the panel's edge (SwiftUI resets the scroll view's
            // `scrollerInsets`, so the list itself is inset). The list is drawn by AppKit, which SwiftUI clipping doesn't
            // reach, so it also stops short of the rounded corners.
            .padding(EdgeInsets(top: 6, leading: 0, bottom: 10, trailing: 5))
            // The arrow keys move the selection from the search field, so keep it in view. Centring it lets the first
            // and last rows scroll fully into view, padding included.
            .onChange(of: selection) { proxy.scrollTo(selection, anchor: .center) }
        }
    }

    /// A semantic fill rather than nested glass: on glass it's drawn vibrant, a translucent tint of what's behind the
    /// panel like Spotlight's, where glass on glass brightens and gets a rim.
    private var selectionHighlight: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.quaternary)
            .padding(.horizontal, 10)
    }

    private func moveSelection(by offset: Int) -> KeyPress.Result {
        guard !results.isEmpty else { return .ignored }
        // Wraps around at either end.
        selection = (selection + offset + results.count) % results.count
        return .handled
    }

    private func openSelection() {
        guard let app = selectedApp else { return }
        // Opening the app takes key status from the panel, which hides it.
        NSWorkspace.shared.openApplication(at: app.url, configuration: .init())
    }
}

#Preview {
    ContentView()
}

