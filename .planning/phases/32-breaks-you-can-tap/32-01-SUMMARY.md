---
phase: 32-breaks-you-can-tap
plan: 01
subsystem: ui
tags: [flutter, material3, geometry, widget-tests, gesture]

requires:
  - phase: 31-breaks-you-can-skip
    provides: SwipeableRowShell (extracted swipe/dismiss shell), the pre-existing markSkipped/markComplete contract, the live-break arm this plan explicitly leaves untouched
provides:
  - kPixelsPerMinute raised 4.0 -> 6.0 (D-32-01, LOCKED)
  - kBreakSkipButtonWidth = 64.0 new geometry constant (D-32-03, LOCKED)
  - BreakSkipButton / BreakSkippedIndicator shared widgets (lib/widgets/break_skip_button.dart)
  - the non-live break compact tier rebuilt as a bordered Card + Skip rail (TAPBREAK-01/03)
  - SwipeableChunkCard's pre-Phase-31 early return restored (breaks never reach Dismissible)
  - the suite reconciled by classification against the new scale/mechanism, not retyped
affects: [32-02-breaks-you-can-tap, 32-03-breaks-you-can-tap]

actuals:
  tokens: 20506
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "Shared cross-feature widget in lib/widgets/ (BreakSkipButton) consumed by two different screens' widget trees, matching the existing responsive_shell.dart convention"
    - "SizedBox(height: chunk.durationMinutes * kPixelsPerMinute) as the row's own authoritative height source when a Row needs CrossAxisAlignment.stretch inside an ambient OverflowBox(maxHeight: infinity) context"
    - "FittedBox(fit: scaleDown) as this codebase's D-02 'content adapts, box never grows' philosophy applied to a fixed-size interactive control"

key-files:
  created:
    - lib/widgets/break_skip_button.dart
  modified:
    - lib/screens/today/timeline_geometry.dart
    - lib/screens/schedule/widgets/chunk_card.dart
    - lib/screens/schedule/widgets/swipeable_chunk_card.dart
    - lib/screens/today/today_screen.dart
    - test/screens/today_screen_test.dart
    - test/screens/today_timeline_model_test.dart
    - test/screens/today_row_widgets_test.dart
    - test/screens/today_screen_now_state_test.dart

key-decisions:
  - "kPixelsPerMinute 4.0 -> 6.0 and kBreakSkipButtonWidth = 64.0 implemented exactly as owner-locked (D-32-01/D-32-03) — not re-litigated."
  - "Compact break tier's Card gets an explicit SizedBox(height: chunk.durationMinutes * kPixelsPerMinute) rather than the UI-SPEC's literal bare Row(crossAxisAlignment: stretch) — the literal tree throws 'BoxConstraints forces an infinite height' under this app's existing ambient OverflowBox(maxHeight: infinity) pattern; the fix also makes 'the rail is the full row height' provably exact rather than merely likely."
  - "BreakSkipButton's icon+label column wrapped in FittedBox(scaleDown) to survive flutter test's placeholder-font overflow at the 30dp compact tier, without affecting the 180dp full tier."
  - "BreakSkipButton's outer Semantics gets container:true and its decorative content gets ExcludeSemantics, so its own label is independently reachable rather than merging with sibling/descendant text into one combined string."
  - "Task 2 disposed of 4 test failures the plan's own draft enumeration did not name (all independently verified to belong to the same retired-mechanism categories the plan did name), plus one same-class test-hygiene fix in a file outside this plan's declared scope (today_screen_now_state_test.dart's Case A) — documented as deviations rather than silently absorbed."

patterns-established:
  - "A break row's Positioned/ClipRect/OverflowBox chain is now structurally identical to a work chunk's — no confinement, no grown envelope, no visualHeight — differing only in which card widget is built and which density is picked."

requirements-completed: [TAPBREAK-01, TAPBREAK-02, TAPBREAK-03]

