import SwiftUI

@main
struct CliphoardApp: App {
    @State private var monitor = ClipboardMonitor(store: Self.openStore())

    var body: some Scene {
        WindowGroup("Cliphoard") {
            ContentView(monitor: monitor)
                .onAppear { monitor.start() }
        }
        .windowToolbarStyle(.unified)
    }

    /// Opens the per-user history database. On failure the app still runs,
    /// keeping items in memory only.
    private static func openStore() -> ClipboardStore? {
        do {
            let store = try ClipboardStore(url: ClipboardStore.defaultURL())
            print("Clipboard history: \(store.url.path)")
            return store
        } catch {
            print("Could not open clipboard history database: \(error)")
            return nil
        }
    }
}
