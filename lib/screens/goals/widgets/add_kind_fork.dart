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
Future<void> showRestorativeQuickAdd(BuildContext context) async {
  final notifier = context.read<RestorativesNotifier>();
  // Captured before the dialog opens: the dialog's own context is gone by the
  // time the confirmation is shown.
  final messenger = ScaffoldMessenger.of(context);
  final nameController = TextEditingController();
  final emojiController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  Future<void> submit(BuildContext dialogContext) async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    final name = nameController.text.trim();
    final emojiRaw = emojiController.text.trim();
    await notifier.saveItem(
      RestorativeItem(
        name: name,
        emojiTag: emojiRaw.isEmpty ? null : emojiRaw,
        sortOrder: notifier.items.length,
      ),
    );
    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
    messenger.showSnackBar(
      SnackBar(content: Text('Saved "$name" — a restorative, never scheduled.')),
    );
  }

  try {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add restorative'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'What restores you?',
                  hintText: 'e.g. Play guitar',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Give it a name' : null,
                onFieldSubmitted: (_) => submit(ctx),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: emojiController,
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
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(onPressed: () => submit(ctx), child: const Text('Add')),
        ],
      ),
    );
  } finally {
    nameController.dispose();
    emojiController.dispose();
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
