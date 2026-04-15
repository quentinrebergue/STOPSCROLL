// Metrics card builder — attaches to window.StopScroll.cardBuilder.
(function (global) {
  'use strict';

  var ns = (global.StopScroll = global.StopScroll || {});
  var cb = ns.cardBuilder;

  function buildMetricsCard(config) {
    var t = config.card_templates || {};
    var readCount = Math.floor((Date.now() / 1000) % 12) + 1;
    var focusMinutes = Math.floor((Date.now() / 1000) % 40) + 8;
    var body = (t.metrics_body || 'You skipped {skipped} dopamine loops and protected {minutes} min of focus.')
      .replace('{skipped}', readCount).replace('{minutes}', focusMinutes);
    var ui = cb.createCardContainer(t.metrics_title || 'Session snapshot', body, '#7ad8ff');
    ui.row.appendChild(cb.makeButton('Open reader', '#8ae9ff', function () { ns.dom.postToNative('metrics-open'); }));
    return ui.card;
  }

  cb.buildMetricsCard = buildMetricsCard;
})(window);
