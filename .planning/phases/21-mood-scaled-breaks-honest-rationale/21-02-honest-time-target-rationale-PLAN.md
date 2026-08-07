---
phase: 21-mood-scaled-breaks-honest-rationale
plan: 02
type: execute
wave: 2
depends_on: [21-01-mood-scaled-break-cadence]
files_modified:
  - lib/services/schedule_generator.dart
  - test/services/schedule_generator_test.dart
autonomous: true
requirements: [TONE-01]

must_haves:
  truths:
    - "A time-target chunk for a goal under its weekly pace reads 'Working toward 5.0h this week'"
    - "The literal string 'behind this week' appears nowhere under lib/"
    - "No chunk rationale produced by the generator contains the word 'behind' at any mood"
    - "The on-track branch still reads exactly 'On track this week' — TONE-01 did not disturb the sibling branch"
    - "The remaining-hours arithmetic is byte-for-byte unchanged: same clamp, same toStringAsFixed(1)"
  artifacts:
    - path: "lib/services/schedule_generator.dart"
      provides: "Reframed time-target rationale string in _timeTargetRationale"
      contains: "Working toward "
    - path: "test/services/schedule_generator_test.dart"
      provides: "Two rationale-copy tests pinning both branches of _timeTargetRationale"
      contains: "TONE-01:"
  key_links:
    - from: "_timeTargetRationale"
      to: "ScheduledChunk.rationale"
      via: "four call sites inside generate() — restorative floor, PRIORITY-03 surplus, VSCHED-03 reservation, FILL-02 round-robin"
      pattern: "rationale: _timeTargetRationale\\(goal, completionLogs, date\\)"
    - from: "ScheduledChunk.rationale"
      to: "chunk_card.dart / chunk_detail_sheet.dart / focus_screen.dart"
      via: "verbatim render in the existing bodySmall rationale badge — no widget change needed"
      pattern: "chunk.rationale"
---

<objective>
Replace the time-target deficit string `'${remaining}h behind this week'` with the locked replacement
`'Working toward ${remaining}h this week'`, and pin both branches of `_timeTargetRationale` with tests
so the copy cannot silently regress.

Purpose: TONE-01 requires that no schedule or rationale text anywhere reads "behind this week", and
that a time-target goal's rationale reads as what the schedule is doing *for* the user rather than as
a deficit report. `_timeTargetRationale` is the single producer of that string — 21-RESEARCH.md
re-verified this by grep against the working tree, independently of 21-UI-SPEC.md's claim — so one
return-statement edit covers all four emission points and all three rendering widgets.

This is copy-only. The `remaining` computation, the `< 0.1` threshold, and the `toStringAsFixed(1)`
formatting are unchanged; no numeric behavior may move. Note that `_timeTargetRationale` has **no
existing test coverage at all** today, so the two tests here are the first thing that constrains this
string.

Output: one changed return statement in `lib/services/schedule_generator.dart`; two new tests in
`test/services/schedule_generator_test.dart`; a green repo-wide grep gate.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/21-mood-scaled-breaks-honest-rationale/21-UI-SPEC.md
@.planning/phases/21-mood-scaled-breaks-honest-rationale/21-RESEARCH.md
@.planning/phases/21-mood-scaled-breaks-honest-rationale/21-PATTERNS.md
@lib/services/schedule_generator.dart
@test/services/schedule_generator_test.dart
</context>

## Artifacts this phase produces

| Symbol | Kind | Location | New/Modified |
|--------|------|----------|--------------|
| `ScheduleGeneratorService._timeTargetRationale` deficit-branch return | string literal / interpolation | `lib/services/schedule_generator.dart` (currently line 190) | Modified |
| `TONE-01: under-pace time-target rationale reads as working toward, not behind` | test | `test/services/schedule_generator_test.dart` | **New** |
| `TONE-01: on-track branch is unchanged` | test | same | **New** |

