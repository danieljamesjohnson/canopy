---
phase: 35-your-real-commitments-read-from-your-calendar
plan: 06
subsystem: ui
tags: [flutter, calendar, commitments, chunk-card, timeline]

requires:
  - phase: 35-01
    provides: "CommitmentBlock.isFromCalendar, CommitmentsNotifier.syncFromCalendar"
  - phase: 35-04
    provides: "CalendarSettingsScreen reachable at /settings/calendars"
provides:
  - "_CommitmentRow imported treatment: 14dp glyph, suppressed edit/delete, read-only sheet on tap (D-35-14)"
  - "ChunkCard/ChunkDetailSheet imported-commitment glyph, resolved by a render-time lookup with no ScheduledChunk schema change (D-35-11)"
  - "35-UAT.md written and pre-flight served — awaiting the owner's verdict, which is the actual gate for this plan and this phase"
affects: []

actuals:
  tokens: 13064
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "Render-time cross-notifier lookup (today_screen._lookupIsImportedCommitment) joining ScheduledChunk.commitmentId against CommitmentsNotifier.blocks, alongside the file's five existing _lookupGoalX helpers — avoids a third Hive schema bump and the trap #4 stale-Hive-data failure a persisted field would have reopened"
    - "File-private duplicated glyph widget (_ImportedGlyph in chunk_card.dart, inline Icon+Semantics in commitments_screen.dart) rather than a shared component — matches this file's own stated duplication charter for _StatusChip/_ValenceChip/_PriorityChip"

key-files:
  created:
    - test/screens/commitments_imported_row_test.dart
    - test/screens/chunk_card_imported_glyph_test.dart
    - .planning/phases/35-your-real-commitments-read-from-your-calendar/35-UAT.md
    - .planning/phases/35-your-real-commitments-read-from-your-calendar/35-06-uat-sample.ics
  modified:
    - lib/screens/commitments/commitments_screen.dart
    - lib/screens/schedule/widgets/chunk_card.dart
    - lib/screens/schedule/widgets/swipeable_chunk_card.dart
    - lib/screens/schedule/widgets/chunk_detail_sheet.dart
    - lib/screens/today/today_screen.dart
    - test/screens/today_screen_test.dart

key-decisions:
  - "The read-only sheet reuses showAdaptiveFormModal (the same modal helper CommitmentFormSheet uses) rather than a bespoke dialog, so it inherits the same desktop-Dialog/mobile-bottom-sheet responsive split already proven for the edit form."
  - "ChunkDetailSheet's isImportedCommitment is threaded through BOTH call sites of today_screen._openDetailSheet (the ordinary timeline row AND the live 'now' row), even though the plan's file list only named the ordinary row — the live row opens the identical ChunkDetailSheet, and leaving it false there would have made the header wrong specifically for whichever chunk happens to be live right now. Not treated as scope creep: it's the same sheet, reached from a second door."
  - "Mutation proof for the compact-density omission produced a genuinely useful negative result, recorded rather than smoothed over: forcing the glyph into _buildCompactContent's Row does NOT change the measured Card height (172→172/180→180, identical) because ChunkCardDensity.compact/full force the Card into an explicit `duration * kPixelsPerMinute` SizedBox regardless of content (D-02/GRID-01) — the box literally cannot grow from content, by construction. The assertion that DOES discriminate the mutation is glyph-presence (findsNothing → findsOneWidget). Both assertions are kept in the test file; the height assertion is a valid regression guard for the box-invariant even though it didn't catch this particular mutation, and burying that fact would have been exactly the kind of 'assertion that cannot fail' this project has been burned by before."

patterns-established:
  - "A render-time lookup that joins two notifiers by an id field, gated with a null-check that short-circuits BEFORE touching the second notifier — avoids ProviderNotFoundException in any test pumping a chunk with no cross-reference at all, which is most of them."

requirements-completed: [CAL-01, CAL-04]

