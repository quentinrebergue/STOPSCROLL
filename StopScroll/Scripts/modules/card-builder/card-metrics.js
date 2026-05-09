// Metrics card builder — attaches to window.StopScroll.cardBuilder.
(function (global) {
  'use strict';

  var ns = (global.StopScroll = global.StopScroll || {});
  var cb = ns.cardBuilder;

  function buildMetricsCard(config) {
    var t = config.card_templates || {};
    var stats = ns.sessionStats ? ns.sessionStats.getStats() : { sessionSeconds: 0, posts: 0, ads: 0 };
    var mins = stats.sessionSeconds < 60
      ? 'less than a minute'
      : Math.floor(stats.sessionSeconds / 60) + ' min';
    var body = (t.metrics_body || "You've been scrolling for {minutes} and seen {posts} posts — {ads} of which were ads.")
      .replace('{minutes}', mins)
      .replace('{posts}', String(stats.posts))
      .replace('{ads}', String(stats.ads));
    var ui = cb.createCardContainer(t.metrics_title || 'Scroll check', body, '#7ad8ff');
    ui.row.appendChild(cb.makeButton('Open reader', '#8ae9ff', function () { ns.dom.postToNative('metrics-open'); }));
    return ui.card;
  }

  cb.buildMetricsCard = buildMetricsCard;
})(window);
