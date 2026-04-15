// Ad detection exposed via window.StopScroll.adDetection.
(function (global) {
  'use strict';

  var ns = (global.StopScroll = global.StopScroll || {});

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

  function scanForNewAds(state, callback) {
    var cfg = state.config.feed_injection;
    var maxCards = Number(cfg.max_dynamic_posts_per_session) || 0;
    var posts = document.querySelectorAll('article');
    for (var i = 0; i < posts.length; i++) {
      var post = posts[i];
      if (state.seenPosts.has(post)) continue;
      state.seenPosts.add(post);
      if (ns.sessionStats) ns.sessionStats.trackPost();
      if (!isAdPost(post)) continue;
      if (ns.sessionStats) ns.sessionStats.trackAd();
      if (maxCards > 0 && state.shownCards >= maxCards) return;
      callback(post);
    }
  }

  ns.adDetection = {
    isAdPost: isAdPost,
    scanForNewAds: scanForNewAds
  };
})(window);
