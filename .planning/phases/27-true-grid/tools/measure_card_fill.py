#!/usr/bin/env python3
"""Pixel-count the live row's `primaryContainer` fill band height.

This is the real-browser half of plan 27-04's `kCompactLiveMinHeight`
re-measurement (`27-UI-SPEC.md` "The threshold constant and where it lives",
recipe steps 5-7). `flutter test` cannot answer this question: its
placeholder font has no real Roboto metrics (`kGutterWidth`'s own doc comment
records `'1'`/`'i'`/`'W'`/`':'`/`'p'` all measuring 12.0px at fontSize 12), so
any claim about how tall the live card's content actually renders has to come
from pixels, not from a widget-test `RenderBox` size.

Method, mirroring `measure_hours.py`'s band-detection approach rather than
reinventing it: the live row is the only `primaryContainer`-filled region in
the card region (x >= --gutter), and that colour is visibly saturated AND
light/pastel next to the app's mostly-neutral backgrounds, other cards'
surfaces, and the ordinary (non-live) rows' DARKER `colorScheme.primary`
`FilledButton`s. So the fill colour is DERIVED from the image — the most
common colour in the scanned strip that is both saturated (channel spread >
--sat) and light (minimum channel > --light) — never hard-coded, so this
script survives a theme change the same way `measure_hours.py`'s derived
background does.

For each row in the scan strip, the row counts as "filled" if ANY pixel in
it is close to that derived fill colour. Contiguous filled rows are grouped
into bands, bridging small gaps (<=3 rows) so the now-line's own 2dp stroke
crossing the card — which locally interrupts the fill colour with the
stroke's `colorScheme.primary` — does not split one card into two bands.

Usage: measure_card_fill.py <png> [--gutter=40] [--top=200] [--bottommargin=90]
                             [--sat=15] [--light=100] [--tol=12]
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
    bottom_trim = int(opts.get("bottommargin", 90))
    sat_threshold = int(opts.get("sat", 15))
    tol = int(opts.get("tol", 12))

    img = Image.open(path).convert("RGB")
    w, h = img.size
    px = img.load()

    right = w - 4
    scan_bottom = h - bottom_trim

    # Derive the fill colour: the most common colour in the card-region strip
    # (x in [gutter, right), y in [top, scan_bottom)) that is both visibly
    # saturated (max channel - min channel > sat_threshold) AND light/pastel
    # (min channel > light_threshold). The saturation filter alone is not
    # enough to pick out `primaryContainer` specifically — measured directly
    # against the single-line-tier screenshot, the naive "most common
    # saturated colour" picked (16, 107, 87), the ordinary (non-live)
    # ChunkCard's `FilledButton` background (`colorScheme.primary`, a DARK
    # saturated tone), because four full-size ordinary Complete buttons
    # outnumber one thin live-row strip in raw pixel count. Material 3's
    # "Container" roles are deliberately light/pastel tones next to their
    # darker "primary"/"secondary" accents in a light-seeded theme, so
    # requiring high lightness (a high minimum channel value) discriminates
    # `primaryContainer` from `primary` generically, without hard-coding
    # either colour.
    counts = Counter(
        px[x, y]
        for y in range(top, scan_bottom)
        for x in range(gutter, right, 2)
    )
    light_threshold = int(opts.get("light", 100))
    candidates = [
        (c, n)
        for c, n in counts.items()
        if (max(c) - min(c)) > sat_threshold and min(c) > light_threshold
    ]
    if not candidates:
        print("  !! no light, saturated fill colour found in the scan region")
        return 2
    candidates.sort(key=lambda t: -t[1])
    fill = candidates[0][0]

    def close(c):
        return sum(abs(a - b) for a, b in zip(c, fill)) <= tol

    filled_rows = [
        y
        for y in range(top, scan_bottom)
        if any(close(px[x, y]) for x in range(gutter, right, 2))
    ]

    bands = []
    for y in filled_rows:
        if bands and y - bands[-1][-1] <= 3:
            bands[-1].append(y)
        else:
            bands.append([y])

    print(f"{path}")
    print(
        f"  size={w}x{h} fill={fill} gutter={gutter}.. scan={top}..{scan_bottom}"
    )
    if not bands:
        print("  !! no fill band found")
        return 2
    heights = []
    for b in bands:
        height = b[-1] - b[0] + 1
        heights.append(height)
        print(f"  fill band rows {b[0]}..{b[-1]}  height={height}")
    tallest = max(heights)
    print(f"  TALLEST FILL BAND HEIGHT: {tallest} px")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
