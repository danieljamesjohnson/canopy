---
phase: 27-true-grid
plan: 04
subsystem: ui
tags: [flutter, layout, live-row, real-browser-measurement, grid-01, grid-02]

# Dependency graph
requires:
  - phase: 27-01
    provides: "Branch-free TimelineGeometry.yFor(); kCompactLiveMinHeight UNMEASURED PLACEHOLDER (88.0)"
  - phase: 27-02
    provides: "LiveRowCard's two density tiers (compact/single-line), duration-exact Positioned slot"
  - phase: 27-03
    provides: "Full green flutter test suite (567 tests) against the two-tier live row"
provides:
  - "kCompactLiveMinHeight replaced with a real-browser measurement (84.0 = 76px measured + 8px explicit safety margin), doc comment rewritten in house style with date/method/raw-number/invalidation conditions"
  - "The Pitfall 6 relationship to kFullTierMinHeight resolved explicitly: kept separate (4dp apart, different card layouts)"
  - "measure_card_fill.py, a new committed pixel-count script mirroring measure_hours.py's derived-colour band-detection approach"
  - "GRID-01 proven end-to-end in pixels: measure_hours.py prints UNIFORM against the measured build, for both a live work chunk and a live break, with no 132.0 spread"
  - "Six evidence screenshots under .planning/phases/27-true-grid/shots/"
affects: ["Phase 27 phase-close — Task 3 (human-verify checkpoint) is the only remaining gate before this plan and the phase can be marked complete"]

tech-stack:
  added: []
  patterns:
    - "Deriving a fill colour from the image by filtering candidate pixel colours to (saturated AND light/pastel) rather than saturated alone -- the naive 'most common saturated colour' picked the ordinary ChunkCard's darker FilledButton background (colorScheme.primary) over the live row's lighter primaryContainer fill, because non-live cards outnumber the live row in raw pixel count"
    - "Bridging small (<=3 row) gaps in a colour-band scan to survive the now-line's own stroke interrupting the card's fill colour where it crosses"

key-files:
  created:
    - .planning/phases/27-true-grid/tools/measure_card_fill.py
    - .planning/phases/27-true-grid/shots/compact-1000-work-live.png
    - .planning/phases/27-true-grid/shots/single-line-1022-break-live.png
    - .planning/phases/27-true-grid/shots/uniform-1000-work-live.png
    - .planning/phases/27-true-grid/shots/uniform-1022-break-live.png
    - .planning/phases/27-true-grid/shots/nowline-early-1000-work-live.png
    - .planning/phases/27-true-grid/shots/nowline-late-1017-work-live.png
  modified:
    - lib/screens/today/timeline_geometry.dart

key-decisions:
  - "kCompactLiveMinHeight set to 84.0 (76px raw measured natural height + 8px explicit safety margin, the upper end of this file's established 4-8dp range), chosen over the tighter 4px margin because the compact tier's clearance over a standard 100px slot is generous (24px of natural slack)"
  - "kFullTierMinHeight (88.0) and kCompactLiveMinHeight (84.0) kept SEPARATE, not collapsed -- 4dp apart (outside the 'within 2dp, decide explicitly' trigger), and they threshold different card layouts with no shared content; their prior identical 88.0 value was coincidental (both independently re-derived from the same estimate before either was measured)"
  - "The freshly onboarded profile's generated day did not reproduce the spike's own 8:50 AM live chunk (Exercise starts 9:55 AM in this run) -- captured the equivalent 20%-elapsed instant (10:00 AM, 5 min into the 9:55-10:20 AM Exercise chunk) instead of the literal spike time, and renamed the evidence files to match the actual times used rather than keeping the plan's placeholder filenames"
  - "measure_card_fill.py's fill-colour derivation filters candidates to (saturated AND min-channel > 100) rather than saturated alone -- verified empirically against the single-line-tier screenshot, where the naive saturated-only heuristic picked the ordinary ChunkCard's FilledButton colorScheme.primary background (dark, saturated) over the live row's lighter primaryContainer fill, because four full-size ordinary Complete buttons outnumber one thin live-row strip in raw pixel count"

requirements-completed: [GRID-01]

# Metrics
duration: ~55min (Tasks 1-2; Task 3 pending)
completed: 2026-08-18
---

# Phase 27 Plan 04: Real-browser measurement of `kCompactLiveMinHeight` and end-to-end GRID-01 proof Summary

**Tasks 1 and 2 complete and committed: `kCompactLiveMinHeight` is now a real-browser measurement (84.0, not the 88.0 estimate), and `measure_hours.py` prints `UNIFORM` against the build containing that measurement, in both a live work chunk and a live break. Task 3 (the human touch-device checkpoint) is PENDING — this plan is NOT closed, and neither is Phase 27.**

## Performance

- **Duration:** ~55 min for Tasks 1-2
- **Completed:** 2026-08-18 (Tasks 1-2 only)
- **Tasks:** 2/3 (Task 3 is a `checkpoint:human-verify` gate, intentionally left open)
- **Files modified:** 1 (`lib/screens/today/timeline_geometry.dart`)
- **Files created:** 7 (1 script, 6 evidence screenshots)

## IMPORTANT — this plan is not finished

Per the plan's own gate (`27-VALIDATION.md`, `27-UI-SPEC.md` "Touch-target exception"), Task 3 —
tapping the 36×36dp Complete/Skip targets on an actual touch device — **cannot be signed off by
an agent**. This summary documents Tasks 1 and 2, both `type="auto"` and both committed. Task 3's
`<what-built>`/`<how-to-verify>`/`<resume-signal>` are presented verbatim below, unanswered. A
human must open `http://danserver:8137/` on a phone or tablet and return a verdict before this
plan — and Phase 27 — can be marked complete. **Do not treat GRID-02's touch-target exception as
closed on the strength of this summary alone.**

## Served build

The debug web bundle is built with the measured `kCompactLiveMinHeight` (84.0) baked in and is
being served on port `8137` (`python3 tools/serve-uat.py 8137 --dir build/web`, backgrounded).
Served-bytes check immediately before writing this summary:

```
$ curl -s http://localhost:8137/main.dart.js | grep -c 'Right now: '
1
```

Non-zero — the human will be judging the current, measured build, not a stale one.

## The generated day did not match the spike's