coverage:
  - id: D1
    description: "An imported commitment row carries a 14dp calendar glyph with a 'Imported from your calendar' Semantics label; a hand-entered row carries neither"
    requirement: "CAL-01"
    verification:
      - kind: unit
        ref: "test/screens/commitments_imported_row_test.dart#a row for a block with isFromCalendar: true renders the calendar glyph and its semantics label; a hand-entered block renders neither"
        status: pass
    human_judgment: false
  - id: D2
    description: "An imported row offers no edit or delete affordance (mobile IconButton or desktop hover row); tapping it opens a read-only sheet, never CommitmentFormSheet"
    requirement: "CAL-04"
    verification:
      - kind: unit
        ref: "test/screens/commitments_imported_row_test.dart#mobile: the imported row has no delete IconButton; the hand-entered row keeps its delete IconButton unchanged"
        status: pass
      - kind: unit
        ref: "test/screens/commitments_imported_row_test.dart#desktop: the imported row has no hover edit/delete row; the hand-entered row keeps both, unchanged"
        status: pass
      - kind: unit
        ref: "test/screens/commitments_imported_row_test.dart#tapping the imported row opens the read-only sheet with its locked body copy, not CommitmentFormSheet"
        status: pass
    human_judgment: false
  - id: D3
    description: "Hand-entered commitments are completely unchanged — same tap-to-edit, same affordances — proven by a mutation test that removes the isFromCalendar gate and observes the hand-entered assertions fail"
    requirement: "CAL-04"
    verification:
      - kind: unit
        ref: "test/screens/commitments_imported_row_test.dart#tapping the hand-entered row opens CommitmentFormSheet, not the read-only sheet (mutation-proofed: gate removal observed to fail this + 3 other assertions)"
        status: pass
    human_judgment: false
  - id: D4
    description: "A 120-character imported commitment name renders on one line with an ellipsis and produces no overflow error"
    requirement: "CAL-01"
    verification:
      - kind: unit
        ref: "test/screens/commitments_imported_row_test.dart#a 120-character imported name renders on one line with an ellipsis and produces no overflow error"
        status: pass
    human_judgment: false
  - id: D5
    description: "The Commitments empty state offers 'Import from your calendar' below the existing copy; the AppBar carries a persistent route to Calendars settings on both empty and populated states"
    requirement: "CAL-01"
    verification:
      - kind: unit
        ref: "test/screens/commitments_imported_row_test.dart#the empty state shows the existing copy plus the \"Import from your calendar\" button"
        status: pass
      - kind: unit
        ref: "test/screens/commitments_imported_row_test.dart#the AppBar action is present on the empty state / on the populated state"
        status: pass
    human_judgment: false
  - id: D6
    description: "A work chunk anchored to an imported commitment carries the glyph at detailed/full density, omits it at compact; ChunkDetailSheet's header carries the glyph plus a visible label"
    requirement: "CAL-01"
    verification:
      - kind: unit
        ref: "test/screens/chunk_card_imported_glyph_test.dart (8 tests: detailed/full presence, compact omission + mutation-proofed height/presence split, no-commitmentId inertness, ChunkDetailSheet header)"
        status: pass
    human_judgment: false
  - id: D7
    description: "isFromCalendar reaches the card by a render-time lookup, not a new ScheduledChunk field — no schema bump (D-35-11)"
    requirement: "CAL-01"
    verification:
      - kind: other
        ref: "grep -v '^\\s*//' lib/data/models/scheduled_chunk.dart | grep -c isFromCalendar → 0; git diff --stat -- lib/data/models/scheduled_chunk.dart lib/data/database/migrations.dart → empty; currentSchemaVersion still 11"
        status: pass
    human_judgment: false
  - id: D8
    description: "The owner has seen an imported commitment on his own screen, in the browser, on a day he re-checked-in first — and said whether read-only imported commitments feel right or feel like a refusal"
    verification: []
    human_judgment: true
    rationale: "This is the plan's actual gate (checkpoint:human-verify, gate=blocking-human). 35-UAT.md is written, pre-flight is served and verified (build/serve/port/bytes-on-wire/visual check all confirmed by the executor), and a fixture feed proven against the real ICS stack is live at http://danserver:8161/sample.ics — but the verdict itself, including the two open questions in steps 7a (all-day span) and 7b (RECURRENCE-ID/EXDATE gap), can only come from the owner. Not marked complete."

duration: ~75min
completed: 2026-09-17
status: halted
---

# Phase 35 Plan 06: An imported commitment reads as imported — and the owner's verdict is now the only thing left Summary

**`_CommitmentRow` and `ChunkCard` both gained a 14dp "imported from your calendar" glyph and a read-only treatment, resolved by a render-time lookup with zero schema changes — and a real fixture feed proving the moved/deleted-occurrence gap is now live on the tailnet, awaiting the owner's UAT.**

