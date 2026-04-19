// Card injection into ad posts exposed via window.StopScroll.cardInjection.
(function (global) {
  'use strict';

  var ns = (global.StopScroll = global.StopScroll || {});
  var _cardCacheByPostKey = Object.create(null);
  var _cardTypeByPostKey = Object.create(null);
  var _fallbackKeySeq = 0;

  function logInjectionDebug(message, payload) {
    try {
      if (ns.dom && ns.dom.postToBridge) {
        ns.dom.postToBridge({
          type: 'debugLog',
          category: 'CardInjection',
          level: 'DEBUG',
          message: '[CardInjection] ' + message + ' ' + JSON.stringify(payload || {})
        });
      }
    } catch (_) {}
  }

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

  function normalizePath(path) {
    if (!path) return '';
    return path.endsWith('/') ? path : path + '/';
  }

  function buildStablePostKey(snapshot) {
    if (!snapshot) return '';
    if (snapshot.permalink) return normalizePath(snapshot.permalink);
    if (snapshot.mediaKey) return snapshot.mediaKey;
    if (snapshot.headerHref || snapshot.previewText) {
      return (snapshot.headerHref || '') + '::' + (snapshot.previewText || '');
    }
    return '';
  }

  function snapshotArticleIdentity(article) {
    var snapshot = {
      permalink: '',
      mediaKey: '',
      headerHref: '',
      previewText: ''
    };

    var anchors = article.querySelectorAll('a[href]');
    for (var i = 0; i < anchors.length; i++) {
      var href = anchors[i].getAttribute('href') || '';
      var match = href.match(/\/(p|reel|reels)\/[^/?#]+\/?/i);
      if (match) {
        snapshot.permalink = match[0];
        break;
      }
    }

    var media = article.querySelector('img[src], img[currentSrc], video[src], video[poster]');
    if (media) {
      snapshot.mediaKey = media.currentSrc || media.getAttribute('src') || media.getAttribute('poster') || '';
    }

    var headerLink = article.querySelector('header a[href]');
    snapshot.headerHref = headerLink ? (headerLink.getAttribute('href') || '') : '';
    snapshot.previewText = (article.textContent || '').trim().replace(/\s+/g, ' ').slice(0, 80);
    return snapshot;
  }

  function rememberCardType(postKey, type) {
    if (!postKey || !type) return;
    _cardTypeByPostKey[postKey] = type;
  }

  function resolveEffectiveCardType(postKey, requestedType) {
    return postKey ? (_cardTypeByPostKey[postKey] || requestedType) : requestedType;
  }

  function shouldReuseCachedCard(cachedCard, targetArticle) {
    if (!cachedCard) return false;
    if (!cachedCard.isConnected) return true;
    if (!targetArticle) return false;
    var owner = null;
    try {
      owner = cachedCard.closest ? cachedCard.closest('article') : null;
    } catch (_) {
      owner = null;
    }
    if (!owner) return true;
    return owner === targetArticle;
  }

  function needsInjectionRepair(wrapper) {
    if (!wrapper) return true;
    return !wrapper.firstElementChild;
  }

  function getPostKey(article) {
    if (!article) return '';

    var existing = article.getAttribute('data-ss-post-key');
    if (existing) return existing;

    var stableKey = buildStablePostKey(snapshotArticleIdentity(article));
    if (stableKey) {
      article.setAttribute('data-ss-post-key', stableKey);
      return stableKey;
    }

    var fallbackKey = 'fallback-post-' + (++_fallbackKeySeq);
    article.setAttribute('data-ss-post-key', fallbackKey);
    return fallbackKey;
  }

  function prepareCardForReuse(card, height, type, postKey) {
    if (!card) return;
    card.setAttribute('data-ss-card-type', type || card.getAttribute('data-ss-card-type') || 'unknown');
    if (postKey) card.setAttribute('data-ss-post-key', postKey);
    card.style.minHeight = height + 'px';
    card.style.height = '100%';
  }

  function attachCardToArticle(article, card, type, postKey) {
    var h = article.offsetHeight;
    prepareCardForReuse(card, h, type, postKey);

    article.style.setProperty('min-height', h + 'px', 'important');
    article.style.setProperty('overflow', 'hidden', 'important');
    article.style.setProperty('position', 'relative', 'important');
    article.setAttribute('data-ss-replaced', 'true');
    article.setAttribute('data-ss-card-type', type || card.getAttribute('data-ss-card-type') || 'unknown');
    if (postKey) article.setAttribute('data-ss-post-key', postKey);

    hideOriginalContent(article);

    new MutationObserver(function () {
      hideOriginalContent(article);
    }).observe(article, { childList: true, subtree: false });

    var oldWrapper = article.querySelector('[data-ss-injection]');
    if (oldWrapper) oldWrapper.remove();

    var wrapper = document.createElement('div');
    wrapper.setAttribute('data-ss-injection', 'true');
    wrapper.style.cssText = 'position:absolute;inset:0;overflow:hidden';
    wrapper.appendChild(card);
    article.appendChild(wrapper);
    return true;
  }

  function injectCardIntoPost(article, type, config) {
    var h = article.offsetHeight;
    if (h < 80) return false;

    var postKey = getPostKey(article);
    var cachedCard = postKey ? _cardCacheByPostKey[postKey] : null;
    var effectiveType = resolveEffectiveCardType(postKey, type);

    var canReuseCached = shouldReuseCachedCard(cachedCard, article);
    var card = canReuseCached ? cachedCard : null;
    if (!card && cachedCard && cachedCard.isConnected) {
      logInjectionDebug('cached_card_connected_elsewhere', {
        postKey: postKey,
        type: effectiveType
      });
    }
    if (!card) {
      card = ns.cardBuilder.buildCardFor(effectiveType, config);
    }
    if (!card) return false;

    if (postKey) {
      _cardCacheByPostKey[postKey] = card;
      rememberCardType(postKey, effectiveType);
    }

    return attachCardToArticle(article, card, effectiveType, postKey);
  }

  function repairBrokenInjections(config) {
    var replacedPosts = document.querySelectorAll('article[data-ss-replaced="true"]');
    var repaired = 0;

    for (var i = 0; i < replacedPosts.length; i++) {
      var article = replacedPosts[i];
      var wrapper = article.querySelector('[data-ss-injection]');
      if (!needsInjectionRepair(wrapper)) continue;

      var postKey = getPostKey(article);
      var type = article.getAttribute('data-ss-card-type') || resolveEffectiveCardType(postKey, 'stop');
      if (!type) continue;

      var card = ns.cardBuilder && ns.cardBuilder.buildCardFor ? ns.cardBuilder.buildCardFor(type, config || { captions: [] }) : null;
      if (!card) continue;

      attachCardToArticle(article, card, type, postKey);
      repaired += 1;
      logInjectionDebug('repaired_empty_injection_wrapper', {
        postKey: postKey,
        type: type
      });
    }

    return repaired;
  }

  ns.cardInjection = {
    buildStablePostKey: buildStablePostKey,
    getPostKey: getPostKey,
    rememberCardType: rememberCardType,
    resolveEffectiveCardType: resolveEffectiveCardType,
    shouldReuseCachedCard: shouldReuseCachedCard,
    needsInjectionRepair: needsInjectionRepair,
    hasCachedCard: function (postKey) { return !!(postKey && _cardCacheByPostKey[postKey]); },
    getCachedCardType: function (postKey) { return postKey ? (_cardTypeByPostKey[postKey] || null) : null; },
    injectCardIntoPost: injectCardIntoPost,
    repairBrokenInjections: repairBrokenInjections,
    injectTimerExpiredCard: injectTimerExpiredCard
  };
})(window);
