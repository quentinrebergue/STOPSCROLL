import XCTest
import JavaScriptCore

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
          documentElement: { appendChild: function(){}, backgroundColor: '' }
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