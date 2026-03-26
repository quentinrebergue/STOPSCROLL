// StopScroll — Block Instagram Reels & Ads
// Hides Reels in the main feed, allows them on profiles & search but disables scroll.
// Uses visibility collapse (not display:none) to preserve layout flow.

(function() {
    'use strict';

    const MARK = 'data-ss';          // attribute to tag processed elements
    let observer = null;              // MutationObserver reference
    let debounceTimer = null;         // debounce timer for observer
    let scrollLockActive = false;     // whether reel scroll-lock is applied

    // ——— Page context helpers ———
    function isMainFeed() {
        const path = window.location.pathname;
        return path === '/' || path === '';
    }

    function isReelPage() {
        const path = window.location.pathname;
        // Match /reel/ID or /reels/ID (individual reel, singular or plural)
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

    function isExplorePage() {
        return window.location.pathname.startsWith('/explore');
    }

    // ——— Helper: collapse an element visually but keep it in layout flow ———
    function collapse(el) {
        if (!el || el.hasAttribute(MARK)) return;
        el.setAttribute(MARK, '1');
        el.style.cssText += ';visibility:hidden!important;height:0!important;min-height:0!important;max-height:0!important;overflow:hidden!important;margin:0!important;padding:0!important;border:0!important;opacity:0!important;pointer-events:none!important;';
    }

    // ——— Helper: fully hide small UI bits (nav tabs) ———
    function hide(el) {
        if (!el || el.hasAttribute(MARK)) return;
        el.setAttribute(MARK, '1');
        el.style.cssText += ';display:none!important;';
    }

    // ——— CSS layer ———
    const BLOCK_CSS = `
        /* Reels tab in bottom nav — match links that go exactly to /reels/ */
        a[href="/reels/"],
        a[href="/reels"] {
            display: none !important;
        }

        /* Reels aria labels */
        [aria-label="Reels"],
        [aria-label="reels"] {
            display: none !important;
        }

        /* Ad tracking iframes */
        iframe[src*="doubleclick"],
        iframe[src*="facebook.com/tr"] {
            display: none !important;
        }
    `;

    // ——— CSS injected on reel pages to lock scrolling ———
    const REEL_SCROLL_LOCK_CSS = `
        /* Prevent scrolling to next/previous reel — only on reel pages */
        html, body {
            overflow: hidden !important;
            overscroll-behavior: none !important;
            height: 100vh !important;
        }
        /* Lock scrollable containers but keep video interactive */
        main {
            overflow: hidden !important;
            overscroll-behavior: none !important;
        }
    `;

    function injectCSS() {
        if (document.getElementById('stopscroll-css')) return;
        const style = document.createElement('style');
        style.id = 'stopscroll-css';
        style.textContent = BLOCK_CSS;
        document.head.appendChild(style);
    }

    // ——— Reel scroll lock: prevents swiping to next reel (reel pages only) ———
    function applyScrollLock() {
        if (scrollLockActive) return;
        if (!isReelPage()) return;  // only lock scroll on /reel/ pages
        scrollLockActive = true;

        // Inject scroll-lock CSS
        if (!document.getElementById('stopscroll-reel-lock')) {
            const style = document.createElement('style');
            style.id = 'stopscroll-reel-lock';
            style.textContent = REEL_SCROLL_LOCK_CSS;
            document.head.appendChild(style);
        }

        // Block mouse wheel scroll
        document.addEventListener('wheel', blockWheel, { passive: false, capture: true });
        // Block keyboard scroll (arrow keys, space, page down)
        document.addEventListener('keydown', blockScrollKeys, { capture: true });
    }

    // ——— Hide suggested content below the main post/reel ———
    function hideExtraContent() {
        if (!isSingleContentPage()) return;

        // 1. Find "More posts like this" / "Suggested posts" headers and hide from there down
        //    Only check h2 and span with short own-text to avoid matching parent containers
        document.querySelectorAll('h2:not([' + MARK + ']), span:not([' + MARK + '])').forEach(el => {
            const ownText = el.childNodes.length <= 3 ? el.textContent?.trim().toLowerCase() : '';
            if (ownText === 'more posts like this' || ownText === 'related content' || ownText === 'suggested posts') {
                // Walk up a few levels to find the wrapper, but stay below main/body
                let wrapper = el.parentElement;
                for (let i = 0; i < 5 && wrapper; i++) {
                    if (wrapper.tagName === 'MAIN' || wrapper.tagName === 'BODY') break;
                    // Check if this wrapper is a sibling-level container (has siblings after it)
                    if (wrapper.nextElementSibling || wrapper.parentElement?.children.length > 1) {
                        break;
                    }
                    wrapper = wrapper.parentElement;
                }
                if (wrapper && wrapper.tagName !== 'MAIN' && wrapper.tagName !== 'BODY') {
                    // Hide this wrapper and all following siblings
                    let sibling = wrapper;
                    while (sibling) {
                        const next = sibling.nextElementSibling;
                        if (!sibling.hasAttribute(MARK)) {
                            sibling.setAttribute(MARK, '1');
                            sibling.style.cssText += ';display:none!important;';
                        }
                        sibling = next;
                    }
                }
            }
        });

        // 2. If there are multiple articles, keep only the first (the main post)
        const allArticles = document.querySelectorAll('article');
        if (allArticles.length > 1) {
            for (let i = 1; i < allArticles.length; i++) {
                if (!allArticles[i].hasAttribute(MARK)) {
                    allArticles[i].setAttribute(MARK, '1');
                    allArticles[i].style.cssText += ';display:none!important;';
                }
            }
        }

        // 3. For reel pages only: hide extra videos below the first
        if (isReelPage()) {
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
                        if (foundFirst && !child.hasAttribute(MARK)) {
                            child.setAttribute(MARK, '1');
                            child.style.cssText += ';display:none!important;';
                        }
                    }
                }
            }

            document.querySelectorAll('div[style*="snap"]').forEach(container => {
                const children = container.children;
                for (let i = 1; i < children.length; i++) {
                    if (!children[i].hasAttribute(MARK)) {
                        children[i].setAttribute(MARK, '1');
                        children[i].style.cssText += ';display:none!important;';
                    }
                }
            });
        }
    }

    function removeScrollLock() {
        if (!scrollLockActive) return;
        scrollLockActive = false;

        const lockStyle = document.getElementById('stopscroll-reel-lock');
        if (lockStyle) lockStyle.remove();

        document.removeEventListener('wheel', blockWheel, { capture: true });
        document.removeEventListener('keydown', blockScrollKeys, { capture: true });
    }

    function blockWheel(e) {
        e.preventDefault();
        e.stopPropagation();
    }

    const SCROLL_KEYS = new Set(['ArrowDown', 'ArrowUp', 'Space', ' ', 'PageDown', 'PageUp']);
    function blockScrollKeys(e) {
        if (SCROLL_KEYS.has(e.key)) {
            e.preventDefault();
            e.stopPropagation();
        }
    }

    // ——— Reels cleanup (only in main feed) ———
    function cleanReels() {
        // Hide the Reels nav tab — match only links whose href IS /reels/ or /reels (the tab)
        // Do NOT match /reels/XXXID (individual reel) or /reel/XXXID
        document.querySelectorAll('a[href="/reels/"]:not([' + MARK + ']), a[href="/reels"]:not([' + MARK + '])').forEach(el => {
            hide(el);
            const li = el.closest('li');
            if (li) hide(li);
            // Also walk up to the parent div that acts as a tab wrapper
            const tabWrapper = el.parentElement;
            if (tabWrapper && tabWrapper.children.length === 1) {
                hide(tabWrapper);
            }
        });

        // Only hide reel content when on the main feed
        if (!isMainFeed()) return;

        // "Reels" / "Suggested Reels" section headers in feed
        document.querySelectorAll('span:not([' + MARK + ']), h2:not([' + MARK + '])').forEach(el => {
            const text = el.textContent?.trim().toLowerCase();
            if (text === 'reels' || text === 'suggested reels' || text === 'reels and short videos') {
                const container = el.closest('section') || el.closest('article');
                if (container) collapse(container);
            }
        });

        // Reel links in feed articles
        document.querySelectorAll('article:not([' + MARK + ']) a[href*="/reel/"]').forEach(el => {
            const article = el.closest('article');
            if (article) collapse(article);
        });
    }

    // ——— Ad removal (works on all pages) ———
    function cleanAds() {
        document.querySelectorAll('article:not([' + MARK + '])').forEach(article => {
            const spans = article.querySelectorAll('span');
            for (const span of spans) {
                const t = span.textContent?.trim();
                if (t === 'Ad' || t === 'ad' || t === 'Sponsored' || t === 'sponsored') {
                    collapse(article);
                    break;
                }
            }
        });

        document.querySelectorAll('span:not([' + MARK + '])').forEach(el => {
            const t = el.textContent?.trim();
            if (t === 'Sponsored' || t === 'sponsored') {
                const container = el.closest('div[role="presentation"]') || el.closest('section');
                if (container) collapse(container);
            }
        });

        document.querySelectorAll('li:not([' + MARK + '])').forEach(li => {
            const spans = li.querySelectorAll('span');
            for (const span of spans) {
                const t = span.textContent?.trim();
                if (t === 'Sponsored' || t === 'Ad') {
                    collapse(li);
                    break;
                }
            }
        });

        document.querySelectorAll('iframe:not([' + MARK + '])').forEach(el => {
            const src = el.src || '';
            if (src.includes('doubleclick') || src.includes('facebook.com/tr')) {
                hide(el);
            }
        });
    }

    // ——— Scroll lock management based on current page ———
    function manageScrollLock() {
        if (isReelPage()) {
            applyScrollLock();
        } else {
            removeScrollLock();
        }

        // Hide suggested posts/reels below on any single content page
        if (isSingleContentPage()) {
            hideExtraContent();
        }

        // If somehow the user navigates to the Reels tab, redirect to home
        if (isReelsTab()) {
            window.location.href = '/';
        }
    }

    // ——— Limit explore/search grid to 10 posts ———
    const EXPLORE_POST_LIMIT = 10;
    function limitExploreGrid() {
        if (!isExplorePage()) return;

        // Instagram explore grid: rows of posts inside the main content area
        // Each clickable item is typically an anchor <a> with href /p/ or /reel/
        // They sit inside a grid of divs. Find all grid cells.
        const gridLinks = document.querySelectorAll('main a[href*="/p/"], main a[href*="/reel/"], main a[href*="/reels/"]');
        let count = 0;
        gridLinks.forEach(link => {
            // Find the grid cell wrapper (the parent that represents one tile)
            const cell = link.closest('div > div > div') || link.parentElement;
            if (!cell) return;

            count++;
            if (count > EXPLORE_POST_LIMIT) {
                if (!cell.hasAttribute(MARK)) {
                    cell.setAttribute(MARK, '1');
                    cell.style.cssText += ';display:none!important;';
                }
            }
        });

        // Also hide any rows that are now fully empty
        // And cut off loading of more content by hiding the scroll sentinel
        if (count > EXPLORE_POST_LIMIT) {
            // Try to find and hide the "load more" triggers at the bottom
            const footers = document.querySelectorAll('main > div > div > div:last-child, main footer');
            footers.forEach(el => {
                if (!el.querySelector('a[href*="/p/"]') && !el.hasAttribute(MARK)) {
                    // Don't hide nav or header, only blank trailing containers
                }
            });
        }
    }

    // ——— Combined cleanup ———
    function runCleanup() {
        if (observer) observer.disconnect();

        manageScrollLock();
        cleanReels();
        cleanAds();
        limitExploreGrid();

        if (observer) {
            observer.observe(document.body, { childList: true, subtree: true });
        }
    }

    // ——— Debounced observer ———
    function startObserver() {
        observer = new MutationObserver(() => {
            clearTimeout(debounceTimer);
            debounceTimer = setTimeout(runCleanup, 300);
        });

        observer.observe(document.body, {
            childList: true,
            subtree: true
        });
    }

    // ——— Watch for SPA navigation (URL changes without page reload) ———
    let lastPath = window.location.pathname;
    function watchNavigation() {
        setInterval(() => {
            const currentPath = window.location.pathname;
            if (currentPath !== lastPath) {
                lastPath = currentPath;
                runCleanup();
            }
        }, 500);
    }

    // ——— Init ———
    function init() {
        injectCSS();
        runCleanup();
        startObserver();
        watchNavigation();
        setInterval(runCleanup, 3000);
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
