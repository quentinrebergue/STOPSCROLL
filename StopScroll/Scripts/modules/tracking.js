// Tracking, scanning & SPA history exposed via window.StopScroll.tracking.
(function (global) {
  'use strict';

  var ns = (global.StopScroll = global.StopScroll || {});

  function scanNewPosts(state) {
    var cfg = state.config.feed_injection;

    // ── Timer-expired mode: replace ALL posts, even non-ads ──
    var expired = window.__STOPSCROLL_TIMER_EXPIRED;
    if (expired) {
      var allPosts = document.querySelectorAll('article:not([data-ss-replaced])');
      for (var k = 0; k < allPosts.length; k++) {
        var p = allPosts[k];
        if (state.seenPosts.has(p)) continue;
        state.seenPosts.add(p);
        ns.cardInjection.injectTimerExpiredCard(p);
      }
      return;
    }

    if (!ns.pageManager.isMainFeedPage() || !ns.pageManager.feedInjectingEnabled(state.config) || cfg.ad_replacement === false) {
      return;
    }
    ns.adDetection.scanForNewAds(state, function (post) {
      state.opportunities += 1;
      var tried = {};
      for (var attempts = 0; attempts < 5; attempts++) {
        var chosen = ns.cardLogic.chooseCardType(state, state.config, tried);
        if (!chosen) return; // no eligible type left
        if (ns.cardInjection.injectCardIntoPost(post, chosen, state.config)) {
          ns.cardLogic.recordChoice(chosen);
          state.shownCards += 1;
          state.byTypeCount[chosen] += 1;
          return;
        }
        tried[chosen] = true; // builder failed, exclude and retry
      }
    });
  }

  function patchHistoryForSPA(scheduleScanFn, checkNavInjectionsFn) {
    var originalPushState = history.pushState;
    var originalReplaceState = history.replaceState;

    history.pushState = function () {
      var result = originalPushState.apply(this, arguments);
      setTimeout(scheduleScanFn, 80);
      setTimeout(checkNavInjectionsFn, 350);
      return result;
    };

    history.replaceState = function () {
      var result = originalReplaceState.apply(this, arguments);
      setTimeout(scheduleScanFn, 80);
      setTimeout(checkNavInjectionsFn, 350);
      return result;
    };

    global.addEventListener('popstate', function () {
      setTimeout(scheduleScanFn, 80);
      setTimeout(checkNavInjectionsFn, 350);
    });
  }

  function setupLightweightTracking(state, scheduleScanFn) {
    global.addEventListener('scroll', function () {
      if (ns.sessionStats) ns.sessionStats.onScrollActivity();
      scheduleScanFn();
    }, { passive: true });
    global.addEventListener('resize', scheduleScanFn);
    if (state.periodicScanTimer) clearInterval(state.periodicScanTimer);
    state.periodicScanTimer = setInterval(scheduleScanFn, 1400);
    document.addEventListener('visibilitychange', function () {
      if (!document.hidden) scheduleScanFn();
    });
  }

  ns.tracking = {
    scanNewPosts: scanNewPosts,
    patchHistoryForSPA: patchHistoryForSPA,
    setupLightweightTracking: setupLightweightTracking
  };
})(window);
