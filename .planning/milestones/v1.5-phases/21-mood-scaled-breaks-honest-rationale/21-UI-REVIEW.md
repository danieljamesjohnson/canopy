---
phase: 21-mood-scaled-breaks-honest-rationale
audited: 2026-08-07
baseline: 21-UI-SPEC.md
scores:
  copywriting: 4
  visuals: null
  color: null
  typography: null
  spacing: null
  experience_design: null
applicable_pillars: 1
status: passed
findings_for_this_phase: 0
findings_routed_forward: 1
---

# Phase 21 UI Review — Mood-Scaled Breaks & Honest Rationale

**Baseline:** `21-UI-SPEC.md`
**Screenshots:** not captured — this phase shipped zero widget/screen changes, so a screenshot diff
would show nothing it touched. Verified by direct code read instead.

## Scope confirmed correct

The UI-SPEC's framing checks out against the actual source (grepped and read, not taken from the
SUMMARYs): the entire diff is `lib/services/schedule_generator.dart` plus its test file. No new
screen, widget, route, or style.

## Pillar scores

| Pillar | Score | Note |
|---|---|---|
| 1. Copywriting | **4/4** | Exact match to contract, verified in code |
| 2. Visuals | N/A (reasoned) | No new visual element |
| 3. Color | N/A (reasoned) | No new color |
| 4. Typography | N/A (reasoned) | Reuses existing `bodySmall` role verbatim |
| 5. Spacing | N/A (reasoned) | No new layout; existing card margins/padding unchanged |
| 6. Experience Design | N/A (reasoned) | No new state or interaction added |

**How to read this score.** Only one pillar has substance in this phase. Rendering it as a fraction
of 24 would be misleading. Read it as: the one thing this phase could get wrong, it got right — and
it correctly declared everything else out of scope rather than inventing filler changes.

## Copywriting — verified

`lib/services/schedule_generator.dart:200-201`:

```dart
if (remaining < 0.1) return 'On track this week';
return 'Working toward ${remaining.toStringAsFixed(1)}h this week';
```

- The banned `'…h behind this week'` is gone. `grep -rn "behind" lib/` returns zero user-facing hits
  (only the sort-order code comment the spec already scoped out).
- The `On track this week` sibling branch is byte-identical to before, as the contract required.
- The replacement reuses the `Working toward …` verb phrase already established by
  `_outcomeRationale` (line 182: `'Working toward your goal'`) — voice consistency with the app's own
  existing copy, not an arbitrary new tone.
- No other rationale string (`_habitRationale`, `_outcomeRationale`, commitment block copy) was
  touched, matching the spec's "not touched" table.

Clean pass, verified at the line, not from a SUMMARY claim.

## Break-rhythm density — the one judgment call in scope

Read `lib/screens/schedule/widgets/chunk_card.dart` directly. Confirmed:

- `_buildLongBreak` (106-124): plain `Card`, no accordion/collapse, unchanged margins
  (`vertical: 4, horizontal: 16`) and padding (`16`).
- `_buildShortBreak` (76-104): unchanged 48px pill, `vertical: 2, horizontal: 16` margin.
- Cadence source: `_moodBreakCadence = {1: 2, 2: 3, 3: 4, 4: 4, 5: 5}`, consumed via `longBreakEvery`
  feeding the pre-existing `breakCount % longBreakEvery == 0` branch — structurally unchanged, only
  the divisor moved.

**Verdict: the spec's "degree, not kind" call holds — with one caveat worth carrying forward.** At
mood 1, every chunk still gets its short-break pill (BREAK-02, unchanged) *and* every 2nd chunk now
gets a full long-break `Card`. So a Stormy day renders: work, short-break, work,
short-break + long-break, work, short-break, work, short-break + long-break… Two visually similar
"break" rows (a 48px pill immediately followed by an elevated Card) land back-to-back roughly every
4th row. The spec's claim that "the existing rhythm already tolerates adjacent cards" is true in that
the code path existed — but it was previously reachable only at cadence 3, never cadence 2. This is a
real if modest readability question, correctly not solved here.

### Finding routed to Phase 22 (not a Phase 21 defect)

When auditing the merged Today screen, check a mood-1 day's rendered list for crowding where a
short-break pill and a long-break card land adjacent. If it reads as noisy, that is the moment to
consider a lightweight visual tightening of the two break variants when adjacent — **not** a new
collapse affordance, and not before there is real content on screen. Phase 22 already owns
`chunk_card.dart`, so the cost of looking is near zero there.

## Top fixes

None required for Phase 21. The shipped diff matches its contract exactly. The only actionable item
is the forward-looking note above.

## Files audited

- `lib/services/schedule_generator.dart` (around lines 39, 182, 200-201, 237, 739)
- `lib/screens/schedule/widgets/chunk_card.dart` (full file)
- `21-UI-SPEC.md`, `21-CONTEXT.md`, `21-01-SUMMARY.md`, `21-02-SUMMARY.md`

No `components.json` (Flutter, not a web/shadcn stack) — registry safety audit not applicable.
