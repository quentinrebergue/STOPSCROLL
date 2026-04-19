// Navigation behavior (Reels tab replacement and legacy cleanup).
(function (global) {
  'use strict';

  const ns = (global.StopScroll = global.StopScroll || {});
  const dom = ns.dom;
  const constants = ns.constants;

  let lastSentTab = '';
  let lastSentMessageBadge = -1;

  function normalizePath(path) {
    if (!path) return '/';
    const noQuery = path.split('?')[0].split('#')[0];
    if (noQuery.length > 1 && noQuery.endsWith('/')) return noQuery.slice(0, -1);
    return noQuery || '/';
  }

  function pathFromHref(href) {
    try {
      return normalizePath(new URL(href, global.location.origin).pathname);
    } catch (_) {
      return '';
    }
  }

  function isProfilePath(path) {
    if (!path || path === '/') return false;
    const normalized = normalizePath(path);
    const blockedPrefixes = [
      '/explore', '/reels', '/direct', '/accounts', '/p/', '/stories', '/challenge', '/about', '/developer', '/legal'
    ];
    for (let i = 0; i < blockedPrefixes.length; i++) {
      if (normalized === blockedPrefixes[i] || normalized.startsWith(blockedPrefixes[i])) {
        return false;
      }
    }
    return /^\/[a-zA-Z0-9._]+$/.test(normalized);
  }

  function detectCurrentTab() {
    const path = normalizePath(global.location.pathname);
    if (path === '/') return 'home';
    if (path.startsWith('/explore')) return 'search';
    if (path.startsWith('/direct')) return 'messages';
    if (path.startsWith('/accounts/activity')) return 'activity';
    if (isProfilePath(path)) return 'profile';
    return 'home';
  }

  function getNavLinks() {
    const tabNav = findBottomTabNav();
    if (!tabNav) return [];
    return Array.from(tabNav.querySelectorAll('a[href]'));
  }

  function findBottomTabNav() {
    const navs = Array.from(document.querySelectorAll('nav'));
    if (!navs.length) return null;

    let bestNav = null;
    let bestScore = -1;

    for (let i = 0; i < navs.length; i++) {
      const nav = navs[i];
      const links = Array.from(nav.querySelectorAll('a[href]'));
      if (!links.length) continue;

      let score = 0;
      let hasHome = false;
      let hasSearch = false;
      let hasMessages = false;
      let hasProfile = false;

      for (let k = 0; k < links.length; k++) {
        const path = pathFromHref(links[k].getAttribute('href') || links[k].href || '');
        if (normalizePath(path) === '/') { hasHome = true; continue; }
        if (normalizePath(path).startsWith('/explore')) { hasSearch = true; continue; }
        if (normalizePath(path).startsWith('/direct')) { hasMessages = true; continue; }
        if (isProfilePath(path)) { hasProfile = true; continue; }
      }

      if (hasHome) score += 2;
      if (hasSearch) score += 2;
      if (hasMessages) score += 2;
      if (hasProfile) score += 2;

      const rect = nav.getBoundingClientRect();
      const nearBottom = rect.top > global.innerHeight * 0.45;
      const isFixed = global.getComputedStyle(nav).position === 'fixed';
      if (nearBottom) score += 3;
      if (isFixed) score += 2;

      if (score > bestScore) {
        bestScore = score;
        bestNav = nav;
      }
    }

    return bestScore >= 6 ? bestNav : null;
  }

  function findTabLink(tab) {
    const links = getNavLinks();
    const tabPaths = {
      home: ['/', ''],
      search: ['/explore', '/explore/'],
      messages: ['/direct', '/direct/', '/direct/inbox', '/direct/inbox/'],
      activity: ['/accounts/activity', '/accounts/activity/']
    };

    for (let i = 0; i < links.length; i++) {
      const link = links[i];
      const path = pathFromHref(link.getAttribute('href') || link.href || '');

      if (tab === 'profile') {
        if (link.querySelector('img')) return link;
        if (isProfilePath(path)) return link;
      }

      const paths = tabPaths[tab] || [];
      for (let k = 0; k < paths.length; k++) {
        if (normalizePath(paths[k]) === normalizePath(path)) {
          return link;
        }
      }
    }
    return null;
  }

  function extractInt(text) {
    const match = String(text || '').match(/\d+/);
    return match ? parseInt(match[0], 10) : 0;
  }

  function readMessageBadge() {
    const messageLink = findTabLink('messages')
      || document.querySelector('a[href^="/direct"], a[href*="/direct/"]');
    if (!messageLink) return 0;

    const aria = messageLink.getAttribute('aria-label') || '';
    const ariaCount = extractInt(aria);
    if (ariaCount > 0) return ariaCount;

    const badgeNodes = messageLink.querySelectorAll('span, div');
    for (let i = 0; i < badgeNodes.length; i++) {
      const text = (badgeNodes[i].textContent || '').trim();
      if (!text || text.length > 4) continue;
      const value = extractInt(text);
      if (value > 0) return value;
    }
    return 0;
  }

  function syncNativeNavState() {
    const tab = detectCurrentTab();
    const badge = readMessageBadge();
    if (tab === lastSentTab && badge === lastSentMessageBadge) return;

    lastSentTab = tab;
    lastSentMessageBadge = badge;
    dom.postToBridge({ type: 'nativeNavState', tab: tab, messageBadge: badge });
  }

  function nativeNavigateToTab(tab) {
    if (!tab) return false;

    const link = findTabLink(tab);
    if (link) {
      // Prefer dispatching events on an inner visual node (icon/span) so React handlers fire
      // without triggering the anchor default navigation (which causes full page reloads).
      const interactionTarget = link.querySelector('svg, span, div') || link;

      try {
        interactionTarget.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true, cancelable: true, pointerType: 'touch' }));
      } catch (_) {}
      try {
        interactionTarget.dispatchEvent(new MouseEvent('mousedown', { bubbles: true, cancelable: true, view: global }));
      } catch (_) {}
      try {
        interactionTarget.dispatchEvent(new PointerEvent('pointerup', { bubbles: true, cancelable: true, pointerType: 'touch' }));
      } catch (_) {}
      try {
        interactionTarget.dispatchEvent(new MouseEvent('mouseup', { bubbles: true, cancelable: true, view: global }));
      } catch (_) {}
      try {
        interactionTarget.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: global }));
      } catch (_) {}

      // Fallback: update SPA history state without network navigation.
      const href = link.getAttribute('href') || link.href || '';
      const path = pathFromHref(href);
      if (path && normalizePath(path) !== normalizePath(global.location.pathname)) {
        try {
          global.history.pushState({}, '', path + (path.endsWith('/') ? '' : '/'));
          global.dispatchEvent(new Event('pushstate'));
          global.dispatchEvent(new PopStateEvent('popstate'));
          global.dispatchEvent(new Event('locationchange'));
        } catch (_) {
          // Keep silent: click simulation above is the primary path.
        }
      }
      return true;
    }

    // Fallbacks for cases where bottom tab links are not yet discoverable.
    if (tab === 'search') {
      global.location.href = '/explore/';
      return true;
    }
    if (tab === 'home') {
      global.location.href = '/';
      return true;
    }
    if (tab === 'profile') {
      var raw = (global.__STOPSCROLL_INSTAGRAM_USERNAME || '').trim();
      var username = raw.replace(/^@+/, '').replace(/[^a-zA-Z0-9._]/g, '');
      if (username) {
        global.location.href = '/' + username + '/';
        return true;
      }
    }
    return false;
  }


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
    cleanLegacyReloadButton: cleanLegacyReloadButton,
    syncNativeNavState: syncNativeNavState,
    nativeNavigateToTab: nativeNavigateToTab
  };
})(window);
