---
phase: 23
slug: live-activity-tracking
status: reviewed
audited: 2026-08-07
baseline: 23-UI-SPEC.md
screenshots: captured (5, provided by orchestrator — desktop 1280x900, low-mood day)
scope_note: "LiveRowCard widget untouched this phase; layout/spacing/typography carry no new surface. Copywriting and Experience Design are the substantive pillars."
pillars:
  copywriting: 4
  visuals: 2
  color: 3
  typography: 4
  spacing: 4
  experience_design: 3
overall: 20/24
---

# Phase 23 — UI Review: Live Activity Tracking

**Audited:** 2026-08-07
**Baseline:** `.planning/phases/23-live-activity-tracking/23-UI-SPEC.md` (locked design contract)
**Screenshots:** 5 provided, captured live against the served debug build — read pixel-by-pixel, not code-only

---

## Pillar Scores

| Pillar | Score | Key Finding |
|--------|-------|-------------|
| 1. Copywriting | 4/4 | Locked LIVE-01/02/03 copy renders verbatim in every screenshot; no deficit language found |
| 2. Visuals | 2/4 | Break and work live rows are visually near-identical; the "this is rest, not work" signal is text-only |
| 3. Color | 3/4 | No misuse, but the same `primaryContainer` blue represents two semantically opposite states (working vs. resting) |
| 4. Typography | 4/4 | Kicker/title/body hierarchy holds under the longer "RIGHT NOW — RESTING" string; no new sizes/weights introduced |
| 5. Spacing | 4/4 | No layout change this phase; card padding/gaps consistent across all 5 screenshots |
| 6. Experience Design | 3/4 | Timer lifecycle is well-engineered, but the flagship UX claim (break "reads as rest") is only partially delivered on the pixels |

**Overall: 20/24**

---

## Top 3 Priority Fixes

