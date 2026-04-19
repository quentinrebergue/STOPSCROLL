// Runtime UI orchestration.
(function (global) {
  'use strict';

  const ns = (global.StopScroll = global.StopScroll || {});

  function applyNavInjections() {
    ns.nav.cleanReels();
    ns.topMenu.injectTopMenu();
    ns.nav.cleanLegacyReloadButton();
    ns.nav.syncNativeNavState();
    if (ns.cardBuilder && ns.cardBuilder.refreshInjectedCardColors) {
      ns.cardBuilder.refreshInjectedCardColors();
    }
  }

  function applyPagePolicies(state) {
    ns.pageManager.manageReelPageRestrictions(state);
  }

  ns.runtimeUI = {
    applyNavInjections: applyNavInjections,
    applyPagePolicies: applyPagePolicies
  };
})(window);