## Performance

- **Duration:** ~75 min
- **Completed:** 2026-09-17
- **Tasks:** 2 of 3 auto-executed and committed; Task 3 (checkpoint:human-verify) prepared and handed off
- **Files modified:** 6 modified, 4 created (2 test files, 1 UAT doc, 1 fixture)

## Accomplishments

- `_CommitmentRow` (`commitments_screen.dart`) now distinguishes an imported commitment: a 14dp calendar glyph with a screen-reader label, no edit/delete affordance of any kind, and a tap that opens a locked-copy read-only sheet instead of `CommitmentFormSheet`. Hand-entered rows are untouched, proven by a mutation test that removes the gate and watches the hand-entered assertions fail. The AppBar gained a persistent route to `/settings/calendars`; the empty state gained an "Import from your calendar" CTA.
- `ChunkCard` renders the identical glyph on the Today timeline at `detailed`/`full` density, omitted at `compact` — resolved by a new `today_screen._lookupIsImportedCommitment` render-time lookup joining `chunk.commitmentId` against `CommitmentsNotifier.blocks`, exactly alongside the file's five existing `_lookupGoalX` helpers (D-35-11). No `ScheduledChunk` field, no migration, `currentSchemaVersion` unchanged at 11.
- `ChunkDetailSheet`'s header carries the glyph plus the visible "Imported from your calendar" label, so the compact tier's omission is a reachable degrade rather than a hole.
- A mutation proof on the compact-density omission produced a real, useful negative result (recorded rather than hidden): the card's measured height literally cannot change from content at `compact`/`full` because it's forced by an explicit `duration * kPixelsPerMinute` `SizedBox` (D-02/GRID-01) — the discriminating assertion for that mutation turned out to be glyph-presence, not height. Both assertions are kept; the height one is a legitimate regression guard for the box-invariant even though this specific mutation didn't trip it.
- `.planning/phases/35-your-real-commitments-read-from-your-calendar/35-UAT.md` written, with step 0 (mandatory ⟳ Re-check-in) as its own first instruction, and a pre-flight that was actually performed, not just described: debug web build, served via `tools/serve-uat.py` on port 8161 (never before used by this project — checked), bound to `0.0.0.0` and confirmed reachable over the tailnet (not just loopback), served-bytes grep non-zero, and a headless-Chromium screenshot confirming the app renders (not blank) with no JS console errors.
- A fixture feed (`35-06-uat-sample.ics`) built with dates relative to the actual UAT date (2026-09-17) and **verified by running the real `CalendarSyncService`/`IcsCalendarSource` code against it before handing it to the owner** — not assumed from reading the `.ics` text. The real sync output confirmed: today's timeline will show the Weekly Sync TWICE (2pm original + 4pm "(moved)"), proving the `RECURRENCE-ID` override doesn't suppress the original; next week's `EXDATE`'d occurrence still imports; the all-day entry blocks exactly `08:00–22:00`, confirming the plan's claim against the actual `ScheduleGeneratorService.dayStartMinutes`/`dayEndMinutes` constants rather than trusting the plan's prose.

## Task Commits

1. **Task 1: An imported commitment reads as imported, and cannot be edited into a lie** — `aa28d9f` (feat)
2. **Task 2: The same glyph on the timeline, without a schema bump (D-35-11)** — `4605fc5` (feat)

**Task 3 (checkpoint:human-verify, gate=blocking-human): not a commit — the owner's verdict, recorded in `35-UAT.md`, is what closes this plan.**

## Files Created/Modified

- `lib/screens/commitments/commitments_screen.dart` — imported-row glyph/suppression/read-only-sheet, empty-state CTA, AppBar action
- `test/screens/commitments_imported_row_test.dart` — 11 tests + a performed-and-reverted mutation proof
- `lib/screens/schedule/widgets/chunk_card.dart` — `isImportedCommitment` param, `_ImportedGlyph`, glyph in the shared detailed/full content shell, deliberately absent from `_buildCompactContent`
- `lib/screens/schedule/widgets/swipeable_chunk_card.dart` — forwards `isImportedCommitment` to `ChunkCard` on the work-chunk path
- `lib/screens/schedule/widgets/chunk_detail_sheet.dart` — `isImportedCommitment` header treatment
- `lib/screens/today/today_screen.dart` — `_lookupIsImportedCommitment`, wired through `_buildChunkCard` and both `_openDetailSheet` call sites
- `test/screens/chunk_card_imported_glyph_test.dart` — 8 tests + a performed-and-reverted mutation proof
- `test/screens/today_screen_test.dart` — Rule 3 fix: both `MultiProvider` pump helpers gained a `CommitmentsNotifier` (see Deviations)
- `.planning/phases/35-your-real-commitments-read-from-your-calendar/35-UAT.md` — the owner's verification script, step 0 first, pre-flight recorded
- `.planning/phases/35-your-real-commitments-read-from-your-calendar/35-06-uat-sample.ics` — the fixture feed, verified against the real sync stack before serving