1. **Break live row is visually indistinguishable from a work live row at a glance** — user impact: a user skimming the screen (which is this app's entire interaction model — "control your time" via a glance) gets the "you are working" cue by default unless they stop to read the kicker text and notice two buttons are missing. Missing buttons is a weak/ambiguous signal — it can also read as "still loading." Concrete fix: give the break state a distinct fill (e.g. `secondaryContainer` or `tertiaryContainer` instead of `primaryContainer`), or an icon token (a moon/leaf glyph) next to the kicker, so rest is recognizable without reading.

2. **Color pillar reuses the single "now" accent for two opposite meanings** — user impact: none acute today, but it caps how differentiable rest vs. work can ever look while both draw from the same container role. Concrete fix: reserve `primaryContainer` for active work and introduce one additional semantic container (already available in Material 3's generated `ColorScheme`) for "resting" — a one-line `chunk.chunkType == break ? colorScheme.secondaryContainer : colorScheme.primaryContainer` swap in the row builder, no new tokens to design.

3. **Countdown minutes→seconds handover motion is still an open UAT item, not yet closed** — user impact: 23-UAT.md test 1 (smoothness across the 60s boundary) is `pending`, and the static screenshots (`13 min left` at plus70, `12s left` at plus80.2) can't confirm there's no visible reflow jump — the seconds string is narrower and left-aligned, so a width change on that line is plausible even if harmless. Concrete fix: not a code fix — this needs the human verification 23-UAT.md already calls for before the phase can be marked visually clean. Flagging here so it isn't lost as "probably fine."

---

## Detailed Findings

### Pillar 1: Copywriting (4/4)

Every locked string from `23-UI-SPEC.md` and `23-CONTEXT.md` decision 3 is present verbatim in the screenshots:

- `warp-plus70.png` / `br-plus80p2.png`: kicker `RIGHT NOW — RESTING`, title `Taking a long break`, exactly matching the spec table's break row.
- `sec-plus82p6.png`: kicker `RIGHT NOW` (no suffix) for the work chunk, title `Creative time` — the goal's own name, matching the spec's "Title" row for work chunks.
- `p23-today.png` (PreStart): `Nothing until 5:35 PM` / `The day starts with Exercise. Until then the time is yours.` — byte-for-byte the D-03 copy from CONTEXT.md decision 3.
- `eod-plus125.png` (DayComplete): `That's the day.` / `Everything scheduled is behind you.` — matches spec; no total, no percentage, no comparison to plan visible anywhere on the card.

One observation worth recording rather than deducting for: `"Everything scheduled is behind you"` uses the word "behind," which the Copywriting Contract explicitly bans as deficit language elsewhere ("not behind, missed, overdue"). Here it's temporal ("in the past"), not evaluative, and it's the literal Dan-approved D-03 string — codebase guard tests already assert "behind" appears nowhere else. Not a finding against this phase; noting it because a future contributor pattern-matching on the word alone could get confused.

### Pillar 2: Visuals (2/4)

This is the pillar the phase's own review questions bear most directly on, and the honest answer is that the intended contrast doesn't fully land on the pixels.

Direct comparison, `warp-plus70.png` (break) vs. `sec-plus82p6.png` (work):
- Same card shape, same corner radius, same `primaryContainer` blue fill, same left accent-less full-bleed card.
- Same title weight/size treatment (large serif-adjacent bold).
- The **only** differentiators are (a) the kicker text growing from `RIGHT NOW` to `RIGHT NOW — RESTING`, and (b) the entire Complete/Skip button row being absent on the break card.

At a normal glance-speed (the interaction model this whole app is built for — "control your time" via a quick look), (a) requires actually reading eight extra characters in a small caps line, and (b) reads as an *absence* rather than a *statement*. An absent button row is exactly what a half-rendered or loading card also looks like. Nothing on the break card actively says "this is calm/rest" the way, say, a different tint or a small icon would. The progress bar itself is styled identically in both states, reinforcing the "this is still a task ticking down" read rather than "this is deliberate downtime."

This isn't a widget bug — `LiveRowCard` was correctly left untouched per this phase's scope, and the screen-injected strings are correct per spec. But visually, question 1's premise ("is the contrast legible at a glance, or do the two states look too similar") lands on: **too similar**. The spec's own contract table (LIVE-01) lists five dimensions that differ between break and work, and four of the five are copy/behavior, not visual weight — color/shape carries none of the distinction.

**The `— RESTING` kicker suffix specifically** (question 2): it reads acceptably as prose — the em dash is doing real work separating "when" from "what state" — but it is easy to miss at the caps/tracking size used for kickers throughout the app. A locked decision, so not scored down further, but if this ever comes up for revision, a distinct kicker color (not full-card retint, just the kicker) would be a lower-cost way to get legibility without touching the shared widget's structure.

### Pillar 3: Color (3/4)

No hardcoded colors introduced by this phase (widget untouched, confirmed by 23-01/02/03 SUMMARY files listing `live_row_card.dart` as unmodified across all three plans). The `primaryContainer` blue is used correctly per Material 3 semantics for "the thing happening now" — that part is a clean pass.

The deduction is the same finding as Visuals, viewed through the color lens: the app has exactly one "now" treatment, and it is applied without variation to two states the copy contract is at pains to distinguish (work vs. rest). Nothing here is a contract violation — `23-UI-SPEC.md` never asked for a color split — but it's a missed opportunity the spec left on the table, and question 5 asks for an honest opinion: **no, it should not be identical.** Reusing the exact same fill for "you are actively producing" and "you are deliberately resting" undercuts the copy's own intent that rest be legible as rest.

### Pillar 4: Typography (4/4)

No new sizes or weights. Verified in screenshots: kicker (small caps, medium weight), title (large, bold), remaining-time line (regular, muted), "Next · …" line (regular, muted, smaller). The longer break kicker string (`RIGHT NOW — RESTING` vs `RIGHT NOW`) does not wrap or truncate at 1280px card width in either capture — no overflow risk observed at this breakpoint.

### Pillar 5: Spacing (4/4)

No layout changes this phase (confirmed: Phase 22 owns the layout, Phase 23 only changed injected strings/timer logic per all three SUMMARY files). Card padding, inter-card gaps, and progress-bar margins are pixel-consistent across all 5 screenshots — nothing to flag.

### Pillar 6: Experience Design (3/4)

Strengths, well evidenced by both the SUMMARY files and the screenshots:
- Break correctly resolves as `Active` rather than a gap (`warp-plus70.png` shows the break as the live row, not "Next chunk at 6:55" framing) — LIVE-01 genuinely fixed, not just copy-patched.
- Complete/Skip correctly suppressed only on the break row (`warp-plus70.png`/`br-plus80p2.png` vs. `sec-plus82p6.png`) — the one interaction-model difference that *is* legible, because it changes what you can click, not just what you read.
- Countdown handover: `13 min left` (plus70) → `12s left` (plus80.2) is present and correctly formatted per the locked granularity rule (minutes rounds up, no "0 min left" ever shown). The label is left-aligned within the card, so the string-width change on entering the seconds branch reflows only that one line's trailing edge — it does not shift the title, kicker, or button row above/below it. Static frames can't rule out a visible "pop," which is exactly why 23-UAT.md correctly still lists this as a pending human test — I'm not overriding that with a code-only opinion.
- Edge states (`p23-today.png` PreStart, `eod-plus125.png` DayComplete) are genuinely distinct in both wording and visual weight (PreStart keeps the day list below it fully visible and inviting; DayComplete's card doesn't compete with a call to action).

Deduction: the same visual-sameness issue from Visuals/Color has a direct Experience Design consequence — a user who glances at the screen mid-break, without reading, gets no experiential cue that this is *supposed* to look different from work. For an app whose entire pitch is "control over your time" via quick, trustworthy glances, that's a real (if not severe) experience gap, not just a cosmetic one. Scored 3, not lower, because the underlying mechanics (state resolution, timer lifecycle, action suppression) are correct and well-tested — it's specifically the *glanceability* of the distinction that's weak.

---

## Registry Safety

`components.json` not present in this Flutter project — shadcn/registry audit does not apply. Skipped per audit protocol.

---

## Files Audited

- `.planning/phases/23-live-activity-tracking/23-UI-SPEC.md`
- `.planning/phases/23-live-activity-tracking/23-CONTEXT.md`
- `.planning/phases/23-live-activity-tracking/23-01-SUMMARY.md`
- `.planning/phases/23-live-activity-tracking/23-02-SUMMARY.md`
- `.planning/phases/23-live-activity-tracking/23-03-SUMMARY.md`
- `.planning/phases/23-live-activity-tracking/23-UAT.md`
- Screenshots: `warp-plus70.png`, `br-plus80p2.png`, `eod-plus125.png`, `p23-today.png`, `sec-plus82p6.png`

Note: `lib/screens/today/today_screen.dart` and `lib/screens/today/widgets/live_row_card.dart` were not directly re-read as source in this audit — the three SUMMARY.md files' grep-verified acceptance criteria (occurrence counts for `ChunkType.work`, `resolveNowState`, `_liveSecondsRemaining`, etc.) were treated as reliable evidence of what shipped, cross-checked against the rendered screenshots rather than re-deriving from source.
