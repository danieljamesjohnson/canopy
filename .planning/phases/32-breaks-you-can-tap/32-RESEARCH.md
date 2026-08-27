# Phase 32: Breaks You Can Tap - Research

**Researched:** 2026-08-27
**Domain:** Flutter widget geometry migration + gesture-to-button interaction replacement (in-house code, no new packages)
**Confidence:** HIGH — every claim below was checked by reading the live source or running the live suite this session, not by trusting the ROADMAP/CONTEXT/UI-SPEC's own restatements.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

These three were ruled by the owner on 2026-08-27 and are recorded in the ROADMAP phase entry.
Planning must treat them as fixed inputs.

- **D-32-01 — `kPixelsPerMinute` 4.0 → 6.0.** This **reverses Phase 29 D-03**, which rejected
  raising it. That rejection was made on *legibility* evidence and is not wrong on its own terms; it
  is overturned by evidence that did not exist then — two rounds of a real thumb failing on a 20dp
  row. Chosen over three alternatives specifically **because it keeps the grid honest**: every row
  still renders at exactly `durationMinutes × kPixelsPerMinute`. A 5-min break becomes 30dp, a
  25-min work chunk 150dp. **Known cost, accepted by the owner: the day is 50% taller to scroll**
  (an 8-hour day 1920dp → 2880dp). The rejected alternatives all bought a bigger break by making
  some row lie about its duration.

- **D-32-02 — breaks become button-only; the swipe is removed from break rows.** Chosen over
  keeping both. **Reverses D-31-01's one-directional `Dismissible` for breaks and makes D-31-06 dead
  — both halves of it.** Retire the dead machinery deliberately; do not leave an unused
  invisible-band mechanism in the tree. Accepted inconsistency: work chunks stay swipeable, so
  breaks and work no longer share a gesture vocabulary. The owner was shown that trade-off and took
  it.

- **D-32-03 — the Skip button is ~64dp wide × the full 30dp row height.** At 6.0 px/min a 5-min row
  is 30dp, under Material's 48dp minimum, so the button earns its target area from **width** instead
  of height: ~64 × 30 = 1920dp² against the 48 × 48 = 2304dp² guideline. Slightly under on raw area,
  and **deliberately so** — every pixel of it is *visible*, and a wider-than-tall target suits a
  thumb's contact patch better than a square one. Three alternatives were offered and declined: a
  vertically-overhanging hit area would hit 48dp *on paper* by extending into invisible space (the
  exact pattern that failed the owner twice) and would steal target area from neighbouring work
  chunks again; a 48dp floor on short breaks was declined because it makes the row lie about its
  duration.

### Claude's Discretion

Everything not fixed above — file layout, widget decomposition, how the density-tier thresholds are
re-derived from `kPixelsPerMinute`, test structure — is at Claude's discretion, guided by the
ROADMAP success criteria and existing codebase conventions. Discuss was skipped per
`workflow.skip_discuss=true`.

### Deferred Ideas (OUT OF SCOPE)

None — discuss phase skipped.

**What this phase must NOT do (ROADMAP, restated because it bounds every recommendation below):**

- Do not make any row lie about its duration (SKIPBREAK-02's spirit survives D-32-01 intact).
- Do not remove the swipe from work chunks. Only breaks become button-only.
- Do not remove `LiveRowCard`'s compact-tier Skip button (D-31-07). It survives unchanged.
- Do not re-litigate skipped-break legibility at `Opacity(0.5)` or D-31-03's "skipping a break does
  not hand the minutes back." Both PASSED human UAT and are settled.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TAPBREAK-01 | A break is skipped by a visible, labelled button; no swipe, no invisible target. | "The retirement surface" + "The Skip rail" sections below identify every file:line that must change to remove the swipe and add the button, and the exact widget tree (verified against `32-UI-SPEC.md` and the live `swipeable_chunk_card.dart`/`chunk_card.dart` source). |
| TAPBREAK-02 | The grid still tells the exact truth: every row renders at `durationMinutes × kPixelsPerMinute`, at the new 6.0. | "The `kPixelsPerMinute` blast radius" section gives the verified, corrected literal-migration list; "Density-tier reachability at 6.0" gives the verified per-constant reachability table. |
| TAPBREAK-03 | A 5-minute break reads as a section of the day, not a hairline. | "Density-tier reachability at 6.0" + "The retirement surface" (retiring `_SubCompactRow`) establish that the new Card-based compact tier is the only tier a 5-min break can reach at 6.0, and what replaces the old hairline. |
</phase_requirements>

## Summary

This phase is a **constant migration + gesture-to-button swap** inside four already-well-documented
files (`timeline_geometry.dart`, `chunk_card.dart`, `swipeable_chunk_card.dart`,
`live_row_card.dart`) plus their call sites in `today_screen.dart`. There is no new package, no new
architectural layer, and (per the UI-SPEC, confirmed against the live source this session) a fully
specified widget tree for the one new component (`BreakSkipButton`). The engineering risk is not
"can this be built" — it's "does every one of ~12 interlocking constants and ~9 render-arm branches
get updated together," because this codebase has a documented three-strikes history of exactly this
kind of migration going wrong quietly (`kGutterWidth` 46→75→52, `kPixelsPerMinute` 4.0→5.5→4.0,
`kCompactLiveMinHeight` 88→84→88).

I independently re-ran the ROADMAP/CONTEXT's own migration survey rather than trusting it, and it
holds up almost exactly: **38 symbolic `kPixelsPerMinute` references across exactly the 4 named test
files** (verified: `grep -c` per file sums to 38 exactly), and only a small number of hardcoded pixel
literals — **but the true count is 3, not 4**, once retired-mechanism tests (which contain their own
hardcoded pixel offsets but are being *deleted*, not *migrated*) are excluded. See "The
`kPixelsPerMinute` blast radius" below for the corrected, itemized list — this is the one place this
research overturns the ROADMAP's own number, in the direction the ROADMAP's own caveat anticipated
("if the count is wrong in either direction, say so").

The single largest hidden cost in this phase is **test deletion, not test migration**: reading
`today_screen_test.dart`'s "Phase 31 — SKIPBREAK" group (766 lines, the entire back half of the
file) shows it splits cleanly into ~7 `testWidgets` that drive a synthetic drag gesture (all dead
the moment `Dismissible` is removed from break rows) and ~5 `testWidgets` under a
`SKIPBREAK-02 — the grid is unchanged` subgroup that assert pure painted geometry with no gesture
dependency (these survive and only need the pixel literal inside one of them re-derived). The same
split exists in `today_screen_now_state_test.dart`'s live-break group. Undercounting the deletion
work (vs. treating everything as "needs editing") is the likeliest way this phase's test-file task
balloons unnecessarily.

