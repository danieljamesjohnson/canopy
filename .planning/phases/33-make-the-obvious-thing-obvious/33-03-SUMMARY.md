---
phase: 33-make-the-obvious-thing-obvious
plan: 03
subsystem: goals-ui
tags: [goals, priority, progress-line, legibility, mutation-tested, kind-a-retirement]
status: complete

requires:
  - "33-02 — WeeklyProgressService.weekFractionFor for the progress fraction"
provides:
  - "GoalCard.rank + GoalCard.weekProgress — a rank gutter and a fixed-geometry weekly progress line"
  - "kGoalProgressTrackHeight — the constant that IS UI-SPEC item 18"
  - "GoalsScreen(completionLogRepository:) — injectable log repo test seam"
affects:
  - "33-04 (goal/restorative fork) shares goals_screen.dart's FAB path — the quick-add field was left goal-only on purpose"

tech_stack:
  added: []
  patterns:
    - "Injectable repository on a screen for a Hive-free test seam (QuarterlyReviewScreen's shape)"
    - "File-private chip widget per file — duplication is the recorded convention, not an oversight"
    - "Fixed-geometry fill over proportional fill when the container's height varies"

key_files:
  created:
    - test/screens/goal_card_progress_line_test.dart
    - test/screens/goals_screen_ranked_list_test.dart
  modified:
    - lib/screens/goals/widgets/goal_card.dart
    - lib/screens/goals/goals_screen.dart
    - test/screens/goals_screen_heading_test.dart
  deleted:
    - test/screens/goal_card_priority_chip_test.dart
    - test/screens/goal_card_priority_chip_rebuild_test.dart

decisions:
  - "The progress track is a 40dp constant, never a fraction of the card — a proportional fill was measured rendering a 0.90 line at 68.4px and a 0.62 line at 76.88px"
  - "Band colours are hard-coded, not theme-derived: ColorScheme.fromSeed moves every role with the mood seed, and there is no key on screen to fall back on"
  - "DevClock.now() rather than DateTime.now() for the week window, so time travel moves the progress line with the rest of the app's clock-gated surfaces"
  - "The ranked-list fixture's sortOrder is the REVERSE of its priority order, because the two agree in production and an agreeing fixture would pass with no sort at all"
  - "Both priority-chip test files retired (Kind A) with the reason recorded in the replacement file, not in a commit message"

metrics:
  duration_minutes: 52
  completed: 2026-09-01

actuals:
  tokens: 71000
  tasks: 3
  commits: 3
---

# Phase 33 Plan 03: Goals Reads As The Priority Order Summary

One ranked list headed `Priority order`, numbered 1..N across every type, with the loudest mark on
each card reassigned from identity colour to this week's progress — red, amber or green on a fill
whose height is a constant times the fraction, never a fraction of the card.

## What was built

**`goal_card.dart`** — `rank` and `weekProgress`, both optional and both nullable (the archived-goals
call site passes neither, and an archived list is not a priority order). The 5dp identity border
became `_ProgressLine`: a 40dp grey track holding a fill that grows bottom-up. The bare 16dp type
glyph became `_TypeChip` — glyph **and** word. `_PriorityChip` is gone; identity colour now paints
exactly one thing, the 16dp swatch, with the WR-03 hover gate above it untouched.

**`goals_screen.dart`** — three `ReorderableListView`s collapsed to one, sorted by `priorityWeight`
descending with a `sortOrder` tie-break. `_buildSectionHeader` and `_buildFullOrderedIds` deleted
rather than left unreferenced; `onReorderItem` is now a straight pass-through because with one list
there is no three-group display order to splice back into. Heading is `Priority order` with the
sub-line and the quick-add `helperText` deleted, not reworded.

| Grep | Expected | Actual |
|---|---|---|
| `_PriorityChip` in `goal_card.dart` (code) | 0 | 0 |
| `FractionallySizedBox` in `goal_card.dart` (code) | 0 | 0 |
| `_PriorityChip` in `chunk_card.dart` | ≥ 2 | 5 — the chunk badge is untouched |
| `kGoalProgressTrackHeight` | ≥ 3 | 8 |
| `goalColor` in `goal_card.dart` | exactly 2 | 2 |
| `ReorderableListView` in `goals_screen.dart` | 1 | 1 |
| `ProviderNotFoundException` | 1 | 1 |
| `removeListener` | 1 | 1 |
| `_buildFullOrderedIds` / `_buildSectionHeader` / `'Your goals'` / `Drag to prioritize` / `refine details later` | 0 | 0 |

