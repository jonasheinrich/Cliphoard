import SwiftUI
import AppKit

struct ContentView: View {
    let monitor: any ClipboardMonitoring

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Latest clipboard item")
                .font(.headline)

            if let item = monitor.latestItem {
                // A list of rows later; for now just the latest item.
                ScrollView {
                    VStack(spacing: 6) {
                        ClipboardItemRow(item: item)
                    }
                }
            } else {
                ContentUnavailableView(
                    "No text on the clipboard",
                    systemImage: "doc.on.clipboard",
                    description: Text("Copy some text and it will appear here.")
                )
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }
}

/// One clipboard entry: text on the left, source app and time on the right,
/// all inside a rounded grey box.
struct ClipboardItemRow: View {
    let item: ClipboardItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(item.text)
                .font(.body.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            ItemMetadataView(item: item)
                .frame(width: 160, alignment: .leading)
        }
        .padding(8)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 6))
    }
}

/// Source app and copy time shown in the right-hand column of a row.
private struct ItemMetadataView: View {
    let item: ClipboardItem

    private static let utcFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS 'UTC'"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let icon = appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 16, height: 16)
                }
                Text(item.sourceAppName ?? "Unknown app")
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            // Re-render once a minute, counted from the copy time, so the label
            // changes exactly when another full minute has passed.
            TimelineView(.periodic(from: item.copiedAt, by: 60)) { context in
                Text(relativeTime(now: context.date))
            }
            .help(Self.utcFormatter.string(from: item.copiedAt))
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .numeric
        return formatter
    }()

    /// Minute granularity: "Just now" for the first minute, then "1 minute ago",
    /// "2 hours ago", etc.
    private func relativeTime(now: Date) -> String {
        let elapsed = now.timeIntervalSince(item.copiedAt)
        guard elapsed >= 60 else { return "Just now" }
        // Round down to whole minutes so seconds never show up.
        let flooredMinutes = (elapsed / 60).rounded(.down) * 60
        return Self.relativeFormatter.localizedString(
            for: item.copiedAt,
            relativeTo: item.copiedAt.addingTimeInterval(flooredMinutes)
        )
    }

    private var appIcon: NSImage? {
        guard let bundleID = item.sourceBundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

#if DEBUG
#Preview("Short text") {
    ContentView(monitor: PreviewClipboardMonitor(latestItem: .sampleShort))
}

#Preview("Code") {
    ContentView(monitor: PreviewClipboardMonitor(latestItem: .sampleCode))
}

#Preview("Long text") {
    ContentView(monitor: PreviewClipboardMonitor(latestItem: .sampleLong))
}

#Preview("Unknown app") {
    ContentView(monitor: PreviewClipboardMonitor(latestItem: .sampleUnknownApp))
}

#Preview("Empty") {
    ContentView(monitor: PreviewClipboardMonitor(latestItem: nil))
}
#endif
