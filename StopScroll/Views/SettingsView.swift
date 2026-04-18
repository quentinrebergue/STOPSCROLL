import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var newLabel = ""
    @State private var showResetAlert = false
    let onDismiss: () -> Void
    var onOpenDashboard: (() -> Void)? = nil

    /// Discrete frequency steps mapped to slider positions.
    /// 0 = off (no cards injected).
    private static let frequencySteps: [Int] = [1, 2, 3, 5, 10, 20, 30, 50, 100, 0]

    /// Slider index (0..steps.count-1) mapped to the actual frequency value.
    @State private var freqSliderIndex: Double = 0

    private var langDisplay: String {
        settings.detectedLanguage.isEmpty ? "unknown" : settings.detectedLanguage
    }

    private var currentFreq: Int {
        let idx = Int(freqSliderIndex.rounded())
        return Self.frequencySteps[min(idx, Self.frequencySteps.count - 1)]
    }

    private var freqLabel: String {
        let f = currentFreq
        if f == 0 { return "Off" }
        if f == 1 { return "Every post" }
        return "1 / \(f) posts"
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

                    if let onOpenDashboard {
                        Button {
                            onOpenDashboard()
                        } label: {
                            Label("Open Dashboard", systemImage: "chart.bar.xaxis")
                                .foregroundColor(.blue)
                        }
                    }
                }

                // Card injection frequency
                Section(header: Text("Card frequency")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Injection rate")
                            Spacer()
                            Text(freqLabel)
                                .foregroundColor(.secondary)
                        }
                        Slider(
                            value: $freqSliderIndex,
                            in: 0...Double(Self.frequencySteps.count - 1),
                            step: 1
                        )
                        .onChange(of: freqSliderIndex) { _ in
                            settings.injectionFrequency = currentFreq
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Article source
                Section(header: Text("Article sources")) {
                    Toggle("Wikipedia", isOn: Binding(
                        get: { settings.articleSources.contains("wikipedia") },
                        set: { enabled in
                            if enabled { settings.articleSources.insert("wikipedia") }
                            else { settings.articleSources.remove("wikipedia") }
                        }
                    ))
                    Toggle("The Guardian", isOn: Binding(
                        get: { settings.articleSources.contains("guardian") },
                        set: { enabled in
                            if enabled { settings.articleSources.insert("guardian") }
                            else { settings.articleSources.remove("guardian") }
                        }
                    ))
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

                // Developer
                Section(header: Text("Developer")) {
                    Toggle("Dev mode", isOn: $settings.devMode)
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
        .onAppear {
            if let idx = Self.frequencySteps.firstIndex(of: settings.injectionFrequency) {
                freqSliderIndex = Double(idx)
            }
        }
    }
}
