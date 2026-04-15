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

  function fetchArticle(callback) {
    if (_fetching) return;
    _fetching = true;
    var lang = getLang();
    var url = 'https://' + lang + '.wikipedia.org/api/rest_v1/page/random/summary';

    var xhr = new XMLHttpRequest();
    xhr.open('GET', url, true);
    xhr.setRequestHeader('Accept', 'application/json');
    xhr.onreadystatechange = function () {
      if (xhr.readyState !== 4) return;
      _fetching = false;
      if (xhr.status !== 200) { if (callback) callback(null); return; }
      try {
        var data = JSON.parse(xhr.responseText);
        _article = {
          title: data.title || '',
          extract: data.extract || '',
          description: data.description || '',
          pageUrl: (data.content_urls && data.content_urls.mobile && data.content_urls.mobile.page) || '',
          thumbnail: (data.thumbnail && data.thumbnail.source) || '',
          lang: lang
        };
        if (callback) callback(_article);
      } catch (e) {
        if (callback) callback(null);
      }
    };
    xhr.send();
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
    getLang: getLang
  };
})(window);
