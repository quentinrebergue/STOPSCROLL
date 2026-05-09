import Foundation
import Combine
import SwiftUI

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

    /// Enabled article sources for culture cards (e.g. "wikipedia", "guardian").
    @Published var articleSources: Set<String> {
        didSet { UserDefaults.standard.set(Array(articleSources), forKey: Keys.articleSources) }
    }

    /// Developer mode: shows debug info in cards when something fails.
    @Published var devMode: Bool {
        didSet { UserDefaults.standard.set(devMode, forKey: Keys.devMode) }
    }

    /// Maximum normal session duration in minutes (home/search/reels). Default 30 min.
    @Published var normalSessionMaxMinutes: Int {
        didSet { UserDefaults.standard.set(normalSessionMaxMinutes, forKey: Keys.normalSessionMax) }
    }

    /// Maximum long session duration in minutes (once per day). Default 60 min.
    @Published var longSessionMaxMinutes: Int {
        didSet { UserDefaults.standard.set(longSessionMaxMinutes, forKey: Keys.longSessionMax) }
    }

    /// Most recent Instagram UI language reported by the WebView (BCP-47, e.g. "fr", "en-US").
    @Published private(set) var detectedLanguage: String = ""

    /// Last detected Instagram app background color (CSS format, e.g. rgb(18, 18, 18)).
    @Published private(set) var instagramBackgroundCSS: String {
        didSet { UserDefaults.standard.set(instagramBackgroundCSS, forKey: Keys.instagramBackgroundCSS) }
    }

    /// Increments when the user requests a manual background refresh from Settings.
    @Published private(set) var backgroundRefreshToken: Int = 0

    /// Increments when a live Instagram color change should lazily invalidate other webviews.
    @Published private(set) var lazyWebViewRefreshToken: Int = 0

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
        if let savedSources = UserDefaults.standard.array(forKey: Keys.articleSources) as? [String] {
            articleSources = Set(savedSources)
        } else {
            articleSources = ["wikipedia"]
        }
        devMode = UserDefaults.standard.bool(forKey: Keys.devMode)
        instagramBackgroundCSS = UserDefaults.standard.string(forKey: Keys.instagramBackgroundCSS) ?? "rgb(0, 0, 0)"
        normalSessionMaxMinutes = (UserDefaults.standard.object(forKey: Keys.normalSessionMax) as? Int) ?? 30
        longSessionMaxMinutes   = (UserDefaults.standard.object(forKey: Keys.longSessionMax) as? Int) ?? 60
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

    // MARK: - Instagram background color

    func requestBackgroundRefresh() {
        DispatchQueue.main.async {
            self.backgroundRefreshToken += 1
        }
    }

    func updateInstagramBackgroundColor(
        _ cssColor: String?,
        invalidateOtherWebViewsLazily: Bool = false
    ) {
        guard let cssColor = cssColor?.trimmingCharacters(in: .whitespacesAndNewlines),
              let normalized = Self.normalizedCSSColor(cssColor) else {
            return
        }

        DispatchQueue.main.async {
            guard self.instagramBackgroundCSS != normalized else { return }
            self.instagramBackgroundCSS = normalized
            if invalidateOtherWebViewsLazily {
                self.lazyWebViewRefreshToken += 1
            }
        }
    }

    var instagramBackgroundRGBA: (red: Double, green: Double, blue: Double, alpha: Double)? {
        Self.parseCSSColor(instagramBackgroundCSS)
    }

    struct AdaptivePalette {
        let background: Color
        let surface: Color
        let elevatedSurface: Color
        let primaryText: Color
        let secondaryText: Color
        let border: Color
    }

    var adaptivePalette: AdaptivePalette {
        let rgba = instagramBackgroundRGBA ?? (red: 0, green: 0, blue: 0, alpha: 1)
        let base = (
            red: Self.clamp01(rgba.red / 255.0),
            green: Self.clamp01(rgba.green / 255.0),
            blue: Self.clamp01(rgba.blue / 255.0)
        )

        let background = Color(.sRGB, red: base.red, green: base.green, blue: base.blue, opacity: 1)

        if isInstagramBackgroundDarkByRGBSum {
            let surface = Self.mix(base, with: (1, 1, 1), amount: 0.08)
            let elevated = Self.mix(base, with: (1, 1, 1), amount: 0.14)
            return AdaptivePalette(
                background: background,
                surface: Color(.sRGB, red: surface.red, green: surface.green, blue: surface.blue, opacity: 1),
                elevatedSurface: Color(.sRGB, red: elevated.red, green: elevated.green, blue: elevated.blue, opacity: 1),
                primaryText: Color.white.opacity(0.96),
                secondaryText: Color.white.opacity(0.68),
                border: Color.white.opacity(0.12)
            )
        }

        let surface = Self.mix(base, with: (0, 0, 0), amount: 0.04)
        let elevated = Self.mix(base, with: (0, 0, 0), amount: 0.1)
        return AdaptivePalette(
            background: background,
            surface: Color(.sRGB, red: surface.red, green: surface.green, blue: surface.blue, opacity: 1),
            elevatedSurface: Color(.sRGB, red: elevated.red, green: elevated.green, blue: elevated.blue, opacity: 1),
            primaryText: Color.black.opacity(0.9),
            secondaryText: Color.black.opacity(0.58),
            border: Color.black.opacity(0.12)
        )
    }

    /// Global app mode derived from Instagram background color using RGB sum.
    var preferredColorScheme: ColorScheme {
        isInstagramBackgroundDarkByRGBSum ? .dark : .light
    }

    var isInstagramBackgroundDarkByRGBSum: Bool {
        guard let rgba = instagramBackgroundRGBA else { return true }
        let rgbSum = rgba.red + rgba.green + rgba.blue
        return rgbSum < Self.darkModeRGBSumThreshold
    }

    private static let darkModeRGBSumThreshold: Double = 382.5

    private static func clamp01(_ value: Double) -> Double {
        max(0, min(1, value))
    }

    private static func mix(
        _ lhs: (red: Double, green: Double, blue: Double),
        with rhs: (Double, Double, Double),
        amount: Double
    ) -> (red: Double, green: Double, blue: Double) {
        let t = clamp01(amount)
        return (
            red: lhs.red + (rhs.0 - lhs.red) * t,
            green: lhs.green + (rhs.1 - lhs.green) * t,
            blue: lhs.blue + (rhs.2 - lhs.blue) * t
        )
    }

    private static func normalizedCSSColor(_ cssColor: String) -> String? {
        guard let parsed = parseCSSColor(cssColor) else { return nil }
        if parsed.alpha < 0.999 {
            return "rgba(\(parsed.red), \(parsed.green), \(parsed.blue), \(parsed.alpha))"
        }
        return "rgb(\(parsed.red), \(parsed.green), \(parsed.blue))"
    }

    private static func parseCSSColor(_ cssColor: String) -> (red: Double, green: Double, blue: Double, alpha: Double)? {
        let input = cssColor.replacingOccurrences(of: " ", with: "")
        if input.hasPrefix("rgb(") {
            guard input.hasSuffix(")") else { return nil }
            let body = String(input.dropFirst(4).dropLast())
            let values = body.split(separator: ",")
            guard values.count == 3,
                  let r = Double(values[0]),
                  let g = Double(values[1]),
                  let b = Double(values[2]) else {
                return nil
            }
            return (red: r, green: g, blue: b, alpha: 1.0)
        }
        if input.hasPrefix("rgba(") {
            guard input.hasSuffix(")") else { return nil }
            let body = String(input.dropFirst(5).dropLast())
            let values = body.split(separator: ",")
            guard values.count == 4,
                  let r = Double(values[0]),
                  let g = Double(values[1]),
                  let b = Double(values[2]),
                  let a = Double(values[3]) else {
                return nil
            }
            return (red: r, green: g, blue: b, alpha: a)
        }
        return nil
    }

    // MARK: - UserDefaults keys

    private enum Keys {
        static let adLabels             = "ss_ad_labels"
        static let injectionFrequency   = "ss_injection_frequency"
        static let articleSources       = "ss_article_sources"
        static let devMode              = "ss_dev_mode"
        static let instagramBackgroundCSS = "ss_instagram_background_css"
        static let normalSessionMax     = "ss_normal_session_max"
        static let longSessionMax       = "ss_long_session_max"
    }
}
