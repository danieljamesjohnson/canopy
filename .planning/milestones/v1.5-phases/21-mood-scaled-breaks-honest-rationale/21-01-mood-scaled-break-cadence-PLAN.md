---
phase: 21-mood-scaled-breaks-honest-rationale
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/services/schedule_generator.dart
  - test/services/schedule_generator_test.dart
autonomous: true
requirements: [BREAK-01, BREAK-02]

must_haves:
  truths:
    - "On a mood-1 (Stormy) day the schedule places a 25-minute long break after every 2nd work chunk"
    - "On a mood-5 (Clear skies) day the schedule places a 25-minute long break after every 5th work chunk"
    - "Moods 2, 3 and 4 each have an explicit asserted cadence (3, 4, 4) — no mood value in 1-5 is untested"
    - "Every short break is exactly 5 minutes and every long break is exactly 25 minutes, at every mood"
    - "No schedule ever ends on a break chunk, at any mood"
    - "All 54 pre-existing tests in schedule_generator_test.dart still pass unmodified"
  artifacts:
    - path: "lib/services/schedule_generator.dart"
      provides: "Mood-indexed break-cadence table replacing the isLowMood ternary"
      contains: "_moodBreakCadence"
    - path: "test/services/schedule_generator_test.dart"
      provides: "Five per-mood cadence tests plus one break-structure test"
      contains: "moodIndex: 2"
  key_links:
    - from: "ScheduleGeneratorService.generate"
      to: "_moodBreakCadence"
      via: "map lookup keyed on the moodIndex parameter (never on isLowMood)"
      pattern: "_moodBreakCadence\\[moodIndex\\]"
    - from: "generate() longBreakEvery"
      to: "_assignSyntheticStartTimes"
      via: "named parameter passthrough — the single source of truth for cadence (WR-01)"
      pattern: "longBreakEvery: longBreakEvery"
---

<objective>
Replace the two-valued break-cadence ternary (`isLowMood ? 3 : 4`) in the schedule generator with a
full five-point mood→cadence table, and — more importantly — create the test coverage that makes the
cadence a verifiable behavior instead of an unconstrained constant.

Purpose: BREAK-01 requires the chunks-before-a-long-break count to scale with the morning mood
(roughly 2 on a low day, 5 on a sunny one), deterministically and unit-tested. BREAK-02 requires the
25-min chunk / 5-min short break / 25-min long break structure to survive that change untouched.

**Read this before you start:** 21-RESEARCH.md empirically established that the existing 54 tests all
pass unchanged when the cadence constant is altered. There is currently **zero** test coverage that
discriminates cadence behavior. The tests in Task 1 are therefore the substance of this plan, not
paperwork attached to a one-line edit. A change to the constant without the tests would ship an
unverified behavior change and fail success criterion 1.

Output: `_moodBreakCadence` table + lookup in `lib/services/schedule_generator.dart`; six new tests in
`test/services/schedule_generator_test.dart`; refreshed class-level doc comment.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/21-mood-scaled-breaks-honest-rationale/21-RESEARCH.md
@.planning/phases/21-mood-scaled-breaks-honest-rationale/21-PATTERNS.md
@.planning/phases/21-mood-scaled-breaks-honest-rationale/21-VALIDATION.md
@lib/services/schedule_generator.dart
@test/services/schedule_generator_test.dart
</context>

## Artifacts this phase produces

