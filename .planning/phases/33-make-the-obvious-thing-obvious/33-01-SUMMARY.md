---
phase: 33-make-the-obvious-thing-obvious
plan: 01
subsystem: ui
tags: [flutter, widget-tests, material3, color-scheme, custom-painter, layout-constraints]

requires:
  - phase: 22-today-timeline
    provides: FreeTimeRow, TimelineRowTile, the D-05 locked free-time copy, and the original free-time/break visual match
  - phase: 26-calendar-timeline
    provides: ChunkCardDensity (compact/full/detailed) and the _buildTrailingStatus call sites
  - phase: 32-breaks-you-can-tap
    provides: the bordered-Card break vocabulary (surfaceContainer / outlineVariant / 12dp radius) this plan copies, and the kPixelsPerMinute 6.0 slot geometry
provides:
  - "_StatusChip — a labelled To do / Done / Skipped chip in the chunk row's trailing slot, replacing the unlabelled circle"
  - "_DashedChipBorderPainter — the retired free-time dash rhythm, carried forward for the Skipped chip's border"
  - "FreeTimeRow as a filled bordered Card matching the break vocabulary"
  - "test/screens/chunk_card_status_chip_test.dart — 7 standing assertions on the chip's words, non-tappability and flex behaviour"
  - "A loose-constraint (TimelineRowTile) non-collapse height test, proven able to fail"
