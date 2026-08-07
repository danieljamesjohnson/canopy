---
phase: 22-unified-today-screen
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/screens/today/now_state.dart
  - lib/screens/today/timeline.dart
  - lib/screens/home/home_screen.dart
  - test/screens/home_screen_now_state_test.dart
  - test/screens/active_chunk_card_test.dart
  - test/screens/today_timeline_model_test.dart
autonomous: true
requirements: [UNIFY-01]
must_haves:
  truths:
    - "resolveNowState and the NowState sealed class live in a standalone file with zero widget dependencies, importable without pulling in a screen"
    - "A pure function turns the day's chunks plus a NowState into an ordered row list that names free time and marks exactly one live row"
    - "The row list's live row is derived ONLY from the injected NowState — the list never re-detects 'now' from the clock"
    - "Gaps of 10 minutes or more become named free rows; shorter gaps are suppressed"
    - "The suite stays green after the relocation, and flutter analyze stays clean"
  artifacts:
    - path: "lib/screens/today/now_state.dart"
      provides: "NowState sealed hierarchy (PreStart/Active/Overdue/GapBeforeNext/DayComplete) + resolveNowState, moved verbatim from home_screen.dart"
      contains: "NowState resolveNowState"
      min_lines: 150
    - path: "lib/screens/today/timeline.dart"
      provides: "TimelineRow sealed hierarchy (ChunkRow/LeadingFreeRow/GapFreeRow) + buildTimeline pure function + kMinGapMinutes"
      contains: "buildTimeline"
      min_lines: 90
    - path: "test/screens/today_timeline_model_test.dart"
      provides: "Unit coverage for buildTimeline including the Phase 17 regression guard"
      contains: "buildTimeline"
  key_links:
    - from: "lib/screens/today/timeline.dart"
      to: "lib/screens/today/now_state.dart"
      via: "buildTimeline takes NowState and reads the live chunk id from it"
      pattern: "required NowState nowState"
    - from: "lib/screens/home/home_screen.dart"
      to: "lib/screens/today/now_state.dart"
      via: "import — home_screen no longer declares the state machine"
      pattern: "today/now_state.dart"
---

<objective>
Extract the now-state machine out of `home_screen.dart` into its own file, and add the pure
timeline model that the merged screen will render. This plan contains NO widget code — it is the
data spine of the merge and the structural fix for 22-PATTERNS.md's highest-risk finding.

Purpose: `schedule_screen.dart` currently carries a SECOND, older "now" detector
(`_buildActiveChunkItems`, lines 203-244) that scans for the first unresolved chunk — the exact
bug Phase 17 wrote `resolveNowState` to fix. If the merge keeps schedule_screen's list-building
code and bolts the live card on top, the merged screen ends up with two disagreeing detectors.
`buildTimeline` makes that impossible by construction: it does not know what time it is. It is
handed a NowState and marks the live row from that, or from nothing.

Output: `lib/screens/today/now_state.dart` (relocated, unchanged logic),
`lib/screens/today/timeline.dart` (new pure model), unit tests for the model, and repointed
imports in the two test files that reach into `home_screen.dart` for the state machine.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/22-unified-today-screen/22-CONTEXT.md
@.planning/phases/22-unified-today-screen/22-UI-SPEC.md
@.planning/phases/22-unified-today-screen/22-PATTERNS.md

@lib/screens/home/home_screen.dart
@lib/screens/schedule/schedule_screen.dart
@lib/data/models/scheduled_chunk.dart
@test/screens/home_screen_now_state_test.dart
</context>

<decision_ids>
22-CONTEXT.md states its locked decisions as a numbered list under "LOCKED by design review".
This plan set refers to them as **D-01 through D-07** in list order, plus **D-08 / D-09** for the
two items under "Navigation — the risk item":

| ID | Locked decision |
|----|-----------------|
| D-01 | Inline timeline — one scrollable list, current row swells in place, no hero, no separate "now" card |
| D-02 | The list auto-scrolls the current row to centre on open |
| D-03 | No sticky recall bar (sketch variant B rejected) |
| D-04 | No time rail / gutter chrome (sketch variant C rejected) |
| D-05 | Free time is named, never collapsed; gaps of about 10 minutes or more get their own quiet rows |
| D-06 | Row vocabulary: completed struck through and dimmed with a check, skipped dimmed and labelled "skipped", breaks dashed and lighter, commitments tertiaryContainer, time in a left gutter in mono at ~46px |
| D-07 | Mood theming inherited from the existing mood-seeded ColorScheme; no new palette |
| D-08 | `/schedule` kept as a redirect to the unified route; main.dart:86 (notification tap) must land on the working screen; home_screen.dart:495 "see full schedule" is removed |
| D-09 | Shell drops four destinations to three; update the UI-SPEC note rather than silently violating it |

