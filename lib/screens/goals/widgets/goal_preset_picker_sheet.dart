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
      // WR-03 (34-REVIEW.md): clear `_claiming` on the success path too, not
      // only on failure, so its actual behavior matches its doc comment —
      // "a tap whose save has not resolved yet." `notifier.goals` now
      // contains the goal too (addPresetGoal awaits loadGoals() before
      // returning), so the chip stays correctly hidden regardless; this is
      // belt-and-braces so a future in-sheet undo/archive can't be silently
      // defeated by a name stuck in `_claiming` forever.
      setState(() {
        _justAdded.add(created);
        _claiming.remove(name.trim().toLowerCase());
      });
    } else {
      // Ruling (a) buys its speed by removing the chip before the write
      // lands — that is what closes the double-tap race, and it is also
      // what makes a failure invisible: the user has already moved on, the
      // chip is gone, and nothing was saved. A silent swallow here
      // reproduces the "help" defect in a worse form — a goal the user
      // believes exists and does not.
      //
      // No "Just added" card is ever removed on this path because none is
      // ever added: the card is built from the Goal the notifier returns,
      // so a failed create produces nothing to undo. The invariant this
      // proves is the end state — chip present, zero cards, SnackBar shown —
      // not the mechanism.
      setState(() => _claiming.remove(name.trim().toLowerCase()));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save goal. Please try again.'),
        ),
      );
    }
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
            _AddYourOwnRow(onTap: () => _requestForm(null)),
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
            // An exit, not an objective (UI-SPEC visual hierarchy rank 4):
            // the goals are already real by the time this is visible, so
            // nothing here calls onRequestForm — closing the sheet is enough.
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The escape hatch to a hand-typed name (GOALADD-02, UI-SPEC Decision 2):
/// a full-width tappable row, copying `_DoorTile`'s shape — NOT a text field
/// wearing a new location. The control deleted 2026-09-08 was a `TextField`
/// that created a goal on submit with an unchosen budget; a bordered box with
/// placeholder text would be that same control in a new place. A hand-typed
/// name has no default anyone pre-agreed to, so it earns the full form rather
/// than another instant-create path.
class _AddYourOwnRow extends StatelessWidget {
  const _AddYourOwnRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.add, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Add your own',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
