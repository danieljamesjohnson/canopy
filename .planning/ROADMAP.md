# Canopy — Roadmap

**Created:** 2026-02-24
**Last updated:** 2026-08-10 (Phase 26 planned — 6 plans, 6 waves)

## Milestones

- ✅ **v1.0 — Core Product Loop** — Phases 1-6 (shipped)
- ✅ **v1.1 — Actually Daily** — Phases 7-11 (shipped)
- ✅ **v1.2 — Make It Usable** — Phases 12-14 (shipped 2026-06-13)
- ✅ **v1.3 — An Honest Day** — Phases 15-17 (shipped 2026-06-14)
- ✅ **v1.4 — Energy-Aware** — Phases 18-20 (shipped 2026-06-15)
- 🚧 **v1.5 — Right Now** — Phases 21-26 (in progress)

Full per-milestone detail (phase goals, success criteria, coverage maps) is archived in
`.planning/milestones/`: `v1.2-ROADMAP.md` carries the complete cumulative roadmap through v1.2;
`v1.3-ROADMAP.md`, `v1.3-REQUIREMENTS.md`, and `v1.3-MILESTONE-AUDIT.md` carry the v1.3
phase detail, requirements, and audit.

## Phases

<details>
<summary>✅ v1.0 Core Product Loop (Phases 1-6) — SHIPPED</summary>

- [x] Phase 1: Foundation
- [x] Phase 2: Goals and Commitments
- [x] Phase 3: Schedule Generation and Morning Check-in
- [x] Phase 4: Chunk Tracking and Notifications
- [x] Phase 5: Quarterly Review
- [x] Phase 6: Desktop and Web Polish

</details>

<details>
<summary>✅ v1.1 Actually Daily (Phases 7-11) — SHIPPED</summary>

- [x] Phase 7: Unbreak the Morning
- [x] Phase 8: A Schedule You Can Read
- [x] Phase 9: An Engine That Budgets
- [x] Phase 10: Close the Day
- [x] Phase 11: Honest Long Loop

</details>

<details>
<summary>✅ v1.2 Make It Usable (Phases 12-14) — SHIPPED 2026-06-13</summary>

- [x] Phase 12: Home as Landing, Schedule as Plan (3/3 plans) — NAV-01/02, SCHED-01/02/03
- [x] Phase 13: Check-in and Goal Form (2/2 plans) — CHECKIN-01/02, GOALFORM-01
- [x] Phase 14: Goals Screen and Priority End-to-End (2/2 plans) — GOALS-01/02, PRIORITY-01

</details>

<details>
<summary>✅ v1.3 An Honest Day (Phases 15-17) — SHIPPED 2026-06-14</summary>

**Milestone Goal:** Make the scheduling engine tell the truth and use the whole day — real time, real priority, filled capacity, honest streaks. Rule-based only (no LLM).

- [x] Phase 15: Engine Honesty (2/2 plans) — CAP-01, STREAK-01, PRIORITY-02, FILL-01, FILL-02
- [x] Phase 16: Priority Model Reconciliation (1/1 plan) — PRIORITY-03, GOALFORM-02
- [x] Phase 17: Time-Anchored Home (1/1 plan) — NOW-01, NOW-02

Full detail archived in `.planning/milestones/v1.3-ROADMAP.md`. 9/9 requirements satisfied,
browser-verified; 247/247 tests green. See `v1.3-MILESTONE-AUDIT.md`.

</details>

<details>
<summary>✅ v1.4 Energy-Aware (Phases 18-20) — SHIPPED 2026-06-15</summary>

**Milestone Goal:** Make Canopy fit the screen it's used on and schedule around how activities make you feel — so a fresh review can judge a more honest, more livable day.

- [x] Phase 18: Responsive Modals and Desktop Polish (5/5 plans) — RESP-01/02/03, POLISH-01/02
- [x] Phase 19: Energy Valence (5/5 plans) — ENERGY-01/02/03/04, ONBOARD-01
- [x] Phase 20: Valence-Aware Engine (2/2 plans) — VSCHED-01/02/03

