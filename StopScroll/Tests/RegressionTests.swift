import XCTest
@testable import StopScroll

// MARK: - XPProgress Extended Tests

final class XPProgressExtendedTests: XCTestCase {

    // Level calculation
    func testLevelStartsAtOne() {
        XCTAssertEqual(XPProgress.level(for: 0), 1)
    }

    func testLevelRemainsOneBeforeThreshold() {
        XCTAssertEqual(XPProgress.level(for: 99), 1)
    }

    func testLevelIncreasesAtThreshold() {
        XCTAssertEqual(XPProgress.level(for: 100), 2)
    }

    func testLevelThirdLevel() {
        XCTAssertEqual(XPProgress.level(for: 200), 3)
    }

    func testLevelNegativeXPClampsToOne() {
        XCTAssertEqual(XPProgress.level(for: -50), 1)
    }

    // XP in current level
    func testXPInCurrentLevelZero() {
        XCTAssertEqual(XPProgress.xpInCurrentLevel(for: 0), 0)
    }

    func testXPInCurrentLevelMidLevel() {
        XCTAssertEqual(XPProgress.xpInCurrentLevel(for: 150), 50)
    }

    func testXPInCurrentLevelAtExactThresholdIsZero() {
        // 200 XP = level 3, 0 XP into it
        XCTAssertEqual(XPProgress.xpInCurrentLevel(for: 200), 0)
    }

    func testXPInCurrentLevelNegativeClampsToZero() {
        XCTAssertEqual(XPProgress.xpInCurrentLevel(for: -10), 0)
    }

    // Progress (0.0 – 1.0)
    func testProgressAtZero() {
        XCTAssertEqual(XPProgress.progress(for: 0), 0.0, accuracy: 0.001)
    }

    func testProgressAtHalfLevel() {
        XCTAssertEqual(XPProgress.progress(for: 50), 0.5, accuracy: 0.001)
    }

    func testProgressResetsAtLevelBoundary() {
        // Exact level boundary should be 0.0 (start of new level)
        XCTAssertEqual(XPProgress.progress(for: 100), 0.0, accuracy: 0.001)
    }

    // Remaining to next level
    func testRemainingAtZeroXPIsFullLevel() {
        XCTAssertEqual(XPProgress.remainingToNextLevel(for: 0), 100)
    }

    func testRemainingAtHalfLevelIsHalf() {
        XCTAssertEqual(XPProgress.remainingToNextLevel(for: 50), 50)
    }

    func testRemainingAtLevelBoundaryIsFullLevel() {
        XCTAssertEqual(XPProgress.remainingToNextLevel(for: 100), 100)
    }
}

// MARK: - SurfaceRouter Tests
// Regression: correct surface assigned per tab in each WebView mode (1-4).

final class SurfaceRouterTests: XCTestCase {

    // Mode 1: everything on main
    func testMode1AllTabsOnMain() {
        for tab in ["home", "search", "messages", "profile"] {
            XCTAssertEqual(SurfaceRouter.surface(for: tab, webViewCount: 1), .main,
                           "Mode 1: \(tab) should always be .main")
        }
    }

    // Mode 2: home → main, others → messages (shared secondary)
    func testMode2HomeIsMain() {
        XCTAssertEqual(SurfaceRouter.surface(for: "home", webViewCount: 2), .main)
    }

    func testMode2SearchIsMessages() {
        XCTAssertEqual(SurfaceRouter.surface(for: "search", webViewCount: 2), .messages)
    }

    func testMode2MessagesIsMessages() {
        XCTAssertEqual(SurfaceRouter.surface(for: "messages", webViewCount: 2), .messages)
    }

    func testMode2ProfileIsMessages() {
        XCTAssertEqual(SurfaceRouter.surface(for: "profile", webViewCount: 2), .messages)
    }

    // Mode 3: home → main, search → search, messages + profile → messages
    func testMode3HomeIsMain() {
        XCTAssertEqual(SurfaceRouter.surface(for: "home", webViewCount: 3), .main)
    }

