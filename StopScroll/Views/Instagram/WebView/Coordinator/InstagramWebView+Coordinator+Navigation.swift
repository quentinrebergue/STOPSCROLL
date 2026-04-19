import SwiftUI
import WebKit

extension InstagramWebView.Coordinator {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        LogManager.shared.log("✅ WebView didFinish: \(webView.url?.absoluteString ?? "unknown")", category: "WebView", level: .info)

        var injectionStep = 0

        if parent.scriptProfile == .full {
            if let yamlInjection = parent.buildYAMLInjectionScript() {
                injectionStep += 1
                let stepNum = injectionStep
                webView.evaluateJavaScript(yamlInjection) { _, error in
                    if let error = error {
                        LogManager.shared.log("❌ Step \(stepNum) - YAML: \(error.localizedDescription)", category: "ScriptInjection", level: .error)
                    } else {
                        LogManager.shared.log("✅ Step \(stepNum) - YAML: success", category: "ScriptInjection", level: .debug)
                    }
                }
            }

            injectionStep += 1
            let bookStateStepNum = injectionStep
            webView.evaluateJavaScript(parent.buildBookStateScript()) { _, error in
                if let error = error {
                    LogManager.shared.log("❌ Step \(bookStateStepNum) - BookState: \(error.localizedDescription)", category: "ScriptInjection", level: .error)
                } else {
                    LogManager.shared.log("✅ Step \(bookStateStepNum) - BookState: success", category: "ScriptInjection", level: .debug)
                }
            }

            injectionStep += 1
            let labelsStepNum = injectionStep
            webView.evaluateJavaScript(parent.buildLabelsInjectionScript()) { _, error in
                if let error = error {
                    LogManager.shared.log("❌ Step \(labelsStepNum) - Labels: \(error.localizedDescription)", category: "ScriptInjection", level: .error)
                } else {
                    LogManager.shared.log("✅ Step \(labelsStepNum) - Labels: success", category: "ScriptInjection", level: .debug)
                }
            }
        }

        let scripts = InstagramWebView.loadScripts(profile: parent.scriptProfile)
        let scriptCount = scripts.count
        LogManager.shared.log("📜 Starting injection of \(scriptCount) scripts (profile: \(parent.scriptProfile))", category: "ScriptInjection", level: .info)

        for (index, script) in scripts.enumerated() {
            injectionStep += 1
            let stepNum = injectionStep
            let scriptSize = script.count

            let wrappedScript = """
            (function() {
              try {
                \(script)
              } catch (e) {
                console.error('[StopScroll Script #\(index + 1) Error]', e.message, e.stack);
                throw e;
              }
            })();
            """

            webView.evaluateJavaScript(wrappedScript) { _, error in
                if let error = error {
                    LogManager.shared.log("❌ Step \(stepNum) - Script #\(index + 1) (\(scriptSize) bytes): \(error.localizedDescription)", category: "ScriptInjection", level: .error)
                } else {
                    LogManager.shared.log("✅ Step \(stepNum) - Script #\(index + 1) (\(scriptSize) bytes): success", category: "ScriptInjection", level: .debug)
                }
            }
        }

        applyRuntimeActiveState(parent.isActive)
        DispatchQueue.main.async {
            guard self.parent.tracksLoading else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                self.parent.isLoading = false
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        LogManager.shared.log("❌ WebView didFail: \(error.localizedDescription)", category: "WebView", level: .error)

        DispatchQueue.main.async {
            guard self.parent.tracksLoading else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                self.parent.isLoading = false
            }
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        LogManager.shared.log("❌ WebView didFailProvisionalNavigation: \(error.localizedDescription)", category: "WebView", level: .error)

        DispatchQueue.main.async {
            guard self.parent.tracksLoading else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                self.parent.isLoading = false
            }
        }
    }

    func applyRuntimeActiveState(_ active: Bool) {
        let js = "(function(){var ns=window.StopScroll;var st=ns&&ns._state; if(ns&&ns.runtimeState&&ns.runtimeState.setPaused&&st){ns.runtimeState.setPaused(st,\(!active));}})();"
        DispatchQueue.main.async {
            self.webView?.evaluateJavaScript(js)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let path = navigationAction.request.url?.path {
            let trimmed = path.hasSuffix("/") ? String(path.dropLast()) : path
            if trimmed == "/reels" {
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }
}
