# Scripts Architecture

This folder contains the JavaScript runtime used by the Instagram WebView integration.

## Top-Level Overview

- `block_reels_entry.js`: Readable bootstrap entry with import order for runtime modules.
- `block_reels.js`: Generated bootstrap consumed by Swift (`InstagramWebViewScripts`).
- `build_block_reels.mjs`: Build tool that strips imports from entry and writes `block_reels.js`.
- `build_block_reels.sh`: Shell wrapper for readable/minified build modes.
- `dynamic_feed_config.yaml`: Dynamic feed injection configuration consumed at runtime.
- `modules/`: Domain modules loaded by Swift before bootstrap.
- `runtime/`: Runtime orchestration layer (state, scanning loop, UI application).

## modules/

### modules/core/

- `constants.js`: Shared constants used across modules.
- `config.js`: Runtime config loading and normalization.
- `dom-utils.js`: DOM helpers and low-level utility methods.

### modules/navigation/

- `nav-management.js`: Native tab sync and navigation state bridge.
- `page-manager.js`: Page-level policy handling and route/page checks.
- `scroll-lock.js`: Scroll/reel locking behavior.
- `top-menu.js`: Top menu behavior integration.

### modules/feed/

- `ad-detection.js`: Detects sponsored/ad patterns in feed content.
- `card-logic.js`: Card decision logic and candidate selection rules.
- `card-injection.js`: Injects cards into feed using decisions from card logic.

### modules/analytics/

- `session-stats.js`: Session counters/metrics tracking.
- `tracking.js`: Event tracking hooks and telemetry glue.

### modules/knowledge/

- `wikipedia.js`: Wikipedia article bridge and UI hooks.
- `guardian.js`: Guardian article bridge and UI hooks.

### modules/card-builder/

- `card-builder-helpers.js`: Shared helper utilities for card building.
- `card-metrics.js`: Metrics card builder logic.
- `card-mood.js`: Mood card builder logic.
- `card-timer.js`: Timer card builder logic.
- `card-stop.js`: Stop/break card builder logic.
- `card-stats.js`: Stats card builder logic.
- `card-book.js`: Book card builder logic.
- `card-culture.js`: Culture card builder logic.
- `card-builder.js`: Main card-builder orchestrator.

## runtime/

- `runtime-state.js`: Creates and updates runtime state container.
- `runtime-ui.js`: Applies UI and navigation injections based on state.
- `runtime-scan.js`: Scheduling/scan loop and runtime tracking wiring.

## Load Flow

1. Swift loads module scripts from `modules/` in dependency order.
2. Swift loads bootstrap `block_reels.js`.
3. Bootstrap initializes runtime state and starts scan scheduling.
4. Runtime modules cooperate to detect targets, inject cards, and sync UI/nav state.
