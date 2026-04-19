import XCTest
import JavaScriptCore

final class InjectedCardHoleRegressionTests: XCTestCase {
    func testCachedCardConnectedElsewhereIsNotReused() throws {
        let context = try makeJSContext()
        try evaluateScript(atRelativePath: "StopScroll/Scripts/modules/feed/card-injection.js", in: context)

        let result = context.evaluateScript("""
        var owner = { kind: 'articleA' };
        var articleB = { kind: 'articleB' };
        var cached = {
          isConnected: true,
          closest: function(sel){ return owner; }
        };
        window.StopScroll.cardInjection.shouldReuseCachedCard(cached, articleB);
        """)

        XCTAssertEqual(result?.toBool(), false)
    }

    func testInjectionRepairDetectsEmptyWrapper() throws {
        let context = try makeJSContext()
        try evaluateScript(atRelativePath: "StopScroll/Scripts/modules/feed/card-injection.js", in: context)

        let result = context.evaluateScript("""
        var emptyWrapper = { firstElementChild: null };
        window.StopScroll.cardInjection.needsInjectionRepair(emptyWrapper);
        """)

        XCTAssertEqual(result?.toBool(), true)
    }

    private func makeJSContext() throws -> JSContext {
        guard let context = JSContext() else {
            throw NSError(domain: "InjectedCardHoleRegressionTests", code: 1)
        }

        context.exceptionHandler = { _, exception in
            let message = exception?.toString() ?? "unknown"
            XCTFail("JS exception: \(message)")
        }

        context.evaluateScript("""
        var window = this;
        var global = this;
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
