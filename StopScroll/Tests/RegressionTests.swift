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
// Each Instagram tab always maps to its own dedicated WebSurface (1:1 routing).

final class SurfaceRouterTests: XCTestCase {

    func testHomeIsMain() {
        XCTAssertEqual(SurfaceRouter.surface(for: "home"), .main)
    }

    func testSearchIsSearch() {
        XCTAssertEqual(SurfaceRouter.surface(for: "search"), .search)
    }

    func testReelsIsReels() {
        XCTAssertEqual(SurfaceRouter.surface(for: "reels"), .reels)
    }

    func testMessagesIsMessages() {
        XCTAssertEqual(SurfaceRouter.surface(for: "messages"), .messages)
    }

    func testProfileIsProfile() {
        XCTAssertEqual(SurfaceRouter.surface(for: "profile"), .profile)
    }

    // Unknown tab falls back to main
    func testUnknownTabFallsBackToMain() {
        XCTAssertEqual(SurfaceRouter.surface(for: "unknown_surface"), .main)
        XCTAssertEqual(SurfaceRouter.surface(for: ""), .main)
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

    func testReelsURL() {
        XCTAssertEqual(
            InstagramSecondaryRoute.url(for: "reels", username: ""),
            "https://www.instagram.com/reels/"
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
        XCTAssertNil(InstagramSecondaryRoute.url(for: "not-a-tab", username: ""))
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

    // .searchLite must ONLY include the 4 essential scripts
    func testSearchLiteProfileHasFourScripts() {
        XCTAssertEqual(InstagramWebView.searchLiteScripts.count, 4,
                       "searchLiteScripts count changed — update if intentional")
    }

    func testSearchLiteContainsScrollLock() {
        XCTAssertTrue(InstagramWebView.searchLiteScripts.contains("scroll-lock"),
                      ".searchLite must include scroll-lock")
    }

    func testSearchLiteContainsPageManager() {
        XCTAssertTrue(InstagramWebView.searchLiteScripts.contains("page-manager"),
                      ".searchLite must include page-manager")
    }

    func testSearchLiteDoesNotContainCardInjection() {
        // Regression: secondary surfaces must NOT inject cards
        XCTAssertFalse(InstagramWebView.searchLiteScripts.contains("card-injection"),
                       ".searchLite must NOT include card-injection")
    }

    func testSearchLiteDoesNotContainAdDetection() {
        XCTAssertFalse(InstagramWebView.searchLiteScripts.contains("ad-detection"),
                       ".searchLite must NOT include ad-detection")
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
    func testSearchLiteDoesNotOverlapFullOnlyModules() {
        let fullOnlyModules: Set<String> = [
            "card-injection", "ad-detection", "card-builder", "card-logic",
            "card-culture", "card-book", "card-mood", "card-timer", "card-stop",
            "card-stats", "card-metrics", "card-builder-helpers", "wikipedia",
            "guardian", "session-stats", "tracking",
        ]
        let overlap = fullOnlyModules.intersection(InstagramWebView.searchLiteScripts)
        XCTAssertTrue(overlap.isEmpty,
                      ".searchLite must not include full-only modules: \(overlap)")
    }
}

// MARK: - Native Card Decision Contract Tests

final class NativeCardDecisionContractTests: XCTestCase {

    override func setUp() {
        super.setUp()
        InstagramWebView.Coordinator.resetNativeCardDecisionHistoryForTests()
    }

    func testNativeDecisionSkipsWhenFrequencyGateNotReached() {
        let payload: [String: Any] = [
            "opportunityIndex": 1,
            "frequency": 3,
            "availableCards": [
                ["type": "metrics", "weight": 1.0]
            ]
        ]

        let result = InstagramWebView.Coordinator.makeCardDecisionPayload(from: payload, defaultFrequency: 1)

        XCTAssertEqual(result["contractVersion"] as? Int, 1)
        XCTAssertEqual(result["decision"] as? String, "skip")
        XCTAssertEqual(result["reason"] as? String, "frequency_gate")
    }

    func testNativeDecisionInjectsSingleEligibleCardWithVersionedContract() {
        let payload: [String: Any] = [
            "opportunityIndex": 2,
            "frequency": 2,
            "availableCards": [
                ["type": "culture", "weight": 3.0]
            ]
        ]

        let result = InstagramWebView.Coordinator.makeCardDecisionPayload(from: payload, defaultFrequency: 1)
        let card = result["card"] as? [String: Any]

        XCTAssertEqual(result["contractVersion"] as? Int, 1)
        XCTAssertEqual(result["decision"] as? String, "inject")
        XCTAssertEqual(card?["schemaVersion"] as? Int, 1)
        XCTAssertEqual(card?["renderMode"] as? String, "legacy-builder-v1")
        XCTAssertEqual(card?["type"] as? String, "culture")
    }
}
