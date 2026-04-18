// Generated file — bootstrap only. Modules are injected by Swift before this script.
// Entry point for StopScroll runtime.
// Modules are loaded by Swift (InstagramWebView.swift) in dependency order before this script.
// The build script (build_block_reels.mjs) strips these imports and writes block_reels.js.

(function () {
    'use strict';

    if (window.__STOPSCROLL_DYNAMIC_RUNNING) {
        return;
    }
    window.__STOPSCROLL_DYNAMIC_RUNNING = true;

    var ns = window.StopScroll;
    var state = ns.runtimeState.createRuntimeState();
    ns._state = state; // Expose to native Swift for live config reloads
    var scheduleScan = ns.runtimeScan.createScheduleScan(
        state,
        ns.runtimeUI.applyNavInjections,
        ns.runtimeUI.applyPagePolicies
    );

    function bootstrap() {
        ns.runtimeState.initializeRuntimeState(state);
        ns.runtimeScan.setupRuntimeTracking(state, scheduleScan, ns.runtimeUI.applyNavInjections);
        scheduleScan();
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', bootstrap, { once: true });
    } else {
        bootstrap();
    }
})();