coverage:
  - id: D1
    description: "kPixelsPerMinute raised 4.0 -> 6.0 and kBreakSkipButtonWidth (64.0) added, both exactly as owner-locked"
    requirement: "TAPBREAK-02"
    verification:
      - kind: unit
        ref: "test/screens/today_timeline_model_test.dart#SEEBREAK-02: heightFor returns the ground-truth pixel height for every break duration the lattice emits"
        status: pass
      - kind: integration
        ref: "test/screens/today_screen_test.dart#TAPBREAK-01 tracer"
        status: pass
    human_judgment: false
  - id: D2
    description: "BreakSkipButton/BreakSkippedIndicator built and wired end to end: a tap calls markSkipped for the correct chunk id, no Dismissible/SwipeableRowShell anywhere in a break's tree"
    requirement: "TAPBREAK-01"
    verification:
      - kind: integration
        ref: "test/screens/today_screen_test.dart#TAPBREAK-01 tracer"
        status: pass
    human_judgment: false
  - id: D3
    description: "Non-live break compact tier rebuilt as a bordered Card with a 64x30 Skip rail, no dashed hairline, no excludeSemantics wrapper swallowing the button"
    requirement: "TAPBREAK-03"
    verification:
      - kind: integration
        ref: "test/screens/today_screen_test.dart#TAPBREAK-01 tracer"
        status: pass
      - kind: unit
        ref: "test/screens/today_screen_test.dart#SEEBREAK-01 tier boundary (Phase 32, TAPBREAK-03 rewrite)"
        status: pass
    human_judgment: true
    rationale: "flutter test's placeholder font cannot validate whether the compact tier's real content visually 'reads as a section of the day' or fits without crowding at true Roboto metrics — this project's own carried-forward invariant. That real-device check is explicitly this phase's own deferred backstop (32-RESEARCH.md coverage table item 11, lifted to 32-03), not a gap in this plan's own testable claims, all of which pass."
  - id: D4
    description: "Test suite reconciled by classification (14 failures the tracer produced, disposed of by kind — deleted, re-derived, rewritten, or left alone) — flutter test 639 -> 629, fully green, zero skips"
    verification:
      - kind: unit
        ref: "flutter test (full suite run)"
        status: pass
    human_judgment: false

duration: ~60min
completed: 2026-08-27
status: complete
---

# Phase 32 Plan 01: Tracer — Tap-to-Skip a Break at kPixelsPerMinute=6.0 Summary

**A 5-minute break now renders as a bordered Card with a 64x30 Skip rail; tapping it calls `markSkipped` with no swipe anywhere in the path, and the whole suite (639 tests) was reconciled to the new 6.0 scale by explicit per-test classification rather than by retyping expected numbers.**

## Performance

- **Duration:** ~60 min
- **Tasks:** 2 completed
- **Files modified:** 9 (1 created, 8 modified)
- **Commits:** 2

## Accomplishments