## Decisions Made

**The read-only sheet reuses `showAdaptiveFormModal`.** Same modal helper `CommitmentFormSheet` already uses, so it inherits the proven desktop-Dialog/mobile-bottom-sheet split rather than needing its own responsive logic.

**`ChunkDetailSheet.isImportedCommitment` is wired at both `_openDetailSheet` call sites**, including the live "now" row's, even though the plan's file list only named the ordinary timeline row explicitly. Both call sites open the identical `ChunkDetailSheet` — leaving the live-row path unwired would have made the header silently wrong specifically when an imported commitment happens to be the current live chunk. Treated as the same deliverable reached through a second door, not scope creep.

**The mutation-proof result for compact-density height is reported honestly, not smoothed into "passed as expected."** See coverage D6 and the Deviations section below — the height assertion structurally cannot discriminate this mutation, by design (D-02/GRID-01's own duration-exact box invariant), and the SUMMARY says so rather than implying the height assertion was the one that caught it.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `today_screen.dart`'s new `CommitmentsNotifier` dependency broke 16 pre-existing widget tests**
- **Found during:** Task 2, running the full suite after wiring `_lookupIsImportedCommitment` into `_buildChunkCard`
- **Issue:** `test/screens/today_screen_test.dart`'s two `MultiProvider` pump helpers (`_pumpTodayScreen` and the router-based focus-push helper) didn't provide a `CommitmentsNotifier`. Any test pumping a commitment-anchored chunk (non-null `commitmentId`) now threw `ProviderNotFoundException` the moment `_buildChunkCard` ran the new lookup.
- **Fix:** Added `ChangeNotifierProvider<CommitmentsNotifier>.value(value: CommitmentsNotifier())` to both provider trees. A bare `CommitmentsNotifier()` is safe — its default `HiveCommitmentBlockRepository` only touches `Hive.box()` lazily inside a method call, and neither helper ever calls `loadBlocks()`/`saveBlock()`, so `.blocks` stays its in-memory default (`[]`) with zero I/O.
- **Files modified:** `test/screens/today_screen_test.dart`
- **Verification:** `flutter test test/screens/today_screen_test.dart` — 70/70 green; full suite 821/821 green (813 pre-existing baseline + 8 new)
- **Committed in:** `4605fc5` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 3 — an unavoidable consequence of Task 2's own explicit scope: wiring `today_screen.dart` to a real `CommitmentsNotifier` read necessarily changes what any pre-existing test pumping a commitment-anchored chunk through `TodayScreen` must provide).
**Impact on plan:** Matches this repo's stated preference (see 35-04-SUMMARY.md's identical deviation shape) for recording an honest "no pre-existing test edited" contradiction rather than a flattering checklist. Neither pre-existing test's actual assertions changed — only the provider tree gained the dependency the production code now genuinely has.

## Mutation Proofs (required by acceptance criteria)

### Task 1 — CAL-04: the `isFromCalendar` gate actually discriminates

`_CommitmentRowState.build`'s `final isImported = widget.block.isFromCalendar;` was temporarily changed to `final isImported = true;`. Running `flutter test test/screens/commitments_imported_row_test.dart --name "hand-entered"` with the defect in place:

```
Expected: exactly one matching candidate
  Actual: _DescendantWidgetFinder:<Found 0 widgets with type "AnimatedOpacity" descending from
widgets with type "Card" that are ancestors of widgets with text "Gym": []>
   Which: means none were found but one was expected
```

4 tests failed (mobile delete-IconButton, desktop hover-row, tap-opens-CommitmentFormSheet, plus one cascading assertion), all with clear discriminating messages naming the hand-entered fixture ("Gym") specifically. The defect was reverted; `git diff --stat` against the Task 1 commit was empty for this file, and the full suite returned to 813/813 green.

