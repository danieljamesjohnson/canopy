# Phase 29 Plan 04 — Human UAT

**Served at:** `http://danserver:8143/`
**Debug build** (`flutter build web --debug --source-maps --pwa-strategy=none`), served via
`python3 tools/serve-uat.py 8143 --dir build/web` (never `python3 -m http.server` — CLAUDE.md trap
#3). Port 8143 has served debug builds only, this phase and 29-03.

## Pre-flight — served bytes match built bytes (T-29-05 / PD-29-05)

Checked after Task 1's rebuild, again after Task 2's doc-comment-only `lib/` edit (rebuilt to be
certain rather than assume a comment change can't affect dart2js output — it didn't; both hashes
below are identical to Task 1's), and a third time immediately before presenting this checkpoint.

```
$ curl -s http://localhost:8143/main.dart.js | sha256sum
12ba918e2a3e0e4dd4533a5c76c2d2f8619ece375cb5e9285a96eea6f4b67d07  -
$ sha256sum build/web/main.dart.js
12ba918e2a3e0e4dd4533a5c76c2d2f8619ece375cb5e9285a96eea6f4b67d07  build/web/main.dart.js
```

**Identical.** The build you are about to judge is the build that was measured in Tasks 1 and 2.

---

## Already verified automatically (you do not need to re-check these)

- The timeline's hour spacing is still uniform with the sub-compact tier rendering
  (`measure_hours.py`: `VERDICT: UNIFORM`, 240.0/240.0px spacing, spread 0.0).
- The sub-compact break row's painted ink (10px) fits comfortably inside its 20dp slot.
- The 25-minute work card's own fit inside its 100dp slot has been re-measured in the browser
  (90px ink extent, DISMISSED — not a real clipping defect).

## What automation cannot tell us, and why you are being asked

`flutter test`'s font has no real glyph metrics, so it can call a break legible when it is not;
headless Chromium can blank the canvas outright and return a screenshot that reads as either a
pass or a false failure. Phase 27 scored 16 of 17 automated checks and then failed 2 of 3 on
exactly this kind of look.

---

## Item 1 — Does a 5-minute break read as a break?

Scroll through the morning. Between two work cards there should be a thin line with "Short break"
sitting on it. The question is not "can I find it" — it is: glancing at the day, does that row say
*break*, or does it read as a divider, a separator, or the edge of the card above it? If it reads
as a divider, say so plainly; that is the exact complaint that opened this phase and a near-miss is
a fail here.

**Verdict:**

## Item 2 — Is the label actually legible at this size?

Look at the words themselves, not the layout. Is "Short break" cut off at the top or bottom,
crowded by the cards above and below, or too faint against the background? Try it once at a larger
system text scale. If the text is fine but feels weak, say which: too small, too pale, or too
tight.

**Verdict:**

## Item 3 — Does the day still look right around it?

Scroll a full day. Hour brackets should all look the same height. Nothing should overlap, no card
should be clipped mid-glyph, and a 30-minute long break should still look clearly heavier than a
5-minute one. If a long break and a short break ever sit next to each other, they should not read
as the same thing.

**Verdict:**

---

Worth a glance while you are there: what a 5-minute break looks like while it is the *current*
activity (the live row has its own separate treatment from Phase 27 and is deliberately not
changed by this phase) — if the two now disagree in a way that looks wrong, that is worth
recording even though it is out of scope.

## Remedies if item 1 fails

In order: raise the label's contrast or weight within the existing `onSurfaceVariant`/`bodySmall`
contract, or revisit the sub-compact layout. **Off the table:** raising `kPixelsPerMinute` (D-03,
rejected on evidence) and letting the card exceed its slot (D-05). Any failure routes to a
gap-closure plan, not a fix inside this checkpoint.