**D-04 vs D-06 — do not confuse these.** D-04 rejects sketch variant C's vertical *rail*
(connector lines, decorative gutter chrome). D-06 *requires* variant A's ~46px monospace left
column holding the row's start time. A 46dp text gutter is in scope; a rail is not.

**Planner choices for the two items CONTEXT.md deliberately left open:**
- Merged destination: label **"Today"**, route **`/today`**, source directory
  **`lib/screens/today/`**, shell icon `Icons.today_outlined`. One word, not "Home", matches the
  sketch and the UI-SPEC header.
- Check-in flow: **unchanged**. `/schedule/checkin` keeps its exact path (see plan 22-04).
</decision_ids>

<source_audit>
## Multi-Source Coverage Audit (whole Phase 22 plan set)

### GOAL — ROADMAP.md Phase 22 goal + success criteria

| Item | Status | Plan |
|------|--------|------|
| G1 One screen shows now + the rest of the day, no tab switch | COVERED | 22-01, 22-02, 22-03 |
| G2 Shell destination list reflects the merge | COVERED | 22-04 |
| G3 Chunk-reminder notification tap lands on the working unified screen | COVERED | 22-04 |
| G4 "See full schedule" link resolves coherently post-merge (removed) | COVERED | 22-03 (screen never has it), 22-04 (source deleted) |

### REQ — REQUIREMENTS.md

| Item | Status | Plan |
|------|--------|------|
| UNIFY-01 one screen, now + rest of day | COVERED | 22-01, 22-02, 22-03 |
| UNIFY-02 shell + every entry point lands on the unified screen | COVERED | 22-04 |

### RESEARCH — 22-PATTERNS.md findings (this phase has no RESEARCH.md; PATTERNS.md is the equivalent)

| Item | Status | Plan |
|------|--------|------|
| P1 Two competing "now" detectors (section 5, highest risk) | COVERED | 22-01 (buildTimeline takes NowState; the old scan dies with schedule_screen in 22-04) |
| P2 resolveNowState / NowState relocation + two test import updates (section 2b) | COVERED | 22-01 |
| P3 Duplicated AppBar refresh, ScheduleProgressBar, goal lookups (section 1) | COVERED | 22-03 (single _resolveGoal family) |
| P4 Empty-state reconciliation: BreathingPulseCta + "Add an event" + web banner (section 1) | COVERED | 22-03 |
| P5 NowMarker widget dropped, file deleted (section 2) | COVERED | 22-01 (logic replaced), 22-04 (file deleted) |
| P6 Shell 4-to-3 mechanical collapse, goBranch semantics (section 3) | COVERED | 22-04 |
| P7 `/schedule` redirect in the existing top-level redirect callback; main.dart untouched (section 3.3-3.4) | COVERED | 22-04 |
| P8 responsive_layout_test uses its own dummy 4-branch router — confirm no change (section 3.5) | COVERED | 22-04 (explicit confirm-no-change gate) |
| P9 Reuse pumpWithMood, setViewport, per-file _Fake*Notifier pattern (section 4) | COVERED | all plans |
| P10 chunk_card.dart hardcoded Colors.green.shade600 / Colors.grey.shade400 tech debt | COVERED | 22-02 (converted to ColorScheme slots) |
| P11 RestorativesNotifier + CommitmentFormSheet pulled into the merged provider/import list (section 2) | COVERED | 22-03 |
| P12 showAdaptiveFormModal inherited (RESP-01/02/03) | COVERED | 22-03 |
| P13 720dp content constraint inherited (POLISH-01) | COVERED | 22-03, 22-04 (test repointed) |
| P14 Skipped ExpansionTile vs inline skipped rows — "a genuine design decision" (section 1) | COVERED | 22-02, 22-03 (inline; see note below) |

### CONTEXT — 22-CONTEXT.md locked decisions

