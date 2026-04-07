import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/commitment_block.dart';
import '../../data/models/goal.dart';
import '../../providers/commitments_notifier.dart';
import '../../providers/goals_notifier.dart';
import '../../providers/settings_notifier.dart';
import '../goals/widgets/goal_type_picker.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  // Screen 1 state
  GoalType? _screen1Type;
  final _screen1NameController = TextEditingController();

  // Screen 2 state (null if skipped)
  CommitmentBlock? _screen2Block;

  // Screen 3 state (null if skipped)
  Goal? _screen3Habit;

  // Prevent double-tap on final complete button
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    _screen1NameController.dispose();
    super.dispose();
  }

  void _nextPage() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _skipToComplete() async {
    await _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final goalsNotifier = context.read<GoalsNotifier>();
    final commitmentsNotifier = context.read<CommitmentsNotifier>();
    final settingsNotifier = context.read<SettingsNotifier>();

    // (1) Save Screen 1 goal if filled
    final name = _screen1NameController.text.trim();
    if (name.isNotEmpty && _screen1Type != null) {
      final goal = Goal(
        name: name,
        goalTypeIndex: _screen1Type!.index,
        color: goalsNotifier.autoColor(),
      );
      await goalsNotifier.saveGoal(goal);
    }

    // (2) Save Screen 2 commitment block if filled
    if (_screen2Block != null) {
      await commitmentsNotifier.saveBlock(_screen2Block!);
    }

    // (3) Save Screen 3 habit if filled
    if (_screen3Habit != null) {
      await goalsNotifier.saveGoal(_screen3Habit!);
    }

    // (4) ALWAYS last — triggers router redirect
    await settingsNotifier.setOnboardingComplete(true);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _StepDots(currentPage: _currentPage, totalPages: 3),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (p) => setState(() => _currentPage = p),
                children: [
                  _Screen1(
                    nameController: _screen1NameController,
                    onTypeSelected: (type) =>
                        setState(() => _screen1Type = type),
                    onNext: _nextPage,
                    selectedType: _screen1Type,
                  ),
                  _Screen2(
                    onNext: (block) {
                      _screen2Block = block;
                      _nextPage();
                    },
                    onSkip: _nextPage,
                  ),
                  _Screen3(
                    onComplete: (habit) {
                      _screen3Habit = habit;
                      _completeOnboarding();
                    },
                    onSkip: _skipToComplete,
                    isSaving: _isSaving,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step dots
// ---------------------------------------------------------------------------

class _StepDots extends StatelessWidget {
  const _StepDots({required this.currentPage, required this.totalPages});

  final int currentPage;
  final int totalPages;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(totalPages, (i) {
          final isActive = i == currentPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Screen 1: Goal type + name
// ---------------------------------------------------------------------------

class _Screen1 extends StatefulWidget {
  const _Screen1({
    required this.nameController,
    required this.onTypeSelected,
    required this.onNext,
    required this.selectedType,
  });

  final TextEditingController nameController;
  final ValueChanged<GoalType> onTypeSelected;
  final VoidCallback onNext;
  final GoalType? selectedType;

  @override
  State<_Screen1> createState() => _Screen1State();
}

class _Screen1State extends State<_Screen1> {
  @override
  void initState() {
    super.initState();
    widget.nameController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.nameController.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  bool get _canContinue =>
      widget.selectedType != null &&
      widget.nameController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return _ScreenLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "What's one thing you most want to make time for?",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            "We'll build your schedule around it.",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          GoalTypePicker(
            selectedType: widget.selectedType,
            onTypeSelected: widget.onTypeSelected,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: widget.nameController,
            autofocus: false,
            decoration: const InputDecoration(
              hintText: 'Give it a name',
              border: OutlineInputBorder(),
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _canContinue ? widget.onNext : null,
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Screen 2: Commitment block
// ---------------------------------------------------------------------------

class _Screen2 extends StatefulWidget {
  const _Screen2({required this.onNext, required this.onSkip});

  final ValueChanged<CommitmentBlock?> onNext;
  final VoidCallback onSkip;

  @override
  State<_Screen2> createState() => _Screen2State();
}

class _Screen2State extends State<_Screen2> {
  final _nameController = TextEditingController();
  final Set<int> _selectedDays = {};
  int _startMinutes = 9 * 60;
  int _endMinutes = 17 * 60;

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

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
    if (minute == 0) return '$displayHour$period';
    return '$displayHour:${minute.toString().padLeft(2, '0')}$period';
  }

  Future<void> _pickTime({
    required int currentMinutes,
    required void Function(int) onSet,
  }) async {
    final result = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay(hour: currentMinutes ~/ 60, minute: currentMinutes % 60),
    );
    if (result != null && mounted) {
      onSet(result.hour * 60 + result.minute);
    }
  }

  void _onNext() {
    final name = _nameController.text.trim();
    if (name.isEmpty || _selectedDays.isEmpty) {
      widget.onNext(null);
      return;
    }
    final block = CommitmentBlock(
      name: name,
      daysOfWeek: _selectedDays.toList()..sort(),
      startMinutes: _startMinutes,
      endMinutes: _endMinutes,
    );
    widget.onNext(block);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _ScreenLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Do you have a regular job or fixed commitment?',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            "We'll always schedule around it, whatever your mood.",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),

          // Name field
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. Work, Class, Gym',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Day chips
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
                label: Text(_dayLabels[i]),
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
                child: _TimeTile(
                  label: 'Start',
                  minutes: _startMinutes,
                  formatTime: _formatTime,
                  onTap: () => _pickTime(
                    currentMinutes: _startMinutes,
                    onSet: (v) => setState(() => _startMinutes = v),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _TimeTile(
                  label: 'End',
                  minutes: _endMinutes,
                  formatTime: _formatTime,
                  onTap: () => _pickTime(
                    currentMinutes: _endMinutes,
                    onSet: (v) => setState(() => _endMinutes = v),
                  ),
                ),
              ),
            ],
          ),

          const Spacer(),

          // Skip + Continue row
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: widget.onSkip,
                  child: const Text('Skip'),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _onNext,
                child: const Text('Add it'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Screen 3: First habit
// ---------------------------------------------------------------------------

class _Screen3 extends StatefulWidget {
  const _Screen3({
    required this.onComplete,
    required this.onSkip,
    required this.isSaving,
  });

  final ValueChanged<Goal?> onComplete;
  final VoidCallback onSkip;
  final bool isSaving;

  @override
  State<_Screen3> createState() => _Screen3State();
}

class _Screen3State extends State<_Screen3> {
  final _nameController = TextEditingController();
  int _frequencyPerWeek = 7; // default: Daily

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _onComplete() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      widget.onComplete(null);
      return;
    }
    final habit = Goal(
      name: name,
      goalTypeIndex: GoalType.habit.index,
      frequencyPerWeek: _frequencyPerWeek,
    );
    widget.onComplete(habit);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _ScreenLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Is there anything you do every morning we should protect?',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Like exercise, journaling, or coffee time.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),

          // Habit name
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Habit name',
              hintText: 'e.g. Morning run, Journaling',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Frequency chips
          Text(
            'Frequency',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Daily'),
                selected: _frequencyPerWeek == 7,
                onSelected: (_) => setState(() => _frequencyPerWeek = 7),
              ),
              ChoiceChip(
                label: const Text('Weekdays'),
                selected: _frequencyPerWeek == 5,
                onSelected: (_) => setState(() => _frequencyPerWeek = 5),
              ),
              ChoiceChip(
                label: const Text('3\u00d7 / week'),
                selected: _frequencyPerWeek == 3,
                onSelected: (_) => setState(() => _frequencyPerWeek = 3),
              ),
            ],
          ),

          const Spacer(),

          // Skip + Complete row
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: widget.isSaving ? null : widget.onSkip,
                  child: const Text('Skip'),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: widget.isSaving ? null : _onComplete,
                child: const Text("Let's go"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared layout wrapper
// ---------------------------------------------------------------------------

class _ScreenLayout extends StatelessWidget {
  const _ScreenLayout({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - 32, // account for padding
            ),
            child: IntrinsicHeight(child: child),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Time tile widget
// ---------------------------------------------------------------------------

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.label,
    required this.minutes,
    required this.formatTime,
    required this.onTap,
  });

  final String label;
  final int minutes;
  final String Function(int) formatTime;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
              formatTime(minutes),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