Full detail archived in `.planning/milestones/v1.4-ROADMAP.md`. 13/13 requirements satisfied,
browser-verified; 289/289 tests green. See `v1.4-MILESTONE-AUDIT.md`.

</details>

### 🚧 v1.5 Right Now (In Progress)

**Milestone Goal:** Make Canopy answer "what am I doing right now?" in one place — and stop telling the user they're behind.

- [x] **Phase 21: Mood-Scaled Breaks & Honest Rationale** - Long-break cadence scales with morning mood; time-target rationale drops "behind" framing (completed 2026-08-07)
- [x] **Phase 22: Unified Today Screen** - Home and Schedule merge into one destination; every existing entry point still resolves somewhere real (completed 2026-08-07)
- [x] **Phase 23: Live Activity Tracking** - The unified screen always names the current activity, including breaks, with a live countdown (completed 2026-08-08)
- [x] **Phase 24: Where Am I** - The timeline carries a now-marker at the current clock position (completed 2026-08-10)
- [x] **Phase 25: Time Travel** - Debug-only clock override makes time-gated states inspectable on demand (completed 2026-08-10)
- [ ] **Phase 26: The Day Has a Shape** - Time-proportional day surface with a continuously-moving now-line

## Phase Details

### Phase 21: Mood-Scaled Breaks & Honest Rationale

**Goal**: The schedule's break cadence adapts to the morning mood, and a time-target goal's rationale never frames the user as behind
**Depends on**: Nothing (parallel-safe with Phase 22 — self-contained engine + copy change, no shared surface with the screen merge)
**Requirements**: BREAK-01, BREAK-02, TONE-01
**Success Criteria** (what must be TRUE):

  1. On a low-mood day, the generated schedule inserts a long break after roughly every 2 chunks; on a sunny-mood day, after roughly every 5 chunks — deterministic and unit-tested
  2. Every chunk is still followed by its 5-min short break, and every long break is still 25 minutes — only the cadence count changed, not the break structure
  3. No schedule or rationale text anywhere reads "behind this week"; a time-target goal's rationale reads as what the schedule is doing for the user, not as a deficit report

**Plans**: 2 plans, 2 waves. Mood cadence mapping locked at `{1:2, 2:3, 3:4, 4:4, 5:5}` (moods 3/4 plateau; endpoints per success criterion 1).Plans:
**Wave 1**

- [x] 21-01-mood-scaled-break-cadence-PLAN.md — five-point `_moodBreakCadence` table replaces the `isLowMood ? 3 : 4` ternary, plus the six cadence/structure tests that make the cadence verifiable for the first time (wave 1)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 21-02-honest-time-target-rationale-PLAN.md — `_timeTargetRationale` deficit branch becomes "Working toward N.Nh this week", pinned by tests on both branches and a repo-wide grep gate (wave 2)

**Note**: the long-standing carry-forward claim that "three tests at ~lines 492-543 assert the every-4 cadence and must change" is stale — 21-RESEARCH.md verified empirically that all 54 existing tests pass unchanged under the new mapping. There was zero discriminating cadence coverage before this phase, which is why the new tests are the substance of plan 21-01 rather than an afterthought.

### Phase 22: Unified Today Screen

**Goal**: Home and Schedule merge into a single destination — users see what's happening now and the rest of the day without switching tabs, and every existing entry point still lands somewhere real
**Depends on**: Nothing (parallel-safe with Phase 21; structural/navigation work only — live-tracking behavior is layered on afterward in Phase 23)
**Requirements**: UNIFY-01, UNIFY-02
**Success Criteria** (what must be TRUE):

  1. Opening the app lands the user on one screen that shows both what's happening now and the rest of the day's chunks — no tab switch required
  2. The shell's destination list reflects the merge — Home and Schedule no longer point at two separate screens for the same underlying content
  3. Tapping a Chunk reminder notification lands on the working unified screen, not a dead or blank route (currently `router.go('/schedule')`, `lib/main.dart:86`)
  4. The in-app "See full schedule" link (`lib/screens/home/home_screen.dart:495`) resolves to something coherent post-merge, not a stale destination

