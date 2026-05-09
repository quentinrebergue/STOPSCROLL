import SwiftUI
import WebKit

extension InstagramWebView {

    /// Serialises AppSettings.adLabels and injectionFrequency to the WebView.
    func buildLabelsInjectionScript() -> String {
        let labels = AppSettings.shared.adLabels
        let jsonData = (try? JSONSerialization.data(withJSONObject: labels)) ?? Data()
        let json = String(data: jsonData, encoding: .utf8) ?? "[]"
        let freq = AppSettings.shared.injectionFrequency
        let sources = Array(AppSettings.shared.articleSources)
        let srcData = (try? JSONSerialization.data(withJSONObject: sources)) ?? Data()
        let srcJson = String(data: srcData, encoding: .utf8) ?? "[]"
        let devMode = AppSettings.shared.devMode ? "true" : "false"
        let username = (UserDefaults.standard.string(forKey: "ss_instagram_username") ?? "")
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        return "window.__STOPSCROLL_AD_LABELS = \(json); window.__STOPSCROLL_FREQUENCY = \(freq); window.__STOPSCROLL_ARTICLE_SOURCES = \(srcJson); window.__STOPSCROLL_DEV_MODE = \(devMode); window.__STOPSCROLL_INSTAGRAM_USERNAME = '\(username)'; window.__STOPSCROLL_GOVERNOR_MODE = window.__STOPSCROLL_GOVERNOR_MODE || 'nominal'; window.__STOPSCROLL_SCAN_DELAY_MULTIPLIER = window.__STOPSCROLL_SCAN_DELAY_MULTIPLIER || 1.0; window.__STOPSCROLL_NAV_LITE_DELAY_MULTIPLIER = window.__STOPSCROLL_NAV_LITE_DELAY_MULTIPLIER || 1.0;"
    }

