// Navigation behavior (Reels tab replacement and legacy cleanup).
(function (global) {
  'use strict';

  const ns = (global.StopScroll = global.StopScroll || {});
  const dom = ns.dom;
  const constants = ns.constants;

  function transformReelsToBook(link) {
    link.setAttribute('data-ss-book', '1');

    const svg = link.querySelector('svg');
    if (svg) {
      svg.setAttribute('aria-label', 'Read');
      svg.setAttribute('viewBox', '0 0 24 24');
      svg.setAttribute('width', '24');
      svg.setAttribute('height', '24');
      svg.innerHTML = '<path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>'
        + '<path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>';
    }

    link.setAttribute('href', '#book');
    link.style.cssText += ';display:flex!important;align-items:center;justify-content:center;';

    const li = link.closest('li');
    if (li) li.style.cssText += ';display:list-item!important;';

    const wrapper = link.parentElement;
    if (wrapper && wrapper.children.length <= 2) {
      wrapper.style.cssText += ';display:flex!important;';
    }

    link.addEventListener('click', function (e) {
      e.preventDefault();
      e.stopPropagation();
      dom.postToNative('open');
    });
  }

  function cleanReels() {
    document
      .querySelectorAll('a[href="/reels/"]:not([data-ss-book]), a[href="/reels"]:not([data-ss-book])')
      .forEach(function (el) {
        transformReelsToBook(el);
      });
  }

  function cleanLegacyReloadButton() {
    const floating = document.getElementById(constants.RELOAD_BUTTON_ID);
    if (floating) floating.style.display = 'none';
  }

  ns.nav = {
    transformReelsToBook: transformReelsToBook,
    cleanReels: cleanReels,
    cleanLegacyReloadButton: cleanLegacyReloadButton
  };
})(window);
