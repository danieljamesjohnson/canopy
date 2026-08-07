---
status: testing
phase: 22-unified-today-screen
source: [22-VERIFICATION.md]
started: 2026-08-07T20:15:00Z
updated: 2026-08-07T20:15:00Z
---

## Current Test

number: 1
name: Row vocabulary renders as designed at phone and desktop widths
expected: |
  The current activity renders as a swelled primaryContainer card in place in the list; free-time
  rows read as quiet dotted-rule text; breaks show a dashed outline with no fill; commitments show
  tertiaryContainer with no outline; completed/skipped chunks are struck through and dimmed.
awaiting: user response

## Tests

### 1. Row vocabulary renders as designed at phone and desktop widths

expected: The current activity renders as a swelled `primaryContainer` card in place in the list (16dp radius, soft elevation, uppercase "RIGHT NOW" kicker, titleLarge title, progress bar, Complete/Skip buttons, "Next · …" line) — matching 22-UI-SPEC.md's "The live row" section and the reference render in 22-CONTEXT.md. Free-time rows read as quiet dotted-rule text, never blank space. Breaks show a dashed outline with no fill. Commitments show `tertiaryContainer` with no outline. Completed/skipped chunks are struck through and dimmed.
result: [pending]

**Repro:** Open the served debug build at a phone-width viewport (<720dp) and a desktop-width viewport (≥720dp). Scroll to a moment mid-day where a chunk is Active.

**Why human:** Visual treatment (colors, dashed/dotted CustomPainter rendering, opacity ramps, spacing) can't be confirmed by grep or widget-test assertions — tests check widget/string/`colorScheme` presence, not that the painted result matches the sketch.

### 2. Centre-on-open scroll feel

expected: On open, the list scrolls smoothly (250ms ease-out) to bring the live row to roughly the vertical centre of the viewport, and does not jump or re-scroll while reading (e.g. across a 1-minute tick).
result: [pending]

**Repro:** Cold-start the app on a day with a schedule whose current chunk sits several rows down the list.

**Why human:** The mechanism is unit-verified (scroll offset changes once, not twice) but "centred" and "smooth" at real device sizes need an eye — the test only checks the offset moved off zero.

### 3. Mood chip copy and restoratives gating

expected: Chip reads `<emoji> <Low/Cloudy/Steady/Bright/Sunny> day · N chunks`; the restoratives suggestion card appears above the timeline only for mood ≤ 2.
result: [pending]

**Repro:** Check each of the 5 mood levels. Confirm restoratives shows at mood 1–2 and not at 3+.

**Why human:** Mood-to-copy mapping and emoji rendering are visual/copy correctness checks best done by skimming real mood states.

### 4. Reconciled empty state reads as one screen

expected: All four affordances present and usable — breathing-pulse "Start your day" CTA, "Add an event", the web check-in banner (web only), and the "Plan your day in 30 seconds" headline — with content constrained to 720dp on desktop.
result: [pending]

**Repro:** Trigger the empty state (no schedule yet) at both phone and ≥720dp widths.

**Why human:** Tests assert each widget exists; whether the reconciled empty state reads as a single composed screen — rather than an awkward stack of two old screens' parts — needs a human look.

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps
