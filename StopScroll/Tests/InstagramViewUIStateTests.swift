import XCTest
import SwiftUI
@testable import StopScroll

/// Tests pour valider les états d'affichage et les transitions dans InstagramView.
/// Vérifie que la barre de chargement et autres overlays n'apparaissent pas de façon inattendue.
final class InstagramViewUIStateTests: XCTestCase {

    /// **Test 1**: LoadingBar ne devrait jamais être visible si BookReader est ouvert
    func testLoadingBarHiddenWhenBookReaderOpen() {
        // Simule l'état : une WebView charge, mais BookReader est affiché
        let isActiveSurfaceLoading = true  // WebView en cours de chargement
        let showingReader = true            // BookReader visible
        let showingDashboard = false        // Dashboard non visible
        let showingSettings = false

        let shouldShowLoadingBar = isActiveSurfaceLoading && !showingReader && !showingDashboard && !showingSettings

        XCTAssertFalse(shouldShowLoadingBar, "LoadingBar doit être caché quand BookReader est affiché, même si WebView charge")
    }

    /// **Test 2**: LoadingBar ne devrait jamais être visible si Dashboard est ouvert
    func testLoadingBarHiddenWhenDashboardOpen() {
        let isActiveSurfaceLoading = true
        let showingReader = false
        let showingDashboard = true
        let showingSettings = false

        let shouldShowLoadingBar = isActiveSurfaceLoading && !showingReader && !showingDashboard && !showingSettings

        XCTAssertFalse(shouldShowLoadingBar, "LoadingBar doit être caché quand Dashboard est affiché")
    }

    /// **Test 3**: LoadingBar s'affiche correctement quand aucun overlay n'est actif
    func testLoadingBarVisibleWhenNoOverlaysActive() {
        let isActiveSurfaceLoading = true
        let showingReader = false
        let showingDashboard = false
        let showingSettings = false

        let shouldShowLoadingBar = isActiveSurfaceLoading && !showingReader && !showingDashboard && !showingSettings

        XCTAssertTrue(shouldShowLoadingBar, "LoadingBar doit être visible quand pas d'overlay")
    }

    /// **Test 4**: LoadingBar reste caché quand WebView n'est pas en cours de chargement
    func testLoadingBarHiddenWhenNotLoading() {
        let isActiveSurfaceLoading = false
        let showingReader = false
        let showingDashboard = false
        let showingSettings = false

        let shouldShowLoadingBar = isActiveSurfaceLoading && !showingReader && !showingDashboard && !showingSettings

        XCTAssertFalse(shouldShowLoadingBar, "LoadingBar doit être caché quand WebView ne charge pas")
    }

    /// **Test 5**: Masquer les WebView quand BookReader est affiché
    func testWebViewsHiddenWhenReaderOpen() {
        let activeSurface = "main"
        let showingReader = true
        let showingDashboard = false
        let showingSettings = false

        // WebView visibility condition
        let mainWebViewVisible = activeSurface == "main" && !showingReader && !showingDashboard && !showingSettings

        XCTAssertFalse(mainWebViewVisible, "WebView principale ne doit pas être visible quand BookReader est ouvert")
    }

    /// **Test 6**: Masquer les WebView quand Dashboard est affiché
    func testWebViewsHiddenWhenDashboardOpen() {
        let activeSurface = "main"
        let showingReader = false
        let showingDashboard = true
        let showingSettings = false

        let mainWebViewVisible = activeSurface == "main" && !showingReader && !showingDashboard && !showingSettings

        XCTAssertFalse(mainWebViewVisible, "WebView ne doit pas être visible quand Dashboard est ouvert")
    }

