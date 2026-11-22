import SwiftUI

/// Search field, app picker and timeframe picker shown above the history.
struct FilterBar: View {
    @Binding var searchText: String
    @Binding var app: AppFilter
    @Binding var timeframe: Timeframe
    /// Apps to offer in the picker.
    let apps: [SourceApp]
    /// Called when ↩ is pressed in the search field.
    var onSubmitSearch: () -> Void = {}

    private var isActive: Bool {
        !searchText.isEmpty || app != .all || timeframe != .anyTime
    }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search", text: $searchText, prompt: Text("Search text"))
                    .textFieldStyle(.plain)
                    .onSubmit(onSubmitSearch)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Label("Clear search", systemImage: "xmark.circle.fill")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 6))

            Picker("App", selection: $app) {
                Text("All apps").tag(AppFilter.all)
                if !apps.isEmpty {
                    Divider()
                }
                ForEach(apps) { sourceApp in
                    Text("\(sourceApp.name) (\(sourceApp.itemCount))")
                        .tag(sourceApp.filter)
                }
            }
            .labelsHidden()
            .fixedSize()
            .help("Only items copied from this app")

            Picker("Timeframe", selection: $timeframe) {
                ForEach(Timeframe.allCases) { timeframe in
                    Text(timeframe.title).tag(timeframe)
                }
            }
            .labelsHidden()
            .fixedSize()
            .help("Only items copied in this timeframe")

            // Always shown so the bar doesn't shift; disabled without filters.
            Button("Clear") {
                searchText = ""
                app = .all
                timeframe = .anyTime
            }
            .disabled(!isActive)
            .help("Show all items")
        }
    }
}