No new files. No new packages. No widget, screen, model, or Hive change — the three rendering sites
(`chunk_card.dart`, `chunk_detail_sheet.dart`, `focus_screen.dart`) already display
`chunk.rationale` verbatim through the existing `bodySmall` / `onSurfaceVariant` style and require no
edit (21-UI-SPEC.md: Typography, Color, Spacing all reasoned N/A).

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Pin both rationale branches with tests (RED)</name>

  <files>test/services/schedule_generator_test.dart</files>

  <read_first>
    - `test/services/schedule_generator_test.dart` — the file being modified. Read the setup block
      (lines 1-88) for `sut`, `monday` (`DateTime(2026, 3, 23)`), and the builders `makeTimeTarget`
      and `makeLog`. Plan 21-01 has already appended six tests to this file; append after those.
    - `lib/services/schedule_generator.dart` lines 178-191 — `_timeTargetRationale`, the helper under
      test: the `_completedChunksThisWeek` → `completedHrs` → clamped `remaining` chain, the
      `remaining < 0.1` branch, and the return being replaced.
    - `lib/services/schedule_generator.dart` lines 141-158 — `_remainingHours` and
      `_demandForTimeTarget`, which decide whether a time-target chunk is generated at all. These are
      what make the on-track branch reachable through the public API (see the arithmetic below).
    - `.planning/phases/21-mood-scaled-breaks-honest-rationale/21-UI-SPEC.md` — the Copywriting
      Contract table. It is the locked source for both strings and for the banned-word list.
    - `.planning/phases/21-mood-scaled-breaks-honest-rationale/21-PATTERNS.md` — the note that this
      file never unit-tests private helpers; assert through `sut.generate(...)`'s returned chunks.
  </read_first>

  <behavior>
    Both tests use `blocks: []`, `date: monday`, `moodIndex: 3`, `lighterDay: false`. Both expected
    results below were produced by running the real generator, not derived on paper.

    **Test A — deficit branch (the one TONE-01 changes).**
    Goals: a single `makeTimeTarget(name: 'Reading', weeklyHourBudget: 5)`. No completion logs.
    `remaining` = 5.0 − 0 = 5.0, so `toStringAsFixed(1)` yields `5.0`. Demand is
    `ceil(5.0 × 60 / 25 / 7) = 2` chunks (Monday → `daysLeft` = 7), so the result is exactly 3 chunks:
    `work, shortBreak, work`. Both work chunks carry the time-target rationale.
    Assertions: `result.length == 3`; `result[0].rationale == 'Working toward 5.0h this week'`;
    `result[2].rationale == 'Working toward 5.0h this week'`; and — the durable guard — every chunk in
    the result has a `rationale` that does **not** contain `'behind'` (case-insensitive).

    **Test B — on-track branch (must stay unchanged).**
    Goals: a single `makeTimeTarget(name: 'Almost', weeklyHourBudget: 0.45)`, plus one completion log
    via `makeLog(goalId: <that goal>.id, dateYmd: '2026-03-23')`. One completed chunk is 25/60 =
    0.4167 h, so `remaining` = 0.45 − 0.4167 = 0.033 — greater than zero (so demand is still 1 and a
    chunk is generated) but below the 0.1 threshold (so the on-track branch fires). The result is
    exactly 1 chunk: `work`.
    Assertions: `result.length == 1`; `result[0].rationale == 'On track this week'`.

    Test B is a regression guard, not a new behavior: it must pass both before and after Task 2.
  </behavior>

  <action>
    Append two `test(...)` blocks to the existing `main()` in
    `test/services/schedule_generator_test.dart`, after the tests plan 21-01 added, using the exact
    names `'TONE-01: under-pace time-target rationale reads as working toward, not behind'` and
    `'TONE-01: on-track branch is unchanged'`.

    For Test A's "no chunk says behind" assertion, iterate the result and assert on each chunk's
    `rationale`, using `contains('behind')` against the lowercased rationale so a future
    re-introduction in any casing is caught. Give it a `reason:` naming TONE-01.

    For Test B, hold the goal in a local variable before building the goals list so `makeLog` can
    reference `goal.id` — `Goal` generates its own id, so the log must be built from the same
    instance that is passed to `generate`.

    Add a short comment above each test recording the arithmetic that makes the expected string
    deterministic (Test A: budget 5.0, zero logs, `remaining` 5.0 → `5.0`; Test B: budget 0.45 minus
    one 25-minute completion = 0.033, under the 0.1 on-track threshold but above zero so a chunk is
    still demanded). This matches the existing convention of documenting capacity arithmetic in-test.

    Do NOT assert against `_timeTargetRationale` directly — it is private and this file's established
    style is integration-style assertions on `sut.generate(...)`'s returned `List<ScheduledChunk>`.
    Do NOT modify any existing test. Do NOT rename the `most-behind` wording in the T-09-02 test
    around line 628 — 21-UI-SPEC.md places that developer-facing sort-order naming explicitly out of
    scope; it describes which goal is most under-served, not user-facing copy.

    **Expected RED state.** Run the suite at the end of this task against the UNCHANGED
    `_timeTargetRationale`. Exactly one of the two new tests must fail:

    | Test | Result before Task 2 | Detail |
    |---|---|---|
    | Test A (`reads as working toward, not behind`) | **FAIL** | Actual rationale is `5.0h behind this week`; expected `Working toward 5.0h this week` |
    | Test B (`on-track branch is unchanged`) | **PASS** | The `remaining < 0.1` branch is not being changed |

    If Test B fails here, the log/budget arithmetic in the setup is wrong — fix the test, not the
    generator. If Test A passes here, the assertion is not actually reading the time-target rationale
    and must be rewritten before Task 2.
  </action>

  <verify>
    <automated>export PATH="$PATH:/home/dan/development/flutter/bin"; flutter test test/services/schedule_generator_test.dart 2>&1 | tail -20</automated>
  </verify>

  <acceptance_criteria>
    - `grep -c "TONE-01:" test/services/schedule_generator_test.dart` returns exactly 2.
    - `flutter test test/services/schedule_generator_test.dart` reports exactly **1 failure out of 62 tests**, and the failing test name contains `working toward`.
    - The failure output shows the actual value `5.0h behind this week` against the expected `Working toward 5.0h this week`.
    - The test named `TONE-01: on-track branch is unchanged` is in the passing set.
    - No test added by plan 21-01 appears in the failure list (all 6 `BREAK-0*` tests still green).
    - `git diff --stat lib/` is empty — this task touches no production file.
  </acceptance_criteria>

  <done>
    Two new TONE-01 tests exist; the suite reports 61 passing and 1 failing; the single failure is
    Test A asserting the new string against the old "behind this week" output; no production code has
    changed.
  </done>
