// Mood / self-diagnostic card builder — attaches to window.StopScroll.cardBuilder.
(function (global) {
  'use strict';

  var ns = (global.StopScroll = global.StopScroll || {});
  var cb = ns.cardBuilder;
  var FONT = cb.FONT;

  function buildMoodCard(config) {
    var t       = config.card_templates || {};
    var accent  = '#ffd37a';

    var ANSWERS = [
      { text: t.mood_a1 || "I'm enjoying the scroll",              reflection: t.mood_r1 || "Pleasure is valid — just stay aware of time." },
      { text: t.mood_a2 || "I feel a bit guilty about it",         reflection: t.mood_r2 || "That awareness is already a superpower." },
      { text: t.mood_a3 || "I have things to do but I'm stuck",    reflection: t.mood_r3 || "Your instincts are right. One small step counts." },
      { text: t.mood_a4 || "I had a rough day and needed this",    reflection: t.mood_r4 || "Rest matters. Make sure this is rest, not avoidance." },
      { text: t.mood_a5 || "Something else",                       reflection: t.mood_r5 || "Whatever it is — you noticed. That's what counts." }
    ];

    var post = document.createElement('div');
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
      'box-sizing:border-box', 'border:2px solid ' + accent
    ].join(';');

    var username = document.createElement('div');
    username.textContent = 'StopScroll';
    username.style.cssText = 'font-size:14px;font-weight:700;letter-spacing:0.1px';

    avatarRow.appendChild(avatar);
    avatarRow.appendChild(username);

    var more = document.createElement('div');
    more.textContent = '···';
    more.style.cssText = 'font-size:20px;letter-spacing:3px;line-height:1;color:rgba(244,246,250,0.45);padding:4px 2px';

    header.appendChild(avatarRow);
    header.appendChild(more);

    var content = document.createElement('div');
    content.style.cssText = [
      'flex:1', 'display:flex', 'flex-direction:column',
      'padding:16px 16px 8px', 'gap:10px', 'overflow:hidden'
    ].join(';');

    var accentBar = document.createElement('div');
    accentBar.style.cssText = 'width:36px;height:3px;border-radius:2px;background:' + accent + ';align-self:center';

    var questionEl = document.createElement('div');
    questionEl.textContent = t.mood_title || 'How do you feel right now?';
    questionEl.style.cssText = 'font-size:18px;font-weight:700;line-height:1.3;text-align:center;padding-bottom:4px';

    var answersView = document.createElement('div');
    answersView.style.cssText = 'display:flex;flex-direction:column;gap:8px;flex:1;justify-content:center';

    var resultView = document.createElement('div');
    resultView.style.cssText = [
      'display:none', 'flex-direction:column',
      'align-items:center', 'justify-content:center',
      'flex:1', 'gap:12px', 'text-align:center'
    ].join(';');

    var checkmark = document.createElement('div');
    checkmark.textContent = '✓';
    checkmark.style.cssText = [
      'width:48px', 'height:48px', 'border-radius:50%',
      'background:' + accent, 'color:#0a0a12',
      'display:flex', 'align-items:center', 'justify-content:center',
      'font-size:24px', 'font-weight:800', 'flex-shrink:0'
    ].join(';');

    var selectedLabel = document.createElement('div');
    selectedLabel.style.cssText = 'font-size:15px;font-weight:600;line-height:1.4;max-width:240px;color:#f4f6fa';

    var reflectionLabel = document.createElement('div');
    reflectionLabel.style.cssText = 'font-size:13px;line-height:1.55;color:rgba(244,246,250,0.6);max-width:230px';

    var undoBtn = document.createElement('button');
    undoBtn.type = 'button';
    undoBtn.textContent = '↩ ' + (t.mood_undo || 'Undo');
    undoBtn.style.cssText = [
      'appearance:none', 'border:1px solid rgba(255,255,255,0.18)',
      'border-radius:999px', 'padding:6px 16px',
      'font-size:12px', 'font-weight:600',
      'cursor:pointer', 'color:rgba(244,246,250,0.65)',
      'background:transparent', 'font-family:' + FONT,
      'margin-top:4px'
    ].join(';');

    resultView.appendChild(checkmark);
    resultView.appendChild(selectedLabel);
    resultView.appendChild(reflectionLabel);
    resultView.appendChild(undoBtn);

    ANSWERS.forEach(function (answer) {
      var btn = document.createElement('button');
      btn.type = 'button';
      btn.textContent = answer.text;
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
        'text-align:left',
        'transition:background 0.15s,border-color 0.15s',
        'width:100%'
      ].join(';');

      btn.addEventListener('click', function (event) {
        event.preventDefault();
        event.stopPropagation();
        cb.burstParticles(btn);
        setTimeout(function () {
          selectedLabel.textContent  = answer.text;
          reflectionLabel.textContent = answer.reflection;
          answersView.style.display = 'none';
          resultView.style.display  = 'flex';
        }, 120);
      });

      answersView.appendChild(btn);
    });

    undoBtn.addEventListener('click', function (event) {
      event.preventDefault();
      event.stopPropagation();
      resultView.style.display  = 'none';
      answersView.style.display = 'flex';
    });

    content.appendChild(accentBar);
    content.appendChild(questionEl);
    content.appendChild(answersView);
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

  cb.buildMoodCard = buildMoodCard;
})(window);
