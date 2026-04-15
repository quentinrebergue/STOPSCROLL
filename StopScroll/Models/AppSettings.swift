import Foundation
import Combine

/// Persistent user-editable settings for StopScroll, stored in UserDefaults.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // MARK: - Published state

    /// Labels used to detect sponsored / suggested posts (lowercase, trimmed).
    @Published private(set) var adLabels: [String] {
        didSet { UserDefaults.standard.set(adLabels, forKey: Keys.adLabels) }
    }

    /// Card injection frequency: replace 1 out of every N detected posts. 0 = disabled.
    @Published var injectionFrequency: Int {
        didSet { UserDefaults.standard.set(injectionFrequency, forKey: Keys.injectionFrequency) }
    }

    /// Most recent Instagram UI language reported by the WebView (BCP-47, e.g. "fr", "en-US").
    @Published private(set) var detectedLanguage: String = ""

    // MARK: - Built-in defaults per language prefix

    static let defaultLabels: [String: [String]] = [
        "fr": ["sponsorisé", "suggestion pour vous", "publicité"],
        "en": ["sponsored", "suggested for you"],
        "es": ["patrocinado", "sugerido para ti"],
        "de": ["gesponsert", "vorschlag für dich"],
        "it": ["sponsorizzato", "suggerito per te"],
        "pt": ["patrocinado", "sugerido para você"],
        "ar": ["ممول", "اقتراح لك"],
        "zh": ["赞助内容", "推荐给你"],
        "ja": ["スポンサー", "あなたへのおすすめ"],
        "ko": ["광고", "추천 게시물"]
    ]

    // MARK: - Init

    private init() {
        if let saved = UserDefaults.standard.array(forKey: Keys.adLabels) as? [String] {
            adLabels = saved
        } else {
            adLabels = []
        }
        let savedFreq = UserDefaults.standard.object(forKey: Keys.injectionFrequency)
        injectionFrequency = (savedFreq as? Int) ?? 1
    }

    // MARK: - Language seeding

    /// Called when the WebView detects Instagram's UI language.
    /// Auto-populates the label list only when it is still empty (first launch).
    func seedLabels(forLanguage lang: String) {
        DispatchQueue.main.async {
            self.detectedLanguage = lang
            guard self.adLabels.isEmpty else { return }
            let prefix = String(lang.prefix(2)).lowercased()
            self.adLabels = AppSettings.defaultLabels[prefix] ?? []
        }
    }

    // MARK: - Label editing

    func addLabel(_ raw: String) {
        let label = raw.trimmingCharacters(in: .whitespaces).lowercased()
        guard !label.isEmpty, !adLabels.contains(label) else { return }
        adLabels.append(label)
    }

    func removeLabel(at offsets: IndexSet) {
        adLabels.remove(atOffsets: offsets)
    }

    func resetToDefaults(forLanguage lang: String) {
        let prefix = String(lang.prefix(2)).lowercased()
        adLabels = AppSettings.defaultLabels[prefix] ?? []
    }

    // MARK: - UserDefaults keys

    private enum Keys {
        static let adLabels = "ss_ad_labels"
        static let injectionFrequency = "ss_injection_frequency"
    }
}
