# Milestones

## v1.4 Energy-Aware (Shipped: 2026-06-15)

**Phases completed:** 3 phases, 12 plans, 24 tasks

**Key accomplishments:**

- Wave 0 RED test scaffolds for 5 requirements (RESP-01/02/03, POLISH-01/02) — three files covering dialog-vs-sheet routing, 720dp content-width constraints, and copy-label assertions
- showAdaptiveFormModal helper routing goal add/edit to Dialog at >= 720dp and BottomSheet at < 720dp via ModalRoute-aware GoalFormSheet
- CommitmentFormSheet gains isDialog param with ModalRoute fallback; commitment caller routes through showAdaptiveFormModal — completing the adaptive form migration for all user-facing forms
- Align(topCenter)+ConstrainedBox(maxWidth: 720dp) applied to Home, Goals, and Schedule screens — primary content no longer full-bleed at desktop widths
- POLISH-02 copy fixes applied: context-specific "Add Goal"/"Save Goal"/"Discard"/"Archive goal" in goal form, "Discard" TextButton added to commitment form, "Delete commitment"/"Keep commitment" in delete confirm — full suite 257/257 green, debug web bundle builds clean
- Five RED TDD test stubs locking the EnergyValence + emoji behavioral contract before any implementation begins: migration safety (neutral default), Hive round-trip (fields 12+13), goal form picker, goal card badge/emoji, chunk card chip/emoji, and onboarding Screen 4 completion
- Additive Hive migration adding EnergyValence enum and Goal fields 12/13 (energyValenceIndex, emojiTag) with schema bump 7→8, regenerated adapter (writeByte 14), and GREEN migration_schema8 test proving old-record-neutral compatibility
- Energy valence SegmentedButton (gives/neutral/costs) + 40-emoji tag picker added to GoalFormSheet, both persisted via _save() cascade — goal_form_valence_test.dart GREEN (ENERGY-02)
- _ValenceBadge on GoalCard title/secondary rows + _ValenceChip on ChunkCard with emoji prefix + two lookup helpers in ScheduleScreen — 14 valence tests GREEN (ENERGY-03b, ENERGY-04a, ENERGY-04b)
- Onboarding Screen 4 "What gives you energy?" seeds EnergyValence.gives on marked goals before first schedule via stable-ID pending-goal caching and a new _completeOnboarding step 3.5
- RED test suite for VSCHED-01/02/03 engine behaviors: 7 new test blocks added with `EnergyValence` valence param on existing helpers; VSCHED-01-outcome fails RED against unchanged engine
- 4 surgical edits to `lib/services/schedule_generator.dart` implement all three VSCHED behaviors — energy_valence import, gives-valence outcome gate, hoisted placedCountPerGoal + restorative floor pass, VSCHED-03 reservation pass — turning all 7 RED VSCHED tests GREEN with zero regressions across 288 total tests

---

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