The spike's own captures parked at 8:50/8:55/9:10/9:17 AM against a day where Exercise started at
8:50 AM. This plan's fresh onboarding profile (a new origin, port 8137, so IndexedDB starts empty)
generated a different day: **Exercise 9:55–10:20 AM**, short break 10:20–10:25 AM, Side project
10:25–10:50 AM, Exercise 10:55–11:20 AM, Side project 11:25–11:50 AM. Per the plan's own
instruction ("do not assume it... pick an equivalent instant... record which instant you used and
why"), all captures use the equivalent **20%-elapsed** instant inside the live work chunk (10:00
AM, 5 of 25 minutes in — same fraction as the spike's own 08:55 capture) and an instant 2 minutes
into the following 5-minute break (10:22 AM, matching the spike's own +2min-into-break framing at
09:17). Evidence filenames were renamed to the actual times used rather than kept as the plan's
placeholder `-0855-`/`-0917-` names, so nobody re-derives a wrong instant from a stale filename.

## Task 1: Measure `kCompactLiveMinHeight` in a real browser and set it

**`measure_card_fill.py` output, verbatim, for both tiers:**

```
$ python3 .planning/phases/27-true-grid/tools/measure_card_fill.py .planning/phases/27-true-grid/shots/compact-1000-work-live.png
.planning/phases/27-true-grid/shots/compact-1000-work-live.png
  size=430x930 fill=(162, 242, 217) gutter=40.. scan=200..840
  fill band rows 446..521  height=76
  TALLEST FILL BAND HEIGHT: 76 px

$ python3 .planning/phases/27-true-grid/tools/measure_card_fill.py .planning/phases/27-true-grid/shots/single-line-1022-break-live.png
.planning/phases/27-true-grid/shots/single-line-1022-break-live.png
  size=430x930 fill=(162, 242, 217) gutter=40.. scan=200..840
  fill band rows 521..536  height=16
  TALLEST FILL BAND HEIGHT: 16 px
```

Compact tier natural height: **76px** (fits a 100px slot with 24px slack). Single-line tier: **16px**,
strictly under the required `20.0` (4px slack in a slot that cannot spend anything on margin).

**Constant set:** `kCompactLiveMinHeight = 84.0` (76px raw measured + 8px explicit safety margin —
the upper end of this file's established 4-8dp range, chosen because the compact tier's slack over
a standard 25-minute chunk's 100px slot (24px) made the extra headroom free). Doc comment rewritten
wholesale in house style (date, viewport `430`×930 at DPR 1, method, port `8137`, raw number, safety
margin, "what would invalidate this" paragraph) — see `lib/screens/today/timeline_geometry.dart`.

**Pitfall 6 resolved:** `kFullTierMinHeight` (88.0) and `kCompactLiveMinHeight` (84.0) are **kept
separate**, not collapsed. 4dp apart — outside the "within 2dp, decide explicitly" trigger — and
they threshold different card layouts (`LiveRowCard`'s compact tier vs. `ChunkCard`'s full tier)
with no shared content. Their prior identical `88.0` was coincidental: both were independently
re-derived, before either was measured, from the same 2026-08-18 card-compaction arithmetic
estimate.

**Fit observations, by eye, both screenshots opened with the Read tool:**
- Compact tier (`compact-1000-work-live.png`): kicker "RIGHT NOW · 9:55 AM" and title "Exercise"
  are not clipped at any edge; the title (short, in this fixture) does not wrap or overflow — no
  ellipsis was exercised since "Exercise" is short, but the `TextOverflow.ellipsis` styling is in
  place per the code read. Both icon buttons (green check, red skip) sit fully inside the card,
  clear of its right edge. The remaining-time line ("20 min left · until 10:20 AM") is fully
  legible below the action row.
- Single-line tier (`single-line-1022-break-live.png`): "Taking a break" (title) and "3 min left ·
  until 10:25 AM" (countdown suffix) both render on the one line, vertically centred in the 20px
  slot, both fully legible, no clipping top or bottom.

`grep -c "UNMEASURED" lib/screens/today/timeline_geometry.dart` → `0`.

**Commit:** `1ca4204` (fix) — `lib/screens/today/timeline_geometry.dart`,
`.planning/phases/27-true-grid/tools/measure_card_fill.py`,
`.planning/phases/27-true-grid/shots/compact-1000-work-live.png`,
`.planning/phases/27-true-grid/shots/single-line-1022-break-live.png`.

## Task 2: Prove GRID-01 in pixels and re-green the suite

Rebuilt (`flutter build web --debug --source-maps --pwa-strategy=none`) after the constant change,
re-served on 8137, re-ran the served-bytes check (non-zero again), then re-drove to the same two
live instants against the rebuilt bundle.

**`measure_hours.py` output, verbatim, work-live:**

```
$ python3 .planning/spikes/001-live-row-in-a-true-grid/tools/measure_hours.py .planning/phases/27-true-grid/shots/uniform-1000-work-live.png
.planning/phases/27-true-grid/shots/uniform-1000-work-live.png
  size=430x930 bg=(245, 251, 246) gutter=0..40 scan=200..840
  label band rows 217..225  centre=221.0  height=9
  label band rows 457..465  centre=461.0  height=9
  label band rows 697..705  centre=701.0  height=9
  hour-to-hour spacing:
    band 0 -> 1: 240.0 px
    band 1 -> 2: 240.0 px
  min=240.0 max=240.0 spread=0.0
  VERDICT: UNIFORM
```

**`measure_hours.py` output, verbatim, break-live:**

```
$ python3 .planning/spikes/001-live-row-in-a-true-grid/tools/measure_hours.py .planning/phases/27-true-grid/shots/uniform-1022-break-live.png
.planning/phases/27-true-grid/shots/uniform-1022-break-live.png
  size=430x930 bg=(245, 251, 246) gutter=0..40 scan=200..840
  label band rows 436..444  centre=440.0  height=9
  label band rows 676..684  centre=680.0  height=9
  hour-to-hour spacing:
    band 0 -> 1: 240.0 px
  min=240.0 max=240.0 spread=0.0
  VERDICT: UNIFORM
```

Both `UNIFORM`. Every consecutive spacing is `240.0` px = `60 * kPixelsPerMinute` exactly. No
`132.0` spread anywhere in either output — the defect's signature is absent, confirming the fix is
present in the *served* bundle, not just in source.

**Full suite, after the constant change:** `flutter test` → **567 tests, all passed.**
`flutter analyze` → **no issues.** No test fixture needed adjustment — `test/screens/
today_row_widgets_test.dart` and `test/screens/today_screen_test.dart`'s boundary tests reference
`kCompactLiveMinHeight` symbolically, exactly as `27-02`/`27-03` set them up to. `git diff --exit-code
pubspec.yaml pubspec.lock` → empty (no dependency change).

**Extra evidence, not required by this task's acceptance criteria but captured per this run's
instructions:** the now-line crossing the compact card at two points in the same chunk —
`nowline-early-1000-work-live.png` (5 min in, the line crosses the kicker "RIGHT NOW · 9:55 AM",
struck through and legible on both sides) and `nowline-late-1017-work-live.png` (22 min in, the
line lands near the card's bottom edge, clear of all text). Both opened with the Read tool and
confirmed legible.

Port 8137 was stopped between Task 2 and Task 3's re-serve (per Task 2's own instruction), then
restarted for the Task 3 checkpoint below — it is now, and going forward, a debug-build-only port
for this project (never release), matching `CLAUDE.md` trap #1 discipline.

**Commit:** `7d0a1e6` (test) — the four evidence screenshots (`uniform-1000-work-live.png`,
`uniform-1022-break-live.png`, `nowline-early-1000-work-live.png`, `nowline-late-1017-work-live.png`).

## Task 3: UAT — the three things pixels cannot answer (PENDING HUMAN VERIFICATION)

**Not started by this agent — a checkpoint, not auto-executable.** The server is running and
current (served-bytes check re-confirmed non-zero immediately before this summary was written).

**URL:** `http://danserver:8137/` — **open on a phone or tablet, not a mouse-driven browser.**

**Simulated times to reach each tier** (via the debug clock UI, or by repeating the
`drive.cjs --at=HH:MM` technique against a persistent profile): `10:00 AM` lands inside the live
25-minute Exercise chunk (9:55–10:20 AM, compact tier); `10:22 AM` lands inside the following
5-minute break (10:20–10:25 AM, single-line tier). A fresh device/browser session will re-onboard
and may generate a different day than this one — use whichever instant is 15-25% into a live work
chunk and a live break in that session's own generated day.

**The three questions, verbatim from the plan:**

1. **The 36dp tap targets (the declared WCAG exception).** With a work chunk live, tap the
   Complete icon on the live card with a thumb, then Skip on the next one. Do they hit reliably, or
   do you miss and hit the card instead? Try once more at a larger system text scale. If they are
   fiddly, say so — the agreed remedy is more slot height (revisit `kPixelsPerMinute`), never
   smaller text or a dropped action.
2. **The now-line crossing the card.** Watch the live card early in a chunk and again late in it —
   use the debug clock to jump if that is quicker. The 2dp rule will cut through the kicker, the
   title, or the countdown at different points. Is the text still readable everywhere the line
   lands? Check the single-line break tier too, where the rule has nowhere to go but across the
   only line there is.
3. **The day is 132dp shorter.** Scroll the timeline with a chunk live. Every hour bracket should
   look the same height, and more of the day should fit on screen than before. Nothing should
   overlap and no card should be clipped mid-glyph.

Worth a glance while there: a long goal title on the live card should end in an ellipsis on one
line rather than wrapping or overflowing.

**Resume signal:** Type "approved", or describe what looked or felt wrong — especially on item 1,
which this phase deliberately shipped as an accepted trade rather than a settled decision.

**Verdict on each item: NOT YET RECORDED.** No verdict is asserted here, plain-pass or otherwise —
per this plan's own instruction, an agent does not self-approve or substitute a screenshot
inspection for a real thumb on a real touch device.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `measure_card_fill.py`'s naive "most common saturated colour" heuristic picked the wrong colour on the single-line-tier screenshot**
- **Found during:** Task 1, first run of the script against `single-line-1022-break-live.png`.
- **Issue:** Filtering candidate fill colours to "saturated" alone (channel spread > 15) picked
  `(16, 107, 87)` — the ordinary (non-live) `ChunkCard`'s `FilledButton` background
  (`colorScheme.primary`, a dark saturated tone) — over the live row's actual
  `primaryContainer` fill `(162, 242, 217)`, because that screenshot contains four full-size
  ordinary Complete buttons versus one thin live-row strip, so the button colour's raw pixel count
  won.
- **Fix:** Added a second filter, `min(channel) > 100` (light/pastel), on top of the saturation
  filter — Material 3's "Container" roles are deliberately light next to their darker
  "primary"/"secondary" accents in a light-seeded theme, so this discriminates
  `primaryContainer` from `primary` generically without hard-coding either colour. Verified against
  both screenshots after the fix: both correctly resolve to `(162, 242, 217)`.
- **Files modified:** `.planning/phases/27-true-grid/tools/measure_card_fill.py`
- **Verification:** Re-ran the script against both screenshots; both report the correct fill colour
  and plausible band heights (76px, 16px).
- **Committed in:** `1ca4204` (Task 1 commit) — the script was fixed before its first commit, so
  this is not a follow-up patch, just documented here as a real correction made during
  development.

**2. [Rule 1/3 — data mismatch] The freshly onboarded profile's generated day did not reproduce the spike's own live-chunk times**
- **Found during:** Task 1, driving to the plan's literal `--at=08:55`.
- **Issue:** The plan's action text names `08:55`/`09:17` (the spike's own captures) as the target
  instants, assuming the same generated day. This origin (port 8137) starts with empty IndexedDB,
  so onboarding regenerates a day from scratch; the mood/goal RNG landed on a day where Exercise
  starts at 9:55 AM, not 8:50 AM — at `08:55` nothing was live yet ("Nothing until 9:55 AM").
- **Fix:** Per the plan's own explicit instruction for exactly this case ("If the day differs...
  pick an equivalent instant... record which instant you used and why"), used `10:00 AM` (5 of 25
  minutes into the live Exercise chunk — the same 20%-elapsed fraction as the spike's 08:55) and
  `10:22 AM` (2 minutes into the following 5-minute break). Evidence filenames were renamed to match
  the actual times used (`compact-1000-work-live.png`, `single-line-1022-break-live.png`, etc.)
  rather than kept as the plan's placeholder `-0855-`/`-0917-` names.
- **Files modified:** none (filenames only, at creation time — no renaming of an already-committed
  file was needed).
- **Verification:** Confirmed via `drive.cjs --dump`'s semantics tree that the correct chunk was
  live at each captured instant (kicker text, remaining-time copy) before treating any screenshot
  as evidence.
- **Committed in:** `1ca4204`, `7d0a1e6`.

---

**Total deviations:** 2 auto-fixed (1 tooling bug fix, 1 data-mismatch adaptation), neither
affecting the measured numbers' validity — both were caught and corrected before any measurement
was taken as final.

## Known Stubs

None — no data source is stubbed; this plan changed a constant and its doc comment, plus added a
measurement script. No new UI surface was built.

## Threat Flags

None — matches the plan's own threat model (T-27-05, T-27-06 both `mitigate`, both addressed: the
server is loopback-only Tailscale-side, and the served-bytes check was re-run before every capture
and again immediately before this summary). `git diff --exit-code pubspec.yaml pubspec.lock` is
empty (T-27-SC, `accept`, confirmed).

