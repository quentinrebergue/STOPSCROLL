// Scroll lock exposed via window.StopScroll.scrollLock.
(function (global) {
  'use strict';

  var ns = (global.StopScroll = global.StopScroll || {});
  var SCROLL_KEYS = ns.constants.SCROLL_KEYS;

  function blockWheel(e) {
    e.preventDefault();
    e.stopPropagation();
  }

  function blockScrollKeys(e) {
    if (SCROLL_KEYS.has(e.key)) {
      e.preventDefault();
      e.stopPropagation();
    }
  }

  function applyScrollLock(state, isReelPageFn) {
    if (state.scrollLockActive || !isReelPageFn()) return;
    state.scrollLockActive = true;
    document.documentElement.style.setProperty('overflow', 'hidden', 'important');
    document.documentElement.style.setProperty('overscroll-behavior', 'none', 'important');
    document.body.style.setProperty('overflow', 'hidden', 'important');
    document.body.style.setProperty('overscroll-behavior', 'none', 'important');
    document.addEventListener('wheel', blockWheel, { passive: false, capture: true });
    document.addEventListener('keydown', blockScrollKeys, { capture: true });
  }

  function removeScrollLock(state) {
    if (!state.scrollLockActive) return;
    state.scrollLockActive = false;
    document.documentElement.style.removeProperty('overflow');
    document.documentElement.style.removeProperty('overscroll-behavior');
    document.body.style.removeProperty('overflow');
    document.body.style.removeProperty('overscroll-behavior');
    document.removeEventListener('wheel', blockWheel, { capture: true });
    document.removeEventListener('keydown', blockScrollKeys, { capture: true });
  }

  ns.scrollLock = {
    applyScrollLock: applyScrollLock,
    removeScrollLock: removeScrollLock
  };
})(window);
