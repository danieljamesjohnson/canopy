---
gsd_state_version: 1.0
milestone: v1.5
milestone_name: Right Now
status: planning
last_updated: "2026-08-04T00:00:00.000Z"
last_activity: 2026-08-04
progress:
  total_phases: 3
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Execution State

**Project:** Canopy
**Created:** 2026-02-24
**Last session:** 2026-08-04

---

## Current Position

Phase: 21 — Mood-Scaled Breaks & Honest Rationale (Not started)
Plan: —
Status: Roadmap defined; ready to plan Phase 21
Last activity: 2026-08-04 — v1.5 roadmap created (3 phases: 21-23)

```
Progress: [░░░░░░░░░░] 0% — Phase 21/23
```

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-08-04)

**Core value:** Generate a usable daily schedule every morning — one that reflects your real goals and how you actually feel.
**Current focus:** v1.5 "Right Now" — merge Home/Schedule, live activity tracking, mood-scaled breaks, drop "behind" framing

## v1.5 Phase Summary

| Phase | Goal | Requirements | Status |
|-------|------|--------------|--------|
| 21 — Mood-Scaled Breaks & Honest Rationale | Break cadence scales with mood; time-target rationale drops "behind" framing | BREAK-01/02, TONE-01 | Not started |
| 22 — Unified Today Screen | Home and Schedule merge into one destination; every entry point still resolves | UNIFY-01/02 | Not started |
| 23 — Live Activity Tracking | The unified screen always names the current activity, including breaks, with a live countdown | LIVE-01/02/03 | Not started |

## Accumulated Context

### Decisions

Key decisions are in PROJECT.md. Decisions relevant to v1.5:

- [v1.5 roadmap]: Phase 21 (engine + copy) is parallel-safe with Phase 22 (screen merge) — no shared surface, so either can run first.
- [v1.5 roadmap]: Phase 23 (live activity tracking) sequenced after Phase 22 (unified screen) — the live readout is layered onto the merged screen's now-state rather than built against the soon-to-be-replaced split Home/Schedule screens.
- [v1.5 roadmap]: LIVE-02's tick granularity (per-minute vs. per-second) deliberately left open — flagged for Phase 23 planning to decide and justify, not inherited silently from the existing 1-min `Timer.periodic`.
- [Phase 14-02]: Priority drives composite score (remainingHours × priorityWeight) for time-targets; habit sort pre-filtered by priority.
- [Phase 19-energy-valence]: EnergyValence is a plain Dart enum with no @HiveType — stored as int index in Goal.energyValenceIndex (HiveField 12) — Follows existing GoalType/ChunkType pattern; no new typeId needed; neutral=0 ensures old records read correctly via getter default.
- [Phase ?]: Align(topCenter)+ConstrainedBox(maxWidth: 720) applied to Home, Goals, Schedule body content for POLISH-01 — relevant precedent for whatever layout Phase 22's merged screen uses.
- [Phase ?]: Valence colors: tertiaryContainer for gives, secondaryContainer for costs — colorScheme.error excluded per UI-SPEC.

### Engine Constraints (carry-forward for Phase 21)

- Rule-based only — no LLM
- Hive migrations are additive-only (new fields with defaults, never remove/rename)
- Long-break cadence is currently a single constant: `final int longBreakEvery = isLowMood ? 3 : 4;` (`lib/services/schedule_generator.dart:220`) — BREAK-01 replaces this with a `_moodBreakCadence` lookup keyed on `moodIndex`; mapping locked during Phase 21 planning at `{1:2, 2:3, 3:4, 4:4, 5:5}`
- **CORRECTED 2026-08-07:** the earlier note that "three existing tests (~lines 492–543) assert the every-4 cadence and must change" is **stale and wrong**. 21-RESEARCH.md verified empirically (patched the constant, ran the suite) that all 54 tests in `test/services/schedule_generator_test.dart` pass unchanged under the new mapping. There is currently **zero** test coverage that discriminates cadence behavior — so the new tests are the substance of Phase 21, not a formality. Lines 492–543 today are the WR-01 test (mood=3), which is cadence-insensitive.
- The "behind" string lives at `lib/services/schedule_generator.dart:190`; its sibling branch already reads "On track this week" — use that framing as the model
- Schedule generator lives in `lib/services/schedule_generator.dart` — deterministic, covered by unit tests

### UI Constraints (carry-forward for Phase 22/23)

