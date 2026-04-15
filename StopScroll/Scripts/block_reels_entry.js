// Entry point for StopScroll runtime.
// Modules are loaded by Swift (InstagramWebView.swift) in dependency order before this script.
// The build script (build_block_reels.mjs) strips these imports and writes block_reels.js.

import './modules/constants.js';
import './modules/config.js';
import './modules/dom-utils.js';
import './modules/session-stats.js';
import './modules/scroll-lock.js';
import './modules/page-manager.js';
import './modules/nav-management.js';
import './modules/top-menu.js';
import './modules/ad-detection.js';
import './modules/card-logic.js';
import './modules/card-builder/card-builder-helpers.js';
import './modules/card-builder/card-metrics.js';
import './modules/card-builder/card-mood.js';
import './modules/card-builder/card-timer.js';
import './modules/card-builder/card-stop.js';
import './modules/card-builder/card-stats.js';
import './modules/card-builder/card-builder.js';
import './modules/card-injection.js';
import './modules/tracking.js';
import './runtime/runtime-state.js';
import './runtime/runtime-ui.js';
import './runtime/runtime-scan.js';

(function () {
    'use strict';

    if (window.__STOPSCROLL_DYNAMIC_RUNNING) {
        return;
    }
    window.__STOPSCROLL_DYNAMIC_RUNNING = true;

    var ns = window.StopScroll;
    var state = ns.runtimeState.createRuntimeState();
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
