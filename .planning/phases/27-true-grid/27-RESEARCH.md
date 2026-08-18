# Phase 27: True Grid - Research

**Researched:** 2026-08-18
**Domain:** Flutter layout geometry (`Positioned`/`ClipRect`/`OverflowBox`), Flutter test-harness
limitations, real-browser pixel measurement
**Confidence:** HIGH

## Summary

Phase 27 is not a design problem — `27-UI-SPEC.md` already locks every visual value — it is a
**blast-radius and verification-methodology problem**. The one-line fix (deleting `liveExtraPx`
from `TimelineGeometry.yFor()`) is trivial; what makes this phase risky is (1) the geometry change
retires a field and a constant (`liveExtraPx`, `kLiveRowReservedHeight`) that four other call sites
and at least five tests currently depend on, (2) the live row's `LiveRowCard` gains a `slotHeight`
contract and two brand-new density-tiered layouts that must render correctly from 20dp to well
beyond 100dp, and (3) **the only test that can prove GRID-01 (uniform hour spacing) is not a
`flutter test` at all** — it is a pixel measurement in a real, GPU-backed browser. This project has
already been burned three times treating a `flutter test`-derived layout constant as real
(`kGutterWidth` 46→75→52, `kPixelsPerMinute` 4.0→5.5→4.0, `kLiveRowReservedHeight` 240→232), and
this phase's own headline constant (`kCompactLiveMinHeight`, currently an explicit `88.0` estimate)
is exactly that class of number, shipped un-measured on purpose per the UI-SPEC.

The spike (`.planning/spikes/001-live-row-in-a-true-grid/`) already built and real-browser-measured
a working reference implementation of the winning design (variant a) and left `variants.patch`
(diff, not a patch to apply) plus reusable tooling (`tools/drive.cjs`, `tools/measure_hours.py`).
Planning's job is to sequence: (1) the geometry deletion + its test fallout, (2) the widget-level
consumer changes (today_screen.dart's live-row branch, LiveRowCard's two new tiers), (3) the new
equidistance regression test that actually closes the coverage hole, and (4) a real-browser
measurement task that re-derives `kCompactLiveMinHeight` and confirms `UNIFORM` — in that order,
because the tiers can't be measured until they're built, and the constant can't ship until it's
measured.

**Primary recommendation:** Sequence the phase as geometry-first (delete `liveExtraPx`, update/
delete the tests that encode it), then widget-consumer (route the live row through the same
`Positioned(height:)` + `ClipRect`/`OverflowBox` path, build the two `LiveRowCard` tiers exactly per
`27-UI-SPEC.md`), then verification-last (equidistance test + mandatory real-browser measurement
task using the spike's tooling, unchanged). Do not let any task claim GRID-01 done on the strength
of `flutter test` alone.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Minute→pixel geometry (`yFor`/`heightFor`/`totalHeight`) | Client (pure Dart model) | — | `TimelineGeometry` is a pure arithmetic class with no widget-tree access — the single minute-to-pixel authority per `STATE.md`'s carry-forward invariant |
| Row positioning/dispatch (`_buildPositionedRow`) | Client (Flutter widget layer) | — | `today_screen.dart` owns placing every row via `Positioned` against `TimelineGeometry`'s output |
| Live-row density-tier selection | Client (widget layer, `LiveRowCard`) | — | Slot height (a value computed by the geometry layer) picks the tier inside the widget, mirroring `ChunkCard`'s existing `kFullTierMinHeight` pattern |
| Now-line overlay position | Client (widget layer, `NowLineOverlay`) | Geometry (position input) | Reads `geometry.yFor(nowMinutes)` — unaffected by this phase except that the value it reads is now branch-free |
| Scroll-to-now target | Client (widget layer, `_TodayScreenState.build()`) | Geometry (position input) | Same `geometry.yFor(nowMinutes)` call; the deleted branch changes the number only while a chunk is live, not the code path |
| Verification (grid uniformity) | Real browser (headless Chromium + pixel script) | `flutter test` (arithmetic-only) | This is the phase's central finding — see Validation Architecture |

No backend/API/database tier exists in this phase's scope — Canopy's `TimelineGeometry` and
`LiveRowCard` are pure client-side Flutter, and this phase touches no persistence, no service layer.

## Standard Stack

Not applicable in the conventional sense — this phase adds no new dependency. Confirmed via
`pubspec.yaml`: Flutter SDK `>=3.18.0-18.0.pre.54` (`CLAUDE.md`), installed toolchain measured at
`Flutter 3.44.1 • Dart 3.12.1` `[VERIFIED: flutter --version, run this session]`. Every widget used
by the UI-SPEC's locked layouts (`Card`, `IconButton`, `Row`, `Column`, `Positioned`, `ClipRect`,
`OverflowBox`, `Tooltip`, `Semantics`, `TextOverflow.ellipsis`) is a Flutter/Material-3 built-in
already imported elsewhere in `lib/screens/today/` — no new import.

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Flutter SDK (built-in Material 3 widgets) | 3.44.1 (installed) | `IconButton`, `Card`, `ClipRect`, `OverflowBox`, `Positioned` | Already the project's exclusive widget vocabulary for this screen — `27-UI-SPEC.md` explicitly rules out any new component library |

### Supporting

