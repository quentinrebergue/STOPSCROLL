// Card injection into ad posts exposed via window.StopScroll.cardInjection.
(function (global) {
  'use strict';

  var ns = (global.StopScroll = global.StopScroll || {});

  // ── Timer-expired motivational messages ─────────────────
  var EXPIRED_MESSAGES = [
    { emoji: '🏁', text: "Time\u2019s up! You did it \u2014 now stand up and stretch." },
    { emoji: '🌿', text: "Your break is over. Take a deep breath." },
    { emoji: '🚶', text: "Get up. Walk around. Your body will thank you." },
    { emoji: '💪', text: "You set a goal and respected it. That\u2019s discipline." },
    { emoji: '☀️', text: "The real world is waiting for you out there." },
    { emoji: '🧠', text: "Your brain needs rest from the feed. Go offline." },
    { emoji: '🎯', text: "You\u2019ve scrolled enough. Time to be productive." },
    { emoji: '🌊', text: "Close the app. Go outside. Feel alive." },
    { emoji: '✨', text: "Every minute you stop scrolling is a win." },
    { emoji: '🔋', text: "Recharge yourself, not just your phone." }
  ];
  var _expiredIdx = 0;

  function buildTimerExpiredCard(article, isFirst) {
    var h = article.offsetHeight;
    var FONT = '-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif';

    // Detect IG background color
    var igBg = '#000';
    try {
      var bodyBg = getComputedStyle(document.body).backgroundColor;
      if (bodyBg && bodyBg !== 'rgba(0, 0, 0, 0)' && bodyBg !== 'transparent') igBg = bodyBg;
    } catch (e) {}

    var endColor = '#b3d9f2'; // light calming blue

    var card = document.createElement('div');
    card.style.cssText = [
      'display:flex', 'flex-direction:column',
      'align-items:center', 'justify-content:center',
      'width:100%', 'height:100%', 'min-height:' + h + 'px',
      'font-family:' + FONT, 'text-align:center',
      'box-sizing:border-box', 'padding:40px 24px',
      'color:#0a1a2a'
    ].join(';');

    if (isFirst) {
      // First card: gradient from IG bg → light blue
      card.style.background = 'linear-gradient(180deg, ' + igBg + ' 0%, ' + endColor + ' 45%, ' + endColor + ' 100%)';
    } else {
      // Subsequent cards: solid light blue
      card.style.background = endColor;
    }

    var msg = EXPIRED_MESSAGES[_expiredIdx % EXPIRED_MESSAGES.length];
    _expiredIdx++;

    var emoji = document.createElement('div');
    emoji.textContent = msg.emoji;
    emoji.style.cssText = 'font-size:52px;line-height:1;margin-bottom:18px';

    var text = document.createElement('div');
    text.textContent = msg.text;
    text.style.cssText = 'font-size:20px;font-weight:700;line-height:1.4;max-width:280px;color:#0a1a2a';

    card.appendChild(emoji);
    card.appendChild(text);
    return card;
  }

  function injectTimerExpiredCard(article) {
    var expired = window.__STOPSCROLL_TIMER_EXPIRED;
    if (!expired) return false;

    var h = article.offsetHeight;
    if (h < 80) return false;

    var isFirst = (expired.remaining === 10);
    var card = buildTimerExpiredCard(article, isFirst);

    article.style.setProperty('min-height', h + 'px', 'important');
    article.style.setProperty('overflow', 'hidden', 'important');
    article.style.setProperty('position', 'relative', 'important');
    article.setAttribute('data-ss-replaced', 'true');
    article.setAttribute('data-ss-expired', 'true');

    hideOriginalContent(article);

    new MutationObserver(function () {
      hideOriginalContent(article);
    }).observe(article, { childList: true, subtree: false });

    var wrapper = document.createElement('div');
    wrapper.setAttribute('data-ss-injection', 'true');
    wrapper.style.cssText = 'position:absolute;inset:0;overflow:hidden';
    wrapper.appendChild(card);
    article.appendChild(wrapper);

    if (expired.remaining > 0) expired.remaining--;
    return true;
  }

  /** Hide all original children of an article (and any future ones). */
  function hideOriginalContent(article) {
    for (var i = 0; i < article.children.length; i++) {
      var child = article.children[i];
      if (child.getAttribute && child.getAttribute('data-ss-injection')) continue;
      child.style.setProperty('display', 'none', 'important');
    }
  }

  function injectCardIntoPost(article, type, config) {
    var h = article.offsetHeight;
    if (h < 80) return false;

    var card = ns.cardBuilder.buildCardFor(type, config);
    if (!card) return false;

    article.style.setProperty('min-height', h + 'px', 'important');
    article.style.setProperty('overflow', 'hidden', 'important');
    article.style.setProperty('position', 'relative', 'important');
    article.setAttribute('data-ss-replaced', 'true');

    hideOriginalContent(article);

    new MutationObserver(function () {
      hideOriginalContent(article);
    }).observe(article, { childList: true, subtree: false });

    var wrapper = document.createElement('div');
    wrapper.setAttribute('data-ss-injection', 'true');
    wrapper.style.cssText = 'position:absolute;inset:0;overflow:hidden';

    wrapper.appendChild(card);
    article.appendChild(wrapper);
    return true;
  }

  ns.cardInjection = {
    injectCardIntoPost: injectCardIntoPost,
    injectTimerExpiredCard: injectTimerExpiredCard
  };
})(window);