**Primary recommendation:** Treat this as five essentially independent, ordered pieces of work: (1)
re-derive `timeline_geometry.dart`'s constants and delete the four retired ones, verified against the
reachability table below; (2) delete the swipe/slop machinery in `today_screen.dart` and
`swipeable_chunk_card.dart` (restore `SwipeableChunkCard`'s pre-Phase-31 early return); (3) build
`BreakSkipButton` and wire it into `chunk_card.dart`'s two break tiers and `live_row_card.dart`'s
single-line tier; (4) delete the ~7 gesture-driven tests, migrate the ~3 pixel literals in the
surviving grid-honesty tests, delete the now-meaningless sub-compact-tier-boundary test; (5) the
real-browser compact-tier fit check + human UAT. Do not attempt a single "big" task that touches all
four files at once — the four files change for different reasons (arithmetic constant, retired
class, new widget, screen wiring) and can be verified independently before integration.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Minute→pixel scale (`kPixelsPerMinute`) | Frontend Server (SSR — N/A here; this is a pure-Dart client app) → **Client, pure geometry layer** | — | `TimelineGeometry` is a plain Dart class with no widget/BuildContext dependency (verified: `timeline_geometry.dart` imports only `../../utils/time_format.dart`). It is the single minute-to-pixel authority per the project's own carry-forward invariant. |
| Density-tier selection (which card layout renders) | Client — widget layer (`today_screen.dart`'s `_buildPositionedRow`) | Client — `ChunkCard`/`LiveRowCard` (each also self-selects internally) | Tier selection is duplicated by design: the screen picks `ChunkCardDensity` from `slot`, and `LiveRowCard` separately compares its own `slotHeight` against `kCompactLiveMinHeight` internally. Both are pure arithmetic, no I/O. |
| Skip action (state mutation) | Client — `ScheduleNotifier` (a `ChangeNotifier`, this app's provider-based state layer) | Client — Hive persistence (`_repo.save`) | `markSkipped(chunkId)` already exists, is type-agnostic, and already has the WR-05 revert-and-rethrow contract (verified, `schedule_notifier.dart:687-745`). This phase changes what *calls* it (a button's `onPressed` instead of `Dismissible.confirmDismiss`), not the method itself. |
| Visual rendering of the break row | Client — `chunk_card.dart` / `live_row_card.dart` | — | No server/backend exists in this app; all rendering is client-side Flutter. |
| Persistence of `isSkipped` | Client — Hive (local device storage via `HiveDailyScheduleRepository`) | — | Unaffected by this phase; the persistence path is identical whether skip is triggered by drag or by tap. |

This is a single-tier (client-only) Flutter app — there is no separate backend/API for this feature.
The map above exists mainly to confirm there is **no tier misassignment risk** here: every piece of
this phase's work is client-side Dart, and the one class that must never become tier-aware
(`TimelineGeometry`) already enforces that with a documented "no clock read" invariant that this
phase does not touch.

## Standard Stack

Not applicable in the conventional sense — **this phase adds no new package**. Every widget primitive
used (`Card`, `Row`, `Material`/`InkWell`, `Semantics`, `Center`, `SizedBox`) is Flutter SDK Material,
already imported throughout `lib/screens/`. No `pubspec.yaml` change is required.

**Version verification (existing toolchain, re-confirmed this session):**
```
$ flutter --version
Dart SDK ^3.10.3, Flutter (bundled at /home/dan/development/flutter/bin)
```
`pubspec.yaml:22` pins `sdk: ^3.10.3`; `pubspec.yaml:44-45` declares `flutter_test` via the `sdk:
flutter` source (no version pin needed/possible for the bundled test package).

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| A shared `BreakSkipButton` widget (`lib/widgets/`) | Two independent Skip-button implementations, one per call site (`chunk_card.dart` and `live_row_card.dart`) | UI-SPEC explicitly rejects this (visual drift risk between the two call sites) — confirmed as the only cross-cutting new widget this phase needs, per the file-search below (no existing `lib/widgets/break_skip_button.dart` or `kBreakSkipButtonWidth` anywhere in the tree — greenfield). |

**Installation:** none — no new dependency.

## Package Legitimacy Audit

**Not applicable.** This phase introduces zero external packages. `grep -rn "kBreakSkipButtonWidth"
lib/ test/` and `find lib -iname "*break_skip*"` both return empty — the new widget and constant are
fully greenfield within this phase's own file set, built from Flutter SDK primitives only.

## Architecture Patterns

### System Architecture Diagram

```
User's thumb
     │  tap
     ▼
BreakSkipButton.onTap ──────────────► context.read<ScheduleNotifier>().markSkipped(chunkId)
     │                                        │
     │  (rendered inside)                     │  mutates chunk.isSkipped = true (optimistic)
     ▼                                        ▼
 ┌─────────────────────────┐          _repo.save(_todaySchedule)  ──► Hive box (disk)
 │ ChunkCard._buildBreak    │                 │
 │  (non-live break card)   │                 ▼
 │  OR                      │          _logRepo.append(CompletionLog)
 │ LiveRowCard._buildSingleLine │             │
 │  (live short-break tier) │           on failure: chunk.isSkipped = false, rethrow (WR-05)
 └─────────────────────────┘                  │
     ▲                                        ▼
     │ density/tier selection           notifyListeners() ──► TodayScreen rebuilds
     │ (ChunkCardDensity / slotHeight        │
     │  vs. kFullBreakMinHeight /             ▼
     │  kCompactLiveMinHeight)          Row re-renders: strikethrough title,
     │                                  Skip rail → 'skipped' text (same 64dp slot)
 TimelineGeometry.heightFor(start, duration)
   = duration × kPixelsPerMinute (6.0)
     │
     ▼
today_screen.dart._buildPositionedRow
  (Positioned height = slot, NO slop —
   the grown-envelope arm is deleted)
```

Entry point: a visible tap on the 64×slot Skip rail. No gesture recognizer, no drag distance, no
dismiss threshold — the tap either fires `markSkipped` or it doesn't, mirroring the work-chunk Skip
`OutlinedButton`'s existing wiring pattern (`chunk_card.dart:891`, verified: `onPressed: () =>
context.read<ScheduleNotifier>().markSkipped(chunk.id)`).

### Recommended Project Structure

No new directories. One new file, matching the UI-SPEC's own recommendation and this codebase's
existing convention of putting cross-cutting widgets in `lib/widgets/` (alongside
`responsive_shell.dart` — verified: `lib/widgets/responsive_shell.dart` exists today):

```
lib/
├── widgets/
│   └── break_skip_button.dart        # NEW — BreakSkipButton, shared by both call sites
├── screens/
│   ├── today/
│   │   ├── timeline_geometry.dart    # EDIT — re-derive constants, delete 4
│   │   ├── today_screen.dart         # EDIT — delete slop/_needsSlop/Layer-1b, wire button rail
│   │   └── widgets/
│   │       └── live_row_card.dart    # EDIT — single-line tier gains BreakSkipButton rail
│   └── schedule/
│       └── widgets/
│           ├── chunk_card.dart              # EDIT — _buildBreak redesigned, _SubCompactRow/
│           │                                #        _DashedBorderPainter/kSubCompactGripSize deleted
│           └── swipeable_chunk_card.dart    # EDIT — restore chunkType != work early return,
│                                             #        visualHeight/_confineReveal/_confineContent
│                                             #        become dead (delete or leave — see note below)
```

**Note on `swipeable_chunk_card.dart`'s `visualHeight`/`_confineReveal`/`_confineContent`.** These
exist inside `SwipeableRowShell`, which is **also used by the live work-chunk arm's swipe** — wait,
verified against the live source: `SwipeableRowShell` is used by `SwipeableChunkCard` (non-live,
work-chunk-only after this phase's restored early return) and by the live-break arm in
`today_screen.dart` (which this phase deletes entirely, see "The retirement surface"). Once the
live-break arm's `SwipeableRowShell` call site is deleted, **every remaining call site passes
`visualHeight: null`** (work chunks never grow a slop envelope — `_needsSlop` returns `false` for
non-breaks unconditionally, verified `timeline_geometry.dart`/`today_screen.dart:697-701`). This
makes `visualHeight`, `_confineReveal`, and `_confineContent` **dead code with zero live non-null
callers**, exactly the class of thing `32-UI-SPEC.md`'s retirement checklist calls out for
`SwipeableChunkCard`'s own `visualHeight` parameter — the identical argument applies one level down,
inside `SwipeableRowShell`, and the UI-SPEC's retirement table does not currently list it. **Flag
this as an additional retirement item** (see "The retirement surface" below).

### Pattern 1: Density-driven tier selection (existing pattern, reused not invented)

**What:** A `slot` (pixels) is compared against a named threshold constant to pick a rendering
branch; the box height is never adjusted for content — only content adapts to the box (D-02,
carried from Phase 26).
**When to use:** Any row whose available height is duration-exact and whose content must degrade
gracefully rather than clip or inflate the slot.
**Example (existing, verified `today_screen.dart:891-899`):**
```dart
final density = isBreak
    ? (slot >= kFullBreakMinHeight
          ? ChunkCardDensity.full
          : slot >= kSubCompactBreakMinHeight   // ← this arm is deleted this phase
          ? ChunkCardDensity.compact
          : ChunkCardDensity.subCompact)          // ← this branch is deleted this phase
    : (slot >= kFullTierMinHeight
          ? ChunkCardDensity.full
          : ChunkCardDensity.compact);
```
Post-phase, the break ternary collapses to the same two-way shape the work ternary already uses:
`slot >= kFullBreakMinHeight ? full : compact`.

### Anti-Patterns to Avoid

- **Re-deriving a threshold from a fresh guess instead of from the reachability arithmetic.** Every
  constant in `timeline_geometry.dart` that survives this phase unchanged (`kFullTierMinHeight`,
  `kFullBreakMinHeight`, `kCompactLiveMinHeight`) does so because it is an *absolute* content-fit
  threshold, not a ratio of `kPixelsPerMinute` — verify this distinction per-constant (see "Density-
  tier reachability at 6.0" below) before touching any of them.
- **A find-and-replace of expected pixel values in tests.** This is the codebase's own named,
  repeated failure mode (STATE.md: "the carried-forward defect class of this whole project"). Any
  test literal that changes value must be re-derived from the new constant (or intentionally kept a
  bare literal with a comment explaining why, matching the existing `today_timeline_model_test.dart`
  style), never just retyped to "the new expected number."
- **Deleting `Icons.drag_indicator` project-wide.** This exact icon constant is also used,
  unrelatedly, by `lib/screens/goals/goals_screen.dart`'s goal-reordering drag handle (verified:
  `goals_screen.dart:254,276`, and its own test `test/screens/goal_card_drag_handle_test.dart`). A
  blind `grep -rl drag_indicator | xargs sed -i` or similar would break goal reordering. Only
  `chunk_card.dart`'s `_SubCompactRow`'s use of the icon is in scope for retirement.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Skip action wiring | A new async state-mutation path for button-triggered skip | `context.read<ScheduleNotifier>().markSkipped(chunkId)` — already exists, already type-agnostic, already has WR-05 revert-and-rethrow (verified `schedule_notifier.dart:687-745`) | The exact same call the work-chunk Skip `OutlinedButton` already makes (`chunk_card.dart:891`) and the exact same call `SwipeableRowShell`'s `confirmDismiss` currently makes for the endToStart direction (`swipeable_chunk_card.dart:148`) — zero new business logic needed. |
| Touch-target sizing math | A bespoke hit-test-envelope/slop mechanism (what this phase is explicitly retiring) | A visibly-painted, fixed-width `SizedBox`/`Material`/`InkWell` at `kBreakSkipButtonWidth` | The owner's own stated reasoning (D-32-03, ROADMAP): "meeting a spec number with an invisible target is a weaker guarantee than missing it slightly with a visible one." Do not resurrect any invisible-envelope idea to "help" the button clear 48×48 — that is re-litigating a settled decision. |

**Key insight:** Every piece of business logic this phase needs (skip mutation, persistence,
error-revert, streak-inertness for goalless breaks) already exists and is already proven correct by
639 passing tests. This phase is 100% presentation-layer + one constant migration — there is no
engine change and no data-model change.

## Constant re-derivation and reachability (TAPBREAK-02/03) — verified against the live source

Read `timeline_geometry.dart` (503 lines) in full this session. Every value quoted below is the
literal from that file, not a restatement.

| Constant | File:Line | Current value | Verified quote | Action | Why |
|---|---|---|---|---|---|
| `kPixelsPerMinute` | `timeline_geometry.dart:72` | `4.0` | `const double kPixelsPerMinute = 4.0;` | **→ 6.0** | D-32-01, locked. |
| `kFullTierMinHeight` | `timeline_geometry.dart:88` | `88.0` | `const double kFullTierMinHeight = 88.0;` | **unchanged** | Absolute content-fit threshold (70dp measured card + 8dp margin + slack), not a ratio of `kPixelsPerMinute`. Every work chunk is ≥25min → ≥150dp at 6.0, so slack only grows (150−88=62dp vs. 100−88=12dp today). |
| `kFullBreakMinHeight` | `timeline_geometry.dart:95` | `88.0` | `const double kFullBreakMinHeight = 88.0;` | **unchanged**, but see below | Same absolute-threshold reasoning. **What changes is reachability**, not the number: at 6.0 a 5-min break is 30dp (< 88 → `compact`) and a 30-min break is 180dp (≥ 88 → `full`) — a clean two-way split, with the *content* behind `compact` completely redesigned (Card+Skip rail replaces the old dashed box). |
| `kSubCompactBreakMinHeight` | `timeline_geometry.dart:170` | `32.0` | `const double kSubCompactBreakMinHeight = 32.0;` | **DELETE** | The tier it gates (`ChunkCardDensity.subCompact`, `_SubCompactRow`) is retired outright for breaks (D-32-02: the whole "hairline with a grip glyph" mechanism is dead). Nothing reads this constant once the tier is gone. |
| `kBreakHitSlop` | `timeline_geometry.dart:243` | `24.0` (raised from 16.0 in the Phase 31 gap closure, D-31-06) | `const double kBreakHitSlop = 24.0;` | **DELETE** | Existed solely to grow the invisible swipe hit-test envelope. Breaks have no swipe (D-32-02). |
| `kMinBreakDragTarget` | `timeline_geometry.dart:249` | `48.0` | `const double kMinBreakDragTarget = 48.0;` | **DELETE** | The gate deciding *when* `kBreakHitSlop` applied. Dead once `kBreakHitSlop` is gone. |
| `kSubCompactGripSize` | `chunk_card.dart:348` | `14.0` | `const double kSubCompactGripSize = 14.0;` | **DELETE** | Sized `Icons.drag_indicator` inside `_SubCompactRow` — the exact glyph the owner said reads as "drag and drop." Deleted with the glyph and the tier, not repurposed. |
| `kCompactLiveMinHeight` | `live_row_card.dart:320` | `88.0` | `const double kCompactLiveMinHeight = 88.0;` | **unchanged** | Same absolute-threshold reasoning (kicker+title stack is a fixed content height, not duration-scaled). Live long break: 120dp→180dp (more slack, same branch). Live short break: 20dp→30dp (still < 88, same branch: single-line tier). |
| `kNowLineHeight`, `kHourAxisHeight`, `kTimelineEdgePadding`, `kLiveActionTouchTarget`, `kGutterWidth`, `kTimelineRowInset`, `kCardLeftInset`, `kNowContentEdge`, `kNowDotDiameter` | various (`timeline_geometry.dart`, `timeline_row_tile.dart`) | unchanged | (fixed chrome heights/horizontal metrics; none derived from `kPixelsPerMinute` — verified none of these appears on the right-hand side of a `kPixelsPerMinute` expression anywhere in `timeline_geometry.dart`) | **unchanged** | Listed so a reader auditing this migration gets an explicit no for each. |
| `kBreakSkipButtonWidth` (**new**) | proposed: `timeline_geometry.dart`, colocated with the density-threshold cluster | — | not yet in the tree (verified: `grep -rn kBreakSkipButtonWidth lib/` returns nothing) | **ADD, = 64.0** | D-32-03, locked. `64 = 8 × 8`, on the existing 8-pt spacing scale. |

**Density-tier reachability table (verified arithmetic, not the UI-SPEC's restatement):**

| Row type | Duration | Slot @ 4.0 (today) | Slot @ 6.0 (this phase) | Tier @ 6.0 | Threshold compared |
|---|---|---|---|---|---|
| Non-live short break | 5 min | 20dp (→ `subCompact`, retired) | **30dp** | `compact` (new Card+Skip design) | `< kFullBreakMinHeight` (88) |
| Non-live long break | 30 min | 120dp (→ `full`) | **180dp** | `full` (existing heavier weight, + Skip rail) | `>= kFullBreakMinHeight` (88) |
| Live short break | 5 min | 20dp (→ single-line, no actions today) | **30dp** | single-line (**gains** `BreakSkipButton` rail this phase) | `< kCompactLiveMinHeight` (88) |
| Live long break | 30 min | 120dp (→ compact, has icon buttons) | **180dp** | compact (unchanged, D-31-07 survives) | `>= kCompactLiveMinHeight` (88) |
| Work chunk | 25 min (only duration the generator emits, verified `schedule_generator.dart` always creates `durationMinutes: 25` — confirmed via `timeline_geometry.dart:229-234`'s own doc-comment audit of the generator) | 100dp (→ `full`) | **150dp** | `full` (unchanged) | `>= kFullTierMinHeight` (88) |

**The load-bearing trap the ROADMAP names, confirmed true:** a 5-min break at the *old* scale (20dp)
was under the *old* `kSubCompactBreakMinHeight` (32.0) and rendered as a hairline. At the *new* scale
(30dp) it would **still** be under 32.0 if that constant were left in place — the ROADMAP is correct
that leaving thresholds unmoved reproduces the defect. This phase's answer is not "raise the
threshold" — it's "delete the tier and its threshold entirely," which is a stronger fix than
re-tuning the number would have been, and is what D-32-02 actually mandates.

## Package Legitimacy Audit

Not applicable — see "Package Legitimacy Audit" above (no packages introduced).

## The `kPixelsPerMinute` blast radius — independently re-verified, one correction

**Symbolic references: confirmed exactly 38, across exactly the 4 named files.**

```
$ grep -rn "kPixelsPerMinute" test/ | wc -l
38
$ grep -rl "kPixelsPerMinute" test/
test/screens/today_row_widgets_test.dart
test/screens/today_timeline_model_test.dart
test/screens/today_screen_test.dart
test/screens/today_screen_now_state_test.dart
```
Per-file count (summing to 38): `today_row_widgets_test.dart`=1, `today_timeline_model_test.dart`=9,
`today_screen_test.dart`=26, `today_screen_now_state_test.dart`=2. These all read
`N * kPixelsPerMinute` symbolically and need **zero edits** — they follow the constant automatically.

**Hardcoded pixel literals: I find 3 that must be re-derived for correctness, not 4** — plus a 4th
category (a cluster of retired-mechanism literals) that the ROADMAP's count may have been referring
to instead. Both possibilities are documented below so the planner can decide with full information
rather than trust either count blindly.

**The 3 literals that unambiguously encode `duration × 4.0` and must change to `duration × 6.0`:**

1. `test/screens/today_timeline_model_test.dart:499` — `expect(geometry.heightFor(540, 5), 20.0);`
   → must become `30.0`. The surrounding comment (line 488-491) explicitly documents this as a
   **deliberate bare literal**, not `5 * kPixelsPerMinute`, specifically so this test doesn't
   inherit "the same self-referential blindness" the GRID-01 test's own discipline warns against.
2. `test/screens/today_timeline_model_test.dart:500` — `expect(geometry.heightFor(600, 30),
   120.0);` → must become `180.0`. Same test, same deliberate-literal rationale.
3. `test/screens/today_screen_test.dart:2372` — `expect(tester.getSize(breakClipRect).height,
   20.0);` inside the `'SEEBREAK-02: a 5-minute break occupies exactly 20.0dp of slot at
   sub-compact density'` test → must become `30.0`, **and** this test's own name and its
   `subCompact`-tier premise are both retired this phase (see "The retirement surface" — this test
   asserts the tier that no longer exists, so it should be rewritten to assert the new `compact`
   tier's Card, not merely have its literal edited).

**A 4th candidate, excluded from the count above on purpose — flag for the planner rather than
silently drop:** `test/screens/today_screen_test.dart:2733` —
```dart
final origin = Offset(paintedRect.center.dx, paintedRect.top - 22);
```
This is a genuine hardcoded pixel literal (`-22`), explicitly commented as "deliberately a bare
numeric literal, NOT an expression involving kBreakHitSlop" (line 2728-2732) inside the
**`D-31-06 — a bigger, findable acquisition band`** test group. This whole test group drives a
synthetic drag gesture to test the swipe-slop acquisition band — the exact mechanism D-32-02
retires. **This literal does not need re-deriving; the test it lives in needs deleting.** If the
ROADMAP's "4 hardcoded pixel literals" count includes this one, that is defensible under a looser
definition of "hardcoded pixel literal in the test tree," but it is not comparable to the 3 above —
those 3 survive the phase and must change value; this one and its enclosing test do not survive the
phase at all. **My finding: the ROADMAP's count of 4 is not clearly wrong, but it conflates two
different categories of literal** (grid-honesty assertions that must be re-derived, vs.
retired-mechanism assertions that must be deleted) that the plan should track as separate line
items, because "re-derive" and "delete" are different task types with different verification.

**A 5th, non-counted observation worth flagging:** `today_row_widgets_test.dart` passes
`slotHeight: 100.0` (~9 occurrences) and `slotHeight: 20.0` (~7 occurrences) as **fixture inputs**
to `pumpLiveRowCard`/`LiveRowCard` directly — these are not assertions computed from
`kPixelsPerMinute` and **do not need to change value** for the tests to keep passing correctly (100
stays ≥ `kCompactLiveMinHeight`=88, 20/30 both stay < 88 — the boolean tier selection is unaffected
either way). However, several of these are labelled in comments as "a 25-minute work chunk's slot"
/ "a 5-minute break's slot," which becomes numerically stale (the true values are now 150.0/30.0).
**Recommendation:** update these fixture literals to 150.0/30.0 anyway, purely for comment accuracy
and so a future reader isn't misled about what duration a given `slotHeight:` represents — but this
is cosmetic, not a correctness requirement, and should be scoped as a cheap batch edit, not treated
with the same care as the 3 literals above.

**Full audit command trail (reproducible):**
```bash
grep -rn "kPixelsPerMinute" test/ | wc -l                    # 38
grep -rl "kPixelsPerMinute" test/                            # the 4 files
grep -nE "expect\([^,]+, *[0-9]+\.[0-9]+\)" test/screens/{today_screen_test,today_timeline_model_test,today_row_widgets_test,today_screen_now_state_test}.dart | grep -v "kPixelsPerMinute\|kGutterWidth\|kNowLineHeight\|..."
```

## The retirement surface (TAPBREAK-01, D-32-02) — every definition and reference

Verified by reading each file in full this session (not by trusting the UI-SPEC's own table).

| Item | Definition | Every reference found | Disposition |
|---|---|---|---|
| `kBreakHitSlop` | `timeline_geometry.dart:243` | `today_screen.dart:782,824,901,912,932` (doc comments + 2 live reads); test refs: `today_screen_test.dart:2458,2490,2493,2542,2546,2619,2625,2729,2767,2770,2777`; `today_screen_now_state_test.dart:1256,1467` | DELETE constant; delete every test that references it (see below) |
| `kMinBreakDragTarget` | `timeline_geometry.dart:249` | `today_screen.dart:690,705,782,900,932`; test refs: `today_screen_test.dart:2481,2484,2760,2768,2772,2782` | DELETE constant; delete referencing tests |
| `_needsSlop(...)` | `today_screen.dart:697-706` | called at `today_screen.dart:824,1547,1592` (doc refs at 796-803,921,930,1116) | DELETE method and all 3 call sites |
| Layer 1b `Stack` pass | `today_screen.dart:1555-1599` (the `for (final row in timelineRows) if (row is ChunkRow && !row.isLive && ... _needsSlop(...))` loop) | single location | DELETE the whole loop |
| Break arm's grown-`Positioned` envelope | `today_screen.dart:931-946` (`_buildPositionedRow`'s `ChunkRow` case, `isBreak` branch) | single location | Collapse to the same shape as the work-chunk arm immediately below it (`today_screen.dart:948-969`) — `Positioned(top: geometry.yFor(start), height: slot, ...)`, no slop, no `visualHeight` |
| Live-break arm's grown envelope + `SwipeableRowShell` wrap | `today_screen.dart:776-841` (`_buildPositionedRow`'s `isLive && isLiveBreak` branch) | single location | Collapse to the same `ClipRect`/`OverflowBox` shape the live-work arm uses (`today_screen.dart:859-878`) — no `SwipeableRowShell`, no slop |
| `SwipeableChunkCard`'s `chunk.chunkType != ChunkType.work` early return | was deleted in Phase 31 (`promote` decision) | `swipeable_chunk_card.dart:255-282` (`build()` currently has no early return — every chunk type reaches `SwipeableRowShell`) | **RESTORE** the early return: `if (chunk.chunkType != ChunkType.work) return ChunkCard(...)` before constructing `SwipeableRowShell` |
| `SwipeableRowShell`'s `visualHeight`/`_confineReveal`/`_confineContent` | `swipeable_chunk_card.dart:30-92` | Called from `SwipeableChunkCard.build()` (`:264`) and from `today_screen.dart`'s (now-deleted) live-break arm | **Not listed in UI-SPEC's own retirement table** — becomes dead code (zero non-null callers) once the two items above are done. Flag for the plan: either delete `visualHeight` and the two confinement helpers from `SwipeableRowShell` (matching the UI-SPEC's stated philosophy for `SwipeableChunkCard`'s identical parameter), or explicitly document why it's kept. Recommend deleting — leaving a parameter with zero live callers repeats exactly the "unused invisible-band mechanism" anti-pattern this phase's own charter forbids. |
| `_SubCompactRow`, `ChunkCardDensity.subCompact` | `chunk_card.dart:384-498` (class), `chunk_card.dart:34-52` (enum value) | Reachable arm: `chunk_card.dart:161-169` (`_buildBreak`'s `if (density == subCompact)`). Documented-dead arm: `chunk_card.dart:648-661` (`_WorkChunkContent`'s switch, kept only for exhaustiveness). Screen-side selector: `today_screen.dart:891-896`. Tests: `today_screen_test.dart` "SEEBREAK-01 tier boundary" test (~2280-2340, asserts `Divider` presence/absence) | DELETE the enum value, the class, both switch arms, the screen ternary's third branch, and the tier-boundary test (its premise — 3 reachable break tiers — no longer holds) |
| `kSubCompactGripSize`, `Icons.drag_indicator` (break-row grip) | `chunk_card.dart:348,452-464` | only inside `_SubCompactRow` | DELETE with `_SubCompactRow`. **Do NOT touch** `goals_screen.dart:254,276`'s unrelated `Icons.drag_indicator` usage (goal reordering) or its test `goal_card_drag_handle_test.dart` — confirmed via grep these are a distinct, unrelated feature sharing only the icon constant name. |
| `_DashedBorderPainter` | `chunk_card.dart:290-338` | used by `_buildBreak`'s `compact` (today's dashed-box tier, `:184-216`) and `full` (`:233-282`) branches | DELETE — both break branches are redesigned to the bordered-`Card` treatment this phase specifies. **Do NOT touch** `free_time_row.dart`'s own `_DashedRegionPainter` (`:77-100+`) — verified this is a **separate, deliberately duplicated** file-private class for free/gap rows, not an importer of `chunk_card.dart`'s painter. Note: after this phase, a free/gap region will still render dashed while a break renders as a filled Card — a visual-language divergence the 2026-08-18 UAT specifically chose to *avoid* ("Same visual language as breaks, deliberately"). **Flag this divergence for the human UAT** — it is a foreseeable side effect of D-32-02's own instruction ("make it look like a small section similar to work") that no one has explicitly ruled on for free/gap rows. |

**Tests to DELETE outright (gesture-dependent, `today_screen_test.dart`'s "Phase 31 — SKIPBREAK"
group, lines 2377-2840, verified by reading every `testWidgets` title in the group):**
`SKIPBREAK-01 tracer`, `SKIPBREAK-01 vacuity guard`, `SKIPBREAK-01` (bottom slop band),
`SKIPBREAK-01 negative case`, `SKIPBREAK-01` (below-threshold drag), `D-31-06 Case A`, `D-31-06 Case
B` — 7 tests, all drive `tester.dragFrom(...)`.

**Tests to KEEP and re-derive (same file, `SKIPBREAK-02 — the grid is unchanged` subgroup, lines
2840-3005, verified no gesture dependency — each pumps a static fixture and asserts geometry):**
`'painted extent is exactly duration x kPixelsPerMinute...'` (uses symbolic `kPixelsPerMinute`,
needs no literal edit), `'painted rows stay exactly adjacent...'` (symbolic), `'the timeline's total
painted extent is unchanged...'` (symbolic) — these 3 need **no literal changes**, only removal of
any `kBreakHitSlop`-related commentary/assertions that no longer apply (verify each still makes
sense once the grown-envelope arm is gone — e.g. the "Positioned deliberately extends
kBreakHitSlop beyond its own slot" comment at `:2976-2977` describes a mechanism this phase deletes).
Two more tests in the same file (`'a day with zero breaks...'`, `'a mixed day renders every row
independently...'`) are pure rendering tests, unaffected.

**Tests to DELETE outright (`today_screen_now_state_test.dart`'s live-break group):** `'Case A — a
live short break can be swiped'` (drives `dragFrom`) and `'Case C — a break that was live and is now
resolved-and-delisted offers no Skip affordance and cannot be re-swiped'` (also drives `dragFrom`,
now meaningless — there is no `Dismissible` left to fail to re-trigger). **Keep and adapt** `'Case B
— truth #14's composition, proven'` — verified it does **not** use `dragFrom` at all; it constructs
the pre-skipped fixture directly (`liveSkipFixture(breakSkipped: true)`) and asserts slot-height/
position invariants across the live→resolved transition, which remain meaningful after this phase
(a skip via button produces the identical state transition a skip via drag used to).

## The live-break gap (D-31-07 surface, TAPBREAK-01) — verified, not assumed

Read `live_row_card.dart` in full. Confirmed, verbatim:

- `LiveRowCard._buildSingleLine` (`:303-365`) renders exactly one `Padding(Row(Expanded(Text(title)),
  Text(' · $remainingLabel')))` wrapped in a `Semantics(...button: onTap != null...)`. **There is no
  action affordance of any kind in this tier today** — confirmed no `IconButton`, `FilledButton`, or
  any tappable child besides the optional whole-row `onTap` (which the screen always passes `null`
  for a break — `today_screen.dart:1102-1113`, the `onTap` local is non-null only for
  `chunk.chunkType == ChunkType.work`).
- The tier-selection call, verified: `LiveRowCard.build()` (`:132-139`) —
  `return slotHeight >= kCompactLiveMinHeight ? _buildCompact(...) : _buildSingleLine(...);` — a
  live 5-min break (30dp @ 6.0) is `30 < 88` → `_buildSingleLine`. Confirmed this is the tier with no
  action row, so **the UI-SPEC's claimed regression is real**: without a fix, a live 5-minute break
  ships with zero way to skip it.
- `showActions`/`showComplete` wiring, verified exactly as the UI-SPEC states, at
  `today_screen.dart:1123,1130-1131`:
  ```dart
  final isBreak = chunk.chunkType != ChunkType.work;
  return LiveRowCard(
    ...
    showActions: isBreak ? !chunk.isSkipped : true,
    showComplete: !isBreak,
    ...
  );
  ```
  These two parameters are consumed only inside `_buildCompact` (`:214-232`) — `_buildSingleLine`
  currently **ignores both parameters entirely** (verified: neither `showActions` nor
  `showComplete` is referenced anywhere in `_buildSingleLine`'s body, `:303-365`). This confirms the
  UI-SPEC's framing exactly: the screen already asks for "at least one action, Skip only" for a live
  break; only the single-line tier's own layout needs to start honoring that request.

**Resolution, matching the UI-SPEC's proposed shape and verified compatible with the existing
call site:** `_buildSingleLine` gains a `Row(crossAxisAlignment: stretch)` with the existing
title/countdown content in an `Expanded` and a new `SizedBox(width: kBreakSkipButtonWidth,
child: BreakSkipButton(...))` trailing slot, gated on `showActions` (already threaded into this
widget as a constructor parameter — no new plumbing needed, only new usage inside the method body).

## The Skip rail — verified against the app's existing skip vocabulary

- `Icons.skip_next_outlined` is **already** the work-chunk Skip button's icon (verified,
  `chunk_card.dart:889`: `icon: const Icon(Icons.skip_next_outlined)`), so reusing it for
  `BreakSkipButton` introduces no new icon.
- The error-family coloring the UI-SPEC proposes (`colorScheme.errorContainer` fill,
  `onErrorContainer` icon/text) is a **new usage of an existing role** — the work-chunk Skip button
  today uses the bare `colorScheme.error` (verified, `chunk_card.dart:895-896`:
  `foregroundColor: theme.colorScheme.error, side: BorderSide(color: theme.colorScheme.error)`), and
  the retired swipe reveal used the same bare `error` (verified, `swipeable_chunk_card.dart:101-110`,
  `_skipReveal`: `color: colorScheme.error`). Using the softer `errorContainer`/`onErrorContainer`
  pair for a *permanently visible* control (vs. the bare `error` used for a transient outline/fill)
  is a reasonable, in-scheme choice — not a new color role, no `ColorScheme.fromSeed` change needed.
- `markSkipped(String chunkId)`'s signature (verified, `schedule_notifier.dart:687`) matches the
  UI-SPEC's proposed `onTap: () => context.read<ScheduleNotifier>().markSkipped(chunkId)` call
  exactly — no signature mismatch to plan around.

## Testing the geometry without re-baking a magic number (verification protocol)

**Recommended assertion style, and the discipline that already exists in this codebase to copy:**
`today_timeline_model_test.dart:479-501`'s own SEEBREAK-02 test is the house style to follow: derive
from the constant wherever the assertion's *purpose* is "prove the formula still holds"
(`n * kPixelsPerMinute`), but use a **deliberate bare literal, with a comment explaining why**,
wherever the assertion's purpose is "pin the ground-truth ratio itself" (i.e., the one place in the
suite that would catch `kPixelsPerMinute` silently drifting to a different value while every
`n * kPixelsPerMinute` expression trivially "passed" against the wrong constant). This project
already articulates the failure mode precisely (`timeline_geometry.dart:97-104`'s own doc comment
uses the phrase "self-referential blindness") — a plan does not need to invent this discipline, only
apply it consistently: **exactly 2-3 literals in the whole suite should ever be bare numbers, and
each one needs a comment stating that it is deliberately not derived from the constant.**

**Which of the (now 3, corrected) hardcoded literals genuinely must stay literal, and why:** all
three (`today_timeline_model_test.dart:499,500`, `today_screen_test.dart:2372`) should **stay
literal** post-migration too (updated to 30.0/180.0/30.0), for the identical reason they are literal
today — they are the suite's canary against `kPixelsPerMinute` itself silently drifting. The
D-31-06 `-22` literal (`today_screen_test.dart:2733`) should **not** be re-derived — its enclosing
test is deleted, not migrated.

## Common Pitfalls

### Pitfall 1: Treating "hardcoded literal" as a single undifferentiated category
**What goes wrong:** A plan that says "find and fix the 4 hardcoded literals" conflates 3 grid-
honesty canaries (which must be updated to new values and kept literal) with 1+ retired-mechanism
literals (which should be deleted along with their tests, never updated).
**Why it happens:** Both look identical under a naive `grep` for bare numbers.
**How to avoid:** Classify each literal by whether its enclosing test still has a reason to exist
post-D-32-02 before deciding "edit" vs. "delete."
**Warning signs:** A task that says "update literal at line N" where line N is inside a
`testWidgets` whose title contains "drag," "swipe," "slop," or "D-31-06."

### Pitfall 2: `SwipeableRowShell`'s dead parameter surviving as unreachable-but-present
**What goes wrong:** Restoring `SwipeableChunkCard`'s early return and deleting the live-break
`SwipeableRowShell` call site makes `visualHeight`/`_confineReveal`/`_confineContent` dead code, but
nothing forces their removal — Dart doesn't warn on an unused-but-still-callable public parameter
with a default value.
**Why it happens:** The UI-SPEC's own retirement table does not list this item (verified: absent
from `32-UI-SPEC.md`'s "Retirement checklist" table) — it is one level of indirection deeper than
what that document audited.
**How to avoid:** Explicitly add this to the plan's retirement checklist (see table above) and grep
for zero non-null `visualHeight:` call sites as a completion check.
**Warning signs:** `grep -n "visualHeight" lib/screens/schedule/widgets/swipeable_chunk_card.dart`
still returns the parameter declaration after the phase is "done," with no call site passing it
non-null.

### Pitfall 3: `Icons.drag_indicator` name-collision with goal reordering
**What goes wrong:** A grep-driven removal of "the drag indicator icon" touches
`goals_screen.dart`'s unrelated goal-reordering handle.
**Why it happens:** Same icon constant, two unrelated features.
**How to avoid:** Scope every retirement action to `chunk_card.dart`'s `_SubCompactRow` specifically,
never a bare `Icons.drag_indicator` grep-and-replace.
**Warning signs:** `test/screens/goal_card_drag_handle_test.dart` starts failing.

### Pitfall 4: Free/gap rows silently diverging from the new break-card visual language
**What goes wrong:** After this phase, a break renders as a filled bordered `Card` while a free/gap
region (`FreeTimeRow`, unaffected by this phase) still renders the old dashed-outline treatment —
re-opening the exact "same visual language" concern the 2026-08-18 UAT closed by design (making
free/gap rows visually match breaks).
**Why it happens:** `FreeTimeRow` and `ChunkCard`'s break arm share no code (verified: separate,
deliberately-duplicated painters), so a change to one does not propagate to the other, and nothing
in this phase's scope touches `FreeTimeRow`.
**How to avoid:** This is explicitly **out of scope** per the ROADMAP (only break rows are
respecified) — but it should be surfaced to the human UAT as a known, foreseeable side effect
rather than silently shipped and discovered later the way three previous phases' gaps were.
**Warning signs:** A UAT reviewer notices free time and breaks now look different and asks whether
that was intentional.

