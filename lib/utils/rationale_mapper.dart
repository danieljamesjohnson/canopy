/// Maps the raw generator rationale string to a human-readable display string
/// per the READ-01 Rationale Strings table.
///
/// Phase 8 static mapping; Phase 9 replaces these with budget-driven dynamic
/// strings. Shared by the schedule screen, the chunk detail sheet, and the
/// focus screen so a chunk's rationale reads identically everywhere.
///
/// Commitment block names and any unknown values pass through unchanged.
String toDisplayRationale(String rationale) {
  switch (rationale) {
    case 'Habit':
      return 'Daily habit';
    case 'Outcome goal':
      return 'Working toward your goal';
    case 'Weekly goal':
      return 'Your weekly time goal';
    default:
      return rationale;
  }
}
