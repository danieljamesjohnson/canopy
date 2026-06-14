#!/usr/bin/env bash
#
# Serve a single-bundle DEBUG web build for tailnet (danserver) UAT.
#
# WHY this exists / WHY NOT `flutter run -d web-server --debug`:
#   `flutter run -d web-server` uses the DDC incremental compiler, which fans the
#   app out into ~866 separate JS module files. Over tailscale latency the
#   browser's ~6-connections-per-origin limit turns that into minutes of serial
#   round-trips -> blue loading strip -> white. It only "worked before" when the
#   app was small (few modules); it has outgrown that approach.
#   `flutter build web --debug` is ONE dart2js bundle -> a single request -> loads
#   reliably over the network, while still being a real debug build (assertions on,
#   DEBUG banner, source-mapped stack traces). See CLAUDE.md "Local hosting for UAT".
#
# Usage:  scripts/serve-debug-web.sh [port]   (default port 8098)
#
set -euo pipefail

PORT="${1:-8098}"
cd "$(dirname "$0")/.."

# danserver keeps flutter/dart outside the default PATH.
if ! command -v flutter >/dev/null 2>&1 && [ -x "$HOME/development/flutter/bin/flutter" ]; then
  export PATH="$HOME/development/flutter/bin:$PATH"
fi

echo "==> Building single-bundle debug web (assertions + DEBUG banner + source maps, no service worker)"
flutter build web --debug --source-maps --pwa-strategy=none

# Free the port so re-runs are clean (fuser is best-effort; ignore if absent).
fuser -k "${PORT}/tcp" 2>/dev/null || true
sleep 1

echo "==> Serving build/web at http://danserver:${PORT}/  (Ctrl-C to stop)"
echo "    NOTE: only ever serve a DEBUG build on this port. A release build's"
echo "    service worker on the same origin will cache-collide -> blank page."
cd build/web
exec python3 -m http.server "${PORT}" --bind 0.0.0.0
