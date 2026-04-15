// Card selection logic exposed via window.StopScroll.cardLogic.
(function (global) {
  'use strict';

  var ns = (global.StopScroll = global.StopScroll || {});
  var TYPES = ['metrics', 'mood', 'timer', 'stop', 'stats'];

  function cardEnabled(config, type) {
    return !!(config.cards[type] && config.cards[type].enabled);
  }

  function chooseCardType(state, config) {
    // Global frequency gate: only show a card every N opportunities
    var freq = Number(config.cards.every_n_opportunities) || 3;
    if (state.opportunities % freq !== 0) return null;

    // Collect enabled cards with their weights
    var pool = [];
    var totalWeight = 0;
    for (var i = 0; i < TYPES.length; i++) {
      var type = TYPES[i];
      if (!cardEnabled(config, type)) continue;
      var w = Number(config.cards[type].weight) || 1;
      pool.push({ type: type, weight: w });
      totalWeight += w;
    }
    if (pool.length === 0) return null;

    // Weighted random pick
    var roll = Math.random() * totalWeight;
    var cum = 0;
    for (var j = 0; j < pool.length; j++) {
      cum += pool[j].weight;
      if (roll < cum) return pool[j].type;
    }
    return pool[pool.length - 1].type;
  }

  ns.cardLogic = {
    cardEnabled: cardEnabled,
    chooseCardType: chooseCardType
  };
})(window);
