import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/commitment_block.dart';
import '../../providers/commitments_notifier.dart';
import '../../utils/commitment_window.dart';

class CommitmentFormSheet extends StatefulWidget {
  const CommitmentFormSheet({
    super.key,
    required this.scrollController,
    this.block,
    this.isDialog = false,
    this.initialOneOff = false,
    this.initialDate,
    this.onSaved,
  });

  final ScrollController scrollController;
  final CommitmentBlock? block;
  final bool isDialog;

  /// When creating a NEW commitment (block == null), open pre-set to the
  /// one-off ("event") mode. Lets the Today screen offer "Add an event"
  /// straight into dated entry. Ignored when editing an existing block.
  final bool initialOneOff;

  /// When [initialOneOff] is set, pre-select this date (e.g. today).
  final DateTime? initialDate;

  /// Fired after a successful save, with the saved block. Lets a caller react
  /// (e.g. the Today screen inserts a same-day event into today's schedule).
  final ValueChanged<CommitmentBlock>? onSaved;

  @override
  State<CommitmentFormSheet> createState() => _CommitmentFormSheetState();
}

class _CommitmentFormSheetState extends State<CommitmentFormSheet> {
  late final TextEditingController _nameController;
  late Set<int> _selectedDays;
  late int _startMinutes;
  late int _endMinutes;
  late String _color;
  late bool _isOneOff;
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    final block = widget.block;
    _nameController = TextEditingController(text: block?.name ?? '');
    _selectedDays = block != null ? Set<int>.from(block.daysOfWeek) : {};
    _startMinutes = block?.startMinutes ?? 9 * 60; // 9:00am
    _endMinutes = block?.endMinutes ?? 17 * 60; // 5:00pm
    _color = block?.color ?? '#607D8B';
    // Editing: mirror the block. Creating: honor the caller's one-off default
    // (e.g. "Add an event" from the Today screen) with a preselected date.
    _isOneOff = block != null ? block.date != null : widget.initialOneOff;
    _date = block != null
        ? block.date
        : (widget.initialOneOff ? widget.initialDate : null);
  }

  static const _monthAbbr = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _formatDate(DateTime d) =>
      '${_monthAbbr[d.month]} ${d.day}, ${d.year}';

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

  bool get _windowTooShort =>
      commitmentWindowTooShort(_startMinutes, _endMinutes);

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty &&
      !_windowTooShort &&
      (_isOneOff ? _date != null : _selectedDays.isNotEmpty);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    // Clamp the seed up to firstDate: a one-off whose date is already in the
    // past (a stale appointment) would otherwise pass initialDate < firstDate
    // and trip showDatePicker's assert — a hard throw in the asserts-on debug
    // build. Re-editing a past one-off opens the picker at today instead.
    final seed = _date ?? now;
    final initial = seed.isBefore(firstDate) ? firstDate : seed;
    final result = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: DateTime(now.year + 2, now.month, now.day),
    );
    if (result != null) {
      // Store date-only (midnight local) so day-equality in the generator is
      // unaffected by any time component.
      setState(() => _date = DateTime(result.year, result.month, result.day));
    }
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final block = CommitmentBlock(
      id: widget.block?.id,
      name: _nameController.text.trim(),
      // A one-off carries no recurring weekdays; a recurring block carries no date.
      daysOfWeek: _isOneOff ? const [] : (_selectedDays.toList()..sort()),
      startMinutes: _startMinutes,
      endMinutes: _endMinutes,
      date: _isOneOff ? _date : null,
    );
    block.color = _color;
    try {
      await context.read<CommitmentsNotifier>().saveBlock(block);
      widget.onSaved?.call(block);
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

    const dayLabels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

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

          // Repeat mode: recurring weekly vs a single dated event. This is what
          // lets a human enter an actual one-off event on a specific day.
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('Repeats weekly'),
                icon: Icon(Icons.repeat),
              ),
              ButtonSegment(
                value: true,
                label: Text('One-off date'),
                icon: Icon(Icons.event),
              ),
            ],
            selected: {_isOneOff},
            onSelectionChanged: (sel) => setState(() => _isOneOff = sel.first),
          ),
          const SizedBox(height: 16),

          // Either weekday chips (recurring) or a single date picker (one-off).
          if (_isOneOff) ...[
            Text(
              'Date',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _date == null ? 'Pick a date' : _formatDate(_date!),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
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
          ],
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
          if (_windowTooShort) ...[
            const SizedBox(height: 8),
            Text(
              'End must be at least 25 minutes after start.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
            ),
          ],
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
