import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/goal.dart';
import '../../../providers/goals_notifier.dart';
import '../../../widgets/preset_chip_grid.dart';
import 'goal_card.dart';

/// The eight common goals offered as one-tap chips (D-34-04).
///
/// **Deliberately hard-coded, and it stays that way** — same commitment as
/// `kCommonRestoratives` (`restoratives_screen.dart:9-17`). `CLAUDE.md`'s
/// product position is that Canopy is a dumb app on purpose, so this is a
/// literal list and not a query: no suggestion engine, no ranking, no
/// frequency- or recency-weighting, no personalisation, and no LLM call — now
/// or later. The eight names are `_goalPresets` unchanged, each gaining the
/// emoji shown in sketch 006. The wording is expected to be revised on the
/// owner's first sight of it, and that revision is cheap by construction —
/// one const, one file.
const List<(String name, String emoji)> kCommonGoals = [
  ('Exercise', '🏃'),
  ('Reading', '📚'),
  ('Family time', '👨‍👩‍👧'),
  ('Side project', '💻'),
  ('Learn something', '🌱'),
  ('Outdoors', '🌲'),
  ('Creative time', '🎨'),
  ('Rest', '😴'),
];

/// The sheet the goal door of the add-goal fork opens (D-34-01): a preset
/// grid that creates a goal immediately on tap, no confirmation and no
/// intermediate form, plus an escape hatch to the full `GoalFormSheet` for a
/// hand-typed name or to edit a goal just created this visit.
class GoalPresetPickerSheet extends StatefulWidget {
  const GoalPresetPickerSheet({
    super.key,
    required this.scrollController,
    this.isDialog = false,
    required this.onRequestForm,
  });

  final ScrollController scrollController;
  final bool isDialog;

  /// Called after this sheet has popped itself. A null [Goal] means "open a
  /// blank create-mode form" (Add your own); a non-null [Goal] means "open
  /// that goal's form in edit mode" (tapping a Just Added row).
  final void Function(Goal? goal) onRequestForm;

  @override
  State<GoalPresetPickerSheet> createState() => _GoalPresetPickerSheetState();
}

class _GoalPresetPickerSheetState extends State<GoalPresetPickerSheet> {
  final List<Goal> _justAdded = [];

  /// Trimmed-lowercased names optimistically claimed by a tap whose save has
  /// not resolved yet — checked alongside the notifier's own goals so the
  /// chip disappears in the same frame as the tap (UI-SPEC Decision 4), not
  /// only after the async save round-trips through `loadGoals()`.
  final Set<String> _claiming = {};

  void _requestForm(Goal? goal) {
    Navigator.of(context).pop();
    widget.onRequestForm(goal);
  }

  Future<void> _onCreate(
    GoalsNotifier notifier,
    String name,
    String emoji,
  ) async {
    // FIRST, synchronously: the chip is gone in the same frame as the tap.
    // This order is the contract (UI-SPEC Decision 4) — moving this after the
    // await reopens the double-tap window this decision exists to close.
    setState(() => _claiming.add(name.trim().toLowerCase()));

    final created = await notifier.addPresetGoal(name, emoji: emoji);

    if (!mounted) return;
    if (created != null) {
      setState(() => _justAdded.add(created));
    }
    // A null result (failed save) is ignored here — Task 3 replaces this
    // branch with a real failure path (restore the chip, show a SnackBar)
    // and its own test proves the replacement.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDialog =
        widget.isDialog || (ModalRoute.of(context) is DialogRoute);
    final notifier = context.watch<GoalsNotifier>();
    final existingNames = [
      ...notifier.goals.map((g) => g.name),
      ..._claiming,
    ];

    return SingleChildScrollView(
      controller: widget.scrollController,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          isDialog ? 24 : 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isDialog)
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            Text(
              'Add a goal',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            // UI-SPEC Decision 5: the heading and grid are omitted together
            // when zero presets remain unclaimed — this section renders
            // nothing at all rather than an empty heading over nothing.
            PresetChipGrid(
              presets: kCommonGoals,
              existingNames: existingNames,
              mode: PresetChipMode.createOnly,
              heading: 'Common',
              onCreate: (name, emoji) =>
                  _onCreate(context.read<GoalsNotifier>(), name, emoji),
            ),
            if (PresetChipGrid.unclaimed(
              kCommonGoals,
              existingNames,
            ).isNotEmpty)
              const SizedBox(height: 16),
            if (_justAdded.isNotEmpty) ...[
              Text('Just added', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              // "Just added" sits BELOW the grid, so the UI-SPEC's one named
              // hierarchy inversion ("Just added grows tall enough to push
              // the preset grid off screen") cannot occur here — the grid is
              // always above it in this scroll.
              for (final g in _justAdded)
                GoalCard(goal: g, onTap: () => _requestForm(g)),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}
