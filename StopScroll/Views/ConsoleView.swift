import SwiftUI

struct ConsoleView: View {
    @Binding var isPresented: Bool
    @ObservedObject var logManager = LogManager.shared
    @State private var filterLevel: LogLevel? = nil
    @State private var filterCategory: String = ""
    @State private var autoScroll = true

    private var filteredLogs: [LogEntry] {
        var filtered = logManager.logs

        if let level = filterLevel {
            filtered = filtered.filter { $0.level == level }
        }

        if !filterCategory.isEmpty {
            filtered = filtered.filter { $0.category.lowercased().contains(filterCategory.lowercased()) }
        }

        return filtered
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter Bar
                HStack(spacing: 8) {
                    Menu {
                        Button("All") { filterLevel = nil }
                        Divider()
                        ForEach([LogLevel.debug, .info, .warning, .error, .critical], id: \.self) { level in
                            Button(level.rawValue) { filterLevel = level }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            Text(filterLevel?.rawValue ?? "All")
                                .font(.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .clipShape(Capsule())
                    }

                    TextField("Category filter", text: $filterCategory)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)

                    Spacer()

                    Menu {
                        Button("Clear logs") {
                            logManager.clearLogs()
                        }
                        Button("Export") {
                            UIPasteboard.general.string = logManager.exportLogs()
                        }
                        Toggle("Auto-scroll", isOn: $autoScroll)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                .padding(8)
                .background(Color(white: 0.08))

                // Logs List
                ScrollViewReader { scrollProxy in
                    List {
                        ForEach(filteredLogs, id: \.timestamp) { entry in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(entry.level.emoji)
                                        .font(.caption)
                                    Text(entry.timestamp)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.gray)
                                    Text(entry.category)
                                        .font(.caption)
                                        .padding(.horizontal, 4)
                                        .background(Color.blue.opacity(0.3))
                                        .clipShape(Capsule())
                                }
                                Text(entry.message)
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .lineLimit(nil)
                                Text(entry.source)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 2)
                            .id(entry.timestamp)
                        }
                    }
                    .listStyle(.plain)
                    .onChange(of: filteredLogs.count) { _ in
                        if autoScroll, let lastLog = filteredLogs.last {
                            scrollProxy.scrollTo(lastLog.timestamp, anchor: .bottom)
                        }
                    }
                }
            }
            .background(Color(white: 0.06))
            .navigationTitle("Debug Console")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("\(filteredLogs.count) logs")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ConsoleView(isPresented: .constant(true))
}
