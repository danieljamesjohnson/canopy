---
status: in_progress
phase: 26-the-day-has-a-shape
source: [26-06-PLAN.md, 26-VALIDATION.md]
started: 2026-08-10T16:20:00Z
updated: 2026-08-10T16:20:00Z
---

## Current Test

number: 1
name: Phase 26 gate — real-browser verification of the proportional surface
expected: |
  The day reads as a time-proportional shape, the now-line sits at the true current moment
  including mid-chunk, and the past is a deliberate scroll away.
awaiting: user response (issue list in progress)

## Tests

### 1. Phase 26 gate — real-browser verification

result: **issues found** — Dan, 2026-08-10

Served: `http://danserver:8131/` (debug build, fresh port, `tools/serve-uat.py`, `no-store`).

**Agent-verified before handoff — do not re-check by hand:**

| Claim | Observed |
|---|---|
| Suite + analyze | 555/555 green, `flutter analyze` clean |
| Single-detector invariant | `resolveNowState` — one definition (`now_state.dart:117`), one call site (`today_screen.dart:1123`) |
| Raw colour literals | zero `Colors.*` in `lib/screens/today/` |
| JS console | no exceptions; all 8 Hive boxes opened cleanly |
| CAL-01 proportionality | 25-min chunk ≈ 137px slot vs 5-min break ≈ 20px dashed strip — visibly ~5:1 |
| CAL-02 now-line renders | `Now · 11:11 AM` chip + 2dp rule in `colorScheme.primary` (green, mood-seeded — not red, not `error`) |
| CAL-03 scroll-on-open | opens with now on screen, past above |
| Hour axis | per-hour `11 AM` / `12 PM` labels + hairlines replaced the per-row gutter |
| Prior-phase regressions intact | G-01 (Drains→Neutral→Lifts), G-06 (count only in progress bar), G-07 (mood consequence pre-commit), G-03 (PreStart→Active carried on a tick, no refresh) |

**Not reachable headlessly** (and therefore the source of the gap below): every fresh-profile run
generates a day starting a few minutes in the future, so the agent only ever observed `PreStart`.
The mid-chunk `Active` state — the core CAL-02 claim — was Dan's to check, and it is exactly where
the defect lives.

## Gaps

Reported by Dan at the 26-06 sign-off gate, 2026-08-10. Verbatim, then diagnosis.

> The now box draws over the name of the chunk and any other information

| # | Gap | Kind | Surface | Status |
|---|-----|------|---------|--------|
| G-01 | The now-line's `Now · <time>` chip paints on top of the chunk card beneath it, occluding the title and other card content whenever the line falls inside or near a card (i.e. mid-chunk `Active` — the normal case during a working day) | **bug** | `lib/screens/today/widgets/now_line.dart` | open |

### G-01 root cause

This is a **UI-SPEC self-contradiction**, not a coding slip. `26-UI-SPEC.md`'s now-line table
specifies the chip as:

> Solid pill at the line's left end, **sized to the hour-axis column width (`52dp`, reusing
> `kGutterWidth`)** … `labelSmall` (12px) weight 600, `8dp` horizontal / `4dp` vertical padding

and simultaneously specifies its content as `"Now · 2:47 PM"`. Those are incompatible: that string
at `labelSmall` 12px/w600 is ~85px of glyphs, plus 16dp of horizontal padding ≈ **101px**. It cannot
fit in a 52dp column.

`now_line.dart:43-72` resolved the contradiction by honouring the **string** and dropping the
**width constraint** — `Align(alignment: Alignment.centerLeft)` with `Padding(left: 16)` and no
width bound. So the chip spans roughly x=16 → x=117.

Cards begin at `16dp` outer inset + `52dp` reserved gutter = **68dp**. The chip therefore overlaps
the card's leading ~49px, which is precisely where `ChunkCard`'s title renders. Because the overlay
sits at topmost z-order — correct and necessary for the 2dp *rule*, which must cross the card — the
chip paints over the title, the time range, and the action row.

**Why neither the widget tests nor the agent's headless pass caught it:**

1. The CAL-02 assertions verify the chip's `Positioned(top:)` **offset** — geometric, and correct.
   Nothing asserted its **width**, because the UI-SPEC's own 52dp figure was taken as given rather
   than measured. Occlusion is a paint-order/extent property, not an offset property.
2. `26-VALIDATION.md` routed text-extent questions to the manual-only gate precisely because the
   test harness's placeholder font inflates glyph widths. That routing was correct — this is the
   defect it was meant to surface, and it did, at the gate.
3. Phase 24's marker never had this failure mode: it was a `NowMarkerRow` **list item** that
   displaced surrounding content. Phase 26 made the line an **overlay**, which is what makes a
   truthful mid-chunk position possible (CAL-02) and what introduces occlusion as a new risk.
   The trade was real and deliberate; the chip sizing is what was not thought through.

### G-01 fix direction

The spec's *intent* — a chip that lives in the time column, alongside the hour labels — is right and
should be honoured. What has to give is the string, since 52dp cannot hold `"Now · 11:11 AM"`.
Pending Dan's choice on the label (see below), the fix constrains the chip to the gutter column so
it can never reach the card, and adds the width assertion the CAL-02 group is missing.
