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

  ns.runtimeState = {
    createRuntimeState: createRuntimeState,
    initializeRuntimeState: initializeRuntimeState,
    setPaused: setPaused
  };
})(window);