### Task 2 — D-35-11: the compact-density omission, and what actually discriminates it

`_buildCompactContent`'s `Row` was temporarily given the same `if (isImportedCommitment) ...` glyph block the detailed/full shell uses. Running the compact-density tests with the defect in place:

- **"the glyph does not render" (presence assertion): FAILED**, exactly as required —
  ```
  Expected: false
    Actual: <true>
  compact omits the glyph unconditionally — the content degrades by tier, never the box
  ```
- **"the card's measured compact height is identical..." (height assertion): PASSED, unexpectedly.** Instrumented with a temporary debug print to confirm the actual numbers: `with=180.0 without=180.0` — bit-for-bit identical, mutation present or not.

**Why, recorded rather than hidden:** `ChunkCardDensity.compact`/`full` force the `Card` into an explicit `chunk.durationMinutes * kPixelsPerMinute` `SizedBox` at the end of `_WorkChunkContent.build()` (D-02/GRID-01, the "the card is sized by its duration, not by its content" invariant from Phase 32). That `SizedBox` is upstream of anything `_buildCompactContent` renders — content added inside it literally cannot change the measured `Card` height, by construction. Per the plan's own acceptance-criteria caution ("If it passes with the glyph present at compact, the harness is wrong, not the code — fix the harness before continuing"), the harness was re-examined: it isn't wrong, it's testing a real invariant (the box-never-grows rule) that this particular mutation was never going to violate, because this codebase already forces that invariant one layer up from where the mutation lives. The glyph-presence assertion is the one that actually discriminates this specific defect, and both assertions stay in the test file — the height one as a legitimate regression guard for the box invariant itself, the presence one as the guard for the actual "compact omits the glyph" behavior.

The defect was reverted (temporary debug `print` also removed); `flutter test test/screens/chunk_card_imported_glyph_test.dart` returned to 8/8 green on the reverted code.

## Issues Encountered

**`find.bySemanticsLabel(String)` does exact match against the MERGED semantics label, not a substring.** `_CommitmentRow`'s `InkWell` (via its `onTap`) merges the glyph's `Semantics` label together with the row's name and subtitle text into one semantics node — the actual rendered label was `"Imported from your calendar\nTeam standup\nMon · 9am–9:30am"`, not the glyph's label alone. `find.bySemanticsLabel('Imported from your calendar')` (exact match) found zero matches; fixed with `find.bySemanticsLabel(RegExp('Imported from your calendar'))` (substring match via `RegExp.hasMatch`). Verified via a throwaway debug test that printed `tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!.toStringDeep()` before landing the fix — the debug test was deleted afterward, never committed.

## User Setup Required

None — no external service configuration required. The UAT fixture feed is served locally by the executor; the owner needs only a browser pointed at the tailnet URL in `35-UAT.md`.

## Next Phase Readiness

**This is the last plan of the last wave of Phase 35.** Nothing downstream depends on this plan finishing — the phase itself is gated on the owner's UAT verdict, recorded in `35-UAT.md`. Once the owner fills in the answers (including the two open decisions at steps 7a and 7b, which are genuinely his to make, not inferable from code), a follow-up pass should:
- Read the recorded verdict.
- If approved outright: close the phase.
- If 7a's all-day span or 7b's RECURRENCE-ID/EXDATE disposition changed: implement the owner's choice as a small follow-up before closing (7a is a one-constant change; 7b, if not accepted for v1, becomes its own follow-up phase per `WINDOWS.md` entry 1).
- If step 6 (the read-only refusal) reads as a rejection of D-35-14 rather than a confirmation: that's an architectural conversation, not a bug fix — surface it rather than auto-resolving.

The UAT server (port 8161) and the debug build under `build/web/` are left running for the owner to reach; they are not part of the committed diff (build artifacts are gitignored) and can be torn down once he's done.

## Self-Check: PASSED

All 10 created/modified files confirmed present via `test -f`. Both commits (`aa28d9f`, `4605fc5`) confirmed present in `git log --oneline --all`. The UAT server was confirmed live via `curl` against the tailnet IP (`100.108.146.112:8161`, HTTP 200) and a headless-Chromium screenshot, not merely assumed from the process starting without error. No missing items.

---
*Phase: 35-your-real-commitments-read-from-your-calendar*
*Completed: 2026-09-17 (Tasks 1-2; Task 3 awaiting owner verdict)*
