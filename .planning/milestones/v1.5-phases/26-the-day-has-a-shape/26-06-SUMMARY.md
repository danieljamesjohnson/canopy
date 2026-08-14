# Plan 26-06 Summary — Phase gate

**Plan:** 26-06 (`autonomous: false` — blocking human checkpoint)
**Completed:** 2026-08-14
**Requirements:** CAL-01, CAL-02, CAL-03

## What this plan was

The phase gate: full suite + analyze, a served debug build, and Dan's sign-off on the manual-only
verifications that `26-VALIDATION.md` routes away from the test harness. It is the only plan in this
phase marked `autonomous: false`, because the claims it covers — text fit at real font metrics,
whether the line visibly moves, whether the day reads as a *shape* — cannot be settled by a pumped
frame.

## Outcome

**Passed, after four rounds of gap closure.** The gate did its job: it caught a defect that ten
plans of automated verification had missed, and then caught two more.

### Timeline

| Round | Trigger | Result |
|-------|---------|--------|
| Initial gate | Debug build served on `danserver:8131` | Dan: *"The now box draws over the name of the chunk and any other information"* → **G-01** |
| 26-07 | G-01 fix — chip confined to the 52dp gutter | Fixed ordinary cards. **Reported closed; it was not** |
| 26-08 | Agent-surfaced dead space under the live row → **G-02** | Constant 240.0 → 232.0 on a real-browser measure; 8px of ~80, remainder structural and accepted |
| 26-09 | 26-08's evidence crops exposed the live row still colliding → **G-03** | The original report, actually fixed: chip yields inside the live row, rule stays |
| 26-10 | UI review (18/24) → **G-04, G-05, G-06** | Edge clipping (both widgets), AM marker |

Final: **560 tests green, `flutter analyze` clean.** Code review: 0 critical, 2 warnings + 1 info,
all fixed (`26-REVIEW-FIX.md`). UI review: 18/24, all three findings closed.

### Builds served

`8131` (initial gate) → `8132` (26-08) → `8133` (26-09) → `8134` (26-10, final). A fresh port per
build, per CLAUDE.md trap #1; `tools/serve-uat.py` throughout, never `python3 -m http.server`.

Phase 25's DevClock was the vehicle for every time-gated check — a fresh profile always generates a
day starting minutes ahead, so `Active`, `PreStart` and `DayComplete` are otherwise unreachable
without waiting. This is precisely what Phase 25 was built for, and it paid for itself here: G-03
and G-05 are both only visible in states the wall clock would not have offered.

## The honest part

**Two defects shipped behind green tests.**

1. **G-03.** 26-07's regression test asserted `chipRect.right <= cardRect.left` against a finder for
   `ChunkCard`. The defect was in `LiveRowCard` — a different widget, because the live row is
   full-bleed by design and has no gutter to hide a chip in. The test was green from the start
   against the live bug, and the defect was reported to Dan as fixed. The manual check missed it too:
   the verification screenshot landed on a *break* live row, whose shorter content (no Complete/Skip
   row, per Phase 23 LIVE-01) happened to leave the title clear.

2. **G-04 / G-05.** The hour-axis test asserted widget count and label text, never a painted rect.
   The first and last hour labels were sheared on *every single render*, and the now-line shared the
   root cause — clipping at exactly `PreStart` and `DayComplete`, the two states where nothing else
   on screen locates "now". That last one was a genuine CAL-02 failure at the range edges.

Both have the same shape: **an assertion that could not fail.** From 26-09 onward every regression
test in this phase was required to be observed RED against the unfixed code before acceptance —
which is how G-04 and G-05 were closed properly rather than optimistically.

The generalised lesson, recorded in `26-UAT.md`: when the symptom is "X overlaps Y", enumerate every
widget type that can be Y before writing the assertion. This surface has two card types with
deliberately different insets and only one was considered.

## Carried forward

- **`kPixelsPerMinute = 5.5` is provisional.** Set from a harness measurement — the same class that
  produced the wrong `kGutterWidth` of 75. A 12-hour day is ~3960px. Dan was shown this at the gate
  and chose to close rather than adjust. The constant's doc comment carries the warning; changing it
  later is contained (constant + geometry tests + UI-SPEC amendment).
- **~50px residual dead space below a *break* live row.** Structural: the reservation is sized to
  the taller work variant, so the shorter variant necessarily leaves slack. Measured, documented,
  accepted — not a shortfall in 26-08.
- `26-UI-SPEC.md` carries five dated amendments. The spec as amended is the contract; its original
  body text is not. Two of those amendments record spec defects the implementation found —
  the `52dp`-column-vs-`"Now · 2:47 PM"`-string contradiction being the notable one.

## Artifacts

`26-UAT.md` (G-01..G-03 + postmortems) · `26-UI-REVIEW.md` (18/24) · `26-REVIEW.md` /
`26-REVIEW-FIX.md` · `26-VALIDATION.md` (signed off) · `evidence-26-08/`, `evidence-26-09/`,
`evidence-26-10/` (18 real-browser captures)
