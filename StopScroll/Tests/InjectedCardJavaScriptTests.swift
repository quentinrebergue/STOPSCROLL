import XCTest
import JavaScriptCore
@testable import StopScroll

final class InjectedCardJavaScriptTests: XCTestCase {
    func testCachedCardTypeWinsOverNewRequestedType() throws {
        let context = try makeJSContext()
        try evaluateScript(atRelativePath: "StopScroll/Scripts/modules/feed/card-injection.js", in: context)

        let result = context.evaluateScript("""
        window.StopScroll.cardInjection.rememberCardType('post-42', 'mood');
        window.StopScroll.cardInjection.resolveEffectiveCardType('post-42', 'timer');
        """)

        XCTAssertEqual(result?.toString(), "mood")
    }

    func testRuntimeUIRefreshesInjectedCardColorsDuringNavPass() throws {
        let context = try makeJSContext()
        context.evaluateScript("""
        window.__ssCalls = [];
        window.StopScroll = {
          nav: {
            cleanReels: function(){ window.__ssCalls.push('cleanReels'); },
            cleanLegacyReloadButton: function(){ window.__ssCalls.push('cleanLegacyReloadButton'); },
            syncNativeNavState: function(){ window.__ssCalls.push('syncNativeNavState'); }
          },
          topMenu: {
            injectTopMenu: function(){ window.__ssCalls.push('injectTopMenu'); }
          },
          cardBuilder: {
            refreshInjectedCardColors: function(){ window.__ssCalls.push('refreshInjectedCardColors'); }
          }
        };
        """)

        try evaluateScript(atRelativePath: "StopScroll/Scripts/runtime/runtime-ui.js", in: context)
        let result = context.evaluateScript("""
        window.StopScroll.runtimeUI.applyNavInjections();
        window.__ssCalls.join(',');
        """)

        XCTAssertEqual(
            result?.toString(),
            "cleanReels,injectTopMenu,cleanLegacyReloadButton,syncNativeNavState,refreshInjectedCardColors"
        )
    }

      func testNavManagement_reportsProfileOnAccountsPages() throws {
        let context = try makeJSContext()
        context.evaluateScript("""
        window.__nativeTab = '';
        window.StopScroll.constants = window.StopScroll.constants || {};
        window.StopScroll.dom = {
          postToBridge: function(payload){ if (payload && payload.type === 'nativeNavState') { window.__nativeTab = payload.tab; } }
        };
        window.location = { pathname: '/accounts/edit/', origin: 'https://www.instagram.com' };
        window.innerHeight = 844;
        window.getComputedStyle = function(){ return { position: 'fixed' }; };
        window.StopScroll = window.StopScroll || {};
        """)

        try evaluateScript(atRelativePath: "StopScroll/Scripts/modules/navigation/nav-management.js", in: context)
        context.evaluateScript("window.StopScroll.nav.syncNativeNavState();")

        let result = context.evaluateScript("window.__nativeTab")
        XCTAssertEqual(result?.toString(), "profile")
      }

    func testNavManagement_homeReselectScrollsToTopWhenNotAtTop() throws {
        let context = try makeJSContext()
        context.evaluateScript("""
        window.__scrollCalls = 0;
        window.__reloadCalls = 0;
        window.scrollY = 120;
        window.scrollTo = function() { window.__scrollCalls += 1; window.scrollY = 0; };
        window.StopScroll.constants = window.StopScroll.constants || {};
        window.StopScroll.dom = {
          postToBridge: function(payload){ if (payload === 'reloadFeed') { window.__reloadCalls += 1; } }
        };
        window.location = { pathname: '/', origin: 'https://www.instagram.com' };
        window.innerHeight = 844;
        window.getComputedStyle = function(){ return { position: 'fixed' }; };
        window.StopScroll = window.StopScroll || {};
        """)

        try evaluateScript(atRelativePath: "StopScroll/Scripts/modules/navigation/nav-management.js", in: context)
        context.evaluateScript("window.StopScroll.nav.nativeNavigateToTab('home');")

        let scrollCalls = context.evaluateScript("window.__scrollCalls")?.toInt32() ?? 0
        let reloadCalls = context.evaluateScript("window.__reloadCalls")?.toInt32() ?? 0
        XCTAssertEqual(scrollCalls, 1)
        XCTAssertEqual(reloadCalls, 0)
    }

