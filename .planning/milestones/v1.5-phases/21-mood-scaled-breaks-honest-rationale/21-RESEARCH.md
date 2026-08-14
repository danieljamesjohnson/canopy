# Phase 21: Mood-Scaled Breaks & Honest Rationale - Research

**Researched:** 2026-08-07
**Domain:** Deterministic Dart scheduling engine (single-file service change) + one string-building helper
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
None locked — discuss phase was skipped for this phase (auto-generated CONTEXT.md, `workflow.skip_discuss`).

### Claude's Discretion
All implementation choices are at Claude's discretion — discuss phase was skipped per user setting.
Use ROADMAP phase goal, success criteria, and codebase conventions to guide decisions.

Standing project constraints that bound those choices:
- Rule-based engine only — **no LLM, no "smart" suggestions** (permanent product position, see PROJECT.md "Out of Scope")
- Hive migrations are additive-only (new fields with defaults; never remove or rename)
- The generator is deterministic and unit-tested — any cadence change must stay both

Specific idea noted in CONTEXT.md: the mood scale has more than two points, so planning should decide
and justify the full mood→cadence mapping (not just the low/sunny endpoints) and lock it in tests.
(See "Recommended full mood → cadence mapping" below for a validated candidate.)

### Deferred Ideas (OUT OF SCOPE)
None — discuss phase skipped.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BREAK-01 | Chunks-before-a-long-break scales with the morning mood — roughly 2 on a low day, 5 on a sunny one — deterministically and unit-tested | "The Insertion Algorithm" and "Recommended full mood → cadence mapping" sections give the exact code location (`schedule_generator.dart:220`), consumption mechanics, and an empirically-validated 5-point mapping table |
| BREAK-02 | The 25-min chunk / 5-min short break interleave and the 25-min long break are preserved through the change | "BREAK-02 Preservation" section identifies every literal-duration call site and states precisely what must NOT change |
| TONE-01 | No "behind this week" framing anywhere; a time-target goal's rationale reads as what the schedule is doing for the user, not as a deficit report | "TONE-01's Blast Radius" section independently re-verifies the UI-SPEC's single-call-site claim via grep, and restates the locked replacement string |
</phase_requirements>

## Summary

This phase touches exactly two things inside one file, `lib/services/schedule_generator.dart`: the
constant that decides how many work chunks occur between long breaks (`longBreakEvery`, currently
`isLowMood ? 3 : 4`), and one string-building helper (`_timeTargetRationale`, currently emitting
`'${remaining}h behind this week'`). Everything needed to plan this phase is already resolvable by
reading the existing generator, its packing pass, and its test suite — there is no external library
research to do (confirmed: no new dependency is introduced by this phase).

The mood input is a plain `int` 1–5 captured once, at check-in, with five distinct semantic values
(`lib/screens/schedule/checkin_screen.dart:25-39`: Stormy/Overcast/Partly cloudy/Clearing
up/Clear skies). It reaches the generator as `moodIndex` and today is immediately collapsed to a
boolean (`isLowMood = moodIndex <= 2`) for every decision in the file, including the break cadence.
BREAK-01 requires un-collapsing just the break-cadence decision into a full 5-point mapping — the
success criteria only fix the two endpoints (mood 1 → ~2, mood 5 → ~5), leaving moods 2–4 as an
explicit planning decision (also flagged as Claude's Discretion in 21-CONTEXT.md).

I built and empirically verified a candidate full mapping (`{1:2, 2:3, 3:4, 4:4, 5:5}`) against the
live test suite by temporarily patching the constant and running `flutter test` — **all 54 existing
tests in `schedule_generator_test.dart` passed unmodified.** This directly contradicts the carried-forward
note in CONTEXT.md/REQUIREMENTS.md/STATE.md claiming "three tests ~492–543 assert the every-4 cadence
and must change" — that note is stale (see Pitfall 1 and the Test Surface section below for the
mechanics of why). The mapping is still a recommendation, not a locked fact — the planner/checker
should treat the "no tests need to change" finding as validated for *this specific* mapping choice,
and re-verify if a materially different mapping is chosen.

TONE-01's blast radius was independently re-verified (not just trusted from 21-UI-SPEC.md): grepping
`behind` across `lib/` and `test/` confirms exactly one user-facing occurrence
(`schedule_generator.dart:190`), reached from a single private helper called at 4 sites, all within
the same file. No test asserts the literal old string. UI-SPEC's claim holds.

