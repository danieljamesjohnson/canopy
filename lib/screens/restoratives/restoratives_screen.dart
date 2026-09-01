import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/restorative_item.dart';
import '../../providers/restoratives_notifier.dart';

/// The nine common restoratives offered as one-tap chips (UI-SPEC item 22).
///
/// **Deliberately hard-coded, and it stays that way** (UI-SPEC item 23).
/// `CLAUDE.md`'s product position is that Canopy is a dumb app on purpose, so
/// this is a literal list and not a query: no suggestion engine, no ranking,
/// no frequency- or recency-weighting, no personalisation, and no LLM call —
/// now or later. The nine names come verbatim from sketch 005, which says out
/// loud that nine is a guess and that changing the guess is free precisely
/// because the list is hard-coded.
const List<(String name, String emoji)> kCommonRestoratives = [
  ('Walk outside', '🚶'),
  ('Music', '🎵'),
  ('Nap', '😴'),
  ('Stretch', '🧘'),
  ('Shower', '🚿'),
  ('Read', '📖'),
  ('Tea or coffee', '☕'),
  ('Call someone', '📞'),
  ('Sit in the sun', '🌞'),
];

/// Manage the user's restorative activities — the things that recharge them,
/// kept deliberately separate from goals. These never get scheduled; they only
/// resurface as gentle suggestions on low-energy days.
class RestorativesScreen extends StatefulWidget {
  const RestorativesScreen({super.key});

  @override
  State<RestorativesScreen> createState() => _RestorativesScreenState();
}

class _RestorativesScreenState extends State<RestorativesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<RestorativesNotifier>().loadItems(),
    );
  }

  Future<void> _openEditDialog(BuildContext context, [RestorativeItem? item]) {
    final notifier = context.read<RestorativesNotifier>();
    final nameController = TextEditingController(text: item?.name ?? '');
    final emojiController = TextEditingController(text: item?.emojiTag ?? '');
    final isEditing = item != null;
    final formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? 'Edit restorative' : 'Add restorative'),
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
                  hintText: 'e.g. Listen to music',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Give it a name' : null,
                onFieldSubmitted: (_) => _submit(
                  ctx,
                  notifier,
                  formKey,
                  item,
                  nameController,
                  emojiController,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: emojiController,
                decoration: const InputDecoration(
                  labelText: 'Emoji (optional)',
                  hintText: '🎵',
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
          FilledButton(
            onPressed: () => _submit(
              ctx,
              notifier,
              formKey,
              item,
              nameController,
              emojiController,
            ),
            child: Text(isEditing ? 'Save' : 'Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(
    BuildContext dialogContext,
    RestorativesNotifier notifier,
    GlobalKey<FormState> formKey,
    RestorativeItem? existing,
    TextEditingController nameController,
    TextEditingController emojiController,
  ) async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    final name = nameController.text.trim();
    final emojiRaw = emojiController.text.trim();
    final emoji = emojiRaw.isEmpty ? null : emojiRaw;

    if (existing != null) {
      existing
        ..name = name
        ..emojiTag = emoji;
      await notifier.saveItem(existing);
    } else {
      await notifier.saveItem(
        RestorativeItem(
          name: name,
          emojiTag: emoji,
          sortOrder: notifier.items.length,
        ),
      );
    }
    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
  }

  Future<void> _confirmDelete(
    BuildContext context,
    RestorativeItem item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove restorative?'),
        content: Text(item.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<RestorativesNotifier>().deleteItem(item.id);
    }
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.spa_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Nothing here yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Add the small things that recharge you — like listening to '
              'music or a walk. These aren\'t goals; they only resurface on '
              'low-energy days, when you need them most.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('What restores you')),
      body: Consumer<RestorativesNotifier>(
        builder: (ctx, notifier, _) {
          // One ListView across both states, not an `isEmpty ? … : …` split:
          // the quick-pick grid matters MOST when the list is empty, which is
          // the case the FAB-and-dialog flow made expensive (UI-SPEC item 22).
          final body = ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              _QuickPickSection(notifier: notifier),
              if (notifier.isEmpty)
                _emptyState()
              else
                ...notifier.items.map(
                  (item) => _RestorativeRow(
                    item: item,
                    onEdit: () => _openEditDialog(context, item),
                    onDelete: () => _confirmDelete(context, item),
                  ),
                ),
            ],
          );
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: body,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add restorative'),
      ),
    );
  }
}

