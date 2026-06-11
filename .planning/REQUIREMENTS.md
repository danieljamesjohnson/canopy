# Canopy — Requirements

**Milestone:** v1.1 "Actually Daily"
**Created:** 2026-06-10
**Source:** `.planning/NEXT-MILESTONE-PROPOSAL.md` (reality check + runtime-verified evidence)

Rule-based only — no LLM in this milestone. All requirements are user-observable capabilities that close the gap between v1.0's "complete on paper" state and a genuinely usable daily companion.

---

## Milestone v1.1 Requirements

### Loop — Unbreak the Morning (LOOP)

- [ ] **LOOP-01**: The morning check-in always generates today's schedule from the user's actual saved goals and commitments — on any cold launch or resume, regardless of which tabs were visited first.
- [ ] **LOOP-02**: The schedule rolls over at the day boundary — resuming the app on a new day shows a fresh, un-generated day rather than yesterday's schedule.
- [ ] **LOOP-03**: The user can re-run the check-in / regenerate today's schedule from a persistent entry point on Home and on the Schedule screen when a schedule already exists.
- [ ] **LOOP-04**: When morning notifications are enabled, the notification is scheduled automatically (on app start / after onboarding) and tapping it opens the schedule via the correct router.
- [ ] **LOOP-05**: The user can reliably enter and edit a goal in the goal form (no cursor/controller defect).

### Read — A Schedule You Can Read (READ)

- [x] **READ-01**: Each scheduled chunk displays its goal's name as the title, with the rationale as secondary text.
- [x] **READ-02**: Chunks are ordered coherently in day order around anchored commitment blocks; breaks never appear inside a commitment window, and there is no dangling trailing break.
- [x] **READ-03**: Tapping a chunk opens a detail sheet showing the goal, why it was scheduled, and complete / skip / defer actions.
- [x] **READ-04**: A minimal companion focus mode highlights the current chunk with an optional 25-minute countdown that flows into completion and a break suggestion. *(Owner decision: companion mode in scope; designed here, completion loop closed in CLOSE.)*

### Engine — An Engine That Budgets (ENGINE)

- [x] **ENGINE-01**: Schedule generation fills the mood capacity with multiple chunks per goal up to the mood cap, rather than one chunk per goal.
- [x] **ENGINE-02**: Time-target goals receive chunks proportional to how far behind their weekly hour budget they are (computed from CompletionLog; most-behind first; capped per accepted allocation policy).
- [x] **ENGINE-03**: Habits respect `frequencyPerWeek` (scheduled on the right number of days) and accrue a real `streakCount` computed from completion history.
- [x] **ENGINE-04**: Outcome goals are scheduled by deadline pressure, replacing the hardcoded `chunksRemaining = 2.0` placeholder.
- [x] **ENGINE-05**: The "Want a lighter day?" toggle measurably reduces the discretionary schedule.
- [x] **ENGINE-06**: The user can set a goal's priority (low / normal / high) in the goal form, and that priority influences scheduling.

### Close — Close the Day (CLOSE)

- [x] **CLOSE-01**: A discoverable end-of-day moment (time-aware Home card after ~6pm or once ≥50% of chunks are resolved) summarizes the day, with an optional opt-in evening reminder.
- [x] **CLOSE-02**: The user can defer a chunk to tomorrow, and deferred chunks carry into the next morning's generation.
- [x] **CLOSE-03**: Commitment chunks are attributed in completion logs (not recorded with an empty goal id).

### Review — Honest Long Loop (REVIEW)

- [ ] **REVIEW-01**: The quarterly review's aggregation and charts count all logged time correctly, including commitment time and archived goals' history, with correct donut totals.
- [ ] **REVIEW-02**: Priority adjustments made during the review demonstrably change subsequent schedule generation.
- [ ] **REVIEW-03**: The review loads its own data independently, with no dependency on a previously-visited tab.

---

## Future Requirements (deferred)

- LLM-assisted scheduling and conversational re-planning (v2 — the deterministic engine from this milestone becomes the auditable baseline).
- Calendar sync (Google Calendar, etc.).
- User-pinned specific days/times for habits and commitments beyond simple frequency.
- "Bonus" overflow chunks when capacity exceeds demand (current policy: leave unscheduled for a calmer day).

## Out of Scope (this milestone)

- Any AI/LLM API dependency — explicitly excluded; the milestone proves the rule-based core first.
- Backend / multi-device sync — local Hive storage only.
- Re-architecture of the stack — Hive / Provider / go_router are sound; this milestone is rewiring and finishing, not rebuilding.
- Multi-user / team features — personal tool only.

---

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| LOOP-01 | Phase 7 | Pending |
| LOOP-02 | Phase 7 | Pending |
| LOOP-03 | Phase 7 | Pending |
| LOOP-04 | Phase 7 | Pending |
| LOOP-05 | Phase 7 | Pending |
| READ-01 | Phase 8 | Complete |
| READ-02 | Phase 8 | Complete |
| READ-03 | Phase 8 | Complete |
| READ-04 | Phase 8 | Complete |
| ENGINE-01 | Phase 9 | Complete |
| ENGINE-02 | Phase 9 | Complete |
| ENGINE-03 | Phase 9 | Complete |
| ENGINE-04 | Phase 9 | Complete |
| ENGINE-05 | Phase 9 | Complete |
| ENGINE-06 | Phase 9 | Complete |
| CLOSE-01 | Phase 10 | Complete |
| CLOSE-02 | Phase 10 | Complete |
| CLOSE-03 | Phase 10 | Complete |
| REVIEW-01 | Phase 11 | Pending |
| REVIEW-02 | Phase 11 | Pending |
| REVIEW-03 | Phase 11 | Pending |

---
*Open detail-level questions deferred to discuss-phase for the Engine phase: discretionary↔clock interleave rule (proposal default: simple day-order interleave) and streak semantics (proposal default: consecutive scheduled days completed, frequency-aware).*