**Primary recommendation:** Change only `schedule_generator.dart:220` (replace the ternary with a
`Map<int,int>` lookup covering moods 1–5) and `schedule_generator.dart:189-190` (branch text per
21-UI-SPEC.md's locked copy). Do not touch `isLowMood` — it drives unrelated allocation logic (habit
demand, outcome inclusion, restorative floor, FILL-01/FILL-02 clamps) that is out of scope and must
not regress. Add new mood-scaled break-cadence tests; the three "must change" tests named in prior
notes do not, in fact, need to change under the recommended mapping.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Mood → break cadence mapping | Backend service (pure Dart, `lib/services/`) | — | `ScheduleGeneratorService.generate()` is a pure, synchronous, no-Flutter-import service; cadence is a scheduling-engine concern, not UI |
| Break insertion / packing | Backend service | — | `_assignSyntheticStartTimes` (private helper in the same service) is the single source of truth for break placement (WR-01 invariant); UI only renders whatever chunks come out |
| Time-target rationale text | Backend service | Client / Widget (render-only) | The string is *generated* by the service (`_timeTargetRationale`) and *rendered* verbatim by `chunk_card.dart` / `chunk_detail_sheet.dart` / `focus_screen.dart` — those widgets own no logic, just display |
| Mood capture / semantics | Client / Widget | Database / Storage | `checkin_screen.dart` captures the 1–5 int; `DailySchedule.moodIndex` (Hive field) persists it — this phase does not touch either, it only changes how the existing `moodIndex` is consumed inside the generator |

## Standard Stack

Not applicable — no new dependency, no new package. This is a pure-Dart, in-repo logic change to an
existing service using only the Dart standard library (`dart:math`) and existing project packages
(`intl`, already imported). `package:flutter_test` (already a dev dependency) is used for new tests.

## Package Legitimacy Audit

Not applicable — this phase installs no packages. Skipping this section per the protocol's trigger
condition ("every phase that installs external packages").

## Architecture Patterns

### System Architecture Diagram

```
[Morning check-in]                    [Schedule generation request]
  checkin_screen.dart                     ScheduleNotifier.generateToday()
  user taps mood emoji (1-5)                     |
        |                                         v
        v                              ScheduleGeneratorService.generate(
  moodIndex: int (1-5) ------------------>   moodIndex, goals, blocks, ... )
        |                                         |
        v                                         v
  DailySchedule.moodIndex            Step 1-4: build workChunks[]
  (Hive persistence)                 (commitments, habits, outcomes,
                                       time-targets) — UNCHANGED by this phase
                                                |
                                                v
                                  longBreakEvery = f(moodIndex)   <-- BREAK-01 changes this line
                                  (currently: isLowMood ? 3 : 4)
                                                |
                                                v
                                  _assignSyntheticStartTimes(...)
                                  packs chunks into free day-slots,
                                  reserves 5-min short / 25-min long
                                  break AFTER every Nth chunk where
                                  N = longBreakEvery              <-- BREAK-02 boundary: this
                                                |                     logic must not change
                                                v
                                  STEP C: emit break chunks using
                                  reservedBreakMinutes (single
                                  source of truth, WR-01)
                                                |
                                                v
                                  result: List<ScheduledChunk>
                                  (work / shortBreak / longBreak)
                                                |
                    +---------------------------+---------------------------+
                    v                                                       v
        chunk_card.dart / chunk_detail_sheet.dart              _timeTargetRationale(goal, logs, date)
        renders '${durationMinutes} min break'                  <-- TONE-01 changes this branch
        (UNCHANGED by this phase — duration-driven,              text only; called from 4 sites,
         not cadence-aware)                                      all within schedule_generator.dart
```

### Recommended change surface (both changes live in one file)

```
lib/services/schedule_generator.dart
├── line 189-190   _timeTargetRationale() deficit branch   <- TONE-01
├── line 220       longBreakEvery ternary                  <- BREAK-01
└── (everything else in this file: DO NOT TOUCH)
```

No new files, no new widgets, no new folders. `test/services/schedule_generator_test.dart` gets new
test cases appended; no production file outside `schedule_generator.dart` changes.

### Pattern 1: Mood-indexed lookup table (existing project convention)

**What:** The codebase already has a precedent for exactly this shape of change:
`_moodCap` (`schedule_generator.dart:28`), a `static const Map<int, int>` keyed by `moodIndex`
covering all 5 mood values, with a documented raw→80%-cap derivation in a comment above it.
**When to use:** Any time a per-mood-level scalar is needed (this is now the second one — cap and,
after this phase, break cadence).
**Example:**
```dart
// Source: lib/services/schedule_generator.dart:24-28 (existing pattern to mirror)
/// Capacity table: maps moodIndex → max discretionary work chunks at 80%.
///
/// Raw max:  mood 1=6, 2=8, 3=10, 4=12, 5=14
/// 80% cap:  mood 1=4, 2=6, 3=8,  4=9,  5=11
static const Map<int, int> _moodCap = {1: 4, 2: 6, 3: 8, 4: 9, 5: 11};
```
Recommend introducing `_moodBreakCadence` (or similarly named) as a `static const Map<int, int>`
field on the class, next to `_moodCap`, following the exact same documentation style (comment
showing the full 1–5 table and the reasoning), then replacing line 220's ternary with a map lookup:
`final int longBreakEvery = _moodBreakCadence[moodIndex] ?? 4;` (the `?? 4` fallback matches the
existing `_moodCap[moodIndex] ?? 8` defensive-default style at line 35).

