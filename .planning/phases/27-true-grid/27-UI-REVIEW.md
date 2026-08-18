# Phase 27 — UI Review

**Audited:** 2026-08-18
**Baseline:** `.planning/phases/27-true-grid/27-UI-SPEC.md` (approved design contract, amends `26-UI-SPEC.md`)
**Screenshots:** captured — real-browser evidence at `.planning/phases/27-true-grid/shots/` (6 PNGs, headless Chromium, 430×930 DPR1, `--use-gl=swiftshader`), reviewed directly with the Read tool. No live dev server was started for this audit; the committed shots plus code review are the evidence base.

**Status note:** Per `27-04-SUMMARY.md`, this phase's own human-verify checkpoint (Task 3 — tapping the 36×36dp targets on an actual touch device) is **still PENDING** as of this audit. This review scores what is currently shipped and evidenced, and treats that open checkpoint as an unresolved risk, not a formality.

---

## Pillar Scores

| Pillar | Score | Key Finding |
|--------|-------|-------------|
| 1. Copywriting | 4/4 | Locked strings match the contract exactly; no generic labels, no new empty/error copy needed (both n/a per spec) |
| 2. Visuals | 2/4 | The compact tier's own screenshot shows it reading as roughly the same visual weight as an ordinary neighboring `ChunkCard` — the height cue that used to make "this is now" unmissable is gone, and color/elevation alone aren't picking up all the slack |
| 3. Color | 3/4 | Roles used correctly (no new hex/roles), but the compact tier's mint `primaryContainer` fill next to plain white ordinary cards is a smaller contrast delta than the spec's own reasoning assumes — legible, not commanding |
| 4. Typography | 4/4 | Exactly two weights (400/600) as locked, title (16px/600, full opacity) does out-rank kicker (12px/600, 72% alpha) |
| 5. Spacing | 3/4 | On-scale, all declared exceptions (PD-27-01 horizontal-inset fix, single-line's zero vertical margin) correctly implemented in code — but the 36×36dp touch target is a spacing-adjacent contract violation carried forward as "declared," not resolved |
| 6. Experience Design | 2/4 | Touch-target UAT still unverified (blocking per the spec's own gate), now-line-crossing evidence doesn't actually show the dramatic mid-glyph crossing the spec's argument leans on, single-line tier borders on illegible-as-a-card at 16-20dp |

**Overall: 18/24**

---

## Top 3 Priority Fixes

1. **The 36×36dp Complete/Skip touch targets are still an open, unverified risk, not a closed decision.** User impact: a work-chunk user may mis-tap Complete/Skip on the one row that's live *right now* — the highest-stakes row on the whole screen for accidental taps. Concrete fix: run `27-04-SUMMARY.md`'s Task 3 (real touch device, `http://danserver:8137/` or equivalent) before calling this phase done; if it's fiddly, the spec's own remedy is to revisit `kPixelsPerMinute`/slot height, not to defer indefinitely. Do not let this sit as "declared" — declared is not verified.

2. **The compact tier reads as merely another card, not "this is now."** `compact-1000-work-live.png` shows the live Exercise card at roughly the same footprint as the "Side project 10:25–10:50 AM" card directly below it (which has a full labelled Complete/Skip button row). The only differentiators left are the mint `primaryContainer` fill, square corners, and elevation — and at this screen's contrast, those read as "a slightly different card," not as the page's obvious focal point the spec's own reasoning assumed would survive the height cut. Concrete fix: increase the fill/background contrast delta (a more saturated `primaryContainer` variant, or a persistent left-edge accent bar in `colorScheme.primary`) so the live row wins the page by color alone, since it no longer wins by size.

3. **The now-line-crossing evidence doesn't actually demonstrate the claimed mechanism.** The UI-SPEC's argument for "no suppression, no z-order change" rests on the line crossing mid-glyph and staying legible (citing the spike's `variant-a-0855`/`variant-a-0917` captures). But `nowline-early-1000-work-live.png` shows the dot/line sitting at the card's *top edge* (barely touching the kicker text), and `nowline-late-1017-work-live.png` shows it at the card's *bottom edge*, clear of all text — neither committed Phase 27 screenshot actually shows the line mid-crossing a line of text the way the spec's prose describes. Concrete fix: capture (or re-derive) an instant where the line demonstrably bisects the kicker or the single-line tier's only text line, and confirm legibility there — the current evidence set under-proves this section's own central claim.

---

## Detailed Findings

### Pillar 1: Copywriting (4/4)
- Compact tier kicker/title/remaining-time copy match `27-UI-SPEC.md` verbatim, confirmed both in code (`lib/screens/today/widgets/live_row_card.dart:126-178`) and rendered (`compact-1000-work-live.png`: "RIGHT NOW · 9:55 AM" / "Exercise" / "20 min left · until 10:20 AM").
- Single-line tier's locked copy (`"$title · $remainingLabel"`, never-truncating suffix) matches exactly (`live_row_card.dart:249-269`), confirmed rendered: "Taking a break" + " · 3 min left · until 10:25 AM" (`single-line-1022-break-live.png`).
- Accessibility label (`'Right now: $title, $remainingLabel'`) present and correctly wired (`live_row_card.dart:273-277`), closing the gap the dropped visible kicker opens for screen-reader users — not visually auditable but code-confirmed.
- No generic "Submit"/"OK"/"Click Here" strings found in the audited files.

### Pillar 2: Visuals (2/4)
- **The core trade this phase makes — trading height for color/elevation prominence — does not clearly hold up in the evidence.** In `compact-1000-work-live.png`, the live Exercise card and the ordinary "Side project" card immediately below it occupy visually similar footprints; the ordinary card, with its full-size labelled Complete/Skip buttons, arguably reads as *more* substantial on the page than the live card with its small icon-only actions. The live row is identifiable as "current" mainly by (a) the dot+line at its top edge and (b) a subtle fill-color shift — neither is a strong focal-point signal at a glance.
- Icon-only Complete/Skip are correctly paired with `Tooltip`s (`live_row_card.dart:200`) satisfying the aria-label-equivalent requirement for icon buttons.
- Hierarchy within the compact tier itself is fine: title (16px/600, full opacity) reads above kicker (12px/600, 72% alpha) and remaining-time (12px/400, 82% alpha) — confirmed both in code and the screenshot.
- Single-line tier (`single-line-1022-break-live.png`) is a ~16-20px strip that, cropped from its neighbors, would not obviously read as a card at all — it survives only because its neighbors (dashed "Short break" placeholder above, solid "Side project" card below) give it context. On its own it is closer to "a colored divider with text" than "a card."

### Pillar 3: Color (3/4)
- No hardcoded hex/`Colors.*` literals found in `live_row_card.dart` — every color reference is a semantic `ColorScheme` slot (`colorScheme.primaryContainer`, `.primary`, `.error`, `.onPrimaryContainer`, `.shadow`), matching the contract.
- Accent (`colorScheme.primary`) usage confined to the Complete icon tint and the now-line stroke, as declared — no overuse.
- The 60/30/10 split is nominally respected (primaryContainer as the 30% "secondary" role, primary/error reserved for accents), but the *visual* distinctiveness of that 30% container fill against the page's mostly-white ordinary cards is modest in the actual screenshots — this is a contrast/saturation issue more than a role-misuse issue, which is why it's scored 3 rather than folded fully into Pillar 2's 2.

### Pillar 4: Typography (4/4)
- Exactly two weights confirmed in code: `FontWeight.w600` (kicker override, title, single-line text) and the unweighted default 400 (remaining-time line, `bodySmall`) — no `w700` anywhere in `live_row_card.dart`, matching the locked "exactly two weights" rule.
- Sizes: `labelSmall` (kicker, 12px), `titleMedium` (title, 16px), `bodySmall` (remaining-time, 12px), `labelMedium` (single-line, ~12-14px) — all reused `TextTheme` roles, no raw px, matching the contract's "no new type roles" rule.
- Rendered evidence confirms all lines are single-line with `TextOverflow.ellipsis` as specified; the "Exercise" title in the sample didn't need to truncate, so ellipsis behavior itself is unverified by this evidence set (code-confirmed only).

### Pillar 5: Spacing (3/4)
- Compact tier margin (`top: 4, bottom: 4, left: kCardLeftInset, right: kTimelineRowInset`) and padding (`horizontal: 12, vertical: 8`) match the spec's corrected standard-margin/symmetric-padding values exactly (`live_row_card.dart:102-113`).
- Single-line tier's PD-27-01 correction (vertical-only zero margin, horizontal insets restated) is correctly implemented (`live_row_card.dart:279-284`) — this is the one place the spec caught and fixed its own draft error before shipping, and the shipped code matches the corrected version, not the erroneous original.
- The 4dp gap between the kicker+title block and the remaining-time line is present (`SizedBox(height: 4)`, `live_row_card.dart:169`).
- **The declared 36×36dp touch-target exception is a spacing-adjacent contract deviation that remains unresolved at the "score it honestly" instruction's request** — it is correctly *implemented* to spec (verified via the `IconButton.styleFrom(tapTargetSize: shrinkWrap)` fix in `27-02-SUMMARY.md`), but "implemented to spec" and "acceptable" are different questions, and the spec itself says the second one isn't settled. Docking one point here rather than accepting the declared-exception framing at face value, per this audit's brief.

### Pillar 6: Experience Design (2/4)
- **Touch-target verification is the single largest open item.** `27-04-SUMMARY.md` states in its own words: "Task 3 ... is PENDING HUMAN VERIFICATION," "this plan is NOT complete and Phase 27 is NOT complete," and explicitly warns "Do not treat GRID-02's touch-target exception as closed on the strength of this summary alone." As of this audit, no resume signal or verdict is recorded anywhere in the phase directory. This is a real, load-bearing gap, not paperwork — 36×36dp below the 44dp WCAG minimum on the two most time-sensitive actions on the screen (Complete/Skip on whatever is happening *right now*).
- **The now-line-crossing "harmless by design" claim is under-evidenced by this phase's own screenshots.** The mechanism the spec leans on (thin stroke + high-contrast text = legible mid-crossing) is asserted by citing the *spike's* screenshots, not Phase 27's own — and Phase 27's own two now-line captures (`nowline-early-1000-work-live.png`, `nowline-late-1017-work-live.png`) both show the line landing near a card edge rather than mid-glyph through rendered text. The claim may still be true, but it isn't demonstrated by what's committed.
- Complete/Skip remain reachable via tooltip-accessible icon buttons (compact tier) and via tap-to-open-`ChunkDetailSheet` (single-line tier's rare live-short-work-chunk case, PD-27-06) — the interaction path itself is sound and well-reasoned, distinct from the touch-target-size concern above.
- No destructive-action confirmation exists for Skip (unchanged from prior phases, explicitly out of scope) — consistent, not a regression.
- Loading/error/empty states: not applicable to this phase's scope (pure layout arithmetic, no I/O) — correctly not addressed, matching the spec's own "not applicable" framing.
- `flutter test` (567/567) and `flutter analyze` (clean) both pass per `27-03-SUMMARY.md`/`27-04-SUMMARY.md`, and `measure_hours.py` prints `UNIFORM` for both a live-work and a live-break instant — the GRID-01 geometric claim (uniform hour grid) is genuinely, independently proven in pixels, which is the one unambiguous win of this phase.

---

## Spec Conformance

- **PD-27-01 (horizontal-inset correction)** — correctly implemented; the shipped code uses `EdgeInsets.only(top: 0, bottom: 0, left: kCardLeftInset, right: kTimelineRowInset)` for the single-line tier, not the originally-drafted all-sides zero. Verified directly against `live_row_card.dart:279-284`.
- **No progress bar, no third tier, exactly two font weights, icon-only actions instead of `FilledButton`/`OutlinedButton`** — all correctly implemented, matching the spec's explicit "what deletes" instructions.
- **`kCompactLiveMinHeight` is a real-browser measurement (84.0 = 76px + 8px safety), not the spec's placeholder 88.0 estimate** — this is a legitimate, documented, planner-anticipated departure (the spec itself said re-measurement was mandatory and the 88.0 was "not measured and must not be treated as final"). Not a finding against the implementation; it's the process working as designed.
- **The single-line tier's "no tap target for a live break" / "tap opens ChunkDetailSheet for a live short work chunk" (PD-27-06) rule** is implemented via the `onTap` gate threaded from `today_screen.dart`'s `_buildLiveRow`, matching the spec.
- **No undocumented spec departures were found** in the files read for this audit — every deviation traced back to either a recorded PD (planner decision) or a summary-documented, justified auto-fix (e.g., the `IconButton` touch-target sizing mechanism, `27-02-SUMMARY.md`).

---

## Registry Safety

Not applicable — Flutter/Material 3 project, no shadcn or component registry (`components.json` absent), matching `27-UI-SPEC.md`'s own "Registry Safety: not applicable" section.

---

## Files Audited

- `.planning/phases/27-true-grid/27-UI-SPEC.md`
- `.planning/phases/27-true-grid/27-02-SUMMARY.md`
- `.planning/phases/27-true-grid/27-03-SUMMARY.md`
- `.planning/phases/27-true-grid/27-04-SUMMARY.md`
- `lib/screens/today/widgets/live_row_card.dart`
- `lib/screens/today/timeline_geometry.dart`
- `lib/screens/today/today_screen.dart` (lines ~1350-1450, live-row/now-line positioning)
- `.planning/phases/27-true-grid/shots/compact-1000-work-live.png`
- `.planning/phases/27-true-grid/shots/single-line-1022-break-live.png`
- `.planning/phases/27-true-grid/shots/nowline-early-1000-work-live.png`
- `.planning/phases/27-true-grid/shots/nowline-late-1017-work-live.png`
- `CLAUDE.md`

---

## Addendum — the now-line finding is confirmed, and worse than the committed evidence showed

**Added 2026-08-18 by the orchestrator, after this audit.**

This audit's third priority fix was that Phase 27's committed screenshots do not actually
demonstrate the UI-SPEC's central "the now-line crossing is harmless" claim — both `nowline-early`
and `nowline-late` happen to catch the rule at a card edge rather than through text. That
observation was correct, and it prompted two additional captures against the same served build
(port 8137, after the code-review fixes, served-bytes checked), at simulated times chosen
specifically to land the rule *inside* the text rather than at an edge:

- `shots/nowline-through-title-1020-work-live.png` (+ `crop-nowline-through-title.png`) — 10:20,
  40% into a live 10:10–10:35 chunk. **The rule strikes clean through the word "Exercise"** — the
  compact tier's title, its most important line.
- `shots/nowline-through-single-line-1037-break-live.png` (+
  `crop-nowline-through-single-line.png`) — 10:37, inside a live 5-minute break. **The rule
  strikes through the entire single-line tier**, which has only one line to strike.

**This changes the finding from "under-evidenced" to "confirmed, and the spec's reasoning does not
hold."** `27-UI-SPEC.md` decided against suppressing the rule or changing z-order, reasoning that
full-opacity text and a thin stroke keep the crossing legible. The text does remain *readable* —
but it reads as struck-through, which on a title carries an unwanted meaning (done / cancelled)
directly on the one row that is emphatically NOT done. The shipped card avoided this by being tall
enough that the rule usually landed in whitespace; a 90dp card and a 20dp card have no whitespace
to spare, which is exactly the residual risk `.planning/spikes/001-live-row-in-a-true-grid/README.md`
recorded and the UI-SPEC then decided to accept.

**Not fixed in this phase, deliberately.** GRID-01 and GRID-02 are both delivered and this does not
block either. Changing it now would mean re-opening an approved design contract at the end of a
phase, on the orchestrator's own aesthetic judgement, without the owner having seen it. It is
instead routed to the human checkpoint (`27-04-PLAN.md` Task 3, item 2 — "is the text still
readable everywhere the 2dp line lands"), which is the right place for it, now with evidence
attached rather than a screenshot that dodges the question.

**If the owner agrees it looks wrong, the fix options are, cheapest first:** draw the live card
above the now-line overlay in the Stack (the rule then stops at the card's edges); interrupt the
rule's stroke across the live card's width only; or shift the compact tier's title off the vertical
centre so the rule preferentially lands in a gap. The first is a one-line reorder and is
recommended.
