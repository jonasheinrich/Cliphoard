import Foundation

nonisolated struct ClipboardFilter: Equatable, Sendable {
    /// Case-insensitive substring of the item's text; empty matches all.
    var text = ""
    var app: AppFilter = .all
    var since: Date?

    var isActive: Bool {
        !text.isEmpty || app != .all || since != nil
    }

    func matches(_ item: ClipboardItem) -> Bool {
        // SQLite's LIKE is case-insensitive for ASCII only; this is
        // Unicode-aware.
        if !text.isEmpty, item.text.range(of: text, options: .caseInsensitive) == nil {
            return false
        }
        switch app {
        case .all: break
        case .unknown: if item.sourceBundleID != nil { return false }
        case .app(let bundleID): if item.sourceBundleID != bundleID { return false }
        }
        if let since, item.copiedAt < since {
            return false
        }
        return true
    }
}

nonisolated enum AppFilter: Hashable, Sendable {
    case all
    case unknown
    case app(bundleID: String)
}

nonisolated struct SourceApp: Hashable, Sendable, Identifiable {
    let bundleID: String?
    let name: String
    var itemCount: Int

    var id: String { bundleID ?? "" }

    var filter: AppFilter {
        bundleID.map { .app(bundleID: $0) } ?? .unknown
    }

    static func displayOrder(_ a: SourceApp, _ b: SourceApp) -> Bool {
        if (a.bundleID == nil) != (b.bundleID == nil) { return b.bundleID == nil }
        return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
    }
}

enum Timeframe: String, CaseIterable, Identifiable {
    case anyTime, lastHour, today, last7Days, last30Days

    var id: Self { self }

    var title: String {
        switch self {
        case .anyTime: "Any time"
        case .lastHour: "Last hour"
        case .today: "Today"
        case .last7Days: "Last 7 days"
        case .last30Days: "Last 30 days"
        }
    }

    func startDate(now: Date = .now, calendar: Calendar = .current) -> Date? {
        switch self {
        case .anyTime: nil
        case .lastHour: now.addingTimeInterval(-3600)
        case .today: calendar.startOfDay(for: now)
        case .last7Days: calendar.date(byAdding: .day, value: -7, to: now)
        case .last30Days: calendar.date(byAdding: .day, value: -30, to: now)
        }
    }
}
