// Culture card builder — attaches to window.StopScroll.cardBuilder.
(function (global) {
  'use strict';

  var ns = (global.StopScroll = global.StopScroll || {});
  var cb = ns.cardBuilder;

  var LABELS = {
    fr: { title: 'Lecture rapide', btn: 'Lire l\u2019article', no: 'Aucun article disponible' },
    en: { title: 'Flash reading', btn: 'Read article', no: 'No article available' },
    es: { title: 'Lectura r\u00E1pida', btn: 'Leer art\u00EDculo', no: 'Sin art\u00EDculo' },
    de: { title: 'Schnelllekt\u00FCre', btn: 'Artikel lesen', no: 'Kein Artikel verf\u00FCgbar' },
    it: { title: 'Lettura rapida', btn: 'Leggi articolo', no: 'Nessun articolo' },
    pt: { title: 'Leitura r\u00E1pida', btn: 'Ler artigo', no: 'Sem artigo' }
  };

  function labels() {
    var lang = (ns.wikipedia && ns.wikipedia.getLang) ? ns.wikipedia.getLang() : 'en';
    return LABELS[lang] || LABELS.en;
  }

  function buildCultureCard(config) {
    var wiki = ns.wikipedia;
    if (!wiki) return null;

    var article = wiki.getCached();
    if (!article || !article.extract) return null;

    var l = labels();
    var t = config.card_templates || {};
    var heading = t.culture_title || l.title;
    var snippet = article.extract.length > 180
      ? article.extract.substring(0, 180).replace(/\s+\S*$/, '') + '\u2026'
      : article.extract;

    var body = '\u00AB\u202F' + article.title + '\u202F\u00BB\n\n' + snippet;

    var accent = '#f9a825';
    var ui = cb.createCardContainer(heading, body, accent);

    // Style the body to preserve the line break
    var bodyEl = ui.card.querySelector('[data-ss-media] div:last-of-type');
    if (bodyEl) bodyEl.style.whiteSpace = 'pre-line';

    ui.row.appendChild(cb.makeButton(t.culture_btn || l.btn, '#f9a825', function () {
      var a = wiki.consume();
      if (!a) return;
      ns.dom.postToBridge({
        type: 'openArticle',
        title: a.title,
        text: a.extract
      });
    }));

    return ui.card;
  }

  cb.buildCultureCard = buildCultureCard;
})(window);
