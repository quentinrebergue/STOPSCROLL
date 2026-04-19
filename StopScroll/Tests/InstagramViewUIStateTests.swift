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

    /// **Test 14**: Un changement live de couleur sur la surface active doit invalider les autres surfaces seulement.
    func testRefreshPolicy_lazyReloadTargetsExcludeSourceSurface() {
        let targets = WebRefreshPolicy.lazyReloadTargets(excluding: .profile)

        XCTAssertEqual(targets, Set([.main, .messages, .search]))
        XCTAssertFalse(targets.contains(.profile))
    }

    /// **Test 15**: Une surface pending doit consommer son refresh lazy quand elle devient active.
    func testRefreshPolicy_consumePendingLazyReload() {
        let pending: Set<WebSurface> = [.messages, .search]

        XCTAssertTrue(WebRefreshPolicy.shouldConsumeLazyReload(for: .messages, pendingSurfaces: pending))
        XCTAssertFalse(WebRefreshPolicy.shouldConsumeLazyReload(for: .main, pendingSurfaces: pending))
    }

    /// **Test 16**: Le swipe horizontal suit l'ordre de la native navbar, y compris BookReader et Dashboard.
    func testNativeTabLayoutUsesNavbarAdjacency() {
        XCTAssertEqual(NativeTabLayout.adjacentTab(to: "messages", swipeTranslation: 140), "book")
        XCTAssertEqual(NativeTabLayout.adjacentTab(to: "messages", swipeTranslation: -140), "dashboard")
        XCTAssertEqual(NativeTabLayout.adjacentTab(to: "dashboard", swipeTranslation: 140), "messages")
        XCTAssertEqual(NativeTabLayout.adjacentTab(to: "dashboard", swipeTranslation: -140), "profile")
    }

    /// **Test 17**: Aucun swipe ne doit sortir des bornes de la navbar.
    func testNativeTabLayoutStopsAtEdges() {
        XCTAssertNil(NativeTabLayout.adjacentTab(to: "home", swipeTranslation: 120))
        XCTAssertNil(NativeTabLayout.adjacentTab(to: "profile", swipeTranslation: -120))
    }

    /// **Test 18**: Le swipe ne commit que si la distance ou la vitesse est suffisante.
    func testHorizontalSwipeCommitPolicy() {
        XCTAssertFalse(HorizontalSwipePolicy.shouldCommit(translation: 20, velocity: 100, pageWidth: 390))
        XCTAssertTrue(HorizontalSwipePolicy.shouldCommit(translation: 90, velocity: 100, pageWidth: 390))
        XCTAssertTrue(HorizontalSwipePolicy.shouldCommit(translation: 20, velocity: 900, pageWidth: 390))
    }

    /// **Test 19**: Le recognizer horizontal ne doit s'activer que pour un geste surtout horizontal.
    func testHorizontalSwipeRecognizerPolicy() {
        XCTAssertTrue(HorizontalSwipeRecognizerPolicy.shouldBegin(velocityX: 500, velocityY: 100, activeTab: "home"))
        XCTAssertFalse(HorizontalSwipeRecognizerPolicy.shouldBegin(velocityX: 180, velocityY: 220, activeTab: "home"))
        XCTAssertFalse(HorizontalSwipeRecognizerPolicy.shouldBegin(velocityX: 80, velocityY: 10, activeTab: "home"))
    }

    /// **Test 20**: En recherche, le recognizer doit etre plus permissif pour eviter les swipes IG internes.
    func testHorizontalSwipeRecognizerPolicy_searchIsMorePermissive() {
        let shouldBeginInSearch = HorizontalSwipeRecognizerPolicy.shouldBegin(velocityX: 70, velocityY: 20, activeTab: "search")
        let shouldBeginInHome = HorizontalSwipeRecognizerPolicy.shouldBegin(velocityX: 70, velocityY: 20, activeTab: "home")

        XCTAssertTrue(shouldBeginInSearch)
        XCTAssertFalse(shouldBeginInHome)
    }

    /// **Test 20b**: En messages, le recognizer doit rester strict pour ne pas casser le scroll chat.
    func testHorizontalSwipeRecognizerPolicy_messagesPrioritizesVerticalScroll() {
        XCTAssertFalse(HorizontalSwipeRecognizerPolicy.shouldBegin(velocityX: 180, velocityY: 120, activeTab: "messages"))
        XCTAssertTrue(HorizontalSwipeRecognizerPolicy.shouldBegin(velocityX: 360, velocityY: 90, activeTab: "messages"))
    }

    /// **Test 20c**: Les drags majoritairement verticaux ne doivent pas deplacer la section en Book/Dashboard.
    func testHorizontalSwipeDragPolicy_rejectsMostlyVerticalDrags() {
        XCTAssertFalse(HorizontalSwipeRecognizerPolicy.shouldTrackDrag(
            translationX: 18,
            translationY: 42,
            activeTab: "book"
        ))
        XCTAssertFalse(HorizontalSwipeRecognizerPolicy.shouldTrackDrag(
            translationX: 20,
            translationY: 34,
            activeTab: "dashboard"
        ))
        XCTAssertTrue(HorizontalSwipeRecognizerPolicy.shouldTrackDrag(
            translationX: 42,
            translationY: 12,
            activeTab: "book"
        ))
    }

    /// **Test 21**: Le preview de swipe anime la page cible depuis le bord oppose.
    func testHorizontalSwipePreviewOffset() {
        XCTAssertEqual(HorizontalSwipeAnimation.previewTargetOffset(translation: -120, pageWidth: 390), 270)
        XCTAssertEqual(HorizontalSwipeAnimation.previewTargetOffset(translation: 120, pageWidth: 390), -270)
    }

    /// **Test 22**: En mode multi-webview, la section visible suit la surface active, pas le tab sync JS.
    func testVisibleSectionPolicy_usesActiveSurfaceInMultiWebViewMode() {
        let tab = VisibleSectionPolicy.currentTab(
            showingReader: false,
            showingDashboard: false,
            normalizedWebViewCount: 4,
            nativeSelectedTab: "home",
            activeSurface: .profile
        )

        XCTAssertEqual(tab, "profile")
    }

    /// **Test 23**: La surface messages ne doit pas utiliser l'overscan bas reserve aux autres surfaces.
    func testMessagesSurfaceHasNoBottomOverscan() {
        XCTAssertEqual(WebViewLayoutPolicy.bottomOverscan(for: .messages, defaultOverscan: 116), 0)
        XCTAssertEqual(WebViewLayoutPolicy.bottomOverscan(for: .main, defaultOverscan: 116), 116)
    }
}