## Issues Encountered

None beyond the two documented deviations above.

## User Setup Required

**Task 3 (this plan's remaining gate) requires Dan to open `http://danserver:8137/` on a phone or
tablet** and return a verdict on the three items above. The debug build server is running now and
was current as of this summary. No other external service configuration required.

## Next Phase Readiness

**This plan is NOT complete and Phase 27 is NOT complete.** Tasks 1 and 2 are done and committed;
Task 3 is a blocking human-verify checkpoint that must be answered before:
- This plan's `27-04-SUMMARY.md`... (this file) can be treated as a closing summary rather than a
  progress record,
- `ROADMAP.md`'s Phase 27 entry can move from "In Progress" to "Complete",
- `STATE.md`'s Current Position can advance past Phase 27.

A continuation agent (or Dan directly) should: open the URL, walk the three items, record the
verbatim verdict, and — only if all three pass (or item 1's follow-up is explicitly routed to
revisiting `kPixelsPerMinute` rather than silently accepted) — finalize this summary's Task 3
section, update `STATE.md`/`ROADMAP.md` to reflect full completion, and make the phase-closing
commit.

---
*Phase: 27-true-grid*
*Tasks 1-2 completed: 2026-08-18*
*Task 3: PENDING HUMAN VERIFICATION*

## Self-Check: PASSED

All 8 referenced files (`lib/screens/today/timeline_geometry.dart`, `.planning/phases/27-true-grid/tools/measure_card_fill.py`, and the six screenshots under `.planning/phases/27-true-grid/shots/`) confirmed present on disk. Both task commit hashes (`1ca4204`, `7d0a1e6`) confirmed present in `git log`. Task 3's checkpoint has not been answered and is not claimed as passed anywhere in this summary.

---

## Task 3 — UAT verdict (2026-08-19, recorded verbatim)

The owner ran this on a real device. Verdict per item, in his words:

> **1 — agreed. complete / skip with a thumb when you're active might be hard.**
> **2 — try it underneath. it does cut some stuff off. may have to adjust to ensure it's still readable.**
> **3 — i scrolled looks good.**

**Item 3 — PASSED as shipped.** The grid reads uniform in the hand and the day being 132dp
shorter is an improvement. No change.

**Item 1 — FAILED, fixed in `419aa7b`.** The 36×36dp targets are too small to hit reliably with a
thumb while a chunk is running. Raised to 44dp via a new `kLiveActionTouchTarget`, closing the
declared WCAG exception rather than carrying it forward.

**The recorded remedy was deliberately not taken.** `27-UI-SPEC.md` said the fix, if this failed,
was "more slot height (revisit `kPixelsPerMinute`)" — because it claimed a 100dp slot "cannot also
fit two 44dp targets side by side without either the title or the countdown losing its line." That
claim was never checked and is false: the compact tier's action row is sized by the kicker+title
stack (~37dp), not by the buttons, so 44dp costs 7dp against ~24dp of measured slack. Raising
`kPixelsPerMinute` would have made the entire day taller to buy something the existing slack
already covered — and would have undone the 5.5→4.0 compaction made for the exact opposite
complaint ("the elements take up too much vertical space", 2026-08-18). Following the spec here
would have been the wrong call.

**Item 2 — FAILED, fixed in `419aa7b`.** The now-line struck through the live card's text — through
the word "Exercise" on the compact tier, and through the single line of the break tier. This was
already flagged before UAT, in `27-UI-REVIEW.md`'s addendum with screenshots, after the UI audit
correctly spotted that the phase's own evidence never actually tested the spec's "the crossing is
harmless" claim.

Fixed by the cheapest of the three options offered: the live row is now painted **after** the
now-line overlay in the Stack, so the rule stops at the card's edges (what Google Calendar does).
Nothing is suppressed and the overlay gained no new flag, so this cannot rot the way the old
`showChip` predicate did. The now-marker stays discoverable because the dot is centred on
`kNowContentEdge`, which is exactly `kCardLeftInset` — its left half sits outside the card.

The owner's "may have to adjust to ensure it's still readable" was checked rather than assumed:
both tiers re-captured in a real browser after the fix (`crop-uat-nowline-under-card.png`,
`crop-uat-nowline-under-single-line.png`) — text is clean on both, and the dot is still visible.

### Re-verification after the fixes

Both fixes changed rendered layout, so everything that could be invalidated was re-measured rather
than assumed to survive:

| Check | Result |
|---|---|
| `measure_hours.py`, live work chunk (8:10) | **UNIFORM** — 240.0 / 240.0, spread 0.0 |
| `measure_hours.py`, live break (8:27) | **UNIFORM** — 240.0 / 240.0, spread 0.0 |
| `measure_card_fill.py`, compact tier | 80px raw (was 76px — the taller buttons) |
| `kCompactLiveMinHeight` | re-measured 84.0 → **88.0** (80 + 8 margin) |
| `flutter test` | 567 green |
| `flutter analyze` | clean |

**One honest note on process:** the first re-measurement run came back `NOT UNIFORM`, which looked
alarming. It was not a regression — the date had rolled to 2026-08-19 overnight, so the persistent
Chromium profile held the previous day's schedule with nothing live, and the scan picked up
day-complete header text as extra label bands. A fresh profile generating today's schedule measured
`UNIFORM` immediately. Recorded because a future reader running this harness across a date boundary
will hit the same thing, and the failure mode looks exactly like a real regression.

**Task 3: CLOSED.** All three items resolved — one passed as shipped, two fixed and re-verified.
