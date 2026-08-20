#!/usr/bin/env python3
"""Pixel-count a bounded window's ink extent — the outer height of whatever
non-background content (text, a stroked/dashed border, or both) occupies a
scan region.

Why this exists, and why `flutter test` cannot answer the same question:
`flutter test`'s placeholder font has no real Roboto metrics (this project's
own `kGutterWidth` doc comment: `'1'`, `'i'`, `'W'`, `':'`, `'p'` all measure
exactly 12.0px at fontSize 12), so any text-driven height taken there is a
harness bound, not a device requirement. Worse, for THIS specific measurement
(kSubCompactBreakMinHeight, plan 29-03): a widget-test `tester.getSize()` call
returns a card's *box* height, not what actually painted — a child that
overflows its `Positioned` slot and gets silently clipped by `ClipRect`
produces an identical `heightFor()`/`getSize()` return value regardless of
whether anything was actually cut off. Only a rendered screenshot, pixel-
counted, can see a real clip.

Method, adapted from `.planning/spikes/001-live-row-in-a-true-grid/tools/
measure_hours.py`'s derive-the-background-then-flag-differing-pixels
approach (NOT `measure_card_fill.py`'s saturated-fill-colour approach — that
script targets `LiveRowCard`'s solid `primaryContainer` background, and the
non-live break card here has no solid fill at all, only a dashed
`outlineVariant` stroke, so there is no fill colour to derive):

1. Derive the background colour from the scan window itself (most common
   colour in a `Counter`), so the script survives a theme change instead of
   hard-coding a colour.
2. Flag every row in `[top, bottom)` containing at least one pixel in
   `[x0, x1)` that differs from the background beyond a small tolerance
   ("ink") — this catches BOTH the dashed border's stroke pixels and the
   label text's glyph pixels, whichever is present.
3. Group contiguous inked rows into bands, bridging small gaps (default 3
   rows) so a DASHED outline — deliberately non-contiguous by construction —
   does not get split into many tiny bands or dropped below a minimum-size
   filter. A dashed border's gaps can be wider than a solid stroke's
   antialiasing gaps, so `--bridge` may need retuning per screenshot; do not
   assume `measure_hours.py`'s tuning transfers unmodified.
4. Print each band (first row, last row, height), then print, last and
   plainly, the OVERALL ink extent: the first inked row to the last inked
   row across every band, and `last - first + 1`. That overall extent is
   the outer height of the card (top border to bottom border, or top of the
   text to bottom of the text if no border band is present) — the number
   that gets copied into a doc comment.

Two intended targets (PD-29-04, `29-03-PLAN.md`): the forced-`compact`
break card here (plan 29-03), and the 25-minute work card's fit check
(plan 29-04). A break-specific script name would be wrong for the second
use; this one is deliberately generic.

Usage:
    measure_card_extent.py <png> [--x0=60] [--x1=<width-16>] [--top=N]
                            [--bottom=N] [--bridge=3] [--minband=1] [--tol=40]
"""
import sys
from collections import Counter

from PIL import Image


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict(
        a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a
    )
    if not args:
        print(__doc__)
        return 1

    path = args[0]
    img = Image.open(path).convert("RGB")
    w, h = img.size
    px = img.load()

    x0 = int(opts.get("x0", 60))
    x1 = int(opts.get("x1", w - 16))
    top = int(opts.get("top", 0))
    bottom = int(opts.get("bottom", h))
    bridge = int(opts.get("bridge", 3))
    minband = int(opts.get("minband", 1))
    tol = int(opts.get("tol", 40))

    top = max(0, top)
    bottom = min(h, bottom)
    x0 = max(0, x0)
    x1 = min(w, x1)

    # Derive the background colour from the scan window itself.
    counts = Counter(px[x, y] for y in range(top, bottom) for x in range(x0, x1))
    bg = counts.most_common(1)[0][0]

    def differs(c):
        return sum(abs(a - b) for a, b in zip(c, bg)) > tol

    inked = [
        y for y in range(top, bottom) if any(differs(px[x, y]) for x in range(x0, x1))
    ]

    bands = []
    for y in inked:
        if bands and y - bands[-1][-1] <= bridge:
            bands[-1].append(y)
        else:
            bands.append([y])
    bands = [b for b in bands if len(b) >= minband]

    print(f"{path}")
    print(
        f"  size={w}x{h} bg={bg} x0={x0} x1={x1} scan={top}..{bottom} "
        f"bridge={bridge} minband={minband} tol={tol}"
    )
    if not bands:
        print("  !! no ink found in scan window")
        return 2

    for b in bands:
        print(f"  band rows {b[0]}..{b[-1]}  height={b[-1] - b[0] + 1}")

    first = bands[0][0]
    last = bands[-1][-1]
    extent = last - first + 1
    print(f"  OVERALL INK EXTENT: rows {first}..{last}  height={extent}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
