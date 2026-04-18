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

  ns.runtimeState = {
    createRuntimeState: createRuntimeState,
    initializeRuntimeState: initializeRuntimeState
  };
})(window);