**Plans**: 4 plans, 3 waves. Merged destination is "Today" at `/today` (`lib/screens/today/`).
Plans:

- [x] 22-01-now-state-and-timeline-model-PLAN.md — relocate `resolveNowState`/`NowState` out of home_screen.dart and add the pure `buildTimeline` row model, making `resolveNowState` the single "now" detector by construction (wave 1)
- [x] 22-02-timeline-row-vocabulary-PLAN.md — 46dp time gutter, named free-time rows, the swelled `LiveRowCard`, and the extended `chunk_card` row treatments (wave 1)
- [x] 22-03-today-screen-assembly-PLAN.md — build `TodayScreen`: one scrollable day, live row centred on open, reconciled empty state, edge-state copy preserved (wave 2)
- [x] 22-04-navigation-merge-and-cleanup-PLAN.md — router branches 4→3 with a `/schedule` redirect, shell 4→3, delete the two old screens, migrate their tests (wave 3)

**UI hint**: yes

### Phase 23: Live Activity Tracking

**Goal**: The unified screen always tells the truth about what's happening right now, including breaks, with a live countdown
**Depends on**: Phase 22 (the live readout is layered onto the merged screen's now-state; wiring it against a screen that's still split in two would mean redoing it once the merge lands)
**Requirements**: LIVE-01, LIVE-02, LIVE-03
**Success Criteria** (what must be TRUE):

  1. When a break is running, the screen names it as a break with time remaining — never reads as empty or idle time (extends `resolveNowState`, which Phase 22 relocated to `lib/screens/today/now_state.dart`, past its current work-chunks-only filter)
  2. Time remaining in the current activity (chunk or break) visibly counts down while the screen stays open
  3. Before the day's first chunk starts, in a gap between activities, and after the day is complete, the screen shows a distinct, truthful state for each case

**Plans**: 8 plans (4 original + 4 UAT gap-closure). Plans 23-05..23-08 close the seven gaps Dan reported at the 23-04 sign-off gate (`23-UAT.md` Gaps, diagnosed in `23-GAP-ANALYSIS.md`).
Plans:
**Wave 1**

- [x] 23-01-PLAN.md — Break-aware now-state: drop resolveNowState's work-only filter, name a running break in the live row and in every "next" line, and exclude breaks from the "Start focus" target (LIVE-01)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 23-02-PLAN.md — Live countdown: second-precision remaining-time label (whole minutes rounded up above 60s, seconds below) driven by a dual-cadence tick, with the 1-second timer alive only in the final minute (LIVE-02)

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 23-03-PLAN.md — Honest edge states: locked pre-start and day-complete copy, plus the recorded and tested decision to leave the gap banner unchanged (LIVE-03)

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 23-04-PLAN.md — Phase gate: full suite + analyze, served debug build, and Dan's sign-off on the two manual-only verifications and the gap-banner decision

  **No 23-04-SUMMARY.md exists.** The gate was discharged through `23-UAT.md` rather than a summary
  write-up: all 4 sign-off items passed (Dan, 2026-08-08), the served debug build ran on
  `danserver:8123`, and the seven gaps Dan raised at that same gate were closed by 23-05..23-08.
  One item is genuinely outstanding and is *not* being smoothed over: `23-VALIDATION.md` never left
  `status: draft` / `nyquist_compliant: false`, matching the same carried tech-debt item already
  logged for phases 15/16/17. Recorded here rather than back-filled.

### Phase 23 gap closure (UAT, 2026-08-08)

Four plans closing G-01..G-07 from `23-UAT.md`. Waves are re-numbered from 1 within this set; the
only cross-plan constraint is `today_screen.dart`, which 23-05 and 23-07 both touch.

**Wave 1**

- [x] 23-05-PLAN.md — G-03 (bug): the minute tick survives a `paused` with no matching `resumed`, the fast tick is guarded from running while backgrounded, a dead timer self-heals in `build()` — pinned by a regression test proven to fail without the fix
- [x] 23-06-PLAN.md — G-05 (behaviour): completing a work chunk early moves the following break to start now and keep its original end ("extend the break to fill"), nothing downstream shifts, Phase 17's unopened-window invariant untouched
- [x] 23-08-PLAN.md — G-01 + G-07: both energy-valence controls reorder to Drains → Neutral → Lifts; picking a day type states its consequence in the generator's real `_moodCap`/`_moodBreakCadence` numbers; the dead acknowledgment-screen duplicate is deleted