    func buildYAMLInjectionScript() -> String? {
        guard let configURL = Bundle.main.url(forResource: "dynamic_feed_config", withExtension: "yaml"),
              let yaml = try? String(contentsOf: configURL, encoding: .utf8) else { return nil }
        let escaped = yaml
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "${", with: "\\${")
        return "window.__STOPSCROLL_DYNAMIC_YAML = `\(escaped)`;"
    }

    /// Reads persisted book state from UserDefaults and exposes it to JS.
    func buildBookStateScript() -> String {
        let title = UserDefaults.standard.string(forKey: "savedBookTitle") ?? ""
        let cardIndex = UserDefaults.standard.integer(forKey: "savedCardIndex")
        let bookId = UserDefaults.standard.string(forKey: "currentBookId") ?? ""
        let articleId = UserDefaults.standard.string(forKey: "currentArticleId") ?? ""

        // Try to get totalPages from the library entry
        var totalPages = 0
        if !bookId.isEmpty,
           let data = UserDefaults.standard.data(forKey: "library"),
           let lib = try? JSONDecoder().decode([LibraryBook].self, from: data) {
            if let entry = lib.first(where: { $0.id == bookId }) {
                totalPages = entry.totalPages
            }
        }

        let escapedTitle = title
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        let escapedBookId = bookId
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        let escapedArticleId = articleId
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        let hasBookState = !bookId.isEmpty || !articleId.isEmpty
        return "window.__STOPSCROLL_BOOK = {title:'\(escapedTitle)',page:\(cardIndex),totalPages:\(totalPages),bookId:'\(escapedBookId)',articleId:'\(escapedArticleId)',hasBook:\(hasBookState)};"
    }

    /// Exposes the native-owned timer state to JS so countdown/expiry survives app lifecycle changes.
    func buildTimerStateScript() -> String {
        let endTimestamp = UserDefaults.standard.double(forKey: "ss_timer_end_timestamp_ms")
        let label = UserDefaults.standard.string(forKey: "ss_timer_label") ?? ""
        let escapedLabel = label
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")

        if endTimestamp > Date().timeIntervalSince1970 * 1000 {
            return "window.__STOPSCROLL_TIMER = {end:\(Int(endTimestamp)),label:'\(escapedLabel)'};"
        }

        return "window.__STOPSCROLL_TIMER = null;"
    }

    /// Loads scripts for the requested profile.
    static func loadScripts(profile: ScriptProfile) -> [String] {
        let names: [String]
        switch profile {
        case .full:
            names = fullModuleScripts
        case .navigationLite:
            names = navigationLiteScripts
        case .searchLite:
            names = searchLiteScripts
        case .reelsLite:
            names = reelsLiteScripts
        case .none:
            names = noScripts
        }

        var scripts: [String] = []
        for name in names {
            if let url = Bundle.main.url(forResource: name, withExtension: "js"),
               let src = try? String(contentsOf: url, encoding: .utf8) {
                scripts.append(src)
            }
        }
        if profile == .full {
            // Full bootstrap entry point – must come last.
            if let url = Bundle.main.url(forResource: "block_reels", withExtension: "js"),
               let src = try? String(contentsOf: url, encoding: .utf8) {
                scripts.append(src)
            }
        } else if profile == .navigationLite {
            scripts.append(navigationSyncBootstrapScript())
        } else if profile == .reelsLite {
            scripts.append(hideReelsHeaderScript())
            scripts.append(reelsCardInjectionScript(frequency: AppSettings.shared.injectionFrequency))
        }
        // .none profile: no bootstrap needed
        return scripts
    }

    /// Injects a card every `frequency` unique Reels watched.
    /// Architecture:
    ///   - JS gating: counts unique reel IDs via SPA URL changes.
    ///   - Logic & content: delegated to the native app via a `cardRequest` bridge message
    ///     (same protocol as the main feed — `makeCardDecisionPayload` in the bridge handler).
    ///   - Rendering: uses `ns.cardBuilder.buildCardFor` — the exact same card-builder pipeline
    ///     as the main feed (card-builder modules are loaded in `reelsLiteScripts`).
    ///   - Injection: same DOM pattern as `attachCardToArticle` — hides original children,
    ///     injects an `absolute;inset:0` wrapper, restores on dismiss.
    static func reelsCardInjectionScript(frequency: Int) -> String {
        let freq = max(1, frequency)
        return """
        (function() {
            'use strict';

            var FREQ     = \(freq);
            var _seen    = Object.create(null); // reelId → true
            var _count   = 0;
            var _lastPath = '';
            var _config  = null;

            // ── Config (parsed once from window.__STOPSCROLL_DYNAMIC_YAML) ──

            function getConfig() {
                if (_config) return _config;
                try {
                    var ns = window.StopScroll;
                    if (ns && ns.config && ns.config.loadConfig) {
                        _config = ns.config.loadConfig();
                    }
                } catch(_e) {}
                return _config || { captions: [], cards: {} };
            }

            function buildAvailableCards(cfg) {
                var types = ['mood', 'timer', 'stop', 'stats', 'book', 'culture'];
                var out = [];
                for (var i = 0; i < types.length; i++) {
                    var t = types[i];
                    var entry = cfg.cards && cfg.cards[t];
                    if (!entry || entry.enabled === false) continue;
                    out.push({ type: t, weight: Number(entry.weight) || 1 });
                }
                return out;
            }

            // ── DOM helpers ──────────────────────────────────────────────────

            var FONT = '-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif';

            var SVG_HEART    = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" width="28" height="28"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/></svg>';
            var SVG_COMMENT  = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" width="28" height="28"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>';
            var SVG_SEND     = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" width="28" height="28"><line x1="22" y1="2" x2="11" y2="13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/></svg>';
            var SVG_MUSIC    = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" width="28" height="28"><circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="3"/></svg>';

            // Build the reel-style chrome that wraps the shared core content.
            // Layout:
            //   - shell: full-screen frosted glass (position:absolute;inset:0)
            //   - coreContent: fills the whole shell (position:absolute;inset:0;centered)
            //   - rightCol: action icons, absolute on the right, overlaying the content
            //   - bottomBar: absolute at the bottom-left, below the content
            function buildReelChrome(feedCard, onDismiss) {
                var coreContent = feedCard.querySelector('[data-ss-media]');
                if (!coreContent) { coreContent = feedCard; }

                // ── Frosted-glass shell ───────────────────────────────────────────
                var shell = document.createElement('div');
                shell.setAttribute('data-ss-reel-card', 'true');
                shell.style.cssText = [
                    'position:absolute', 'inset:0', 'z-index:9999',
                    'display:flex', 'flex-direction:column',
                    '-webkit-backdrop-filter:blur(26px)', 'backdrop-filter:blur(26px)',
                    'background:rgba(0,0,0,0.40)',
                    'font-family:' + FONT, 'color:#fff',
                    'box-sizing:border-box', 'overflow:hidden'
                ].join(';');

                // ── Core content: flex child, fills available height above bottom bar ──
                // The card-builder root has its own header (SS avatar) and action bar —
                // hide them to avoid duplication with our bottom bar.
                var cardRoot = coreContent.parentElement || coreContent;
                if (cardRoot !== coreContent) {
                    // Hide the SS avatar header row (identified by data-ss-card-header)
                    var cardHeader = cardRoot.querySelector('[data-ss-card-header]');
                    if (cardHeader) cardHeader.style.setProperty('display', 'none', 'important');
                    // Hide action bar (last child that is not the media area)
                    var lastChild = cardRoot.children[cardRoot.children.length - 1];
                    if (lastChild && lastChild !== coreContent) {
                        lastChild.style.setProperty('display', 'none', 'important');
                    }
                    cardRoot.style.setProperty('height', 'auto', 'important');
                }
                // Collapse any internal flex:1 stretchers so content centers naturally
                var ccChildren = coreContent.children;
                for (var ci = 0; ci < ccChildren.length; ci++) {
                    ccChildren[ci].style.setProperty('flex', 'none', 'important');
                }
                coreContent.style.setProperty('position', 'relative', 'important');
                coreContent.style.setProperty('flex', '1', 'important');
                coreContent.style.setProperty('min-height', '0', 'important');
                coreContent.style.setProperty('background', 'transparent', 'important');
                coreContent.style.setProperty('background-image', 'none', 'important');
                coreContent.style.setProperty('color', '#fff', 'important');
                coreContent.style.setProperty('display', 'flex', 'important');
                coreContent.style.setProperty('flex-direction', 'column', 'important');
                coreContent.style.setProperty('align-items', 'stretch', 'important');
                coreContent.style.setProperty('justify-content', 'center', 'important');
                coreContent.style.setProperty('padding', '24px 24px 90px 24px', 'important');
                coreContent.style.setProperty('box-sizing', 'border-box', 'important');
                // Strip glass sub-overlays
                var subNodes = coreContent.querySelectorAll('[data-ss-glass]');
                for (var si = 0; si < subNodes.length; si++) {
                    subNodes[si].style.setProperty('background', 'transparent', 'important');
                }
                shell.appendChild(coreContent);

                // ── Right column: action icons (absolute, overlaying content) ────
                var rightCol = document.createElement('div');
                rightCol.style.cssText = [
                    'position:absolute', 'right:8px', 'bottom:90px',
                    'display:flex', 'flex-direction:column',
                    'align-items:center',
                    'padding:0', 'gap:22px'
                ].join(';');

                function makeIconBtn(svgHtml, label) {
                    var wrap = document.createElement('div');
                    wrap.style.cssText = 'display:flex;flex-direction:column;align-items:center;gap:3px';
                    var btn = document.createElement('button');
                    btn.innerHTML = svgHtml;
                    btn.style.cssText = [
                        'background:none', 'border:none', 'color:#fff', 'cursor:pointer',
                        'padding:0', 'display:flex', 'align-items:center',
                        'filter:drop-shadow(0 1px 3px rgba(0,0,0,0.6))',
                        '-webkit-tap-highlight-color:transparent'
                    ].join(';');
                    wrap.appendChild(btn);
                    if (label) {
                        var lbl = document.createElement('span');
                        lbl.textContent = label;
                        lbl.style.cssText = 'font-size:11px;font-weight:600;color:#fff;text-shadow:0 1px 3px rgba(0,0,0,0.6)';
                        wrap.appendChild(lbl);
                    }
                    return wrap;
                }

                rightCol.appendChild(makeIconBtn(SVG_HEART, ''));
                rightCol.appendChild(makeIconBtn(SVG_COMMENT, ''));
                rightCol.appendChild(makeIconBtn(SVG_SEND, ''));
                rightCol.appendChild(makeIconBtn(SVG_MUSIC, ''));
                shell.appendChild(rightCol);

                // ── Bottom bar: absolute bottom-left, right margin leaves room for icons ──
                var bottomBar = document.createElement('div');
                bottomBar.style.cssText = [
                    'position:absolute', 'left:0', 'right:0', 'bottom:0',
                    'display:flex', 'align-items:center',
                    'padding:12px 14px 28px', 'gap:10px'
                ].join(';');

                var avatar = document.createElement('div');
                avatar.textContent = 'SS';
                avatar.style.cssText = [
                    'width:34px', 'height:34px', 'border-radius:50%', 'flex-shrink:0',
                    'background:linear-gradient(135deg,#7ad8ff,#a78bfa)',
                    'display:flex', 'align-items:center', 'justify-content:center',
                    'font-size:12px', 'font-weight:800', 'color:#0a0a12',
                    'border:2px solid rgba(255,255,255,0.85)'
                ].join(';');

                var meta = document.createElement('div');
                meta.style.cssText = 'flex:1;min-width:0;display:flex;flex-direction:column;gap:1px';
                var uname = document.createElement('div');
                uname.textContent = 'StopScroll';
                uname.style.cssText = 'font-size:13px;font-weight:700;color:#fff;text-shadow:0 1px 4px rgba(0,0,0,0.5)';
                var caption = document.createElement('div');
                caption.textContent = 'Take a mindful break ↓';
                caption.style.cssText = 'font-size:11px;color:rgba(255,255,255,0.65);white-space:nowrap;overflow:hidden;text-overflow:ellipsis';
                meta.appendChild(uname);
                meta.appendChild(caption);

                var dismissBtn = document.createElement('button');
                dismissBtn.textContent = '\u{1F441} Show reel';
                dismissBtn.style.cssText = [
                    'border:1.5px solid rgba(255,255,255,0.65)', 'border-radius:20px',
                    'background:transparent', 'color:#fff',
                    'font-size:13px', 'font-weight:600', 'padding:6px 14px',
                    'cursor:pointer', 'font-family:' + FONT,
                    'flex-shrink:0', '-webkit-tap-highlight-color:transparent',
                    'white-space:nowrap'
                ].join(';');
                dismissBtn.addEventListener('click', onDismiss);

                bottomBar.appendChild(avatar);
                bottomBar.appendChild(meta);
                bottomBar.appendChild(dismissBtn);
                shell.appendChild(bottomBar);

                return shell;
            }

            // The reel just below the viewport (Instagram's pre-rendered next reel).
            function findNextReelContainer() {
                var videos = document.querySelectorAll('video');
                var best = null;
                var bestDist = Infinity;
                var innerH = window.innerHeight;
                for (var i = 0; i < videos.length; i++) {
                    var v = videos[i];
                    var r = v.getBoundingClientRect();
                    if (r.width <= 0 || r.height <= 0 || r.top <= 0) continue;
                    var dist = Math.abs(r.top - innerH);
                    if (dist < bestDist) { bestDist = dist; best = v; }
                }
                if (!best) return null;
                return best.closest('[role="presentation"]')
                    || best.closest('article')
                    || best.parentElement;
            }

            // ── Card wiring ──────────────────────────────────────────────────

            function dismissCard(container) {
                var wrapper = container.querySelector('[data-ss-reel-card]');
                if (wrapper) wrapper.remove();
                container.removeAttribute('data-ss-reel-replaced');
                var vid = container.querySelector('video');
                if (vid) { try { vid.play(); } catch(_) {} }
            }

            function injectReelChrome(container, feedCard) {
                if (container.getAttribute('data-ss-reel-replaced')) return;
                container.setAttribute('data-ss-reel-replaced', 'true');

                container.style.setProperty('position', 'relative', 'important');
                container.style.setProperty('overflow', 'hidden', 'important');

                // Pause video — frozen frame becomes the blurred backdrop.
                var vid = container.querySelector('video');
                if (vid) { try { vid.pause(); } catch(_) {} }

                var chrome = buildReelChrome(feedCard, function() { dismissCard(container); });
                container.appendChild(chrome);
            }

            // ── Bridge request ───────────────────────────────────────────────

            function requestCard(container) {
                var ns = window.StopScroll;
                if (!ns || !ns.dom || !ns.dom.postToBridgeWithCallback) return;
                if (!ns.cardBuilder || !ns.cardBuilder.buildCardFor) return;

                var cfg = getConfig();
                var availableCards = buildAvailableCards(cfg);
                if (availableCards.length === 0) return;

                var message = {
                    type: 'cardRequest',
                    opportunityIndex: _count,
                    frequency: 1,        // gating is done on our side already
                    availableCards: availableCards,
                    context: { path: window.location.pathname, surface: 'reels' }
                };

                ns.dom.postToBridgeWithCallback(message, function(result) {
                    if (!result || result.ok !== true) return;
                    var payload = result.payload;
                    if (!payload || payload.contractVersion !== 1) return;
                    if (payload.decision !== 'inject') return;

                    var nativeCard = payload.card;
                    if (!nativeCard || !nativeCard.type) return;

                    try {
                        if (container.getAttribute('data-ss-reel-replaced')) return;
                        // Signal reel surface so card-stats.js shows reel-specific data
                        window.__STOPSCROLL_SURFACE = 'reels';
                        var feedCard = ns.cardBuilder.buildCardFor(nativeCard.type, cfg, nativeCard);
                        if (!feedCard) return;
                        injectReelChrome(container, feedCard);
                    } catch(_e) {}
                });
            }

            // ── Scheduling ───────────────────────────────────────────────────

            function tryInjectNext() {
                var attempts = 0;
                function attempt() {
                    var container = findNextReelContainer();
                    if (container && !container.getAttribute('data-ss-reel-replaced')) {
                        requestCard(container);
                    } else if (!container && attempts < 8) {
                        attempts++;
                        setTimeout(attempt, 350);
                    }
                }
                attempt();
            }

            // ── SPA navigation detection ─────────────────────────────────────

            function extractId(path) {
                var prefix = '/reels/';
                if (!path || path.indexOf(prefix) !== 0) return null;
                var rest = path.slice(prefix.length).split('/')[0].split('?')[0].split('#')[0];
                return rest || null;
            }

            function onPath(path) {
                if (!path || path === _lastPath) return;
                _lastPath = path;
                var id = extractId(path);
                if (!id || _seen[id]) return;
                _seen[id] = true;
                _count++;
                // Count every reel viewed for the session stats card
                try {
                    var ss = window.StopScroll;
                    if (ss && ss.sessionStats && ss.sessionStats.trackReel) { ss.sessionStats.trackReel(); }
                } catch(_e) {}
                try { webkit.messageHandlers.stopScrollBridge.postMessage({ type: 'reelViewed' }); } catch(_e) {}
                if (_count % FREQ === 0) { tryInjectNext(); }
            }

            ['pushState', 'replaceState'].forEach(function(method) {
                var orig = history[method];
                history[method] = function() {
                    orig.apply(history, arguments);
                    try { onPath(window.location.pathname); } catch(_e) {}
                };
            });
            window.addEventListener('popstate', function() {
                try { onPath(window.location.pathname); } catch(_e) {}
            });
            setInterval(function() {
                try { onPath(window.location.pathname); } catch(_e) {}
            }, 600);

            onPath(window.location.pathname);
        })();
        """
    }

    /// Hides the "Reels" title and the down-chevron button that Instagram renders
    /// at the top of the Reels feed.
    /// Strategy: Instagram wraps both in a single `div[role="button"]`. We find it
    /// via the SVG aria-label="Down chevron icon" or via the "Reels" text span,
    /// then hide that ancestor button container entirely.
    static func hideReelsHeaderScript() -> String {
        """
        (function() {
            function hide(el) {
                if (el && el.style) el.style.setProperty('display', 'none', 'important');
            }

            function scan() {
                // 1. The chevron SVG has aria-label="Down chevron icon".
                //    Its ancestor [role="button"] is the whole title+chevron bar.
                var chevron = document.querySelector('svg[aria-label="Down chevron icon"]');
                if (chevron) {
                    var btn = chevron.closest('[role="button"]') || chevron.parentElement;
                    hide(btn);
                    return; // chevron and Reels text share the same container
                }

                // 2. Fallback: find the span whose only text is "Reels" and hide
                //    its nearest [role="button"] ancestor.
                var spans = document.querySelectorAll('span');
                for (var i = 0; i < spans.length; i++) {
                    if (spans[i].children.length === 0 && spans[i].textContent.trim() === 'Reels') {
                        var container = spans[i].closest('[role="button"]') || spans[i].parentElement;
                        hide(container);
                        break;
                    }
                }
            }

            if (document.readyState !== 'loading') { scan(); }
            else { document.addEventListener('DOMContentLoaded', scan); }

            // Re-run after Instagram's deferred / SPA rendering.
            var debounce;
            new MutationObserver(function() {
                clearTimeout(debounce);
                debounce = setTimeout(scan, 150);
            }).observe(document.documentElement, { childList: true, subtree: true });
        })();
        """
    }

    /// Lightweight bridge available even when the full runtime is not loaded.
    /// Supports pause/resume commands to reduce background JS/media activity.
    static func surfaceLifecycleBridgeScript() -> String {
        """
        (function(){
            var ns = (window.StopScroll = window.StopScroll || {});
            ns.bridge = ns.bridge || {};
            var previousReceive = (typeof ns.bridge.receive === 'function') ? ns.bridge.receive : null;

            if (!window.__STOPSCROLL_SURFACE_LIFECYCLE_PATCHED) {
                window.__STOPSCROLL_SURFACE_LIFECYCLE_PATCHED = true;

                var originalSetTimeout = window.setTimeout.bind(window);
                var originalSetInterval = window.setInterval.bind(window);
                var originalRAF = window.requestAnimationFrame ? window.requestAnimationFrame.bind(window) : null;

                window.setTimeout = function(callback, delay) {
                    if (typeof callback !== 'function') {
                        return originalSetTimeout(callback, delay);
                    }
                    return originalSetTimeout(function(){
                        if (window.__STOPSCROLL_SURFACE_PAUSED) return;
                        callback();
                    }, delay);
                };

                window.setInterval = function(callback, delay) {
                    if (typeof callback !== 'function') {
                        return originalSetInterval(callback, delay);
                    }
                    return originalSetInterval(function(){
                        if (window.__STOPSCROLL_SURFACE_PAUSED) return;
                        callback();
                    }, delay);
                };

                if (originalRAF) {
                    window.requestAnimationFrame = function(callback) {
                        if (window.__STOPSCROLL_SURFACE_PAUSED) {
                            return 0;
                        }
                        return originalRAF(callback);
                    };
                }
            }

            ns.bridge.receive = function(command, payload){
                if (command === 'setPaused') {
                    var paused = !!payload;
                    window.__STOPSCROLL_SURFACE_PAUSED = paused;

                    if (paused) {
                        var media = document.querySelectorAll('video,audio');
                        for (var i = 0; i < media.length; i++) {
                            try { media[i].pause(); } catch (_) {}
                        }
                    }
                    return true;
                }

                if (command === 'setGovernor' && payload && typeof payload === 'object') {
                    var scan = Number(payload.scanDelayMultiplier);
                    var navLite = Number(payload.navLiteDelayMultiplier);
                    if (!isFinite(scan) || scan <= 0) scan = 1;
                    if (!isFinite(navLite) || navLite <= 0) navLite = 1;
                    window.__STOPSCROLL_GOVERNOR_MODE = String(payload.mode || 'nominal');
                    window.__STOPSCROLL_SCAN_DELAY_MULTIPLIER = scan;
                    window.__STOPSCROLL_NAV_LITE_DELAY_MULTIPLIER = navLite;
                    return true;
                }

                if (previousReceive) {
                    return previousReceive(command, payload);
                }
                return false;
            };
        })();
        """
    }

    private static func navigationSyncBootstrapScript() -> String {
        """
        (function(){
            if (window.__STOPSCROLL_NAV_LITE_RUNNING) return;
            window.__STOPSCROLL_NAV_LITE_RUNNING = true;
            window.__STOPSCROLL_NAV_LITE_PAUSED = false;
            var tick = function(){
                if (window.__STOPSCROLL_NAV_LITE_PAUSED || document.hidden) return;
                var ns = window.StopScroll;
                if (ns && ns.nav && ns.nav.syncNativeNavState) {
                    ns.nav.syncNativeNavState();
                }
                if (ns && ns.dom && ns.dom.detectTheme) {
                    ns.dom.detectTheme();
                }
            };

            var scheduleNext = function(){
                var governor = Number(window.__STOPSCROLL_NAV_LITE_DELAY_MULTIPLIER || 1);
                if (!isFinite(governor) || governor <= 0) governor = 1;
                var delay = document.hidden ? 6000 : 3200;
                if (!window.__STOPSCROLL_NAV_LITE_PAUSED && !document.hidden) {
                    delay = 2600;
                }
                delay = Math.max(900, Math.round(delay * governor));
                clearTimeout(window.__STOPSCROLL_NAV_LITE_TIMER);
                window.__STOPSCROLL_NAV_LITE_TIMER = setTimeout(function(){
                    tick();
                    scheduleNext();
                }, delay);
            };

            tick();
            window.addEventListener('popstate', tick);
            document.addEventListener('visibilitychange', function(){
                if (!document.hidden) tick();
                scheduleNext();
            });

            var ns = window.StopScroll;
            if (ns && ns.bridge && typeof ns.bridge.receive === 'function') {
                var prevReceive = ns.bridge.receive;
                ns.bridge.receive = function(command, payload){
                    if (command === 'setPaused') {
                        window.__STOPSCROLL_NAV_LITE_PAUSED = !!payload;
                        if (!window.__STOPSCROLL_NAV_LITE_PAUSED && !document.hidden) {
                            tick();
                        }
                        scheduleNext();
                        return true;
                    }
                    return prevReceive(command, payload);
                };
            }

            scheduleNext();
        })();
        """
    }

    /// Hides Instagram messaging back controls that conflict with native navigation.
    /// Emits a JS debugLog payload once per path to keep bridge logs actionable.
    static func messagingHeaderCleanupScript() -> String {
        """
        (function(){
            try {
                if (!location.pathname || location.pathname.indexOf('/direct') !== 0) return;

                var cleanedPath = location.pathname;
                if (window.__STOPSCROLL_LAST_MSG_CLEANUP_PATH === cleanedPath) return;

                var hiddenCount = 0;
                var nodes = document.querySelectorAll(
                    'header a[href="/direct/inbox/"], ' +
                    'header a[href="/direct/inbox"], ' +
                    'header a[aria-label*="Back" i], ' +
                    'header button[aria-label*="Back" i]'
                );

                if (location.pathname.indexOf('/direct/t/') === 0) {
                    var header = document.querySelector('header');
                    if (header) {
                        var firstAction = header.querySelector('a,button');
                        if (firstAction) {
                            firstAction.style.setProperty('display', 'none', 'important');
                            firstAction.style.setProperty('pointer-events', 'none', 'important');
                            hiddenCount += 1;
                        }
                    }
                }

                for (var i = 0; i < nodes.length; i++) {
                    nodes[i].style.setProperty('display', 'none', 'important');
                    nodes[i].style.setProperty('pointer-events', 'none', 'important');
                    hiddenCount += 1;
                }

                window.__STOPSCROLL_LAST_MSG_CLEANUP_PATH = cleanedPath;

                var ns = window.StopScroll;
                if (ns && ns.dom && ns.dom.postToBridge) {
                    ns.dom.postToBridge({
                        type: 'debugLog',
                        category: 'MessagingInjection',
                        level: 'DEBUG',
                        message: 'messages_header_cleanup path=' + cleanedPath + ' hidden=' + hiddenCount
                    });
                }
            } catch (e) {
                try {
                    var nsErr = window.StopScroll;
                    if (nsErr && nsErr.dom && nsErr.dom.postToBridge) {
                        nsErr.dom.postToBridge({
                            type: 'debugLog',
                            category: 'MessagingInjection',
                            level: 'ERROR',
                            message: 'messages_header_cleanup_error ' + (e && e.message ? e.message : 'unknown')
                        });
                    }
                } catch (_) {}
            }
        })();
        """
    }

    /// Lightweight diagnostics for chat thread rendering/scroll state.
    static func messagesDiagnosticsScript() -> String {
        """
        (function(){
            try {
                if (!(window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.stopScrollBridge)) return;
                if (!location.pathname || location.pathname.indexOf('/direct') !== 0) return;

                var composer = document.querySelector('textarea, div[contenteditable="true"], input[type="text"]');
                var scrolling = document.scrollingElement || document.documentElement || document.body;
                var payload = {
                    type: 'debugLog',
                    category: 'MessagesDiagnostics',
                    level: 'DEBUG',
                    message: 'messages_diag path=' + location.pathname
                        + ' hasComposer=' + (!!composer)
                        + ' innerH=' + (window.innerHeight || 0)
                        + ' scrollH=' + ((scrolling && scrolling.scrollHeight) || 0)
                        + ' scrollTop=' + ((scrolling && scrolling.scrollTop) || 0)
                };
                window.webkit.messageHandlers.stopScrollBridge.postMessage(payload);
            } catch (_) {}
        })();
        """
    }


    /// Prevents vertical scroll gestures when they start from the message composer area.
    static func messagesInputScrollGuardScript() -> String {
        """
        (function(){
            try {
                if (!location.pathname || location.pathname.indexOf('/direct') !== 0) return;

                function send(msg) {
                    try {
                        if (!(window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.stopScrollBridge)) return;
                        window.webkit.messageHandlers.stopScrollBridge.postMessage({
                            type: 'debugLog',
                            category: 'MessagesInputGuard',
                            level: 'DEBUG',
                            message: msg
                        });
                    } catch (_) {}
                }

                function isComposerNode(node) {
                    if (!node || !node.closest) return false;
                    return !!node.closest(
                        'footer, form, textarea, input[type="text"], input[type="search"], [contenteditable="true"], [role="textbox"]'
                    );
                }

                if (!window.__STOPSCROLL_MSG_INPUT_GUARD_LISTENERS) {
                    var stopVerticalScroll = function(ev) {
                        if (!isComposerNode(ev.target)) return;
                        ev.preventDefault();
                        ev.stopPropagation();
                    };

                    document.addEventListener('touchmove', stopVerticalScroll, { passive: false, capture: true });
                    document.addEventListener('wheel', stopVerticalScroll, { passive: false, capture: true });
                    window.__STOPSCROLL_MSG_INPUT_GUARD_LISTENERS = true;
                }

                var nodes = document.querySelectorAll(
                    'footer, form, textarea, input[type="text"], input[type="search"], [contenteditable="true"], [role="textbox"]'
                );

                for (var i = 0; i < nodes.length; i++) {
                    nodes[i].style.setProperty('overscroll-behavior-y', 'contain', 'important');
                    nodes[i].style.setProperty('touch-action', 'manipulation', 'important');
                }

                send('messages_input_guard path=' + location.pathname + ' nodes=' + nodes.length);
            } catch (e) {
                try {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.stopScrollBridge) {
                        window.webkit.messageHandlers.stopScrollBridge.postMessage({
                            type: 'debugLog',
                            category: 'MessagesInputGuard',
                            level: 'ERROR',
                            message: 'messages_input_guard_error ' + (e && e.message ? e.message : 'unknown')
                        });
                    }
                } catch (_) {}
            }
        })();
        """
    }

}
