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

    /// Creates or opens the per-user history database (including schema
    /// migrations) and hands it to the store. On failure the app still runs,
    /// keeping items in memory only.
    private static func openStore() -> ClipboardStore? {
        do {
            let url = try DatabaseCreator.defaultURL()
            let db = try DatabaseCreator.open(at: url)
            print("Clipboard history: \(url.path)")
            return ClipboardStore(db: db)
        } catch {
            print("Could not open clipboard history database: \(error)")
            return nil
        }
    }
}
