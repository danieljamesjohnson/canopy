import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/restorative_item.dart';
import '../../providers/restoratives_notifier.dart';

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
          final body = notifier.isEmpty
              ? _emptyState()
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: notifier.items.length,
                  itemBuilder: (ctx, i) {
                    final item = notifier.items[i];
                    return _RestorativeRow(
                      item: item,
                      onEdit: () => _openEditDialog(context, item),
                      onDelete: () => _confirmDelete(context, item),
                    );
                  },
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
