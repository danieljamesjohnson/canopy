import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/restorative_item.dart';
import '../../../providers/restoratives_notifier.dart';

/// The front-door fork that sits in front of the Goals FAB (UI-SPEC item 24),
/// and the name+emoji quick-add its second door leads to.
///
/// **Why the fork is at the front door.** Sketch 005 variant B won on
/// 2026-09-01 over two cheaper alternatives — an inline nudge that appears
/// *after* you pick "Gives energy" in the goal form, and a fourth option on the
/// goal form's energy control. Both were built, both were shown, and both were
/// rejected for the same reason: they put the escape hatch somewhere you must
/// already be inside a goal to find, which is the original friction wearing a
/// hat. Asking first makes the two kinds peers at the moment of entry. The cost
/// — one extra tap on every add, including the common case where the user did
/// just want a goal — is known and was accepted (UI-SPEC item 25).
///
/// **No new aggregate.** [RestorativeItem] (Hive typeId 7) is reused as-is; its
/// own class doc already describes this split. This is an entry-point change,
/// not a data-model change (UI-SPEC item 26).
///
/// **The quick-add below deliberately duplicates `restoratives_screen.dart`'s
/// `_openEditDialog` rather than reaching into it.** That method is
/// file-private and carries edit-mode branching this path does not want, and
/// this codebase's stated convention is file-local duplication over premature
/// sharing — recorded in three separate in-code charters
/// (`chunk_card.dart:810-815`, `free_time_row.dart:78-81`, and 33-PATTERNS
/// §"Container-role chips"). Do not "fix" this by extracting a shared dialog.
enum AddKind { goal, restorative }

/// Asks which kind of thing is being added, before any form exists.
///
/// Returns the chosen door, or null if the user dismissed or cancelled.
///
/// One dialog serves both breakpoints: the fork has no scroll needs, so this
/// follows `restoratives_screen.dart`'s established `showDialog<T>` +
/// branch-on-the-result shape rather than changing `showAdaptiveFormModal`'s
/// `Future<void>` return type.
Future<AddKind?> showAddKindFork(BuildContext context) {
  return showDialog<AddKind>(
    context: context,
    builder: (ctx) => AlertDialog(
      // A question that names the choice, not an instruction telling the user
      // what to do — so it survives the text policy (UI-SPEC item 29).
      title: const Text('What are you adding?'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DoorTile(
              icon: Icons.flag_outlined,
              title: 'Something to make time for',
              consequence:
                  'Gets a type, a weekly budget and a priority. Canopy '
                  'schedules it.',
              onTap: () => Navigator.of(ctx).pop(AddKind.goal),
            ),
            const SizedBox(height: 8),
            _DoorTile(
              // Matches the restoratives screen's own empty-state icon, so the
              // second door looks like where it leads.
              icon: Icons.spa_outlined,
              title: 'Something that restores you',
              consequence:
                  'Never scheduled. Never counted toward a budget or a streak.',
              onTap: () => Navigator.of(ctx).pop(AddKind.restorative),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

/// The restorative door's whole form: a required name and an optional emoji.
///
/// There is no goal form on this path at any point — that absence is the
/// promise each door makes, and it is pinned by
/// `test/screens/goals_add_fork_test.dart` (threat register T-33-12).
Future<void> showRestorativeQuickAdd(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => const _RestorativeQuickAddDialog(),
  );
}

/// The quick-add dialog's body, as a `StatefulWidget` so it owns and disposes
/// its two [TextEditingController]s.
///
/// The controllers must NOT be created in the `showDialog` builder closure and
/// disposed when the returned future completes: `showDialog`'s future resolves
/// the moment `Navigator.pop` is called, while the route is still running its
/// exit transition and still rebuilding the fields — which throws
/// `A TextEditingController was used after being disposed`. Observed here, not
/// theorised. `adaptive_form_modal.dart:55-67` records the same lesson for its
/// `ScrollController` (WR-01), and this is that fix applied to controllers that
/// are read during the exit frame.
class _RestorativeQuickAddDialog extends StatefulWidget {
  const _RestorativeQuickAddDialog();

  @override
  State<_RestorativeQuickAddDialog> createState() =>
      _RestorativeQuickAddDialogState();
}

class _RestorativeQuickAddDialogState
    extends State<_RestorativeQuickAddDialog> {
  final _nameController = TextEditingController();
  final _emojiController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _emojiController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    // Capture every provider/inherited ref BEFORE the await (Pitfall 6, as
    // stated in quarterly_review_screen.dart:73-75) — this route is popped
    // mid-method, so `context` is not safe to read afterwards.
    final notifier = context.read<RestorativesNotifier>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final name = _nameController.text.trim();
    final emojiRaw = _emojiController.text.trim();
    await notifier.saveItem(
      RestorativeItem(
        name: name,
        emojiTag: emojiRaw.isEmpty ? null : emojiRaw,
        sortOrder: notifier.items.length,
      ),
    );
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Saved "$name" — a restorative, never scheduled.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add restorative'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'What restores you?',
                hintText: 'e.g. Play guitar',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Give it a name' : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emojiController,
              decoration: const InputDecoration(
                labelText: 'Emoji (optional)',
                hintText: '🎸',
              ),
              maxLength: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}

/// One door of the fork: an icon, the door's name, and the one line of
/// consequence choosing it commits the user to (UI-SPEC item 27).
///
/// The consequence line is load-bearing, not decoration: sketch 005's "What to
/// Look For" #3 records that if the "not a goal" promise is not believed, the
/// feature does not work.
class _DoorTile extends StatelessWidget {
  const _DoorTile({
    required this.icon,
    required this.title,
    required this.consequence,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String consequence;
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      consequence,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
