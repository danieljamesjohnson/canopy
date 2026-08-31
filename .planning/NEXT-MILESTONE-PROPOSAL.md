> # ⚠ SUPERSEDED — DO NOT ACT ON THIS DOCUMENT
>
> **Marked 2026-08-31.** This proposes **v1.1 "Actually Daily"**, which shipped long ago. Five
> further milestones (v1.2–v1.5) and Phases 27–32 have shipped since. Its "Reality Check" inventory
> describes a June 2026 codebase and is **wrong about the current one** — B1 (cold-launch empty
> schedule), B2 (no day rollover), B3 (chunks show rationale not goal name), B6 (no re-check-in)
> and most of B5's engine gaps are all fixed.
>
> It is kept for provenance only. **For what is actually next, read `ROADMAP.md` Phase 33 and
> `STATE.md`.** An agent that acts on this file will redo finished work.

# Next Milestone Proposal — v1.1 "Actually Daily"

**Author:** Fable (Claude), at owner's request
**Date:** 2026-06-10
**Status:** PROPOSAL ONLY — not yet committed to ROADMAP/STATE
**Verification caveat (RESOLVED 2026-06-10):** Originally written without a Flutter SDK on the machine. Flutter 3.44.1 / Dart 3.12.1 has since been installed and a verification pass was run — see the addendum at the bottom. The headline cold-launch bug is **confirmed in source**; `analyze` is clean and all 90 tests pass (which is itself evidence — the suite never exercises the broken morning path).

---

## 0. Owner Decisions (resolved 2026-06-10)

These were the open questions at the end of the original proposal; the owner has answered them. They are binding for v1.1 planning.

1. **Companion, not checklist.** A minimal focus-session mode (current-chunk / timer) is **in scope** — design it into Phases 2 and 4 rather than shipping a static list.
2. **Allocation policy accepted as proposed.** Time-target: remaining-budget ÷ remaining-days, capped 4/day. Outcome: deadline-pressure. No changes requested.
3. **Daily driver is iOS.** Keep the OS scheduled-notification path (do NOT pivot Phase 1 to an in-app-only morning pattern). Note: live iOS-simulator testing isn't possible on this Linux box; verify logic via `analyze`/`test`/web-or-linux builds, and treat on-device notification behavior as a manual UAT item.
4. **Scope confirmed:** one medium milestone (v1.1, 5 phases), Phases 1–3 firm.

---

## 1. Reality Check

The owner's instinct is correct. The v1.0 milestone produced a real architecture — but the **daily-use loop is broken at the first step**, the scheduling engine implements maybe 40% of its own spec, and several "completed" deliverables exist as UI shells wired to nothing. Here is the candid inventory.

### 1.1 Broken / missing basics (blocks daily use)

**B1. The morning flow generates schedules from empty data — the #1 "it just doesn't work" bug.**
`GoalsNotifier.loadGoals()` is called only from `GoalsScreen.initState` (`lib/screens/goals/goals_screen.dart:24`) and `CommitmentsNotifier.loadBlocks()` only from `CommitmentsScreen.initState` (`lib/screens/commitments/commitments_screen.dart:22`). Both providers are lazily created in `main.dart:89-91` and never initialized at startup. The check-in screen reads `context.read<GoalsNotifier>().goals` and `.blocks` directly (`lib/screens/schedule/checkin_screen.dart:55-59`). So on any cold launch where you go Home → "Start your day" → tap mood (the *intended* daily path), the generator receives `goals: []`, `blocks: []`, returns `[]` (`schedule_generator.dart:155`), and an **empty schedule is persisted for the day**. HomeScreen then renders "All done today!" (`home_screen.dart:125-131`) at 8am. It only "works" if you happen to visit the Goals tab first each session. This single wiring gap plausibly explains most of the owner's experience.