    func testMode3SearchIsSearch() {
        XCTAssertEqual(SurfaceRouter.surface(for: "search", webViewCount: 3), .search)
    }

    func testMode3MessagesIsMessages() {
        XCTAssertEqual(SurfaceRouter.surface(for: "messages", webViewCount: 3), .messages)
    }

    func testMode3ProfileSharesMessages() {
        // Regression: profile uses the messages surface in mode 3
        XCTAssertEqual(SurfaceRouter.surface(for: "profile", webViewCount: 3), .messages)
    }

    // Mode 4: each tab has its own surface
    func testMode4HomeIsMain() {
        XCTAssertEqual(SurfaceRouter.surface(for: "home", webViewCount: 4), .main)
    }

    func testMode4SearchIsSearch() {
        XCTAssertEqual(SurfaceRouter.surface(for: "search", webViewCount: 4), .search)
    }

    func testMode4MessagesIsMessages() {
        XCTAssertEqual(SurfaceRouter.surface(for: "messages", webViewCount: 4), .messages)
    }

    func testMode4ProfileIsProfile() {
        XCTAssertEqual(SurfaceRouter.surface(for: "profile", webViewCount: 4), .profile)
    }

    // Edge cases: out-of-range counts clamp to 1 or 4
    func testWebViewCountBelowOneClampsToOne() {
        XCTAssertEqual(SurfaceRouter.surface(for: "search", webViewCount: 0), .main)
    }

    func testWebViewCountAboveFourClampsToFour() {
        XCTAssertEqual(SurfaceRouter.surface(for: "profile", webViewCount: 99), .profile)
    }

    // Unknown tab falls back to main
    func testUnknownTabFallsBackToMain() {
        XCTAssertEqual(SurfaceRouter.surface(for: "reels", webViewCount: 3), .main)
        XCTAssertEqual(SurfaceRouter.surface(for: "", webViewCount: 3), .main)
    }
}

// MARK: - InstagramSecondaryRoute Extended Tests
// Regression: correct URLs generated per tab and username handling.

final class InstagramSecondaryRouteExtendedTests: XCTestCase {

    func testMessagesURL() {
        XCTAssertEqual(
            InstagramSecondaryRoute.url(for: "messages", username: ""),
            "https://www.instagram.com/direct/inbox/"
        )
    }

    func testSearchURL() {
        XCTAssertEqual(
            InstagramSecondaryRoute.url(for: "search", username: ""),
            "https://www.instagram.com/explore/"
        )
    }

    func testProfileURLWithCleanUsername() {
        XCTAssertEqual(
            InstagramSecondaryRoute.url(for: "profile", username: "john_doe"),
            "https://www.instagram.com/john_doe/"
        )
    }

    func testProfileURLStripsAtPrefix() {
        // Regression: @username should strip the @
        XCTAssertEqual(
            InstagramSecondaryRoute.url(for: "profile", username: "@john_doe"),
            "https://www.instagram.com/john_doe/"
        )
    }

    func testProfileURLTrimsWhitespace() {
        XCTAssertEqual(
            InstagramSecondaryRoute.url(for: "profile", username: "  john_doe  "),
            "https://www.instagram.com/john_doe/"
        )
    }

    func testProfileURLFiltersSpecialChars() {
        // Special chars like # or spaces should be filtered out
        let url = InstagramSecondaryRoute.url(for: "profile", username: "john#doe")
        XCTAssertEqual(url, "https://www.instagram.com/johndoe/")
    }

    func testProfileURLWithEmptyUsernameReturnsNil() {
        // Regression: empty username should return nil (not crash / not load garbage URL)
        XCTAssertNil(InstagramSecondaryRoute.url(for: "profile", username: ""))
    }

    func testProfileURLWithWhitespaceOnlyUsernameReturnsNil() {
        XCTAssertNil(InstagramSecondaryRoute.url(for: "profile", username: "   "))
    }

