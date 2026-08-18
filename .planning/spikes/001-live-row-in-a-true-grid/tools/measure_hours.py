#!/usr/bin/env python3
"""Pixel-measure the vertical distance between hour labels on the Today timeline.

This is the only measurement that can see Phase 27's defect. `flutter test`
cannot: 240dp and 372dp both satisfy every existing assertion, because no test
asserts that consecutive hour boundaries are equidistant — they assert
`yFor(x)` against the same arithmetic the implementation uses, live-row term
included. So the grid is verified against itself.

Method: the hour-axis labels ("8 AM", "9 AM", ...) are the only ink in the
timeline's left gutter (x < kGutterWidth = 40). Scan that column strip for rows
containing non-background pixels, group contiguous rows into label bands, and
report the centre-to-centre distance between consecutive bands. Each label box
is vertically centred on its hour's `yFor`, so band centre spacing IS hour
spacing.

Usage: measure_hours.py <png> [--gutter=40] [--top=200]
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
    gutter = int(opts.get("gutter", 40))
    # Skip the header block above the timeline (app bar, progress, date, chip).
    top = int(opts.get("top", 200))
    # Skip the bottom nav bar.
    bottom_trim = int(opts.get("bottomtrim", 90))

    img = Image.open(path).convert("RGB")
    w, h = img.size
    px = img.load()

    # Background = the most common colour in the gutter strip. Deriving it
    # rather than hard-coding it keeps this working in either theme.
    counts = Counter(
        px[x, y] for y in range(top, h - bottom_trim) for x in range(4, gutter)
    )
    bg = counts.most_common(1)[0][0]

    def differs(c):
        return sum(abs(a - b) for a, b in zip(c, bg)) > 40

    inked = [
        y
        for y in range(top, h - bottom_trim)
        if any(differs(px[x, y]) for x in range(4, gutter))
    ]

    bands = []
    for y in inked:
        if bands and y - bands[-1][-1] <= 3:
            bands[-1].append(y)
        else:
            bands.append([y])
    # A real label is several rows of glyph ink, not a stray antialiased pixel.
    bands = [b for b in bands if len(b) >= 4]

    print(f"{path}")
    print(f"  size={w}x{h} bg={bg} gutter=0..{gutter} scan={top}..{h - bottom_trim}")
    centres = [(b[0] + b[-1]) / 2 for b in bands]
    for b, c in zip(bands, centres):
        print(f"  label band rows {b[0]}..{b[-1]}  centre={c:.1f}  height={len(b)}")
    if len(centres) < 2:
        print("  !! fewer than 2 label bands found — nothing to compare")
        return 2
    print("  hour-to-hour spacing:")
    gaps = [centres[i + 1] - centres[i] for i in range(len(centres) - 1)]
    for i, g in enumerate(gaps):
        print(f"    band {i} -> {i + 1}: {g:.1f} px")
    spread = max(gaps) - min(gaps)
    print(f"  min={min(gaps):.1f} max={max(gaps):.1f} spread={spread:.1f}")
    print(f"  VERDICT: {'UNIFORM' if spread <= 2.0 else 'NOT UNIFORM'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