## Three assertions were proven able to fail, not assumed

CLAUDE.md's new section is explicit that a compile error is a weak form of red. Each load-bearing
assertion was mutation-tested against the real defect and reverted.

**1. UI-SPEC item 18 — the fixed-geometry backstop.** Reimplemented the fill as
`FractionallySizedBox(heightFactor: progress)` inside the full-height `Positioned`, i.e. the exact
shape `33-PATTERNS.md` §3 warns about. Observed:

```
Expected: a value greater than <76.88>
  Actual: <68.4>
   Which: is not a value greater than <76.88>
the 0.90 line must be taller than the 0.62 line in logical pixels regardless of which card is taller
```

That is the sketch's defect reproduced numerically: a 90% line rendering **68.4px** while a 62% line
renders **76.88px**. The eye compares pixels, not percentages.

The test also carries a **discrimination guard**, because the first fixture I wrote could not have
caught this. With a plain tall/short pair the ratio was only ~1.3, and a proportional fill would
still have satisfied the assertion — a passing test proving nothing. The guard asserts
`shortStack * 0.90 < tallStack * 0.62`, i.e. it asserts the *fixture* is strong enough to invert
under the defect, and fails loudly with both measurements if a future layout change narrows the gap.

**2. The refresh listener is live, not just guarded.** Removed the `addListener` call:

```
Expected: a value greater than <8.333333333333334>
  Actual: <8.333333333333334>
indexedStack keeps this screen mounted across tab switches, so without the listener the bar would
still show the pre-completion value — CLAUDE.md trap 4 in miniature
```

The fill froze at exactly its pre-completion height. This is what stops the
`ProviderNotFoundException` guard from quietly becoming the only path.

**3. The list actually sorts by priority.** Removed the sort:

```
Expected: a value greater than <624.0>
  Actual: <540.0>
Bravo (lower priority) must render below Alpha
```

This one only discriminates because of a fixture change I made *after* the test first passed. My
first fixture set `sortOrder` in agreement with `priorityWeight` — which is what production does,
since `reorderAllWithPriority` writes both in one loop and `loadGoals` sorts by `sortOrder`. With an
agreeing fixture the screen renders the right order **even with the sort deleted**, so the assertion
could not fail. The fixture's `sortOrder` is now the deliberate reverse of its priority order, and
the reason is written into the fixture so nobody "tidies" it back.

## I rendered the whole screen and looked at it

This phase exists partly because Phase 32's UI-SPEC passed 6/6 and still shipped a screen the owner
rejected on sight, "because every constant in it was defended in argument and nobody rendered a whole
screen and looked at it." So I dumped the composed screen (five goals, real logs, 420×900) to a PNG
via a throwaway test and looked at it before writing this summary. Confirmed visually, not just by
assertion: rank gutter leads, the progress line sits on the left edge and fills **bottom-up**, the
green ~0.83 line is long and the two ~0.2 ambers are short stubs at the bottom, the outcome card's
track is empty, and identity colour survives only as the right-hand dot. The throwaway was deleted.

One thing the assertions could not have told me, recorded for the owner's UAT rather than
"fixed": **the empty grey track is very low contrast** against the card surface. On an outcome goal
it reads as *nothing there* rather than as *an empty track*. That is the specified colour
(`surfaceContainerHighest`), and item 15 forbids adding an explanation, so I changed nothing — but
it is the one thing I would want a real pair of eyes on.

## Deviations from Plan

**1. [Rule 2 — correctness] `DevClock.now()` instead of the plan's `DateTime.now()`.**
- **Found during:** Task 2, writing `_loadWeekProgress`.
- **Issue:** The plan specified `DateTime.now()` for the week window. This app has a single clock
  source with a persisted debug offset (DEV-01/02/03), and `quarterly_review_screen.dart:98-100`
  uses `DevClock.now()` with the stated rationale of staying "consistent with the rest of the app's
  clock-gated surfaces". A raw `DateTime.now()` here would make the progress line the one surface
  that ignores time travel — and time travel is how this project does date-dependent UAT.
- **Fix:** `DevClock.now()`, which is exactly `DateTime.now()` in release builds, with the precedent
  cited in a comment.
- **Files modified:** `lib/screens/goals/goals_screen.dart`
- **Commit:** `8521f66`