| Symbol | Kind | Location | New/Modified |
|--------|------|----------|--------------|
| `ScheduleGeneratorService._moodBreakCadence` | `static const Map<int, int>` field | `lib/services/schedule_generator.dart`, declared immediately after `_moodCap` (currently line 28) | **New** |
| `longBreakEvery` local in `generate()` | `final int`, derivation changed from ternary to map lookup | `lib/services/schedule_generator.dart` (currently line 220) | Modified |
| `ScheduleGeneratorService` class doc comment | doc comment sentence describing cadence | `lib/services/schedule_generator.dart` (currently lines 21-22) | Modified |
| `BREAK-01: mood=1 places a long break after every 2 work chunks` | test | `test/services/schedule_generator_test.dart` | **New** |
| `BREAK-01: mood=2 places a long break after every 3 work chunks` | test | same | **New** |
| `BREAK-01: mood=3 places a long break after every 4 work chunks (baseline unchanged)` | test | same | **New** |
| `BREAK-01: mood=4 places a long break after every 4 work chunks` | test | same | **New** |
| `BREAK-01: mood=5 places a long break after every 5 work chunks` | test | same | **New** |
| `BREAK-02: only 5-min short breaks and 25-min long breaks are ever emitted, at every mood` | test | same | **New** |

No new files. No new packages. No new public API. No Hive model, adapter, or typeId change.

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add the six cadence and break-structure tests (RED)</name>

  <files>test/services/schedule_generator_test.dart</files>

  <read_first>
    - `test/services/schedule_generator_test.dart` — the file being modified. Read the setup block
      (lines 1-88): `sut`, the `monday` fixture (`DateTime(2026, 3, 23)`), the builders
      `makeHabit` / `makeOutcome` / `makeBlock` / `makeTimeTarget` / `makeLog`, and the predicates
      `workChunksOf` / `hasTrailingBreak`. Reuse them; do NOT add new fixtures or a new `main()`.
    - `test/services/schedule_generator_test.dart` lines 190-247 — `Test 6` and `Test 7`, the exact
      "assert `result[i].chunkType` in sequence" style these new tests must match.
    - `test/services/schedule_generator_test.dart` lines 497-546 — the `WR-01` test, the style for
      asserting `durationMinutes` and iterating the result list.
    - `lib/services/schedule_generator.dart` lines 206-230 — the `generate()` signature and the
      current `cap` / `isLowMood` / `longBreakEvery` derivation, so the allocation counts below are
      traceable rather than magic.
    - `lib/services/schedule_generator.dart` lines 707-742 — the packing loop that consumes
      `longBreakEvery`, including the `discIdx + 1 < discretionaryChunks.length` guard which is why
      the final work chunk of a day never gets a trailing break.
    - `.planning/phases/21-mood-scaled-breaks-honest-rationale/21-PATTERNS.md` — Analog A / Analog B
      excerpts for these exact two test shapes.
  </read_first>

  <behavior>
    Every setup below uses `blocks: []`, `date: monday`, `completionLogs: []`, `lighterDay: false`,
    and `makeHabit` / `makeTimeTarget` with default priority (null → 0.5) so habit and outcome demand
    is 1 chunk per goal. The full-day free window is 480→1320 minutes, so slot room never binds.
    All expected sequences below were produced by running the real generator with the target mapping
    patched in — they are measured, not derived on paper.

    Notation: `W` = 25-min work chunk, `S5` = 5-min `ChunkType.shortBreak`, `L25` = 25-min
    `ChunkType.longBreak`. Index is the 0-based position in the returned `List<ScheduledChunk>`.

    | Test | moodIndex | goals | Expected `result.length` | Expected sequence | Long break at index |
    |------|-----------|-------|--------------------------|-------------------|---------------------|
    | mood=1 → cadence 2 | 1 | 2 × `makeHabit` + 2 × `makeTimeTarget(weeklyHourBudget: 5)` | 7 | `W S5 W L25 W S5 W` | 3 |
    | mood=2 → cadence 3 | 2 | 3 × `makeHabit` + 2 × `makeTimeTarget(weeklyHourBudget: 5)` | 9 | `W S5 W S5 W L25 W S5 W` | 5 |
    | mood=3 → cadence 4 | 3 | 4 × `makeHabit` + 1 × `makeTimeTarget(weeklyHourBudget: 5)` | 11 | `W S5 W S5 W S5 W L25 W S5 W` | 7 |
    | mood=4 → cadence 4 | 4 | 5 × `makeHabit` | 9 | `W S5 W S5 W S5 W L25 W` | 7 |
    | mood=5 → cadence 5 | 5 | 6 × `makeHabit` | 11 | `W S5 W S5 W S5 W S5 W L25 W` | 9 |

    Why those goal counts (do not change them without recomputing): `cap = _moodCap[mood]` at
    `lighterDay: false` is 4/6/8/9/11 for moods 1-5, and `habitCeiling = ceil(cap/2)` is 2/3/4/5/6 —
    which is why the mood-1 test needs time-target goals to reach 4 discretionary chunks and the
    mood-5 test can reach 6 from habits alone. On low-mood days (1-2) FILL-01 clamps each
    time-target to 1 chunk; at mood 3 a `weeklyHourBudget: 5` goal has demand 2.

    Sixth test — BREAK-02 structure, cadence-independent: loop `for (int mood = 1; mood <= 5; mood++)`
    over one fixed goal set (6 × `makeHabit` + 2 × `makeTimeTarget(weeklyHourBudget: 5)`), and for
    each generated result assert (a) every `ChunkType.shortBreak` has `durationMinutes == 5`,
    (b) every `ChunkType.longBreak` has `durationMinutes == 25`, (c) every chunk's `chunkType` is one
    of `work` / `shortBreak` / `longBreak`, (d) no two adjacent chunks are both non-work (a break is
    always preceded by a work chunk), and (e) `result.last.chunkType == ChunkType.work`. Do not
    assert lengths or long-break positions in this test — those belong to the five tests above.
  </behavior>

  <action>
    Append six `test(...)` blocks to the existing `main()` in
    `test/services/schedule_generator_test.dart`, after the last existing test group, using the exact
    test names listed in the "Artifacts this phase produces" table above. Match the surrounding file
    style: build `goals` with the existing builders, call `sut.generate(goals: goals, blocks: [],
    moodIndex: <N>, date: monday, completionLogs: [], lighterDay: false)`, then assert.

    For the five cadence tests, assert on the full sequence, not just the long-break index: first
    `expect(result.length, <N>)`, then one `expect(result[i].chunkType, ChunkType.<type>)` per index
    following the table, then `expect(result[<longBreakIndex>].durationMinutes, 25)` and
    `expect(result[1].durationMinutes, 5)`. Add a `reason:` string on the long-break assertion naming
    the cadence being pinned, e.g. that mood 1 must reach a long break after 2 work chunks.

    Include a short comment above each cadence test recording the capacity arithmetic that justifies
    the goal count (`cap`, `habitCeiling`, and how many discretionary chunks result) — this is the
    convention already used by `Test 6` ("lighterDay: false → cap=8, habitCeiling=4 (CAP-01)").

    Do NOT modify any existing test. Do NOT add a new `main()`, new import, or new builder. Do NOT
    reference `isLowMood` or any private member — every assertion goes through the public
    `sut.generate(...)` return value, which is the only test style present in this file.

    **Expected RED state — verify it precisely.** Run the suite at the end of this task against the
    UNCHANGED production code (cadence still `isLowMood ? 3 : 4`). Exactly two of the six new tests
    must fail, and they must fail in this specific way:

    | Failing test | Actual sequence under the old ternary | Actual long-break index |
    |---|---|---|
    | mood=1 → cadence 2 | `W S5 W S5 W L25 W` | 5 (expected 3) |
    | mood=5 → cadence 5 | `W S5 W S5 W S5 W L25 W S5 W` | 7 (expected 9) |

    The mood=2, mood=3, mood=4 and BREAK-02 structure tests must **PASS** at this point — the chosen
    mapping deliberately preserves those three cadences, and the structure test is cadence-independent.
    If mood=3 or mood=4 fails here, the test setup is wrong (recheck the goal counts against the
    capacity arithmetic above), not the production code — stop and fix the test rather than "fixing"
    the generator. If mood=1 or mood=5 unexpectedly passes here, the test is not discriminating
    cadence at all and must be rewritten before Task 2.
  </action>

  <verify>
    <automated>export PATH="$PATH:/home/dan/development/flutter/bin"; flutter test test/services/schedule_generator_test.dart 2>&1 | tail -20</automated>
  </verify>

  <acceptance_criteria>
    - `grep -c "moodIndex: 2" test/services/schedule_generator_test.dart` returns at least 1 (mood 2 currently has zero coverage anywhere in the suite — Pitfall 4 in 21-RESEARCH.md).
    - `grep -c "BREAK-01:" test/services/schedule_generator_test.dart` returns exactly 5.
    - `grep -c "BREAK-02:" test/services/schedule_generator_test.dart` returns exactly 1.
    - `flutter test test/services/schedule_generator_test.dart` reports exactly **2 failures out of 60 tests**, and the two failure names contain `mood=1` and `mood=5` respectively.
    - The mood=1 failure output shows the actual long break at index 5 where index 3 was expected; the mood=5 failure output shows it at index 7 where index 9 was expected.
    - Zero pre-existing test names appear in the failure list (all 54 originals still green).
    - `git diff --stat lib/` is empty — this task touches no production file.
  </acceptance_criteria>

  <done>
    Six new tests exist in `test/services/schedule_generator_test.dart`; the suite reports 58 passing
    and 2 failing; the 2 failures are exactly the mood=1 and mood=5 cadence tests failing at the
    long-break index; no production code has changed.
  </done>