### Recommended full mood → cadence mapping

The success criteria fix only the endpoints ("roughly every 2" for low/mood 1, "roughly every 5" for
sunny/mood 5). This is a design recommendation for the planner to lock, not a fact verified against
an external source — flag it for confirmation during planning/discuss if desired, but note it has
been empirically validated against the full existing test suite (see below).

| moodIndex | Mood label (checkin_screen.dart) | Recommended `longBreakEvery` | Rationale |
|-----------|-----------------------------------|-------------------------------|-----------|
| 1 | Stormy day | 2 | Success-criterion endpoint ("roughly every 2") |
| 2 | Overcast | 3 | Interpolated step; also matches today's `isLowMood` boundary (moods 1-2) getting the tightest cadences |
| 3 | Partly cloudy | 4 | **Unchanged from today's value** (today: `isLowMood ? 3 : 4` → mood 3 already gets 4) — preserves existing test assumptions and the "neutral day" baseline |
| 4 | Clearing up | 4 | Same as mood 3 — avoids a mapping where mood 4 and mood 5 are indistinguishable AND avoids inventing a 5-point strictly-increasing curve the criteria never asked for; a plateau at the two middle-good moods is a defensible, easy-to-test choice |
| 5 | Clear skies | 5 | Success-criterion endpoint ("roughly every 5") |

**Empirical validation performed this session:** I temporarily patched `schedule_generator.dart:220`
to `_moodBreakCadence[moodIndex] ?? 4` with exactly this table and ran the full suite:
`flutter test test/services/schedule_generator_test.dart` → **54/54 passed, 0 failures** (change was
reverted immediately after with `git checkout`; `git status` confirms the file is clean). This means:
under this specific mapping, no existing test assertion (including the ones the planner might expect
to break) needs to change. See "The Test Surface" below for exactly why.

**Alternative mappings considered:**