Not applicable — no supporting libraries added.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| In-house `TimelineGeometry` + density-tiered `LiveRowCard` | [`kalender`](https://pub.dev/packages/kalender) (pub.dev calendar package) | **Already settled, do not re-open** — ROADMAP.md's 2026-08-18 build-vs-buy call rejected it: the defect is one term, and adopting a 0.x calendar package to fix a one-line special case trades a small defect for a large dependency. Flips only if drag-to-reschedule, week/multi-day views, or timezones enter scope. |

**Installation:** none — no new packages this phase.

**Version verification:** Not applicable (no new packages). Existing `pubspec.yaml` dependencies
(`hive_ce`, `provider`, `go_router`, `flutter_lints`) are untouched by this phase's scope.

## Package Legitimacy Audit

**Not applicable — this phase installs no external packages.** `27-UI-SPEC.md`'s Registry Safety
section confirms: "Flutter/Material 3 project, no shadcn or component registry involved." Every
widget this phase touches is a Flutter SDK built-in already in use in `lib/screens/today/`.

**Packages removed due to [SLOP] verdict:** none (n/a)
**Packages flagged as suspicious [SUS]:** none (n/a)

## Architecture Patterns

### System Architecture Diagram

```
build() [today_screen.dart]
  │
  ├─► _nowFn() ─► nowDt (single clock sample, D-01 invariant)
  │
  ├─► resolveNowState(chunks, nowDt) ─► NowState (Active/Overdue/PreStart/GapBeforeNext/DayComplete)
  │
  ├─► buildTimeline(chunks, NowState, nowMinutes) ─► List<TimelineRow>
  │                                                    (ChunkRow.isLive marks exactly one row)
  │
  ├─► TimelineGeometry.forDay(nowMinutes, firstStart, lastEnd, liveStart, liveEnd)
  │     │
  │     │   BEFORE (defect):                    AFTER (this phase):
  │     │   liveExtraPx = reservedHeight          liveExtraPx term DELETED —
  │     │     - liveDurationPx                    yFor() purely linear
  │     │   yFor() += liveExtraPx once             (clamped - rangeStart)
  │     │     minutes >= liveEndMinutes             * kPixelsPerMinute
  │     │                                           + kTimelineEdgePadding
  │     ▼
  │   geometry.yFor(minutes) / .heightFor(start, dur) / .totalHeight
  │     │
  │     ├──────────────┬───────────────┬────────────────┬───────────────┐
  │     ▼               ▼               ▼                ▼               ▼
  │  Every non-live   Live ChunkRow   Hour-axis      Now-line        Scroll-to-now
  │  ChunkRow/GapRow  (THIS PHASE:    Positioned      overlay          target (raw =
  │  Positioned(       now goes        loop            Positioned       stackTop +
  │   height: slot)    through SAME    (unaffected —   (unaffected —    geometry.yFor
  │   + ClipRect +     path as         reads yFor       reads yFor       (nowMinutes))
  │   OverflowBox       every other     per hour         at nowMinutes)   — unaffected,
  │   (unchanged)       row now)        boundary)                        automatically
  │                        │                                              correct once
  │                        ▼                                              yFor() is
  │                 LiveRowCard(slotHeight: <duration-exact>)              linear
  │                        │
  │                        ├─ slotHeight >= kCompactLiveMinHeight (TARGET 88.0,
  │                        │   MUST re-measure) → Compact tier (kicker+title+
  │                        │   actions row, remaining-time line, NO progress bar)
  │                        │
  │                        └─ slotHeight <  kCompactLiveMinHeight → Single-line tier
  │                            (title · remainingLabel, Row/Expanded split,
  │                            Semantics wrapper, tap→ChunkDetailSheet if work chunk)
  │
  └─► Verification (OUT OF flutter test, see Validation Architecture):
        flutter build web --debug --source-maps --pwa-strategy=none
        → tools/serve-uat.py <port>
        → drive.cjs (headless Chromium, simulated clock via localStorage)
        → measure_hours.py screenshot.png → UNIFORM / NOT UNIFORM
```

### Recommended Project Structure

No new files or folders. Every edit lands in existing files:

```
lib/screens/today/
├── timeline_geometry.dart         # delete liveExtraPx field/computation/branch,
│                                   # delete kLiveRowReservedHeight, add kCompactLiveMinHeight
├── today_screen.dart              # delete the isLive "no height" branch; route live row
│                                   # through the same Positioned+ClipRect+OverflowBox path;
│                                   # thread slotHeight into _buildLiveRow/LiveRowCard;
│                                   # (new) thread onTap into LiveRowCard for the single-line
│                                   #  work-chunk tap-to-detail-sheet case
└── widgets/
    └── live_row_card.dart         # add slotHeight (required, non-null) param; delete the old
                                    # unconstrained build() branch; add _buildCompact() and
                                    # _buildSingleLine() per 27-UI-SPEC.md (NOT variants.patch
                                    # verbatim — UI-SPEC amends margin/typography/progress-bar/
                                    # weight from what the spike shipped)
```

### Pattern 1: Slot-height-driven density tier (already established house rule)

**What:** A widget receives a `slotHeight` (or equivalent) parameter and picks one of a fixed set
of layouts based purely on that number — never on business-logic type (work vs. break).
**When to use:** Any row on this timeline whose available vertical space varies by duration.
**Example (existing precedent this phase must mirror, `today_screen.dart`):**
```dart
// Source: lib/screens/today/today_screen.dart, existing non-live ChunkRow arm
final slot = geometry.heightFor(start, chunk.durationMinutes);
final density = isBreak
    ? (slot >= kFullBreakMinHeight ? ChunkCardDensity.full : ChunkCardDensity.compact)
    : (slot >= kFullTierMinHeight ? ChunkCardDensity.full : ChunkCardDensity.compact);
```
`LiveRowCard` must adopt the identical shape: `slotHeight >= kCompactLiveMinHeight ? compact :
singleLine`, per `27-UI-SPEC.md`'s "One rule, mirroring `26-UI-SPEC.md`'s existing rule... exactly."

### Pattern 2: `Positioned(height: slot)` + `ClipRect` + `OverflowBox(alignment: topCenter)` safety net

**What:** Every row (ordinary and, after this phase, live) is given an exact pixel-height
`Positioned` box. Its child is wrapped in `ClipRect` → `OverflowBox(minHeight: 0, maxHeight:
double.infinity, alignment: Alignment.topCenter)` so the child can lay out at its natural size
without a `RenderFlex` overflow error, while `ClipRect` guarantees nothing paints outside the slot.
**When to use:** Any row whose card content might (rarely) exceed its slot — e.g. a pathological
short chunk, or an unusually long live chunk whose content is shorter than its slot (leaves blank
`primaryContainer` fill below it, per UI-SPEC, "the same way an ordinary `ChunkCard` Full tier does
today").
**Example:**
```dart
// Source: lib/screens/today/today_screen.dart:778-793, existing non-live arm —
// this exact shape is what the live-row arm must become.
return Positioned(
  top: geometry.yFor(start),
  left: 0,
  right: 0,
  height: slot,
  child: ClipRect(
    child: OverflowBox(
      alignment: Alignment.topCenter,
      minHeight: 0,
      maxHeight: double.infinity,
      child: TimelineRowTile(child: _buildChunkCard(context, chunk, density)),
    ),
  ),
);
```
**Load-bearing detail for the live row specifically:** `27-UI-SPEC.md`'s own code block (lines
70-83) shows the live row does NOT get wrapped in `TimelineRowTile` — it stays `left: 0, right: 0`
full-bleed with its own restated `kCardLeftInset`/`kTimelineRowInset` margins inside `LiveRowCard`
itself (unchanged from today). Do not add `TimelineRowTile` around the live row — that would double
the horizontal inset, a documented regression class per `timeline_row_tile.dart`'s own doc comment
("Both did so with their own literal `16`, and both got it wrong at least once").

### Pattern 3: The 60-second "measure before you ship" ritual

**What:** Any Roboto-glyph-driven layout constant is treated as a hypothesis until measured in a
real, GPU-backed browser via `tools/serve-uat.py` + headless Chromium + a pixel-counting script,
never trusted from a `flutter test` pump.
**When to use:** `kCompactLiveMinHeight` in this phase specifically — `27-UI-SPEC.md` ships it as
`88.0` explicitly labeled "TARGET... MUST be re-measured" and gives the exact 9-step recipe (see
"The real-browser re-measurement recipe" below).

### Anti-Patterns to Avoid

- **Deriving `kCompactLiveMinHeight` (or any new layout constant this phase touches) from a
  `flutter test` pump.** This project's own `STATE.md` carry-forward invariant states plainly:
  "Any *text-driven* measurement asserted in a widget test is a harness bound, not a device
  requirement." Three corrections already paid for this lesson.
- **Keeping the old unconstrained `LiveRowCard.build()` branch as a fallback ("dead code, just in
  case").** `27-UI-SPEC.md` is explicit: "the old unconstrained `build()` branch is deleted along
  with `slotHeight == null`, not kept as dead code." `slotHeight` becomes a required, non-nullable
  parameter — there is no longer a legitimate caller that omits it.
- **Wrapping the live row in `TimelineRowTile`.** See Pattern 2 above — this is a specific,
  previously-shipped regression class.
- **Re-deriving `liveExtraPx`-style arithmetic inside the new equidistance test.** See Validation
  Architecture — the test must assert against the *definition* of uniformity (`60 *
  kPixelsPerMinute` per hour boundary), not replicate whatever the implementation currently computes
  — otherwise it is exactly the self-referential hole this phase exists to close.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|--------------|-----|
| Calendar/timeline layout engine | A custom drag-to-reschedule, multi-day, timezone-aware calendar widget | Stay in-house with `TimelineGeometry` (settled) | Out of this phase's scope entirely; ROADMAP's build-vs-buy call already rejected `kalender` for the current, narrower feature set |
| Icon-button minimum tap target enforcement | A custom `GestureDetector` wrapping a bare `Icon` to hit exactly 36×36 | `IconButton(constraints: BoxConstraints.tightFor(width: 36, height: 36))` | Flutter's own `IconButton.constraints` parameter, when supplied explicitly, replaces the default `kMinInteractiveDimension` (48.0) constraint outright — this is exactly how the spike's `variants.patch` achieved a working 36×36 icon button (and how the compact tier must be built) `[CITED: Flutter API docs — IconButton.constraints]` |
| Measuring layout in code at runtime (two-pass GlobalKey/RenderBox measure-then-correct) | A `GlobalKey`-based post-frame measure-and-`setState` cycle to auto-derive `kCompactLiveMinHeight` at runtime | A fixed, offline-measured constant (same mechanism choice already locked for `kLiveRowReservedHeight`, PD-2) | `timeline_geometry.dart`'s own doc comment on `kLiveRowReservedHeight` already rejected this approach project-wide: "a `GlobalKey`/`RenderBox` measure-then-correct flow buys ~10px of precision at the cost of a correction frame and a whole class of one-frame-snap bugs." Same reasoning applies to `kCompactLiveMinHeight`. |

**Key insight:** Nothing in this phase calls for new machinery — every problem this phase raises
already has a solved, in-codebase precedent (`kFullTierMinHeight`'s slot-height-picks-tier rule,
`ClipRect`/`OverflowBox`'s overflow safety net, the offline-measured-constant convention). The risk
is process discipline (measuring in the right place), not missing tooling.

## Runtime State Inventory

Not applicable — this is a pure client-side Flutter layout/rendering phase. No Hive schema change,
no persisted data keyed by the changed identifiers, no external service configuration, no OS-level
registration, no secrets, no build artifacts carrying the old geometry. **Nothing found in every
category** — verified by reading `timeline_geometry.dart`, `today_screen.dart`, and
`live_row_card.dart` in full: none reference Hive, `SharedPreferences`, or any persisted key derived
from `liveExtraPx`/`kLiveRowReservedHeight`. (This section is included per the protocol's trigger
list even though this phase is not a rename/refactor in the "identifier changes meaning" sense —
it deletes dead code and adds new widget layouts, it does not rename a persisted concept.)

## Common Pitfalls

### Pitfall 1: Trusting `flutter test` to prove GRID-01

**What goes wrong:** A plan/executor runs `flutter test`, sees 560+ tests green, and reports the
grid is uniform. It is not provably true — 240dp and 372dp both satisfy every existing assertion
today, because the tests check `yFor()` against the same arithmetic the implementation performs.
**Why it happens:** The test suite has always verified the geometry against itself, never against
an independent ground truth (equidistant hour boundaries).
**How to avoid:** Treat GRID-01 as unverified until (a) the new equidistance test is added AND
passes, AND (b) `measure_hours.py` prints `UNIFORM` against a real-browser screenshot taken while a
chunk is live. Both are required; neither alone is sufficient (the equidistance test is
harness-safe arithmetic, the pixel measurement is the independent ground-truth check).
**Warning signs:** A plan step marked "done" citing only `flutter test` output for a claim about
pixel spacing.

### Pitfall 2: Leaving `kLiveRowReservedHeight`-pinning tests in place, expecting them to just pass

**What goes wrong:** `test/screens/today_timeline_model_test.dart` contains **four** tests inside
the `'TimelineGeometry — CAL-01 minute→pixel mapping'` group that directly exercise
`geometry.liveExtraPx` and `kLiveRowReservedHeight` (lines 410-474): (1) `'the live row exception:
liveExtraPx == kLiveRowReservedHeight - 137.5'`, (2) `'the live row exception: heightFor(liveStart,
25) equals kLiveRowReservedHeight'`, (3) `'a row starting at liveEndMinutes has yFor equal to the
live row's bottom edge'` (asserts `yFor(565) == yFor(540) + kLiveRowReservedHeight`), and (4) `'G-02:
live-row reservation is tight against the real-browser measurement'` (asserts `kLiveRowReservedHeight`
is within `[measured, measured+16]` of `224.0`). Once `liveExtraPx` and `kLiveRowReservedHeight` are
deleted, tests (1), (2), and (4) reference symbols that no longer compile — this is a hard build
break, not a silent pass. Test (3) compiles differently once rewritten (see below) but its current
assertion is behaviorally false post-fix.
**Why it happens:** These tests were written to pin the exact behavior this phase deletes — they are
not adjacent tests, they are the tests *of* the swell.
**How to avoid:** Delete tests (1), (2), (4) outright — they assert a constant and field that no
longer exist. Rewrite test (3) to assert `yFor(565) == yFor(540) + heightFor(540, 25)` (i.e. the row
after a live chunk starts exactly at the live chunk's duration-exact bottom edge, not at some
swelled reservation) — this is the correct positive replacement, not a deletion, since the
underlying claim ("the next row starts immediately after the live row") is still true and worth
protecting.
**Warning signs:** `flutter analyze`/`flutter test` reporting `Undefined name 'liveExtraPx'` or
`Undefined name 'kLiveRowReservedHeight'` after the geometry file is edited — expected and correct;
treat as a todo checklist of exactly these four tests, not a surprise.

### Pitfall 3: `today_screen_test.dart`'s swell-behavior and button-chrome tests break too

**What goes wrong:** Two more tests outside `today_timeline_model_test.dart` encode behavior this
phase deletes:
1. `today_screen_test.dart:697-708`, `'the live row renders taller than its duration-implied slot,
   capped at kLiveRowReservedHeight'` — asserts `liveSize.height > 5 * kPixelsPerMinute` AND
   `liveSize.height <= kLiveRowReservedHeight`. Both clauses describe the swell this phase removes;
   `kLiveRowReservedHeight` won't compile once deleted. Replace with an assertion that the live
   row's rendered height equals its duration-exact slot (`heightFor(liveStart, liveDuration)`) —
   the new true-grid invariant.
2. `today_screen_test.dart:1121-1124`, inside `'hit-testing — a Complete tap still lands through the
   now-line (IgnorePointer proof)'` — finds `find.widgetWithText(FilledButton, 'Complete')` inside
   `LiveRowCard`. Once the compact tier ships, Complete is a bare `IconButton` with a `Tooltip`, not
   a `FilledButton.icon` with visible text. This finder returns zero matches → `tester.tap` throws.
   Fix: change the finder to locate the `IconButton` by its `Tooltip` message (`find.byTooltip(
   'Complete')` scoped `.ancestor`/descendant of `LiveRowCard`, or `find.widgetWithIcon(IconButton,
   Icons.check_circle_outline)` inside `LiveRowCard`).
**Why it happens:** These are exactly the two places the shipped widget's swelled height and
labelled-button chrome were asserted directly.
**How to avoid:** Grep `today_screen_test.dart` for `kLiveRowReservedHeight`, `FilledButton`, and
`OutlinedButton` scoped near `LiveRowCard` before considering the widget-layer task done — both hits
above are real, not hypothetical (confirmed by reading the file this session).
**Warning signs:** `tester.tap` throwing "Finder returned no widgets" — the exact failure this
change should be planned to produce and then fix, not discover after the fact.

### Pitfall 4: The `'nextLine'` ("Next · …") plumbing quietly becomes dead

**What goes wrong:** `27-UI-SPEC.md`'s locked compact-tier layout (the four-item list: kicker+title
row, 4dp gap, remaining-time line, no progress bar) and single-line tier (title · remainingLabel)
do not include a "Next · …" line anywhere. The shipped card's `nextLine` parameter (and
`today_screen.dart`'s `_buildLiveRow` computation of it, and its test at
`test/screens/today_screen_test.dart` around the `"Next · Reading at 10:50 AM"` comment near
line 502) has no home in either new tier. Left wired through, `nextLine` becomes a computed value
that is passed but never rendered — silent dead code, not a compile error, so nothing forces
noticing it.
**Why it happens:** The UI-SPEC only amends "The live row exception" section of `26-UI-SPEC.md`
per its own preamble — it is easy to carry forward every existing `LiveRowCard` parameter
unreflectively rather than checking each one against the new locked layouts.
**How to avoid:** Explicitly decide (planning-time, not silently at code-review time) whether
`nextLine`/`_buildLiveRow`'s next-chunk lookup is deleted outright (matching the spike's own
reasoning, restated in `variants.patch`: "the next row is literally drawn immediately below this
one," i.e. redundant now that the grid is true) or kept as unused dead code (against project
convention — see `STATE.md`'s Phase 22-01 precedent of explicitly suppressing rather than silently
leaving unused imports). Recommend deletion: the parameter, its computation, and the associated
"Next · Reading at 10:50 AM" test comment/assertion should all go together to avoid dead code that
`flutter analyze` won't catch (it's a used-but-unrendered parameter, not an unused one, unless also
removed from the constructor call).
**Warning signs:** `flutter analyze` staying clean while a manually-inspected compact-tier
screenshot shows no "Next" text anywhere — that is the tier working as specified, but if `nextLine`
is still being computed and threaded, it is wasted code that the next engineer will have to
re-investigate.

### Pitfall 5: The single-line tier's work-chunk tap target has no existing plumbing

**What goes wrong:** `27-UI-SPEC.md`'s single-line tier spec (open question "Tap target") requires:
"for a live **work** chunk that happens to render single-line... the whole row opens
`ChunkDetailSheet` on tap." Today, `LiveRowCard` has **no** `onTap` parameter and is never wrapped
in a `GestureDetector`/`InkWell` anywhere in `today_screen.dart` — the live row currently has no
tap-to-detail-sheet affordance at all (only the Complete/Skip buttons are interactive). This is new
plumbing, not a repaint: `LiveRowCard` needs a conditional tap handler, and `today_screen.dart` needs
to supply it by reusing `_openDetailSheet` (already used by the non-live `_buildChunkCard` path,
line ~668-677) for the live chunk.
**Why it happens:** The spike's `variants.patch` never explored this because its fixture never
exercised a live work chunk landing in the single-line tier — the spike's break case had no tap
target requirement (`27-UI-SPEC.md`'s spec: "a live **break** in the single-line tier keeps the
existing, unchanged rule: no tap target at all").
**How to avoid:** Plan a dedicated task/subtask for threading `onTap` through `LiveRowCard`'s
single-line branch, gated on `chunk.chunkType == ChunkType.work` (mirroring the existing
`showActions` gate's condition), wired to the same `_openDetailSheet(context, chunk, goalColor,
goalName, displayRationale)` call the non-live path already uses. Note the live row currently has
no `goalColor`/`goalName`/`displayRationale` lookups computed in `_buildLiveRow` — those helper calls
(`_lookupGoalColor`, `_lookupGoalName`, `_toDisplayRationale(chunk.rationale)`) need to be added at
that call site too.
**Warning signs:** A UAT pass where tapping a short live work chunk (e.g. a live commitment chunk
under 23 minutes) does nothing — the row has fill/elevation/now-line prominence but no interaction,
silently failing the UI-SPEC's own accessibility/interaction requirement.

### Pitfall 6: `kCompactLiveMinHeight`'s 88.0 value collides in spirit with `kFullTierMinHeight`

**What goes wrong:** `27-UI-SPEC.md` explicitly flags that its `88.0` *target* happens to equal the
already-shipped `kFullTierMinHeight` (also `88.0`), and suggests that if the real measurement lands
at or near that same number, reusing `kFullTierMinHeight` directly (rather than introducing a
second, nearly-identical constant) is "worth considering." A plan that blindly adds a second
constant without checking the measured value against the existing one risks two near-duplicate
88.0-ish thresholds sitting in the same file with no cross-reference, inviting a future "these two
numbers drifted apart, which one is right?" bug.
**Why it happens:** `kCompactLiveMinHeight`'s target was *derived* from `kFullTierMinHeight`'s own
measurement history (the UI-SPEC's derivation section explicitly walks from the spike's 90dp,
subtracting the progress bar and adjusting margin) — the two numbers are related by construction,
not coincidence.
**How to avoid:** After measuring, if the value is within ~2dp of `88.0`, decide explicitly (and
record the decision) whether to reuse `kFullTierMinHeight` or keep `kCompactLiveMinHeight` separate
with a doc comment cross-referencing the other constant's history — per `27-UI-SPEC.md`'s own
guidance: "if it lands meaningfully different, keep them separate (they threshold different card
layouts and have no reason to be coupled)."
**Warning signs:** A `timeline_geometry.dart` diff that adds `kCompactLiveMinHeight = 88.0` with no
comment referencing `kFullTierMinHeight`'s adjacent, identical value.

## Code Examples

### The one-line geometry deletion

```dart
// Source: lib/screens/today/timeline_geometry.dart, TimelineGeometry.forDay() — BEFORE
double liveExtraPx = 0.0;
if (liveStartMinutes != null && liveEndMinutes != null) {
  final liveDurationPx = (liveEndMinutes - liveStartMinutes) * kPixelsPerMinute;
  final extra = kLiveRowReservedHeight - liveDurationPx;
  liveExtraPx = extra > 0.0 ? extra : 0.0;
}
return TimelineGeometry(
  rangeStart: rangeStart, rangeEnd: rangeEnd,
  liveStartMinutes: liveStartMinutes, liveEndMinutes: liveEndMinutes,
  liveExtraPx: liveExtraPx,
);

// AFTER (27-UI-SPEC.md "Architecture: the live row joins the grid"):
// liveExtraPx field, the computation block above, and the "offset += liveExtraPx"
// branch inside yFor() are removed OUTRIGHT — not zeroed, not defaulted. yFor()
// becomes purely:
double yFor(int minutes) {
  final clamped = minutes < rangeStart
      ? rangeStart
      : (minutes > rangeEnd ? rangeEnd : minutes);
  return (clamped - rangeStart) * kPixelsPerMinute + kTimelineEdgePadding;
}
// liveStartMinutes/liveEndMinutes STAY on TimelineGeometry — G-03's now-line-chip
// suppression mechanism (in now_line.dart / today_screen.dart) still reads them
// directly and is untouched by this phase.
```

### The new equidistance regression test (closes the coverage hole — see Validation Architecture)

```dart
// Source: this phase's own required addition — pattern below, exact numbers TBD
// by planning. Place in test/screens/today_timeline_model_test.dart inside the
// existing 'TimelineGeometry — CAL-01 minute→pixel mapping' group (pure Dart,
// no widget pump — this assertion IS harness-safe, see Validation Architecture).
test(
  'GRID-01: every hour boundary is equidistant, even with a live chunk present',
  () {
    final geometry = TimelineGeometry.forDay(
      nowMinutes: 550,
      firstStartMinutes: 480,
      lastEndMinutes: 1020,
      liveStartMinutes: 540, // a live chunk mid-range, spanning an hour boundary
      liveEndMinutes: 565,
    );
    final boundaries = geometry.hourBoundaries;
    expect(boundaries.length, greaterThan(2), reason: 'fixture must span multiple hours');
    for (var i = 0; i < boundaries.length - 1; i++) {
      // Ground truth is 60 * kPixelsPerMinute — NOT a re-derivation of whatever
      // yFor() currently computes. This is what makes the test able to fail.
      expect(
        geometry.yFor(boundaries[i + 1]) - geometry.yFor(boundaries[i]),
        60 * kPixelsPerMinute,
        reason: 'boundary $i -> ${i + 1} must be exactly one hour of pixels',
      );
    }
  },
);
```
**Why this is the correct shape, and what makes it different from every existing test:** it asserts
against `60 * kPixelsPerMinute` — the independent definition of "one hour of pixels" — not against
`liveExtraPx` or any implementation-internal quantity. A regression that reintroduces a live-row
exception term would make this test fail, because 240 ≠ 372 even though both would still "satisfy"
the old self-referential tests. **Proveably RED first**, per `STATE.md`'s carry-forward invariant
("Regression tests must be proven RED... Observe red against the unfixed code before accepting a
regression test") — run this test against the *current* (unfixed) `timeline_geometry.dart` before
making the one-line change, confirm it fails, then make the fix and confirm it passes.

### Icon-only Complete/Skip at 36×36dp (compact tier, per UI-SPEC)

```dart
// Source: 27-UI-SPEC.md "Compact tier" section — the exact locked pattern,
// close to the spike's own variants.patch _buildCompact() (evidence the pattern
// works in a real browser — spike measured 86px fill in a 100dp slot with this
// exact IconButton shape).
IconButton(
  tooltip: 'Complete',
  icon: const Icon(Icons.check_circle_outline),
  color: colorScheme.primary,
  constraints: const BoxConstraints.tightFor(width: 36, height: 36),
  visualDensity: VisualDensity.compact,
  padding: EdgeInsets.zero,
  onPressed: () => context.read<ScheduleNotifier>().markComplete(chunkId),
),
```
`[CITED: Flutter API docs — IconButton.constraints]` — explicit `constraints:` on `IconButton`
replaces the default `BoxConstraints(minWidth: kMinInteractiveDimension, minHeight:
kMinInteractiveDimension)` (48.0) outright, so this genuinely lays out at 36×36, not floored to
48×48. Corroborated empirically: the spike used this exact shape and measured an 86px total compact
card fill inside a 100dp slot in a real headless-Chromium browser — the numbers only work if the
buttons are truly 36×36, not 48×48 (two 48px buttons plus text would not fit in 100dp at all).

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| Live row rendered with no `height:` constraint, allowed to swell past its duration-implied slot into a fixed `kLiveRowReservedHeight` reservation | Live row rendered through the same `Positioned(height: slot)` + `ClipRect`/`OverflowBox` path as every other row, with `LiveRowCard` picking a density tier from `slotHeight` | This phase (27) | Deletes one geometry field, one constant, and one widget code branch; the live row becomes duration-exact like everything else; the day gets ~132dp shorter for a standard 25-minute live chunk (a documented, welcome side effect the spike measured) |
| `LiveRowCard`'s Complete/Skip as `FilledButton.icon`/`OutlinedButton.icon` (labelled buttons) | Bare `IconButton`s with `Tooltip` (icon-only), 36×36dp, in the compact tier only | This phase (27) | Frees horizontal/vertical space needed to fit inside a 100dp slot; introduces a stated, deliberate WCAG touch-target exception (36dp < 44dp recommended) flagged for UAT re-verification on an actual touch device |
| Progress bar (`LinearProgressIndicator`) always rendered on the live card | Dropped entirely from the compact tier (and absent from single-line, which never had one) | This phase (27) | ~10dp of reclaimed vertical space; removes a redundant rendering of the same fact the now-line's position already conveys geometrically |

**Deprecated/outdated:**
- `kLiveRowReservedHeight` (232.0): the entire concept of a fixed "reservation" for the live row is
  retired by this phase — replaced by duration-exact slots for every row, live or not.
- The live row's "Next · …" line and its underlying `nextLine` plumbing: not explicitly named as
  deprecated by any locked document, but has no home in either new tier's locked layout (see
  Pitfall 4) — planning must make an explicit call, not inherit it silently.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `IconButton(constraints: BoxConstraints.tightFor(width: 36, height: 36))` lays out at true 36×36dp rather than being floored to Material's 48dp minimum interactive dimension | Don't Hand-Roll, Code Examples | LOW — corroborated both by Flutter's own documented `constraints` override behavior `[CITED: Flutter API docs]` AND by the spike's own real-browser measurement (86px fill in a 100dp slot only works if the buttons are genuinely 36px); if wrong, the compact tier's action row would overflow its slot and this would be caught immediately by the mandatory real-browser re-measurement step (recipe below), not shipped silently |
| A2 | The "Next · …" line (`nextLine` parameter, `_buildLiveRow`'s next-chunk lookup) should be deleted outright rather than kept as unused/dead code | Pitfall 4 | MEDIUM — this is a recommendation, not a locked decision; `27-UI-SPEC.md` does not explicitly say "delete `nextLine`," it simply omits it from both tiers' locked layouts. If planning instead keeps it wired but unrendered, the risk is only code cleanliness (an unused-but-still-computed value), not a functional defect — but it should be a deliberate planning call, not an oversight |
| A3 | `today_screen_test.dart`'s test at line 1121-1124 is the only test in the file that locates Complete/Skip inside `LiveRowCard` by `FilledButton`/`OutlinedButton` widget type with visible text | Pitfall 3 | LOW-MEDIUM — confirmed by grep of the file for `FilledButton`/`OutlinedButton` near `LiveRowCard`, but a full re-grep after the geometry/widget changes land (before considering the test task done) is cheap insurance against a second hit this research missed |

**All other claims in this research are `[VERIFIED]` (confirmed by reading the actual source files,
running `flutter --version`, or running the Playwright/Pillow availability checks this session) or
`[CITED]` (the UI-SPEC/ROADMAP/spike documents, which this phase treats as locked inputs).**

## Open Questions

1. **Should `kCompactLiveMinHeight` be a distinct constant from `kFullTierMinHeight` if the
   real-browser measurement lands at or near 88.0?**
   - What we know: `27-UI-SPEC.md` explicitly raises this as a planning-time decision, not a locked
     answer — "worth considering during planning" if the numbers coincide.
   - What's unclear: the actual measured value (not yet taken — it can't be, until the compact
     tier is built).
   - Recommendation: build first per spec, measure per the recipe below, THEN decide; do not
     pre-emptively merge the constants before measuring, since UI-SPEC also notes "if it lands
     meaningfully different, keep them separate."

2. **Does deleting `nextLine`/the next-chunk lookup ripple into any other test beyond the one
   comment noted in Pitfall 4?**
   - What we know: one test comment (`today_screen_test.dart` near line 502-503) explicitly
     mentions the live row's "Next · Reading at 10:50 AM" text as a disambiguation concern.
   - What's unclear: whether any other test asserts `nextLine`'s content directly (a full grep for
     `'Next ·'` across the test file, beyond the one hit already found via grep for `kicker`/
     `remainingLabel`/`nextLine`/`'Next ·'`, turned up only that one comment — but planning should
     re-grep after the widget change, not rely solely on this pre-change research).
   - Recommendation: grep `test/screens/today_screen_test.dart` for `'Next ·'` and `nextLine` as
     part of the same task that removes the parameter, not as a separate follow-up.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Flutter SDK | building the debug web bundle for re-measurement | ✓ | 3.44.1 (stable channel) | — |
| Playwright (Node, global npm install) | `tools/drive.cjs` headless-Chromium driver | ✓ | confirmed loadable this session (`require('playwright')` succeeded) | — |
| Pillow (system python3) | `tools/measure_hours.py` pixel measurement | ✓ | 10.2.0 | — |
| `tools/serve-uat.py` | serving the debug build with correct no-cache headers | ✓ | present at repo root (`/home/dan/CodeProjects/canopy/tools/serve-uat.py`) | — |
| `.planning/spikes/001-live-row-in-a-true-grid/tools/{drive.cjs,measure_hours.py}` | the phase's re-measurement recipe (UI-SPEC step 4/9) | ✓ | present, reusable as-is (see Validation Architecture "What the spike's tooling does NOT cover") | — |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** none — everything the mandatory re-measurement recipe needs
is already installed and working in this environment.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` (bundled with Flutter SDK 3.44.1) + a standalone real-browser measurement step (NOT `flutter_test`) |
| Config file | none — standard `flutter test` discovery of `test/**/*_test.dart` |
| Quick run command | `flutter test test/screens/today_timeline_model_test.dart` (pure geometry, no widget pump — fastest feedback for the arithmetic half) |
| Full suite command | `flutter test` |
| Independent ground-truth command (NOT flutter_test) | `python3 .planning/spikes/001-live-row-in-a-true-grid/tools/measure_hours.py <screenshot.png>` against a real-browser screenshot taken while a chunk is live |

### The load-bearing split: arithmetic vs. pixels

This phase's central methodological finding, stated plainly because it governs every acceptance
criterion the planner writes:

**Harness-safe (trustworthy in `flutter test`) — geometric/arithmetic claims:**
- `TimelineGeometry.yFor()`/`heightFor()`/`totalHeight` return values, computed purely from `int`
  minutes and the `kPixelsPerMinute` constant — no text measurement involved anywhere in this class.
- The new equidistance test (`yFor(h+60) - yFor(h) == 60 * kPixelsPerMinute` across every hour
  boundary, with a live chunk present) — this is pure arithmetic on already-known constants, exactly
  the class `STATE.md`'s carry-forward invariant names as trustworthy: "Geometric assertions
  (heights and offsets computed from arithmetic) ARE trustworthy."
- `heightFor(liveStart, liveDuration) == duration * kPixelsPerMinute` (the row is duration-exact,
  no swell) — same reasoning.
- Widget-tree structural assertions that don't depend on real glyph metrics: which widget type
  wraps which, `Positioned.height` values, `ClipRect`/`OverflowBox` presence — these are Flutter
  layout facts independent of font rendering.

**NOT harness-safe (real-browser only) — glyph/layout-metric claims:**
- `kCompactLiveMinHeight`'s actual numeric value (currently an explicit, un-measured `88.0`
  estimate per `27-UI-SPEC.md`) — this is a Roboto-glyph-driven natural-height measurement, exactly
  the class that has burned this project three times (`kGutterWidth`, `kPixelsPerMinute`,
  `kLiveRowReservedHeight` — all `flutter test`-derived numbers that were wrong).