/// The one-tap quick-pick grid that sits above the list (UI-SPEC item 22):
/// tapping an unselected chip adds that restorative with its emoji, tapping a
/// selected one removes it.
///
/// These are Material [FilterChip]s rather than the `_ValenceBadge`-style
/// `Container` chips used elsewhere in this codebase, and the difference is not
/// cosmetic: those chips are display-only badges, while a quick-pick chip **is**
/// tappable and needs a real tap target carrying its own selected/unselected
/// semantics. 33-PATTERNS §5 draws exactly that line between the two families.
///
/// Every chip is glyph **plus** word — never a bare glyph (UI-SPEC item 30,
/// which is the same rule as item 2). An emoji-only chip would recreate the
/// unlabelled-circle defect this phase exists to remove.
class _QuickPickSection extends StatelessWidget {
  const _QuickPickSection({required this.notifier});

  final RestorativesNotifier notifier;

  /// The already-saved item matching [name], or null. Case-insensitive on the
  /// trimmed name so a hand-typed "music" and the `Music` chip are one thing,
  /// using the `.where(...).firstOrNull` lookup idiom this codebase already
  /// uses for id/name matching (`goals_notifier.dart:150`).
  RestorativeItem? _matchFor(String name) {
    final needle = name.trim().toLowerCase();
    return notifier.items
        .where((i) => i.name.trim().toLowerCase() == needle)
        .firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Common', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (name, emoji) in kCommonRestoratives)
                _buildChip(name, emoji),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String name, String emoji) {
    final match = _matchFor(name);
    return FilterChip(
      avatar: Text(emoji),
      label: Text(name),
      selected: match != null,
      onSelected: (selected) {
        if (selected) {
          // saveItem, NOT quickAddItems: the bulk helper sets no emoji and
          // these chips carry one, so a chip-added item would otherwise fall
          // back to the generic 🌿 in the row below.
          notifier.saveItem(
            RestorativeItem(
              name: name,
              emojiTag: emoji,
              sortOrder: notifier.items.length,
            ),
          );
        } else if (match != null) {
          // No confirmation dialog on purpose. One tap adds, one tap removes
          // (UI-SPEC item 22) — a confirm on a toggle would defeat the item,
          // and re-adding costs exactly one tap. The heavier `_confirmDelete`
          // stays on the list rows below, which can hold user-typed items the
          // chips cannot restore (threat register T-33-11).
          notifier.deleteItem(match.id);
        }
      },
    );
  }
}

/// One row in the restoratives list. Mirrors the commitments row: on desktop
/// the edit + delete icons fade in on hover; on mobile the delete IconButton is
/// always visible (hover never fires on touch).
class _RestorativeRow extends StatefulWidget {
  const _RestorativeRow({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final RestorativeItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_RestorativeRow> createState() => _RestorativeRowState();
}

class _RestorativeRowState extends State<_RestorativeRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isMobileTouch =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    final emoji = widget.item.emojiTag;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: widget.onEdit,
        onHover: (hovered) => setState(() => _hovered = hovered),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  (emoji != null && emoji.isNotEmpty) ? emoji : '🌿',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.item.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (isMobileTouch)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remove',
                  onPressed: widget.onDelete,
                )
              else
                AnimatedOpacity(
                  opacity: _hovered ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit',
                        onPressed: _hovered ? widget.onEdit : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remove',
                        onPressed: _hovered ? widget.onDelete : null,
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
