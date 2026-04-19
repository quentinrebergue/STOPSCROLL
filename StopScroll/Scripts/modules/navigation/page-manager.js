// Page management exposed via window.StopScroll.pageManager.
(function (global) {
  'use strict';

  var ns = (global.StopScroll = global.StopScroll || {});
  var dom = ns.dom;
  var scrollLock = ns.scrollLock;

  function hideExtraContent() {
    if (!dom.isSingleContentPage()) return;

    var allArticles = document.querySelectorAll('article');
    if (allArticles.length > 1) {
      for (var i = 1; i < allArticles.length; i++) {
        allArticles[i].style.setProperty('display', 'none', 'important');
      }
    }

    if (!dom.isReelPage()) return;

    var videos = document.querySelectorAll('video');
    if (videos.length > 0) {
      var firstVideo = videos[0];
      var firstCard = firstVideo.closest('div[role="presentation"]')
        || firstVideo.closest('article')
        || firstVideo.closest('section > div > div');

      if (firstCard && firstCard.parentElement) {
        var siblings = firstCard.parentElement.children;
        var foundFirst = false;
        for (var j = 0; j < siblings.length; j++) {
          var child = siblings[j];
          if (child === firstCard) { foundFirst = true; continue; }
          if (foundFirst) child.style.setProperty('display', 'none', 'important');
        }
      }
    }
  }

  function manageReelPageRestrictions(state) {
    if (dom.isReelsTab()) { global.location.href = '/'; return; }
    if (dom.isDirectPath && dom.isDirectPath()) {
      scrollLock.removeScrollLock(state);
      if (dom.postToBridge) {
        dom.postToBridge({
          type: 'debugLog',
          category: 'ScrollLock',
          level: 'DEBUG',
          message: 'skip_reel_lock_on_direct_path'
        });
      }
      return;
    }

    if (dom.isReelPage()) {
      scrollLock.applyScrollLock(state, dom.isReelPage);
      if (dom.postToBridge) {
        dom.postToBridge({
          type: 'debugLog',
          category: 'ScrollLock',
          level: 'DEBUG',
          message: 'apply_reel_lock'
        });
      }
    } else {
      scrollLock.removeScrollLock(state);
      if (dom.postToBridge) {
        dom.postToBridge({
          type: 'debugLog',
          category: 'ScrollLock',
          level: 'DEBUG',
          message: 'remove_reel_lock_non_reel_path'
        });
      }
    }
    hideExtraContent();
  }

  function feedInjectingEnabled(config) {
    return !!(config && config.feed_injection && config.feed_injection.enabled);
  }

  function isMainFeedPage() {
    return dom.isMainFeed();
  }

  ns.pageManager = {
    hideExtraContent: hideExtraContent,
    manageReelPageRestrictions: manageReelPageRestrictions,
    feedInjectingEnabled: feedInjectingEnabled,
    isMainFeedPage: isMainFeedPage
  };
})(window);
