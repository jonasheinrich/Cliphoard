import SwiftUI
import AppKit

enum ItemDisplay {
    static func utcTimestamp(_ date: Date) -> String {
        utcFormatter.string(from: date)
    }

    static func relativeTime(_ date: Date, now: Date) -> String {
        let elapsed = now.timeIntervalSince(date)
        guard elapsed >= 60 else { return "Just now" }
        let flooredMinutes = (elapsed / 60).rounded(.down) * 60
        return relativeFormatter.localizedString(
            for: date,
            relativeTo: date.addingTimeInterval(flooredMinutes)
        )
    }

    static func appIcon(for item: ClipboardItem) -> NSImage? {
        guard let bundleID = item.sourceBundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    private static let utcFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS 'UTC'"
        return formatter
    }()

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .numeric
        return formatter
    }()
}

/// Ticks once a minute, counted from the copy time.
struct RelativeTimeText: View {
    let date: Date

    var body: some View {
        TimelineView(.periodic(from: date, by: 60)) { context in
            Text(ItemDisplay.relativeTime(date, now: context.date))
        }
    }
}

struct AppIconView: View {
    let item: ClipboardItem
    var size: CGFloat = 16

    var body: some View {
        if let icon = ItemDisplay.appIcon(for: item) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: size, height: size)
        }
    }
}

struct CopyButton: View {
    let isCopied: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(
                isCopied ? "Copied" : "Copy",
                systemImage: isCopied ? "checkmark" : "doc.on.doc"
            )
            .imageScale(.large)
            .labelStyle(.iconOnly)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: 16, height: 16)
        }
        .help(isCopied ? "Copied" : "Copy to clipboard (C)")
    }
}

extension KeyPress {
    var hasNoCommandModifiers: Bool {
        modifiers.intersection([.command, .control, .option]).isEmpty
    }
}

let copyFeedbackDuration: Duration = .seconds(1.5)