### Pitfall 5: Reordering the `if (density == subCompact)` check relative to `compact` in `_buildBreak`
**What goes wrong:** Not applicable post-deletion — this pitfall (documented in the existing code,
`chunk_card.dart:154-160`) disappears once `subCompact` is deleted from the `if`-chain entirely. Listed
here only so a reader doesn't spend time preserving an ordering constraint that no longer has a
reason to exist once the branch it protects is gone.

## Code Examples

### The button-triggered skip call (pattern to replicate, not invent)
```dart
// Source: lib/screens/schedule/widgets/chunk_card.dart:888-899 (existing, work-chunk Skip button)
Tooltip(
  message: 'Skip',
  child: OutlinedButton.icon(
    icon: const Icon(Icons.skip_next_outlined),
    label: const Text('Skip'),
    onPressed: () => context.read<ScheduleNotifier>().markSkipped(chunk.id),
    style: OutlinedButton.styleFrom(
      visualDensity: VisualDensity.compact,
      foregroundColor: theme.colorScheme.error,
      side: BorderSide(color: theme.colorScheme.error),
    ),
  ),
),
```
`BreakSkipButton` replaces the `OutlinedButton.icon` chrome with a `Material`/`InkWell` (per
`32-UI-SPEC.md`, to get the full-bleed `errorContainer` fill the rail needs) but keeps the identical
`onPressed`/`markSkipped(chunkId)` call.