</task>

<task type="auto">
  <name>Task 2: Reframe the time-target rationale (GREEN) and close the grep gate</name>

  <files>lib/services/schedule_generator.dart</files>

  <read_first>
    - `lib/services/schedule_generator.dart` lines 160-191 — the three rationale helpers in order:
      `_habitRationale`, `_outcomeRationale` (whose `'Working toward your goal'` at line 171 is the
      voice being matched), and `_timeTargetRationale` (the one being edited).
    - `.planning/phases/21-mood-scaled-breaks-honest-rationale/21-UI-SPEC.md` — Copywriting Contract.
      The replacement string and the banned-word list are locked there, not up for reinterpretation.
    - `lib/services/schedule_generator.dart` lines 404-530 — the four `rationale:
      _timeTargetRationale(goal, completionLogs, date)` call sites (restorative floor, PRIORITY-03
      surplus, VSCHED-03 reservation, FILL-02 round-robin). Read enough to confirm all four route
      through the helper, so no call site needs its own edit.
  </read_first>

  <action>
    One edit in `lib/services/schedule_generator.dart`, and nothing else in the file.

    In `_timeTargetRationale`, replace only the final return's value. The current value interpolates
    `remaining.toStringAsFixed(1)` followed by the literal `h behind this week`. The new value must be
    the literal `Working toward ` followed by the same `remaining.toStringAsFixed(1)` interpolation
    followed by the literal `h this week` — producing, for example, `Working toward 5.0h this week`
    and `Working toward 0.3h this week`. Note there is no space between the number and `h`, matching
    the current formatting exactly.

    Leave everything else in the helper byte-for-byte identical: the `_completedChunksThisWeek` call,
    the `completed * 25.0 / 60.0` conversion, the `.clamp(0.0, double.infinity)`, the `remaining < 0.1`
    threshold, and the `return 'On track this week';` sibling branch. The `toStringAsFixed(1)` call in
    particular must be preserved verbatim — the tests pin `5.0`, not `5`.

    **Explicitly out of scope for this diff — do not touch:**
    - `_habitRationale` and `_outcomeRationale`. 21-UI-SPEC.md lists both as unchanged.
    - The `'Carried over from yesterday'` string and commitment-block `rationale: block.name`.
    - The `most-behind first` phrase in the allocation-order class doc comment (currently line 19).
      It is developer-facing sort-order semantics, not user copy, and 21-UI-SPEC.md scopes it out.
      It also does not contain the banned phrase `behind this week`, so it does not affect the gate.
    - The `most-behind` naming in the T-09-02 test around line 628.
    - Anything from plan 21-01 (`_moodBreakCadence`, `longBreakEvery`, break duration literals).

    Do not introduce any of the framings 21-UI-SPEC.md bans into this or any other string in the
    diff: "behind", "short", "owe(s)", "missed", "failing", "catch up", "deficit", or any
    percentage/comparison-to-target framing.
  </action>

  <verify>
    <automated>export PATH="$PATH:/home/dan/development/flutter/bin"; flutter test test/services/schedule_generator_test.dart 2>&1 | tail -5 && grep -rn "behind this week" lib/ | grep -vE ':\s*//' | wc -l</automated>
  </verify>

  <acceptance_criteria>
    - `flutter test test/services/schedule_generator_test.dart` reports **62 tests, 0 failures** ("All tests passed!").
    - `flutter test` (full suite) reports 0 failures.
    - `flutter analyze lib/services/schedule_generator.dart` reports "No issues found!".
    - `grep -rn "behind this week" lib/ | grep -vE ':\s*//' | wc -l` outputs `0` — the phase gate from 21-VALIDATION.md.
    - `grep -rn "behind this week" lib/ | wc -l` also outputs `0` — the phrase is gone from comments too, not just from executable lines.
    - `grep -c "Working toward " lib/services/schedule_generator.dart` returns exactly 2: `_outcomeRationale`'s pre-existing `Working toward your goal` and the new time-target string.
    - `grep -n "On track this week" lib/services/schedule_generator.dart` still returns exactly 1 line.
    - `grep -c "toStringAsFixed(1)" lib/services/schedule_generator.dart` returns exactly 1 — the formatting call was preserved, not rewritten.
    - `git diff --stat lib/` shows exactly one file changed, 1 insertion and 1 deletion.
    - `git diff lib/services/schedule_generator.dart | grep -E "^[-+]" | grep -vE "^(\+\+\+|---)" | wc -l` outputs `2` — a strictly one-line replacement.
  </acceptance_criteria>

  <done>
    `_timeTargetRationale`'s deficit branch returns `Working toward <N.N>h this week`; the on-track
    branch and all arithmetic are untouched; `behind this week` returns zero matches anywhere under
    `lib/`; all 62 tests and the full `flutter test` suite pass; the production diff is exactly one
    changed line.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| (none crossed by this plan) | This plan changes one string-building return inside a pure, synchronous helper. The only value interpolated is `remaining`, a `double` computed from `goal.weeklyHourBudget` and a count of local `CompletionLog` records and rendered through `toStringAsFixed(1)` — never user-controlled free text. The result is displayed by Flutter `Text` widgets, which do not interpret markup. No network, filesystem, process, or deserialization boundary is involved. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-21-03 | Injection / Tampering (output encoding) | `_timeTargetRationale` string interpolation | accept | The single interpolated value is a `double` formatted by `toStringAsFixed(1)`, which can only emit digits, a decimal point and an optional minus sign. No SQL, HTML, shell, or template is constructed, and Flutter `Text` renders the result literally. There is no injection vector to mitigate. |
