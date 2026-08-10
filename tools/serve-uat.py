#!/usr/bin/env python3
"""Static server for hosted UAT builds — like `python3 -m http.server`, but
never lets the browser cache the bundle.

Why this exists: `http.server` sends no `Cache-Control` header. Browsers are
then free to apply *heuristic* caching (typically a fraction of the file's
age since `Last-Modified`) and serve a stale `main.dart.js` without ever
revalidating. On a 13 MB Flutter debug bundle that reliably means you rebuild,
reload, and still see the previous build — and reasonably conclude the change
did not land. That happened during Phase 25's UAT and cost a round trip.

`no-store` is deliberate rather than `no-cache` or an ETag: this serves a
single large bundle to one or two people over a tailnet, so the bandwidth is
irrelevant next to the cost of ever debugging a phantom stale build again.

Usage:
    python3 tools/serve-uat.py <port> [--dir build/web]

Do NOT use this for anything user-facing — it defeats caching by design.
"""

import argparse
import functools
import http.server
import os
import sys


class NoStoreHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    def send_head(self):
        # Drop conditional-request validators before the base class sees them.
        # A browser holding a pre-existing cache entry (created before this
        # server started sending no-store) can still send If-Modified-Since,
        # and SimpleHTTPRequestHandler would happily answer 304 Not Modified —
        # re-serving the stale bundle this script exists to prevent. Removing
        # the headers forces a full 200 with the current bytes.
        for validator in ("If-Modified-Since", "If-None-Match"):
            if self.headers.get(validator) is not None:
                del self.headers[validator]
        return super().send_head()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("port", type=int)
    parser.add_argument("--dir", default="build/web")
    parser.add_argument("--bind", default="0.0.0.0")
    args = parser.parse_args()

    if not os.path.isdir(args.dir):
        print(f"error: {args.dir} does not exist — run a build first", file=sys.stderr)
        return 1

    handler = functools.partial(NoStoreHandler, directory=args.dir)
    server = http.server.ThreadingHTTPServer((args.bind, args.port), handler)
    print(f"serving {args.dir} on {args.bind}:{args.port} with Cache-Control: no-store")
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
