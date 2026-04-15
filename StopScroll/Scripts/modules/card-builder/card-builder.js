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
    stats:   '#c4b5fd'
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

  function applyGradientBg(card, type) {
    var accent = CARD_ACCENTS[type] || '#7ad8ff';
    var media = ensureMediaArea(card);
    if (!media) return;
    media.style.background = [
      'radial-gradient(ellipse at 50% 35%, ' + accent + '40 0%, ' + accent + '15 45%, transparent 70%)',
      'radial-gradient(ellipse at 20% 90%, ' + accent + '20 0%, transparent 45%)',
      '#111116'
    ].join(',');
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

  // ── Entry point ────────────────────────────────────────────
  function buildCardFor(type, config) {
    var card = null;
    if (type === 'metrics') card = cb.buildMetricsCard(config);
    if (type === 'mood')    card = cb.buildMoodCard(config);
    if (type === 'timer')   card = cb.buildTimerCard(config);
    if (type === 'stop')    card = cb.buildStopCard(config);
    if (type === 'stats')   card = cb.buildStatsCard(config);
    if (card) {
      var colors = detectInstagramColors();
      applyGradientBg(card, type);
      applyNativeColors(card, colors);
      appendCaption(card, config, colors);
    }
    return card;
  }

  cb.buildCardFor = buildCardFor;
})(window);
