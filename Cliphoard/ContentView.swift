import SwiftUI

/// The clipboard history, newest first. Clicking an item opens its detail page.
struct ContentView: View {
    let monitor: any ClipboardMonitoring

    /// Fetch the next page when a row this close to the end appears, so new
    /// items are usually ready before the user reaches the bottom.
    private static let prefetchDistance = 20

    var body: some View {
        NavigationStack {
            Group {
                if monitor.items.isEmpty {
                    ContentUnavailableView(
                        "No text on the clipboard",
                        systemImage: "doc.on.clipboard",
                        description: Text("Copy some text and it will appear here.")
                    )
                } else {
                    history
                }
            }
            .navigationTitle("Clipboard History")
            .toolbar {
                // Mirrors the detail page's back button in the same spot, so
                // the toolbar keeps its height and layout when navigating.
                ToolbarItem(placement: .navigation) {
                    // Square frame so the glass background becomes a circle
                    // the size of the back button instead of a narrow pill.
                    Image(systemName: "doc.on.clipboard")
                        .frame(width: 32, height: 32)
                        .accessibilityHidden(true)
                }
            }
            .navigationDestination(for: ClipboardItem.self) { item in
                ClipboardItemDetailView(item: item)
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }

    private var history: some View {
        ScrollView {
            // Lazy: only rows on (or near) the screen are created.
            LazyVStack(spacing: 6) {
                ForEach(Array(monitor.items.enumerated()), id: \.element.id) { index, item in
                    NavigationLink(value: item) {
                        ClipboardItemRow(item: item)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        if index >= monitor.items.count - Self.prefetchDistance {
                            monitor.loadMore()
                        }
                    }
                }

                if monitor.hasMore {
                    ProgressView()
                        .controlSize(.small)
                        .padding()
                        .onAppear { monitor.loadMore() }
                }
            }
            .padding()
        }
    }
}

#if DEBUG
#Preview("History (250 items)") {
    ContentView(monitor: PreviewClipboardMonitor())
}

#Preview("Single item") {
    ContentView(monitor: PreviewClipboardMonitor(items: ClipboardItem.samples(count: 1)))
}

#Preview("Empty") {
    ContentView(monitor: PreviewClipboardMonitor(items: []))
}
#endif
