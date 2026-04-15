// Global constants exposed via window.StopScroll.constants.
(function (global) {
    'use strict';

    const ns = (global.StopScroll = global.StopScroll || {});

    ns.constants = {
        RELOAD_BUTTON_ID: 'ss-reload-floating-button',
        RELOAD_NAV_BTN_ID: 'ss-reload-nav-btn',
        TOP_MENU_ID: 'ss-top-menu',
        TOP_MENU_CONTAINER_ID: 'ss-menu-container',
        SPONSORED_LABELS: [
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
        ],
        SCROLL_KEYS: new Set(['ArrowDown', 'ArrowUp', 'Space', ' ', 'PageDown', 'PageUp']),
        DEFAULT_CONFIG: {
            feed_injection: {
                enabled: true,
                ad_replacement: true,
                max_dynamic_posts_per_session: 30
            },
            cards: {
                every_n_opportunities: 3,
                metrics: { enabled: true, weight: 20 },
                mood:    { enabled: true, weight: 15 },
                timer:   { enabled: true, weight: 10 },
                stop:    { enabled: true, weight: 30 },
                stats:   { enabled: true, weight: 30 }
            },
            captions: [
                'Your time is the most valuable thing you own.',
                'Every minute here is a minute not spent on what matters.',
                'You don\'t need one more scroll. You need one deep breath.',
                'The best version of you isn\'t on this app.',
                'Scrolling never made anyone feel better after 10 minutes.'
            ],
            reload: {
                floating_button_enabled: true
            },
            card_templates: {
                metrics_title: 'Session snapshot',
                metrics_body: 'You skipped {skipped} dopamine loops and protected {minutes} min of focus.',
                mood_title: 'How do you feel right now?',
                mood_a1: "I'm enjoying the scroll",
                mood_r1: 'Pleasure is valid — just stay aware of time.',
                mood_a2: 'I feel a bit guilty about it',
                mood_r2: 'That awareness is already a superpower.',
                mood_a3: "I have things to do but I'm stuck",
                mood_r3: 'Your instincts are right. One small step counts.',
                mood_a4: 'I had a rough day and needed this',
                mood_r4: 'Rest matters. Make sure this is rest, not avoidance.',
                mood_a5: 'Something else',
                mood_r5: "Whatever it is — you noticed. That's what counts.",
                mood_undo: 'Undo',
                stop_title: 'Stop plan',
                stop_body: 'Set a concrete stop point now and switch to intentional time.'
            }
        },
        DEFAULT_STATE: {
            config: null,
            opportunities: 0,
            shownCards: 0,
            byTypeCount: {
                metrics: 0,
                mood: 0,
                timer: 0,
                stop: 0,
                stats: 0
            },
            seenPosts: new WeakSet(),
            periodicScanTimer: null,
            scanScheduled: false,
            scrollLockActive: false
        }
    };
})(window);