| Item | Status | Plan |
|------|--------|------|
| D-01 inline timeline, no hero | COVERED | 22-02 (live row), 22-03 (single list) |
| D-02 auto-scroll live row to centre on open | COVERED | 22-03 |
| D-03 no sticky recall bar | COVERED | 22-03 (explicit negative gate) |
| D-04 no time rail | COVERED | 22-02 (text gutter only, no rail) |
| D-05 free time named, never collapsed, 10-minute threshold | COVERED | 22-01 (model), 22-02 (row) |
| D-06 row vocabulary + 46px mono time gutter | COVERED | 22-02 |
| D-07 mood theming inherited, no new palette | COVERED | 22-02, 22-03 |
| D-08 `/schedule` redirect, notification path, remove "see full schedule" | COVERED | 22-04 |
| D-09 shell 4-to-3 + UI-SPEC note updated | COVERED | 22-04 |

### Deferred — MUST NOT appear in any plan

Sticky recall bar (variant B), time-rail treatment (variant C), any chunk-timer / clock-in
behaviour. Confirmed absent from all four plans.

### Scoped to Phase 23, NOT this phase — the seam is left, the behaviour is not built

LIVE-01 (naming a running break as a break), LIVE-02 (countdown granularity), LIVE-03 (edge-state
copy refinement). Phase 22 delivers the surface: the live row renders a kicker string and a
remaining-time string that are **injected by the screen**, so Phase 23 changes derivations and
copy, not layout. The existing edge-state copy ("Your day starts at ...", "Up next", "That's a
wrap") is **preserved verbatim** in 22-03 — Phase 22 must not delete it, since LIVE-03 is
"the honest edge states *survive* the merge".

### Two presentation reconciliations, called out rather than done silently

1. **Skipped chunks render inline, and the "Skipped today (N)" ExpansionTile is removed.**
   D-01 ("the day is ONE scrollable list") and D-06 ("skipped chunks dimmed and labelled
   'skipped'") make skipped chunks *rows*, not a collapsible drawer. Nothing is hidden — skipped
   work becomes more visible, in clock order, not less.
2. **The mood-coloured AppBar with a `Colors.white` foreground (schedule_screen.dart:52-55) is
   dropped** in favour of the themed default. UI-SPEC: "every colour comes from the active
   ColorScheme ... hardcoded colour is a bug". Mood still reads through the seeded theme, the
   ScheduleProgressBar mood colour, and the header mood chip. No mood signal is lost.

### Data layer

No Hive migration. Both screens already read the same ScheduleNotifier / DailySchedule. No model,
adapter, box, or typeId is touched by any plan in this set. If an executor finds itself editing
`lib/data/`, the scope has drifted — stop and report.
</source_audit>

<tasks>

<task type="auto">
  <name>Task 1: Relocate NowState + resolveNowState to lib/screens/today/now_state.dart (P2)</name>
  <files>lib/screens/today/now_state.dart, lib/screens/home/home_screen.dart, test/screens/home_screen_now_state_test.dart, test/screens/active_chunk_card_test.dart</files>
  <read_first>
    - home_screen.dart lines 21-200 — the block to move (sealed class NowState, PreStart, Active, Overdue, GapBeforeNext, DayComplete, resolveNowState) including every doc comment
    - 22-PATTERNS.md section 2b — the relocation recommendation and the exact two test files that import it
  </read_first>
  <action>
    Create `lib/screens/today/now_state.dart` containing home_screen.dart lines 21-200 moved
    VERBATIM — the section banner comments, the sealed class hierarchy, every doc comment
    (including the KEY INVARIANT and FRAME-OF-REFERENCE notes), and resolveNowState. Do not change
    one line of the algorithm: this is a file move, not a rewrite. The only edits are the import
    block at the top (importing `../../data/models/scheduled_chunk.dart`) and updating the now-stale
    sentence "Conceptually internal to the Home Now zone — not intended for use outside
    home_screen.dart" to say it is the single source of truth for "what is happening now" on the
    unified Today screen.

    Delete lines 21-200 from `lib/screens/home/home_screen.dart` and add an import of
    `../today/now_state.dart` to its import block. home_screen.dart keeps compiling and behaving
    identically — it is deleted later, in plan 22-04, and must stay green until then.

    Add an import of `package:canopy/screens/today/now_state.dart` to BOTH
    `test/screens/home_screen_now_state_test.dart` and `test/screens/active_chunk_card_test.dart`.
    Keep their existing `package:canopy/screens/home/home_screen.dart` imports — those files still
    reference HomeScreen itself, which still exists in this wave. Change nothing else in either
    test file. Run `dart format lib/ test/` and `flutter analyze`.
  </action>
  <verify>
    <automated>test -f lib/screens/today/now_state.dart && grep -q 'sealed class NowState' lib/screens/today/now_state.dart && grep -q 'class GapBeforeNext' lib/screens/today/now_state.dart && ! grep -q 'sealed class NowState' lib/screens/home/home_screen.dart && grep -q 'today/now_state.dart' lib/screens/home/home_screen.dart && grep -q 'screens/today/now_state.dart' test/screens/home_screen_now_state_test.dart && grep -q 'screens/today/now_state.dart' test/screens/active_chunk_card_test.dart && flutter analyze && flutter test test/screens/home_screen_now_state_test.dart test/screens/active_chunk_card_test.dart</automated>
  </verify>
  <done>now_state.dart holds all five NowState subtypes and resolveNowState; home_screen.dart declares none of them but still compiles; both test files import the new path; the pre-existing resolveNowState unit suite and the ActiveChunkCard/HomeScreen widget suite pass unchanged; flutter analyze clean.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: buildTimeline — the single-detector row model (D-05, P1)</name>
  <files>lib/screens/today/timeline.dart, test/screens/today_timeline_model_test.dart</files>
  <read_first>
    - lib/screens/today/now_state.dart (created in Task 1) — the NowState subtypes to switch over
    - lib/data/models/scheduled_chunk.dart lines 60-80 — displayStartMinutes getter semantics (anchoredStartMinutes ?? syntheticStartMinutes, null when neither) and chunkType
    - lib/services/schedule_generator.dart line 630 — proof that schedule.chunks is already emitted in clock order with a 9999 fallback for untimed chunks, which is why buildTimeline must NOT re-sort
    - 22-UI-SPEC.md "Free time (LOCKED)" — the two free-row forms and the ~10-minute suppression rule
    - 22-PATTERNS.md section 5 — the Phase 17 constraint this model exists to make unbreakable
  </read_first>
  <behavior>
    buildTimeline takes named parameters chunks (a list of ScheduledChunk), nowState (a NowState),
    and minGapMinutes (an int defaulting to kMinGapMinutes), and returns a list of TimelineRow.
    Cases the tests must pin, written before the implementation:

    - Empty chunks returns an empty list (no leading free row invented out of nothing).
    - First chunk starts at minute 480: the first element is a LeadingFreeRow with untilMinutes
      480, the second is that chunk's ChunkRow (D-05, "Free until 8:00am").
    - First chunk starts at minute 0: no LeadingFreeRow.
    - All chunks untimed (displayStartMinutes null): no LeadingFreeRow, one ChunkRow each,
      original order preserved.
    - Chunk A at 8:00 for 25 minutes, chunk B at 10:45: a GapFreeRow with startMinutes 505 and
      durationMinutes 140 sits between them (D-05, "Free · 1h 40m").
    - Gap of exactly 10 minutes: a GapFreeRow IS emitted (the threshold is inclusive).
    - Gap of 9 minutes: no free row (suppressed).
    - Gap of 0 (back to back): no free row.
    - An untimed chunk between two timed chunks neither opens nor closes a gap and keeps its
      position in the output order.
    - nowState is Active(c2, ...): exactly one ChunkRow has isLive true, and it is c2's.
    - nowState is Overdue(c1, ...): exactly one ChunkRow has isLive true, and it is c1's.
    - nowState is PreStart, GapBeforeNext or DayComplete: NO row has isLive true.
    - **Phase 17 regression guard (the reason this plan exists):** chunks are an unresolved 8:00am
      work chunk and an in-window 5:30pm work chunk; nowState comes from resolveNowState with a
      frozen clock around 18:00. Assert the live row is the 5:30pm chunk and NOT the 8:00am one.
      The old _buildActiveChunkItems scan would have marked the 8am chunk.
    - Completed and skipped chunks still appear as ChunkRows in clock order — they are never
      filtered out or partitioned (D-01 one list, D-06 skipped is a row).
  </behavior>
  <action>
    Write `test/screens/today_timeline_model_test.dart` FIRST, covering every case in the behavior
    block with a local _workChunk factory (named parameters id, syntheticStartMinutes,
    durationMinutes, isCompleted, isSkipped) modelled on the one in
    `test/screens/home_screen_now_state_test.dart` lines 72-90, plus a _breakChunk factory for
    ChunkType.shortBreak. These are pure test() cases — no widget pump, no providers, no Hive. Run
    them and confirm RED (a compile failure is the expected RED here).

    Then create `lib/screens/today/timeline.dart`:

    Declare `const int kMinGapMinutes = 10;` and a sealed class TimelineRow with exactly three
    subtypes: ChunkRow (fields: a final ScheduledChunk chunk, and a final bool isLive defaulting
    to false), LeadingFreeRow (field: a final int untilMinutes), and GapFreeRow (fields: a final
    int startMinutes and a final int durationMinutes). Three subtypes so the render layer can use
    an exhaustive switch with no default branch.

    Implement buildTimeline as: resolve liveId from nowState with a switch — Active yields
    current.id, Overdue yields overdue.id, every other state yields null. Return early on an empty
    chunk list. Emit a LeadingFreeRow when the first chunk that has a non-null displayStartMinutes
    starts after minute 0. Then walk chunks in the order given, tracking prevEnd as the last seen
    displayStartMinutes plus durationMinutes; before appending each chunk that has a non-null
    start, emit a GapFreeRow when start minus prevEnd is greater than or equal to minGapMinutes.
    Append a ChunkRow for every chunk, with isLive set from an id comparison against liveId.

    Two invariants, stated as doc comments on the function and enforced by the verify gate:
    (1) this function NEVER reads the clock — DateTime must not appear in the file; the only
    source of "now" is the injected nowState, which is the single detector (22-PATTERNS.md
    section 5); (2) the incoming order is preserved, never re-sorted, because the generator
    already emits clock order and re-sorting would silently reposition untimed chunks.

    Run `dart format lib/ test/` and `flutter analyze`.
  </action>
  <verify>
    <automated>flutter test test/screens/today_timeline_model_test.dart && grep -q 'sealed class TimelineRow' lib/screens/today/timeline.dart && grep -q 'class LeadingFreeRow' lib/screens/today/timeline.dart && grep -q 'class GapFreeRow' lib/screens/today/timeline.dart && grep -q 'required NowState nowState' lib/screens/today/timeline.dart && ! grep -vE '^\s*//' lib/screens/today/timeline.dart | grep -q 'DateTime' && flutter analyze</automated>
  </verify>
  <done>buildTimeline is implemented, all behavior cases pass including the Phase 17 regression guard, DateTime appears nowhere in timeline.dart outside comments, and flutter analyze is clean.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| persisted Hive DailySchedule to pure model | schedule.chunks (already validated at write time by the generator) is read and reshaped for display. Read-only; this plan creates no write surface. |
| wall clock to display classification | The clock is sampled in exactly one place (resolveNowState) and its verdict is passed as data. No other component samples it. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-22-01 | Tampering (correctness) | duplicate "now" detection between resolveNowState and any list-side scan | mitigate | buildTimeline takes NowState as a required parameter and cannot read the clock; the verify gate greps that DateTime is absent from timeline.dart outside comments; a dedicated regression test asserts the 6pm/8am case Phase 17 fixed. |
| T-22-02 | Denial of Service (crash) | untimed chunks (displayStartMinutes null) in gap arithmetic | mitigate | Every gap computation is guarded on both endpoints being non-null; untimed chunks neither open nor close a gap. Covered by an explicit unit case. |
| T-22-03 | Information Disclosure (display correctness) | free-time rows leaking negative or absurd durations from out-of-order input | mitigate | A GapFreeRow is emitted only when the gap meets a positive threshold, so overlapping or out-of-order chunks silently produce no free row rather than a negative one. |
| T-22-SC | Tampering | npm/pip/cargo installs | accept | No package installs in this phase. Every plan in the set is implemented with the existing dependency set; the dashed break outline in 22-02 is hand-rolled rather than adding a package. |
</threat_model>

<verification>
- `flutter test test/screens/today_timeline_model_test.dart` — GREEN.
- `flutter test test/screens/home_screen_now_state_test.dart test/screens/active_chunk_card_test.dart` — GREEN (the relocation is behaviour-neutral).
- `flutter test` — full suite still green at its pre-phase count.
- `flutter analyze` — clean.
- `grep -c 'sealed class NowState' lib/screens/home/home_screen.dart` returns 0.
</verification>

<success_criteria>
- UNIFY-01 (data spine): the merged screen's row list can be produced from chunks plus a NowState
  alone, with named free time and exactly one live row.
- P1 closed structurally: there is no code path by which the row list can disagree with
  resolveNowState about which chunk is current.
- P2 closed: resolveNowState and NowState are importable without touching a screen file, and both
  dependent test files compile against the new location.
- No behaviour change ships in this plan — the suite count and results are identical before and
  after.
</success_criteria>

<output>
Create `.planning/phases/22-unified-today-screen/22-01-SUMMARY.md` when done.
</output>
