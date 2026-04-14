import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var newLabel = ""
    @State private var showResetAlert = false
    let onDismiss: () -> Void

    private var langDisplay: String {
        settings.detectedLanguage.isEmpty ? "unknown" : settings.detectedLanguage
    }

    var body: some View {
        NavigationView {
            List {
                // Header info
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Ad detection labels", systemImage: "doc.text.magnifyingglass")
                            .font(.headline)
                        Text("Posts whose label matches an entry below are replaced in-place by a StopScroll card. No scroll jump, no real content lost.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if !settings.detectedLanguage.isEmpty {
                            Text("Detected Instagram language: **\(langDisplay)**")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Current labels (swipe to delete)
                Section(header: Text("Active labels")) {
                    if settings.adLabels.isEmpty {
                        Text("No labels yet. Add one below or tap \"Reset to defaults\".")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(settings.adLabels, id: \.self) { label in
                            Text(label)
                        }
                        .onDelete(perform: settings.removeLabel)
                    }
                }

                // Add label
                Section(header: Text("Add label")) {
                    HStack {
                        TextField("e.g. sponsored", text: $newLabel)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                        Button("Add") {
                            settings.addLabel(newLabel)
                            newLabel = ""
                        }
                        .disabled(newLabel.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                // Reset
                Section {
                    Button("Reset to defaults (\(langDisplay))") {
                        showResetAlert = true
                    }
                    .foregroundColor(.orange)
                }
            }
            .navigationTitle("StopScroll Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done", action: onDismiss)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .alert("Reset labels?", isPresented: $showResetAlert) {
                Button("Reset", role: .destructive) {
                    settings.resetToDefaults(forLanguage: settings.detectedLanguage)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This replaces your custom labels with the defaults for \"\(langDisplay)\".")
            }
        }
        .preferredColorScheme(.dark)
    }
}