| T-21-04 | Information Disclosure | rationale text shown on the schedule surface | accept | The string exposes the user's own weekly hour figure back to that same user on their own local device. No new data leaves the process; nothing is logged, exported, or transmitted. This is strictly less disclosive than the string it replaces. |
| T-21-SC | Tampering (supply chain) | package installs | not applicable | This plan installs no packages and adds no dependency. `pubspec.yaml` is not in `files_modified`. |

## Conclusion

Per 21-RESEARCH.md's Security Domain section, this phase has **no ASVS L1-relevant surface**. Both
rows above are dispositioned `accept` on the basis that no control is required, not on the basis of
tolerated risk. Nothing is rated `high`; nothing blocks.
</threat_model>

<verification>
Run after both tasks, from the repo root:

1. `export PATH="$PATH:/home/dan/development/flutter/bin"; flutter test` — full suite, 0 failures.
2. `grep -rn "behind this week" lib/ | wc -l` — outputs `0`. This is the automated phase gate named
   in 21-VALIDATION.md and must be green before `/gsd-verify-work`.
3. `flutter analyze` — no new issues.
4. `git diff lib/services/schedule_generator.dart` — confirm the production diff for this plan is a
   single replaced return line. Anything else is out of scope and must be reverted.

**Deferred to UAT (not a blocking checkpoint in this plan).** 21-VALIDATION.md lists one manual-only
verification: that the new rationale *reads* as help rather than as a deficit report. That judgment
cannot be made by a unit test, and the project runs in `yolo` mode, so it is not modelled as a
blocking task here. Record it for `/gsd-verify-work` / UAT with these steps: create a time-target goal
with a weekly hour budget, complete fewer chunks than the weekly pace, generate today's schedule, and
read the rationale badge on the resulting chunk in `chunk_card.dart`. It must not imply the user has
failed. Objective coverage of the same criterion — the exact string, the absence of "behind", and the
untouched on-track branch — is fully automated by Task 1's two tests plus the grep gate above.
</verification>

<success_criteria>
- Roadmap success criterion 3: no schedule or rationale text anywhere reads "behind this week"
  (`grep -rn "behind this week" lib/` returns nothing), and a time-target goal's rationale reads as
  what the schedule is doing for the user — `Working toward 5.0h this week` — matching the voice of
  the pre-existing `Working toward your goal` used for outcome goals.
- Both branches of `_timeTargetRationale` are now covered by tests; before this plan the helper had
  no test coverage at all.
- The `remaining` arithmetic, the `< 0.1` threshold, and `toStringAsFixed(1)` are provably unchanged
  (one-line production diff).
</success_criteria>

<output>
Create `.planning/phases/21-mood-scaled-breaks-honest-rationale/21-02-SUMMARY.md` when done.
Record: the exact shipped string, the grep-gate output, the RED failure observed at the end of Task 1,
and confirmation that the production diff was a single line.
</output>