### The restored early return (pattern to reinstate, not invent — was live before Phase 31)
```dart
// Source: 32-UI-SPEC.md "Where breaks render now", cross-checked against the CURRENT (Phase-31)
// swipeable_chunk_card.dart:255-282 build() method, which has NO such early return today —
// confirming this is a restoration, not new logic.
if (chunk.chunkType != ChunkType.work) {
  return ChunkCard(
    chunk: chunk,
    goalColor: goalColor,
    density: density,
    showStartTime: showStartTime,
    // onTap stays null — tappable is still out of scope (owner, 2026-08-21, unchanged)
  );
}
// ...existing work-chunk SwipeableRowShell path, unchanged below this line
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Invisible hit-test-envelope enlargement (`kBreakHitSlop`/`kMinBreakDragTarget`) to make a small swipe target reachable | Visible, fixed-width button rail (`BreakSkipButton`, `kBreakSkipButtonWidth`) | This phase (D-32-02/D-32-03), 2026-08-27 | The touch-target guarantee moves from "meets a platform minimum via invisible reach" to "meets most of a platform minimum via visible paint" — a strictly stronger guarantee per the owner's own stated reasoning, at the cost of ~16% under Material's raw 48×48 area guideline (1920 vs 2304dp²), accepted deliberately. |
| Duration-hairline break rows with a sub-compact density tier | Two-tier Card-based break rows (compact/full), no sub-compact | This phase (D-32-01 + TAPBREAK-03) | The 4.0→6.0 scale change makes the sub-compact tier's whole reason for existing (a slot too small for any card) disappear at every duration the generator currently emits. |

**Deprecated/outdated:**
- `_SubCompactRow`, `kSubCompactBreakMinHeight`, `kSubCompactGripSize`: Phase 29's answer to "a
  5-minute break is illegible" is superseded by Phase 32's answer to the same underlying tension
  (duration-exact slots vs. legible/actionable content) — scaling the whole timeline up rather than
  degrading small rows to a hairline.
- `kBreakHitSlop`/`kMinBreakDragTarget`/Layer 1b Stack pass: Phase 31's answer to "a swipe target is
  too small to grab" is superseded by removing the swipe entirely for breaks.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `errorContainer`/`onErrorContainer` (rather than the bare `error`/`onError` the retired swipe reveal used) is an acceptable, in-scheme color choice for a *permanently visible* control, without a formal design-system sign-off beyond the UI-SPEC's own reasoning. | "The Skip rail" | Low — both are existing `ColorScheme` roles, no new color introduced; worst case is a UAT note that the fill reads slightly muted/vivid and a one-line color swap. |
| A2 | Deleting `SwipeableRowShell`'s `visualHeight`/`_confineReveal`/`_confineContent` (Pitfall 2, not in the UI-SPEC's own retirement table) is the correct call rather than leaving them as unused-but-harmless. | "The retirement surface" | Low-medium — if a future phase needs a confined-hit-test pattern again it would need re-adding, but the phase's own stated charter ("do not leave dead mechanism in the tree") argues for deletion; flagged explicitly for planner sign-off rather than assumed unilaterally. |
| A3 | The free/gap-row visual divergence from the new break-card look (Pitfall 4) is acceptable to ship without a code change this phase, deferring only to a UAT note. | "The retirement surface" table, `_DashedBorderPainter` row | Low — explicitly out of ROADMAP scope; risk is limited to a UAT surprise, not a defect, and the UAT script should ask about it directly rather than let it surface as an unplanned finding. |

**If this table is empty:** not applicable — see above; all three are LOW-risk, explicitly-flagged
discretionary choices, not compliance/security/retention claims.

## Open Questions (RESOLVED)

> **Both resolved at planning, 2026-08-27, in each case by adopting this section's own
> recommendation.** Q1 → `32-02-PLAN.md` Task 2 rewrites Case A/C in place (same assertions,
> `tester.tap()` replacing `dragFrom`). Q2 → `32-01-PLAN.md` places `BreakSkipButton` at
> `lib/widgets/break_skip_button.dart`. Neither was left for the executor to decide.

1. **(RESOLVED — rewrite in place; `32-02-PLAN.md` Task 2.)** Does the D-31-06 gap-closure test group's sibling assertions inside `today_screen_now_state_test.dart` (the live-break Case A/C swipe tests) have any non-gesture content worth preserving?
   - What we know: Case A and Case C both drive `dragFrom` as their trigger and assert on
     `fake.lastSkippedId`/`fake.lastCompletedId` — the assertions themselves (skip fires, complete
     never fires, the correct chunk id is named) are exactly what a button-tap version of the same
     test would also need to prove.
   - What's unclear: Whether the plan should write brand-new button-tap tests from scratch or
     literally rewrite Case A/C in place (same assertions, `tester.tap()` instead of `dragFrom`).
   - Recommendation: Rewrite in place — the assertions are correct and valuable (they prove the
     right *chunk* is skipped, not just *a* chunk), only the trigger mechanism needs to change.

2. **(RESOLVED — `lib/widgets/break_skip_button.dart`; `32-01-PLAN.md`.)** Should `BreakSkipButton` live at `lib/widgets/break_skip_button.dart` as the UI-SPEC recommends, or does Claude's discretion (per CONTEXT.md) favor a different location?
   - What we know: Both call sites (`chunk_card.dart` under `schedule/widgets/`, `live_row_card.dart`
     under `today/widgets/`) need the identical widget, and `lib/widgets/responsive_shell.dart`
     already establishes the "cross-cutting widget lives in `lib/widgets/`" convention.
   - What's unclear: Nothing — this is explicitly marked Claude's discretion in both CONTEXT.md and
     the UI-SPEC.
   - Recommendation: Follow the UI-SPEC's suggested location; it matches existing convention and no
     evidence favors an alternative.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter/Dart SDK | Build + test | ✓ | Dart `^3.10.3` (pubspec-pinned), Flutter bundled at `/home/dan/development/flutter/bin` | — |
| `flutter test` | Automated verification | ✓ (ran this session: 639/639 passing, baseline confirmed) | bundled | — |
| Headless Chromium w/ SwiftShader | Real-browser compact-tier fit check | ✓ (established recipe from Phases 27/29/31, `tools/serve-uat.py` present) | — | — |
| Port 8143 (UAT serving) | Human UAT checkpoint | ⚠ **currently occupied** | — | **Kill before use** — see below |

**Live finding, this session:** `lsof -i :8143` shows a Python process (PID at time of check) that
`ps` confirms was **started 2026-08-26 08:06:46** — a stale server left over from Phase 31's UAT,
exactly the "check `lsof -i :<port>` before trusting a serve" trap STATE.md already warns has fired
twice. **This is the third time.** The plan's UAT task must kill this process before serving the
Phase 32 build, and should say so as its own first line, not assume the port is free.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` (bundled with Flutter SDK, `pubspec.yaml:44-45`) |
| Config file | none — Flutter's default test runner, no custom config |
| Quick run command | `flutter test test/screens/today_screen_test.dart test/screens/today_timeline_model_test.dart test/screens/today_row_widgets_test.dart test/screens/today_screen_now_state_test.dart` |
| Full suite command | `flutter test` (confirmed this session: 639 tests, ~16s, all green) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TAPBREAK-01 | Tapping the Skip rail calls `markSkipped` for the correct chunk, at every tier (non-live compact, non-live full, live single-line) | widget (`testWidgets`, `tester.tap()`) | `flutter test test/screens/today_row_widgets_test.dart` (new tests) + `today_screen_test.dart`/`today_screen_now_state_test.dart` (rewritten Case A/C) | ❌ new/rewritten this phase |
| TAPBREAK-01 (negative) | No `Dismissible`/drag on a break row does anything | widget, negative assertion | same files | ❌ new this phase |
| TAPBREAK-02 | Every break/work row's painted `ClipRect` height is exactly `duration × 6.0` | widget + pure-arithmetic unit test | `flutter test test/screens/today_timeline_model_test.dart test/screens/today_screen_test.dart` | ✅ exists, 3 literals + `kPixelsPerMinute` value need updating |
| TAPBREAK-03 | A 5-min break renders as a bordered Card (not `Divider`/hairline) at both live and non-live positions | widget (structural — `find.byType(Card)`, `find.byType(Divider)` negative) | `flutter test test/screens/today_row_widgets_test.dart test/screens/today_screen_test.dart` | ❌ tier-boundary test needs rewriting (its premise, 3 tiers, is gone) |
| TAPBREAK-03 | The compact-tier card's content fits inside 30dp without clipping, and visually "reads as a section of the day" | **manual only** — see below | none (structurally unautomatable) | n/a |