    func testHomeTabReturnsNil() {
        XCTAssertNil(InstagramSecondaryRoute.url(for: "home", username: ""))
    }

    func testUnknownTabReturnsNil() {
        XCTAssertNil(InstagramSecondaryRoute.url(for: "reels", username: ""))
    }
}

// MARK: - ScriptProfile Tests
// Regression: each profile must load the expected scripts (no surprises after profile refactoring).

final class ScriptProfileTests: XCTestCase {

    // .full must include all 27+ module scripts + block_reels bootstrap
    func testFullProfileHasExpectedModuleCount() {
        XCTAssertEqual(InstagramWebView.fullModuleScripts.count, 26,
                       "fullModuleScripts count changed — update if intentional")
    }

    func testFullProfileContainsScrollLock() {
        XCTAssertTrue(InstagramWebView.fullModuleScripts.contains("scroll-lock"),
                      ".full must include scroll-lock")
    }

    func testFullProfileContainsAdDetection() {
        XCTAssertTrue(InstagramWebView.fullModuleScripts.contains("ad-detection"),
                      ".full must include ad-detection")
    }

    func testFullProfileContainsCardInjection() {
        XCTAssertTrue(InstagramWebView.fullModuleScripts.contains("card-injection"),
                      ".full must include card-injection")
    }

    // .reelBlocker must ONLY include the 4 essential scripts
    func testReelBlockerProfileHasFourScripts() {
        XCTAssertEqual(InstagramWebView.reelBlockerScripts.count, 4,
                       "reelBlockerScripts count changed — update if intentional")
    }

    func testReelBlockerContainsScrollLock() {
        XCTAssertTrue(InstagramWebView.reelBlockerScripts.contains("scroll-lock"),
                      ".reelBlocker must include scroll-lock")
    }

    func testReelBlockerContainsPageManager() {
        XCTAssertTrue(InstagramWebView.reelBlockerScripts.contains("page-manager"),
                      ".reelBlocker must include page-manager")
    }

    func testReelBlockerDoesNotContainCardInjection() {
        // Regression: secondary surfaces must NOT inject cards
        XCTAssertFalse(InstagramWebView.reelBlockerScripts.contains("card-injection"),
                       ".reelBlocker must NOT include card-injection")
    }

    func testReelBlockerDoesNotContainAdDetection() {
        XCTAssertFalse(InstagramWebView.reelBlockerScripts.contains("ad-detection"),
                       ".reelBlocker must NOT include ad-detection")
    }

    // .none must be empty
    func testNoneProfileIsEmpty() {
        XCTAssertTrue(InstagramWebView.noScripts.isEmpty,
                      ".none profile must not inject any scripts")
    }

    // .navigationLite must include nav-management
    func testNavigationLiteContainsNavManagement() {
        XCTAssertTrue(InstagramWebView.navigationLiteScripts.contains("nav-management"),
                      ".navigationLite must include nav-management")
    }

    func testNavigationLiteDoesNotContainCardInjection() {
        XCTAssertFalse(InstagramWebView.navigationLiteScripts.contains("card-injection"),
                       ".navigationLite must NOT include card-injection")
    }

    // Profiles must not share scripts that belong exclusively to .full
    func testReelBlockerDoesNotOverlapFullOnlyModules() {
        let fullOnlyModules: Set<String> = [
            "card-injection", "ad-detection", "card-builder", "card-logic",
            "card-culture", "card-book", "card-mood", "card-timer", "card-stop",
            "card-stats", "card-metrics", "card-builder-helpers", "wikipedia",
            "guardian", "session-stats", "tracking",
        ]
        let overlap = fullOnlyModules.intersection(InstagramWebView.reelBlockerScripts)
        XCTAssertTrue(overlap.isEmpty,
                      ".reelBlocker must not include full-only modules: \(overlap)")
    }
}
