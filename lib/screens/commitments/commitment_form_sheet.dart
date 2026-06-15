import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/commitment_block.dart';
import '../../providers/commitments_notifier.dart';

class CommitmentFormSheet extends StatefulWidget {
  const CommitmentFormSheet({
    super.key,
    required this.scrollController,
    this.block,
    this.isDialog = false,
  });

  final ScrollController scrollController;
  final CommitmentBlock? block;
  final bool isDialog;

  @override
  State<CommitmentFormSheet> createState() => _CommitmentFormSheetState();
}

class _CommitmentFormSheetState extends State<CommitmentFormSheet> {
  late final TextEditingController _nameController;
  late Set<int> _selectedDays;
  late int _startMinutes;
  late int _endMinutes;
  late String _color;

  @override
  void initState() {
    super.initState();
    final block = widget.block;
    _nameController = TextEditingController(text: block?.name ?? '');
    _selectedDays = block != null ? Set<int>.from(block.daysOfWeek) : {};
    _startMinutes = block?.startMinutes ?? 9 * 60; // 9:00am
    _endMinutes = block?.endMinutes ?? 17 * 60; // 5:00pm
    _color = block?.color ?? '#607D8B';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _formatTime(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    final isPm = hour >= 12;
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final period = isPm ? 'pm' : 'am';
    if (minute == 0) {
      return '$displayHour$period';
    }
    return '$displayHour:${minute.toString().padLeft(2, '0')}$period';
  }

  Widget _timeTile(String label, int minutes, void Function(int) onSet) {
    return InkWell(
      onTap: () async {
        final result = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
        );
        if (result != null) {
          onSet(result.hour * 60 + result.minute);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _formatTime(minutes),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty &&
      _selectedDays.isNotEmpty &&
      _endMinutes > _startMinutes;

  Future<void> _save() async {
    if (!_canSave) return;
    final block = CommitmentBlock(
      id: widget.block?.id,
      name: _nameController.text.trim(),
      daysOfWeek: _selectedDays.toList()..sort(),
      startMinutes: _startMinutes,
      endMinutes: _endMinutes,
    );
    block.color = _color;
    try {
      await context.read<CommitmentsNotifier>().saveBlock(block);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save commitment. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEdit = widget.block != null;

    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    // Detect dialog mode: explicit parameter takes precedence; fall back to
    // route detection so callers that omit isDialog still suppress the drag
    // handle and viewInsets.bottom when rendered inside a Dialog.
    final isDialog = widget.isDialog || (ModalRoute.of(context) is DialogRoute);

    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: EdgeInsets.fromLTRB(
        24,
        isDialog ? 24 : 8,
        24,
        isDialog ? 24 : 32 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag indicator — hidden in dialog mode (handle has no meaning
          // in a centered Material Dialog).
          if (!isDialog)
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Title
          Text(
            isEdit ? 'Edit commitment' : 'New commitment',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),

          // Name field
          TextField(
            controller: _nameController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. Work, Class, Gym',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Day chips section
          Text(
            'Days',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: List.generate(7, (i) {
              final day = i + 1;
              return FilterChip(
                label: Text(dayLabels[i]),
                selected: _selectedDays.contains(day),
                onSelected: (sel) {
                  setState(() {
                    if (sel) {
                      _selectedDays.add(day);
                    } else {
                      _selectedDays.remove(day);
                    }
                  });
                },
              );
            }),
          ),
          const SizedBox(height: 16),

          // Time row
          Row(
            children: [
              Expanded(
                child: _timeTile(
                  'Start',
                  _startMinutes,
                  (v) => setState(() => _startMinutes = v),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _timeTile(
                  'End',
                  _endMinutes,
                  (v) => setState(() => _endMinutes = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Discard button — lets the user cancel without saving
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Discard'),
          ),
          const SizedBox(height: 8),

          // Save button
          FilledButton(
            onPressed: _canSave ? _save : null,
            child: Text(isEdit ? 'Save changes' : 'Add commitment'),
          ),
        ],
      ),
    );
  }
}