### Sampling Rate
- **Per task commit:** the 4-file quick-run command above.
- **Per wave merge:** full `flutter test` (16s, cheap enough to always run in full).
- **Phase gate:** full suite green before `/gsd-verify-work`, **plus** the real-browser screenshot
  check, **plus** the human UAT — none of the three substitutes for either of the others.

### Wave 0 Gaps
- None — the test framework, harness, and every helper (`_FakeScheduleNotifierWithSchedule`,
  `pumpLiveRowCard`, `breakBoundaryFixture`, `skipTracerFixture`) already exist and are reused, not
  built new.

### What `flutter test` structurally CANNOT validate (the critical boundary, per this phase's own explicit charge)

This project has been contradicted by a real thumb on a green suite **three times** (Phase 27, 29,
31 round one), and once by a defect no assertion could ever catch (Phase 31 round two: an icon that
was legible but meant the wrong verb). The specific things `flutter test` cannot settle for Phase 32,
stated precisely rather than generically:

1. **Whether the compact tier's real content — one `bodySmall` line, zero margin, inside a bordered
   `Card` at 30dp — actually fits without clipping.** `flutter test`'s placeholder font inflates
   glyph metrics (this project's own carried-forward invariant, responsible for `kGutterWidth`
   46→75→52 and `kCompactLiveMinHeight` 88→84→88 both being *wrong* when first set from this
   harness). A widget test asserting "no `RenderFlex overflow` exception" can pass while the real
   Roboto-rendered text still visually crowds or touches the card's border in a way no exception is
   thrown for. **Only a real-browser screenshot settles this** (recipe: headless Chromium,
   `--use-gl=swiftshader --enable-unsafe-swiftshader`, debug build via
   `flutter build web --debug --source-maps --pwa-strategy=none`, served with `tools/serve-uat.py`
   on port 8143 after killing the stale process found this session).

