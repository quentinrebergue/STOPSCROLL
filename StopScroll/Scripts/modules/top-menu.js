// Pull-to-refresh (main feed) + settings row injection via window.StopScroll.topMenu.
(function (global) {
  'use strict';

  var ns = (global.StopScroll = global.StopScroll || {});
  var dom = ns.dom;

  // ── Pull-to-refresh ─────────────────────────────────────────────────────────

  var PTR_ID = 'ss-ptr';
  var PTR_THRESHOLD = 65; // px drag needed to trigger reload
  var ptrActive = false;
  var ptrStartY = 0;
  var ptrEl = null;
  var ptrListening = false;

  function getPtrEl() {
    if (ptrEl && ptrEl.parentNode) return ptrEl;
    var el = document.createElement('div');
    el.id = PTR_ID;
    el.style.cssText = [
      'position:fixed', 'top:0', 'left:0', 'right:0',
      'z-index:999999', 'pointer-events:none',
      'display:flex', 'align-items:center', 'justify-content:center',
      'gap:6px', 'height:56px',
      'font-size:13px', 'font-weight:600',
      'color:rgba(255,255,255,0.85)',
      'opacity:0', 'transition:opacity 0.15s'
    ].join(';');
    document.body.appendChild(el);
    ptrEl = el;
    return el;
  }

  function onTouchStart(e) {
    if (window.scrollY !== 0) return;
    ptrActive = true;
    ptrStartY = e.touches[0].clientY;
  }

  function onTouchMove(e) {
    if (!ptrActive) return;
    var delta = e.touches[0].clientY - ptrStartY;
    if (delta <= 0) { ptrActive = false; return; }
    var progress = Math.min(delta / PTR_THRESHOLD, 1);
    var el = getPtrEl();
    el.style.opacity = String(progress * 0.9);
    el.textContent = delta >= PTR_THRESHOLD
      ? '\u21bb  Rel\u00e2cher pour actualiser'
      : '\u21bb  Tirer pour actualiser';
  }

  function onTouchEnd(e) {
    if (!ptrActive) return;
    var endY = e.changedTouches && e.changedTouches[0]
      ? e.changedTouches[0].clientY : ptrStartY;
    var delta = endY - ptrStartY;
    ptrActive = false;
    var el = getPtrEl();
    el.style.opacity = '0';
    if (delta >= PTR_THRESHOLD) {
      dom.postToBridge('reloadFeed');
    }
  }

  function setupPullToRefresh() {
    if (ptrListening) return;
    ptrListening = true;
    document.addEventListener('touchstart', onTouchStart, { passive: true });
    document.addEventListener('touchmove', onTouchMove, { passive: true });
    document.addEventListener('touchend', onTouchEnd, { passive: true });
  }

  function teardownPullToRefresh() {
    if (!ptrListening) return;
    ptrListening = false;
    document.removeEventListener('touchstart', onTouchStart);
    document.removeEventListener('touchmove', onTouchMove);
    document.removeEventListener('touchend', onTouchEnd);
    if (ptrEl) { ptrEl.remove(); ptrEl = null; }
  }

  // ── Settings row injection ───────────────────────────────────────────────────

  var SS_ROW_ATTR = 'data-ss-settings-row';

  var GEAR_SVG = '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>';

  function findAnchorByText(keywords) {
    var links = document.querySelectorAll('main a[href]');
    for (var i = 0; i < links.length; i++) {
      var text = links[i].textContent.toLowerCase();
      for (var k = 0; k < keywords.length; k++) {
        if (text.indexOf(keywords[k]) !== -1) return links[i];
      }
    }
    return null;
  }

  function injectSettingsRow() {
    if (!dom.isSettingsPage()) { removeSettingsRow(); return; }
    if (document.querySelector('[' + SS_ROW_ATTR + ']')) return;

    // Anchor: find the Notifications link (works in any language by trying common words).
    var anchor = findAnchorByText(['notification', 'benachrichtigung', 'notificac']);
    // Fallback: logout link (insert before it).
    var logoutLink = !anchor && document.querySelector('main a[href*="logout"]');
    // Last resort: first link in main.
    var firstLink = !anchor && !logoutLink && document.querySelector('main a[href]');

    if (!anchor && !logoutLink && !firstLink) return;

    var row = document.createElement('div');
    row.setAttribute(SS_ROW_ATTR, '1');
    row.style.cssText = [
      'display:flex', 'align-items:center', 'gap:12px',
      'padding:14px 16px',
      'border-bottom:1px solid rgba(255,255,255,0.1)',
      'cursor:pointer',
      '-webkit-tap-highlight-color:transparent',
      'color:inherit', 'width:100%', 'box-sizing:border-box'
    ].join(';');

    var icon = document.createElement('span');
    icon.style.cssText = 'display:inline-flex;align-items:center;flex-shrink:0';
    icon.innerHTML = GEAR_SVG;

    var label = document.createElement('span');
    label.style.cssText = 'font-size:15px;flex:1';
    label.textContent = 'StopScroll';

    var chevron = document.createElement('span');
    chevron.style.cssText = 'color:rgba(255,255,255,0.35);font-size:20px;line-height:1';
    chevron.textContent = '\u203a';

    row.appendChild(icon);
    row.appendChild(label);
    row.appendChild(chevron);
    row.addEventListener('click', function () {
      dom.postToBridge({ type: 'openSettings' });
    });

    if (anchor) {
      // Insert immediately after the Notifications link.
      anchor.parentElement.insertBefore(row, anchor.nextSibling);
    } else if (logoutLink) {
      logoutLink.parentElement.insertBefore(row, logoutLink);
    } else {
      firstLink.parentElement.appendChild(row);
    }
  }

  function removeSettingsRow() {
    var el = document.querySelector('[' + SS_ROW_ATTR + ']');
    if (el) el.remove();
  }

  // ── Orchestrator (called on every scan tick) ─────────────────────────────────

  function manage() {
    if (dom.isMainFeed()) {
      setupPullToRefresh();
    } else {
      teardownPullToRefresh();
    }
    injectSettingsRow();
  }

  ns.topMenu = {
    manage: manage,
    setupPullToRefresh: setupPullToRefresh,
    teardownPullToRefresh: teardownPullToRefresh,
    injectSettingsRow: injectSettingsRow,
    removeSettingsRow: removeSettingsRow,
    // Legacy aliases
    injectHeaderButtons: manage,
    removeHeaderButtons: function () { teardownPullToRefresh(); removeSettingsRow(); },
    injectTopMenu: manage,
    removeTopMenu: function () { teardownPullToRefresh(); removeSettingsRow(); },
    adjustPageForTopMenu: function () {}
  };
})(window);
