import SwiftUI

@main
struct CliphoardApp: App {
    static let mainWindowID = "main"

    private let monitor = ClipboardMonitor(store: Self.openStore())
    private let hotKeys = GlobalHotKeyController()
    private let vault = SecretVault()

    init() {
        monitor.start()
        LaunchAtLogin.enableOnFirstLaunch()
    }

    var body: some Scene {
        Window("Cliphoard", id: Self.mainWindowID) {
            ContentView(monitor: monitor, vault: vault)
                .showsAppInDock()
        }
        .windowToolbarStyle(.unified)

        // Without a Dock icon, this is the only way back to a closed window.
        MenuBarExtra {
            StatusMenu()
        } label: {
            MenuBarLabel(hotKeys: hotKeys)
        }

        Settings {
            SettingsView(monitor: monitor, hotKeys: hotKeys)
                .showsAppInDock()
        }
    }

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

/// The label lives as long as the app, unlike the windows, so it hands the
/// hot key its `openWindow` action.
private struct MenuBarLabel: View {
    let hotKeys: GlobalHotKeyController
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: "doc.on.clipboard")
            .onAppear {
                hotKeys.action = { [openWindow] in
                    openWindow(id: CliphoardApp.mainWindowID)
                    NSApp.activate()
                }
            }
    }
}

private struct StatusMenu: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        Button("Show Clipboard History") {
            openWindow(id: CliphoardApp.mainWindowID)
            NSApp.activate()
        }
        .keyboardShortcut("o")

        Button("Settings…") {
            NSApp.activate()
            openSettings()
        }
        .keyboardShortcut(",")

        Toggle("Launch at Login", isOn: $launchAtLogin)
            .onChange(of: launchAtLogin) {
                LaunchAtLogin.setEnabled(launchAtLogin)
                launchAtLogin = LaunchAtLogin.isEnabled
            }

        Divider()

        Button("Quit Cliphoard") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