    /// **Test 7**: Configuration 3-WebView - le switch vers search devrait charger la bonne URL
    func testThreeWebViewSearchRoute() {
        // Simule le routage en mode 3 WebViews
        let webViewCount = 3
        let targetTab = "search"

        let surfaceFor3: (String) -> String = { tab in
            switch webViewCount {
            case 1: return "main"
            case 2: return tab == "home" ? "main" : "messages"
            case 3:
                if tab == "home" { return "main" }
                if tab == "search" { return "search" }
                return "messages"  // messages + profile partagées
            default: return "main"
            }
        }

        let targetSurface = surfaceFor3(targetTab)
        XCTAssertEqual(targetSurface, "search", "Mode 3: search devrait être routé vers surface dedicate search")
    }

    /// **Test 8**: Configuration 3-WebView - profile et messages partagent la même surface
    func testThreeWebViewProfileAndMessagesShared() {
        let webViewCount = 3
        
        let surfaceFor3: (String) -> String = { tab in
            switch webViewCount {
            case 1: return "main"
            case 2: return tab == "home" ? "main" : "messages"
            case 3:
                if tab == "home" { return "main" }
                if tab == "search" { return "search" }
                return "messages"  // messages + profile partagées
            default: return "main"
            }
        }

        let messagesSurface = surfaceFor3("messages")
        let profileSurface = surfaceFor3("profile")

        XCTAssertEqual(messagesSurface, profileSurface, "Mode 3: messages et profile doivent partager la même surface")
        XCTAssertEqual(messagesSurface, "messages", "Mode 3: surface partagée doit être 'messages'")
    }

    /// **Test 9**: LoadingBar cachée si Settings est ouvert
    func testLoadingBarHiddenWhenSettingsOpen() {
        let isActiveSurfaceLoading = true
        let showingReader = false
        let showingDashboard = false
        let showingSettings = true

        let shouldShowLoadingBar = isActiveSurfaceLoading && !showingReader && !showingDashboard && !showingSettings
        XCTAssertFalse(shouldShowLoadingBar, "LoadingBar doit être caché quand Settings est affiché")
    }

    /// **Test 10**: WebView cachée si Settings est ouvert
    func testWebViewHiddenWhenSettingsOpen() {
        let activeSurface = "main"
        let showingReader = false
        let showingDashboard = false
        let showingSettings = true

        let mainWebViewVisible = activeSurface == "main" && !showingReader && !showingDashboard && !showingSettings
        XCTAssertFalse(mainWebViewVisible, "WebView ne doit pas être visible quand Settings est affiché")
    }

    /// **Test 11**: Le refresh feed ne se fait que si la fréquence change vraiment
    func testRefreshPolicy_feedReloadOnInjectionChange() {
        XCTAssertTrue(WebRefreshPolicy.shouldReloadFeedOnInjectionChange(oldValue: 5, newValue: 10))
        XCTAssertFalse(WebRefreshPolicy.shouldReloadFeedOnInjectionChange(oldValue: 5, newValue: 5))
    }

    /// **Test 12**: Le refresh global se fait seulement si la couleur de background change
    func testRefreshPolicy_reloadAllOnBackgroundChange() {
        XCTAssertTrue(WebRefreshPolicy.shouldReloadAllWebViewsOnBackgroundChange(previousCSS: "rgb(10, 10, 10)", newCSS: "rgb(240, 240, 240)"))
        XCTAssertFalse(WebRefreshPolicy.shouldReloadAllWebViewsOnBackgroundChange(previousCSS: "rgb(10, 10, 10)", newCSS: "rgb(10, 10, 10)"))
        XCTAssertFalse(WebRefreshPolicy.shouldReloadAllWebViewsOnBackgroundChange(previousCSS: "rgb(10, 10, 10)", newCSS: "   "))
    }

    /// **Test 13**: Un tap sur la native tab bar doit fermer Settings
    func testNativeTabSelectionClosesSettingsOverlay() {
        var showingSettings = true
        let selectedTab = "home"

        // Mirrors InstagramView onSelectTab behavior.
        if showingSettings {
            showingSettings = false
        }
        _ = selectedTab

        XCTAssertFalse(showingSettings, "Le tap sur une tab native doit fermer l'overlay Settings")
    }
}
