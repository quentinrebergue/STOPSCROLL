// Book progress card builder — attaches to window.StopScroll.cardBuilder.
(function (global) {
  'use strict';

  var ns = (global.StopScroll = global.StopScroll || {});
  var cb = ns.cardBuilder;

  function buildBookCard(config) {
    var book = global.__STOPSCROLL_BOOK;
    if (!book || !book.hasBook) return null;

    var t = config.card_templates || {};
    var page = book.page || 0;
    var total = book.totalPages || '?';
    var title = book.title || 'ton livre';

    var heading = (t.book_title || 'Ton livre t\u2019attend \uD83D\uDCD6');
    var body = (t.book_body || 'Tu en es \u00E0 la page {page} sur {total} de \u00AB\u202F{title}\u202F\u00BB. Chaque page compte, reprends l\u00E0 o\u00F9 tu en es\u202F!')
      .replace('{page}', page)
      .replace('{total}', total)
      .replace('{title}', title);

    var accent = '#90eeb0';
    var ui = cb.createCardContainer(heading, body, accent);
    ui.row.appendChild(cb.makeButton('Reprendre la lecture', '#90eeb0', function () {
      ns.dom.postToNative('open');
    }));
    return ui.card;
  }

  cb.buildBookCard = buildBookCard;
})(window);
