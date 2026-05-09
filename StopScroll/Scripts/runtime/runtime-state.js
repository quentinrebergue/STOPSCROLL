// Runtime state bootstrap.
(function (global) {
  'use strict';

  const ns = (global.StopScroll = global.StopScroll || {});

  function createRuntimeState() {
    return Object.assign({}, ns.constants.DEFAULT_STATE);
  }

  function initializeRuntimeState(state) {
    state.config = ns.config.loadConfig();
    ns.dom.detectLanguage();
    if (ns.dom.detectTheme) ns.dom.detectTheme();
    // Pre-fetch articles from all enabled sources
    var sources = global.__STOPSCROLL_ARTICLE_SOURCES || ['wikipedia'];
    for (var i = 0; i < sources.length; i++) {
      if (sources[i] === 'guardian' && ns.guardian && ns.guardian.prefetch) {
        ns.guardian.prefetch();
      }
      if (sources[i] === 'wikipedia' && ns.wikipedia && ns.wikipedia.prefetch) {
        ns.wikipedia.prefetch();
      }
    }
  }

  function setPaused(state, paused) {
    var nextPaused = !!paused;
    state.paused = nextPaused;
    global.__STOPSCROLL_RUNTIME_PAUSED = nextPaused;

    if (ns.tracking && ns.tracking.stopPeriodicScan && ns.tracking.startPeriodicScan) {
      if (nextPaused) {
        ns.tracking.stopPeriodicScan(state);
      } else if (global.__STOPSCROLL_SCHEDULE_SCAN) {
        ns.tracking.startPeriodicScan(state, global.__STOPSCROLL_SCHEDULE_SCAN);
        global.__STOPSCROLL_SCHEDULE_SCAN();
      }
    }

    if (nextPaused) {
      var videos = document.querySelectorAll('video');
      for (var i = 0; i < videos.length; i++) {
        try { videos[i].pause(); } catch (_) {}
      }
    }
  }

  function applyConfigFromGlobals(state) {
    if (!state || !ns.config || !ns.config.loadConfig) return false;
    state.config = ns.config.loadConfig();
    return true;
  }

  function normalizeFrequency(value) {
    var parsed = Number(value);
    if (!isFinite(parsed)) return null;
    return Math.max(0, Math.floor(parsed));
  }

  function normalizeLabels(value) {
    if (!Array.isArray(value)) return null;
    var out = [];
    for (var i = 0; i < value.length; i++) {
      var label = String(value[i] || '').trim().toLowerCase();
      if (!label) continue;
      out.push(label);
    }
    return out;
  }

  function normalizeDelayMultiplier(value, fallback) {
    var parsed = Number(value);
    if (!isFinite(parsed) || parsed <= 0) return fallback;
    return parsed;
  }

  function applyGovernor(state, payload) {
    var next = payload && typeof payload === 'object' ? payload : {};
    var mode = String(next.mode || 'nominal');
    var scanMultiplier = normalizeDelayMultiplier(next.scanDelayMultiplier, 1);
    var navLiteMultiplier = normalizeDelayMultiplier(next.navLiteDelayMultiplier, 1);

    global.__STOPSCROLL_GOVERNOR_MODE = mode;
    global.__STOPSCROLL_SCAN_DELAY_MULTIPLIER = scanMultiplier;
    global.__STOPSCROLL_NAV_LITE_DELAY_MULTIPLIER = navLiteMultiplier;

    if (state) {
      state.governorMode = mode;
    }

    if (!state || state.paused || global.__STOPSCROLL_RUNTIME_PAUSED) {
      return true;
    }

    if (ns.tracking && ns.tracking.startPeriodicScan && global.__STOPSCROLL_SCHEDULE_SCAN) {
      ns.tracking.startPeriodicScan(state, global.__STOPSCROLL_SCHEDULE_SCAN);
      global.__STOPSCROLL_SCHEDULE_SCAN();
    }

    return true;
  }

  function receiveBridgeCommand(command, payload) {
    if (command === 'setPaused') {
      if (ns._state) {
        setPaused(ns._state, !!payload);
        return true;
      }
      return false;
    }

    if (command === 'setFrequency') {
      var nextFrequency = normalizeFrequency(payload);
      if (nextFrequency === null) return false;

      global.__STOPSCROLL_FREQUENCY = nextFrequency;
      if (applyConfigFromGlobals(ns._state) && !global.__STOPSCROLL_RUNTIME_PAUSED && global.__STOPSCROLL_SCHEDULE_SCAN) {
        global.__STOPSCROLL_SCHEDULE_SCAN();
      }
      return true;
    }

    if (command === 'setGovernor') {
      return applyGovernor(ns._state, payload);
    }

    if (command === 'setLabels') {
      var nextLabels = normalizeLabels(payload);
      if (nextLabels === null) return false;

      global.__STOPSCROLL_AD_LABELS = nextLabels;
      if (applyConfigFromGlobals(ns._state) && !global.__STOPSCROLL_RUNTIME_PAUSED && global.__STOPSCROLL_SCHEDULE_SCAN) {
        global.__STOPSCROLL_SCHEDULE_SCAN();
      }
      return true;
    }

    return false;
  }

  ns.bridge = ns.bridge || {};
  ns.bridge.receive = receiveBridgeCommand;

  ns.runtimeState = {
    createRuntimeState: createRuntimeState,
    initializeRuntimeState: initializeRuntimeState,
    setPaused: setPaused,
    applyConfigFromGlobals: applyConfigFromGlobals
  };
})(window);
