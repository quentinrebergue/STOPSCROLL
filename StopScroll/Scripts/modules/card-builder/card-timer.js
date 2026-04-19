// Timer card builder — attaches to window.StopScroll.cardBuilder.
(function (global) {
  'use strict';

  var ns = (global.StopScroll = global.StopScroll || {});
  var cb = ns.cardBuilder;
  var FONT = cb.FONT;
  var postToBridge = ns.dom.postToBridge;

  function buildTimerCard(config) {
    var t = config.card_templates || {};
    var now = new Date();
    var accent = '#ffd37a';

    function hhmm(date) {
      return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    }
    function minutesFrom(date) {
      return Math.round((date.getTime() - now.getTime()) / 60000);
    }

    // ── Compute the 4 time options ────────────────────────────
    var tens = [];
    var base = new Date(now.getTime());
    base.setSeconds(0, 0);
    var curMin = base.getMinutes();
    var nextTenMin = Math.ceil((curMin + 1) / 10) * 10;
    for (var i = 0; i < 6; i++) {
      var d = new Date(base.getTime());
      var target = nextTenMin + i * 10;
      d.setHours(base.getHours() + Math.floor(target / 60), target % 60, 0, 0);
      tens.push(d);
    }

    var halfIdx = -1, fullIdx = -1;
    for (var j = 0; j < tens.length; j++) {
      var m = tens[j].getMinutes();
      if (halfIdx === -1 && m === 30) halfIdx = j;
      if (fullIdx === -1 && m === 0)  fullIdx = j;
    }

    var picks;
    if (halfIdx === 0 || fullIdx === 0) {
      var mark = tens[0];
      var plusTen = tens[1];
      var other = (halfIdx === 0 && fullIdx !== -1) ? tens[fullIdx]
                : (fullIdx === 0 && halfIdx !== -1) ? tens[halfIdx]
                : tens[2];
      var plusHour = new Date(mark.getTime() + 60 * 60000);
      picks = [mark, plusTen, other, plusHour];
    } else if (halfIdx === 1 || fullIdx === 1) {
      var mark2 = tens[1];
      picks = [tens[0], mark2, tens[2], new Date(mark2.getTime() + 60 * 60000)];
    } else {
      picks = [tens[0], tens[1]];
      if (halfIdx !== -1) picks.push(tens[halfIdx]);
      if (fullIdx !== -1) picks.push(tens[fullIdx]);
    }

    var usedTimes = {};
    picks = picks.filter(function (p) {
      if (!p) return false;
      var k = p.getTime();
      if (usedTimes[k]) return false;
      usedTimes[k] = true;
      return true;
    });
    var fi = 0;
    while (picks.length < 4 && fi < tens.length) {
      if (!usedTimes[tens[fi].getTime()]) {
        picks.push(tens[fi]);
        usedTimes[tens[fi].getTime()] = true;
      }
      fi++;
    }
    picks.sort(function (a, b) { return a.getTime() - b.getTime(); });

    var activeTimer = window.__STOPSCROLL_TIMER || null;
    var timerRunning = activeTimer && activeTimer.end > Date.now();

    var post = document.createElement('div');
    post.setAttribute('data-ss-xp-card', '1');
    post.style.cssText = [
      'display:flex', 'flex-direction:column', 'width:100%', 'height:100%',
      'background:#1a1a22',
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
      'padding:16px 16px 8px', 'gap:10px', 'overflow:hidden'
    ].join(';');

    var accentBar = document.createElement('div');
    accentBar.style.cssText = 'width:36px;height:3px;border-radius:2px;background:' + accent + ';align-self:center';

    var titleEl = document.createElement('div');
    titleEl.style.cssText = 'font-size:18px;font-weight:700;line-height:1.3;text-align:center;padding-bottom:4px';

    var optionsView = document.createElement('div');
    optionsView.style.cssText = 'display:flex;flex-direction:column;gap:8px;flex:1;justify-content:center';

    var resultView = document.createElement('div');
    resultView.style.cssText = [
      'display:none', 'flex-direction:column',
      'align-items:center', 'justify-content:center',
      'flex:1', 'gap:14px', 'text-align:center'
    ].join(';');

    var timerIcon = document.createElement('div');
    timerIcon.textContent = '⏱';
    timerIcon.style.cssText = 'font-size:44px;line-height:1';

    var selectedLabel = document.createElement('div');
    selectedLabel.style.cssText = 'font-size:28px;font-weight:800;color:' + accent + ';line-height:1.2;letter-spacing:-0.5px';

    var remainingLabel = document.createElement('div');
    remainingLabel.style.cssText = 'font-size:13px;line-height:1.55;color:rgba(244,246,250,0.6);max-width:230px';

    var undoBtn = document.createElement('button');
    undoBtn.type = 'button';
    undoBtn.textContent = '↩ ' + (t.timer_undo || 'Change');
    undoBtn.style.cssText = [
      'appearance:none', 'border:1px solid rgba(255,255,255,0.18)',
      'border-radius:999px', 'padding:6px 16px',
      'font-size:12px', 'font-weight:600',
      'cursor:pointer', 'color:rgba(244,246,250,0.65)',
      'background:transparent', 'font-family:' + FONT,
      'margin-top:4px'
    ].join(';');

    resultView.appendChild(timerIcon);
    resultView.appendChild(selectedLabel);
    resultView.appendChild(remainingLabel);
    resultView.appendChild(undoBtn);

    var countdownInterval = null;
    function updateCountdown() {
      var timer = window.__STOPSCROLL_TIMER;
      if (!timer || timer.end <= Date.now()) {
        remainingLabel.textContent = t.timer_done || 'Time is up!';
        selectedLabel.textContent = '✓';
        if (countdownInterval) { clearInterval(countdownInterval); countdownInterval = null; }
        // ── Trigger expired-mode for next 10 posts ──
        if (timer && !timer._expiredTriggered) {
          timer._expiredTriggered = true;
          window.__STOPSCROLL_TIMER_EXPIRED = { remaining: 10 };
        }
        return;
      }
      var left = Math.max(0, Math.ceil((timer.end - Date.now()) / 1000));
      var mm = Math.floor(left / 60);
      var ss = left % 60;
      remainingLabel.textContent = mm + ' min ' + (ss < 10 ? '0' : '') + ss + 's remaining';
    }

    if (timerRunning) {
      titleEl.textContent = t.timer_active_title || 'Timer running';
      optionsView.style.display = 'none';
      resultView.style.display = 'flex';
      selectedLabel.textContent = activeTimer.label;
      updateCountdown();
      countdownInterval = setInterval(updateCountdown, 1000);
    } else {
      titleEl.textContent = t.timer_title || 'Set a timer';
    }

    function activateTimer(time, label, originBtn) {
      var mins = Math.max(1, Math.round((time.getTime() - Date.now()) / 60000));
      window.__STOPSCROLL_TIMER = { end: time.getTime(), label: label };
      postToBridge({ type: 'setTimer', minutes: mins, label: label });
      cb.burstParticles(originBtn);
      setTimeout(function () {
        titleEl.textContent = t.timer_active_title || 'Timer running';
        selectedLabel.textContent = label;
        optionsView.style.display = 'none';
        resultView.style.display = 'flex';
        updateCountdown();
        if (countdownInterval) clearInterval(countdownInterval);
        countdownInterval = setInterval(updateCountdown, 1000);
      }, 120);
    }

    picks.forEach(function (time) {
      var btn = document.createElement('button');
      btn.type = 'button';
      var mins = minutesFrom(time);
      btn.textContent = hhmm(time) + '  ·  ' + mins + ' min';
      btn.style.cssText = [
        'appearance:none',
        'border:1px solid rgba(255,255,255,0.14)',
        'border-radius:12px',
        'padding:10px 14px',
        'font-size:13px', 'font-weight:500',
        'cursor:pointer',
        'color:#f4f6fa',
        'background:rgba(255,255,255,0.05)',
        'font-family:' + FONT,
        'text-align:center',
        'transition:background 0.6s,border-color 0.6s,transform 0.1s',
        'width:100%'
      ].join(';');
      btn.setAttribute('data-ss-glass-btn', '1');

      btn.addEventListener('click', function (event) {
        event.preventDefault();
        event.stopPropagation();
        if (cb.claimCardXP) {
          cb.claimCardXP(btn, 12, 'card_button');
        }
        activateTimer(time, hhmm(time), btn);
      });

      optionsView.appendChild(btn);
    });

    undoBtn.addEventListener('click', function (event) {
      event.preventDefault();
      event.stopPropagation();
      if (cb.claimCardXP) {
        cb.claimCardXP(undoBtn, 12, 'card_button');
      }
      window.__STOPSCROLL_TIMER = null;
      if (countdownInterval) { clearInterval(countdownInterval); countdownInterval = null; }
      titleEl.textContent = t.timer_title || 'Set a timer';
      resultView.style.display = 'none';
      optionsView.style.display = 'flex';
      postToBridge({ type: 'cancelTimer' });
    });

    content.appendChild(accentBar);
    content.appendChild(titleEl);
    content.appendChild(optionsView);
    content.appendChild(resultView);

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
    post.appendChild(actionBar);

    return post;
  }

  cb.buildTimerCard = buildTimerCard;
})(window);
