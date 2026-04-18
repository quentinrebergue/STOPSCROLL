// Navigation behavior (Reels tab replacement and legacy cleanup).
(function (global) {
  'use strict';

  const ns = (global.StopScroll = global.StopScroll || {});
  const dom = ns.dom;
  const constants = ns.constants;
  const HIDE_NAV_ATTR = 'data-ss-hidden-native-nav';
  const HIDE_NAV_PARENT_ATTR = 'data-ss-hidden-native-nav-parent';
  const STYLE_ID = 'ss-native-nav-hide-style';

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
    return Array.from(document.querySelectorAll('nav a[href]'));
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
      link.click();
      return true;
    }

    const fallbackPaths = {
      home: '/',
      search: '/explore/',
      messages: '/direct/inbox/',
      activity: '/accounts/activity/',
      profile: null
    };
    const fallback = fallbackPaths[tab];
    if (fallback) {
      global.location.href = fallback;
      return true;
    }

    if (tab === 'profile') {
      // Last-resort profile fallback: try to infer username from current path.
      const path = normalizePath(global.location.pathname);
      if (isProfilePath(path)) {
        global.location.href = path + '/';
        return true;
      }
    }

    return false;
  }

  function ensureHideStyle() {
    if (document.getElementById(STYLE_ID)) return;
    const style = document.createElement('style');
    style.id = STYLE_ID;
    style.textContent = [
      'nav[' + HIDE_NAV_ATTR + '="1"]{display:none!important;visibility:hidden!important;opacity:0!important;pointer-events:none!important;}',
      '[' + HIDE_NAV_PARENT_ATTR + '="1"]{display:none!important;visibility:hidden!important;opacity:0!important;pointer-events:none!important;}'
    ].join('\n');
    (document.head || document.documentElement).appendChild(style);
  }

  function hideInstagramNativeNav() {
    ensureHideStyle();
    const navs = document.querySelectorAll('nav');
    navs.forEach(function (nav) {
      const links = nav.querySelectorAll('a[href]');
      let score = 0;
      links.forEach(function (link) {
        const path = pathFromHref(link.getAttribute('href') || link.href || '');
        if (path === '/' || path.startsWith('/explore') || path.startsWith('/direct') || path.startsWith('/accounts/activity') || isProfilePath(path)) {
          score += 1;
        }
      });

      if (score >= 3) {
        nav.setAttribute(HIDE_NAV_ATTR, '1');
        nav.style.setProperty('display', 'none', 'important');
        nav.style.setProperty('visibility', 'hidden', 'important');
        nav.style.setProperty('pointer-events', 'none', 'important');

        let parent = nav.parentElement;
        let depth = 0;
        while (parent && depth < 4) {
          const isFixed = global.getComputedStyle(parent).position === 'fixed';
          if (isFixed || parent.tagName === 'FOOTER') {
            parent.setAttribute(HIDE_NAV_PARENT_ATTR, '1');
            parent.style.setProperty('display', 'none', 'important');
            parent.style.setProperty('visibility', 'hidden', 'important');
            parent.style.setProperty('pointer-events', 'none', 'important');
          }
          parent = parent.parentElement;
          depth += 1;
        }
      }
    });
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
    nativeNavigateToTab: nativeNavigateToTab,
    hideInstagramNativeNav: hideInstagramNativeNav
  };
})(window);
