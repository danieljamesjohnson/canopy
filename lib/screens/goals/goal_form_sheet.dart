import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/goal.dart';
import '../../providers/goals_notifier.dart';
import 'widgets/goal_type_picker.dart';

class GoalFormSheet extends StatefulWidget {
  const GoalFormSheet({super.key, required this.scrollController, this.goal});

  final ScrollController scrollController;
  final Goal? goal;

  @override
  State<GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends State<GoalFormSheet> {
  GoalType? _selectedType;
  late TextEditingController _nameController;
  // LOOP-05: hoisted from build() to State so the cursor position is preserved
  // across rebuilds. Controllers constructed inside build() are recreated on
  // every setState(), which resets the selection to position 0.
  late TextEditingController _weeklyHoursController;
  late TextEditingController _descriptionController;
  double? _priorityWeight;
  double? _weeklyHourBudget;
  DateTime? _deadline;
  String? _outcomeDescription;
  int? _frequencyPerWeek;

  bool get _isEditMode => widget.goal != null;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    if (goal != null) {
      _selectedType = goal.goalType;
      _nameController = TextEditingController(text: goal.name);
      _priorityWeight = goal.priorityWeight;
      _weeklyHourBudget = goal.weeklyHourBudget;
      _deadline = goal.deadline;
      _outcomeDescription = goal.outcomeDescription;
      _frequencyPerWeek = goal.frequencyPerWeek;
    } else {
      _nameController = TextEditingController();
    }
    _weeklyHoursController = TextEditingController(
      text: _weeklyHourBudget != null
          ? _weeklyHourBudget!.toStringAsFixed(1)
          : '',
    );
    _descriptionController = TextEditingController(
      text: _outcomeDescription ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weeklyHoursController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty && _selectedType != null;

  Future<void> _save() async {
    if (!_canSave) return;
    final notifier = context.read<GoalsNotifier>();
    final color = widget.goal?.color ?? notifier.autoColor();

    final goal =
        widget.goal ??
        Goal(
          name: _nameController.text.trim(),
          goalTypeIndex: _selectedType!.index,
          color: color,
        );

    goal
      ..name = _nameController.text.trim()
      ..goalTypeIndex = _selectedType!.index
      ..color = color
      ..priorityWeight = _priorityWeight
      ..weeklyHourBudget = _weeklyHourBudget
      ..deadline = _deadline
      ..outcomeDescription = _outcomeDescription
      ..frequencyPerWeek = _frequencyPerWeek;

    await notifier.saveGoal(goal);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _archive() async {
    final goal = widget.goal;
    if (goal == null) return;
    await context.read<GoalsNotifier>().archiveGoal(goal.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      controller: widget.scrollController,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle indicator
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title
            Text(
              _isEditMode ? 'Edit goal' : 'Add goal',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Goal type picker
            GoalTypePicker(
              selectedType: _selectedType,
              onTypeSelected: (t) => setState(() {
                _selectedType = t;
                // Reset type-specific fields when type changes
                _weeklyHourBudget = null;
                _deadline = null;
                _outcomeDescription = null;
                _frequencyPerWeek = null;
                // Also clear the hoisted controllers so the fields visually
                // reset without recreating the controller (LOOP-05).
                _weeklyHoursController.clear();
                _descriptionController.clear();
              }),
            ),
            const SizedBox(height: 12),

            // Goal name
            TextField(
              controller: _nameController,
              autofocus: !_isEditMode,
              decoration: const InputDecoration(
                hintText: 'Goal name',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),

            // Priority control — shown for all goal types
            Row(
              children: [Text('Priority', style: theme.textTheme.bodyMedium)],
            ),
            SegmentedButton<double>(
              segments: const [
                ButtonSegment(value: 0.25, label: Text('Low')),
                ButtonSegment(value: 0.5, label: Text('Normal')),
                ButtonSegment(value: 0.75, label: Text('High')),
              ],
              selected: {_priorityWeight ?? 0.5},
              onSelectionChanged: (Set<double> val) =>
                  setState(() => _priorityWeight = val.first),
            ),
            const SizedBox(height: 16),

            // Type-specific fields
            if (_selectedType == GoalType.timeTarget) ...[
              TextField(
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Weekly hours target',
                  hintText: 'e.g. 5.0',
                  border: OutlineInputBorder(),
                  suffixText: 'hrs/week',
                ),
                controller: _weeklyHoursController,
                onChanged: (v) {
                  setState(() {
                    _weeklyHourBudget = double.tryParse(v);
                  });
                },
              ),
              const SizedBox(height: 16),
            ],

            if (_selectedType == GoalType.outcome) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Target date'),
                subtitle: Text(
                  _deadline != null
                      ? '${_deadline!.year}-${_deadline!.month.toString().padLeft(2, '0')}-${_deadline!.day.toString().padLeft(2, '0')}'
                      : 'Optional — tap to set',
                ),
                trailing: _deadline != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _deadline = null),
                      )
                    : const Icon(Icons.calendar_today_outlined),
                onTap: _pickDeadline,
              ),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'What does success look like?',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                controller: _descriptionController,
                onChanged: (v) =>
                    setState(() => _outcomeDescription = v.isEmpty ? null : v),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
            ],

            if (_selectedType == GoalType.habit) ...[
              Row(
                children: [
                  Text(
                    'Sessions per week: ${_frequencyPerWeek ?? 7}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
              Slider(
                value: (_frequencyPerWeek ?? 7).toDouble(),
                min: 1,
                max: 7,
                divisions: 6,
                label: '${_frequencyPerWeek ?? 7}x/week',
                onChanged: (v) => setState(() => _frequencyPerWeek = v.round()),
              ),
              const SizedBox(height: 16),
            ],

            // Archive button (edit mode only)
            if (_isEditMode) ...[
              TextButton(
                onPressed: _archive,
                style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                child: const Text('Archive'),
              ),
              const SizedBox(height: 8),
            ],

            // Cancel / Save row
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _canSave ? _save : null,
                    child: Text(_isEditMode ? 'Save' : 'Add goal'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
