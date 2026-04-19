// Wikipedia random article fetcher — attaches to window.StopScroll.wikipedia.
(function (global) {
  'use strict';

  var ns = (global.StopScroll = global.StopScroll || {});
  var _article = null;
  var _fetching = false;

  function getLang() {
    var raw = document.documentElement.lang || navigator.language || 'en';
    return raw.split('-')[0].toLowerCase() || 'en';
  }

  /** Ask the native Swift side to fetch a Wikipedia article (bypasses CSP). */
  function fetchArticle(callback) {
    if (_fetching) return;
    _fetching = true;
    _pendingCallback = callback || null;
    ns.dom.postToBridgeWithCallback({ type: 'fetchArticle', lang: getLang() }, function (result) {
      if (!result || result.ok !== false) return;
      _fetching = false;
      if (_pendingCallback) {
        _pendingCallback(_article);
        _pendingCallback = null;
      }
    });
    // Timeout: if Swift doesn't respond in 10s, allow retry
    setTimeout(function () { _fetching = false; }, 10000);
  }

  var _pendingCallback = null;

  /** Called by Swift when the native fetch completes. */
  function _setFromNative(article) {
    _fetching = false;
    if (article && article.extract) {
      _article = article;
    }
    if (_pendingCallback) {
      _pendingCallback(_article);
      _pendingCallback = null;
    }
  }

  /** Pre-fetch an article so it's ready when the card appears. */
  function prefetch() {
    if (!_article) fetchArticle();
  }

  /** Get cached article (may be null if not yet fetched). */
  function getCached() { return _article; }

  /** Consume the article and pre-fetch the next one. */
  function consume() {
    var a = _article;
    _article = null;
    fetchArticle(); // pre-load next
    return a;
  }

  ns.wikipedia = {
    prefetch: prefetch,
    getCached: getCached,
    consume: consume,
    fetchArticle: fetchArticle,
    getLang: getLang,
    _setFromNative: _setFromNative
  };
})(window);
