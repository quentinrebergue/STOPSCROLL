// Scroll session statistics exposed via window.StopScroll.sessionStats.
//
// Session model:
//   - First scroll event starts the session clock.
//   - Every subsequent scroll extends the session.
//   - If no scroll is detected for 5 minutes the NEXT scroll starts a fresh
//     session (timer, post count and ad count all reset to zero).
//
// Usage from other modules:
//   ns.sessionStats.onScrollActivity()  — call on every scroll event
//   ns.sessionStats.trackPost()         — call for every new article found
//   ns.sessionStats.trackAd()           — call for every article confirmed as ad
//   ns.sessionStats.getStats()          — returns { sessionSeconds, posts, ads }
(function (global) {
  'use strict';

  var ns = (global.StopScroll = global.StopScroll || {});

  var INACTIVITY_MS = 5 * 60 * 1000; // 5 minutes

  var sessionStart = null;
  var lastScrollAt = null;
  var sessionPosts = 0;
  var sessionAds   = 0;

  // Reel session tracking (separate counter — resets with the feed session)
  var reelSessionStart = null;
  var reelCount = 0;

  /**
   * Must be called on every scroll / touch-move event.
   * Starts a new session if the user was inactive for > 5 minutes.
   */
  function onScrollActivity() {
    var now = Date.now();
    if (!lastScrollAt || (now - lastScrollAt) > INACTIVITY_MS) {
      // Either first scroll ever, or user returned after a long break
      sessionStart = now;
      sessionPosts = 0;
      sessionAds   = 0;
      reelSessionStart = null;
      reelCount = 0;
    }
    lastScrollAt = now;
  }

  /**
   * Increment the "posts seen" counter for the current session.
   * Silently ignored if no active session (user hasn't scrolled yet).
   */
  function trackPost() {
    if (lastScrollAt && (Date.now() - lastScrollAt) < INACTIVITY_MS) {
      sessionPosts += 1;
    }
  }

  /**
   * Increment the "ads seen" counter for the current session.
   * Only counts articles that were confirmed as sponsored/ad posts.
   */
  function trackAd() {
    if (lastScrollAt && (Date.now() - lastScrollAt) < INACTIVITY_MS) {
      sessionAds += 1;
    }
  }

  /**
   * Call each time a reel card is shown. Starts the reel session timer
   * on first call and increments the reel counter.
   */
  function trackReel() {
    if (!reelSessionStart) { reelSessionStart = Date.now(); }
    reelCount += 1;
  }

  /**
   * Returns reel-specific stats for the current session.
   * @returns {{ reelCount: number, reelSeconds: number }}
   */
  function getReelStats() {
    var secs = reelSessionStart ? Math.floor((Date.now() - reelSessionStart) / 1000) : 0;
    return { reelCount: reelCount, reelSeconds: secs };
  }

  /**
   * Returns a snapshot of the current session stats.
   * @returns {{ sessionSeconds: number, posts: number, ads: number }}
   */
  function getStats() {
    var secs = sessionStart ? Math.floor((Date.now() - sessionStart) / 1000) : 0;
    return { sessionSeconds: secs, posts: sessionPosts, ads: sessionAds };
  }

  ns.sessionStats = {
    onScrollActivity: onScrollActivity,
    trackPost: trackPost,
    trackAd: trackAd,
    trackReel: trackReel,
    getStats: getStats,
    getReelStats: getReelStats
  };
})(window);
