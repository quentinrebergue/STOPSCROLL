import SwiftUI
import WebKit

extension InstagramWebView.Coordinator {
    private struct RuntimeGovernorPolicy {
        let mode: String
        let scanDelayMultiplier: Double
        let navLiteDelayMultiplier: Double
        let frequencyMultiplier: Double

        var signature: String {
            let scan = String(format: "%.2f", scanDelayMultiplier)
            let nav = String(format: "%.2f", navLiteDelayMultiplier)
            let freq = String(format: "%.2f", frequencyMultiplier)
            return "\(mode)|\(scan)|\(nav)|\(freq)"
        }
    }

    private func currentRuntimeGovernorPolicy() -> RuntimeGovernorPolicy {
        let processInfo = ProcessInfo.processInfo
        let thermal = processInfo.thermalState
        let lowPower = processInfo.isLowPowerModeEnabled
        let isActiveSurface = parent.isActive

        // Preserve UI responsiveness on the currently visible surface.
        if isActiveSurface, thermal == .nominal {
            return RuntimeGovernorPolicy(
                mode: lowPower ? "low_power_active" : "nominal_active",
                scanDelayMultiplier: 1.00,
                navLiteDelayMultiplier: 1.00,
                frequencyMultiplier: 1.00
            )
        }

        switch thermal {
        case .nominal:
            if lowPower {
                return RuntimeGovernorPolicy(
                    mode: "low_power",
                    scanDelayMultiplier: 1.35,
                    navLiteDelayMultiplier: 1.30,
                    frequencyMultiplier: 1.20
                )
            }
            // Keep a light preventive profile only for non-active surfaces.
            return RuntimeGovernorPolicy(
                mode: "nominal",
                scanDelayMultiplier: 1.15,
                navLiteDelayMultiplier: 1.10,
                frequencyMultiplier: 1.10
            )
        case .fair:
            return RuntimeGovernorPolicy(
                mode: "fair",
                scanDelayMultiplier: 2.15,
                navLiteDelayMultiplier: 1.95,
                frequencyMultiplier: 1.90
            )
        case .serious, .critical:
            return RuntimeGovernorPolicy(
                mode: "serious",
                scanDelayMultiplier: 3.20,
                navLiteDelayMultiplier: 2.70,
                frequencyMultiplier: 3.00
            )
        @unknown default:
            return RuntimeGovernorPolicy(
                mode: "nominal",
                scanDelayMultiplier: 1.25,
                navLiteDelayMultiplier: 1.20,
                frequencyMultiplier: 1.15
            )
        }
    }

    private func effectiveInjectionFrequency(for policy: RuntimeGovernorPolicy) -> Int {
        let base = max(0, AppSettings.shared.injectionFrequency)
        if base == 0 { return 0 }
        return max(1, Int((Double(base) * policy.frequencyMultiplier).rounded()))
    }

    func applyRuntimeGovernorIfNeeded(force: Bool = false) {
        guard let webView else { return }

        let policy = currentRuntimeGovernorPolicy()
        let effectiveFrequency = effectiveInjectionFrequency(for: policy)
        let signature = "\(policy.signature)|freq=\(effectiveFrequency)"

        if !force, signature == lastGovernorSignature { return }
        lastGovernorSignature = signature

        let js = """
        (function(){
            var ns = window.StopScroll;
            var payload = {
                mode: '\(policy.mode)',
                scanDelayMultiplier: \(policy.scanDelayMultiplier),
                navLiteDelayMultiplier: \(policy.navLiteDelayMultiplier)
            };
            var bridged = false;
            if (ns && ns.bridge && typeof ns.bridge.receive === 'function') {
                try { bridged = !!ns.bridge.receive('setGovernor', payload); } catch (_) { bridged = false; }
                try { ns.bridge.receive('setFrequency', \(effectiveFrequency)); } catch (_) {}
            }
            if (!bridged) {
                window.__STOPSCROLL_GOVERNOR_MODE = payload.mode;
                window.__STOPSCROLL_SCAN_DELAY_MULTIPLIER = payload.scanDelayMultiplier;
                window.__STOPSCROLL_NAV_LITE_DELAY_MULTIPLIER = payload.navLiteDelayMultiplier;
                window.__STOPSCROLL_FREQUENCY = \(effectiveFrequency);
                if (ns && ns.runtimeState && ns.runtimeState.applyConfigFromGlobals && ns._state) {
                    ns.runtimeState.applyConfigFromGlobals(ns._state);
                }
            }
        })();
        """

        webView.evaluateJavaScript(js)
    }

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

        applyRuntimeGovernorIfNeeded(force: true)
        applyRuntimeActiveState(parent.isActive)
        syncNativeTimerStateToWebView(markExpiredIfNeeded: true)
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
        let js = "(function(){var ns=window.StopScroll;var paused=\(!active);var bridged=false;if(ns&&ns.bridge&&typeof ns.bridge.receive==='function'){try{bridged=!!ns.bridge.receive('setPaused',paused);}catch(_){bridged=false;}}if(!bridged){var st=ns&&ns._state;if(ns&&ns.runtimeState&&ns.runtimeState.setPaused&&st){ns.runtimeState.setPaused(st,paused);}}})();"
        DispatchQueue.main.async {
            guard let webView = self.webView else { return }

            // Enforce media stop/resume even on surfaces that don't inject StopScroll runtime.
            if #available(iOS 15.0, *) {
                webView.setAllMediaPlaybackSuspended(!active)
            } else if !active {
                webView.evaluateJavaScript("(function(){var media=document.querySelectorAll('video,audio');for(var i=0;i<media.length;i++){try{media[i].pause();}catch(_){}}})();")
            }

            webView.evaluateJavaScript(js)
            self.applyRuntimeGovernorIfNeeded(force: true)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Block accidental entry into the Reels feed from non-reels surfaces (e.g. feed scroll-past).
        // The dedicated reels surface (activeSectionTab == "reels") must be allowed through.
        if parent.activeSectionTab != "reels",
           let path = navigationAction.request.url?.path {
            let trimmed = path.hasSuffix("/") ? String(path.dropLast()) : path
            if trimmed == "/reels" {
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }
}