affects: [33-05 UAT screenshots, any future change to the chunk row's trailing slot or the free-time treatment]

actuals:
  tokens: 7438
  tasks: 3
  commits: 4

tech-stack:
  added: []
  patterns:
    - "Structural flex assertion over width assertion: find.byWidgetPredicate((w) => w is Flexible) rather than find.byType(Flexible), because find.byType compares runtimeType exactly and silently does NOT match the Expanded subclass — a byType version of this assertion was measured green against the very mutation it existed to catch."
    - "Loose-constraint widget-test harness: pump a timeline row through TimelineRowTile (Row(crossAxisAlignment: start) + Expanded) rather than a bare SizedBox, so a height assertion can distinguish a filling child from a collapsing one. Measured side by side against a deliberately introduced defect: tight harness 232.0 (passes over it), loose harness 20.0 (catches it)."
    - "Mutation-verified numeric bounds: every measured ceiling in the new tests carries the mutation that trips it and the number it produced, recorded in the test comment beside the bound."

key-files:
  created:
    - test/screens/chunk_card_status_chip_test.dart
  modified:
    - lib/screens/schedule/widgets/chunk_card.dart
    - lib/screens/today/widgets/free_time_row.dart
    - test/screens/today_row_widgets_test.dart

key-decisions:
  - "The compact tier's `if (isResolved)` guard is deleted, not relaxed: T-26-02's rationale ('dropping it for an unresolved chunk removes an empty icon slot') was true of a circle and is exactly what this phase overturns — the slot now carries a word."
  - "The `To do` chip's transparent-state fill is expressed as a null BoxDecoration.color, not Colors.transparent, so no hardcoded Colors literal reaches the widget tree (this file's own standing test gate)."
  - "UI-SPEC item 6 is pinned structurally (no Flexible ancestor) rather than by width alone, after the width-only form was measured unable to fail the Expanded mutation."
  - "The item-6 width ceiling is 110dp, not the plan's 80dp — the correct implementation measures 91.5dp under flutter test's placeholder font. The plan's 80 was a pre-measurement estimate of that same harness number."
  - "free_time_row.dart keeps its `Center` child, and the reason is written into the code: a Card sizes to its child and the production constraint is loose, so Center is the thing that fills the slot."

patterns-established:
  - "Kind C test repoint: when a test's premise inverts rather than its expected value, rewrite it in place with the reason recorded above it — following today_row_widgets_test.dart's own Phase 32 precedent — rather than deleting it."
  - "Retired mechanism leaves a tombstone comment naming what was deleted and where its behaviour went (free_time_row.dart's _DashedRegionPainter note points at _DashedChipBorderPainter)."

requirements-completed: [OBVIOUS-01]

coverage:
  - id: D1
    description: "An unresolved work chunk reads `To do` in its trailing slot at every density tier, and Icons.radio_button_unchecked no longer exists in chunk_card.dart"
    requirement: OBVIOUS-01
    verification:
      - kind: unit
        ref: "test/screens/chunk_card_status_chip_test.dart#1. unresolved chunk at compact tier reads \"To do\""
        status: pass
      - kind: unit
        ref: "test/screens/chunk_card_status_chip_test.dart#2. unresolved chunk at full tier reads \"To do\""
        status: pass
      - kind: unit
        ref: "test/screens/today_row_widgets_test.dart#unresolved work chunk: no strikethrough, To do chip, Complete/Skip present"
        status: pass
    human_judgment: false
  - id: D2
    description: "A completed chunk reads `Done` and a skipped chunk reads `Skipped` — one vocabulary, three words, never a bare glyph"
    requirement: OBVIOUS-01
    verification:
      - kind: unit
        ref: "test/screens/chunk_card_status_chip_test.dart#3. completed chunk reads \"Done\", never \"To do\""
        status: pass
      - kind: unit
        ref: "test/screens/chunk_card_status_chip_test.dart#4. skipped chunk reads \"Skipped\", never \"To do\""
        status: pass
    human_judgment: false
  - id: D3
    description: "The chip is display-only and introduces no second way to complete a chunk"
    requirement: OBVIOUS-01
    verification:
      - kind: unit
        ref: "test/screens/chunk_card_status_chip_test.dart#5. the chip is display-only — nothing about it is tappable"
        status: pass
      - kind: unit
        ref: "test/screens/chunk_card_status_chip_test.dart#6. no second completion affordance — one Complete, one Skip"
        status: pass
    human_judgment: false
  - id: D4
    description: "The chip does not push the compact-tier title into ellipsis — it is flex 0 0 auto and the title yields"
    requirement: OBVIOUS-01
    verification:
      - kind: unit
        ref: "test/screens/chunk_card_status_chip_test.dart#7. backstop (UI-SPEC item 6): the title yields, the chip does not"
        status: pass
    human_judgment: false
  - id: D5
    description: "FreeTimeRow renders as a filled bordered Card at the break's own fill/radius/border tokens, with the D-05 locked copy unchanged"
    requirement: OBVIOUS-01
    verification:
      - kind: unit
        ref: "test/screens/today_row_widgets_test.dart#both forms render a Card"
        status: pass
      - kind: unit
        ref: "test/screens/today_row_widgets_test.dart#leading form renders exactly \"Free until 8:00 AM\""
        status: pass
      - kind: unit
        ref: "test/screens/today_row_widgets_test.dart#gap form renders exactly \"Free · 1h 40m\""
        status: pass
    human_judgment: false
  - id: D6
    description: "The free-time card fills its allocated timeline slot instead of collapsing to label height"
    requirement: OBVIOUS-01
    verification:
      - kind: unit
        ref: "test/screens/today_row_widgets_test.dart#the card fills its allocated slot, it does not collapse to label height"
        status: pass
    human_judgment: false
  - id: D7
    description: "The change reads correctly on a real Today timeline — chip weight beside the title, free-time fill against neighbouring break and work cards"
    verification: []
    human_judgment: true
    rationale: "Visual weight and the free-time/break match are judgments against a rendered screen, not assertions. Phase 32 shipped a screen the owner rejected on sight despite a 6-of-6 UI-SPEC, precisely because nobody rendered a whole screen and looked at it. Plan 33-05 owns the screenshot UAT."

duration: 12min
completed: 2026-09-01
status: complete
---

# Phase 33 Plan 01: The Chunk Row Names Its Own State Summary

**The unlabelled circle is gone from the Today timeline — every work row now says `To do`, `Done` or `Skipped` in words, and free time is a filled card matching a break again.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-09-01T13:53:34Z
- **Completed:** 2026-09-01T14:05:50Z
- **Tasks:** 3
- **Files modified:** 4 (3 modified, 1 created)

## Accomplishments

- **Deleted `Icons.radio_button_unchecked` from `chunk_card.dart`.** This was the owner's 2026-06-12 complaint, on screen for 2.5 months because no phase ever aimed at it. Zero occurrences remain.
- **Added a file-private `_StatusChip`** rendering a labelled chip in all three states at all three density tiers, geometry copied verbatim from the file's own `_ValenceChip` so the chip family sits at one visual weight. Display-only: no `InkWell`, no `GestureDetector`, no `IconButton`, no `onTap`.
- **Dropped the compact tier's `if (isResolved)` guard**, which was the single line preventing an unresolved compact row from saying anything about its state.
- **Restored the Phase 22 free-time/break match** by rebuilding `FreeTimeRow` on the break's own `Card` (`surfaceContainer` fill, `outlineVariant` 1dp side, 12dp radius, `Clip.antiAlias`) and deleting `_DashedRegionPainter` outright.
- **Suite is green at 629** (621 baseline + 8 new), `flutter analyze` clean across the repo.

## Task Commits

1. **Task 1 (RED): failing status-chip tests** — `cd3c432` (test)
2. **Task 1 (GREEN): the chunk row names its own state** — `6e99967` (feat)
3. **Task 2: free time is a filled card** — `b1abbe4` (feat)
4. **Task 3: repoint the four tests whose premise changed** — `3fda4b1` (test)

## Files Created/Modified

- `lib/screens/schedule/widgets/chunk_card.dart` — added `_StatusChip` and `_DashedChipBorderPainter`; rewrote `_buildTrailingStatus` to a single expression; removed the compact tier's resolved-only guard; rewrote the two doc comments that asserted the retired rule.
- `lib/screens/today/widgets/free_time_row.dart` — `CustomPaint` → `Card`; `_DashedRegionPainter` deleted with a tombstone comment; class doc rewritten (two of its claims had become false).
- `test/screens/chunk_card_status_chip_test.dart` — **new.** 7 assertions covering the three words, non-tappability, the single Complete/Skip pair, and the item-6 flex backstop.
- `test/screens/today_row_widgets_test.dart` — one inverted test, one new non-collapse height test, three repointed row-vocabulary tests.

## Decisions Made

**1. UI-SPEC item 6 is pinned structurally, not by width.** The plan asked for a width ceiling. I wrote it, then tried to prove it could fail by wrapping the chip in `Expanded` at the compact call site — and it stayed green. Two flex children split the 192dp content band evenly at **92.0dp each**, one half-pixel above the chip's own natural 91.5dp, so no ceiling loose enough to survive the harness font could ever catch that regression. Replaced with a structural finder (no `Flexible` ancestor) and kept the width bound as a coarse companion.

**2. `find.byType(Flexible)` does not match `Expanded`.** The first structural finder was `find.byType(Flexible)`, and it *also* stayed green against the `Expanded` mutation — `find.byType` compares `runtimeType` exactly, so the subclass slips through. Switched to `find.byWidgetPredicate((w) => w is Flexible)`, which fails the mutation as intended. Both facts are recorded in the test comment; this was two un-failable assertions caught in a row on the same line, in a codebase that has shipped defects behind exactly this five times.

**3. Null, not `Colors.transparent`.** The `Skipped` chip has no fill. Expressed as a null `BoxDecoration.color` rather than `Colors.transparent`, because this file carries a standing "no hardcoded `Colors` literal reaches the widget tree" gate.

**4. The `Center` rationale lives in the code, not just the test.** The next person to tidy `free_time_row.dart` will see a `Center` wrapping a single `Text` and reach for `Padding`. The comment above it now states the loose-constraint mechanism and points at the test that catches the collapse.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] The item-6 width ceiling of 80dp cannot be met by a correct implementation**