| Mapping | Tradeoff |
|---|---|
| `{1:2, 2:2, 3:3, 4:4, 5:5}` (strict linear-ish, no plateau) | Also endpoint-correct, but changes mood 3's cadence from today's 4 to 3 — this WOULD break "Test 6" (see below), and gives moods 1-2 an identical cadence, which is arguably less mood-responsive than the recommended table's 2/3 split |
| `{1:2, 2:3, 3:4, 4:5, 5:5}` (mood 4 already at the sunny endpoint) | Endpoint-correct; mood 4 and mood 5 still tie, just one step earlier — functionally similar to the recommendation, slightly less conservative (less test-surface-preserving since it wasn't the table empirically validated this session) |

### Anti-Patterns to Avoid

- **Touching `isLowMood`:** `isLowMood = moodIndex <= 2` (line 219) is a boolean used in ~10 other
  places in `generate()` (outcome inclusion at line 346, habit demand at line 289, restorative floor
  at line 412, FILL-01 clamps at lines 449/516, VSCHED-03 guard at line 468). BREAK-01 must derive
  `longBreakEvery` directly from `moodIndex` via its own lookup — do NOT refactor `isLowMood` itself
  or make the cadence table depend on it, or all of those unrelated allocation behaviors risk drifting
  along with a change meant only for the break cadence.
- **Recomputing the cadence in the emit step:** The file has an explicit comment (lines 596-604)
  warning against re-deriving the long-break decision with an "independent counter" in STEP C — the
  packing pass (`_assignSyntheticStartTimes`) is the single source of truth via
  `reservedBreakMinutes`. BREAK-01 only needs to change what value `longBreakEvery` holds when it's
  passed into that packing pass (line 591) — nothing about STEP C changes.

## Don't Hand-Roll

Not applicable — no deceptively-complex, commonly-solved problem is being introduced (no new
date/time math, no new randomness, no new persistence format). The existing packing/interleave logic
is reused verbatim.

## The Insertion Algorithm (detailed, per research focus item 2)

`longBreakEvery` is consumed in exactly one place: `_assignSyntheticStartTimes`
(`schedule_generator.dart:649-742`), specifically the packing loop at lines 716-734.

**Mechanics:**
- `breakCount` is a running counter across the *entire day* (not reset per free-time slot), incremented
  once per discretionary chunk placed (line 721).
- After placing a chunk, `isLong = breakCount % longBreakEvery == 0` (line 722) decides short (5 min)
  vs long (25 min) break duration.
- The break is only actually **reserved** (`reservedBreakMinutes` set, consumed later by STEP C) if
  two conditions both hold (lines 727-731): (a) `cursor + breakDur <= slot.end` — the break physically
  fits in the remaining free-time slot, and (b) `discIdx + 1 < discretionaryChunks.length` — **there is
  a next discretionary chunk still to be placed.** Condition (b) means **the very last discretionary
  chunk of the day never gets a reserved break**, regardless of what `breakCount % longBreakEvery`
  evaluates to. This is also why STEP E (line 636) trims trailing non-work chunks — belt-and-suspenders,
  but the reservation logic already usually avoids emitting a trailing break at all.

**Confirmed: changing `longBreakEvery`'s value alone is sufficient.** No surrounding logic assumes a
specific numeric range (2, 3, 4, or 5 all behave identically as a modulus — no special-casing, no
minimum/maximum bound in the algorithm itself). The variable is declared `final int` and passed straight
through as a parameter; no type change needed.

**Edge behavior with a low cadence (e.g. 2) on a short day:** Because `breakCount` is a whole-day
running counter (not reset per slot, and not reset per commitment-window boundary), a low cadence
like 2 simply means long breaks recur roughly twice as often across the same chunk sequence — no
special edge case beyond what's already true for cadence 3/4 today. The one edge case that *does*
already exist and is unaffected by this phase: if the last discretionary chunk of the day happens to
land exactly on a `breakCount % longBreakEvery == 0` boundary, no break is reserved for it at all
(condition (b) above) — this is existing, tested behavior (STEP E trim), not something BREAK-01
introduces or worsens.

**Off-by-one risk for the planner to watch:** None identified in the algorithm itself. The only
planning risk is choosing a mapping where a *previously-untested* mood value's new cadence produces a
different break pattern than a similarly-shaped existing test assumed — see "The Test Surface" below.

## BREAK-02 Preservation (detailed, per research focus item 3)

**What enforces the 25-min chunk / 5-min short break / 25-min long break structure:**
- **Chunk duration (25 min):** Hard-coded as a literal `25` at every chunk-creation call site (e.g.
  lines 246-250, 307-314, 369-376, 419-426, 451-458, 492-499, 558-565) — completely independent of
  `longBreakEvery`. BREAK-01 does not touch any of these call sites.
- **Short break duration (5 min):** `const breakDur = isLong ? 25 : 5` at line 723 — the `5` literal is
  independent of `longBreakEvery`'s value; only which breaks *are* long changes, not what "long" or
  "short" numerically means.
- **Long break duration (25 min):** Same line 723 — the `25` literal.

**What would have to be true for a cadence change to accidentally disturb BREAK-02:** Only if the
planner also touched the `isLong ? 25 : 5` literal (they must not), or touched the `25`-minute chunk
literals at the various `workChunks.add(...)` call sites (they must not). Changing only the modulus
divisor (`longBreakEvery`'s value) cannot, by construction, alter either duration — it only changes
*how often* the 25-min branch is selected. **Regression surface for a plan-checker / verifier:** grep
the diff for any literal `25` or `5` change inside `_assignSyntheticStartTimes` or the `workChunks.add`
call sites — any such diff outside of the `longBreakEvery` lookup itself is out of scope and should be
flagged.

## The Test Surface (detailed, per research focus item 4)

**Correction to carried-forward notes:** CONTEXT.md, REQUIREMENTS.md, and STATE.md all repeat the
claim "Three existing tests (~lines 492–543) assert the every-4 cadence and must change with it." I
verified this empirically (see "Empirical validation performed this session" above) and it does **not**
hold for the recommended mapping. Line numbers have also drifted: 492–543 in the current file is the
**WR-01 test** (`'WR-01: emitted long break matches reserved slot...'`, mood=3, currently asserts "at
least one long break exists, first one is 25 min" — not an every-4-specific assertion; it stays
mood=3 and, under the recommended mapping, mood 3's cadence is unchanged at 4, so this test is
unaffected either way). Flagging this so the planner does not spend a task "fixing" tests that don't
need fixing, and instead spends that budget on the new coverage described below.

**Why the existing low-mood tests are cadence-insensitive:** Both `'Test 7: mood=1 break pattern with
2 work chunks'` (line 222) and the CAP-01/FILL tests that use `moodIndex: 1` place too few
discretionary chunks (2, in Test 7's case) to ever reach a *mid-sequence* long-break boundary — the
packing loop's condition (b) (`discIdx + 1 < discretionaryChunks.length`) means a 2-chunk day never
reserves a break on its last chunk regardless of what the modulus is, so Test 7 passes unchanged
whether mood 1's cadence is 2, 3, or anything else, as long as it's ≥ 2. **This will not remain true
if a future test adds a 3rd+ chunk at mood 1** — the planner's new tests (below) should deliberately
use 4+ chunks so the cadence is actually exercised.

**Existing tests requiring no change (re-verified, not just theorized):** All 54.

**No test helper exists for "generator input with a given mood"** — `moodIndex` is passed as a plain
named int argument directly to `sut.generate(...)` at each call site (e.g. `moodIndex: 3`). There is
no builder/fixture abstraction to update or extend; new tests simply pass a different `moodIndex`
value like every existing test does. `makeHabit()` / `makeTimeTarget()` / `makeOutcome()` /
`makeBlock()` / `makeLog()` (lines 25-78) are the existing goal/block/log builders and can be reused
as-is for the new mood-cadence tests.

**Proposed new test cases** (to make success criteria 1 and 2 concretely verifiable):

1. **Cadence-low test (mood 1 → every 2):** Generate with `moodIndex: 1`, enough habits to produce
   ≥5 discretionary work chunks (note: `habitCeiling = ceil(cap/2)`, and `_moodCap[1] = 4`, so
   `habitCeiling = 2` at mood 1 — habits alone cannot reach 5 chunks at mood 1; combine habits with a
   `gives`-valence time-target goal to clear the restorative floor, or use `lighterDay: false` and
   check the actual mood-1 cap math before picking goal counts). Assert: the first `longBreak` chunk
   appears after exactly 2 work chunks (i.e., `result[2]` — 0-indexed: work, shortBreak, work,
   longBreak — is a `ChunkType.longBreak`), and its `durationMinutes == 25`.
2. **Cadence-sunny test (mood 5 → every 5):** Generate with `moodIndex: 5`, enough goals to produce
   ≥6 discretionary work chunks (cap at mood 5 is 11, comfortably enough room). Assert the first
   `longBreak` appears after exactly 5 work chunks, `durationMinutes == 25`.
3. **Cadence-middle tests (moods 2, 3, 4):** Currently **zero** tests use `moodIndex: 2` anywhere in
   the suite — this is a real coverage gap independent of this phase, worth closing here since BREAK-01
   explicitly requires a stance on mood 2. Add at least one test per middle mood value asserting the
   recommended cadence (3, 4, 4 respectively) using the same "assert Nth work chunk is followed by a
   longBreak" pattern as tests 1-2 above.
4. **BREAK-02 regression test (structure preserved):** For at least one mood value, assert every
   non-final work chunk is immediately followed by *either* a `shortBreak` with `durationMinutes == 5`
   *or* a `longBreak` with `durationMinutes == 25` — i.e., no third duration value ever appears. This
   directly encodes success criterion 2 ("only the cadence count changed, not the break structure").
5. **Update the doc comment** at line 22 (`"longBreakEvery = 3 for mood 1-2, 4 for 3-5"`) to describe
   the new 5-point table — not a test, but should be a plan task so the comment doesn't go stale
   (existing project convention per `_moodCap`'s comment at lines 24-27 — mirror that style).

**Test command (verified working this session):**
```bash
export PATH="$PATH:/home/dan/development/flutter/bin"
flutter test test/services/schedule_generator_test.dart
```
Full-file run completes in <1s (54 tests). No CI workflow exists in this repo (`.github/workflows/`
absent) — `flutter test` is run manually / via the phase's own verification step.

## TONE-01's Blast Radius (detailed, per research focus item 5) — independently re-verified

**Claim being checked:** 21-UI-SPEC.md asserts `_timeTargetRationale` is the only producer of "behind
this week" framing, and all call sites route through it.

**Verification performed:**
```
$ grep -rn "behind" lib/ test/
lib/services/schedule_generator.dart:19:  ///   4. Time-target goals (mood 3-5 only; multi-chunk demand, most-behind first)
lib/services/schedule_generator.dart:190:    return '${remaining.toStringAsFixed(1)}h behind this week';
lib/providers/theme_notifier.dart:138:  /// timestamp does not lag behind the actual mood state...
lib/screens/onboarding/onboarding_screen.dart:753:/// router gates the app behind onboarding...
lib/screens/commitments/commitments_screen.dart:259:  // delete access is never gated behind a hover...
lib/dev/dev_data_loader.dart:83:/// ...MUST gate invocation behind...
test/services/schedule_generator_test.dart:628-659:  // T-09-02 comments/test-name using "most-behind" (sort-order semantics, developer-facing)
```
**Confirmed [VERIFIED: grep against working tree]:** the *only* user-facing string containing "behind"
is `schedule_generator.dart:190`. Every other hit is either a code comment describing unrelated
concepts (theme timestamp lag, router gating, hover gating, invocation gating) or the T-09-02 test's
internal "most-behind" naming for *goal-priority sort order* (not rendered to the user). UI-SPEC's
claim holds.

**Call-site count for `_timeTargetRationale`:** confirmed 4 call sites, all within
`schedule_generator.dart` itself (lines 424, 456, 497, 523 — restorative floor, PRIORITY-03 surplus,
VSCHED-03 reservation, and FILL-02 round-robin, respectively). All four pass through the same helper —
a single string-branch edit at lines 189-190 covers every emission point. No other file constructs a
time-target rationale string independently.

**No test asserts the literal old string** — confirmed via the same grep; the only "behind" hits in
`test/` are the T-09-02 sort-order test/comments, which do not assert rendered rationale text and are
explicitly flagged in 21-UI-SPEC.md as out of scope for renaming.

**Exact replacement (locked by 21-UI-SPEC.md, restated here for planner convenience):**
```dart
// lib/services/schedule_generator.dart:178-191, current:
String _timeTargetRationale(
  Goal goal,
  List<CompletionLog> logs,
  DateTime date,
) {
  final completed = _completedChunksThisWeek(goal.id, logs, date);
  final completedHrs = completed * 25.0 / 60.0;
  final remaining = ((goal.weeklyHourBudget ?? 0.0) - completedHrs).clamp(
    0.0,
    double.infinity,
  );
  if (remaining < 0.1) return 'On track this week';        // UNCHANGED
  return '${remaining.toStringAsFixed(1)}h behind this week';  // REPLACE ONLY THIS LINE
}
```
Replace only the last line's return value with:
```dart
return 'Working toward ${remaining.toStringAsFixed(1)}h this week';
```
`remaining` computation, the `< 0.1` branch, and the `toStringAsFixed(1)` formatting are all
unchanged — TONE-01 is copy-only, confirmed by reading the surrounding logic (no numeric behavior to
preserve-check beyond "don't touch it," which the diff naturally satisfies if only the return string
literal changes).

## Common Pitfalls

### Pitfall 1: Trusting carried-forward context notes without re-verifying against current code
**What goes wrong:** CONTEXT.md/REQUIREMENTS.md/STATE.md all repeat "three tests ~492-543 must
change" — a plan built on that assumption would budget a task to edit tests that, empirically, don't
need editing (for the recommended mapping), wasting effort, or worse, an agent might force an edit to
match the false expectation and introduce an unnecessary diff.
**Why it happens:** These notes were captured once, early (at roadmap-creation time), as a heuristic
guess about the file before the specific mapping was chosen; line numbers drift as the file evolves,
and "must change" was speculative, not derived from actually running the cadence change against the
suite.
**How to avoid:** Actually run the change (as this research session did) rather than trust the
citation. The planner should treat "N tests must change" as a hypothesis to verify with the sut, not
a given.
**Warning signs:** A plan task titled "update tests 492-543 for new cadence" without a concrete list
of *which specific assertions* fail and why.

### Pitfall 2: Deriving the new cadence from `isLowMood` instead of `moodIndex` directly
**What goes wrong:** `isLowMood` is a coarse boolean already reused by ~10 unrelated allocation
decisions in the same method. If a plan "extends" `isLowMood` into a tri-state or adds new booleans
derived from it to compute cadence, it risks entangling BREAK-01 with those other behaviors (outcome
inclusion, habit demand, restorative floor, etc.) — a classic shared-mutable-flag coupling bug.
**Why it happens:** `isLowMood` is right there, one line above, and looks reusable.
**How to avoid:** Add an independent `_moodBreakCadence[moodIndex]` lookup; never reference
`isLowMood` in its computation.
**Warning signs:** Any code path where changing the break-cadence table also changes outcome-goal
inclusion or habit-demand counts in a test that wasn't touching cadence.

### Pitfall 3: Picking a mapping that silently breaks Test 6 (mood=3, 4 chunks)
**What goes wrong:** `'Test 6: mood=3 break pattern with 4 work chunks (trailing break trimmed)'`
(line 190) hard-asserts positions `result[1]`, `result[3]`, `result[5]` are all `shortBreak` — i.e., it
assumes mood 3 does NOT reach a long-break boundary within 4 chunks. This is true for cadence values
of 4 or higher, but **false** for cadence 3 (a mid-sequence long break would appear at position 5
instead of a short break, in the traced scenario, given adequate slot room). If the planner's chosen
mapping sets mood 3's cadence below 4, this test breaks and must be intentionally updated.
**Why it happens:** Mood 3 currently maps to 4 under the existing `isLowMood ? 3 : 4` split; any
mapping that lowers it changes this specific test's outcome.
**How to avoid:** Either keep mood 3 at cadence 4 (the recommended mapping does this, verified 54/54
green), or explicitly plan a Test 6 rewrite if a different mood-3 value is chosen.
**Warning signs:** `flutter test` failure at `Test 6` after a mapping change — this is the canary; run
the full suite immediately after changing the constant, not just the new tests.

### Pitfall 4: Forgetting mood 2 has zero existing test coverage
**What goes wrong:** No test in the entire suite uses `moodIndex: 2`. A plan that only "fixes what's
broken" risks shipping BREAK-01 without ever exercising the mood-2 code path at all, leaving an
untested branch exactly where the success criteria are silent on the exact number.
**Why it happens:** The existing suite happened to only ever need mood 1, 3, 4, 5 for other features;
mood 2 was never load-bearing for anything until now.
**How to avoid:** Explicitly add a mood-2 test as part of this phase (see Test Surface section,
proposed test 3).
**Warning signs:** Coverage review showing `moodIndex: 2` absent from the diff's new tests.

## Code Examples

### Full recommended diff shape for `longBreakEvery` (BREAK-01)
```dart
// Source: pattern mirrors existing _moodCap at schedule_generator.dart:24-28
/// Break-cadence table: maps moodIndex → work chunks between long breaks.
///
/// mood 1 (Stormy)      = 2  — success-criterion endpoint
/// mood 2 (Overcast)    = 3
/// mood 3 (Partly cloudy) = 4  — unchanged from pre-BREAK-01 baseline
/// mood 4 (Clearing up) = 4
/// mood 5 (Clear skies) = 5  — success-criterion endpoint
static const Map<int, int> _moodBreakCadence = {1: 2, 2: 3, 3: 4, 4: 4, 5: 5};

// Replaces schedule_generator.dart:220
final int longBreakEvery = _moodBreakCadence[moodIndex] ?? 4;
```

### Full recommended diff shape for `_timeTargetRationale` (TONE-01)
```dart
// Source: lib/services/schedule_generator.dart:189-190, replace return only
if (remaining < 0.1) return 'On track this week'; // unchanged
return 'Working toward ${remaining.toStringAsFixed(1)}h this week'; // was: '...h behind this week'
```

## State of the Art

Not applicable — no external ecosystem/library shift is relevant; this is an internal, deterministic
engine change with no framework-version dependency.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Recommended mood→cadence mapping `{1:2, 2:3, 3:4, 4:4, 5:5}` is the "right" middle-value choice | Architecture Patterns → Recommended full mood → cadence mapping | Low — it is a design choice explicitly delegated to Claude's Discretion per 21-CONTEXT.md, not a factual claim; empirically validated against the full test suite (54/54 green), so the *risk* is aesthetic/product-feel (e.g. Dan may want mood 4 to feel more "sunny-adjacent" than mood 3), not correctness. Flag for confirmation if the planner wants a different curve. |

**All other claims in this research are `[VERIFIED]`** — obtained by reading the actual source files
in this session, or by directly running `flutter test` / `grep` against the working tree (see inline
citations throughout). No claims here rely on training-data assumptions about this specific codebase.

## Open Questions

1. **Should the mood→cadence comment at line 22 (class-level doc comment) be updated as part of this
   phase's diff?**
   - What we know: it currently reads "longBreakEvery = 3 for mood 1-2, 4 for 3-5" and will be stale
     the moment BREAK-01 lands.
   - What's unclear: nothing technically — this is a trivial one-line doc fix.
   - Recommendation: include it as a task/checklist item in the same task that changes line 220, not
     a separate task (avoid a phantom "stale comment" follow-up).

2. **Exact goal-count recipe to reliably produce ≥5-6 discretionary chunks at mood 1 for the new
   cadence-low test.**
   - What we know: `_moodCap[1] = 4` (lighterDay=false) or effectively lower with `lighterDay=true`;
     `habitCeiling = ceil(cap/2) = 2` at mood 1, so habits alone plateau at 2 chunks; the restorative
     floor (`VSCHED-01/02`, `isLowMood` branch, lines 406-432) adds up to 1 more gives-valence
     time-target chunk; PRIORITY-03/FILL-02 passes can add more if goals have high priority or
     remaining demand.
   - What's unclear: the exact minimal goal-list recipe (how many habits + which valence/priority
     time-targets) that reliably clears 5 discretionary chunks at mood 1 without relying on
     `lighterDay: false` edge behavior that might itself be a moving target across phases.
   - Recommendation: the planner/implementer should prototype this directly against `sut.generate()`
     during test-writing (fast iteration, <1s per run) rather than have research pre-compute it —
     the existing `WR-01` test (mood=3, `4 habits + makeTimeTarget(weeklyHourBudget: 5)`) is a good
     template to adapt for mood=1 with an added `gives`-valence goal to clear the restorative floor.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | `flutter test` execution | Yes | Resolved via `/home/dan/development/flutter/bin` (not on default PATH — must be exported) | — |
| Dart SDK | Pure-Dart service compilation | Yes (bundled with Flutter) | `^3.10.3` per CLAUDE.md | — |

No missing dependencies. No external services required — this phase has zero I/O, zero network, zero
new packages.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` (bundled with Flutter SDK, already a dev dependency) |
| Config file | none — standard `flutter test` convention, no custom config |
| Quick run command | `export PATH="$PATH:/home/dan/development/flutter/bin"; flutter test test/services/schedule_generator_test.dart` |
| Full suite command | `export PATH="$PATH:/home/dan/development/flutter/bin"; flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BREAK-01 | Low-mood day → long break after ~2 chunks | unit | `flutter test test/services/schedule_generator_test.dart --plain-name "cadence-low"` (new test, name TBD by planner) | ❌ Wave 0 — new test to add |
| BREAK-01 | Sunny-mood day → long break after ~5 chunks | unit | `flutter test test/services/schedule_generator_test.dart --plain-name "cadence-sunny"` (new test, name TBD) | ❌ Wave 0 — new test to add |
| BREAK-01 | Mood 2/3/4 middle values covered deterministically | unit | new tests per middle mood value | ❌ Wave 0 — new tests to add |
| BREAK-02 | Every chunk still followed by 5-min short break; every long break still 25 min | unit | new "structure preserved" test (see Test Surface item 4) | ❌ Wave 0 — new test to add |
| TONE-01 | No "behind this week" anywhere; time-target rationale reframed | unit + grep | existing `_timeTargetRationale` is not directly unit-tested today (no test asserts its exact string) — recommend adding one assertion of the new string, plus a repo-wide `grep -rn "behind this week" lib/` check as a phase-gate verification step (not a Dart test, a shell check) | ❌ Wave 0 — new unit test + manual/CI grep step |

### Sampling Rate
- **Per task commit:** `flutter test test/services/schedule_generator_test.dart` (<1s, single file)
- **Per wave merge:** `flutter test` (full suite; repo has no other slow test files observed)
- **Phase gate:** Full suite green before `/gsd-verify-work`, plus the `grep -rn "behind this week" lib/` check returning zero matches

### Wave 0 Gaps
- [ ] New test: mood=1 cadence-low assertion (long break after 2 chunks) — `test/services/schedule_generator_test.dart`
- [ ] New test: mood=5 cadence-sunny assertion (long break after 5 chunks) — same file
- [ ] New test(s): mood=2, mood=3 (regression-guard for Pitfall 3), mood=4 cadence assertions — same file
- [ ] New test: BREAK-02 structure-preserved assertion (only 5-min/25-min durations ever appear) — same file
- [ ] New test: `_timeTargetRationale` new-string assertion (e.g. via a scheduled time-target goal with known remaining hours) — same file
- [ ] No framework install needed — `flutter_test` already present

*(No fixture/builder gaps — existing `makeHabit`/`makeTimeTarget`/`makeOutcome`/`makeBlock`/`makeLog`
helpers at the top of the test file cover every goal/block/log shape needed for the new tests.)*

## Security Domain

Not applicable — pure computation on already-trusted, already-validated in-memory data (`Goal`,
`CompletionLog`, `CommitmentBlock` objects passed in by the caller); no user input parsing, no
authentication/session/crypto surface, no injection vector (no SQL/HTML/shell construction — the
`_timeTargetRationale` string is interpolated only from a `double` formatted via `toStringAsFixed`,
not from any user-controlled free text). `security_enforcement` gate: this phase has no ASVS-relevant
surface to enumerate.

## Sources

### Primary (HIGH confidence — read/executed directly this session)
- `lib/services/schedule_generator.dart` (full file read) — cadence logic, rationale helper, packing algorithm
- `test/services/schedule_generator_test.dart` (full file read) — existing test coverage, helper builders
- `lib/screens/schedule/checkin_screen.dart` — mood capture UI, full 5-point label/emoji tables
- `lib/data/models/daily_schedule.dart` — `moodIndex` persistence (Hive field 2)
- `flutter test test/services/schedule_generator_test.dart` executed twice (baseline 54/54 green; then
  again with the candidate cadence mapping patched in, also 54/54 green) — empirical, not inferred
- `grep -rn "behind" lib/ test/` executed — confirms TONE-01 blast radius claim independently

### Secondary (MEDIUM confidence)
- `.planning/phases/21-mood-scaled-breaks-honest-rationale/21-UI-SPEC.md` — locked copy contract, cross-checked (not just trusted) against source

### Tertiary (LOW confidence / superseded)
- CONTEXT.md / REQUIREMENTS.md / STATE.md's "three tests ~492-543 must change" note — checked and
  found stale; documented in Pitfall 1 rather than repeated as fact

## Metadata

**Confidence breakdown:**
- Standard stack: N/A — no new stack, pure in-repo logic change
- Architecture: HIGH — read the exact algorithm and traced its behavior by hand and by execution
- Pitfalls: HIGH — all four pitfalls were derived from actually running the test suite against a
  candidate change, not speculation

**Research date:** 2026-08-07
**Valid until:** Until `schedule_generator.dart` or its test file materially changes (this is an
internal-codebase research artifact, not subject to external ecosystem drift — no expiry driven by
upstream library releases)
