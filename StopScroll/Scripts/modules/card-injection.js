// Card injection into ad posts exposed via window.StopScroll.cardInjection.
(function (global) {
  'use strict';

  var ns = (global.StopScroll = global.StopScroll || {});

  function injectCardIntoPost(article, type, config) {
    var h = article.offsetHeight;
    if (h < 80) return false;

    var card = ns.cardBuilder.buildCardFor(type, config);
    if (!card) return false;

    article.style.setProperty('min-height', h + 'px', 'important');
    article.style.setProperty('overflow', 'hidden', 'important');
    article.style.setProperty('position', 'relative', 'important');
    article.setAttribute('data-ss-replaced', 'true');

    for (var i = 0; i < article.children.length; i++) {
      var child = article.children[i];
      if (child.getAttribute('data-ss-injection')) continue;
      child.style.setProperty('visibility', 'hidden', 'important');
      child.style.setProperty('pointer-events', 'none', 'important');
    }

    new MutationObserver(function () {
      for (var j = 0; j < article.children.length; j++) {
        var c = article.children[j];
        if (!c.getAttribute('data-ss-injection')) {
          c.style.setProperty('visibility', 'hidden', 'important');
          c.style.setProperty('pointer-events', 'none', 'important');
        }
      }
    }).observe(article, { childList: true });

    var wrapper = document.createElement('div');
    wrapper.setAttribute('data-ss-injection', 'true');
    wrapper.style.cssText = 'position:absolute;inset:0;overflow:hidden';

    wrapper.appendChild(card);
    article.appendChild(wrapper);
    return true;
  }

  ns.cardInjection = {
    injectCardIntoPost: injectCardIntoPost
  };
})(window);
