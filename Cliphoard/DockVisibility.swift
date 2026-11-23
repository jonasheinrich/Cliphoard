import SwiftUI
import AppKit

/// macOS ties ⌘-Tab to the Dock, so the app shows in both while one of its
/// windows is open and returns to menu-bar-only once all are closed.
private enum DockVisibility {
    static var openWindows = 0 {
        didSet { update() }
    }

    private static func update() {
        let policy: NSApplication.ActivationPolicy = openWindows > 0 ? .regular : .accessory
        guard NSApp.activationPolicy() != policy else { return }
        NSApp.setActivationPolicy(policy)
        // An LSUIElement app that turns regular otherwise gets a blank Dock
        // tile.
        if policy == .regular, let icon = NSImage(named: "AppIcon") {
            NSApp.applicationIconImage = icon
        }
    }
}

extension View {
    func showsAppInDock() -> some View {
        onAppear { DockVisibility.openWindows += 1 }
            .onDisappear { DockVisibility.openWindows -= 1 }
    }
}