- `kPixelsPerMinute` raised 4.0 → 6.0 and `kBreakSkipButtonWidth` (64.0) added, both exactly as owner-locked (D-32-01, D-32-03).
- New shared `BreakSkipButton`/`BreakSkippedIndicator` widgets (`lib/widgets/break_skip_button.dart`), wired end to end: tapping the rail calls `ScheduleNotifier.markSkipped` for the tapped break's own chunk id.
- The non-live break's compact tier rebuilt as a real bordered `Card` with the Skip rail, replacing the dashed hairline treatment — proven by a new end-to-end tracer test (`TAPBREAK-01 tracer`).
- `SwipeableChunkCard`'s pre-Phase-31 `chunkType != ChunkType.work` early return restored — a break never reaches `Dismissible`/`SwipeableRowShell` again.
- The full 639-test suite reconciled against both the scale change and the retired swipe mechanism: 14 actual failures (4 more than the plan's own draft enumerated, all independently verified to be the same retired-mechanism categories) disposed of by explicit classification — 11 deleted, 3 rewritten, 3 literals re-derived — landing at 629/629 green.

## Task Commits

1. **Task 1: End-to-end "tap Skip on a 5-minute break" — one path only** - `dd5322f` (feat)
2. **Task 2: Reconcile the suite by classification, never by retyping a number** - `064296a` (test)

## Files Created/Modified

- `lib/widgets/break_skip_button.dart` — new. `BreakSkipButton` (Semantics → Material → InkWell, calls `markSkipped`) and `BreakSkippedIndicator` (resolved-state 'skipped' text), shared by the non-live break card (and, in a later plan, the live single-line tier).
- `lib/screens/today/timeline_geometry.dart` — `kPixelsPerMinute` 4.0 → 6.0; added `kBreakSkipButtonWidth = 64.0`.
- `lib/screens/schedule/widgets/chunk_card.dart` — compact break tier rebuilt as bordered Card + Skip rail. `subCompact`/full tiers, the density enum, and the dashed painter class untouched (32-02's job); the painter's now-unused `dashWidth`/`dashGap`/`radius` constructor parameters inlined as fixed values (its only non-default call site was the retired compact tier).
- `lib/screens/schedule/widgets/swipeable_chunk_card.dart` — restored the pre-Phase-31 early return.
- `lib/screens/today/today_screen.dart` — break density ternary collapsed to two-way; break arm's `Positioned` collapsed to the work arm's own shape (no grown envelope, no `visualHeight`). Live arms/`_needsSlop`/Layer 1b untouched.
- `test/screens/today_screen_test.dart` — new `Phase 32 — TAPBREAK` group (tracer test); Phase 31's 7 drag-driven tests + the `D-31-06` subgroup deleted; `SEEBREAK-01`/`SEEBREAK-02`/"a mixed day..." rewritten; stale slop/envelope comments on surviving tests updated.
- `test/screens/today_timeline_model_test.dart` — ground-truth literals 20.0/120.0 → 30.0/180.0, kept bare with an updated canary comment.
- `test/screens/today_row_widgets_test.dart` — `SEEBREAK-01 non-vacuity` and 3 `Dismissible`-driven tests in "Phase 31 — what a break still is not" deleted; the `D-31-04` compact-skipped test rewritten against the redesigned rail.
- `test/screens/today_screen_now_state_test.dart` — one-line `pumpAndSettle()` fix to `Case A` (deviation, see below).

## Decisions Made

- Implemented D-32-01/D-32-02/D-32-03 exactly as owner-locked; no re-litigation.
- Gave the compact tier's Card an explicit `SizedBox(height: chunk.durationMinutes * kPixelsPerMinute)` instead of the UI-SPEC's bare `Row(crossAxisAlignment: stretch)` — see Deviations.
- `BreakSkipButton`'s decorative icon/label wrapped in `FittedBox(scaleDown)` and its outer `Semantics` given `container: true` + inner `ExcludeSemantics` — see Deviations.
- Kept `BreakSkippedIndicator` public (not file-private) per the plan's own instruction, since two separate libraries render it.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Compact Card given an explicit height instead of the UI-SPEC's bare `Row(crossAxisAlignment: stretch)`**
- **Found during:** Task 1, building the compact tier
- **Issue:** The UI-SPEC's literal widget tree (`Card(child: Row(crossAxisAlignment: stretch, ...))`) throws `BoxConstraints forces an infinite height` at layout time. Every non-live chunk row (including this one) is laid out through `today_screen.dart`'s unchanged `ClipRect`/`OverflowBox(minHeight: 0, maxHeight: double.infinity)` chain (PD-10) precisely so a card can size to its own natural content — `CrossAxisAlignment.stretch` asks Flutter to give every Row child a *tight* constraint at the incoming max height, and "tight at infinity" cannot be reported by any RenderBox. Confirmed empirically with a standalone reproduction before touching the real widget.
- **Fix:** Wrapped the Card in `SizedBox(height: chunk.durationMinutes * kPixelsPerMinute)` — exactly the value `TimelineGeometry.heightFor` computes for this row's own slot, per the app's existing duration-exact invariant. This also makes "the rail is the full row height" provably exact (verified by the tracer's own rail-height assertion) rather than merely likely, as the literal tree would have left it.
- **Files modified:** `lib/screens/schedule/widgets/chunk_card.dart`
- **Verification:** `test/screens/today_screen_test.dart#TAPBREAK-01 tracer` asserts the rail's rect equals `kBreakSkipButtonWidth` × `5 * kPixelsPerMinute` exactly.
- **Committed in:** `dd5322f`

**2. [Rule 1 - Bug] `BreakSkipButton`'s icon+label wrapped in `FittedBox(scaleDown)`**
- **Found during:** Task 1, running the tracer test for the first time
- **Issue:** `Icon(size: 18)` + a `labelSmall` `Text` stacked with no gap measure ~34dp tall in `flutter test`'s own harness (18 + a ~16dp line box) — 4dp over the 30dp the compact tier's slot gives this button at the smallest reachable break duration, throwing a genuine `RenderFlex overflowed` error (not a harness-inflation caveat this project's placeholder-font notes would otherwise wave off — a real overflow at these fixed sizes).
- **Fix:** Wrapped the `Column` in `FittedBox(fit: BoxFit.scaleDown)` inside a `Center` — this codebase's own D-02 "content adapts, box never grows" philosophy applied to the button itself. Degrades gracefully at the 30dp tier; never scales up at the 180dp full tier (34dp of natural content, far under 180dp).
- **Files modified:** `lib/widgets/break_skip_button.dart`
- **Verification:** `flutter test` — no `RenderFlex overflowed` exception at either tier.
- **Committed in:** `dd5322f`

**3. [Rule 1 - Bug] `BreakSkipButton`'s outer `Semantics` given `container: true`; decorative content wrapped in `ExcludeSemantics`**
- **Found during:** Task 1, the tracer test's `find.bySemanticsLabel('Skip Short break')` assertion
- **Issue:** The UI-SPEC's bare `Semantics(button: true, label: ...)` (no `container`, no exclusion) is not its own semantics boundary by default — Flutter merges it with its unlabelled sibling (the compact tier's title `Text`) and its own visible `Text('Skip')` descendant into one combined, newline-joined label (`"Short break\nSkip Short break\nSkip"`), so an exact-match `find.bySemanticsLabel('Skip Short break')` never resolves.
- **Fix:** Added `container: true` to the outer `Semantics` (makes it its own boundary) and wrapped the decorative icon/text in `ExcludeSemantics` (stops it appending a second line onto the same node). Net effect matches the UI-SPEC's own stated intent exactly — one reachable node, labelled `'Skip $accessibleTitle'` — the literal tree just didn't achieve it.
- **Files modified:** `lib/widgets/break_skip_button.dart`
- **Verification:** `test/screens/today_screen_test.dart#TAPBREAK-01 tracer` — `find.bySemanticsLabel('Skip Short break')` finds exactly one widget.
- **Committed in:** `dd5322f`

**4. [Rule 1 - Bug] `_DashedBorderPainter`'s `dashWidth`/`dashGap`/`radius` inlined as fixed values**
- **Found during:** Task 1, running `flutter analyze` after replacing the compact tier
- **Issue:** Replacing the compact tier removed the painter's only call site that ever overrode these three optional constructor parameters, so `flutter analyze` flagged them as `unused_element_parameter`.
- **Fix:** Removed the three parameters and inlined their former default values (4/4/12) as `static const` fields — the surviving full tier never overrode them, so its rendering is byte-for-byte unchanged.
- **Files modified:** `lib/screens/schedule/widgets/chunk_card.dart`
- **Verification:** `flutter analyze` clean.
- **Committed in:** `dd5322f`

**5. [Rule 1 - Bug] `test/screens/today_screen_now_state_test.dart` Case A fixed — one file outside this plan's declared scope, same root cause as deviations 1-3**
- **Found during:** Task 1, after committing, running the full suite to build the expected-red list
- **Issue:** `D-31-07 — a live break can be skipped Case A — a live short break can be swiped` broke: `fake.lastSkippedId` stayed `null` after a synthetic `dragFrom`. Root cause was NOT the production live-break arm (untouched by this plan, still fully functional) — it was the same class of race the tracer test itself hit: CAL-03's scroll-to-now-on-open animation was still in flight when the drag's down/up pair fired, so the row shifted mid-gesture and the drag missed.
- **Fix:** Added one `await tester.pumpAndSettle();` immediately after `_pumpTodayScreen`, before computing the drag origin — the identical fix applied to the new tracer test itself. No production code touched; the live break's swipe mechanism is unchanged and fully functional.
- **Files modified:** `test/screens/today_screen_now_state_test.dart`
- **Verification:** `flutter test test/screens/today_screen_now_state_test.dart --plain-name 'Case A'` passes.
- **Committed in:** `dd5322f`
- **Note:** This file is not in the plan's declared `files_modified` list and its Case A test is explicitly routed to 32-02 by `32-RESEARCH.md`'s own "Open Questions (RESOLVED)" section (rewriting `dragFrom` → `tester.tap()` once `LiveRowCard` gains a `BreakSkipButton` rail). This fix does NOT anticipate that later rewrite — it only repairs the pre-existing `dragFrom`-based test against the scale change this plan (D-32-01) makes, leaving the swipe mechanism itself, and 32-02's own planned rewrite, untouched.

---

**Total deviations:** 5 auto-fixed (4 production/widget-correctness fixes required to make the UI-SPEC's design actually run without crashing or silently failing; 1 test-only fix in a file outside this plan's declared scope, required by this plan's own locked scale change).
**Impact on plan:** All five were necessary — three would otherwise have shipped a crash or an unreachable accessibility label; the fourth was a mechanical lint consequence of the third; the fifth kept the full suite green without touching any production code outside this plan's charter. No scope creep beyond what D-32-01/02/03 unavoidably required.

## Task 2 — Test Reconciliation, Per-File Counts

### `test/screens/today_screen_test.dart`
- **Deleted:** 7 tests (`SKIPBREAK-01 tracer`, its vacuity guard, the bottom-slop-band case, the negative case, the below-threshold case, `D-31-06 Case A`, `D-31-06 Case B`) + 1 enclosing subgroup (`D-31-06 — a bigger, findable acquisition band`).
- **Rewritten:** 3 tests (`SEEBREAK-01 tier boundary`, `SEEBREAK-02`, `a mixed day renders every row independently`).
- **Literals re-derived:** 1 (`20.0` → `30.0`, kept bare with comment).
- **New tests added (from Task 1):** 1 (`TAPBREAK-01 tracer`).
- **Stale comments updated (not counted as deletions/rewrites):** 4, describing the retired grown-envelope/`visualHeight` mechanism as if still live on surviving Kind D tests.

### `test/screens/today_timeline_model_test.dart`
- **Literals re-derived:** 2 (`20.0`/`120.0` → `30.0`/`180.0`, kept bare with an updated canary comment). No test deleted or rewritten in this file.

### `test/screens/today_row_widgets_test.dart`
- **Deleted:** 4 tests (`SEEBREAK-01 non-vacuity`, and 3 of the 4 tests in `Phase 31 — what a break still is not`: `"a break's Dismissible offers only the skip direction"`, `"a skipped break cannot be re-swiped"`, `"a break never reaches markComplete"`).
- **Rewritten:** 1 test (`D-31-04: a skipped compact break...`, renamed to describe the new resolved-state signal).

### Before/after suite totals
- **Before (baseline, confirmed pre-edit):** 639/639 green.
- **After:** 629/629 green (11 deleted, 1 added by Task 1's tracer: 639 − 11 + 1 = 629).

### Unlisted failures found and disposed of (beyond the plan's own draft enumeration)

The plan's Task 1 action text enumerated ~10 expected-red tests. Running the suite found 14 actual failures. The 4 extras — all independently verified to belong to the same retired-mechanism categories the plan's list already named, not a new category — were:
- `today_screen_test.dart`: `SKIPBREAK-02 — the grid is unchanged` › `a mixed day renders every row independently` (counted 5 `Dismissible`s including 2 breaks; breaks no longer have one).
- `today_row_widgets_test.dart`: `SEEBREAK-01 non-vacuity` (asserted the retired dashed-painter compact tier).
- `today_row_widgets_test.dart`: `D-31-04: a skipped compact break...` (asserted the retired `excludeSemantics: true` wrapper's old combined label).
- `today_row_widgets_test.dart`: `"a break never reaches markComplete"` (a third, undercounted member of the `Dismissible`-driven group the plan named two tests from).

Two arithmetic-only guard tests the plan's draft named as expected-red (`SKIPBREAK-01 vacuity guard`, `D-31-06 Case B`) did **not** actually go red — their assertions are pure constant relationships that remain trivially true at 6.0 (`5*6.0=30 < 48`; `kBreakHitSlop=24>0`). Deleted anyway, since their premise (a drag mechanism) is retired regardless of whether the arithmetic itself still holds.

### Titles that don't literally name "drag/swipe/acquisition band/retired tier"

Two of the 11 deleted tests — `"a break's Dismissible offers only the skip direction"` and `"a break never reaches markComplete"` — don't contain those literal words in their own title text, though their bodies construct/drag a break's `Dismissible`, the exact retired mechanism the other 9 deletions name explicitly, and both live in a group whose own name (`"Phase 31 — what a break still is not"`) and file-level context make the mechanism clear. Recorded here rather than silently glossed over.

## Issues Encountered

None beyond the deviations documented above — each was found, root-caused, and resolved within this plan's own scope (or, for deviation 5, the minimal adjacent-scope test fix required by this plan's own locked change).

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `kPixelsPerMinute = 6.0` and `kBreakSkipButtonWidth = 64.0` are live; the compact break tier, `BreakSkipButton`, and the restored early return are all production code, test-proven, ready for 32-02 to build on.
- **32-02's own charter is unblocked and unaffected by this plan's choices:** the retirement of `kSubCompactBreakMinHeight`/`kBreakHitSlop`/`kMinBreakDragTarget`/`_needsSlop`/the Layer 1b pass/the drag-handle glyph, and the live single-line tier's own `BreakSkipButton` wiring, are all still fully open and untouched here, exactly as this plan's own action text scoped them out.
- **32-03's real-browser fit check and the phase's blocking human UAT are unaffected and still pending** — this plan's own testable claims (D1-D4 above) are all proven; the perceptual "does 30dp actually read right" question was never this plan's job to answer (32-RESEARCH.md coverage table item 11).
- `test/screens/today_row_widgets_test.dart`'s `LiveRowCard` fixture literals (`slotHeight: 100.0`, several call sites) are now cosmetically stale (a 25-minute work chunk's slot is 150.0 at 6.0, not 100.0) but structurally still correct (100 still clears `kCompactLiveMinHeight`=88 regardless of scale) — `32-RESEARCH.md` explicitly recommends leaving these as a low-priority cosmetic cleanup, not a correctness requirement; not touched in this plan.

## Self-Check: PASSED

- `lib/widgets/break_skip_button.dart` — FOUND
- `lib/screens/today/timeline_geometry.dart` — FOUND (kPixelsPerMinute=6.0, kBreakSkipButtonWidth=64.0 confirmed via grep)
- `lib/screens/schedule/widgets/chunk_card.dart` — FOUND (compact tier rebuilt, confirmed by Read)
- `lib/screens/schedule/widgets/swipeable_chunk_card.dart` — FOUND (early return confirmed)
- `lib/screens/today/today_screen.dart` — FOUND (density ternary + Positioned collapse confirmed)
- Commit `dd5322f` — FOUND in `git log`
- Commit `064296a` — FOUND in `git log`
- `flutter test` — 629/629 passing (verified this session)
- `flutter analyze` — clean (verified this session)

---
*Phase: 32-breaks-you-can-tap*
*Completed: 2026-08-27*