2. **Whether the redesigned break card actually "reads as a section of the day" (TAPBREAK-03's own
   words) rather than merely "not clipped."** This is a perceptual/aesthetic judgment — structurally
   identical to Phase 29's own stated boundary ("can a person see that this is a break" is not
   something an assertion settles) and to Phase 31 round two's defect class (a rendered, legible,
   structurally-correct element that nonetheless communicates the wrong thing to a human). No
   widget test, however thorough, can close this gap — **only the human UAT can.**

3. **Whether the Skip rail's icon-above-label vocabulary reads unambiguously as one tappable unit at
   30dp, versus two separate zones** — the exact category of defect (a glyph choice that is legible
   but misleading) that ended Phase 31. A widget test can prove the rail is one `InkWell` (one tap
   target, mechanically); it cannot prove a human perceives it that way.

4. **Whether the full-height Skip rail "reads sensibly" on the 30-minute long break (180dp tall),
   not just the 5-minute case it was explicitly sized for** — the UI-SPEC itself flags this as an
   open aesthetic question, not a locked decision, and explicitly recommends surfacing it to the
   UAT rather than assuming an answer.

5. **Whether D-31-07's `LiveRowCard` compact-tier Skip button — code-complete and test-proven at
   639/639, but never confirmed on a real device across two prior UAT rounds — actually works for a
   human thumb**, now that the surface immediately beside it (the short break) looks completely
   different. This is not a new gap this phase introduces, but it is one this phase's own UAT is
   explicitly obligated to re-ask (ROADMAP, CONTEXT.md) rather than let ride a third time.