    func testNavManagement_homeReselectReloadsWhenAlreadyAtTop() throws {
        let context = try makeJSContext()
        context.evaluateScript("""
        window.__scrollCalls = 0;
        window.__reloadCalls = 0;
        window.scrollY = 0;
        window.scrollTo = function() { window.__scrollCalls += 1; };
        window.StopScroll.constants = window.StopScroll.constants || {};
        window.StopScroll.dom = {
          postToBridge: function(payload){ if (payload === 'reloadFeed') { window.__reloadCalls += 1; } }
        };
        window.location = { pathname: '/', origin: 'https://www.instagram.com' };
        window.innerHeight = 844;
        window.getComputedStyle = function(){ return { position: 'fixed' }; };
        window.StopScroll = window.StopScroll || {};
        """)

        try evaluateScript(atRelativePath: "StopScroll/Scripts/modules/navigation/nav-management.js", in: context)
        context.evaluateScript("window.StopScroll.nav.nativeNavigateToTab('home');")

        let scrollCalls = context.evaluateScript("window.__scrollCalls")?.toInt32() ?? 0
        let reloadCalls = context.evaluateScript("window.__reloadCalls")?.toInt32() ?? 0
        XCTAssertEqual(scrollCalls, 0)
        XCTAssertEqual(reloadCalls, 1)
    }

    func testPageManager_skipsReelLockOnDirectPath() throws {
        let context = try makeJSContext()
        context.evaluateScript("""
        window.__lockEvents = [];
        window.__debugEvents = [];
        window.StopScroll = {
          dom: {
            isReelsTab: function(){ return false; },
            isDirectPath: function(){ return true; },
            isReelPage: function(){ return false; },
            isSingleContentPage: function(){ return false; },
            postToBridge: function(payload){ if (payload && payload.message) { window.__debugEvents.push(payload.message); } }
          },
          scrollLock: {
            applyScrollLock: function(){ window.__lockEvents.push('apply'); },
            removeScrollLock: function(){ window.__lockEvents.push('remove'); }
          }
        };
        """)

        try evaluateScript(atRelativePath: "StopScroll/Scripts/modules/navigation/page-manager.js", in: context)
        context.evaluateScript("window.StopScroll.pageManager.manageReelPageRestrictions({});")

        let lockEvents = context.evaluateScript("window.__lockEvents.join(',')")?.toString()
        let debugEvents = context.evaluateScript("window.__debugEvents.join(',')")?.toString()
        XCTAssertEqual(lockEvents, "remove")
        XCTAssertEqual(debugEvents, "skip_reel_lock_on_direct_path")
    }

    func testNavManagement_reportsMessagesOnDirectThreadPath() throws {
        let context = try makeJSContext()
        context.evaluateScript("""
        window.__nativeTab = '';
        window.StopScroll.constants = window.StopScroll.constants || {};
        window.StopScroll.dom = {
          postToBridge: function(payload){
            if (payload && payload.type === 'nativeNavState') {
              window.__nativeTab = payload.tab;
            }
          }
        };
        window.location = { pathname: '/direct/t/123456/', origin: 'https://www.instagram.com' };
        window.innerHeight = 844;
        window.getComputedStyle = function(){ return { position: 'fixed' }; };
        window.StopScroll = window.StopScroll || {};
        """)

        try evaluateScript(atRelativePath: "StopScroll/Scripts/modules/navigation/nav-management.js", in: context)
        context.evaluateScript("window.StopScroll.nav.syncNativeNavState();")

        let result = context.evaluateScript("window.__nativeTab")
        XCTAssertEqual(result?.toString(), "messages")
    }

    func testDomUtils_isDirectPathMatchesDirectRoutes() throws {
        let context = try makeJSContext()
        context.evaluateScript("window.location.pathname = '/direct/inbox/';")

        try evaluateScript(atRelativePath: "StopScroll/Scripts/modules/core/dom-utils.js", in: context)
        let directResult = context.evaluateScript("window.StopScroll.dom.isDirectPath()")?.toBool() ?? false

        context.evaluateScript("window.location.pathname = '/explore/';")
        let nonDirectResult = context.evaluateScript("window.StopScroll.dom.isDirectPath()")?.toBool() ?? true

        XCTAssertTrue(directResult)
        XCTAssertFalse(nonDirectResult)
    }

