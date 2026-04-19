// Runtime scan loop exposed via window.StopScroll.runtimeScan.
(function (global) {
  'use strict';

  var ns = (global.StopScroll = global.StopScroll || {});

  function createScheduleScan(state, applyNavInjections, applyPagePolicies) {
    function scheduleScan() {
      if (state.paused || global.__STOPSCROLL_RUNTIME_PAUSED) return;
      if (state.scanScheduled) return;
      state.scanScheduled = true;
      requestAnimationFrame(function () {
        state.scanScheduled = false;
        applyNavInjections();
        applyPagePolicies(state);
        ns.tracking.scanNewPosts(state);
      });
    }
    return scheduleScan;
  }

  function setupRuntimeTracking(state, scheduleScan, applyNavInjections) {
    ns.tracking.patchHistoryForSPA(scheduleScan, applyNavInjections);
    ns.tracking.setupLightweightTracking(state, scheduleScan);
  }

  ns.runtimeScan = {
    createScheduleScan: createScheduleScan,
    setupRuntimeTracking: setupRuntimeTracking
  };
})(window);