- Whether the compact tier's content actually fits inside its slot without clipping (title
  ellipsis behavior, icon-button sizing, kicker/title stacking) — `flutter test`'s placeholder font
  has no real Roboto metrics (`kGutterWidth`'s own doc comment: "'1', 'i', 'W', ':' and 'p' all
  measure exactly 12.0px at fontSize 12 — real proportional Roboto metrics are not loaded").
- The single-line tier's natural height staying under 20dp (the smallest guaranteed slot).
- **GRID-01 itself** — "every hour occupies the same vertical distance" is, at the level that
  matters to a human looking at the screen, a *rendered pixel* claim. The equidistance unit test
  proves the *geometry function* is branch-free; it does NOT prove the *rendered app* paints
  uniformly (a widget could theoretically still overflow its slot and visually distort spacing
  despite correct arithmetic — unlikely given `ClipRect`, but `measure_hours.py` against a real
  screenshot is the only claim that closes this gap end-to-end).

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|---------------------|--------------|
| GRID-01 | `yFor()` is purely linear, no live-row branch | unit (arithmetic) | `flutter test test/screens/today_timeline_model_test.dart -x` (targeting the new equidistance test) | ✅ (file exists; new test to be added within it) |
| GRID-01 | Rendered hour-label spacing is pixel-uniform in a real browser while a chunk is live | manual/scripted real-browser measurement (NOT flutter_test) | `python3 .planning/spikes/001-live-row-in-a-true-grid/tools/measure_hours.py <screenshot>` — prints `UNIFORM`/`NOT UNIFORM` | ✅ tool exists and is reusable as-is |
| GRID-02 | Live row renders through the same `Positioned(height:)`+`ClipRect`+`OverflowBox` path as every other row, duration-exact | widget test | `flutter test test/screens/today_screen_test.dart -x` (existing swell test, rewritten per Pitfall 3) | ✅ (file/test exist; rewrite required) |
| GRID-02 | Compact tier renders correctly (kicker/title/actions/remaining-time, no progress bar) at a live 25-min work chunk's 100dp slot | widget test + real-browser measurement | widget test for structure; `measure_hours.py`-style pixel-count (or manual screenshot inspection) for `kCompactLiveMinHeight`'s actual value | ⚠️ widget test needs authoring; real-browser step is Wave 0-adjacent (see below) |
| GRID-02 | Single-line tier renders correctly (title · remainingLabel, tap-to-detail for live work chunks, no tap for live breaks) at a live 5-min break's 20dp slot | widget test | new widget test in `today_screen_test.dart` | ⚠️ needs authoring |
| GRID-02 | Now-line crossing the live card remains legible (no suppression, no z-order change) | widget test (existing precedent) | existing now-line tests in `today_screen_test.dart` (`'Phase 26 — CAL-02 the now-line'` group) should continue to pass unmodified — this phase does not touch `NowLineOverlay` | ✅ |

### Sampling Rate

- **Per task commit:** `flutter test test/screens/today_timeline_model_test.dart test/screens/today_screen_test.dart` (targeted, fast feedback on the two files this phase touches)
- **Per wave merge:** `flutter test` (full suite — this phase's changes are concentrated in
  `lib/screens/today/`, but the full suite catches any accidental cross-file breakage, e.g. other
  files importing `kLiveRowReservedHeight`)
- **Phase gate (mandatory, cannot be skipped):** full `flutter test` green AND
  `tools/measure_hours.py` prints `UNIFORM` against a real-browser screenshot taken while a chunk is
  live, served via `tools/serve-uat.py` on a fresh, never-before-used port (per `CLAUDE.md` trap #1)
  — before `/gsd-verify-work` is run for this phase.

### Wave 0 Gaps

- [ ] No new test *file* is needed — both consumer test files (`today_timeline_model_test.dart`,
  `today_screen_test.dart`) already exist and already have the relevant groups
  (`'TimelineGeometry — CAL-01 minute→pixel mapping'`, `'Task 2 — the day as one list...'`,
  `'Phase 26 — CAL-01 the day has a shape'`). No `conftest`-equivalent shared fixture work needed —
  Dart's `buildDayFixture()`/`longDayFixture()`/`twoChunkFixture()` helpers already exist in
  `today_screen_test.dart` and cover the needed live-chunk-duration variety (5-minute break/work
  chunk for single-line tier, 25-minute work chunk for compact tier).
- [ ] A **real-browser measurement task** is a genuine Wave 0-adjacent gap in the sense that it
  cannot be automated inside `flutter test` — it must be sequenced as its own task, after the
  widget-layer implementation lands (the compact tier must exist before its natural height can be
  measured), using the exact 9-step recipe `27-UI-SPEC.md` already specifies (reproduced below for
  convenience). This is not a missing test-framework gap — it is a categorically different kind of
  verification step the planner must schedule explicitly as a task, not assume `flutter test`
  covers.

### The real-browser re-measurement recipe (reusable as-is; assessed this session)

`.planning/spikes/001-live-row-in-a-true-grid/tools/drive.cjs` and `tools/measure_hours.py` are
**directly reusable, unmodified**, for this phase's verification — confirmed by reading both scripts
in full this session:
- `drive.cjs` onboards a persistent Chromium profile (idempotent — re-running against an
  already-onboarded profile skips straight to setting the clock), sets an exact simulated instant
  via `localStorage['flutter.dev_clock_offset_micros']`, and screenshots at 430×930/DPR 1. It takes
  a `--at=HH:MM` flag — usable unmodified for both the compact-tier moment (e.g. `08:55`, 20% into a
  25-minute chunk, matching the spike's own capture) and the single-line moment (e.g. `09:17`,
  inside a 5-minute break).
- `measure_hours.py` scans the `kGutterWidth`-wide left strip for hour-label ink and prints
  `UNIFORM`/`NOT UNIFORM` plus exact spacing numbers — its background-color derivation is
  theme-agnostic, and its gutter-width parameter (`--gutter=40`) already matches the current
  `kGutterWidth = 40.0` (verified against `timeline_row_tile.dart`).

**What the tooling does NOT cover** (per the spike's own "What This Does NOT Claim" section,
carried forward as this phase's residual risk, not resolved by re-running the same tooling):
dark theme, desktop-width viewports, large accessibility text scales, and the `Overdue` live state.
None of these are required by GRID-01/GRID-02's stated scope, but if planning wants extra
confidence, `drive.cjs`'s viewport/profile setup would need extension (a wider viewport arg, a
theme toggle) — out of scope for this phase's minimum bar per the UI-SPEC, worth flagging to the
planner as an explicit scope decision (include or defer) rather than silently assuming coverage.

**The 9-step recipe** (per `27-UI-SPEC.md` "Re-measurement is mandatory before this constant
ships"), unmodified from the UI-SPEC and confirmed executable with tooling present in this
environment:
1. Implement the compact tier exactly as specified (no progress bar, corrected margin).
2. `flutter build web --debug --source-maps --pwa-strategy=none`.
3. Serve with `python3 tools/serve-uat.py <port> --dir build/web` (fresh port, never reused across
   build types — `CLAUDE.md` trap #1).
4. Drive to a simulated instant inside a live work chunk (e.g. `08:55`) via `drive.cjs --at=08:55`.
5. Screenshot headless Chromium at 430×930, DPR 1, `--use-gl=swiftshader
   --enable-unsafe-swiftshader` (already `drive.cjs`'s default — avoids `CONTEXT_LOST_WEBGL`,
   `CLAUDE.md` trap #2).
6. Pixel-count the compact card's `primaryContainer` fill height.
7. Set `kCompactLiveMinHeight` to that measured height + an explicit, documented safety margin.
8. Separately confirm the single-line tier's natural height (drive to `09:17` or equivalent) stays
   comfortably under 20dp.
9. Run `measure_hours.py` against a screenshot taken while a chunk is live — must print `UNIFORM`.

## Security Domain

Not applicable — `.planning/config.json` does not set `security_enforcement`, and this phase touches
no authentication, authorization, network I/O, cryptography, or user-supplied input validation. It
is a pure client-side layout/rendering change to an already-trusted, already-loaded local schedule.
No ASVS category applies.

## Sources

### Primary (HIGH confidence — read in full this session)

- `.planning/phases/27-true-grid/27-UI-SPEC.md` — the design contract, every locked value
- `.planning/phases/27-true-grid/27-CONTEXT.md` — phase boundary and specifics
- `.planning/ROADMAP.md` "Phase 27: True Grid" section — the DECIDED block and spike table
- `.planning/spikes/001-live-row-in-a-true-grid/README.md` — full investigation trail, verdict,
  residual risks, "What This Does NOT Claim"
- `.planning/spikes/001-live-row-in-a-true-grid/variants.patch` — reference implementation diff
- `.planning/spikes/001-live-row-in-a-true-grid/tools/drive.cjs` — read in full, verified reusable
- `.planning/spikes/001-live-row-in-a-true-grid/tools/measure_hours.py` — read in full, verified
  reusable, gutter-width parameter matches current `kGutterWidth`
- `.planning/spikes/CONVENTIONS.md`
- `.planning/STATE.md` — carry-forward invariants, three-strikes history
- `lib/screens/today/timeline_geometry.dart` — full file read
- `lib/screens/today/today_screen.dart` — full file read (1531 lines)
- `lib/screens/today/widgets/live_row_card.dart` — full file read
- `lib/screens/today/widgets/timeline_row_tile.dart` — full file read
- `test/screens/today_timeline_model_test.dart` — full file read (490 lines)
- `test/screens/today_screen_test.dart` — read in full via targeted sections (2113 lines; header,
  the four `kLiveRowReservedHeight`/`liveExtraPx` grep hits, the FilledButton 'Complete' hit, the
  "Next ·" comment, all inspected directly)
- `CLAUDE.md` (project) — UAT hosting protocol, the three traps
- Session-verified: `flutter --version` (3.44.1), `require('playwright')` (loadable),
  `python3 -c "import PIL"` (Pillow 10.2.0 present), `tools/serve-uat.py` present at repo root

### Secondary (MEDIUM confidence)

- [IconButton.constraints — Flutter API docs](https://api.flutter.dev/flutter/material/IconButton/constraints.html)
  and corroborating GitHub issue discussion, confirming explicit `constraints:` overrides the
  default 48dp minimum interactive dimension — cross-checked against the spike's own successful
  real-browser measurement using this exact pattern.

### Tertiary (LOW confidence)

None — every claim in this document is either read directly from the codebase/planning artifacts
this session, or cited to official Flutter documentation and cross-checked against the spike's
empirical evidence.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies; every widget already in use in the codebase
- Architecture: HIGH — every pattern cited is either read directly from existing shipped code
  (`today_screen.dart`'s non-live row path) or locked verbatim in `27-UI-SPEC.md`
- Pitfalls: HIGH — every pitfall in this document was found by directly grepping and reading the
  actual test files this session (not inferred), with exact line numbers and current assertion text
- Verification split (arithmetic vs. pixels): HIGH — this is a restatement/extension of the
  project's own three-times-proven carry-forward invariant, applied concretely to this phase's exact
  constants and test files

**Research date:** 2026-08-18
**Valid until:** No hard expiry — this research is tied to the current state of
`lib/screens/today/` and `27-UI-SPEC.md`, both dated 2026-08-18. Re-verify the four
`kLiveRowReservedHeight`/`liveExtraPx` test locations and the `FilledButton` finder location if
significant time passes before planning executes and either file is touched by other work first.