    func testPageManager_appliesReelLockOutsideDirectPath() throws {
        let context = try makeJSContext()
        context.evaluateScript("""
        window.__lockEvents = [];
        window.__debugEvents = [];
        window.StopScroll = {
          dom: {
            isReelsTab: function(){ return false; },
            isDirectPath: function(){ return false; },
            isReelPage: function(){ return true; },
            isSingleContentPage: function(){ return false; },
            postToBridge: function(payload){ if (payload && payload.message) { window.__debugEvents.push(payload.message); } }
          },
          scrollLock: {
            applyScrollLock: function(){ window.__lockEvents.push('apply'); },
            removeScrollLock: function(){ window.__lockEvents.push('remove'); }
          }
        };
        """)

        try evaluateScript(atRelativePath: "StopScroll/Scripts/modules/navigation/page-manager.js", in: context)
        context.evaluateScript("window.StopScroll.pageManager.manageReelPageRestrictions({});")

        let lockEvents = context.evaluateScript("window.__lockEvents.join(',')")?.toString()
        let debugEvents = context.evaluateScript("window.__debugEvents.join(',')")?.toString()
        XCTAssertEqual(lockEvents, "apply")
        XCTAssertEqual(debugEvents, "apply_reel_lock")
    }

      func testMessagingHeaderCleanupScriptTargetsDirectRoutesAndLogs() {
        let script = InstagramWebView.messagingHeaderCleanupScript()

        XCTAssertTrue(script.contains("location.pathname.indexOf('/direct') !== 0"))
        XCTAssertTrue(script.contains("window.__STOPSCROLL_LAST_MSG_CLEANUP_PATH"))
        XCTAssertTrue(script.contains("category: 'MessagingInjection'"))
        XCTAssertTrue(script.contains("messages_header_cleanup path="))
        XCTAssertTrue(script.contains("messages_header_cleanup_error"))
      }

      func testMessagingHeaderCleanupScriptHidesDirectHeaderActions() {
        let script = InstagramWebView.messagingHeaderCleanupScript()

        XCTAssertTrue(script.contains("header a[href=\"/direct/inbox/\"]"))
        XCTAssertTrue(script.contains("header button[aria-label*=\"Back\" i]"))
        XCTAssertTrue(script.contains("location.pathname.indexOf('/direct/t/') === 0"))
        XCTAssertTrue(script.contains("style.setProperty('display', 'none', 'important')"))
        XCTAssertTrue(script.contains("style.setProperty('pointer-events', 'none', 'important')"))
      }

    func testTrackingUsesNativeDecisionWhenBridgeReturnsInject() throws {
        let context = try makeJSContext()
        context.evaluateScript("""
        window.__injectedType = '';
        window.__nativeRenderMode = '';
        window.setTimeout = function(fn){ fn(); return 1; };
        window.StopScroll = {
          cardInjection: {
            repairBrokenInjections: function(){},
            getPostKey: function(){ return 'post-native-1'; },
            hasCachedCard: function(){ return false; },
            injectCardIntoPost: function(_post, type, _config, nativeCard){
              window.__injectedType = type;
              window.__nativeRenderMode = nativeCard && nativeCard.renderMode ? nativeCard.renderMode : '';
              return true;
            }
          },
          pageManager: {
            isMainFeedPage: function(){ return true; },
            feedInjectingEnabled: function(){ return true; }
          },
          adDetection: {
            scanForNewAds: function(_state, cb){ cb({}); }
          },
          cardLogic: {
            chooseCardType: function(){ return 'mood'; },
            recordChoice: function(){}
          },
          dom: {
            postToBridgeWithCallback: function(_payload, cb){
              cb({
                ok: true,
                payload: {
                  contractVersion: 1,
                  decision: 'inject',
                  card: {
                    type: 'book',
                    renderMode: 'legacy-builder-v1',
                    content: { title: 'Read now' },
                    actions: { primary: 'openArticle' }
                  }
                }
              });
              return 'req-1';
            }
          }
        };
        """)

        try evaluateScript(atRelativePath: "StopScroll/Scripts/modules/analytics/tracking.js", in: context)
        context.evaluateScript("""
        var state = {
          paused: false,
          config: {
            feed_injection: {
              ad_replacement: true
            },
            cards: {
              every_n_opportunities: 1,
              metrics: { enabled: true, weight: 1 },
              mood: { enabled: true, weight: 1 },
              timer: { enabled: true, weight: 1 },
              stop: { enabled: true, weight: 1 },
              stats: { enabled: true, weight: 1 },
              book: { enabled: true, weight: 1 },
              culture: { enabled: true, weight: 1 }
            }
          },
          opportunities: 0,
          shownCards: 0,
          byTypeCount: { metrics: 0, mood: 0, timer: 0, stop: 0, stats: 0, book: 0, culture: 0 }
        };
        window.StopScroll.tracking.scanNewPosts(state);
        """)

        XCTAssertEqual(context.evaluateScript("window.__injectedType")?.toString(), "book")
    XCTAssertEqual(context.evaluateScript("window.__nativeRenderMode")?.toString(), "legacy-builder-v1")
    }

    func testTrackingFallsBackToLegacyPolicyWhenBridgeUnavailable() throws {
        let context = try makeJSContext()
        context.evaluateScript("""
        window.__injectedType = '';
        window.setTimeout = function(fn){ fn(); return 1; };
        window.StopScroll = {
          cardInjection: {
            repairBrokenInjections: function(){},
            getPostKey: function(){ return 'post-fallback-1'; },
            hasCachedCard: function(){ return false; },
            injectCardIntoPost: function(_post, type){ window.__injectedType = type; return true; }
          },
          pageManager: {
            isMainFeedPage: function(){ return true; },
            feedInjectingEnabled: function(){ return true; }
          },
          adDetection: {
            scanForNewAds: function(_state, cb){ cb({}); }
          },
          cardLogic: {
            chooseCardType: function(){ return 'timer'; },
            recordChoice: function(){}
          },
          dom: {}
        };
        """)

        try evaluateScript(atRelativePath: "StopScroll/Scripts/modules/analytics/tracking.js", in: context)
        context.evaluateScript("""
        var state = {
          paused: false,
          config: {
            feed_injection: {
              ad_replacement: true
            },
            cards: {
              every_n_opportunities: 1,
              metrics: { enabled: true, weight: 1 },
              mood: { enabled: true, weight: 1 },
              timer: { enabled: true, weight: 1 },
              stop: { enabled: true, weight: 1 },
              stats: { enabled: true, weight: 1 },
              book: { enabled: true, weight: 1 },
              culture: { enabled: true, weight: 1 }
            }
          },
          opportunities: 0,
          shownCards: 0,
          byTypeCount: { metrics: 0, mood: 0, timer: 0, stop: 0, stats: 0, book: 0, culture: 0 }
        };
        window.StopScroll.tracking.scanNewPosts(state);
        """)

        XCTAssertEqual(context.evaluateScript("window.__injectedType")?.toString(), "timer")
    }

    private func makeJSContext() throws -> JSContext {
        guard let context = JSContext() else {
            throw NSError(domain: "InjectedCardJavaScriptTests", code: 1)
        }

        context.exceptionHandler = { _, exception in
          let message = exception?.toString() ?? "unknown"
          XCTFail("JS exception: \(message)")
        }

        context.evaluateScript("""
        var window = this;
        var global = this;
        if (!window.addEventListener) { window.addEventListener = function(){}; }
        if (!window.dispatchEvent) { window.dispatchEvent = function(){}; }
        if (!window.setInterval) { window.setInterval = function(){ return 1; }; }
        if (!window.clearInterval) { window.clearInterval = function(){}; }
        if (!window.history) { window.history = { pushState: function(){}, replaceState: function(){} }; }
        if (!window.location) { window.location = { pathname: '/', origin: 'https://www.instagram.com', href: 'https://www.instagram.com/' }; }
        if (!window.innerHeight) { window.innerHeight = 844; }
        if (!window.getComputedStyle) { window.getComputedStyle = function(){ return { position: 'static' }; }; }
        if (typeof PointerEvent === 'undefined') { var PointerEvent = function(){}; }
        if (typeof MouseEvent === 'undefined') { var MouseEvent = function(){}; }
        if (typeof Event === 'undefined') { var Event = function(){}; }
        if (typeof PopStateEvent === 'undefined') { var PopStateEvent = function(){}; }
        var document = {
          querySelectorAll: function(){ return []; },
          querySelector: function(){ return null; },
          createElement: function(){ return { style: {}, setAttribute: function(){}, appendChild: function(){}, querySelector: function(){ return null; }, querySelectorAll: function(){ return []; }, children: [] }; },
          head: { appendChild: function(){} },
          documentElement: { appendChild: function(){}, backgroundColor: '' },
          addEventListener: function(){},
          hidden: false,
          body: {}
        };
        var MutationObserver = function(){ return { observe: function(){} }; };
        window.StopScroll = window.StopScroll || {};
        """)

        return context
    }

    private func evaluateScript(atRelativePath relativePath: String, in context: JSContext) throws {
        let fileURL = repositoryRoot().appendingPathComponent(relativePath)
        let source = try String(contentsOf: fileURL, encoding: .utf8)
        context.evaluateScript(source)
    }

    private func repositoryRoot() -> URL {
        let fileURL = URL(fileURLWithPath: #filePath)
        return fileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}