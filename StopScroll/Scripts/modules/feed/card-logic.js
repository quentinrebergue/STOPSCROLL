// Card selection logic exposed via window.StopScroll.cardLogic.
(function (global) {
  'use strict';

  var ns = (global.StopScroll = global.StopScroll || {});
  var TYPES = ['metrics', 'mood', 'timer', 'stop', 'stats', 'book', 'culture'];

  // Rolling history of last shown card types (most recent first)
  var _history = [];
  var HISTORY_LEN = 5;

  function cardEnabled(config, type) {
    return !!(config.cards[type] && config.cards[type].enabled);
  }

  /**
   * Pick a card type. Does NOT record the choice — the caller must
   * call recordChoice() once the card is successfully shown.
   * @param {Set|Object} [exclude] — types to skip (e.g. already tried)
   */
  function chooseCardType(state, config, exclude) {
    // Frequency 0 = cards disabled
    var freq = Number(config.cards.every_n_opportunities);
    if (freq <= 0) return null;

    // Global frequency gate: only show a card every N opportunities
    if (state.opportunities % freq !== 0) return null;

    var lastShown = _history.length > 0 ? _history[0] : null;

    // Collect enabled cards with adjusted weights
    var pool = [];
    var totalWeight = 0;
    for (var i = 0; i < TYPES.length; i++) {
      var type = TYPES[i];
      if (!cardEnabled(config, type)) continue;
      // Hard-exclude the last shown type (no repeat)
      if (type === lastShown) continue;
      // Skip types the caller already tried and failed
      if (exclude && exclude[type]) continue;

      var w = Number(config.cards[type].weight) || 1;

      // Softer penalty for 2nd and 3rd in history
      var histIdx = _history.indexOf(type);
      if (histIdx === 1) w = Math.max(w / 3, 1);
      else if (histIdx === 2) w = Math.max(w / 1.5, 1);

      pool.push({ type: type, weight: w });
      totalWeight += w;
    }
    if (pool.length === 0) return null;

    // If only one type available, just return it
    if (pool.length === 1) return pool[0].type;

    // Weighted random pick
    var roll = Math.random() * totalWeight;
    var cum = 0;
    for (var j = 0; j < pool.length; j++) {
      cum += pool[j].weight;
      if (roll < cum) return pool[j].type;
    }
    return pool[pool.length - 1].type;
  }

  function recordChoice(type) {
    _history.unshift(type);
    if (_history.length > HISTORY_LEN) _history.length = HISTORY_LEN;
  }

  ns.cardLogic = {
    cardEnabled: cardEnabled,
    chooseCardType: chooseCardType,
    recordChoice: recordChoice
  };
})(window);