- `resolveNowState` (`lib/screens/home/home_screen.dart:115`) filters to work chunks only — extension point for LIVE-01, currently makes a running break invisible to "now"
- Now-tick is a 1-minute `Timer.periodic` (`home_screen.dart:263`) — LIVE-02 open design decision, see above
- `lib/widgets/responsive_shell.dart` hardcodes four destinations (Home/Goals/Schedule/Settings) citing a UI-SPEC "icon library lock" — UNIFY-02 revisits this contract
- Notification taps route via `router.go('/schedule')` (`lib/main.dart:86`); `home_screen.dart:495` also navigates there — both must land on the unified screen after Phase 22, not a dead route
- Screens to merge: `lib/screens/home/home_screen.dart` (848 lines) and `lib/screens/schedule/schedule_screen.dart` (495 lines), plus their `widgets/` folders

### Blockers / Concerns

None.

## Deferred Items

Items acknowledged and deferred at milestone close on 2026-06-15 (v1.4) — carried forward, not yet routed to v1.5 (out of this milestone's scope per REQUIREMENTS.md Future Requirements / Out of Scope):

| Category | Item | Status |
|----------|------|--------|
| todo | Onboarding screens full-bleed at desktop width | Candidate for future polish phase — not in v1.5 scope |
| todo | Onboarding commitment-step day chips ambiguous (M/T/W/T/F/S/S) | Candidate for future polish phase — not in v1.5 scope |
| tech-debt | FILL-02 high-priority monopoly edge | documented-accepted (3+ goals at weight ≥0.75 can starve lower-priority time-targets) |
| tech-debt | Nyquist VALIDATION frontmatter drafts (15/16/17) | tests green; `nyquist_compliant: false` metadata only |
| tech-debt | chunk_card.dart hardcoded `Colors.green.shade600` / `Colors.grey.shade400` | pre-existing, bypasses ColorScheme (no dark-mode/dynamic adapt) — worth revisiting if Phase 22/23 touch chunk_card.dart anyway |
| product | Start/stop focus timer per chunk (clock-in tracking) | deferred — see REQUIREMENTS.md Future Requirements |
| product | Drag-to-reorder restoratives | deferred — see REQUIREMENTS.md Future Requirements |
| product | Restoratives in onboarding (screen 4 invite) | deferred — see REQUIREMENTS.md Future Requirements |

Carried from earlier milestones (v1.0–v1.2), still open:

| Category | Item | Status |
|----------|------|--------|
| uat | Phase 12 12-UAT.md | testing — 5 pending visual scenarios |
| uat | Phase 13 13-UAT.md | testing — 8 pending visual scenarios |
| uat | Phase 14 14-UAT.md | testing — 4 pending visual scenarios |
| uat | Phases 04/05/06/09/10/11 UAT | carried over from v1.0/v1.1 |
| verification | Phases 01/06/07/09/10/11/12/13/14 | human visual sign-off pending |

## Quick Tasks Completed

| Date | Slug | Outcome |
|------|------|---------|
| 2026-06-14 | fix-stale-hive-data-startup-crash | Resilient Hive box open — incompatible old-version data is reset instead of blanking the app at startup. `.planning/quick/20260614-fix-stale-hive-data-startup-crash/` |

## Session Continuity

Last session: 2026-08-04
Stopped at: v1.5 roadmap created
Resume at: `/gsd-plan-phase 21`

## Performance Metrics

| Phase | Plan | Duration | Notes |
|-------|------|----------|-------|
| Phase 15-engine-honesty P01 | 6 | 3 tasks | 2 files |
| Phase 15-engine-honesty P02 | 230 | 1 tasks | 2 files |
| Phase 16-priority-model-reconciliation P01 | 25 | 2 tasks | 2 files |
| Phase 17-time-anchored-home P01 | 7 | 3 tasks | 3 files |
| Phase 18-responsive-modals-and-desktop-polish P02 | 3 | 2 tasks | 3 files |
| Phase 18-responsive-modals-and-desktop-polish P03 | 3min | 1 tasks | 2 files |
| Phase 18-responsive-modals-and-desktop-polish P04 | 20min | 2 tasks | 3 files |
| Phase 18-responsive-modals-and-desktop-polish P05 | 25 | 2 tasks | 4 files |
| Phase 19-energy-valence P01 | 6 | 2 tasks | 5 files |
| Phase 19-energy-valence P02 | 5min | 2 tasks | 6 files |
| Phase 19-energy-valence P04 | 4 | 2 tasks | 4 files |
| Phase 19-energy-valence P05 | 15min | 2 tasks | 2 files |
| Phase 20-valence-aware-engine P01 | 2min | 2 tasks | 1 files |
| Phase 20-valence-aware-engine P02 | 3min | 3 tasks | 1 files |
