#!/usr/bin/env python3
"""Static server for the RELEASE web build, tuned for running Canopy as an
installed home-screen app (PWA) rather than for one-off UAT.

Why this exists alongside tools/serve-uat.py — they want OPPOSITE things:

  serve-uat.py  sends `Cache-Control: no-store` on everything, because during
                UAT the only thing that matters is that a rebuild is seen
                immediately (CLAUDE.md trap #3). It is deliberately hostile to
                caching, and it has no service worker to coexist with.

  serve-pwa.py  serves a build whose service worker OWNS the offline cache.
                `no-store` there is wrong twice over: it fights the service
                worker's own caching, and it defeats the offline behaviour that
                is the entire reason to install the app on a phone.

The rule that actually matters for updates, and the reason this is not just
`python3 -m http.server`:

  * The three "entry point" files must REVALIDATE on every load, or a rebuild
    never reaches the phone. `http.server` sends no `Cache-Control` at all,
    which lets the browser apply heuristic caching to index.html and to
    flutter_service_worker.js — and a stale service worker will keep serving a
    stale app shell indefinitely, offline-first, with no way for the user to
    tell. That is trap #3 wearing a PWA costume: the server has the new bytes,
    the phone shows the old app, and nothing looks broken.

  * Everything else (main.dart.js, assets, fonts, icons) is safe to cache. The
    Flutter service worker versions the app shell itself and re-fetches these
    when its version hash changes, so long-lived caching here is correct and is
    what makes a cold launch fast on a phone.

Usage:
    python3 tools/serve-pwa.py <port> --dir build/web [--host 127.0.0.1]

Bind loopback (the default) when fronting this with `tailscale serve`, which
proxies from 127.0.0.1 and supplies the real TLS certificate. iOS will not
install a home-screen app with a service worker over plain HTTP — a service
worker requires a secure context — so HTTPS is not optional for this use.
"""

import argparse
import functools
import http.server
import os
import sys

# Files that must always be revalidated. These are the app's entry points; if
# any of them is served stale, the phone is pinned to an old build.
ALWAYS_REVALIDATE = frozenset(
    {
        "/",
        "/index.html",
        "/flutter_service_worker.js",
        "/flutter_bootstrap.js",
        "/manifest.json",
        "/version.json",
    }
)

# Long, but not immutable: the build emits these at stable paths (no content
# hash in the filename), so `immutable` would be a lie the browser could hold
# us to across a rebuild. One hour is long enough to make a cold launch fast
# and short enough that a stuck client self-heals without clearing storage.
CACHEABLE_MAX_AGE = 3600


class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        path = self.path.split("?", 1)[0].split("#", 1)[0]
        if path in ALWAYS_REVALIDATE:
            self.send_header("Cache-Control", "no-cache, must-revalidate")
        else:
            self.send_header("Cache-Control", f"public, max-age={CACHEABLE_MAX_AGE}")

        # NOTE: COOP/COEP headers were tried here and REMOVED on 2026-09-10.
        # They are only needed for SharedArrayBuffer, which Canopy does not use,
        # and they were the first suspect when the service worker failed to
        # register. Do not add them back "for correctness" without re-testing
        # service-worker registration — see the SW note in the module docstring.
        super().end_headers()

    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("port", type=int)
    ap.add_argument("--dir", default="build/web")
    ap.add_argument(
        "--host",
        default="127.0.0.1",
        help="default loopback; `tailscale serve` fronts it with TLS",
    )
    args = ap.parse_args()

    root = os.path.abspath(args.dir)
    if not os.path.isdir(root):
        sys.exit(f"ERROR: {root} does not exist — run `flutter build web --release` first.")
    if not os.path.exists(os.path.join(root, "flutter_service_worker.js")):
        sys.exit(
            f"ERROR: {root} has no flutter_service_worker.js.\n"
            "That means this is a --pwa-strategy=none (debug/UAT) build, which "
            "cannot be installed as a home-screen app. Use tools/serve-uat.py "
            "for those, and build with `flutter build web --release` for this."
        )

    handler = functools.partial(Handler, directory=root)
    httpd = http.server.ThreadingHTTPServer((args.host, args.port), handler)
    print(f"serving {root} on http://{args.host}:{args.port}", file=sys.stderr)
    httpd.serve_forever()


if __name__ == "__main__":
    main()
