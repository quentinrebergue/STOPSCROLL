// Shared card-builder helpers exposed via window.StopScroll.cardBuilder.
(function (global) {
  'use strict';

  var ns = (global.StopScroll = global.StopScroll || {});
  var cb = (ns.cardBuilder = ns.cardBuilder || {});

  var FONT = '-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif';

  var ICON = {
    heart:    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" width="22" height="22"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/></svg>',
    comment:  '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" width="22" height="22"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>',
    send:     '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" width="22" height="22"><line x1="22" y1="2" x2="11" y2="13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/></svg>',
    bookmark: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" width="22" height="22"><path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z"/></svg>'
  };

  function claimCardXP(originEl, amount, source) {
    if (!(ns.dom && ns.dom.postToBridge)) return false;

    var cardEl = originEl && originEl.closest
      ? originEl.closest('[data-ss-xp-card]')
      : null;

    if (!cardEl) {
      ns.dom.postToBridge({ type: 'grantXP', amount: amount || 12, source: source || 'card_button' });
      return true;
    }

    if (cardEl.getAttribute('data-ss-xp-claimed') === '1') {
      return false;
    }

    cardEl.setAttribute('data-ss-xp-claimed', '1');
    ns.dom.postToBridge({ type: 'grantXP', amount: amount || 12, source: source || 'card_button' });
    return true;
  }

  function makeButton(label, background, handler) {
    var btn = document.createElement('button');
    btn.type = 'button';
    btn.textContent = label;
    // Start grey; real color applied on scroll-into-view via IntersectionObserver
    btn.setAttribute('data-ss-btn-color', background);
    btn.style.cssText = [
      'appearance:none', 'border:none', 'border-radius:999px',
      'padding:12px 26px', 'font-size:14px', 'font-weight:700',
      'cursor:pointer', 'color:#0a0a12', 'background:#8e8e93',
      'font-family:' + FONT, 'flex-shrink:0', 'white-space:nowrap',
      'transition:transform 0.12s ease,filter 0.12s ease,background 0.6s ease',
      'transform:scale(1)',
      'filter:brightness(1)'
    ].join(';');
    btn.addEventListener('pointerdown', function () { btn.style.transform = 'scale(0.95)'; btn.style.filter = 'brightness(0.92)'; });
    btn.addEventListener('pointerup',   function () { btn.style.transform = 'scale(1)'; btn.style.filter = 'brightness(1)'; });
    btn.addEventListener('pointerleave',function () { btn.style.transform = 'scale(1)'; btn.style.filter = 'brightness(1)'; });
    btn.addEventListener('click', function (event) {
      event.preventDefault();
      event.stopPropagation();
      claimCardXP(btn, 12, 'card_button');
      handler(event);
    });
    return btn;
  }

  function makeIconBtn(svgHtml) {
    var btn = document.createElement('button');
    btn.type = 'button';
    btn.innerHTML = svgHtml;
    btn.style.cssText = 'appearance:none;border:none;background:none;padding:0;cursor:pointer;color:#f4f6fa;display:flex;align-items:center;line-height:1';
    return btn;
  }

  function createCardContainer(title, body, accent) {
    var post = document.createElement('div');
    post.setAttribute('data-ss-xp-card', '1');
    post.style.cssText = [
      'display:flex', 'flex-direction:column', 'width:100%', 'height:100%',
      'background:#1a1a22', 'color:#f4f6fa',
      'font-family:' + FONT, 'box-sizing:border-box', 'overflow:hidden'
    ].join(';');

    var header = document.createElement('div');
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
      'box-sizing:border-box',
      'border:2px solid ' + accent
    ].join(';');

    var username = document.createElement('div');
    username.textContent = 'StopScroll';
    username.setAttribute('data-ss-username', '');
    username.style.cssText = 'font-size:14px;font-weight:700;letter-spacing:0.1px';

    avatarRow.appendChild(avatar);
    avatarRow.appendChild(username);

    var more = document.createElement('div');
    more.textContent = '···';
    more.setAttribute('data-ss-more', '');
    more.style.cssText = 'font-size:20px;letter-spacing:3px;line-height:1;color:rgba(244,246,250,0.45);padding:4px 2px';

    header.appendChild(avatarRow);
    header.appendChild(more);

    var content = document.createElement('div');
    content.style.cssText = [
      'flex:1', 'display:flex', 'flex-direction:column',
      'align-items:center', 'justify-content:center',
      'padding:20px 22px 10px', 'text-align:center', 'gap:12px'
    ].join(';');

    var accentBar = document.createElement('div');
    accentBar.style.cssText = 'width:36px;height:3px;border-radius:2px;background:' + accent;

    var titleEl = document.createElement('div');
    titleEl.textContent = title;
    titleEl.style.cssText = 'font-size:19px;font-weight:700;line-height:1.25;letter-spacing:0.1px';

    var bodyEl = document.createElement('div');
    bodyEl.textContent = body;
    bodyEl.style.cssText = 'font-size:14px;line-height:1.55;color:rgba(244,246,250,0.78);max-width:300px';

    content.appendChild(accentBar);
    content.appendChild(titleEl);
    content.appendChild(bodyEl);

    var row = document.createElement('div');
    row.style.cssText = 'display:flex;gap:10px;flex-wrap:wrap;justify-content:center;padding:10px 14px 14px';

    var actionBar = document.createElement('div');
    actionBar.setAttribute('data-ss-actionbar', '');
    actionBar.style.cssText = 'display:flex;align-items:center;justify-content:space-between;padding:10px 14px 12px;border-top:1px solid rgba(255,255,255,0.07)';

    var leftIcons = document.createElement('div');
    leftIcons.style.cssText = 'display:flex;gap:18px;align-items:center';
    leftIcons.appendChild(makeIconBtn(ICON.heart));
    leftIcons.appendChild(makeIconBtn(ICON.comment));
    leftIcons.appendChild(makeIconBtn(ICON.send));

    actionBar.appendChild(leftIcons);
    actionBar.appendChild(makeIconBtn(ICON.bookmark));

    var mediaArea = document.createElement('div');
    mediaArea.setAttribute('data-ss-media', '');
    mediaArea.style.cssText = 'flex:1;display:flex;flex-direction:column;background:#1a1a22;overflow:hidden;color:#f4f6fa';
    mediaArea.appendChild(content);
    mediaArea.appendChild(row);

    post.appendChild(header);
    post.appendChild(mediaArea);
    post.appendChild(actionBar);

    return { card: post, row: row };
  }

  // ── Dopamine particle burst ──────────────────────────────────
  var DOPAMINE_STYLE_ID = 'ss-dopamine-style';
  var DOPAMINE_COLORS = ['#ffd37a','#ff9f7a','#ff7aab','#a78bfa','#7ad8ff','#90ff9f'];

  function ensureDopamineStyle() {
    if (document.getElementById(DOPAMINE_STYLE_ID)) return;
    var s = document.createElement('style');
    s.id = DOPAMINE_STYLE_ID;
    s.textContent = [
      '@keyframes ss-pop{',
      '  0%  {transform:translate(0,0) scale(1.2);opacity:1}',
      '  60% {opacity:0.7}',
      '  100%{transform:translate(var(--tx),var(--ty)) scale(0);opacity:0}',
      '}',
      '@keyframes ss-ripple{',
      '  0%  {transform:scale(1);opacity:0.55}',
      '  100%{transform:scale(3.5);opacity:0}',
      '}'
    ].join('');
    document.head.appendChild(s);
  }

  function burstParticles(originEl) {
    ensureDopamineStyle();
    var rect   = originEl.getBoundingClientRect();
    var cx     = rect.left + rect.width  / 2;
    var cy     = rect.top  + rect.height / 2;
    var count  = 10;

    var ring = document.createElement('div');
    ring.style.cssText = [
      'position:fixed',
      'left:'  + (cx - rect.width  / 2) + 'px',
      'top:'   + (cy - rect.height / 2) + 'px',
      'width:'  + rect.width  + 'px',
      'height:' + rect.height + 'px',
      'border-radius:999px',
      'border:2px solid #ffd37a',
      'pointer-events:none',
      'z-index:99999',
      'animation:ss-ripple 0.5s ease-out forwards'
    ].join(';');
    document.body.appendChild(ring);
    setTimeout(function () { ring.parentNode && ring.parentNode.removeChild(ring); }, 550);

    for (var i = 0; i < count; i++) {
      (function (idx) {
        var angle    = (2 * Math.PI / count) * idx - Math.PI / 2;
        var dist     = 40 + Math.random() * 30;
        var size     = 6 + Math.random() * 5;
        var color    = DOPAMINE_COLORS[idx % DOPAMINE_COLORS.length];
        var delay    = Math.random() * 80;
        var dot      = document.createElement('div');
        dot.style.cssText = [
          'position:fixed',
          'left:' + (cx - size / 2)     + 'px',
          'top:'  + (cy - size / 2)     + 'px',
          'width:'  + size              + 'px',
          'height:' + size              + 'px',
          'border-radius:50%',
          'background:' + color,
          'pointer-events:none',
          'z-index:99999',
          '--tx:' + (Math.cos(angle) * dist) + 'px',
          '--ty:' + (Math.sin(angle) * dist) + 'px',
          'animation:ss-pop 0.6s ' + delay + 'ms ease-out forwards'
        ].join(';');
        document.body.appendChild(dot);
        setTimeout(function () { dot.parentNode && dot.parentNode.removeChild(dot); }, 700 + delay);
      })(i);
    }
  }

  // Expose shared helpers
  cb.FONT = FONT;
  cb.ICON = ICON;
  cb.makeButton = makeButton;
  cb.makeIconBtn = makeIconBtn;
  cb.createCardContainer = createCardContainer;
  cb.claimCardXP = claimCardXP;
  cb.burstParticles = burstParticles;
})(window);
