---
status: resolved
phase: 22-unified-today-screen
source: [22-VERIFICATION.md]
started: 2026-08-07T20:15:00Z
updated: 2026-08-07T21:05:00Z
---

## Current Test

number: 2
name: Centre-on-open scroll feel
expected: |
  On open, the list scrolls smoothly (250ms ease-out) to bring the live row to roughly the vertical
  centre of the viewport, and does not jump or re-scroll while reading.
awaiting: none — closed 2026-08-14 as SUPERSEDED by Phase 26-05

## Tests

### 1. Row vocabulary renders as designed at phone and desktop widths

expected: The current activity renders as a swelled `primaryContainer` card in place in the list (16dp radius, soft elevation, uppercase "RIGHT NOW" kicker, titleLarge title, progress bar, Complete/Skip buttons, "Next · …" line). Free-time rows read as quiet dotted-rule text, never blank space. Breaks show a dashed outline with no fill. Completed/skipped chunks are struck through and dimmed.
result: **passed** — verified by agent against the running debug build (2026-08-07)

Checked at 1280×900 and 390×844 on the served debug build (`http://danserver:8123`), driving the real
onboarding → check-in → schedule flow. Observed on the live row: uppercase `RIGHT NOW` kicker,
titleLarge "Exercise", `25 min left · until 4:30 PM`, progress bar, Complete/Skip buttons,
`Next · Creative time at 4:35 PM`, all on a swelled `primaryContainer` card sitting **in place** in the
list rather than pinned. Free-time row rendered as `Free until 4:05 PM` behind a quiet vertical rule.
Both break variants rendered as dashed outline, no fill, duration right-aligned. Time gutter present
(4:05p / 4:30p / 4:35p / 5:00p / 5:25p). Rows carry the left goal-colour accent bar and a completion
circle.

*Not exercised:* the struck-through/dimmed treatment for completed and skipped chunks — the generated
day had no resolved chunks. Left for a human pass.

### 2. Centre-on-open scroll feel

expected: On open, the list scrolls smoothly (250ms ease-out) to bring the live row to roughly the vertical centre of the viewport, and does not jump or re-scroll while reading (e.g. across a 1-minute tick).
result: [pending] — **not exercised**

The agent could not create the precondition: reaching an `Active` chunk positioned several rows down
requires either waiting hours of real time or seeding Hive with a mid-day schedule. In every generated
run the live row was the first row (the engine anchors the day at "now"), so there was nothing above it
to scroll past. Genuinely needs a human on a real mid-day session.

### 3. Mood chip copy and restoratives gating

expected: Chip reads `<emoji> <Low/Cloudy/Steady/Bright/Sunny> day · N chunks`; the restoratives suggestion card appears above the timeline only for mood ≤ 2.
result: **passed** — verified by agent at both ends of the scale (2026-08-07)

- Mood 1 (Stormy): chip read `🌧 Low day · 3 chunks`; restoratives card **present** above the timeline
  ("A lighter day — here's what restores you", with the `Walk` item chosen during onboarding).
- Mood 5 (Clear skies): chip read `☀️ Sunny day · 9 chunks`; restoratives card **absent**.

Gating verified in both directions, not just the positive case. Moods 2/3/4 chip copy not individually
checked.

### 4. Reconciled empty state reads as one screen

expected: All four affordances present and usable — breathing-pulse "Start your day" CTA, "Add an event", the web check-in banner (web only), and the "Plan your day in 30 seconds" headline — with content constrained to 720dp on desktop.
result: **passed** — verified by agent at both widths (2026-08-07)

All four present at 1280×900 and 390×844. Desktop content sits in a 720px column (the check-in banner
spans x=321→1041). Reads as one composed screen, not a stack of two old screens' parts. Shell
navigation confirmed collapsed to three destinations (Today / Goals / Settings) — NavigationRail on
desktop, NavigationBar on phone — with no Home or Schedule entry anywhere.

### Outcome — 2026-08-14 (milestone audit): test 2 closed as SUPERSEDED

**Test 2 ("centre-on-open scroll feel — 250ms ease-out, brings the live row to centre,
does not re-scroll while reading") is closed as superseded, NOT as verified.** The
distinction matters and is recorded deliberately.

Phase 26-05 replaced the mechanism this test targets. Phase 22 centred the live row with
`Scrollable.ensureVisible` behind two one-shot flags (`_didCentreLiveRow`,
`_didCentreMarker`); under Phase 26's absolute positioning the target offset is pure
arithmetic, so that became a single flag and one `animateTo`. The code this test was
written against no longer exists.

The replacement carries its own coverage — a CAL-03 assertion that a 1-minute tick after
open does not re-trigger the scroll (the "does not re-scroll while reading" half), plus
real-browser confirmation at the 26-06 gate. Nobody ever judged the original 250ms
ease-out feel, and nobody now can: it is gone. Marking it "passed" would be a fabrication.

## Summary

total: 4
passed: 3
issues: 0
pending: 0
superseded: 1
skipped: 0
blocked: 0

## Notes

Two things verified incidentally that belong to Phase 21, both confirmed live in the running app
rather than only in unit tests:

- **TONE-01**: chunk rationale rendered as `Working toward 3.0h this week`. No "behind this week"
  anywhere on screen.
- **BREAK-01**: at mood 5 the long break landed after exactly 5 chunks (chunks at 4:10 / 4:40 / 5:10 /
  5:40 / 6:10, long break 6:35–7:00). At mood 1 it landed after 2. Both endpoints of the new cadence
  table confirmed end-to-end.

The Phase 21 UI review routed a concern forward to this phase: that a denser low-mood break rhythm
would put a 48px short-break pill immediately before an elevated long-break Card. **That does not
occur.** At a cadence boundary the long break *replaces* the short break rather than stacking after it
(chunk ends 6:35 → long break 6:35–7:00 → next chunk 7:00). Both break variants also render with the
same quiet dashed-outline treatment, so the rhythm reads consistently. Finding closed — no action
needed in Phase 22 or later.

## Gaps
