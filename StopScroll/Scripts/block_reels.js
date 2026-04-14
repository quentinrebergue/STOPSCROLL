// StopScroll feed replacement and reel limiting.

(function () {
    'use strict';

    if (window.__STOPSCROLL_DYNAMIC_RUNNING) {
        return;
    }
    window.__STOPSCROLL_DYNAMIC_RUNNING = true;

    const RELOAD_BUTTON_ID = 'ss-reload-floating-button';

    // Instagram ad/sponsored labels across languages (lowercase for comparison).
    const SPONSORED_LABELS = [
        // French
        'sponsorisé', 'suggestion pour vous', 'publicité',
        // English
        'sponsored', 'suggested for you',
        // Spanish
        'patrocinado', 'sugerido para ti',
        // German
        'gesponsert', 'vorschlag für dich',
        // Italian
        'sponsorizzato', 'suggerito per te',
        // Portuguese
        'patrocinado', 'sugerido para você'
    ];


    // Returns the active label list: Swift-injected (from AppSettings/UserDefaults) takes priority.
    function getAdLabels() {
        var injected = window.__STOPSCROLL_AD_LABELS;
        if (Array.isArray(injected) && injected.length > 0) {
            return injected
                .map(function (label) { return String(label || '').trim().toLowerCase(); })
                .filter(Boolean);
        }
        return SPONSORED_LABELS;
    }

    const SCROLL_KEYS = new Set(['ArrowDown', 'ArrowUp', 'Space', ' ', 'PageDown', 'PageUp']);
    const DEFAULT_CONFIG = {
        feed_injection: {
            enabled: true,
            ad_replacement: true,
            max_dynamic_posts_per_session: 30
        },
        cards: {
            metrics: { enabled: true, every_n_opportunities: 1 },
            mood: { enabled: true, every_n_opportunities: 2 },
            stop: { enabled: true, every_n_opportunities: 3 }
        },
        reload: {
            floating_button_enabled: true
        },
        card_templates: {
            metrics_title: 'Session snapshot',
            metrics_body: 'You skipped {skipped} dopamine loops and protected {minutes} min of focus.',
            mood_title: 'Mood check',
            mood_prompt_1: 'What do you want to feel after this session?',
            mood_prompt_2: 'What is one useful thing you can do in 10 minutes?',
            mood_prompt_3: 'Pause: are you scrolling by choice or habit?',
            stop_title: 'Stop plan',
            stop_body: 'Set a concrete stop point now and switch to intentional time.'
        }
    };

    const state = {
        config: null,
        opportunities: 0,
        shownCards: 0,
        byTypeCount: {
            metrics: 0,
            mood: 0,
            stop: 0
        },
        seenPosts: new WeakSet(),
        periodicScanTimer: null,
        scanScheduled: false,
        scrollLockActive: false
    };

    function isMainFeed() {
        const path = window.location.pathname;
        return path === '/' || path === '';
    }

    function isReelPage() {
        const path = window.location.pathname;
        return /^\/(reels?\/)[^/]+/.test(path) && path !== '/reels/' && path !== '/reels';
    }

    function isPostPage() {
        return window.location.pathname.startsWith('/p/');
    }

    function isSingleContentPage() {
        return isReelPage() || isPostPage();
    }

    function isReelsTab() {
        const path = window.location.pathname;
        return path === '/reels' || path === '/reels/';
    }

    // Returns true if the article contains an Instagram ad/sponsored indicator.
    function isAdPost(article) {
        const spans = article.querySelectorAll('span');
        for (const el of spans) {
            // Only inspect leaf text nodes to avoid false positives from wrappers.
            if (el.childElementCount > 0) continue;
            const text = (el.textContent || '').trim().toLowerCase();
            if (text.length < 2 || text.length > 60) continue;
            if (getAdLabels().includes(text)) return true;
        }
        return false;
    }

    // Replaces an ad article's visual content with a StopScroll card while
    // preserving its exact height so no scroll shift occurs.
    function injectCardIntoPost(article, type) {
        const h = article.offsetHeight;
        if (h < 80) return false; // Article not yet laid out — skip.

        const card = buildCardFor(type);
        if (!card) return false;

        // Lock height before touching children to prevent reflow.
        article.style.setProperty('min-height', h + 'px', 'important');
        article.style.setProperty('overflow', 'hidden', 'important');
        article.style.setProperty('position', 'relative', 'important');
        article.setAttribute('data-ss-replaced', 'true');

        // Hide existing children (keep them for React's virtual DOM).
        for (const child of article.children) {
            if (child.getAttribute('data-ss-injection')) continue;
            child.style.setProperty('visibility', 'hidden', 'important');
            child.style.setProperty('pointer-events', 'none', 'important');
        }

        // Re-hide any children React re-renders into the article.
        const observer = new MutationObserver(function () {
            for (const child of article.children) {
                if (!child.getAttribute('data-ss-injection')) {
                    child.style.setProperty('visibility', 'hidden', 'important');
                    child.style.setProperty('pointer-events', 'none', 'important');
                }
            }
        });
        observer.observe(article, { childList: true });

        // Overlay wrapper fills the article footprint exactly.
        const wrapper = document.createElement('div');
        wrapper.setAttribute('data-ss-injection', 'true');
        wrapper.style.cssText = [
            'position:absolute',
            'inset:0',
            'z-index:9999',
            'display:flex',
            'align-items:center',
            'justify-content:center',
            'padding:16px',
            'box-sizing:border-box',
            'background:linear-gradient(155deg, #14141c, #0e0e14)'
        ].join(';');

        wrapper.appendChild(card);
        article.appendChild(wrapper);
        return true;
    }

    function toValue(raw) {
        const value = (raw || '').trim();
        if (value === 'true') return true;
        if (value === 'false') return false;
        if (/^-?\d+$/.test(value)) return parseInt(value, 10);
        if (/^-?\d+\.\d+$/.test(value)) return parseFloat(value);
        return value.replace(/^['"]|['"]$/g, '');
    }

    function parseSimpleYAML(text) {
        const root = {};
        const stack = [{ indent: -1, obj: root }];
        const lines = (text || '').split(/\r?\n/);

        for (const line of lines) {
            if (!line.trim() || line.trim().startsWith('#')) {
                continue;
            }

            const indent = line.match(/^\s*/)[0].length;
            const entry = line.trim();
            const sepIndex = entry.indexOf(':');
            if (sepIndex < 0) {
                continue;
            }

            const key = entry.slice(0, sepIndex).trim();
            const rawValue = entry.slice(sepIndex + 1).trim();

            while (stack.length > 1 && indent <= stack[stack.length - 1].indent) {
                stack.pop();
            }

            const parent = stack[stack.length - 1].obj;
            if (!rawValue) {
                const next = {};
                parent[key] = next;
                stack.push({ indent: indent, obj: next });
            } else {
                parent[key] = toValue(rawValue);
            }
        }

        return root;
    }

    function deepMerge(base, override) {
        if (typeof base !== 'object' || base === null) {
            return override;
        }
        const out = Array.isArray(base) ? base.slice() : Object.assign({}, base);
        if (typeof override !== 'object' || override === null) {
            return out;
        }

        for (const key of Object.keys(override)) {
            const next = override[key];
            if (typeof next === 'object' && next !== null && !Array.isArray(next)) {
                out[key] = deepMerge(out[key] || {}, next);
            } else {
                out[key] = next;
            }
        }

        return out;
    }

    function loadConfig() {
        const yamlText = window.__STOPSCROLL_DYNAMIC_YAML || '';
        const parsed = parseSimpleYAML(yamlText);
        state.config = deepMerge(DEFAULT_CONFIG, parsed);
    }

    function postToNative(message) {
        try {
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.openBookReader) {
                window.webkit.messageHandlers.openBookReader.postMessage(message || 'open');
            }
        } catch (_) {
            // Ignore bridge errors.
        }
    }

    function makeButton(label, background, handler) {
        const btn = document.createElement('button');
        btn.type = 'button';
        btn.textContent = label;
        btn.style.cssText = [
            'appearance:none',
            'border:none',
            'border-radius:999px',
            'padding:8px 12px',
            'font-size:12px',
            'font-weight:700',
            'cursor:pointer',
            'color:#0f1118',
            'background:' + background
        ].join(';');
        btn.addEventListener('click', handler);
        return btn;
    }

    function createCardContainer(title, body, accent) {
        const card = document.createElement('div');
        card.style.cssText = [
            'pointer-events:auto',
            'margin:0 auto',
            'max-width:560px',
            'padding:14px',
            'border-radius:14px',
            'border:1px solid rgba(255,255,255,0.16)',
            'background:linear-gradient(155deg, rgba(20,20,28,0.96), rgba(14,14,20,0.98))',
            'box-shadow:0 18px 36px rgba(0,0,0,0.34)',
            'color:#f4f6fa',
            'font-family:-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif'
        ].join(';');

        const header = document.createElement('div');
        header.style.cssText = 'display:flex;align-items:center;justify-content:space-between;gap:8px;margin-bottom:8px';

        const titleEl = document.createElement('strong');
        titleEl.textContent = title;
        titleEl.style.cssText = 'font-size:15px;letter-spacing:0.2px';

        const badge = document.createElement('span');
        badge.textContent = 'StopScroll';
        badge.style.cssText = 'font-size:11px;font-weight:700;color:' + accent;

        header.appendChild(titleEl);
        header.appendChild(badge);

        const bodyEl = document.createElement('div');
        bodyEl.textContent = body;
        bodyEl.style.cssText = 'font-size:13px;line-height:1.42;color:rgba(244,246,250,0.9)';

        const row = document.createElement('div');
        row.style.cssText = 'display:flex;gap:8px;flex-wrap:wrap;margin-top:10px';

        card.appendChild(header);
        card.appendChild(bodyEl);
        card.appendChild(row);

        return { card: card, row: row };
    }

    function buildMetricsCard() {
        const t = state.config.card_templates || {};
        const readCount = Math.floor((Date.now() / 1000) % 12) + 1;
        const focusMinutes = Math.floor((Date.now() / 1000) % 40) + 8;
        const body = (t.metrics_body || 'You skipped {skipped} dopamine loops and protected {minutes} min of focus.')
            .replace('{skipped}', readCount)
            .replace('{minutes}', focusMinutes);
        const ui = createCardContainer(t.metrics_title || 'Session snapshot', body, '#7ad8ff');
        ui.row.appendChild(makeButton('Open reader', '#8ae9ff', function () { postToNative('metrics-open'); }));
        return ui.card;
    }

    function buildMoodCard() {
        const t = state.config.card_templates || {};
        const prompts = [
            t.mood_prompt_1 || 'What do you want to feel after this session?',
            t.mood_prompt_2 || 'What is one useful thing you can do in 10 minutes?',
            t.mood_prompt_3 || 'Pause: are you scrolling by choice or habit?'
        ];
        const prompt = prompts[Math.floor(Math.random() * prompts.length)];
        const ui = createCardContainer(t.mood_title || 'Mood check', prompt, '#ffd37a');
        ui.row.appendChild(makeButton('Reset with reading', '#ffe18e', function () { postToNative('mood-open'); }));
        return ui.card;
    }

    function buildStopCard() {
        const t = state.config.card_templates || {};
        const now = new Date();
        const inFive = new Date(now.getTime() + 5 * 60000);
        const nextRound = new Date(now.getTime());
        const mins = nextRound.getMinutes();
        nextRound.setMinutes(mins < 30 ? 30 : 60, 0, 0);

        function hhmm(date) {
            return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        }

        const ui = createCardContainer(
            t.stop_title || 'Stop plan',
            t.stop_body || 'Set a concrete stop point now and switch to intentional time.',
            '#90ff9f'
        );
        ui.row.appendChild(makeButton('In 5 min (' + hhmm(inFive) + ')', '#a4ffb0', function () { postToNative('stop-5min'); }));
        ui.row.appendChild(makeButton('Next round (' + hhmm(nextRound) + ')', '#b6ffc0', function () { postToNative('stop-next-round'); }));
        return ui.card;
    }

    function buildCardFor(type) {
        if (type === 'metrics') return buildMetricsCard();
        if (type === 'mood') return buildMoodCard();
        if (type === 'stop') return buildStopCard();
        return null;
    }

    function cardEnabled(type) {
        return !!(state.config.cards[type] && state.config.cards[type].enabled);
    }

    function cardFrequency(type) {
        const raw = state.config.cards[type] && state.config.cards[type].every_n_opportunities;
        const n = Number(raw);
        if (!Number.isFinite(n) || n <= 0) {
            return 1;
        }
        return Math.floor(n);
    }

    function chooseCardType() {
        const order = ['metrics', 'mood', 'stop'];
        const candidates = [];

        for (const type of order) {
            if (!cardEnabled(type)) {
                continue;
            }
            if (state.opportunities % cardFrequency(type) === 0) {
                candidates.push(type);
            }
        }

        if (candidates.length === 0) {
            return null;
        }

        candidates.sort(function (a, b) {
            return state.byTypeCount[a] - state.byTypeCount[b];
        });

        return candidates[0];
    }

    function blockWheel(e) {
        e.preventDefault();
        e.stopPropagation();
    }

    function blockScrollKeys(e) {
        if (SCROLL_KEYS.has(e.key)) {
            e.preventDefault();
            e.stopPropagation();
        }
    }

    function applyScrollLock() {
        if (state.scrollLockActive || !isReelPage()) {
            return;
        }

        state.scrollLockActive = true;
        document.documentElement.style.setProperty('overflow', 'hidden', 'important');
        document.documentElement.style.setProperty('overscroll-behavior', 'none', 'important');
        document.body.style.setProperty('overflow', 'hidden', 'important');
        document.body.style.setProperty('overscroll-behavior', 'none', 'important');

        document.addEventListener('wheel', blockWheel, { passive: false, capture: true });
        document.addEventListener('keydown', blockScrollKeys, { capture: true });
    }

    function removeScrollLock() {
        if (!state.scrollLockActive) {
            return;
        }

        state.scrollLockActive = false;
        document.documentElement.style.removeProperty('overflow');
        document.documentElement.style.removeProperty('overscroll-behavior');
        document.body.style.removeProperty('overflow');
        document.body.style.removeProperty('overscroll-behavior');

        document.removeEventListener('wheel', blockWheel, { capture: true });
        document.removeEventListener('keydown', blockScrollKeys, { capture: true });
    }

    function hideExtraContent() {
        if (!isSingleContentPage()) {
            return;
        }

        const allArticles = document.querySelectorAll('article');
        if (allArticles.length > 1) {
            for (let index = 1; index < allArticles.length; index += 1) {
                allArticles[index].style.setProperty('display', 'none', 'important');
            }
        }

        if (!isReelPage()) {
            return;
        }

        const videos = document.querySelectorAll('video');
        if (videos.length > 0) {
            const firstVideo = videos[0];
            const firstCard = firstVideo.closest('div[role="presentation"]')
                || firstVideo.closest('article')
                || firstVideo.closest('section > div > div');

            if (firstCard && firstCard.parentElement) {
                const siblings = firstCard.parentElement.children;
                let foundFirst = false;

                for (const child of siblings) {
                    if (child === firstCard) {
                        foundFirst = true;
                        continue;
                    }

                    if (foundFirst) {
                        child.style.setProperty('display', 'none', 'important');
                    }
                }
            }
        }
    }

    // ——— Transform Reels nav button into a Book reader button ———
    function transformReelsToBook(link) {
        link.setAttribute('data-ss-book', '1');

        // Replace the SVG icon with an open-book icon
        const svg = link.querySelector('svg');
        if (svg) {
            svg.setAttribute('aria-label', 'Read');
            svg.setAttribute('viewBox', '0 0 24 24');
            svg.setAttribute('width', '24');
            svg.setAttribute('height', '24');
            svg.innerHTML = '<path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>'
                          + '<path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>';
        }

        // Change href so CSS a[href="/reels/"] no longer hides it, and prevent navigation
        link.setAttribute('href', '#book');

        // Make sure the link and its wrappers are visible
        link.style.cssText += ';display:flex!important;align-items:center;justify-content:center;';
        const li = link.closest('li');
        if (li) li.style.cssText += ';display:list-item!important;';
        const wrapper = link.parentElement;
        if (wrapper && wrapper.children.length <= 2) {
            wrapper.style.cssText += ';display:flex!important;';
        }

        // Open the book reader on click
        link.addEventListener('click', function(e) {
            e.preventDefault();
            e.stopPropagation();
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.openBookReader) {
                window.webkit.messageHandlers.openBookReader.postMessage('open');
            }
        });
    }

    function manageReelPageRestrictions() {
        if (isReelsTab()) {
            window.location.href = '/';
            return;
        }

        if (isReelPage()) {
            applyScrollLock();
        } else {
            removeScrollLock();
        }

        hideExtraContent();
    }

    function scanNewPosts() {
        const cfg = state.config.feed_injection;
        const maxCards = Number(cfg.max_dynamic_posts_per_session) || 0;

        if (!isMainFeed() || !cfg.enabled || cfg.ad_replacement === false) {
            return;
        }

        const posts = document.querySelectorAll('article');
        for (const post of posts) {
            if (state.seenPosts.has(post)) {
                continue;
            }
            state.seenPosts.add(post);

            if (!isAdPost(post)) {
                continue;
            }

            if (maxCards > 0 && state.shownCards >= maxCards) {
                return;
            }

            state.opportunities += 1;
            const chosen = chooseCardType();
            if (chosen && injectCardIntoPost(post, chosen)) {
                state.shownCards += 1;
                state.byTypeCount[chosen] += 1;
            }
        }
    }

    function scheduleScan() {
        if (state.scanScheduled) {
            return;
        }
        state.scanScheduled = true;
        requestAnimationFrame(function () {
            state.scanScheduled = false;
            checkNavInjections();
            manageReelPageRestrictions();
            scanNewPosts();
        });
    }

    function ensureReloadButton() {
        const enabled = !!(state.config.reload && state.config.reload.floating_button_enabled);
        const existing = document.getElementById(RELOAD_BUTTON_ID);

        if (!enabled) {
            if (existing) existing.remove();
            return;
        }

        if (existing) {
            return;
        }

        const button = document.createElement('button');
        button.id = RELOAD_BUTTON_ID;
        button.type = 'button';
        button.textContent = 'Reload';
        button.style.cssText = [
            'position:fixed',
            'right:14px',
            'bottom:92px',
            'z-index:999999',
            'border:none',
            'border-radius:999px',
            'padding:10px 14px',
            'font-size:12px',
            'font-weight:700',
            'color:#0f1118',
            'background:#8ae9ff',
            'box-shadow:0 10px 24px rgba(0,0,0,0.24)'
        ].join(';');
        button.addEventListener('click', function () {
            window.location.reload();
        });

        document.body.appendChild(button);
    }

    function patchHistoryForSPA() {
        const originalPushState = history.pushState;
        const originalReplaceState = history.replaceState;

        history.pushState = function () {
            const result = originalPushState.apply(this, arguments);
            setTimeout(scheduleScan, 80);
            setTimeout(checkNavInjections, 350);
            return result;
        };

        history.replaceState = function () {
            const result = originalReplaceState.apply(this, arguments);
            setTimeout(scheduleScan, 80);
            setTimeout(checkNavInjections, 350);
            return result;
        };

        window.addEventListener('popstate', function () {
            setTimeout(scheduleScan, 80);
            setTimeout(checkNavInjections, 350);
        });
    }

    function setupLightweightTracking() {
        window.addEventListener('scroll', scheduleScan, { passive: true });
        window.addEventListener('resize', scheduleScan);

        if (state.periodicScanTimer) {
            clearInterval(state.periodicScanTimer);
        }
        state.periodicScanTimer = setInterval(scheduleScan, 1400);

        document.addEventListener('visibilitychange', function () {
            if (!document.hidden) {
                scheduleScan();
            }
        });
    }


    // ── NAV INJECTION ────────────────────────────────────────────────────────

    // Detect Instagram's UI language and report it to Swift via stopScrollBridge.
    function detectLanguage() {
        var lang = document.documentElement.lang || navigator.language || '';
        if (!lang) return;
        try {
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.stopScrollBridge) {
                window.webkit.messageHandlers.stopScrollBridge.postMessage({ type: 'language', value: lang });
            }
        } catch (_) {}
    }

    // Replace the Reels icon in Instagram's bottom nav with a book icon.
    function cleanReels() {
        // Transform the Reels nav tab into a Book button
        document.querySelectorAll('a[href="/reels/"]:not([data-ss-book]), a[href="/reels"]:not([data-ss-book])').forEach(el => {
            transformReelsToBook(el);
        });
    }

    // Inject a reload button into Instagram's top nav bar, left of the + (create) button.
    function injectReloadButton() {
        if (document.getElementById('ss-reload-nav-btn')) return;

        var candidates = document.querySelectorAll('header a, header [role="button"], header button');
        var createEl = null;
        for (var i = 0; i < candidates.length; i++) {
            var el = candidates[i];
            var href = (el.getAttribute('href') || '').toLowerCase();
            var aria = (el.getAttribute('aria-label') || '').toLowerCase();
            if (href.indexOf('/create') !== -1 || aria.indexOf('new post') !== -1 ||
                aria.indexOf('créer') !== -1 || aria.indexOf('create') !== -1) {
                createEl = el;
                break;
            }
        }
        if (!createEl || !createEl.parentElement) return;

        var btn = document.createElement('button');
        btn.id = 'ss-reload-nav-btn';
        btn.type = 'button';
        btn.setAttribute('aria-label', 'Reload feed');
        btn.style.cssText = [
            'background:transparent',
            'border:none',
            'padding:6px 8px',
            'cursor:pointer',
            'color:inherit',
            'display:inline-flex',
            'align-items:center',
            'justify-content:center',
            '-webkit-tap-highlight-color:transparent'
        ].join(';');
        btn.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M23 4v6h-6"/><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/></svg>';

        btn.addEventListener('click', function () {
            try {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.stopScrollBridge) {
                    window.webkit.messageHandlers.stopScrollBridge.postMessage('reloadFeed');
                }
            } catch (_) {}
        });

        createEl.parentElement.insertBefore(btn, createEl);

        // Hide the native floating reload button once the nav button is in place.
        var floating = document.getElementById(RELOAD_BUTTON_ID);
        if (floating) floating.style.display = 'none';
    }

    function checkNavInjections() {
        cleanReels();
        injectReloadButton();
    }

    function bootstrap() {
        loadConfig();
        ensureReloadButton();
        patchHistoryForSPA();
        setupLightweightTracking();
        detectLanguage();
        scheduleScan();
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', bootstrap, { once: true });
    } else {
        bootstrap();
    }
})();