- **Found during:** Task 1 (chunk row status chip)
- **Issue:** The plan specified `expect(chipWidth, lessThan(80.0))`. Built exactly to the plan's own geometry spec (8dp padding either side, 12dp icon, 4dp gap, `labelSmall` label), the chip measures **91.5dp** under `flutter test`'s placeholder font, which draws every glyph as a fixed `fontSize`-wide box. The plan's own comment anticipated this inflation and called 80 "a generous ceiling"; it was a pre-measurement estimate and simply too low.
- **Fix:** Raised to 110dp with the measured 91.5 and the full arithmetic recorded in the test comment, and — more importantly — added the structural `Flexible` assertion that actually pins item 6, so the requirement is not resting on a number at all. Verified the raised bound still has teeth: a chip wrapped in `SizedBox(width: 150)` measures 150.0 and trips it.
- **Files modified:** `test/screens/chunk_card_status_chip_test.dart`
- **Verification:** Both mutations run and observed failing; both numbers recorded in place.
- **Committed in:** `6e99967`

**2. [Rule 3 — Blocking] Task 3A's test file was created during Task 1, not Task 3**

- **Found during:** Task 1
- **Issue:** Task 1 is marked `tdd="true"`, which requires a failing test before the implementation. The test that would fail is Task 3A's `chunk_card_status_chip_test.dart`. The two instructions cannot both be honoured in the stated order.
- **Fix:** Wrote the file first as Task 1's RED gate (`cd3c432`, 6 of 7 assertions failing — assertion 6 passes correctly, it guards an unchanged invariant), then implemented. Task 3 covered parts B, B2 and C as written. Nothing from Task 3A was dropped; all 7 assertions exist and pass.
- **Files modified:** `test/screens/chunk_card_status_chip_test.dart`
- **Verification:** RED run captured before `cd3c432`; GREEN after `6e99967`.
- **Committed in:** `cd3c432` / `6e99967`

---

**Total deviations:** 2 auto-fixed (1 × Rule 1, 1 × Rule 3)
**Impact on plan:** No scope creep. Deviation 1 strengthened the assertion it touched rather than weakening it. Deviation 2 is a task-ordering consequence of the plan's own `tdd="true"` flag.

## Issues Encountered

**Two acceptance-criteria greps in Task 3 cannot return 0 as written.** Both are plan-authoring imprecision, not unfinished work:

