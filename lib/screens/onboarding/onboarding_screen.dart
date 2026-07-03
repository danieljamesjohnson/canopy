import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/commitment_block.dart';
import '../../data/models/energy_valence.dart';
import '../../data/models/goal.dart';
import '../../providers/commitments_notifier.dart';
import '../../providers/goals_notifier.dart';
import '../../providers/restoratives_notifier.dart';
import '../../providers/settings_notifier.dart';
import '../../services/notification_service.dart';
import '../../utils/commitment_window.dart';
import '../../widgets/quick_add_field.dart';

/// Onboarding as "let the app get to know you", in four warm beats:
///   1. Goals    — what do you want to make time for? (a whole slate, fast)
///   2. Energy   — which of those lift you up, and which drain you?
///   3. Restore  — what recharges you when you're low?
///   4. Job      — any fixed commitment we should schedule around?
///
/// Goals and restoratives are persisted immediately as they're entered (via the
/// shared [QuickAddField]), so the later beats can read them straight back and
/// the user's input can never be lost mid-flow. Completion just flips the
/// onboarding flag, which the router watches to leave onboarding.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _totalBeats = 4;

  final _controller = PageController();
  int _currentPage = 0;
  bool _isFinishing = false;

  @override
  void initState() {
    super.initState();
    // Load any pre-existing data so lists render immediately (also covers the
    // case where a user re-enters an incomplete onboarding).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<GoalsNotifier>().loadGoals();
      context.read<RestorativesNotifier>().loadItems();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  void _back() {
    _controller.previousPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  /// Saves the optional job commitment (if provided), marks onboarding complete
  /// — which the router redirect watches to leave onboarding — and schedules
  /// the morning notification. Guarded against double-tap.
  Future<void> _finish({CommitmentBlock? job}) async {
    if (_isFinishing) return;
    setState(() => _isFinishing = true);

    final settings = context.read<SettingsNotifier>();
    if (job != null) {
      await context.read<CommitmentsNotifier>().saveBlock(job);
    }
    await settings.setOnboardingComplete(true);
    if (settings.morningNotificationEnabled) {
      await NotificationService.scheduleMorningNotification(
        settings.morningNotificationMinutes,
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
            _StepDots(currentPage: _currentPage, totalPages: _totalBeats),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (p) => setState(() => _currentPage = p),
                children: [
                  _GoalsBeat(onNext: _next),
                  _EnergyBeat(onNext: _next, onBack: _back),
                  _RestorativesBeat(onNext: _next, onBack: _back),
                  _JobBeat(
                    isFinishing: _isFinishing,
                    onBack: _back,
                    onFinish: _finish,
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
// Beat 1: Goals
// ---------------------------------------------------------------------------

class _GoalsBeat extends StatefulWidget {
  const _GoalsBeat({required this.onNext});

  final VoidCallback onNext;

  @override
  State<_GoalsBeat> createState() => _GoalsBeatState();
}

class _GoalsBeatState extends State<_GoalsBeat> {
  final _quickAdd = QuickAddController();

  /// Commit any typed-but-unsubmitted goal, then advance — so tapping Continue
  /// without pressing Enter first never drops the name.
  void _continue() {
    _quickAdd.flush();
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return _ScreenLayout(
      child: Consumer<GoalsNotifier>(
        builder: (context, goals, _) {
          final list = goals.goals;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('What do you want to make time for?', style: textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Add as many as come to mind — big or small. You can change '
                'them anytime.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              QuickAddField(
                controller: _quickAdd,
                onSubmit: (names) => context
                    .read<GoalsNotifier>()
                    .quickAddGoals(names),
                autofocus: list.isEmpty,
                multiAddNoun: 'goals',
                addTooltip: 'Add goal',
                hintText: list.isEmpty ? 'e.g. Exercise' : 'Add another',
                helperText: 'Press Enter after each, or paste a list',
              ),
              const SizedBox(height: 16),
              Expanded(
                child: list.isEmpty
                    ? _EmptyHint(
                        text: 'Your goals will appear here as you add them.',
                      )
                    : ListView(
                        children: [
                          for (final g in list)
                            _GoalChipRow(goal: g),
                        ],
                      ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: list.isEmpty ? null : _continue,
                child: const Text('Continue'),
              ),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Add at least one goal to continue.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _GoalChipRow extends StatelessWidget {
  const _GoalChipRow({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (goal.emojiTag != null) ...[
            Text(goal.emojiTag!, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
          ] else ...[
            Icon(
              Icons.flag_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              goal.name,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Beat 2: Energy
// ---------------------------------------------------------------------------

class _EnergyBeat extends StatelessWidget {
  const _EnergyBeat({required this.onNext, required this.onBack});

  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return _ScreenLayout(
      child: Consumer<GoalsNotifier>(
        builder: (context, goals, _) {
          final list = goals.goals;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Which of these lift you up?', style: textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                "Mark what gives you energy and what drains you — we'll lean on "
                'the good ones when your energy is low.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: list.isEmpty
                    ? _EmptyHint(text: 'No goals yet — go back and add a few.')
                    : ListView(
                        children: [
                          for (final g in list) _EnergyRow(goal: g),
                        ],
                      ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(onPressed: onBack, child: const Text('Back')),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onNext,
                      child: const Text('Continue'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EnergyRow extends StatelessWidget {
  const _EnergyRow({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (goal.emojiTag != null) ...[
                Text(goal.emojiTag!, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
              ],
              Expanded(child: Text(goal.name, style: textTheme.bodyLarge)),
            ],
          ),
          const SizedBox(height: 6),
          SegmentedButton<EnergyValence>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: EnergyValence.gives,
                label: Text('Lifts'),
                icon: Icon(Icons.bolt, size: 18),
              ),
              ButtonSegment(
                value: EnergyValence.neutral,
                label: Text('Neutral'),
                icon: Icon(Icons.remove, size: 18),
              ),
              ButtonSegment(
                value: EnergyValence.costs,
                label: Text('Drains'),
                icon: Icon(Icons.battery_2_bar, size: 18),
              ),
            ],
            selected: {goal.energyValence},
            onSelectionChanged: (sel) {
              goal.energyValenceIndex = sel.first.index;
              context.read<GoalsNotifier>().saveGoal(goal);
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Beat 3: Restoratives
// ---------------------------------------------------------------------------

class _RestorativesBeat extends StatefulWidget {
  const _RestorativesBeat({required this.onNext, required this.onBack});

  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  State<_RestorativesBeat> createState() => _RestorativesBeatState();
}

class _RestorativesBeatState extends State<_RestorativesBeat> {
  final _quickAdd = QuickAddController();

  /// Commit any typed-but-unsubmitted restorative before navigating, so a
  /// name isn't lost when Continue/Skip/Back is tapped without Enter.
  void _navigate(VoidCallback move) {
    _quickAdd.flush();
    move();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return _ScreenLayout(
      child: Consumer<RestorativesNotifier>(
        builder: (context, restoratives, _) {
          final list = restoratives.items;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('What helps you recharge?', style: textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                "A walk, music, a long bath — the small things that restore you. "
                "These aren't goals; we'll gently suggest them on low days.",
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              QuickAddField(
                controller: _quickAdd,
                onSubmit: (names) => context
                    .read<RestorativesNotifier>()
                    .quickAddItems(names),
                multiAddNoun: 'restoratives',
                addTooltip: 'Add restorative',
                hintText: list.isEmpty ? 'e.g. Listen to music' : 'Add another',
                helperText: 'Press Enter after each, or paste a list',
              ),
              const SizedBox(height: 16),
              Expanded(
                child: list.isEmpty
                    ? _EmptyHint(
                        text: 'Optional — but even one helps on a hard day.',
                      )
                    : ListView(
                        children: [
                          for (final item in list)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Text(
                                    item.emojiTag ?? '🌿',
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: textTheme.bodyLarge,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: () => _navigate(widget.onBack),
                    child: const Text('Back'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _navigate(widget.onNext),
                      child: Text(list.isEmpty ? 'Skip' : 'Continue'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Beat 4: Job / fixed commitment
// ---------------------------------------------------------------------------

class _JobBeat extends StatefulWidget {
  const _JobBeat({
    required this.isFinishing,
    required this.onBack,
    required this.onFinish,
  });

  final bool isFinishing;
  final VoidCallback onBack;
  final Future<void> Function({CommitmentBlock? job}) onFinish;

  @override
  State<_JobBeat> createState() => _JobBeatState();
}

class _JobBeatState extends State<_JobBeat> {
  final _nameController = TextEditingController();
  final Set<int> _selectedDays = {1, 2, 3, 4, 5}; // default weekdays
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

  /// The user has started describing a job (typed a name) — so we must save a
  /// real, schedulable commitment rather than silently drop it.
  bool get _hasStartedJob => _nameController.text.trim().isNotEmpty;

  bool get _windowTooShort =>
      commitmentWindowTooShort(_startMinutes, _endMinutes);

  /// A started job is only savable with at least one day and a window that can
  /// actually hold a chunk (guards the inverted/night-shift case that would
  /// otherwise persist a commitment the scheduler turns into zero chunks).
  bool get _jobValid =>
      _hasStartedJob && _selectedDays.isNotEmpty && !_windowTooShort;

  /// Finishes onboarding, saving the job only when it's fully valid. Never
  /// called for a started-but-invalid job — that path is blocked in the UI.
  Future<void> _finishWithJob() async {
    final job = _jobValid
        ? CommitmentBlock(
            name: _nameController.text.trim(),
            daysOfWeek: _selectedDays.toList()..sort(),
            startMinutes: _startMinutes,
            endMinutes: _endMinutes,
          )
        : null;
    await widget.onFinish(job: job);
  }

  /// Finishes onboarding WITHOUT the job (used to escape a half-filled,
  /// invalid job rather than trapping the user).
  Future<void> _finishWithoutJob() async {
    await widget.onFinish();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return _ScreenLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Do you have a job or fixed commitment?',
            style: textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            "We'll always schedule around it, whatever your mood. "
            'No worries if not — just finish.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),

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

          Text(
            'Days',
            style: textTheme.labelMedium?.copyWith(
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
                onSelected: (sel) => setState(() {
                  if (sel) {
                    _selectedDays.add(day);
                  } else {
                    _selectedDays.remove(day);
                  }
                }),
              );
            }),
          ),
          const SizedBox(height: 16),

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

          // Inline warning when a job is half-described but not schedulable.
          // Without this, an inverted/too-short window would save a commitment
          // that silently produces zero chunks.
          if (_hasStartedJob && _windowTooShort)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'End time needs to be at least 25 minutes after the start.',
                style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
              ),
            )
          else if (_hasStartedJob && _selectedDays.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Pick at least one day for this commitment.',
                style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
              ),
            ),

          Row(
            children: [
              TextButton(
                onPressed: widget.isFinishing ? null : widget.onBack,
                child: const Text('Back'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  // Enabled when there's no job (clean finish) or the job is
                  // fully valid. A started-but-invalid job disables this so a
                  // broken commitment can't be saved.
                  onPressed: (widget.isFinishing || (_hasStartedJob && !_jobValid))
                      ? null
                      : _finishWithJob,
                  child: Text(
                    _hasStartedJob ? 'Add & finish' : "Finish — I'm ready",
                  ),
                ),
              ),
            ],
          ),

          // Escape hatch: if a job is half-filled and invalid, let the user
          // finish without it rather than being trapped behind validation.
          if (_hasStartedJob && !_jobValid)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextButton(
                onPressed: widget.isFinishing ? null : _finishWithoutJob,
                child: const Text('Skip the job and finish'),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

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

class _ScreenLayout extends StatelessWidget {
  const _ScreenLayout({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: child,
    );
  }
}

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
