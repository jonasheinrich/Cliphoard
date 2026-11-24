import SwiftUI
import AppKit
import Carbon.HIToolbox

enum HistoryLimit {
    static let key = "maxHistoryItems"
    static let defaultValue = 10_000

    static var current: Int {
        let value = UserDefaults.standard.integer(forKey: key)
        return value > 0 ? value : defaultValue
    }
}

struct SettingsView: View {
    let monitor: ClipboardMonitor
    @Bindable var hotKeys: GlobalHotKeyController

    @AppStorage(HistoryLimit.key) private var maxItems = HistoryLimit.defaultValue
    @State private var draftLimit = HistoryLimit.current
    @State private var pendingLimit: Int?
    @AppStorage(SecretDetector.byContentKey) private var detectSecretsByContent = true

    var body: some View {
        Form {
            Section("History") {
                TextField("Maximum items", value: $draftLimit, format: .number)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: draftLimit) { requestLimit(draftLimit) }
                Text("When the history is full, the oldest items are deleted.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Secrets") {
                Toggle("Detect passwords and tokens by their content", isOn: $detectSecretsByContent)
                    .onChange(of: detectSecretsByContent) {
                        monitor.detectSecretsByContent = detectSecretsByContent
                    }
                Text("""
                    Items that password managers mark as concealed or that are copied from them \
                    are always secrets. Secrets are encrypted, hidden in the list and left out \
                    of searches; showing or copying one needs Touch ID or your password.
                    """)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Global Shortcut") {
                Toggle("Bring Cliphoard to the front from any app", isOn: $hotKeys.isEnabled)
                LabeledContent("Shortcut") {
                    HotKeyRecorder(controller: hotKeys)
                }
                .disabled(!hotKeys.isEnabled)
                if let error = hotKeys.registrationError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .confirmationDialog(
            "Delete old items?",
            isPresented: Binding(get: { pendingLimit != nil }, set: { if !$0 { cancelLimit() } }),
            presenting: pendingLimit
        ) { limit in
            Button("Delete \((monitor.historyCount() - limit).formatted()) Items", role: .destructive) {
                applyLimit(limit)
            }
            Button("Cancel", role: .cancel, action: cancelLimit)
        } message: { limit in
            Text("Only the newest \(limit.formatted()) items will be kept. This can't be undone.")
        }
    }

    private func requestLimit(_ limit: Int) {
        guard limit >= 1 else {
            draftLimit = maxItems
            return
        }
        guard limit != maxItems else { return }
        if limit < monitor.historyCount() {
            pendingLimit = limit
        } else {
            applyLimit(limit)
        }
    }

    private func applyLimit(_ limit: Int) {
        maxItems = limit
        monitor.maxItems = limit
        pendingLimit = nil
    }

    private func cancelLimit() {
        pendingLimit = nil
        draftLimit = maxItems
    }
}

private struct HotKeyRecorder: View {
    let controller: GlobalHotKeyController

    @State private var isRecording = false
    @State private var eventMonitor: Any?

    var body: some View {
        HStack {
            Button {
                isRecording ? stopRecording() : startRecording()
            } label: {
                Text(isRecording ? "Type shortcut…" : controller.hotKey.displayString)
                    .frame(minWidth: 110)
            }
            .help(isRecording ? "Press Esc to cancel" : "Click to change")

            Button("Reset") { controller.hotKey = .default }
                .disabled(controller.hotKey == .default)
        }
        .onDisappear(perform: stopRecording)
    }

    private func startRecording() {
        isRecording = true
        controller.isPaused = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                stopRecording()
            } else if let hotKey = HotKey(event: event) {
                controller.hotKey = hotKey
                stopRecording()
            } else {
                NSSound.beep()
            }
            return nil
        }
    }

    private func stopRecording() {
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
        eventMonitor = nil
        isRecording = false
        controller.isPaused = false
    }
}
