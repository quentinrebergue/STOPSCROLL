// DOM and bridge helpers exposed via window.StopScroll.dom.
(function (global) {
    'use strict';

    const ns = (global.StopScroll = global.StopScroll || {});

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
            if (global.webkit && global.webkit.messageHandlers && global.webkit.messageHandlers.stopScrollBridge) {
                global.webkit.messageHandlers.stopScrollBridge.postMessage(message);
            }
        } catch (_) {
            // Ignore bridge errors.
        }
    }

    function detectLanguage() {
        const lang = document.documentElement.lang || navigator.language || '';
        if (!lang) return;
        postToBridge({ type: 'language', value: lang });
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
        detectLanguage: detectLanguage
    };
})(window);
