import SwiftUI

struct ContentView: View {
    let monitor: ClipboardMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Latest clipboard item")
                .font(.headline)

            if let text = monitor.latestText {
                ScrollView {
                    Text(text)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 6))

                if let date = monitor.lastChanged {
                    Text("Copied \(date, style: .relative) ago")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

#Preview {
    ContentView(monitor: ClipboardMonitor())
}
