# Canopy — Roadmap

**Created:** 2026-02-24
**Last updated:** 2026-08-14 (v1.5 shipped and archived)

## Milestones

- ✅ **v1.0 — Core Product Loop** — Phases 1-6 (shipped)
- ✅ **v1.1 — Actually Daily** — Phases 7-11 (shipped)
- ✅ **v1.2 — Make It Usable** — Phases 12-14 (shipped 2026-06-13)
- ✅ **v1.3 — An Honest Day** — Phases 15-17 (shipped 2026-06-14)
- ✅ **v1.4 — Energy-Aware** — Phases 18-20 (shipped 2026-06-15)
- ✅ **v1.5 — Right Now** — Phases 21-26 (shipped 2026-08-14)

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

<details>
<summary>✅ v1.5 Right Now (Phases 21-26) — SHIPPED 2026-08-14</summary>

**Milestone Goal:** Make Canopy answer "what am I doing right now?" in one place — and stop telling
the user they're behind.

- [x] Phase 21: Mood-Scaled Breaks & Honest Rationale (2/2 plans) — BREAK-01/02, TONE-01
- [x] Phase 22: Unified Today Screen (4/4 plans) — UNIFY-01/02
- [x] Phase 23: Live Activity Tracking (8/8 plans) — LIVE-01/02/03
- [x] Phase 24: Where Am I (4/4 plans) — NOW-01/02
- [x] Phase 25: Time Travel (1/1 plan) — DEV-01/02/03
- [x] Phase 26: The Day Has a Shape (10/10 plans) — CAL-01/02/03

Full detail archived in `.planning/milestones/v1.5-ROADMAP.md`. 16/16 requirements satisfied,
browser-verified; 560/560 tests green. See `v1.5-MILESTONE-AUDIT.md`.

</details>

### Phase 27: True Grid

Standalone phase, no milestone. Raised during post-v1.5 UAT of the Today timeline; small enough
that it did not justify opening v1.6 (owner's call, 2026-08-18).

**Goal:** Every hour on the Today timeline occupies the same vertical distance, always — an hour is an hour, whatever is happening inside it.

**The defect.** `TimelineGeometry.yFor()` is linear except for one term
(`timeline_geometry.dart`): `offset += liveExtraPx` once the minute passes `liveEndMinutes`.
`liveExtraPx = kLiveRowReservedHeight − (liveDuration × kPixelsPerMinute)` = `232 − 100` = **132dp**
for a standard 25-minute chunk. So the hour containing the live chunk's end renders 240 + 132 =
**372dp against every other hour's 240dp — 55% taller.** Confirmed against a UAT screenshot
(2026-08-18): the 9→10 and 10→11 brackets measure 242.5dp and 377.5dp, matching the arithmetic to
within antialiasing. Exactly one hour per day is wrong, and only while a chunk is live.

**The tension to resolve.** That term exists to let `LiveRowCard` swell — CAL-01's one named
exception, "let now break the grid" (22-UI-SPEC.md), which the owner asked for in Phase 22 UAT
("makes it to where I am doesn't just jump off the page"). A 25-minute slot is 100dp; the live card
needs ~200dp. A true grid and a variable-height live row cannot both hold. **This phase decides
which, and that decision is the phase — not the deletion, which is one line.**

Options carried in: (a) live card fits its slot, distinguished by fill / square corners / the
now-line, as Google Calendar does — cleanest code, ends the swell; (b) shrink the live card toward
its slot so the exception is small rather than absent — half-measure, grid still not true;
(c) keep the swell, close this as won't-fix.

**Build vs. buy — settled, revisit only on new evidence.** pub.dev was searched 2026-08-18.
[`kalender`](https://pub.dev/packages/kalender) is credible (MIT, all six platforms, 160/160 pub
points, 42.6k downloads, actively maintained, custom event model, uniform hour grid, replaceable
time indicator). Recommendation is still **in-house**: the defect is one term, and Canopy's
timeline is not an event list — free/gap regions are the *absence* of events, density tiers are
driven by slot height, and untimed chunks render outside the grid entirely. Adopting a 0.x calendar
package to fix a one-line special case trades a small defect for a large dependency. **This flips
if drag-to-reschedule, week/multi-day views, or timezones enter scope** — then `kalender` is doing
work we would otherwise write.

**Requirements:** GRID-01 (uniform hour spacing), GRID-02 (live-row prominence without variable
height)
**Depends on:** Phase 26 (The Day Has a Shape) — owns `TimelineGeometry` and the now-line
**Plans:** 0 plans

Plans:

- [ ] TBD (run `/gsd-plan-phase 27` to break down)

**Also open on this surface, fold in or split as planning decides:**

- The schedule screen's `detailed` tier was never compacted (only Today's `full` tier was).
- Free regions and break rows now render near-identical dashed outlines, distinguished only by
  label — deliberate, but unreviewed.
- `kGutterWidth` at 40dp leaves ~4dp of text-scale slack ("11 AM" measures 36dp); large
  accessibility text sizes will clip there first.

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
| 21-26 (Right Now) | v1.5 | 28/28 | Complete   | 2026-08-14 |
| 27. True Grid | — (standalone) | 0/0 | Not started | — |
