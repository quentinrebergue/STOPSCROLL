// DOM and bridge helpers exposed via window.StopScroll.dom.
(function (global) {
    'use strict';

    const ns = (global.StopScroll = global.StopScroll || {});
    var _bridgeSeq = 0;
    var _pendingBridgeRequests = {};

    function isMainFeed() {
        const path = global.location.pathname;
        return path === '/' || path === '';
    }

    function isReelPage() {
        const path = global.location.pathname;
        return /^\/(reels?\/)[^/]+/.test(path) && path !== '/reels/' && path !== '/reels';
    }

    function isPostPage() {
        return global.location.pathname.startsWith('/p/');
    }

    function isSingleContentPage() {
        return isReelPage() || isPostPage();
    }

    function isReelsTab() {
        const path = global.location.pathname;
        return path === '/reels' || path === '/reels/';
    }

    function isSettingsPage() {
        const path = global.location.pathname;
        return path.startsWith('/accounts/') || path.startsWith('/settings/');
    }

    function postToNative(message) {
        try {
            if (global.webkit && global.webkit.messageHandlers && global.webkit.messageHandlers.openBookReader) {
                global.webkit.messageHandlers.openBookReader.postMessage(message || 'open');
            }
        } catch (_) {
            // Ignore bridge errors.
        }
    }

    function postToBridge(message) {
        try {
            if (!(global.webkit && global.webkit.messageHandlers && global.webkit.messageHandlers.stopScrollBridge)) {
                return null;
            }

            // New envelope format (v1): { v, id, type, payload, ts }
            // Keep backward compatibility by accepting old inputs:
            // - string: "reloadFeed"
            // - object: { type: "...", ...legacyFields }
            var envelope = null;

            if (typeof message === 'string') {
                envelope = {
                    v: 1,
                    id: 'js-' + Date.now() + '-' + (++_bridgeSeq),
                    type: message,
                    payload: {},
                    ts: Date.now()
                };
            } else if (message && typeof message === 'object' && typeof message.type === 'string') {
                var payload = {};
                for (var k in message) {
                    if (!Object.prototype.hasOwnProperty.call(message, k)) continue;
                    if (k === 'type') continue;
                    payload[k] = message[k];
                }
                envelope = {
                    v: 1,
                    id: 'js-' + Date.now() + '-' + (++_bridgeSeq),
                    type: message.type,
                    payload: payload,
                    ts: Date.now()
                };
            }

            if (!envelope) {
                // Unknown payload shape: keep old behaviour and forward raw.
                global.webkit.messageHandlers.stopScrollBridge.postMessage(message);
                return null;
            }

            global.webkit.messageHandlers.stopScrollBridge.postMessage(envelope);
            return envelope.id;
        } catch (_) {
            // Ignore bridge errors.
            return null;
        }
    }

    function postToBridgeWithCallback(message, callback) {
        var reqId = postToBridge(message);
        if (reqId && typeof callback === 'function') {
            _pendingBridgeRequests[reqId] = callback;
        }
        return reqId;
    }

    // Called by Swift: window.StopScroll.dom._onNativeBridgeResult({ ... })
    function _onNativeBridgeResult(result) {
        if (!result || typeof result !== 'object') return;

        var reqId = result.requestId;
        if (reqId && _pendingBridgeRequests[reqId]) {
            try {
                _pendingBridgeRequests[reqId](result);
            } catch (_) {
                // Ignore callback errors.
            }
            delete _pendingBridgeRequests[reqId];
        }

        try {
            global.dispatchEvent(new CustomEvent('stopscroll:bridge-result', { detail: result }));
        } catch (_) {
            // Ignore environments without CustomEvent support.
        }
    }

    function detectLanguage() {
        const lang = document.documentElement.lang || navigator.language || '';
        if (!lang) return;
        postToBridge({ type: 'language', value: lang });
    }

    function detectTheme() {
        var el = document.body || document.documentElement;
        if (!el) return;
        var bg = global.getComputedStyle(el).backgroundColor || '';
        var m = bg.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/i);
        var dark = true;
        if (m) {
            var r = parseInt(m[1], 10);
            var g = parseInt(m[2], 10);
            var b = parseInt(m[3], 10);
            var luminance = (0.2126 * r + 0.7152 * g + 0.0722 * b);
            dark = luminance < 140;
        }
        postToBridge({ type: 'instagramTheme', dark: dark });
    }

    ns.dom = {
        isMainFeed: isMainFeed,
        isReelPage: isReelPage,
        isPostPage: isPostPage,
        isSingleContentPage: isSingleContentPage,
        isReelsTab: isReelsTab,
        isSettingsPage: isSettingsPage,
        postToNative: postToNative,
        postToBridge: postToBridge,
        postToBridgeWithCallback: postToBridgeWithCallback,
        _onNativeBridgeResult: _onNativeBridgeResult,
        detectLanguage: detectLanguage,
        detectTheme: detectTheme
    };
})(window);
