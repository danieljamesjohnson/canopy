# Milestones

## v1.3 An Honest Day (Shipped: 2026-06-14)

**Phases completed:** 3 phases (15-17), 4 plans, 9 tasks
**Requirements:** 9/9 satisfied (CAP-01, STREAK-01, PRIORITY-02/03, FILL-01/02, NOW-01/02, GOALFORM-02)
**Tests:** 247/247 passing · `flutter analyze` clean · all 9 requirements browser-verified (hosted debug web build)
**Git range:** `test(15-01)` → `v1.3` · lib +729/−325, tests +1983/−302

**Delivered:** Made the scheduling engine tell the truth and use the whole day — fair capacity, honest streaks, priority that drives all goal types, regular-time fills open days, and a time-anchored Home.

**Key accomplishments:**

- **CAP-01 — fair capacity sharing:** Habit ceiling (`ceil(cap/2)`) in the allocation Step 2 so habits can't monopolize the discretionary cap on low-mood days; outcomes and time-targets get a fair share.
- **PRIORITY-02 — priority drives all goal types:** Multi-chunk priority demand for habits AND outcomes (previously time-target only) — raising priority measurably increases chunk count for every goal type.
- **FILL-01 / FILL-02 — fill the day:** Always-run round-robin Step 4 fills open days with time-target goals, distributed by priority and bounded by the mood cap, so no single goal swallows an empty day.
- **STREAK-01 — honest streaks:** Generation-time streak write-back so the displayed streak always equals the computed backward due-day walk — no divergence possible.
- **PRIORITY-03 / GOALFORM-02 — reconciled priority model:** Drag-reorder and the Low/Normal/High selector write one coherent `priorityWeight`; the chip stays correct after a drag, with true-modal-height reachability tests proving Priority + Save are reachable for all three goal types.
- **NOW-01 / NOW-02 — time-anchored Home:** `resolveNowState` sealed hierarchy + 1-min timer drive Now/Next from the chunk whose clock window contains the actual current time, with honest pre-start and day-complete states.

**Known deferred items (non-blocking):** F-03 desktop goal-form layout (routed to next milestone), FILL-02 high-priority monopoly edge (documented-accepted), Nyquist VALIDATION frontmatter drafts (tests green; metadata only). See STATE.md Deferred Items.

---

## v1.2 Phases (Shipped: 2026-06-13)

**Phases completed:** 3 phases, 7 plans, 4 tasks

**Key accomplishments:**

- Added `@HiveField(10) int? syntheticStartMinutes` with `displayStartMinutes` getter and no-op `_migration6to7` to bump schema from 6 to 7, enabling discretionary chunk clock times to survive app restart.
- Fixed post-onboarding router redirect to /home, added _formatTimeRange clock-time display and always-visible Complete/Skip buttons in ChunkCard, and created NowMarker widget inserted before the first unresolved work chunk in ScheduleScreen.
- Created ActiveChunkCard with "Now" badge and always-visible Complete/Skip buttons; refactored HomeScreen to Now/Next layout with currentChunk/nextChunk split, relocated mood row, and "See full schedule" TextButton (NAV-02).
- CHECKIN-01: Luminance-adaptive contrast + emoji hover/pressed states
- GoalTypePicker _TypeCard compacted from ~168dp to ~92dp in test env (~64dp on real device) via contentPadding(h:12,v:6) + minVerticalPadding:0, freeing Priority + Save from being clipped off-screen
- Replaced the inline `GoalType.habit` filter inside the `activeGoals` loop with a pre-filtered, priority-sorted `habitGoals` list. High-priority habits (0.75) now fill the discretionary cap before low-priority habits (0.25). The cap-check guard and due-weekday guard are unchanged.

---
