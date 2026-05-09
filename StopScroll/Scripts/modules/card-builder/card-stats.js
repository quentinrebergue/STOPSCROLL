// Stats card builder — attaches to window.StopScroll.cardBuilder.
(function (global) {
  'use strict';

  var ns = (global.StopScroll = global.StopScroll || {});
  var cb = ns.cardBuilder;
  var FONT = cb.FONT;

  function buildStatsCard(config) {
    var stats  = ns.sessionStats ? ns.sessionStats.getStats() : { sessionSeconds: 0, posts: 0, ads: 0 };
    var t      = config.card_templates || {};
    var accent = '#c4b5fd';

    function formatTime(secs) {
      if (secs < 1)  return t.stats_just_started || 'Just started';
      if (secs < 60) return secs + 's';
      var m = Math.floor(secs / 60);
      if (m < 60)    return m + ' min';
      return Math.floor(m / 60) + 'h ' + (m % 60) + 'min';
    }

    var post = document.createElement('div');
    post.style.cssText = [
      'display:flex', 'flex-direction:column', 'width:100%', 'height:100%',
      'background:transparent',
      'font-family:' + FONT, 'box-sizing:border-box', 'overflow:hidden'
    ].join(';');

    var topLine = document.createElement('div');
    topLine.style.cssText = 'width:100%;height:3px;flex-shrink:0;background:linear-gradient(90deg,' + accent + ',rgba(255,255,255,0.15))';
    post.appendChild(topLine);

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
    username.style.cssText = 'font-size:14px;font-weight:700;letter-spacing:0.1px';

    avatarRow.appendChild(avatar);
    avatarRow.appendChild(username);

    var more = document.createElement('div');
    more.textContent = '···';
    more.style.cssText = 'font-size:20px;letter-spacing:3px;line-height:1;opacity:0.45;padding:4px 2px';

    header.appendChild(avatarRow);
    header.appendChild(more);

    var content = document.createElement('div');
    content.style.cssText = [
      'flex:1', 'display:flex', 'flex-direction:column',
      'align-items:center', 'justify-content:center',
      'padding:20px 22px 10px', 'text-align:center', 'gap:16px'
    ].join(';');

    var accentBar = document.createElement('div');
    accentBar.style.cssText = 'width:36px;height:3px;border-radius:2px;background:' + accent;

    var titleEl = document.createElement('div');
    titleEl.textContent = t.stats_title || 'Your session';
    titleEl.style.cssText = 'font-size:19px;font-weight:700;line-height:1.25;letter-spacing:0.1px';

    var grid = document.createElement('div');
    grid.style.cssText = 'display:flex;gap:12px;width:100%;justify-content:center';

    var statItems = [
      { value: formatTime(stats.sessionSeconds), label: t.stats_label_time  || 'scrolling' },
      { value: String(stats.posts),              label: t.stats_label_posts || 'posts seen' },
      { value: String(stats.ads),                label: t.stats_label_ads   || 'ads seen' }
    ];

    statItems.forEach(function (item) {
      var cell = document.createElement('div');
      cell.style.cssText = 'display:flex;flex-direction:column;align-items:center;gap:3px;flex:1;min-width:0';

      var val = document.createElement('div');
      val.textContent = item.value;
      val.style.cssText = 'font-size:24px;font-weight:800;color:' + accent + ';line-height:1';

      var lbl = document.createElement('div');
      lbl.textContent = item.label;
      lbl.style.cssText = 'font-size:11px;line-height:1.3;color:rgba(244,246,250,0.5);letter-spacing:0.3px';

      cell.appendChild(val);
      cell.appendChild(lbl);
      grid.appendChild(cell);
    });

    content.appendChild(accentBar);
    content.appendChild(titleEl);
    content.appendChild(grid);

    var row = document.createElement('div');
    row.style.cssText = 'padding:0 14px 14px';

    var actionBar = document.createElement('div');
    actionBar.style.cssText = 'display:flex;align-items:center;justify-content:space-between;padding:10px 14px 12px;border-top:1px solid rgba(255,255,255,0.07)';

    var leftIcons = document.createElement('div');
    leftIcons.style.cssText = 'display:flex;gap:18px;align-items:center';
    leftIcons.appendChild(cb.makeIconBtn(cb.ICON.heart));
    leftIcons.appendChild(cb.makeIconBtn(cb.ICON.comment));
    leftIcons.appendChild(cb.makeIconBtn(cb.ICON.send));

    actionBar.appendChild(leftIcons);
    actionBar.appendChild(cb.makeIconBtn(cb.ICON.bookmark));

    post.appendChild(header);
    post.appendChild(content);
    post.appendChild(row);
    post.appendChild(actionBar);

    return post;
  }

  cb.buildStatsCard = buildStatsCard;
})(window);
