# Milestones

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
