// Stop card builder — attaches to window.StopScroll.cardBuilder.
(function (global) {
  'use strict';

  var cb = (global.StopScroll = global.StopScroll || {}).cardBuilder;

  function buildStopCard(config) {
    // Stop card reuses the timer card UI (same purpose: set a stop time)
    return cb.buildTimerCard(config);
  }

  cb.buildStopCard = buildStopCard;
})(window);