</task>

<task type="auto">
  <name>Task 2: Replace the cadence ternary with the five-point mood table (GREEN)</name>

  <files>lib/services/schedule_generator.dart</files>

  <read_first>
    - `lib/services/schedule_generator.dart` lines 10-38 — the class doc comment (the sentence at
      line 22 is the one going stale), the `_moodCap` table at lines 24-28, and `_effectiveCap` at
      lines 34-38. `_moodCap` is the exact declaration style the new table must mirror: doc comment
      containing the full 1-5 table inline, then a `static const Map<int, int>` literal.
    - `lib/services/schedule_generator.dart` lines 206-230 — `generate()`'s opening, where `cap`,
      `isLowMood` and `longBreakEvery` are derived. Confirm by reading that `isLowMood` is read again
      further down the same method before you touch anything near it.
    - `lib/services/schedule_generator.dart` lines 707-742 — `_assignSyntheticStartTimes`' packing
      loop, to confirm `longBreakEvery` is used only as a modulus divisor and that the `25` / `5`
      duration literals at the `breakDur` line are BREAK-02's boundary and must not move.
    - `.planning/phases/21-mood-scaled-breaks-honest-rationale/21-RESEARCH.md` — sections
      "Anti-Patterns to Avoid" and "BREAK-02 Preservation".
  </read_first>

  <action>
    Three edits in `lib/services/schedule_generator.dart`, and nothing else in the file.

    **Edit 1 — declare the table.** Add a `static const Map<int, int> _moodBreakCadence = {1: 2, 2: 3,
    3: 4, 4: 4, 5: 5};` field immediately below the existing `_moodCap` declaration (currently
    line 28), before `_effectiveCap`. Give it a doc comment in the same shape as `_moodCap`'s: a
    one-line summary ("Break-cadence table: maps moodIndex → work chunks between long breaks"), a
    blank doc line, then the full mapping written out with the mood labels from
    `lib/screens/schedule/checkin_screen.dart` and the reason for each value —
    mood 1 Stormy = 2 (BREAK-01 low endpoint), mood 2 Overcast = 3, mood 3 Partly cloudy = 4
    (unchanged from the pre-BREAK-01 baseline), mood 4 Clearing up = 4, mood 5 Clear skies = 5
    (BREAK-01 sunny endpoint). State in the comment that moods 3 and 4 deliberately plateau at 4
    rather than inventing a strictly increasing curve the success criteria never asked for.

    **Edit 2 — change the derivation.** Replace the single line
    `final int longBreakEvery = isLowMood ? 3 : 4;` (currently line 220) with
    `final int longBreakEvery = _moodBreakCadence[moodIndex] ?? 4;`. The `?? 4` fallback is the
    neutral mood-3 value and matches the existing defensive-default convention at
    `_effectiveCap`'s `_moodCap[moodIndex] ?? 8`.

    Key the lookup on `moodIndex` directly. Do **not** derive it from `isLowMood`, do not widen
    `isLowMood` into a tri-state, and do not remove or move the `final bool isLowMood = moodIndex <= 2;`
    line above it — `isLowMood` is read by ~10 unrelated allocation decisions further down the same
    method (habit demand, outcome inclusion, the restorative floor, the FILL-01 clamps, the VSCHED-03
    guard). Entangling cadence with it is Pitfall 2 in 21-RESEARCH.md.

    **Edit 3 — refresh the stale doc comment.** The class doc comment currently ends with the sentence
    "longBreakEvery = 3 for mood 1-2, 4 for 3-5." (currently line 22). Rewrite that sentence to state
    the new five-point mapping — 2 / 3 / 4 / 4 / 5 for moods 1 through 5 — and point at
    `_moodBreakCadence` as the source of truth.

    **Explicitly out of scope for this diff — do not touch:**
    - The `breakDur` line in `_assignSyntheticStartTimes` (the `isLong ? 25 : 5` literals) or any
      `durationMinutes: 25` literal at a `workChunks.add(...)` call site. Those are BREAK-02's
      contract; only *how often* the 25-minute branch is selected may change.
    - STEP C's break emission. `reservedBreakMinutes` recorded during packing is the single source of
      truth (WR-01); do not add an independent cadence counter there.
    - `_timeTargetRationale` and the "behind this week" string — that is plan 21-02's scope.
    - The "most-behind first" phrase in the allocation-order doc comment (currently line 19). It
      describes time-target sort-order semantics, is developer-facing, and 21-UI-SPEC.md explicitly
      places it out of scope.
  </action>

  <verify>
    <automated>export PATH="$PATH:/home/dan/development/flutter/bin"; flutter test test/services/schedule_generator_test.dart 2>&1 | tail -5 && flutter analyze lib/services/schedule_generator.dart 2>&1 | tail -3</automated>
  </verify>

  <acceptance_criteria>
    - `flutter test test/services/schedule_generator_test.dart` reports **60 tests, 0 failures** ("All tests passed!").
    - `flutter test` (full suite) reports 0 failures.
    - `flutter analyze lib/services/schedule_generator.dart` reports "No issues found!".
    - `grep -n "_moodBreakCadence" lib/services/schedule_generator.dart` returns exactly 2 lines: the declaration and the lookup.
    - `grep -n "isLowMood ? 3 : 4" lib/services/schedule_generator.dart` returns nothing.
    - `grep -n "final bool isLowMood = moodIndex <= 2;" lib/services/schedule_generator.dart` still returns exactly 1 line — `isLowMood` was preserved, not refactored.
    - `grep -n "_moodBreakCadence\[moodIndex\]" lib/services/schedule_generator.dart` returns exactly 1 line — the lookup keys on `moodIndex`, not on `isLowMood`.
    - `git diff lib/services/schedule_generator.dart | grep -E "^[-+].*(isLong \? 25 : 5|durationMinutes: 25)"` returns nothing — no break or chunk duration literal moved (BREAK-02 regression gate).
    - `git diff --stat lib/` shows exactly one file changed with no more than ~15 inserted lines and 2 deleted lines.
    - `grep -v '^ *//' lib/services/schedule_generator.dart | grep -c "3 for mood 1-2"` returns 0 — and the class doc comment now names the 2/3/4/4/5 mapping.
  </acceptance_criteria>

  <done>
    `_moodBreakCadence` exists next to `_moodCap` with a documented five-point table; `longBreakEvery`
    is a lookup on `moodIndex`; `isLowMood` is untouched; the class doc comment describes the new
    mapping; all 60 tests in the generator suite and the full `flutter test` suite pass; the diff
    contains no change to any break or chunk duration literal.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| (none crossed by this plan) | This plan changes a pure, synchronous, side-effect-free computation inside `ScheduleGeneratorService`. Its inputs (`moodIndex`, `List<Goal>`, `List<CommitmentBlock>`, `List<CompletionLog>`) are in-memory objects already constructed and validated by the caller from local Hive storage. There is no network I/O, no filesystem access, no process invocation, no deserialization of untrusted bytes, and no new API surface. `moodIndex` originates from a five-option tap target in `checkin_screen.dart`, not free text. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-21-01 | Tampering (input) | `generate(moodIndex:)` receiving an out-of-range mood | mitigate | The `_moodBreakCadence[moodIndex] ?? 4` lookup is total over all `int` inputs — an unmapped key yields the neutral cadence 4 rather than a null-dereference crash. This mirrors the existing `_moodCap[moodIndex] ?? 8` convention and is asserted implicitly by the mood 1-5 tests. |