**Consequently, this phase's `checkpoint:human-verify` task is not ceremony — it is the only place
items 1-5 above get settled, and the plan must not treat a green `flutter test` run (however large)
as sufficient grounds to skip it.** Reuse port 8143 (after killing the stale server found this
session), and the UAT script's own first instruction must be the mandatory ⟳ Re-check-in
(`CLAUDE.md` trap #4) — this UAT judges a timeline built from generated schedule data, exactly the
condition trap #4 warns about.

## Security Domain

Not applicable in the conventional sense (no auth, no network I/O, no untrusted input parsing in this
phase's scope) — this is a local-only, single-user Flutter app with no server component. The
`ASVS` categories below are assessed for completeness rather than skipped silently:

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | app has no auth surface |
| V3 Session Management | no | n/a |
| V4 Access Control | no | single-user local app |
| V5 Input Validation | no | this phase adds no new user-text input; `markSkipped(chunkId)` already validates chunk existence (`if (chunk == null || chunk.isSkipped) return;`, verified `schedule_notifier.dart:690-691`) |
| V6 Cryptography | no | n/a |

**Known Threat Patterns for this stack:** none applicable — a button tap replacing a drag gesture on
a local-only app introduces no new attack surface. The one state-mutation call (`markSkipped`) is
unchanged by this phase.

## Sources

### Primary (HIGH confidence — read directly, this session)
- `lib/screens/today/timeline_geometry.dart` (full file, 503 lines) — every constant's value,
  doc-comment history, and reachability arithmetic
- `lib/screens/schedule/widgets/chunk_card.dart` (full file, 1022 lines) — `_buildBreak`,
  `_SubCompactRow`, `_DashedBorderPainter`, `ChunkCardDensity` enum, work-chunk Skip button wiring
- `lib/screens/schedule/widgets/swipeable_chunk_card.dart` (full file, 283 lines) —
  `SwipeableRowShell`, `SwipeableChunkCard`, current absence of the `chunkType != work` early return
- `lib/screens/today/widgets/live_row_card.dart` (full file, 366 lines) — `_buildCompact`,
  `_buildSingleLine`, `showActions`/`showComplete` wiring
- `lib/screens/today/today_screen.dart` (targeted reads, ~700 lines) — `_needsSlop`,
  `_buildPositionedRow`, the Layer 1a/1b Stack construction, `_buildLiveRow`
- `lib/screens/today/now_state.dart:176` — the advance-past-resolved loop, verbatim quote confirmed
- `lib/providers/schedule_notifier.dart` (targeted reads) — `markSkipped`, WR-05 revert-and-rethrow,
  streak-inertness guard
- `lib/data/models/scheduled_chunk.dart` — `ChunkType` enum, `isSkipped`/`goalId` fields
- `lib/screens/today/widgets/free_time_row.dart` — confirming `_DashedRegionPainter` is separate
- `lib/screens/goals/goals_screen.dart` — confirming the unrelated `Icons.drag_indicator` usage
- `test/screens/today_screen_test.dart`, `today_timeline_model_test.dart`,
  `today_row_widgets_test.dart`, `today_screen_now_state_test.dart` (targeted reads covering every
  `kPixelsPerMinute`/`kBreakHitSlop`/literal occurrence and every `testWidgets` title in the
  Phase-31 groups)
- `flutter test` run this session: 639/639 passing, ~16s
- `lsof -i :8143` / `ps` run this session: confirmed a stale server from 2026-08-26 08:06:46 still
  squatting the UAT port

### Secondary (MEDIUM confidence)
- `.planning/phases/32-breaks-you-can-tap/32-UI-SPEC.md` — cross-checked against source above;
  every specific claim it makes about existing code was independently re-verified rather than
  trusted, and one gap (the `SwipeableRowShell.visualHeight` dead-parameter retirement) was found
  that its own retirement table omits.
- `.planning/ROADMAP.md` Phase 32 entry and `.planning/STATE.md` — cross-checked for the
  `kPixelsPerMinute` blast-radius claim (partially corrected, see above) and the port-8143 history.

### Tertiary (LOW confidence)
- None — no WebSearch/external-package research was needed for this phase (no new dependency, pure
  in-house Flutter/Dart code).

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new packages; every widget primitive already in use elsewhere in this file tree.
- Architecture: HIGH — every file, line range, and current behavior claim was read directly this session.
- Pitfalls: HIGH — each pitfall is grounded in a specific, quoted line range, not a generic warning.
- Constant re-derivation table: HIGH — every current value and every "unchanged because absolute-threshold" claim was verified against the doc comments and cross-checked arithmetically.
- The `kPixelsPerMinute` literal count: MEDIUM-HIGH — my count (3 must-migrate + a separate to-be-deleted category) is independently derived and reproducible via the grep commands shown, but it is a correction to, not a simple confirmation of, the ROADMAP's stated "4."

**Research date:** 2026-08-27
**Valid until:** Until this phase's plan is executed — this is a point-in-time snapshot of a codebase
mid-migration; any commit to the four core files before planning starts invalidates the line numbers
above (not the reasoning).
