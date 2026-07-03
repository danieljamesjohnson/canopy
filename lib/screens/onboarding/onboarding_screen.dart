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

/// Onboarding as "let the app get to know you", in four short, centered beats:
///   1. Goals    — what do you want to make time for?
///   2. Recharge — what helps you recharge? (restoratives)
///   3. Energy   — which of those goals lift you up, and which drain you?
///   4. Job      — any fixed commitment we should schedule around?
///
/// Goals and restoratives are captured with tappable preset chips plus a fast
/// type/paste field, and persist immediately so the energy beat reads them
/// straight back. Completion just flips the onboarding flag, which the router
/// watches to leave onboarding.
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

  /// Saves the optional job, marks onboarding complete (router watches this to
  /// leave onboarding), and schedules the morning notification. On a write
  /// failure we re-enable and let the user retry rather than trap them.
  Future<void> _finish({CommitmentBlock? job}) async {
    if (_isFinishing) return;
    setState(() => _isFinishing = true);

    final settings = context.read<SettingsNotifier>();
    final commitments = context.read<CommitmentsNotifier>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (job != null) {
        await commitments.saveBlock(job);
      }
      await settings.setOnboardingComplete(true);
      if (settings.morningNotificationEnabled) {
        await NotificationService.scheduleMorningNotification(
          settings.morningNotificationMinutes,
        );
      }
      // On success the flag flips and the router navigates away — this widget
      // unmounts, so we must NOT reset state here.
    } catch (_) {
      if (!mounted) return;
      setState(() => _isFinishing = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Couldn't finish setup. Please try again."),
        ),
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
                  _RestorativesBeat(onNext: _next, onBack: _back),
                  _EnergyBeat(onNext: _next, onBack: _back),
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

// Preset "big buttons" — one tap adds the item; the type/paste field stays for
// anything not listed.
const List<String> _goalPresets = [
  'Exercise',
  'Reading',
  'Family time',
  'Side project',
  'Learn something',
  'Outdoors',
  'Creative time',
  'Rest',
];

const List<String> _restorativePresets = [
  'Walk',
  'Music',
  'Nap',
  'Nature',
  'Call a friend',
  'Bath',
  'Stretch',
  'Games',
];

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

  void _continue() {
    _quickAdd.flush(); // don't drop a name typed but not yet Entered
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return _ScreenLayout(
      child: Consumer<GoalsNotifier>(
        builder: (context, goals, _) {
          final added = [
            for (final g in goals.goals) _Entry(g.id, g.name, g.emojiTag),
          ];
          final goalsNotifier = context.read<GoalsNotifier>();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const _BeatTitle('What are your goals?'),
              const SizedBox(height: 16),
              _ChipCloud(
                added: added,
                suggestions: _suggestionsFor(_goalPresets, added),
                onAdd: (name) => goalsNotifier.quickAddGoals([name]),
                onRemove: goalsNotifier.archiveGoal,
              ),
              const SizedBox(height: 20),
              QuickAddField(
                controller: _quickAdd,
                onSubmit: (names) => goalsNotifier.quickAddGoals(names),
                autofocus: added.isEmpty,
                multiAddNoun: 'goals',
                addTooltip: 'Add goal',
                hintText: 'Add your own',
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: added.isEmpty ? null : _continue,
                child: const Text('Continue'),
              ),
              if (added.isEmpty)
                const _CenteredHint('Add at least one to continue.'),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Beat 2: Recharge (restoratives)
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

  void _navigate(VoidCallback move) {
    _quickAdd.flush();
    move();
  }

  @override
  Widget build(BuildContext context) {
    return _ScreenLayout(
      child: Consumer<RestorativesNotifier>(
        builder: (context, restoratives, _) {
          final added = [
            for (final i in restoratives.items) _Entry(i.id, i.name, i.emojiTag),
          ];
          final notifier = context.read<RestorativesNotifier>();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const _BeatTitle('What helps you recharge?'),
              const SizedBox(height: 16),
              _ChipCloud(
                added: added,
                suggestions: _suggestionsFor(_restorativePresets, added),
                onAdd: (name) => notifier.quickAddItems([name]),
                onRemove: notifier.deleteItem,
              ),
              const SizedBox(height: 20),
              QuickAddField(
                controller: _quickAdd,
                onSubmit: (names) => notifier.quickAddItems(names),
                multiAddNoun: 'restoratives',
                addTooltip: 'Add restorative',
                hintText: 'Add your own',
              ),
              const SizedBox(height: 12),
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
                      child: Text(added.isEmpty ? 'Skip' : 'Continue'),
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
// Beat 3: Energy (sorts the goals)
// ---------------------------------------------------------------------------

class _EnergyBeat extends StatelessWidget {
  const _EnergyBeat({required this.onNext, required this.onBack});

  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return _ScreenLayout(
      child: Consumer<GoalsNotifier>(
        builder: (context, goals, _) {
          final list = goals.goals;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const _BeatTitle('Which of these lift you up?'),
              const SizedBox(height: 16),
              if (list.isEmpty)
                const _CenteredHint('No goals yet — go back and add a few.')
              else
                for (final g in list) _EnergyRow(goal: g),
              const SizedBox(height: 20),
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (goal.emojiTag != null) ...[
                Text(goal.emojiTag!, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  goal.name,
                  style: textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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

  bool get _windowTooShort =>
      commitmentWindowTooShort(_startMinutes, _endMinutes);

  /// The pre-filled (or edited) schedule is savable. Name is NOT required — the
  /// beat opens fully pre-filled (M–F 9–5), so tapping the primary action must
  /// capture that job rather than silently discard it. A blank name defaults to
  /// "Work" so the user's fixed commitment is never lost just for skipping a
  /// field.
  bool get _scheduleValid => _selectedDays.isNotEmpty && !_windowTooShort;

  Future<void> _addAndFinish() async {
    final typed = _nameController.text.trim();
    final job = CommitmentBlock(
      name: typed.isEmpty ? 'Work' : typed,
      daysOfWeek: _selectedDays.toList()..sort(),
      startMinutes: _startMinutes,
      endMinutes: _endMinutes,
    );
    await widget.onFinish(job: job);
  }

  Future<void> _finishWithoutJob() async => widget.onFinish();

  @override
  Widget build(BuildContext context) {
    return _ScreenLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _BeatTitle('Do you have a job or fixed commitment?'),
          const SizedBox(height: 16),

          TextField(
            controller: _nameController,
            onChanged: (_) => setState(() {}),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              hintText: 'e.g. Work, Class, Gym',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: List.generate(7, (i) {
              final day = i + 1;
              return FilterChip(
                label: Text(_dayLabels[i]),
                selected: _selectedDays.contains(day),
                // Drop the checkmark (the selected fill already signals state)
                // and tighten padding so all 7 days fit on one row instead of
                // wrapping Sunday onto its own line.
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                labelPadding: const EdgeInsets.symmetric(horizontal: 6),
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

          const SizedBox(height: 24),

          // Warn only when the user has broken the pre-filled schedule.
          if (_windowTooShort)
            _CenteredHint(
              'End time needs to be at least 25 minutes after the start.',
              error: true,
            )
          else if (_selectedDays.isEmpty)
            _CenteredHint(
              'Pick at least one day for this commitment.',
              error: true,
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
                  // Saves the pre-filled/edited job. Disabled only if the user
                  // broke the schedule (no days / too-short window).
                  onPressed: (widget.isFinishing || !_scheduleValid)
                      ? null
                      : _addAndFinish,
                  child: const Text('Add & finish'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Always-available escape for anyone without a fixed commitment, so
          // the prominent action can safely capture the pre-filled job.
          TextButton(
            onPressed: widget.isFinishing ? null : _finishWithoutJob,
            child: const Text("I don't have a fixed commitment"),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

/// A single added/suggested entry (a goal or a restorative).
class _Entry {
  const _Entry(this.id, this.name, this.emoji);
  final String id;
  final String name;
  final String? emoji;
}

/// Presets not already added (case-insensitive), so a preset the user has
/// added shows as a removable chip rather than a duplicate suggestion.
List<String> _suggestionsFor(List<String> presets, List<_Entry> added) {
  final have = {for (final e in added) e.name.toLowerCase()};
  return [for (final p in presets) if (!have.contains(p.toLowerCase())) p];
}

/// Added items (removable input chips) + preset suggestions (add chips), all
/// centered. Tapping a suggestion adds it; tapping the × on an added chip
/// removes it.
class _ChipCloud extends StatelessWidget {
  const _ChipCloud({
    required this.added,
    required this.suggestions,
    required this.onAdd,
    required this.onRemove,
  });

  final List<_Entry> added;
  final List<String> suggestions;
  final void Function(String name) onAdd;
  final void Function(String id) onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in added)
          InputChip(
            avatar: e.emoji != null ? Text(e.emoji!) : null,
            label: Text(e.name),
            backgroundColor: colorScheme.secondaryContainer,
            onDeleted: () => onRemove(e.id),
          ),
        for (final s in suggestions)
          ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: Text(s),
            onPressed: () => onAdd(s),
          ),
      ],
    );
  }
}

/// Short, centered beat heading.
class _BeatTitle extends StatelessWidget {
  const _BeatTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineSmall,
    );
  }
}

class _CenteredHint extends StatelessWidget {
  const _CenteredHint(this.text, {this.error = false});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: error ? colorScheme.error : colorScheme.onSurfaceVariant,
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

/// Centers content and constrains it to a comfortable reading width, and makes
/// EVERY beat fill-the-height-or-scroll: a trailing [Spacer] pins actions to
/// the bottom when there's room, but the whole beat scrolls when the viewport
/// is shorter than the content — a shrunk viewport (soft keyboard) OR large
/// accessibility text scale. Without this, a fixed column overflows and pushes
/// its primary button off-screen; because the PageView can't scroll and the
/// router gates the app behind onboarding, that would lock the user out.
class _ScreenLayout extends StatelessWidget {
  const _ScreenLayout({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                // Vertically center the content when it fits; when it's taller
                // than the viewport (small phone, large text, or keyboard up)
                // the ConstrainedBox grows and the whole beat scrolls. No
                // IntrinsicHeight/Spacer — those misbehave with the chip Wrap.
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: child,
                  ),
                ),
              ),
            );
          },
        ),
      ),
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
