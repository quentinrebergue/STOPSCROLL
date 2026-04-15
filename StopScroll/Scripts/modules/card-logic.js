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

  function chooseCardType(state, config) {
    // Frequency 0 = cards disabled
    var freq = Number(config.cards.every_n_opportunities);
    if (freq <= 0) return null;

    // Global frequency gate: only show a card every N opportunities
    if (state.opportunities % freq !== 0) return null;

    // Collect enabled cards with adjusted weights
    var pool = [];
    var totalWeight = 0;
    for (var i = 0; i < TYPES.length; i++) {
      var type = TYPES[i];
      if (!cardEnabled(config, type)) continue;
      var w = Number(config.cards[type].weight) || 1;

      // Penalise recently shown types:
      // last shown → weight ÷ 8, second-to-last → ÷ 3, third → ÷ 1.5
      var histIdx = _history.indexOf(type);
      if (histIdx === 0) w = Math.max(w / 8, 1);
      else if (histIdx === 1) w = Math.max(w / 3, 1);
      else if (histIdx === 2) w = Math.max(w / 1.5, 1);

      pool.push({ type: type, weight: w });
      totalWeight += w;
    }
    if (pool.length === 0) return null;

    // If only one type available, just return it
    if (pool.length === 1) {
      recordChoice(pool[0].type);
      return pool[0].type;
    }

    // Weighted random pick
    var roll = Math.random() * totalWeight;
    var cum = 0;
    for (var j = 0; j < pool.length; j++) {
      cum += pool[j].weight;
      if (roll < cum) {
        recordChoice(pool[j].type);
        return pool[j].type;
      }
    }
    var last = pool[pool.length - 1].type;
    recordChoice(last);
    return last;
  }

  function recordChoice(type) {
    _history.unshift(type);
    if (_history.length > HISTORY_LEN) _history.length = HISTORY_LEN;
  }

  ns.cardLogic = {
    cardEnabled: cardEnabled,
    chooseCardType: chooseCardType
  };
})(window);
