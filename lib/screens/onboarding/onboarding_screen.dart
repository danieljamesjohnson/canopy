import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/commitment_block.dart';
import '../../data/models/energy_valence.dart';
import '../../data/models/goal.dart';
import '../../providers/commitments_notifier.dart';
import '../../providers/goals_notifier.dart';
import '../../providers/settings_notifier.dart';
import '../../services/notification_service.dart';
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

  // Screen 4 state
  Set<String> _screen4MarkedGoalIds = {};
  List<Goal> _screen4QuickGoals = [];

  // Cached pending goals passed to Screen 4 (same objects saved in _completeOnboarding).
  // Rebuilt whenever Screen 3 onComplete fires (when _screen3Habit changes).
  List<Goal>? _screen4PendingGoals;

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

  /// Returns the stable display list of pending goals for Screen 4.
  ///
  /// The list is cached after first build so that the same Goal objects
  /// (with stable IDs) are both shown on Screen 4 and saved by
  /// _completeOnboarding steps (1) and (3). Without caching, every
  /// PageView rebuild would create new Goal instances with new UUIDs,
  /// making the marked-ID set stale.
  List<Goal> _getPendingGoalsForScreen4() {
    if (_screen4PendingGoals != null) return _screen4PendingGoals!;
    final goals = <Goal>[];
    final name = _screen1NameController.text.trim();
    if (name.isNotEmpty && _screen1Type != null) {
      goals.add(
        Goal(
          name: name,
          goalTypeIndex: _screen1Type!.index,
          weeklyHourBudget: _screen1Type == GoalType.timeTarget ? 3.0 : null,
        ),
      );
    }
    if (_screen3Habit != null) {
      goals.add(_screen3Habit!);
    }
    _screen4PendingGoals = goals;
    return goals;
  }

  Future<void> _completeOnboarding() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final goalsNotifier = context.read<GoalsNotifier>();
    final commitmentsNotifier = context.read<CommitmentsNotifier>();
    final settingsNotifier = context.read<SettingsNotifier>();

    // (1) Save Screen 1 goal if filled.
    // Re-use the same Goal object that was displayed on Screen 4 (stable ID)
    // so that any marked-ID in _screen4MarkedGoalIds resolves correctly.
    final pendingGoals = _getPendingGoalsForScreen4();
    final screen1Goal = pendingGoals
        .where((g) => g.goalTypeIndex != GoalType.habit.index)
        .firstOrNull;
    if (screen1Goal != null) {
      screen1Goal.color = goalsNotifier.autoColor();
      await goalsNotifier.saveGoal(screen1Goal);
    }

    // (2) Save Screen 2 commitment block if filled
    if (_screen2Block != null) {
      await commitmentsNotifier.saveBlock(_screen2Block!);
    }

    // (3) Save Screen 3 habit if filled.
    // _screen3Habit is already in pendingGoals (same object), so saving it
    // here keeps the existing path working correctly.
    if (_screen3Habit != null) {
      await goalsNotifier.saveGoal(_screen3Habit!);
    }

    // (3.5) NEW: Save Screen 4 quick-added goals with gives valence,
    // then apply gives to goals the user marked on Screen 4.
    for (final goal in _screen4QuickGoals) {
      goal.energyValenceIndex = EnergyValence.gives.index;
      await goalsNotifier.saveGoal(goal);
    }
    for (final id in _screen4MarkedGoalIds) {
      final goals = goalsNotifier.goals;
      final goal = goals.where((g) => g.id == id).firstOrNull;
      if (goal != null) {
        goal.energyValenceIndex = EnergyValence.gives.index;
        await goalsNotifier.saveGoal(goal);
      }
    }

    // (4) ALWAYS last — triggers router redirect
    await settingsNotifier.setOnboardingComplete(true);

    // LOOP-04: schedule the morning notification after onboarding completes
    // so it fires without the user toggling the Settings switch off/on.
    if (settingsNotifier.morningNotificationEnabled) {
      await NotificationService.scheduleMorningNotification(
        settingsNotifier.morningNotificationMinutes,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _StepDots(currentPage: _currentPage, totalPages: 4),
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
                      _screen4PendingGoals = null; // invalidate cache
                      _nextPage();
                    },
                    onSkip: () {
                      _screen4PendingGoals = null; // invalidate cache
                      _nextPage();
                    },
                    isSaving: _isSaving,
                  ),
                  _Screen4(
                    pendingGoals: _getPendingGoalsForScreen4(),
                    onComplete: (markedIds, quickGoals) {
                      _screen4MarkedGoalIds = markedIds;
                      _screen4QuickGoals = quickGoals;
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
      initialTime: TimeOfDay(
        hour: currentMinutes ~/ 60,
        minute: currentMinutes % 60,
      ),
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
              ElevatedButton(onPressed: _onNext, child: const Text('Add it')),
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
// Screen 4: What gives you energy?
// ---------------------------------------------------------------------------

class _Screen4 extends StatefulWidget {
  const _Screen4({
    required this.pendingGoals,
    required this.onComplete,
    required this.onSkip,
    required this.isSaving,
  });

  /// Goals from Screens 1 and 3 — not yet persisted. Display-only list.
  final List<Goal> pendingGoals;

  /// Called when user taps "Let's go". Receives marked goal IDs and quick-added goals.
  final void Function(Set<String>, List<Goal>) onComplete;

  final VoidCallback onSkip;
  final bool isSaving;

  @override
  State<_Screen4> createState() => _Screen4State();
}

class _Screen4State extends State<_Screen4> {
  final Set<String> _markedGoalIds = {};
  final List<Goal> _quickGoals = [];

  // Quick-add state
  bool _showQuickAdd = false;
  final _quickAddController = TextEditingController();

  @override
  void dispose() {
    _quickAddController.dispose();
    super.dispose();
  }

  void _toggleMark(String id, bool selected) {
    setState(() {
      if (selected) {
        _markedGoalIds.add(id);
      } else {
        _markedGoalIds.remove(id);
      }
    });
  }

  void _confirmQuickAdd() {
    final name = _quickAddController.text.trim();
    if (name.isEmpty) return;
    final goal = Goal(
      name: name,
      goalTypeIndex: GoalType.timeTarget.index,
      weeklyHourBudget: 3.0,
      energyValenceIndex: EnergyValence.gives.index,
    );
    setState(() {
      _quickGoals.add(goal);
      _quickAddController.clear();
      _showQuickAdd = false;
    });
  }

  void _onComplete() {
    widget.onComplete(
      Set<String>.from(_markedGoalIds),
      List<Goal>.from(_quickGoals),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Combined display list: pending goals from parent + quick-added goals
    final allGoals = [...widget.pendingGoals, ..._quickGoals];

    return _ScreenLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('What gives you energy?', style: textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            "Pick one or two activities that leave you feeling good. "
            "We'll make sure to include them on hard days.",
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Goal rows
          if (allGoals.isEmpty)
            Text(
              'No goals yet — add one below.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            )
          else
            ...allGoals.map((goal) {
              final isMarked =
                  _markedGoalIds.contains(goal.id) ||
                  goal.energyValenceIndex == EnergyValence.gives.index;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text(
                  goal.emojiTag ?? '',
                  style: const TextStyle(fontSize: 20),
                ),
                title: Text(goal.name, style: textTheme.bodyMedium),
                trailing: FilterChip(
                  label: const Text('Energizing'),
                  selected: isMarked,
                  avatar: isMarked ? const Icon(Icons.bolt, size: 14) : null,
                  onSelected: (sel) => _toggleMark(goal.id, sel),
                ),
              );
            }),

          const SizedBox(height: 16),

          // Quick-add button or inline text field
          if (_showQuickAdd)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quickAddController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Goal name',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _confirmQuickAdd(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Add goal',
                  icon: const Icon(Icons.check_circle_outlined),
                  onPressed: _confirmQuickAdd,
                ),
              ],
            )
          else
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add something energizing'),
              onPressed: () => setState(() => _showQuickAdd = true),
            ),

          const Spacer(),

          // CTA row
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