- `grep -c "neither form renders a Card" today_row_widgets_test.dart` → returns **1**, not 0. The one hit is inside the recorded-reason comment, which the same task instructed me to write ("leave a short comment above it recording that it was inverted by Phase 33 / sketch 003 and why"). Quoting the retired test's name is the codebase's own precedent (lines ~740-763 of this file quote three retired names verbatim). Comment-filtered — `grep -v '^\s*//'`, the form the plan's other criteria use — it returns **0**, which is the criterion's actual intent: no live test carries that name.
- `grep -c "find.text('skipped')" today_row_widgets_test.dart` → returns **2**, not 0. Both survivors are at lines 866 and 907, in the D-31-04 **break** density group. Breaks render their own lowercase `skipped` from `_buildBreak`, which is behind this phase's explicit "do not touch the break tiers" fence. The criterion's own gloss says "the lowercase string is gone **from the work-chunk test**" — and it is; the work-chunk test now reads `find.text('Skipped')`. Driving the file-wide count to 0 would have required editing out-of-scope break tests.

**RED observations, all run and recorded rather than asserted:**

| Assertion | Mutation | Observed |
|---|---|---|
| Status chip suite | none (pre-implementation) | 6 of 7 fail; assertion 6 correctly passes |
| Free-time non-collapse | card's `Center` → bare `Text`, loose harness | height **232.0 → 20.0**, fails |
| Free-time non-collapse | same defect, **forbidden** bare-`SizedBox` harness | height **232.0**, **passes over the defect** |
| Item-6 flex backstop | chip wrapped in `Expanded` | width 92.0; `byType(Flexible)` green, `is Flexible` fails |
| Item-6 width bound | chip wrapped in `SizedBox(width: 150)` | width **150.0**, fails |

The third row is the one worth keeping: the harness the plan forbade reports the *correct number for the wrong reason* and sails straight over a collapsed row. The prohibition was load-bearing, not stylistic.

## Known Stubs

None. No placeholder values, no `TODO`/`FIXME`, no skipped tests, no unwired data sources introduced.

## Threat Flags

None. No new network endpoint, auth path, file access pattern or schema change — this plan is display-layer only. T-33-01 (chip masquerading as a control) and T-33-02 (no new mutation path) are both mitigated and pinned by tests D3 above.

## TDD Gate Compliance

Task 1's gate sequence is present in git log: `test(33-01)` at `cd3c432` (RED, observed failing) → `feat(33-01)` at `6e99967` (GREEN). No REFACTOR commit was needed.

## State Files — deliberately not written from this worktree

`STATE.md`, `ROADMAP.md` and the plan-progress counters are **left for the orchestrator to update after the wave merges.** Three concrete reasons, recorded so this does not read as an omission:

1. **33-02 is also wave 1** and runs concurrently in its own worktree. `STATE.md` here is 767 lines of accumulated narrative; two worktrees writing the same progress row and the same `stopped_at` line produce a merge conflict in exactly the file where a bad resolution is most expensive.
2. **This plan's own `files_modified` frontmatter excludes them** — it declares four code/test files and nothing else.
3. **The project's global operating guide documents a data-loss bug in precisely these write verbs.** `state.advance-plan`, `state.begin-phase` and `phase.complete` edit `STATE.md` by regex over the whole file and match `**Bold:**` body lines before frontmatter keys; on a `STATE.md` that keeps historical sections — which this one does, extensively — they overwrite the wrong occurrence. Read-only `gsd-tools query` verbs are unaffected and were used freely.

`requirements.mark-complete` was skipped for a different reason: **this project has no `.planning/REQUIREMENTS.md`.** `OBVIOUS-01` is defined in `ROADMAP.md` (line 889) instead, so there is no checkbox to tick. Verified by `ls`, not assumed.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- **Ready.** Plans 33-02 through 33-04 touch disjoint files (`weekly_progress_service.dart`, `goal_card.dart`, `goals_screen.dart`, `restoratives_screen.dart`, `add_kind_fork.dart`) and none of them reads the chunk row's trailing status or the free-time treatment.
- **One live note for 33-03:** this plan's `_DashedChipBorderPainter` and `_StatusChip` are file-private to `chunk_card.dart` **by charter**. 33-03 deletes `goal_card.dart`'s `_PriorityChip` and adds a `_TypeChip`; do not "consolidate" the two files' chips while both are open.
- **One live note for 33-05:** D7 above is the only human-judgment deliverable here. The UAT must look at a rendered Today timeline with at least one unresolved chunk, one resolved chunk, one break and one free-time stretch in the same frame — the free-time/break match is only judgeable side by side.
- **No blockers.**

## Self-Check: PASSED

- All 6 claimed files verified present on disk (4 touched by this plan, plus `chunk_card_priority_badge_test.dart`, confirmed still present and passing per the out-of-scope fence).
- All 4 claimed commit hashes verified present in `git log`.
- `flutter analyze` clean across the repo; `flutter test` 629/629 green.

---
*Phase: 33-make-the-obvious-thing-obvious*
*Completed: 2026-09-01*
