// Ad detection exposed via window.StopScroll.adDetection.
(function (global) {
  'use strict';

  var ns = (global.StopScroll = global.StopScroll || {});

  // ── Follow-button keywords per language (lowercase, trimmed) ──
  var FOLLOW_LABELS = [
    'follow', 'suivre', 'seguir', 'folgen', 'segui', 'seguire',
    'フォロー', '팔로우', '关注', 'متابعة'
  ];

  function isAdPost(article) {
    var spans = article.querySelectorAll('span');
    var adLabels = ns.config.getAdLabels();
    for (var i = 0; i < spans.length; i++) {
      var el = spans[i];
      if (el.childElementCount > 0) continue;
      var text = (el.textContent || '').trim().toLowerCase();
      if (text.length < 2 || text.length > 60) continue;
      if (adLabels.indexOf(text) !== -1) return true;
    }
    return false;
  }

  /**
   * Detect suggested/recommended posts by looking for a Follow button
   * in the post header (the area above the image).
   * Instagram shows "· Suivre" / "· Follow" next to the username for
   * posts from accounts the user doesn't follow.
   */
  /** Returns true if text contains any follow keyword. */
  function containsFollowKeyword(text) {
    var t = (text || '').trim().toLowerCase();
    if (!t) return false;
    for (var k = 0; k < FOLLOW_LABELS.length; k++) {
      if (t === FOLLOW_LABELS[k]) return true;
      // Match "· Suivre", "• Follow", etc.
      if (t.indexOf(FOLLOW_LABELS[k]) !== -1 && t.length < 40) return true;
    }
    return false;
  }

  function isSuggestedPost(article) {
    // Scan both the header and the area just above the media.
    var header = article.querySelector('header');
    var scope = header || article;

    // Strategy 1: clickable elements (button, link, role=button, div)
    var clickables = scope.querySelectorAll('button, a, [role="button"], div');
    for (var i = 0; i < clickables.length; i++) {
      var el = clickables[i];
      // Only check leaf-ish elements (avoid scanning huge parent divs)
      if (el.children.length > 3) continue;
      var text = (el.textContent || '').trim();
      if (text.length > 60) continue;
      if (containsFollowKeyword(text)) return true;
    }

    // Strategy 2: any span containing a follow keyword
    var spans = scope.querySelectorAll('span');
    for (var j = 0; j < spans.length; j++) {
      var sp = spans[j];
      if (sp.childElementCount > 0) continue;
      var st = (sp.textContent || '').trim();
      if (st.length > 60) continue;
      if (containsFollowKeyword(st)) return true;
    }

    return false;
  }

  /** Checks whether a post should be replaced (ad OR suggested). */
  function shouldReplace(article, config) {
    if (isAdPost(article)) return true;
    if (config.feed_injection.replace_suggested !== false && isSuggestedPost(article)) return true;
    return false;
  }

  function scanForNewAds(state, callback) {
    var cfg = state.config.feed_injection;
    var maxCards = Number(cfg.max_dynamic_posts_per_session) || 0;
    var freq = Number(state.config.cards.every_n_opportunities) || 1;
    var replaceAll = freq === 1; // "Every post" mode: bypass ad/suggested check
    var posts = document.querySelectorAll('article');
    for (var i = 0; i < posts.length; i++) {
      var post = posts[i];
      if (state.seenPosts.has(post)) continue;
      state.seenPosts.add(post);
      if (ns.sessionStats) ns.sessionStats.trackPost();
      if (!replaceAll && !shouldReplace(post, state.config)) continue;
      if (ns.sessionStats) ns.sessionStats.trackAd();
      if (maxCards > 0 && state.shownCards >= maxCards) return;
      callback(post);
    }
  }

  ns.adDetection = {
    isAdPost: isAdPost,
    isSuggestedPost: isSuggestedPost,
    shouldReplace: shouldReplace,
    scanForNewAds: scanForNewAds
  };
})(window);