| T-21-02 | Denial of Service | packing loop `breakCount % longBreakEvery` | mitigate | A cadence of 0 would raise `IntegerDivisionByZeroException`. The table contains no zero and the fallback is 4, so the divisor is provably ≥ 2 for every input. No further control needed. |
| T-21-SC | Tampering (supply chain) | package installs | not applicable | This plan installs no packages and adds no dependency. `pubspec.yaml` is not in `files_modified`. 21-RESEARCH.md's Package Legitimacy Audit section is correspondingly marked not applicable. |

## Conclusion

Per 21-RESEARCH.md's Security Domain section, this phase has **no ASVS L1-relevant surface**: no
authentication, session, access-control, input-parsing, cryptography, output-encoding, or
data-protection control is introduced, removed, or altered. The two rows above are defensive-coding
concerns rather than security findings, and both are already satisfied by the recommended
implementation. No threat in this plan is rated `high`; nothing blocks.
</threat_model>

<verification>
Run after both tasks, from the repo root:

1. `export PATH="$PATH:/home/dan/development/flutter/bin"; flutter test` — full suite, 0 failures.
2. `flutter analyze` — no new issues in `lib/services/schedule_generator.dart`.
3. `git diff lib/services/schedule_generator.dart` — confirm by eye the diff is exactly: one new
   documented `_moodBreakCadence` field, one changed `longBreakEvery` line, one reworded doc-comment
   sentence. Anything else in the diff is out of scope and must be reverted.
4. `flutter test test/services/schedule_generator_test.dart 2>&1 | grep -c "BREAK-0"` — 6 new tests
   present and named.
</verification>

<success_criteria>
- Roadmap success criterion 1 (partial — cadence half): a mood-1 schedule places a 25-min long break
  after every 2nd work chunk and a mood-5 schedule after every 5th, both asserted by name in
  `test/services/schedule_generator_test.dart`, both deterministic (no randomness, no clock read).
- Roadmap success criterion 2: every short break is 5 minutes and every long break is 25 minutes at
  all five moods, asserted by the BREAK-02 structure test; the diff contains no change to any
  duration literal.
- Every mood value 1-5 has an explicit cadence assertion — including mood 2, which had zero coverage
  anywhere in the suite before this plan.
- 54 pre-existing tests still pass without modification.
</success_criteria>

<output>
Create `.planning/phases/21-mood-scaled-breaks-honest-rationale/21-01-SUMMARY.md` when done.
Record: the final mapping shipped, the exact test names added, the RED failure count observed at the
end of Task 1, and confirmation that `isLowMood` and all duration literals were left untouched.
</output>