**Wave 2** *(blocked on 23-05 — shares `today_screen.dart`)*

- [x] 23-07-PLAN.md — G-04 + G-02 + G-06: time gutter gains the 16dp inset every other element has (cards do not move), a long break reads substantially heavier within the dashed vocabulary, and the chunk count stops rendering twice

**UI hint**: yes

---

### Phase 24: Where Am I

**Goal**: The timeline itself shows where "now" falls, so the user can locate themselves in the day even when no activity is currently running
**Depends on**: Phase 23 (layers onto the merged screen's row model and its single now-detector)
**Requirements**: NOW-01, NOW-02
**Success Criteria** (what must be TRUE):

  1. The list carries a visible now-marker at the current clock position, so "where am I" is answerable by looking at the timeline rather than by reading a header line several rows away
  2. The marker's position derives from the same clock sample `resolveNowState` already uses — it is a *position*, never a second opinion about which activity is current (the Phase 17 / 22-PATTERNS §5 single-detector rule stands)
  3. A leading "Free until <time>" row never describes a window that has already closed

**Origin**: Dan, UAT 2026-08-08 — *"i clicked the link and right now i can't tell what we're 'on'"*, then *"just can't tell where now is"*, with a screenshot (`~/feedback-drop/canopy/inbox/2026-08-08_17-34-09/`). Root cause traced: Phase 22-04 deleted `now_marker.dart` with the screens it replaced and nothing took over the job. 22-PATTERNS.md §2 had explicitly flagged the widget as worth keeping — that note was not acted on.

**UI hint**: yes

**Plans**: 4 plans
Plans:
**Wave 1**

- [x] 24-01-PLAN.md — Row model + widget: `NowMarkerRow`, `nowMinutes` threading, NOW-02 leading-row guard, `NowMarker` widget, unit + row-widget tests (wave 1)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 24-02-PLAN.md — Screen wiring: `nowMinutes` from the single `nowDt` sample, the fourth exhaustive-switch case, screen-level tests, correction of the stale NOW-02 assertion, phase gate (wave 2)

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 24-03-PLAN.md — Serve the debug web build and get Dan's at-a-glance verdict (wave 3, has checkpoint)

**Wave 4** *(gap closure, blocked on Wave 3 completion)*

- [x] 24-04-PLAN.md — Gap closure: key the now-marker and add its centre-on-open fallback for `DayComplete`/`PreStart`/`GapBeforeNext` (no live row to centre on otherwise), plus a two-flag regression test (wave 4)

**Open design decision — RESOLVED during Phase 23 planning:** LIVE-02's tick granularity was left open here and is now decided (`23-CONTEXT.md` decision 1, implemented in plan 23-02): whole minutes rounded up while at least 60s remain, seconds below that, with a second 1-second timer that exists only inside the final minute so the all-day 1-minute ticker is not replaced. The original wording follows. LIVE-02's tick granularity is not decided here. The existing `Timer.periodic` (carried into `TodayScreen` by Phase 22) fires once a minute; a countdown that visibly moves may need a faster tick for the live row while other regions stay on the coarser cadence. Phase planning must pick and justify a granularity rather than silently inherit the 1-minute timer.

**Seam left by Phase 22:** `LiveRowCard` takes `kicker` and `remainingLabel` as injected strings, so LIVE-01/LIVE-02 change what `TodayScreen` computes rather than the widget's layout. `showActions` is already wired from the chunk type for LIVE-01's break case. The pre-start / gap / day-complete copy was carried across verbatim, so LIVE-03 refines wording rather than rebuilding states.

---

### Phase 25: Time Travel

**Goal**: A debug-only clock override lets time-gated states be inspected on demand, so UAT of "what does the app look like at 9pm" does not require waiting until 9pm
**Depends on**: nothing (pure dev infrastructure; the seams it uses already exist)
**Requirements**: DEV-01, DEV-02, DEV-03
**Success Criteria** (what must be TRUE):

  1. A debug build can be put into any simulated moment and the whole app agrees — the timeline, the schedule's "today" key, and the end-of-day card all read the same clock
  2. Time still *flows* while overridden — the override is an offset, not a frozen instant, so the minute ticker keeps advancing and a moving marker can be watched
  3. The override survives a page reload (web UAT means reloads) and is impossible to leave on by accident — it is always visibly indicated
  4. Release builds are unaffected: the override cannot be set, and the clock is exactly `DateTime.now()`

**Origin**: Dan, Phase 24 UAT 2026-08-10 — *"Probably need a testing harness that we can set time and such."* Phase 24's final UAT item (`DayComplete`) was blocked purely on wall-clock time: the state only exists after the day's last chunk ends, and the running app has no clock seam the router uses. Phase 26 will be strictly worse — a continuously-moving now-line cannot be UAT'd by waiting.

**Why this is cheap**: the seams already exist and are already used by the test suite — `ScheduleNotifier(now:)`, `TodayScreen(now:)`, `shouldShowEodCard(now:)`, `resolveNowState(now:)`. Only `HiveDailyScheduleRepository.getTodaysSchedule()` reads `DateTime.now()` hard-coded. This phase supplies one source for those seams rather than inventing new ones.

**Deliberate constraint**: this is dev instrumentation, not a product feature. It must be `kDebugMode`-gated end to end. A user-facing time override would be a footgun in an app whose whole premise is a schedule you can trust.

**UI hint**: yes (debug-only surface)

**Plans**: 1/1 complete — `25-01` (no PLAN.md; executed directly from a scoped prompt, see `.planning/phases/25-time-travel/25-01-SUMMARY.md`)

---

### Phase 26: The Day Has a Shape

**Goal**: The day renders as a time-proportional surface with a continuously-moving now-line, so "where am I" is answered by position rather than by a marker slotted between rows
**Depends on**: Phase 24 (owns the row model, the single clock sample, and the marker this phase generalises)
**Requirements**: CAL-01, CAL-02, CAL-03
**Success Criteria** (what must be TRUE):

  1. A row's height corresponds to its duration, so the shape of the day is legible without reading any times
  2. The now-line sits at the true current moment *including inside an activity's span*, not only at chunk boundaries
  3. Elapsed time recedes — the past is a deliberate scroll away rather than the default view
  4. The single-clock-sample rule still holds: the line is a position derived from build()'s one `nowDt`, never a second opinion about which activity is current

**Origin**: Dan, Phase 24 UAT 2026-08-08 — *"could maek it like a calendar view as well where as time goes on theres a red line that scrolls downt he page to tell you where you are relatively to the time"*, alongside *"i think things int het past should have to be scrolle dto"*. Phase 24 delivered the marker and confirmed it reads well mid-day; this phase is the structural version of the same question.

**Why this is not just a skin**: Phase 24's `24-UI-SPEC.md` suppresses the marker during `Active` on the explicit grounds that a chunk-boundary position "would visually assert a boundary position that isn't the true one" mid-chunk. A time-proportional layout removes that constraint rather than working around it, so CAL-02 supersedes the `Active`-suppression rule instead of coexisting with it. Expect `NowMarkerRow`'s between-rows insertion contract in `timeline.dart` to be reworked, not extended.

**Open questions — RESOLVED at discuss-phase, 2026-08-10** (`26-CONTEXT.md`): **D-01** — the
proportional surface *replaces* the list; no toggle, no second mode, no persisted view
preference. **D-02** — fully proportional; an empty 4-hour stretch renders 4 hours tall, with no
gap compression and no min/max row clamping. **D-03** — the now-line is `colorScheme.primary`,
not a hardcoded red and not `colorScheme.error`.

**Scope boundary inherited from Phase 24**: D-03's prohibition on a sticky bar, floating pill, or jump button was about the *marker*. Whether it binds a proportional layout is an open question for this phase, not a settled constraint. (Planning added none — Dan has not asked for one.)

**UI hint**: yes

**Planner corrections to `26-UI-SPEC.md`** (measured 2026-08-10, recorded in plan 26-01 as PD-1
and PD-2): `kPixelsPerMinute` is **5.5**, not the UI-SPEC's 4.0 — a Full-tier work card measures
126px, so a 25-minute chunk needs 137.5px of slot, not 100px. `kLiveRowReservedHeight` is
**240.0** — `LiveRowCard` measures 230px, above the UI-SPEC's 200–220 estimate. Density tiers are
keyed on pixel slot height, not on minutes, so they cannot rot if the scale moves again. All
three are subject to Dan's real-browser verdict at the phase gate.

**Plans**: 6 plans, 6 waves (strictly sequential — every plan boundary is a point where the tree
must compile and the suite must be green, which is the phase's dominant risk)
Plans:
**Wave 1**

- [x] 26-01-PLAN.md — Foundations, additive only: hour-range helpers in `time_format.dart`, the pure `TimelineGeometry` minute→pixel authority and its six constants, and the `NowLineOverlay` / `HourAxisLine` widgets (CAL-01/02/03)

**Wave 2** *(blocked on Wave 1)*

- [x] 26-02-PLAN.md — Row vocabulary at proportional scale: `ChunkCardDensity` (detailed/full/compact) with a parameterised dashed painter, and `TimelineRowTile` reduced to a blank reserved gutter with `FreeTimeRow` centring in its allocated height (CAL-01)

**Wave 3** *(blocked on Wave 2)*

- [ ] 26-03-PLAN.md — Retire `NowMarkerRow` end-to-end in one green commit, then render the day as a fixed-height `Stack` of duration-positioned rows (CAL-01, CAL-02)

**Wave 4** *(blocked on Wave 3)*

- [ ] 26-04-PLAN.md — Wire the hour axis and the now-line overlays into the `Stack`; suppression deleted, not relocated; CAL-02 asserted across all five `NowState`s including mid-chunk (CAL-02)

**Wave 5** *(blocked on Wave 4)*

- [ ] 26-05-PLAN.md — Centre-on-open: two flags, two `GlobalKey`s and two `ensureVisible` blocks collapse into one flag and one arithmetic `animateTo` (CAL-03)

**Wave 6** *(blocked on Wave 5, has checkpoint)*

- [ ] 26-06-PLAN.md — Phase gate: full suite + analyze, debug web build served on fresh port 8131 via `tools/serve-uat.py`, and Dan's real-browser sign-off on the ten harness-bound checks using Phase 25's DevClock offset (CAL-01/02/03)

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1-6 (Core Product Loop) | v1.0 | — | Complete | 2026-02 |
| 7-11 (Actually Daily) | v1.1 | — | Complete | — |
| 12-14 (Make It Usable) | v1.2 | 7/7 | Complete | 2026-06-13 |
| 15. Engine Honesty | v1.3 | 2/2 | Complete | 2026-06-13 |
| 16. Priority Model Reconciliation | v1.3 | 1/1 | Complete | 2026-06-13 |
| 17. Time-Anchored Home | v1.3 | 1/1 | Complete | 2026-06-14 |
| 18. Responsive Modals and Desktop Polish | v1.4 | 5/5 | Complete   | 2026-06-15 |
| 19. Energy Valence | v1.4 | 5/5 | Complete   | 2026-06-15 |
| 20. Valence-Aware Engine | v1.4 | 2/2 | Complete   | 2026-06-15 |
| 21. Mood-Scaled Breaks & Honest Rationale | v1.5 | 2/2 | Complete   | 2026-08-07 |
| 22. Unified Today Screen | v1.5 | 4/4 | Complete   | 2026-08-07 |
| 23. Live Activity Tracking | v1.5 | 8/8 | Complete   | 2026-08-08 |
| 24. Where Am I | v1.5 | 4/4 | Complete    | 2026-08-10 |
| 25. Time Travel | v1.5 | 1/1 | Complete    | 2026-08-10 |
| 26. The Day Has a Shape | v1.5 | 2/6 | In Progress|  |
