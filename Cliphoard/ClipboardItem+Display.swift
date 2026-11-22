import SwiftUI
import AppKit

/// Formatting and lookups shared by the list rows and the detail page.
enum ItemDisplay {
    /// e.g. `2026-11-22 14:03:07.123 UTC`
    static func utcTimestamp(_ date: Date) -> String {
        utcFormatter.string(from: date)
    }

    /// Minute granularity: "Just now" for the first minute, then "1 minute ago",
    /// "2 hours ago", etc. Seconds never show up.
    static func relativeTime(_ date: Date, now: Date) -> String {
        let elapsed = now.timeIntervalSince(date)
        guard elapsed >= 60 else { return "Just now" }
        let flooredMinutes = (elapsed / 60).rounded(.down) * 60
        return relativeFormatter.localizedString(
            for: date,
            relativeTo: date.addingTimeInterval(flooredMinutes)
        )
    }

    /// Icon of the app the item was copied from, if it's still installed.
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

/// Relative copy time that updates once a minute, counted from the copy time,
/// so the label changes exactly when another full minute has passed.
struct RelativeTimeText: View {
    let date: Date

    var body: some View {
        TimelineView(.periodic(from: date, by: 60)) { context in
            Text(ItemDisplay.relativeTime(date, now: context.date))
        }
    }
}

/// The source app's icon, or nothing if unknown.
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
