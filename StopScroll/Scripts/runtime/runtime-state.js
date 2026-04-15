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
  }

  ns.runtimeState = {
    createRuntimeState: createRuntimeState,
    initializeRuntimeState: initializeRuntimeState
  };
})(window);
