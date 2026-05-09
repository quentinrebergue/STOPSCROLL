# Instagram Architecture

This folder groups Instagram UI, support types, and WebView logic by responsibility.

## Structure

- `Core/InstagramView.swift`
- `Core/InstagramView+Actions.swift`
- `Support/InstagramViewSupport.swift`
- `Support/Core/XPProgress.swift`
- `Support/Core/SurfaceRouting.swift`
- `Support/Core/InstagramSecondaryRoute.swift`
- `Support/Components/DashboardView.swift`
- `Support/Components/InstagramUsernamePromptSheet.swift`
- `Support/Components/NativeInstagramTabBar.swift`
- `Support/Components/LoadingBar.swift`
- `Support/Components/XPDynamicIsland.swift`
- `WebView/InstagramWebView.swift`
- `WebView/InstagramWebViewScripts.swift`
- `WebView/InstagramWebView+Coordinator.swift`
- `WebView/Coordinator/InstagramWebView+Coordinator+Bridge.swift`
- `WebView/Coordinator/InstagramWebView+Coordinator+Wikipedia.swift`
- `WebView/Coordinator/InstagramWebView+Coordinator+Guardian.swift`
- `WebView/Coordinator/InstagramWebView+Coordinator+Navigation.swift`
- `WebView/Coordinator/InstagramWebView+Coordinator+Timer.swift`

## File roles

- `Core/InstagramView.swift`: Main screen composition and state wiring.
- `Core/InstagramView+Actions.swift`: Routing and action handlers extracted from the main view.
- `Support/InstagramViewSupport.swift`: Aggregation file kept intentionally small.
- `Support/Core/*`: Pure models/helpers (XP math, surface routing, secondary route mapping).
- `Support/Components/*`: Reusable SwiftUI components used by the Instagram view.
- `WebView/InstagramWebView.swift`: `UIViewRepresentable` shell and WebView lifecycle integration.
- `WebView/InstagramWebViewScripts.swift`: Script profile definitions and JS/bootstrap builders.
- `WebView/InstagramWebView+Coordinator.swift`: Coordinator core types/state (`LeakAvoider`, `Coordinator`, shared properties/init).
- `WebView/Coordinator/*`: Coordinator behavior split by concern:
	- Bridge and native message handling
	- Wikipedia/article pipeline
	- Guardian API pipeline
	- Navigation delegate and runtime active-state sync
	- Timer notifications

## Notes

- `InstagramView.swift` and `InstagramWebView.swift` stay the main entry points.
- The split is structural only: behavior should stay unchanged while reducing file size and merge conflicts.

## Card Decision Contract (V1)

- Feed card opportunity detection and DOM injection remain in injected JS.
- Card type decision is now requested from native Swift through `stopScrollBridge` action `requestCardForOpportunity`.
- Native returns a versioned payload (`contractVersion: 1`) with `decision`:
	- `inject` with `card.type` (rendered by existing JS builders)
	- `skip` when frequency gate/policy says no card
- JS keeps a timeout/availability fallback to legacy local decision (`card-logic`) to avoid empty injections when bridge is unavailable.
