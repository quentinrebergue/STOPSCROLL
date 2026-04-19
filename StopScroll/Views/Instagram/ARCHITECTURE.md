# Instagram Architecture

This folder groups the Instagram UI and WebView integration by responsibility.

## Structure

- `Core/InstagramView.swift`
- `Support/InstagramViewSupport.swift`
- `WebView/InstagramWebView.swift`
- `WebView/InstagramWebViewScripts.swift`

## File roles

- `Core/InstagramView.swift`: Main screen orchestration (surface mounting, native tab routing, overlays, XP flow, settings/dashboard transitions).
- `Support/InstagramViewSupport.swift`: Supporting UI and routing models extracted from the main file (XP utilities, tab bar, loading bar, dashboard, route helpers, transition helpers).
- `WebView/InstagramWebView.swift`: WKWebView wrapper + Coordinator (bridge handling, navigation events, article opening pipeline, runtime sync).
- `WebView/InstagramWebViewScripts.swift`: Script/profile configuration and JavaScript builders extracted from the webview core.

## Notes

- The split keeps behavior unchanged while reducing file size and merge conflicts.
- `InstagramView.swift` and `InstagramWebView.swift` remain primary entry points.
