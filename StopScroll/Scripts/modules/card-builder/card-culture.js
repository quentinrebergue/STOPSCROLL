// Culture card builder — attaches to window.StopScroll.cardBuilder.
(function (global) {
  'use strict';

  var ns = (global.StopScroll = global.StopScroll || {});
  var cb = ns.cardBuilder;
  var FONT = cb.FONT;

  var LABELS = {
    fr: { tag: 'ARTICLE', btn: 'Lire l\u2019article', time: 'min de lecture' },
    en: { tag: 'ARTICLE', btn: 'Read article', time: 'min read' },
    es: { tag: 'ART\u00CDCULO', btn: 'Leer art\u00EDculo', time: 'min lectura' },
    de: { tag: 'ARTIKEL', btn: 'Artikel lesen', time: 'Min. Lesezeit' },
    it: { tag: 'ARTICOLO', btn: 'Leggi articolo', time: 'min lettura' },
    pt: { tag: 'ARTIGO', btn: 'Ler artigo', time: 'min leitura' }
  };

  function labels() {
    var lang = (ns.wikipedia && ns.wikipedia.getLang) ? ns.wikipedia.getLang() : 'en';
    return LABELS[lang] || LABELS.en;
  }

  function estimateReadTime(text) {
    var words = text.split(/\s+/).length;
    return Math.max(1, Math.round(words / 200));
  }

  function buildDebugCultureCard(config, sources, debugLines) {
    var accent = '#ff5722';
    var body = 'Sources: [' + sources.join(', ') + ']\n' + debugLines.join('\n');
    var ui = cb.createCardContainer('[DEV] Culture card failed', body, accent);
    return ui.card;
  }

  function buildCultureCard(config) {
    // Determine which sources are enabled
    var sources = global.__STOPSCROLL_ARTICLE_SOURCES || ['wikipedia'];
    var devMode = !!global.__STOPSCROLL_DEV_MODE;
    var debugLines = [];

    // Collect providers that have a cached article
    var candidates = [];
    for (var s = 0; s < sources.length; s++) {
      var src = sources[s];
      var prov = (src === 'guardian') ? ns.guardian : ns.wikipedia;
      if (!prov) { debugLines.push(src + ': module not loaded'); continue; }
      var a = prov.getCached();
      if (a && a.extract) {
        candidates.push({ source: src, provider: prov, article: a });
      } else {
        debugLines.push(src + ': no cached article');
      }
    }

    if (candidates.length === 0) {
      if (devMode) return buildDebugCultureCard(config, sources, debugLines);
      return null;
    }

    // Pick one at random from available candidates
    var pick = candidates[Math.floor(Math.random() * candidates.length)];
    var provider = pick.provider;
    var article = pick.article;
    var isGuardian = (pick.source === 'guardian');

    // Consume the article immediately so the next culture card gets a fresh one
    provider.consume();

    var l = labels();
    var t = config.card_templates || {};
    var accent = isGuardian ? '#005689' : '#f9a825';
    var sourceLabel = isGuardian ? 'THE GUARDIAN' : null;

    // ── Newspaper-style card ──────────────────────────────────
    var post = document.createElement('div');
    post.setAttribute('data-ss-xp-card', '1');
    post.style.cssText = [
      'display:flex', 'flex-direction:column', 'width:100%', 'height:100%',
      'background:transparent',
      'font-family:' + FONT, 'box-sizing:border-box', 'overflow:hidden'
    ].join(';');

    // Accent gradient top line
    var topLine = document.createElement('div');
    topLine.style.cssText = 'width:100%;height:3px;flex-shrink:0;background:linear-gradient(90deg,' + accent + ',rgba(255,255,255,0.15))';
    post.appendChild(topLine);

    // Header (StopScroll identity)
    var header = document.createElement('div');
    header.setAttribute('data-ss-card-header', '');
    header.style.cssText = 'display:flex;align-items:center;justify-content:space-between;padding:10px 14px;border-bottom:1px solid rgba(255,255,255,0.07)';

    var avatarRow = document.createElement('div');
    avatarRow.style.cssText = 'display:flex;align-items:center;gap:10px';

    var avatar = document.createElement('div');
    avatar.textContent = 'SS';
    avatar.style.cssText = [
      'width:38px', 'height:38px', 'border-radius:50%', 'flex-shrink:0',
      'background:linear-gradient(135deg,#7ad8ff,#a78bfa)',
      'display:flex', 'align-items:center', 'justify-content:center',
      'font-size:13px', 'font-weight:800', 'color:#0a0a12',
      'box-sizing:border-box', 'border:2px solid ' + accent
    ].join(';');

    var username = document.createElement('div');
    username.textContent = 'StopScroll';
    username.setAttribute('data-ss-username', '');
    username.style.cssText = 'font-size:14px;font-weight:700;letter-spacing:0.1px';

    avatarRow.appendChild(avatar);
    avatarRow.appendChild(username);

    var more = document.createElement('div');
    more.textContent = '\u00B7\u00B7\u00B7';
    more.setAttribute('data-ss-more', '');
    more.style.cssText = 'font-size:20px;letter-spacing:3px;line-height:1;opacity:0.45;padding:4px 2px';

    header.appendChild(avatarRow);
    header.appendChild(more);

    // Media area — newspaper layout
    var mediaArea = document.createElement('div');
    mediaArea.setAttribute('data-ss-media', '');
    mediaArea.style.cssText = 'flex:1;display:flex;flex-direction:column;overflow:hidden;color:#f4f6fa;padding:16px 18px 8px';

    // Category tag (like a newspaper section)
    var desc = article.description || '';
    var tagText = sourceLabel || (desc.length > 0 && desc.length < 40 ? desc.toUpperCase() : l.tag);
    var tag = document.createElement('div');
    tag.textContent = tagText;
    tag.style.cssText = [
      'display:inline-block', 'padding:4px 10px', 'border-radius:999px',
      'background:rgba(255,255,255,0.08)', 'border:1px solid rgba(255,255,255,0.15)',
      'font-size:11px', 'font-weight:700', 'letter-spacing:0.5px',
      'color:' + accent, 'text-transform:uppercase', 'margin-bottom:12px',
      'align-self:flex-start'
    ].join(';');

    // Headline
    var headline = document.createElement('div');
    headline.textContent = article.title;
    headline.style.cssText = [
      'font-size:22px', 'font-weight:800', 'line-height:1.2',
      'letter-spacing:-0.4px', 'color:#ffffff', 'margin-bottom:10px'
    ].join(';');

    // Lead paragraph — editorial snippet
    var snippet = article.extract.length > 220
      ? article.extract.substring(0, 220).replace(/\s+\S*$/, '') + '\u2026'
      : article.extract;
    var lead = document.createElement('div');
    lead.textContent = snippet;
    lead.style.cssText = [
      'font-size:14px', 'line-height:1.55', 'color:rgba(244,246,250,0.82)',
      'flex:1'
    ].join(';');

    // Footer meta — read time
    var readMin = estimateReadTime(article.extract);
    var meta = document.createElement('div');
    meta.style.cssText = 'display:flex;align-items:center;justify-content:space-between;padding:8px 0 4px;gap:8px';

    var timeTag = document.createElement('span');
    timeTag.textContent = '\u231A ' + readMin + ' ' + l.time;
    timeTag.style.cssText = 'font-size:11px;color:rgba(244,246,250,0.45);letter-spacing:0.3px';

    var srcBadge = document.createElement('span');
    srcBadge.textContent = isGuardian ? 'The Guardian' : 'Wikipedia';
    srcBadge.style.cssText = 'font-size:10px;font-weight:700;color:rgba(244,246,250,0.35);letter-spacing:0.5px;text-transform:uppercase';

    meta.appendChild(timeTag);
    meta.appendChild(srcBadge);

    mediaArea.appendChild(tag);
    mediaArea.appendChild(headline);
    mediaArea.appendChild(lead);

    // Button inside the media area — full width
    var btnWrap = document.createElement('div');
    btnWrap.style.cssText = 'display:flex;justify-content:center;padding:12px 0 6px';
    btnWrap.appendChild(cb.makeButton(t.culture_btn || l.btn, accent, function () {
      if (isGuardian && article.webUrl) {
        ns.dom.postToBridge({
          type: 'openGuardianArticle',
          url: article.webUrl,
          title: article.title
        });
      } else {
        ns.dom.postToBridge({
          type: 'openArticle',
          title: article.title,
          lang: article.lang || 'en'
        });
      }
    }));
    mediaArea.appendChild(btnWrap);

    mediaArea.appendChild(meta);

    // Action bar
    var actionBar = document.createElement('div');
    actionBar.setAttribute('data-ss-actionbar', '');
    actionBar.style.cssText = 'display:flex;align-items:center;justify-content:space-between;padding:10px 14px 12px;border-top:1px solid rgba(255,255,255,0.07)';
    var leftIcons = document.createElement('div');
    leftIcons.style.cssText = 'display:flex;gap:18px;align-items:center';
    leftIcons.appendChild(cb.makeIconBtn(cb.ICON.heart));
    leftIcons.appendChild(cb.makeIconBtn(cb.ICON.comment));
    leftIcons.appendChild(cb.makeIconBtn(cb.ICON.send));
    actionBar.appendChild(leftIcons);
    actionBar.appendChild(cb.makeIconBtn(cb.ICON.bookmark));

    post.appendChild(header);
    post.appendChild(mediaArea);
    post.appendChild(actionBar);

    return post;
  }

  cb.buildCultureCard = buildCultureCard;
})(window);
