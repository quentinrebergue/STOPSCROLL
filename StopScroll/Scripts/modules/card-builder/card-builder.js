// Card builder index — buildCardFor, captions, gradient, Instagram color detection.
// Depends on card-builder-helpers, card-metrics, card-mood, card-timer, card-stop, card-stats.
(function (global) {
  'use strict';

  var ns = (global.StopScroll = global.StopScroll || {});
  var cb = ns.cardBuilder;
  var FONT = cb.FONT;

  // ── Instagram color detection (cached) ─────────────────────
  var _igColors = null;

  function detectInstagramColors() {
    if (_igColors) return _igColors;
    _igColors = { bg: '#000', text: '#f5f5f5' };
    try {
      var articles = document.querySelectorAll('article:not([data-ss-replaced])');
      for (var i = 0; i < articles.length; i++) {
        var art = articles[i];
        var bg = getComputedStyle(art).backgroundColor;
        if (bg && bg !== 'rgba(0, 0, 0, 0)' && bg !== 'transparent') {
          _igColors.bg = bg;
        }
        var hdr = art.querySelector('header');
        if (hdr) {
          var spans = hdr.querySelectorAll('span, a');
          for (var j = 0; j < spans.length; j++) {
            if (spans[j].textContent && spans[j].textContent.trim().length > 0) {
              _igColors.text = getComputedStyle(spans[j]).color;
              break;
            }
          }
        }
        break; // one article is enough
      }
      // Fallback: check body background
      if (_igColors.bg === '#000') {
        var bodyBg = getComputedStyle(document.body).backgroundColor;
        if (bodyBg && bodyBg !== 'rgba(0, 0, 0, 0)' && bodyBg !== 'transparent') {
          _igColors.bg = bodyBg;
        }
      }
    } catch (e) {}
    return _igColors;
  }

  // ── Captions ───────────────────────────────────────────────
  function pickCaption(config) {
    var list = config.captions;
    if (!Array.isArray(list) || list.length === 0) return null;
    return list[Math.floor(Math.random() * list.length)];
  }

  function appendCaption(card, config, colors) {
    var text = pickCaption(config);
    if (!text) return;
    var caption = document.createElement('div');
    caption.style.cssText = 'padding:4px 14px 12px;font-size:13px;line-height:1.45;color:' + colors.text + ';font-family:' + FONT;
    var bold = document.createElement('span');
    bold.textContent = 'StopScroll ';
    bold.style.cssText = 'font-weight:700';
    caption.appendChild(bold);
    caption.appendChild(document.createTextNode(text));
    card.appendChild(caption);
  }

  // ── Gradient (only on media area) ──────────────────────────
  var CARD_ACCENTS = {
    metrics: '#7ad8ff',
    mood:    '#ffd37a',
    timer:   '#ffd37a',
    stop:    '#ffd37a',
    stats:   '#c4b5fd',
    book:    '#90eeb0',
    culture: '#f9a825'
  };

  /**
   * Ensure the card has a [data-ss-media] wrapper around the content
   * (everything between the first child = header and last child = actionBar).
   * Cards built by createCardContainer already have one; the others get one now.
   */
  function ensureMediaArea(card) {
    var media = card.querySelector('[data-ss-media]');
    if (media) {
      media.style.flex = '1';
      media.style.display = 'flex';
      media.style.flexDirection = 'column';
      return media;
    }
    var children = Array.prototype.slice.call(card.children);
    if (children.length < 3) return null;
    // Everything from index 1 to length-2 is "media content"
    var toMove = children.slice(1, children.length - 1);
    media = document.createElement('div');
    media.setAttribute('data-ss-media', '');
    media.style.cssText = 'flex:1;display:flex;flex-direction:column;overflow:hidden;color:inherit';
    card.insertBefore(media, toMove[0]);
    for (var i = 0; i < toMove.length; i++) media.appendChild(toMove[i]);
    return media;
  }

  // ── Animated gradient style (injected once) ─────────────
  var GRADIENT_STYLE_ID = 'ss-gradient-anim';
  function ensureGradientStyle() {
    if (document.getElementById(GRADIENT_STYLE_ID)) return;
    var s = document.createElement('style');
    s.id = GRADIENT_STYLE_ID;
    s.textContent = [
      '@keyframes ss-grad-shift{',
      '  0%{background-position:0% 50%}',
      '  50%{background-position:100% 50%}',
      '  100%{background-position:0% 50%}',
      '}'
    ].join('');
    document.head.appendChild(s);
  }

  function applyGradientBg(card, type) {
    ensureGradientStyle();
    var accent = CARD_ACCENTS[type] || '#7ad8ff';
    var media = ensureMediaArea(card);
    if (!media) return;

    // Soft gradients — close tones for readability, full opacity
    var GRAD_MAP = {
      metrics: 'linear-gradient(135deg, #0d2d4d, #123d5e, #1a5580, #1f6694, #123d5e)',
      mood:    'linear-gradient(135deg, #3d2b10, #5a3e1a, #7a5528, #8c6430, #5a3e1a)',
      timer:   'linear-gradient(135deg, #3d2b10, #6b4e2a, #8a6838, #9a7845, #6b4e2a)',
      stop:    'linear-gradient(135deg, #3a1010, #551a1a, #6e2222, #802a2a, #551a1a)',
      stats:   'linear-gradient(135deg, #1a1040, #2a1a5a, #3d2d78, #4a3888, #2a1a5a)',
      book:    'linear-gradient(135deg, #0a2a1e, #14402e, #1e5a40, #266a4e, #14402e)',
      culture: 'linear-gradient(135deg, #3a2010, #553518, #704820, #885628, #553518)'
    };

    media.style.background = GRAD_MAP[type] || ('linear-gradient(135deg, #1a1a22, ' + accent + '60, #1a1a22)');
    media.style.backgroundSize = '200% 200%';
    media.style.animation = 'ss-grad-shift 10s ease infinite';
    media.style.position = 'relative';

    // ── Glassmorphism overlay with subtle noise texture ──────
    var glass = document.createElement('div');
    glass.style.cssText = [
      'position:absolute', 'inset:0', 'z-index:0',
      'background:rgba(255,255,255,0.06)',
      'backdrop-filter:blur(18px) saturate(1.3)',
      '-webkit-backdrop-filter:blur(18px) saturate(1.3)',
      'pointer-events:none'
    ].join(';');

    // Noise texture via tiny inline SVG data-URI (no extra request)
    var noise = document.createElement('div');
    noise.style.cssText = [
      'position:absolute', 'inset:0', 'z-index:0',
      'opacity:0.045', 'pointer-events:none', 'mix-blend-mode:overlay',
      'background-image:url("data:image/svg+xml,%3Csvg xmlns=\'http://www.w3.org/2000/svg\' width=\'200\' height=\'200\'%3E%3Cfilter id=\'n\'%3E%3CfeTurbulence type=\'fractalNoise\' baseFrequency=\'0.9\' numOctaves=\'4\' stitchTiles=\'stitch\'/%3E%3C/filter%3E%3Crect width=\'100%25\' height=\'100%25\' filter=\'url(%23n)\'/%3E%3C/svg%3E")',
      'background-size:200px 200px'
    ].join(';');

    media.insertBefore(noise, media.firstChild);
    media.insertBefore(glass, media.firstChild);

    // Make sure actual content sits above the glass
    for (var ci = 0; ci < media.children.length; ci++) {
      var ch = media.children[ci];
      if (ch !== glass && ch !== noise) {
        ch.style.position = 'relative';
        ch.style.zIndex = '1';
      }
    }
  }

  // ── Apply native Instagram colors to non-media sections ───
  function applyNativeColors(card, colors) {
    // Outer card background (header + caption area)
    card.style.background = colors.bg;
    card.style.color = colors.text;
    // Header: first child
    var header = card.children[0];
    if (header) {
      var divs = header.querySelectorAll('div');
      for (var i = 0; i < divs.length; i++) {
        var d = divs[i];
        // Skip avatar (has border-radius:50%)
        if (d.style.borderRadius === '50%') continue;
        d.style.color = colors.text;
      }
    }
    // Action bar: last child
    var actionBar = card.children[card.children.length - 1];
    if (actionBar) {
      var btns = actionBar.querySelectorAll('button');
      for (var j = 0; j < btns.length; j++) btns[j].style.color = colors.text;
    }
  }

  // ── Button scroll-reveal animation ──────────────────────────
  function revealButtons(el) {
    var btns = el.querySelectorAll('[data-ss-btn-color]');
    for (var b = 0; b < btns.length; b++) {
      btns[b].style.background = btns[b].getAttribute('data-ss-btn-color');
    }
  }

  // Inject glass-in keyframes once so mood/timer buttons can use them.
  function ensureGlassStyles() {
    if (document.getElementById('ss-glass-kf')) return;
    var s = document.createElement('style');
    s.id = 'ss-glass-kf';
    s.textContent = '@keyframes ss-glass-in{' +
      '0%{background:rgba(255,255,255,.05);border-color:rgba(255,255,255,.12)}' +
      '50%{background:rgba(255,255,255,.26);border-color:rgba(255,255,255,.38)}' +
      '100%{background:rgba(255,255,255,.16);border-color:rgba(255,255,255,.28)}' +
    '}';
    (document.head || document.documentElement).appendChild(s);
  }

  function revealGlassButtons(el) {
    ensureGlassStyles();
    var btns = el.querySelectorAll('[data-ss-glass-btn]');
    for (var b = 0; b < btns.length; b++) {
      (function (btn, idx) {
        setTimeout(function () {
          btn.style.animation = 'ss-glass-in 0.65s ease-out forwards';
        }, idx * 90);
      })(btns[b], b);
    }
  }

  function observeButtonReveal(card) {
    if (!('IntersectionObserver' in window)) {
      setTimeout(function () { revealButtons(card); revealGlassButtons(card); }, 400);
      return;
    }
    // threshold: 0.85 → card must be 85 % visible before reveal fires,
    // ensuring the user sees the grey state before the colour animation.
    var revealed = false;
    var obs = new IntersectionObserver(function (entries) {
      if (revealed || !entries[0].isIntersecting) return;
      revealed = true;
      obs.disconnect();
      (function (el) {
        setTimeout(function () { revealButtons(el); revealGlassButtons(el); }, 400);
      })(card);
    }, { threshold: 0.85 });
    obs.observe(card);
  }

  // ── Entry point ────────────────────────────────────────────
  function buildCardFor(type, config) {
    var card = null;
    if (type === 'metrics') card = cb.buildMetricsCard(config);
    if (type === 'mood')    card = cb.buildMoodCard(config);
    if (type === 'timer')   card = cb.buildTimerCard(config);
    if (type === 'stop')    card = cb.buildStopCard(config);
    if (type === 'stats')   card = cb.buildStatsCard(config);
    if (type === 'book')    card = cb.buildBookCard(config);
    if (type === 'culture') card = cb.buildCultureCard(config);
    if (card) {
      var colors = detectInstagramColors();
      applyGradientBg(card, type);
      applyNativeColors(card, colors);
      appendCaption(card, config, colors);
      observeButtonReveal(card);
    }
    return card;
  }

  cb.buildCardFor = buildCardFor;
})(window);
