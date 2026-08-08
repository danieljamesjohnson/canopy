# Requirements: Canopy — v1.5 "Right Now"

**Defined:** 2026-08-04
**Core Value:** Generate a usable daily schedule every morning — one that reflects your real goals and how you actually feel.
**Source:** Dan's dogfood pass on the hosted debug build (2026-08-04). Research skipped — every item lands on an existing surface.

## v1.5 Requirements

### Unified Today Screen

- [x] **UNIFY-01**: User sees what's happening now and the rest of the day on one screen, without switching tabs
- [x] **UNIFY-02**: Shell navigation reflects the merge, and every existing entry point (notification tap, in-app links to `/schedule`) lands on the unified screen rather than a dead route

### Live Activity Tracking

- [x] **LIVE-01**: The screen always names what the user is doing right now, including breaks — a running break reads as a break, never as empty time
- [x] **LIVE-02**: Time remaining in the current activity is shown and counts down while the screen is open
- [x] **LIVE-03**: The honest edge states survive the merge — before the day starts, between activities, and day-complete each read truthfully

### Mood-Scaled Breaks

- [x] **BREAK-01**: Chunks-before-a-long-break scales with the morning mood — roughly 2 on a low day, 5 on a sunny one — deterministically and unit-tested
- [x] **BREAK-02**: The 25-min chunk / 5-min short break interleave and the 25-min long break are preserved through the change

### Tone

- [x] **TONE-01**: No "behind this week" framing anywhere; a time-target goal's rationale reads as what the schedule is doing for the user, not as a deficit report

### Where Am I (added 2026-08-08 from UAT)

- [x] **NOW-01**: The timeline carries a visible now-marker at the current clock position, so the user can locate themselves by looking at the list rather than reading a header line rows away. Its position derives from the same clock sample `resolveNowState` uses — a position, never a second opinion about which activity is current.
- [x] **NOW-02**: A leading "Free until <time>" row never describes a window that has already closed.

### Time-Proportional Day (added 2026-08-08 from Phase 24 UAT)

- [ ] **CAL-01**: The day reads as a time-proportional surface — a row's height corresponds to its duration — so the shape of the day (a long stretch of work, a thin gap) is legible without reading any times.
- [ ] **CAL-02**: A continuously-positioned now-line sits at the true current moment, including *inside* an activity's span rather than only at chunk boundaries. This supersedes Phase 24's `Active`-state marker suppression, which exists only because a boundary-positioned marker would be mildly false mid-chunk.
- [ ] **CAL-03**: Elapsed time recedes: the past does not compete for the viewport with what is upcoming, and reaching it is a deliberate scroll rather than the default view.

## Implementation Notes

Known starting points, captured at definition time so planning doesn't re-derive them:

- `resolveNowState` (`lib/screens/home/home_screen.dart:115`) filters to **work chunks only** — this is why a running break is invisible to "now". Its five states (`PreStart`/`Active`/`Overdue`/`GapBeforeNext`/`DayComplete`) are the extension point for LIVE-01.
- The now-tick is a 1-minute `Timer.periodic` (`home_screen.dart:263`). LIVE-02's granularity (per-minute vs. per-second) is an open design choice for phase planning.
- Long-break cadence is a single constant: `final int longBreakEvery = isLowMood ? 3 : 4;` (`lib/services/schedule_generator.dart:220`). Three tests in `test/services/schedule_generator_test.dart` (~lines 492–543) assert the every-4 behavior and change with it.
- The "behind" string is `lib/services/schedule_generator.dart:190`; its sibling branch already reads "On track this week".
- Screens to merge: `lib/screens/home/home_screen.dart` (848 lines) and `lib/screens/schedule/schedule_screen.dart` (495 lines), plus their `widgets/` folders.
- `lib/widgets/responsive_shell.dart` hardcodes four destinations (Home/Goals/Schedule/Settings) and cites a UI-SPEC "icon library lock" — that contract is revisited by UNIFY-02.
- Notification taps route via `router.go('/schedule')` (`lib/main.dart:86`); `home_screen.dart:495` also navigates there.

## Future Requirements

Deferred — tracked, not in this roadmap.

- Start/stop focus timer per chunk (clock-in tracking, as opposed to the app simply reporting where you are). `/focus` exists; this milestone deliberately reads "active tracking" as the reporting sense.
- Drag-to-reorder restoratives (sortOrder is stored and honored; no reorder UI).
- Restoratives in onboarding — screen 4 flags goals as energy-giving but doesn't invite a first restorative.

## Out of Scope

- **LLM-powered scheduling / any in-app AI surface** — permanent product position, see PROJECT.md "Out of Scope".
- **Overnight / midnight-crossing commitments** — a tracked whole-app limitation, deliberately not folded into UI work.
- **Calendar sync** — v2 consideration, unrelated to this milestone.

## Traceability

Which phases cover which requirements. Populated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| UNIFY-01 | Phase 22 | Complete |
| UNIFY-02 | Phase 22 | Complete |
| LIVE-01 | Phase 23 | Complete |
| LIVE-02 | Phase 23 | Complete |
| LIVE-03 | Phase 23 | Complete |
| NOW-01 | Phase 24 | Complete |
| NOW-02 | Phase 24 | Complete |
| BREAK-01 | Phase 21 | Complete |
| BREAK-02 | Phase 21 | Complete |
| TONE-01 | Phase 21 | Complete |
| CAL-01 | Phase 25 | Not started |
| CAL-02 | Phase 25 | Not started |
| CAL-03 | Phase 25 | Not started |

**Coverage:**

- v1.5 requirements: 11 total
- Mapped to phases: 11 (100%)
- Unmapped: 0 ✓

---
*Requirements defined: 2026-08-04*
*Last updated: 2026-08-08 — CAL-01..03 added from Phase 24's UAT verdict*