**B2. No day rollover.** `ScheduleNotifier.hasScheduleToday` is just `_todaySchedule != null` (`schedule_notifier.dart:22`), loaded once in `init()` at process start. There is no lifecycle observer and no date re-check. Resume the app the next morning (the normal mobile pattern — apps are resumed, not relaunched) and yesterday's schedule is displayed as today's. `ThemeNotifier` got this right (`_resetIfDayChanged()` on resume, `theme_notifier.dart`); `ScheduleNotifier` never did.

**B3. The schedule doesn't say what the chunks are.** Chunk cards render `chunk.rationale` as their title (`chunk_card.dart:188-190`), and the generator sets rationale to the literal strings `'Habit'`, `'Outcome goal'`, `'Weekly goal'` (`schedule_generator.dart:82,121,145`). The goal *name* is never shown — `goalId` is used only for the color bar (`schedule_screen.dart:122-128`). Your day reads as "Habit, Habit, Outcome goal, Weekly goal." The ROADMAP promised "goal name (large/bold)" and rationales like "Streak active — 12 days". Neither exists.

**B4. The morning notification never fires on a fresh install.** `SettingsNotifier` defaults `morningNotificationEnabled = true` (`settings_notifier.dart:15`), but `NotificationService.scheduleMorningNotification()` is invoked **only** from the Settings screen toggle/time-picker handlers (`settings_screen.dart:93,115`). Nothing schedules it at startup, after onboarding, or after check-in. Unless the user toggles the switch off and back on, the "daily companion" never knocks. Additionally, the notification tap handler calls `rootNavigatorKey.currentState?.pushNamed('/schedule')` (`main.dart:60-62`) — Navigator *named routes* do not exist under go_router; this will throw `onGenerateRoute == null` at runtime. And on Linux (the owner's desktop OS), `zonedSchedule` is not implemented by flutter_local_notifications' Linux plugin — the settings toggle likely surfaces an error there. Needs runtime confirmation.

**B5. The scheduling engine is a skeleton of its own spec.** `schedule_generator.dart` (190 lines) vs. ROADMAP Phase 3 deliverables:
- **One chunk per goal, ever.** Each loop adds exactly one chunk per goal (`:74-86, :108-126, :138-149`). At mood 5 the cap is 11 discretionary chunks, but with 3 goals you get 3. Capacity, the core "time budgeting" concept, is never actually allocated.
- **`weeklyHourBudget` is ignored.** Time-target goals are sorted by `priorityWeight` (`:135-136`), not "most behind weekly budget first" (ROADMAP line 146). The form collects hours/week (`goal_form_sheet.dart:172-190`), the card displays it, the engine never reads it.
- **`frequencyPerWeek` is ignored.** Habits are scheduled every day regardless of the 3x/5x/7x setting collected in onboarding and the goal form. Grep confirms zero reads outside forms/dev-loader.
- **`chunksRemaining = 2.0` placeholder still shipping.** `schedule_generator.dart:101-102`. STATE.md (Phase 03-01 decision) says "replaced with CompletionLog in Phase 4" — Phase 4 never did.
- **`priorityWeight` has no UI.** `GoalFormSheet` declares `_priorityWeight` but renders no control for it (only name/type/budget/deadline/frequency appear in `build()`). Every goal is null → 0.5. "Priority" does not exist in the product, which also nullifies the urgency formula's main input.
- **`streakCount` is never written.** `goal_card.dart:64-65` displays "N-day streak" but no code ever increments it (grep: writes only in dev_data_loader). Permanently 0.
- **Ordering is incoherent.** All commitment chunks come first regardless of time of day (a 2pm meeting block precedes your morning habit), and the break-insertion pass (`:160-185`) inserts 5/25-min breaks *between back-to-back anchored commitment chunks* whose `anchoredStartMinutes` are 25 minutes apart — the displayed timeline is self-contradicting. A trailing break is always appended after the last chunk.
- **"Want a lighter day?" toggle is dead.** `_lighterDay` state in `checkin_screen.dart:40,186` is never passed to `generateToday()`. UI exists, does nothing.

**B6. No way to re-check-in or regenerate.** Once a schedule exists, `/schedule/checkin` is reachable only from empty-state buttons (`home_screen.dart:198`, `schedule_screen.dart:147,179`) — which no longer render. Mood changed mid-day, added a goal, schedule wrong? No path. (`generateToday` supports silent replace; there's just no button.)

**B7. End-of-day summary is effectively unreachable.** Its only entry is a popup menu on the Schedule screen that appears once ≥50% of work chunks are resolved (`schedule_screen.dart:47-58`). No Home entry, no evening notification (ROADMAP OQ-11's 9:00pm default was never built). Most users will never discover `/summary`.

**B8. Quarterly review's "adjust priorities" doesn't affect the schedule.** Section 3 says "Drag to reorder. Your schedule will reflect this tomorrow" (`adjustments_section.dart:165`) and persists `sortOrder` — but the generator orders by `priorityWeight`/urgency, never `sortOrder`. Phase 5 AC-4 ("updated priorities are reflected in the next morning's schedule generation") is unmet. The review also reads `GoalsNotifier.goals`, so opened from the Home banner on a cold launch it sees an empty goal list (same B1 bug): empty adjustments list, nameless charts.

**B9. Completion data is quietly skewed.** Commitment-block chunks log `goalId: ''` (`schedule_notifier.dart:83,107`). The donut chart builds slices only for active goals (`donut_chart.dart:38-53`) but its total includes the `''` bucket and archived goals' counts → invisible slice, wrong percentages. Commitment time (most of a workday!) vanishes from the review entirely.

### 1.2 Incomplete polish (annoying, not blocking)

- `GoalFormSheet` recreates `TextEditingController`s inside `build()` for weekly-hours and description (`goal_form_sheet.dart:180,218`) → cursor jumps to position 0 every keystroke. Entering "5.0" is a fight.
- Tap-chunk → detail/edit bottom sheet (Phase 4 deliverable) — absent. Schedule reorder (OQ-5 "full reorder always available") — absent.
- `CompletionEvent.deferred` exists in the enum, is counted by aggregation, and is never emitted anywhere.
- "Minutes from midnight UTC" comments vs. actual local-time values throughout — harmless today (local-only app) but the comments lie.
- Acknowledgment text says "Starting with Habit." (B3's rationale problem leaking into copy).

### 1.3 Genuinely done (real, and good)

- **Data layer:** 7 Hive entities, clean repository interfaces, additive migration runner, append-only enforcement at the interface level for logs/snapshots. Solid foundation.
- **Goals/commitments CRUD + onboarding:** complete flows, archive-only deletion, plain-language type picker, the 3-screen onboarding works (and because onboarding saves via the notifiers, the *first* session's check-in works — masking B1 until day 2, which matches "it worked, then it didn't").
- **Check-in UX + mood theming:** the emoji check-in, acknowledgment, app-wide `ColorScheme.fromSeed` mood theming with time-of-day HSL modulation and proper day rollover (`theme_notifier.dart`) — genuinely polished, lifecycle-aware, reduced-motion-aware.
- **Swipe complete/skip → CompletionLog append** works (`swipeable_chunk_card.dart`, `schedule_notifier.dart:68-114`), with desktop hover parity.
- **Quarterly aggregation service:** pure Dart, correct, tested (`quarterly_aggregation_service.dart`). The review flow's 3 sections, charts, snapshot persistence with retry-dedup are real code, hampered only by B8/B9 inputs.
- **Export, responsive shell, window constraints, web banner fallback** — fine.

**Bottom line:** v1.0 built a good chassis and bolted on a cardboard engine. Nothing here requires re-architecture — the stack (Hive/Provider/go_router) is fine. What's missing is the *connective tissue* (data loading, rollover, entry points, navigation) and an engine that honors the goal model it already stores.

---

## 2. The Gap → The Goal

**"Genuinely usable daily companion" for Canopy means, concretely:**

1. **Morning never dead-ends.** Cold launch or resume, day N or day N+1: check-in is reachable, and tapping a mood produces a schedule built from *your actual saved goals and commitments* — every time.
2. **The schedule is legible and believable.** Each chunk names its goal and why it's there; the list reads in day order around your anchored commitments; break placement doesn't contradict the clock.
3. **The schedule reflects the budget.** Mood capacity is actually filled; weekly-hour goals get chunks proportional to how far behind they are; habits respect their frequency; "lighter day" does something.
4. **The day closes.** Completing/skipping is one gesture (already true), streaks accrue, and an end-of-day moment is offered, not hidden.
5. **Long-loop honesty.** The review counts all logged time correctly and its adjustments demonstrably change tomorrow's schedule.

**Minimum bar:** items 1–2 are non-negotiable; 3 is the product's reason to exist; 4–5 make it stick. All rule-based — nothing here needs (or should use) an LLM.

---

## 3. Milestone Proposal

**Milestone:** v1.1 — **"Actually Daily"**
**One-line goal:** Close the gap between "all phases complete" and "I open it every morning and it works" — fix the broken daily loop, then make the rule-based engine honor the goal model it already stores.

### Phase 1: Unbreak the Morning (loop plumbing)
*Delivers:* a daily loop that cannot dead-end.
- Initialize `GoalsNotifier`/`CommitmentsNotifier` at startup (construct + `await init()` before `runApp`, mirroring `ScheduleNotifier`), or load inside `generateToday()` itself — generation must never see unloaded data (B1).
- Day rollover in `ScheduleNotifier`: date-aware `hasScheduleToday`, lifecycle-observer refresh on resume, midnight seam matching `ThemeNotifier` (B2).
- Persistent "re-check-in / regenerate" entry point on Home + Schedule when a schedule exists (B6).
- Fix notification-tap navigation to use the go_router instance, not `pushNamed` (B4); schedule the morning notification on app start / onboarding-complete when enabled; guard Linux `zonedSchedule` (B4).
- Fix `GoalFormSheet` controller-in-build bug (1.2) — it blocks reliable goal entry, which Phase 3 depends on.
- **Runtime verification pass** of every B-item above on at least Linux desktop + one mobile target (this is also where my static findings get confirmed/falsified).
*Why first:* every other phase is invisible if the user's day starts with an empty or stale schedule.
*Size:* small-medium (~3-4 plans). High certainty, mostly wiring.

### Phase 2: A Schedule You Can Read
*Delivers:* a schedule list that communicates the plan.
- Chunk cards titled by **goal name** (goalId lookup), with rationale as secondary line; fix acknowledgment copy (B3).
- Honest rationales from real data: "Deadline in 3 days", "2.5h behind weekly target", "Streak: 12 days" (depends on Phase 3 for some inputs; ship static improvements now, dynamic strings in Phase 3).
- Coherent ordering: interleave discretionary chunks around anchored commitment blocks in time order; never insert breaks inside a contiguous commitment window; drop the trailing break (B5-ordering).
- Tap chunk → detail sheet (goal, why scheduled, complete/skip/defer actions) — the missing Phase 4 deliverable, and the natural home for "defer".
*Why:* legibility is the difference between a plan and a list of grey boxes.
*Size:* medium (~3-4 plans). Generator ordering changes need careful tests.

### Phase 3: An Engine That Budgets (the headline)
*Delivers:* rule-based generation that actually implements the PROJECT.md model. Pure Dart, TDD, deterministic.
- **Fill capacity:** multiple chunks per goal up to the mood cap, allocation policy per type (see Open Q2).
- **Time-target goals:** compute this week's completed hours from `CompletionLog`, schedule most-behind-budget first, chunk count proportional to remaining budget / remaining days (replaces the priorityWeight-only sort).
- **Habits:** respect `frequencyPerWeek` (schedule on N days/week, e.g. spread or user-pinned days); compute and persist `streakCount` from CompletionLog at completion time.
- **Outcome goals:** replace `chunksRemaining = 2.0` with an estimate from logged chunks vs. a new optional "estimated chunks" field, or deadline-pressure-only urgency (Open Q2).
- Wire the "Want a lighter day?" toggle (mood 1–2 already restricts to habits; toggle off = include deadline-critical outcome work).
- Surface a priority control (single 3-level chip: low/normal/high → priorityWeight) in the goal form, so "priority" exists at all.
*Why:* this is the product's core promise — "a schedule that reflects your real goals." Today it reflects only goal *count*.
*Size:* large (~5-6 plans). The one phase with real algorithm design; gated on Open Q2 answers.

### Phase 4: Close the Day
*Delivers:* an actual end to the daily loop.
- End-of-day entry on Home (time-aware card after ~6pm or ≥50% resolved) + optional evening reminder notification (opt-in, default per OQ-11) (B7).
- "Defer to tomorrow" action emitting `CompletionEvent.deferred`; deferred chunks influence next morning's generation (carry-in).
- Attribute commitment chunks in logs (use `commitment:<blockId>` or block name as goalId) so a workday isn't logged as `''` (B9, write side).
*Size:* small-medium (~2-3 plans).

### Phase 5: Honest Long Loop
*Delivers:* a quarterly review whose data is right and whose output matters.
- Aggregation/charts include commitment time and archived goals' history; fix donut total/slices (B9, read side).
- Make review priority adjustments feed the generator (map review order → priorityWeight tiers, or have the generator consume `sortOrder` as tiebreak + weight) so Phase 5 AC-4 finally holds (B8).
- Review loads goals itself (no dependency on a previously-visited tab).
*Size:* small (~2 plans).

**Sequencing:** 1 → 2 → 3 → 4 → 5. Phases 1–2 have no design unknowns and make the app daily-usable by themselves; do not let Phase 3 design discussion delay them. Phase 3 depends on Phase 1 (loaded data) and feeds Phase 2's dynamic rationales. Phases 4–5 are independent of each other after 3.

---

## 4. Scope Call (my honest recommendation)

**One milestone, five phases, medium-sized — commit firmly to Phases 1–3; treat 4–5 as same-milestone fast-follows.**

Reasoning:
- This is **not** a big rebuild. ~80% of the work is rewiring and finishing what exists; only Phase 3 contains genuine new design. The stack is sound; I found zero reasons to touch Hive/Provider/go_router.
- It also **cannot honestly be smaller** than Phases 1–3. Phase 1 alone fixes "broken" but leaves the engine fake — the owner would be back in three weeks saying the schedule doesn't reflect his goals, because it doesn't. The north star explicitly includes "reflects your real goals"; that's Phase 3.
- Resist scope creep *into* this milestone: chunk timers / active-session mode (see Q1), calendar sync, and anything LLM-flavored (v2 per PROJECT.md — the deterministic engine from Phase 3 becomes the auditable baseline an LLM layer could later explain itself against) stay out unless Q1 says otherwise.
- Estimated total: roughly comparable to v1.0's Phases 2+3 combined (~15-19 plans). With v1.0's observed plan velocity, that is a tractable single milestone.

---

## 5. Risks / Open Questions for the Owner

**Q1 — Is Canopy a checklist or a companion during the chunk?** (Biggest product question.) Today there is no timer, no "current chunk" state, no in-chunk experience at all — the day is a static list you swipe. The north star says "help you follow it through the day." v1.0 deliberately avoided timers *for breaks*, but never decided about work chunks. If you want a focus-session mode (start chunk → 25-min countdown → done → break suggestion), it should be designed into Phase 2/4 now, not bolted on. My read: a minimal "current chunk" highlight + optional timer is the single most companion-making feature available, but it's your call — it changes daily interaction cost.

**Q2 — Allocation policy for multiple chunks per goal (Phase 3 needs your answer):**
- Time-target: max chunks/day for one goal? (Proposal: `ceil(remaining weekly hours / days left this week / 25min)`, capped at 4/day.)
- Outcome: fixed 1–3 chunks by deadline pressure, or add an "estimated total chunks" field to the goal form? (Proposal: deadline-pressure-only; no new form field yet.)
- When capacity exceeds demand, leave it unscheduled (current 80% rule) or offer "bonus" chunks for top-priority goals? (Proposal: leave unscheduled — calmer.)

**Q3 — How should discretionary chunks relate to clock time?** v1.0 decided "no clock times on discretionary chunks" (good), but interleaving still needs a rule: schedule discretionary chunks before/after/between commitment blocks based on what assumption about your free time? (Proposal: simple day-order interleave — morning habits first, then fill around blocks in list order; no time math shown.)

**Q4 — Which platforms do you actually use daily?** Notification reliability differs wildly (Linux desktop: scheduled notifications likely unsupported; web: banner only). If your daily driver is Linux or web, Phase 1's notification work should pivot to an in-app "morning banner + autostart" pattern instead of chasing `zonedSchedule`. Tell me where you'll actually open the app each morning.

**Q5 — Streak semantics:** does a skipped habit day break the streak, or only a fully-missed day? And does `frequencyPerWeek < 7` mean streaks count weeks-met rather than consecutive days? (Proposal: streak = consecutive *scheduled* days completed; frequency-aware.)

**Risks:**
- **Static-analysis blind spots:** I could not execute the app or tests (no SDK here). A handful of findings (notification tap crash, Linux zonedSchedule, cursor-jump bug) are high-confidence but unverified at runtime — Phase 1 starts with a verification pass; if any finding is wrong, that phase shrinks, not grows.
- **Phase 3 calibration:** budget-driven allocation may produce schedules that *feel* wrong even when arithmetically right (e.g., 4 chunks of one goal). Mitigation: rationale strings expose the math (auditability is the product's differentiator), and the owner dogfoods from Phase 1 onward — calibrate before Phase 5.
- **Hive migration risk:** Phase 3/4 add fields (streak bookkeeping, deferred carry-in). The additive migration runner handles this, but schema bumps must stay additive-only per STATE.md conventions.

---

## Addendum — Runtime Verification Pass (2026-06-10)

Flutter **3.44.1** / Dart **3.12.1** (stable) installed on this machine; `flutter pub get` succeeded. This closes the original "no SDK" caveat.

**Results:**

| Check | Result |
|-------|--------|
| `flutter analyze` | Clean — 5 `info`-level deprecations only (`ReorderableListView.onReorder`, deprecated post-3.41; cosmetic) |
| `flutter test` | **90/90 pass** |
| Headline cold-launch bug | **CONFIRMED in source** (trace below) |

**Headline bug — confirmed trace:**
- `GoalsNotifier._goals` initializes to `[]` and is populated *only* by `loadGoals()` (`lib/providers/goals_notifier.dart:40`).
- `loadGoals()` is invoked from exactly one screen path: the Goals tab's post-frame callback (`lib/screens/goals/goals_screen.dart:24`) — plus internally after save/archive. Same pattern for `loadBlocks()` ↔ Commitments tab (`lib/screens/commitments/commitments_screen.dart:22`).
- The morning generator reads the in-memory list directly: `checkin_screen._generate()` passes `context.read<GoalsNotifier>().goals` / `…CommitmentsNotifier>().blocks` into `generateToday()` (`lib/screens/schedule/checkin_screen.dart:56-57`).
- ∴ Cold launch → Home → "Start your day" → mood, without ever visiting the Goals/Commitments tabs, generates from **empty lists**. Day 1 only works because onboarding's `saveGoal()` populates the notifier within that same session.

**Interpretation:** A green 90-test suite sitting next to a broken morning loop confirms the core thesis — the tests assert that widgets render, never that the daily product *works*. Phase 1's first task (a runtime verification pass) is validated as the right starting move; the SDK is now in place to do it on-device.
