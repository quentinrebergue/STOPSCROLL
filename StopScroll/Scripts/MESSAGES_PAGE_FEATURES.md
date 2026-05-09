# Messages Page - Required Features (Rebuild Plan)

Current status
- JS injection is intentionally disabled on messages/chat surface.
- Existing scripts remain in repository for future rewrite.

Must-have features for messages page
1. Native navigation safety
- Do not break Instagram chat gestures (vertical scroll, media scrub, swipe back).
- Never trigger cross-surface tab swipe from chat content.

2. Stable route awareness
- Detect inbox route and thread route reliably:
- /direct/inbox/
- /direct/t/{threadId}/
- Emit lightweight route state to native only when route changes.

3. Header conflict handling
- Optional and minimal: hide only conflicting header controls when necessary.
- No broad selector sweep; selectors must be scoped and version-tolerant.

4. Message badge sync
- Read unread badge count safely from native tab DOM when available.
- Fallback to 0 without throwing.

5. Theme sync
- Detect IG background/theme changes and notify native.
- Debounce updates and avoid noisy bridge events.

6. Performance constraints
- No MutationObserver over full document by default.
- Prefer route-change hooks + targeted queries.
- Hard cap polling frequency when polling is unavoidable.

7. Error isolation
- Every injected block must be try/catch wrapped.
- Bridge debug logs must include category + short code + context path.

8. Kill switch
- Runtime flag to disable messages injection remotely (or via app setting).

9. Test coverage targets
- Unit tests for route detection and badge parsing.
- Unit tests for no-op behavior on unsupported DOM.
- UI tests for opening inbox/thread without navigation regressions.

Non-goals for first rewrite
- Feed card injection in messages surface.
- Reel lock behavior in messages surface.
- Heavy DOM rewrites of message thread layout.
