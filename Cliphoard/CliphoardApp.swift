import SwiftUI

@main
struct CliphoardApp: App {
    @State private var monitor = ClipboardMonitor()

    var body: some Scene {
        WindowGroup("Cliphoard") {
            ContentView(monitor: monitor)
                .onAppear { monitor.start() }
        }
    }
}