**2. [cosmetic] Reworded one pre-existing comment** in `_buildReorderableList` that named
`reorderAllWithPriority` in prose, because the plan's acceptance criterion greps the whole file
(not code-only) and expects exactly `1`. The comment now describes the call instead of naming it;
no assertion was weakened and the criterion's intent — one call site — is what is satisfied.

**3. Backstop fixture widened from the first attempt.** Not a plan deviation so much as a recorded
failure of my own first try: at a 230dp width the type chip's own text overflowed
(`RenderFlex OVERFLOWING`) rather than wrapping, because widget tests render every glyph as a
full-em box. 260dp wraps the chip *run* without overflowing the chip.

No architectural changes. No package installs. `flutter analyze` was clean at every commit.

## Fences held

| Fence | Evidence |
|---|---|
| `schedule_generator.dart` not modified | not in `git diff --name-only` for this plan |
| Priority model not re-opened | `lib/providers/goals_notifier.dart` not in the diff; `reorderAllWithPriority` keeps its contract and receives the same `List<String>` shape |
| No legend, no key, no per-card readout | asserted, not just omitted — no band words, no `%` anywhere, and exactly one swatch per goal |
| No bare glyph | every chip is glyph + word; asserted for all three types |
| No shared chip widget extracted | `_TypeChip` is file-private and documents the duplication as deliberate |
| No LLM or suggestion surface | none added |
| `chunk_card.dart`'s own `_PriorityChip` | untouched (5 occurrences); `chunk_card_priority_badge_test.dart` still passes |
| `STATE.md` / `ROADMAP.md` untouched, no `gsd-tools` write verbs run | orchestrator owns phase state |

## Known Stubs

None. Every rendered value is wired to real data through `WeeklyProgressService` and the completion
log — proven by the test that seeds logs and asserts the fill renders in a band colour, rather than
merely that the code compiles.

**One recorded edge, not a stub:** a `weekProgress` of exactly `0.0` renders no fill, because the
fill is only built when `progress > 0` (the plan specifies this explicitly). So a budgeted goal with
nothing done yet is visually identical to an outcome goal with no target. This is inherent to a
proportional bottom-up fill — a zero-height red is zero pixels of red either way — and the
null-vs-`0.0` distinction 33-02 established survives intact in the data and in `_ProgressLine`'s
contract. Flagging it because the distinction was called out as load-bearing: if the owner wants a
just-started goal to show a visible red nub, that is a design decision (a minimum fill height), not
a bug fix, and it belongs to him rather than to me.

## Threat Flags

None. No new network, auth, file-access or schema surface. Of the plan's register:

- **T-33-07** (tampering at the `reorderAllWithPriority` call site) — mitigated: the notifier is
  unmodified, and the ordering test proves the rendered order matches `priorityWeight` descending
  with a fixture that fails if the order is wrong.
- **T-33-08** (a commitment block's completions surfacing on a goal card) — mitigated upstream:
  `WeeklyProgressService` filters on `goalId`, and this plan passes `goal.id` per card.
- **T-33-09** (read rate on the listener) — mitigated: one `getAll()` per notification, and the
  listener is removed in `dispose` (greped).

## Verification

| Check | Result |
|---|---|
| `flutter test` (full suite) | **664 pass** — 651 baseline, minus 6 retired, plus 19 new |
| `flutter analyze` (repo) | **No issues found** |
| Task 2's five "must pass unchanged" test files | all pass, unedited — both defensive guards work |
| `chunk_card_priority_badge_test.dart` | still exists, still passes |
| Retired files gone | both; reason greppable by filename in the replacement (`2` hits) |
| `testWidgets(` in `goal_card_progress_line_test.dart` | **11** (≥ 9 required) |
| `testWidgets(` in `goals_screen_ranked_list_test.dart` | **8** (≥ 7 required) |
| `grep -c 'Legend'` in the ranked-list test | `1` |
| Item 18 backstop observed RED | yes — quoted above, with measurements |
| Refresh-listener test observed RED | yes — quoted above |

## Self-Check: PASSED

- `lib/screens/goals/widgets/goal_card.dart` — FOUND
- `lib/screens/goals/goals_screen.dart` — FOUND
- `test/screens/goal_card_progress_line_test.dart` — FOUND
- `test/screens/goals_screen_ranked_list_test.dart` — FOUND
- `test/screens/goal_card_priority_chip_test.dart` — CONFIRMED ABSENT
- `test/screens/goal_card_priority_chip_rebuild_test.dart` — CONFIRMED ABSENT
- commit `6bfe659` — FOUND
- commit `8521f66` — FOUND
- commit `1ff08fc` — FOUND
