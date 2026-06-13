---
phase: 15-engine-honesty
verified: 2026-06-13T22:30:00Z
status: human_needed
score: 5/5
overrides_applied: 0
human_verification:
  - test: "Generate a schedule for a low-mood day with 4+ daily habits and at least one outcome goal. Open the goal card for the outcome goal."
    expected: "The outcome goal appears in the generated schedule with at least one chunk, confirming that habits did not monopolize the discretionary cap."
    why_human: "The generated schedule is the user-facing surface. The unit test proves the engine logic (CAP-01 ceiling), but only a real app run confirms the UI renders the chunk and does not suppress it through a display filter."
  - test: "Open a goal card for a habit you have completed on at least two consecutive due days. Observe the streak number displayed."
    expected: "The displayed streak count matches what a manual backward walk over due-days would compute — e.g., if you completed Mon and Wed and today is Thu (not a due day), the card shows 2."
    why_human: "Streak display correctness requires confirming that the UI reads the persisted streakCount field (updated by the generation-time write-back) and that no intermediate display layer shows a cached stale value."
  - test: "On a day with open capacity after habits, verify that a regular-time (time-target) goal appears in the generated schedule."
    expected: "At least one chunk from a time-target goal appears in the generated schedule even when mood is low (mood 1-2)."
    why_human: "FILL-01 removes the !isLowMood gate. Unit tests prove the engine places the chunk. Human check confirms the schedule screen renders it and doesn't hide it in a filtered section."
---

# Phase 15: Engine Honesty Verification Report

**Phase Goal:** The scheduling engine allocates capacity fairly, counts streaks truthfully, and uses the full day — so the generated schedule reflects reality rather than an artifact of processing order.
**Verified:** 2026-06-13T22:30:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | CAP-01: On a low-mood day (mood 1), outcome and time-target goals receive chunks even when habits are also scheduled — no single goal type monopolizes the discretionary cap. | VERIFIED | `habitCeiling = (cap / 2).ceil()` at schedule_generator.dart:262 enforces a hard ceiling. Two deterministic tests pass: `CAP-01: mood=1, 4 daily habits + 1 outcome → outcome receives ≥1 chunk` and `CAP-01: mood=1 total work chunks do not exceed cap`. Observed test output: 2/2 PASS. |
| 2 | STREAK-01: A goal's streak shown in the UI matches what a manual backward walk over due-days would compute — no divergence possible. | VERIFIED | `computeStreak()` static method at schedule_generator.dart:78 performs a calendar backward walk. Generation-time write-back loop at schedule_notifier.dart:149–169 calls `computeStreak` and persists via `_goalRepo.save` only when value differs. STREAK-01 test passes: `goalRepo.saved.last.streakCount == 2` after generateToday with two prior completions. Full backward-walk unit test T-09-WR02 and T-09-WR02b also pass. |
| 3 | PRIORITY-02: Raising a habit's priority increases its chunk allocation; raising an outcome's priority increases its chunk allocation — relative to lower-priority counterparts at mood 3. | VERIFIED | `habitDemand()` at schedule_generator.dart:267–268 returns 2 for priorityWeight >= 0.75 on non-low-mood days. `outcomeDemand` inline at schedule_generator.dart:335–336 applies same rule. Two PRIORITY-02 tests pass: habit variant (`highCount > normalCount`) and outcome variant (`highCount > normalCount`). |
| 4 | FILL-01: On a day with open capacity after required work and habits, regular-time (time-target) goals appear in the schedule rather than leaving the day empty. | VERIFIED | Step 4 in schedule_generator.dart:353–420 runs unconditionally (no `!isLowMood` gate). Low-mood per-goal demand is capped at 1 via `isLowMood ? rawDemand.clamp(0, 1) : rawDemand`. FILL-01 test passes: `ttChunks >= 1` at mood=1 with 2 habits and 1 time-target. |
| 5 | FILL-02: When multiple regular-time goals compete for open slots, higher-priority goals receive more chunks and no single goal claims the entire open day. | VERIFIED | Round-robin `while (anyPlaced && discretionaryCount < cap)` loop at schedule_generator.dart:397–420, with a PRIORITY-03 surplus pass (lines 377–394) giving high-priority time-targets one extra chunk before round-robin begins. FILL-02 test passes: `g3 >= 1` and `g1 <= totalWorkChunks - 1`. The existing Phase 14 test `Step 4: high-priority time-target goal gets strictly more chunks` also passes, confirming the high-priority surplus (4 chunks vs 2) under the new implementation. |

