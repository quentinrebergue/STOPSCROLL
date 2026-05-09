// Tracking, scanning & SPA history exposed via window.StopScroll.tracking.
(function (global) {
  'use strict';

  var ns = (global.StopScroll = global.StopScroll || {});

  function markScanActivity(state, didWork) {
    if (didWork) {
      state.idleScanStreak = 0;
      return;
    }
    state.idleScanStreak = (state.idleScanStreak || 0) + 1;
  }

  function nextPeriodicScanDelay(state) {
    var streak = state.idleScanStreak || 0;
    var base = 1400;
    if (streak >= 16) base = 3600;
    else if (streak >= 8) base = 2400;

    var governor = Number(global.__STOPSCROLL_SCAN_DELAY_MULTIPLIER || 1);
    if (!isFinite(governor) || governor <= 0) governor = 1;
    return Math.max(600, Math.round(base * governor));
  }

  function queueNextPeriodicScan(state, scheduleScanFn) {
    if (state.periodicScanTimer) clearTimeout(state.periodicScanTimer);

    var delay = nextPeriodicScanDelay(state);
    state.periodicScanTimer = setTimeout(function () {
      state.periodicScanTimer = null;
      if (!state.paused && !global.__STOPSCROLL_RUNTIME_PAUSED) {
        scheduleScanFn();
      }
      queueNextPeriodicScan(state, scheduleScanFn);
    }, delay);
  }

  function makeAvailableCards(runtimeConfig) {
    var cardsCfg = (runtimeConfig && runtimeConfig.cards) || {};
    var types = ['metrics', 'mood', 'timer', 'stop', 'stats', 'book', 'culture'];
    var out = [];
    for (var i = 0; i < types.length; i++) {
      var type = types[i];
      var entry = cardsCfg[type];
      if (!entry || entry.enabled === false) continue;
      out.push({ type: type, weight: Number(entry.weight) || 1 });
    }
    return out;
  }

  function recordShownCard(state, type, recordLegacyHistory) {
    if (!type) return;
    if (recordLegacyHistory && ns.cardLogic && ns.cardLogic.recordChoice) {
      ns.cardLogic.recordChoice(type);
    }
    state.shownCards += 1;
    if (typeof state.byTypeCount[type] !== 'number') {
      state.byTypeCount[type] = 0;
    }
    state.byTypeCount[type] += 1;
  }

  function tryInjectWithLegacyPolicy(post, state, opportunitySnapshot) {
    var freq = Number(state.config.cards.every_n_opportunities);
    if (freq > 0 && opportunitySnapshot % freq !== 0) return false;
    var tried = {};
    for (var attempts = 0; attempts < 5; attempts++) {
      var chosen = ns.cardLogic.chooseCardType(state, state.config, tried);
      if (!chosen) return false;
      if (ns.cardInjection.injectCardIntoPost(post, chosen, state.config)) {
        recordShownCard(state, chosen, true);
        return true;
      }
      tried[chosen] = true;
    }
    return false;
  }

  function tryInjectWithNativeDecision(post, nativeCard, state) {
    var chosenType = '';
    if (typeof nativeCard === 'string') {
      chosenType = nativeCard;
      nativeCard = null;
    } else if (nativeCard && typeof nativeCard === 'object') {
      chosenType = nativeCard.type || '';
    }

    if (!chosenType) return false;
    if (!ns.cardInjection.injectCardIntoPost(post, chosenType, state.config, nativeCard || null)) {
      return false;
    }
    recordShownCard(state, chosenType, false);
    return true;
  }

  function requestNativeCardDecision(post, state, runtimeConfig, done) {
    var postKey = ns.cardInjection && ns.cardInjection.getPostKey
      ? ns.cardInjection.getPostKey(post)
      : '';

    if (!state.pendingNativeCardRequests) {
      state.pendingNativeCardRequests = {};
    }
    if (postKey && state.pendingNativeCardRequests[postKey]) {
      return;
    }
    if (postKey) {
      state.pendingNativeCardRequests[postKey] = true;
    }

    var finished = false;
    function finish(decision) {
      if (finished) return;
      finished = true;
      if (postKey) {
        delete state.pendingNativeCardRequests[postKey];
      }
      done(decision || { mode: 'fallback' });
    }

    if (!(ns.dom && ns.dom.postToBridgeWithCallback)) {
      finish({ mode: 'fallback' });
      return;
    }

    var message = {
      type: 'cardRequest',
      opportunityIndex: state.opportunities,
      frequency: Number(runtimeConfig && runtimeConfig.cards && runtimeConfig.cards.every_n_opportunities) || 0,
      availableCards: makeAvailableCards(runtimeConfig),
      context: {
        path: (global.location && global.location.pathname) || '/',
        postKey: postKey || ''
      }
    };

    var requestId = ns.dom.postToBridgeWithCallback(message, function (result) {
      if (!result || result.ok !== true || !result.payload || result.payload.contractVersion !== 1) {
        finish({ mode: 'fallback' });
        return;
      }

      var decision = result.payload.decision;
      if (decision === 'skip') {
        finish({ mode: 'skip' });
        return;
      }

      if (decision === 'inject') {
        var nativeCard = result.payload.card;
        var cardType = nativeCard && nativeCard.type;
        if (cardType) {
          finish({ mode: 'inject', type: cardType, card: nativeCard });
          return;
        }
      }

      finish({ mode: 'fallback' });
    });

    if (!requestId) {
      finish({ mode: 'fallback' });
      return;
    }

    // Keep feed responsive if native response is delayed.
    global.setTimeout(function () {
      finish({ mode: 'fallback' });
    }, 220);
  }

  function scanNewPosts(state) {
    if (state.paused || global.__STOPSCROLL_RUNTIME_PAUSED) {
      return;
    }
    var didWorkThisPass = false;
    var cfg = state.config.feed_injection;

    if (ns.cardInjection && ns.cardInjection.repairBrokenInjections) {
      ns.cardInjection.repairBrokenInjections(state.config);
    }

    // ── Timer-expired mode: replace ALL posts, even non-ads ──
    var expired = window.__STOPSCROLL_TIMER_EXPIRED;
    if (expired) {
      var allPosts = document.querySelectorAll('article:not([data-ss-replaced])');
      for (var k = 0; k < allPosts.length; k++) {
        var p = allPosts[k];
        if (state.seenPosts.has(p)) continue;
        state.seenPosts.add(p);
        ns.cardInjection.injectTimerExpiredCard(p);
        didWorkThisPass = true;
      }
      markScanActivity(state, didWorkThisPass);
      return;
    }

    if (!ns.pageManager.isMainFeedPage() || !ns.pageManager.feedInjectingEnabled(state.config) || cfg.ad_replacement === false) {
      markScanActivity(state, false);
      return;
    }
    ns.adDetection.scanForNewAds(state, function (post) {
      didWorkThisPass = true;
      var postKey = ns.cardInjection && ns.cardInjection.getPostKey ? ns.cardInjection.getPostKey(post) : '';
      if (postKey && ns.cardInjection && ns.cardInjection.hasCachedCard && ns.cardInjection.hasCachedCard(postKey)) {
        ns.cardInjection.injectCardIntoPost(
          post,
          ns.cardInjection.getCachedCardType(postKey),
          state.config
        );
        return;
      }

      state.opportunities += 1;
      var snapshotOpportunity = state.opportunities;
      requestNativeCardDecision(post, state, state.config, function (decision) {
        if (!decision || decision.mode === 'fallback') {
          tryInjectWithLegacyPolicy(post, state, snapshotOpportunity);
          return;
        }
        if (decision.mode === 'skip') {
          return;
        }
        if (decision.mode === 'inject') {
          if (!tryInjectWithNativeDecision(post, decision.card || decision.type, state)) {
            tryInjectWithLegacyPolicy(post, state, snapshotOpportunity);
          }
        }
      });
    });

    markScanActivity(state, didWorkThisPass);
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
    if (state.trackingSetupDone) {
      startPeriodicScan(state, scheduleScanFn);
      return;
    }
    state.trackingSetupDone = true;

    global.addEventListener('scroll', function () {
      if (ns.sessionStats) ns.sessionStats.onScrollActivity();
      scheduleScanFn();
    }, { passive: true });
    global.addEventListener('resize', scheduleScanFn);
    startPeriodicScan(state, scheduleScanFn);
    document.addEventListener('visibilitychange', function () {
      if (!document.hidden) scheduleScanFn();
    });
  }

  function startPeriodicScan(state, scheduleScanFn) {
    stopPeriodicScan(state);
    queueNextPeriodicScan(state, scheduleScanFn);
  }

  function stopPeriodicScan(state) {
    if (!state.periodicScanTimer) return;
    clearTimeout(state.periodicScanTimer);
    state.periodicScanTimer = null;
  }

  ns.tracking = {
    scanNewPosts: scanNewPosts,
    patchHistoryForSPA: patchHistoryForSPA,
    setupLightweightTracking: setupLightweightTracking,
    startPeriodicScan: startPeriodicScan,
    stopPeriodicScan: stopPeriodicScan
  };
})(window);
