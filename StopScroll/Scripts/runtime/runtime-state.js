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
    // Pre-fetch a Wikipedia article so the culture card has content ready
    if (ns.wikipedia && ns.wikipedia.prefetch) ns.wikipedia.prefetch();
  }

  ns.runtimeState = {
    createRuntimeState: createRuntimeState,
    initializeRuntimeState: initializeRuntimeState
  };
})(window);
