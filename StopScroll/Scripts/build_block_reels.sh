#!/usr/bin/env bash
set -euo pipefail

mode="${1:---readable}"

case "$mode" in
	--readable)
		echo "[build_block_reels] Generating readable bundle"
		node StopScroll/Scripts/build_block_reels.mjs --readable
		;;
	--minify)
		echo "[build_block_reels] Generating minified bundle"
		node StopScroll/Scripts/build_block_reels.mjs --minify
		;;
	-h|--help)
		echo "Usage: ./StopScroll/Scripts/build_block_reels.sh [--readable|--minify]"
		echo "  --readable (default): keeps block_reels.js readable"
		echo "  --minify: requires terser installed (no auto-install)"
		;;
	*)
		echo "Unknown option: $mode" >&2
		echo "Use --help for usage." >&2
		exit 2
		;;
esac
