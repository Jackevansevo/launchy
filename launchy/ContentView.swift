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
        // Rows scrolling past the rounded bottom corners are clipped to the panel.
        .clipShape(.rect(cornerRadius: Metrics.cornerRadius, style: .continuous))
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

    /// The rows scroll only when they don't fit, so the panel shrinks to fit a few results, as Spotlight's does.
    private var resultsList: some View {
        ViewThatFits(in: .vertical) {
            rows
                .padding(Self.listPadding)
            ScrollViewReader { proxy in
                // The system scroll bar, which follows System Settings › Appearance › Show scroll bars.
                ScrollView {
                    rows
                }
                .contentMargins(.horizontal, Self.listPadding.leading, for: .scrollContent)
                .contentMargins(.top, Self.listPadding.top, for: .scrollContent)
                .contentMargins(.bottom, Self.listPadding.bottom, for: .scrollContent)
                // Keeps the scroll bar clear of the divider, the panel's edge and its rounded bottom corner.
                .contentMargins(.top, 6, for: .scrollIndicators)
                .contentMargins(.bottom, 14, for: .scrollIndicators)
                .contentMargins(.trailing, 5, for: .scrollIndicators)
                // The arrow keys move the selection from the search field, so keep it in view.
                .onChange(of: selection) { proxy.scrollTo(selection) }
            }
        }
    }

    private static let listPadding = EdgeInsets(top: 6, leading: 10, bottom: 10, trailing: 10)

    private var rows: some View {
        VStack(spacing: 0) {
            // Rows are identified by index, which is what `scrollTo(selection)` targets.
            ForEach(results.indices, id: \.self) { index in
                // A button, so clicking selects the row without taking focus from the search field. Like Spotlight, a
                // click selects and a double-click opens.
                Button {
                    selection = index
                    if NSApp.currentEvent?.clickCount == 2 { openSelection() }
                } label: {
                    row(results[index], isSelected: index == selection)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(index == selection ? .isSelected : [])
                .id(index)
            }
        }
    }

    private func row(_ app: AppEntry, isSelected: Bool) -> some View {
        HStack(spacing: 14) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: Metrics.iconSize, height: Metrics.iconSize)
            Text(app.name)
                .lineLimit(1)
        }
        .font(.title2)
        .padding(.vertical, 6)
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { if isSelected { selectionHighlight } }
        .contentShape(.rect) // The whole row is clickable, not just the icon and name.
    }

    /// A semantic fill rather than nested glass: on glass it's drawn vibrant, a translucent tint of what's behind the
    /// panel like Spotlight's, where glass on glass brightens and gets a rim.
    private var selectionHighlight: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.quaternary)
    }

    private func moveSelection(by offset: Int) -> KeyPress.Result {
        guard !results.isEmpty else { return .ignored }
        // Wraps around at either end.
        selection = (selection + offset + results.count) % results.count
        return .handled
    }

    private func openSelection() {
        guard let app = selectedApp else { return }
        // Hide explicitly: if the app is already frontmost, opening it won't take key status
        // from the non-activating panel, so resignKey never fires.
        NSApp.keyWindow?.orderOut(nil)
        NSWorkspace.shared.openApplication(at: app.url, configuration: .init())
    }
}

#Preview {
    ContentView()
}

