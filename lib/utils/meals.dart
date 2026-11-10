import '../data/models/commitment_block.dart';

/// Phase 37 — Three Meals, One Tap. The three meals, their defaults, and the
/// one validation rule they have. Shared by the onboarding meals beat and
/// Settings → Meals so both offer the same three rows (D-37-05).
///
/// Deliberately dumb (CLAUDE.md product position): fixed defaults, the same
/// times all seven days (D-37-02), no suggestions.

/// A meal shorter than this is not a meal (D-37-04). Also the floor below
/// which a meeting-carved piece of a meal is dropped (D-37-01). The 25-minute
/// lattice floor ([kMinCommitmentWindowMinutes]) does not apply to a meal: a
/// meal is one solid block with no lattice inside.
const int kMinMealMinutes = 10;

/// True when [startMinutes]→[endMinutes] is too short for a meal, or
/// inverted.
bool mealWindowTooShort(int startMinutes, int endMinutes) =>
    endMinutes - startMinutes < kMinMealMinutes;

/// Every day of the week, ISO 1=Mon..7=Sun (D-37-02).
const List<int> kAllWeekdays = [1, 2, 3, 4, 5, 6, 7];

enum MealSlot {
  breakfast(
    kind: CommitmentBlock.kindBreakfast,
    label: 'Breakfast',
    emoji: '🍳',
    defaultStart: 7 * 60,
    defaultEnd: 7 * 60 + 30,
  ),
  lunch(
    kind: CommitmentBlock.kindLunch,
    label: 'Lunch',
    emoji: '🥪',
    defaultStart: 12 * 60,
    defaultEnd: 13 * 60,
  ),
  dinner(
    kind: CommitmentBlock.kindDinner,
    label: 'Dinner',
    emoji: '🍝',
    defaultStart: 18 * 60,
    defaultEnd: 19 * 60,
  );

  const MealSlot({
    required this.kind,
    required this.label,
    required this.emoji,
    required this.defaultStart,
    required this.defaultEnd,
  });

  /// The [CommitmentBlock.kind] value that marks this meal.
  final String kind;
  final String label;
  final String emoji;
  final int defaultStart;
  final int defaultEnd;

  /// The slot a block's [CommitmentBlock.kind] names, or null when the block
  /// is not a meal.
  static MealSlot? fromKind(String? kind) {
    for (final s in MealSlot.values) {
      if (s.kind == kind) return s;
    }
    return null;
  }
}

/// One editable row of the meals editor: a meal, whether it is on, and its
/// window. Mutable on purpose — the editor owns three of these.
class MealDraft {
  MealDraft({
    required this.slot,
    this.enabled = true,
    int? startMinutes,
    int? endMinutes,
  }) : startMinutes = startMinutes ?? slot.defaultStart,
       endMinutes = endMinutes ?? slot.defaultEnd;

  final MealSlot slot;
  bool enabled;
  int startMinutes;
  int endMinutes;

  /// A switched-off meal is never invalid — it is not saved.
  bool get isValid => !enabled || !mealWindowTooShort(startMinutes, endMinutes);

  /// The three defaults, all switched on — what one tap saves.
  static List<MealDraft> defaults() => [
    for (final s in MealSlot.values) MealDraft(slot: s),
  ];

  /// Drafts reflecting the user's saved meal [blocks]. With no meals saved at
  /// all, this is [defaults] (so an existing user's first visit to Settings →
  /// Meals is the same one tap as onboarding). Otherwise a saved meal shows
  /// its own times, and a meal with no block shows switched off at its
  /// defaults.
  static List<MealDraft> fromBlocks(Iterable<CommitmentBlock> blocks) {
    final bySlot = <MealSlot, CommitmentBlock>{};
    for (final b in blocks) {
      final slot = MealSlot.fromKind(b.kind);
      if (slot != null) bySlot[slot] = b;
    }
    if (bySlot.isEmpty) return defaults();
    return [
      for (final s in MealSlot.values)
        bySlot[s] == null
            ? MealDraft(slot: s, enabled: false)
            : MealDraft(
                slot: s,
                startMinutes: bySlot[s]!.startMinutes,
                endMinutes: bySlot[s]!.endMinutes,
              ),
    ];
  }
}