**Score:** 5/5 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/services/schedule_generator.dart` | habitCeiling reservation, habitDemand function, outcome multi-chunk demand, always-run round-robin time-target allocation | VERIFIED | `habitCeiling` at line 262, `habitDemand` at lines 267–268, `outcomeDemand` at lines 335–336, round-robin Step 4 at lines 353–420. Contains `habitCeiling`, `placedCountPerGoal`. No stubs. |
| `test/services/schedule_generator_test.dart` | CAP-01, PRIORITY-02, FILL-01, FILL-02 deterministic engine tests | VERIFIED | Tests with CAP-01, PRIORITY-02, FILL-01, FILL-02 banner labels found at lines 1167–1375. All carry `reason:` strings with requirement IDs. |
| `lib/providers/schedule_notifier.dart` | generation-time streakCount sync loop in generateToday() | VERIFIED | Streak write-back loop at lines 149–169. Iterates active habit goals after `_generator.generate()`. Contains `ScheduleGeneratorService.computeStreak` call and `_goalRepo.save(goal)`. No-op guard and try/catch present. |
| `test/providers/schedule_notifier_engine_test.dart` | STREAK-01 generation-time sync test | VERIFIED | STREAK-01 group at lines 353–431. Tests that `goalRepo.saved.last.streakCount == 2` after generateToday with stale stored value of 0. |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| schedule_generator.dart Step 2 | discretionaryCount / cap | `habitCeiling = (cap / 2).ceil()` guard | WIRED | Lines 262–263: `final int habitCeiling = (cap / 2).ceil(); int habitCount = 0;`. Inner loop breaks on both `habitCount >= habitCeiling` (line 285) and `discretionaryCount >= cap` (line 284). |
| schedule_generator.dart Step 4 | timeTargetGoals | round-robin `placedCountPerGoal` loop (no `!isLowMood` gate) | WIRED | `placedCountPerGoal` declared at line 377. Round-robin while loop at lines 397–420. No `if (!isLowMood)` gate wrapping Step 4. |
| schedule_notifier.dart generateToday() | goal.streakCount (Hive field) via _goalRepo.save | ScheduleGeneratorService.computeStreak write-back after _generator.generate() | WIRED | Lines 149–169: loop after generate() call (line 130), before _repo.save(schedule) (line 183). Pattern `streakCount = ScheduleGeneratorService.computeStreak` present as `computed = ScheduleGeneratorService.computeStreak(...)` + `goal.streakCount = computed` at lines 156–163. |

---

### Data-Flow Trace (Level 4)

Not applicable — the artifacts are pure scheduling logic (engine methods and a persistence notifier). The unit tests directly assert the data values produced. No UI component rendering dynamic data was introduced in this phase.

---

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| CAP-01 tests pass | `flutter test --name "CAP-01"` | 2/2 PASS | PASS |
| PRIORITY-02 tests pass | `flutter test --name "PRIORITY-02"` | 2/2 PASS | PASS |
| FILL-01 test passes | `flutter test --name "FILL-01"` | 1/1 PASS | PASS |
| FILL-02 test passes | `flutter test --name "FILL-02"` | 1/1 PASS | PASS |
| STREAK-01 test passes | `flutter test --name "STREAK-01"` (notifier test) | 1/1 PASS | PASS |
| Full suite regression | `flutter test` (221 tests) | 221/221 PASS | PASS |
| Static analysis | `flutter analyze` on modified files | No issues | PASS |

---

### Probe Execution

Step 7c: SKIPPED — no `scripts/*/tests/probe-*.sh` files found. Phase used `flutter test` as its verification mechanism (confirmed above).

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| CAP-01 | 15-01-PLAN.md | Habits cannot consume entire discretionary cap before outcomes/time-targets | SATISFIED | `habitCeiling = (cap/2).ceil()` implemented; 2 unit tests pass |
| STREAK-01 | 15-02-PLAN.md | Displayed streak equals backward due-day walk — no divergence | SATISFIED | computeStreak write-back in generateToday(); STREAK-01 unit test passes |
| PRIORITY-02 | 15-01-PLAN.md | Priority changes chunk count for habits and outcomes, not just sort order | SATISFIED | `habitDemand` and `outcomeDemand` multi-chunk functions; 2 unit tests pass |
| FILL-01 | 15-01-PLAN.md | Time-target goals fill open capacity even on low-mood days | SATISFIED | Step 4 runs unconditionally; FILL-01 unit test passes |
| FILL-02 | 15-01-PLAN.md | Open capacity distributed across regular-time goals; no monopoly | SATISFIED | Round-robin + PRIORITY-03 surplus; FILL-02 unit test passes |

No orphaned requirements found. All 5 IDs (CAP-01, STREAK-01, PRIORITY-02, FILL-01, FILL-02) appear in plan frontmatter and are traced to REQUIREMENTS.md entries (all marked Complete in the Traceability table at REQUIREMENTS.md line 60–68).

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | - | - | - | No TBD/FIXME/XXX markers found. No stub returns (return null / return [] / return {}). No hardcoded-empty props found. |

No debt markers of any kind detected in the four modified files.

---

### Post-Plan Deviation: PRIORITY-03 Surplus Pass

The original 15-01 PLAN specified only a round-robin to implement FILL-02. A post-execution code review (commit `bbe1b8c`) added a PRIORITY-03 surplus pass before the round-robin, giving time-target goals with `priorityWeight >= 0.75` one extra chunk. This:

- Does **not** break FILL-02: the `g1 <= totalWorkChunks - 1` and `g3 >= 1` assertions still pass against three equal-priority goals (no goal has 0.75 weight in that test).
- Strengthens success criterion 5 from "distributed proportionally" to "strictly more chunks for high-priority" — the Phase 14 regression test uses `greaterThan` (not `greaterThanOrEqualTo`) after this commit, and still passes.
- Is consistent with REQUIREMENTS.md PRIORITY-02 wording ("higher-priority goals receive more chunks").

This deviation improves fidelity to the requirement and causes no regression.

---

### Human Verification Required

Three items need in-app confirmation that the engine-level fixes surface correctly through the UI:

#### 1. CAP-01 — Outcome visible in low-mood schedule

**Test:** Set mood to 1 (or 2) in the app. Ensure you have 4+ daily habits and at least one outcome goal with a near-term deadline. Generate today's schedule.
**Expected:** The outcome goal appears in the schedule with at least one work chunk — it is not crowded out by habits.
**Why human:** The unit test proves the engine allocation. A human check confirms no UI filter (e.g., the schedule screen's section grouping or `!c.isSkipped` partition) hides the outcome chunk.

#### 2. STREAK-01 — Displayed streak matches backward walk

**Test:** Open a habit goal card after generating today's schedule (without having marked anything complete today yet). The card should show the streak value. Manually count backward through its completion history.
**Expected:** The displayed streak exactly matches the backward-walk count from the most recent due day.
**Why human:** The notifier writes `streakCount` to Hive and the unit test asserts the value. A human check confirms the goal card's streak display reads from that Hive field (and not a stale cached value from before generation).

#### 3. FILL-01 — Time-target goal appears on a low-mood schedule

**Test:** On a low-mood day (mood 1), generate a schedule that includes at least one time-target (regular-time) goal with remaining weekly budget. Observe the schedule screen.
**Expected:** At least one chunk from the time-target goal appears in the schedule list, even on a low-mood day.
**Why human:** FILL-01 removes a code gate. The schedule screen's section partitioning or display filters could theoretically suppress these chunks. A live run confirms end-to-end rendering.

---

### Gaps Summary

No gaps. All 5 must-have truths are verified against the codebase, all 4 artifacts are substantive and wired, all key links are confirmed present, no anti-patterns were found, and the full 221-test suite is green. Three human verification items remain for UI surface confirmation — these are confirmation checks, not gap indicators.

---

_Verified: 2026-06-13T22:30:00Z_
_Verifier: Claude (gsd-verifier)_
