import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/commitment_block.dart';
import '../../data/models/goal.dart';
import '../../data/repositories/completion_log_repository.dart';
import '../../data/repositories/hive_completion_log_repository.dart';
import '../../data/repositories/hive_quarterly_snapshot_repository.dart';
import '../../data/repositories/quarterly_snapshot_repository.dart';
import '../../providers/commitments_notifier.dart';
import '../../providers/goals_notifier.dart';
import '../../services/quarterly_aggregation_service.dart';
import 'sections/adjustments_section.dart';
import 'sections/data_section.dart';
import 'sections/reflection_section.dart';

/// Full-screen quarterly review flow with three sections:
///   1. DataSection — hero stat, donut chart, bar chart
///   2. ReflectionSection — 5 guided questions
///   3. AdjustmentsSection — drag reorder + archive + persist snapshot
///
/// Route: `/review` — outside StatefulShellRoute, no bottom nav bar.
///
/// [completionLogRepository] and [snapshotRepository] are optional injectable
/// repositories for testing without Hive initialisation.
class QuarterlyReviewScreen extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  QuarterlyReviewScreen({
    super.key,
    CompletionLogRepository? completionLogRepository,
    QuarterlySnapshotRepository? snapshotRepository,
  }) : _completionLogRepository = completionLogRepository,
       _snapshotRepository = snapshotRepository;

  final CompletionLogRepository? _completionLogRepository;
  final QuarterlySnapshotRepository? _snapshotRepository;

  @override
  State<QuarterlyReviewScreen> createState() => _QuarterlyReviewScreenState();
}

class _QuarterlyReviewScreenState extends State<QuarterlyReviewScreen> {
  final _outerController = PageController();
  int _currentSection = 0;

  // Aggregated data loaded in initState
  bool _loading = true;
  bool _hasData = false;

  int _totalCompleted = 0;
  Map<String, int> _goalChunkTotals = {};
  int _notSpentCount = 0;
  Map<String, int> _weeklyData = {};
  Map<String, double> _completionRates = {};
  String _periodStartYmd = '';
  String _periodEndYmd = '';

  // Archived goals + commitment blocks loaded in _loadData for DonutChart
  List<Goal> _archivedGoals = [];
  List<CommitmentBlock> _commitmentBlocks = [];

  // Answers from ReflectionSection (passed to AdjustmentsSection)
  List<String> _reflectionAnswers = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _outerController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // Capture provider refs BEFORE any await (Pitfall 6: context.read after
    // an await risks accessing an unmounted widget's context).
    final goalsNotifier = context.read<GoalsNotifier>();
    final commitmentsNotifier = context.read<CommitmentsNotifier>();

    final logRepo =
        widget._completionLogRepository ?? HiveCompletionLogRepository();
    final snapshotRepo =
        widget._snapshotRepository ?? HiveQuarterlySnapshotRepository();
    final allLogs = await logRepo.getAll();
    final latestSnapshot = await snapshotRepo.getLatest();

    // Load archived goals + commitment blocks for DonutChart (REVIEW-03).
    final archivedGoals = await goalsNotifier.getArchivedGoals();
    // CommitmentsNotifier.blocks is already populated at startup — sync read.
    final commitmentBlocks = commitmentsNotifier.blocks;

    final service = QuarterlyAggregationService();
    final today = DateTime.now();
    final todayYmd = _toYmd(today);

    // Determine period start
    String startYmd;
    if (latestSnapshot != null) {
      startYmd = latestSnapshot.periodEndYmd;
    } else if (allLogs.isNotEmpty) {
      final sorted = allLogs.map((l) => l.dateYmd).toList()..sort();
      startYmd = sorted.first;
    } else {
      // No data at all
      if (mounted) {
        setState(() {
          _loading = false;
          _hasData = false;
        });
      }
      return;
    }

    final totalCompleted = service.totalCompleted(allLogs, startYmd, todayYmd);

    // Guard on allLogs.isEmpty: show empty state only when there is literally
    // no review data, independent of provider goal-list state (REVIEW-03).
    if (allLogs.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _hasData = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _loading = false;
        _hasData = true;
        _archivedGoals = archivedGoals;
        _commitmentBlocks = List.of(commitmentBlocks);
        _periodStartYmd = startYmd;
        _periodEndYmd = todayYmd;
        _totalCompleted = totalCompleted;
        _goalChunkTotals = service.completedByGoal(allLogs, startYmd, todayYmd);
        _notSpentCount = service.notSpentCount(allLogs, startYmd, todayYmd);
        _weeklyData = service.completedByWeek(allLogs, startYmd, todayYmd);
        _completionRates = service.completionRateByGoal(
          allLogs,
          startYmd,
          todayYmd,
        );
      });
    }
  }

  void _advanceToSection(int section) {
    setState(() => _currentSection = section);
    _outerController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  String _toYmd(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goals = context.watch<GoalsNotifier>().goals;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Your quarter'),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_hasData
          ? _buildEmptyState(theme)
          : Column(
              children: [
                // Section indicator (3 dots)
                _SectionDots(currentSection: _currentSection, totalSections: 3),
                Expanded(
                  child: PageView(
                    controller: _outerController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      // Section 1: Data
                      DataSection(
                        totalCompleted: _totalCompleted,
                        goalChunkTotals: _goalChunkTotals,
                        notSpentCount: _notSpentCount,
                        weeklyData: _weeklyData,
                        goals: goals,
                        archivedGoals: _archivedGoals,
                        commitmentBlocks: _commitmentBlocks,
                        onNext: () => _advanceToSection(1),
                      ),

                      // Section 2: Reflection
                      ReflectionSection(
                        goals: goals,
                        goalChunkTotals: _goalChunkTotals,
                        completionRates: _completionRates,
                        onComplete: (answers) {
                          setState(() => _reflectionAnswers = answers);
                          _advanceToSection(2);
                        },
                      ),

                      // Section 3: Adjustments
                      AdjustmentsSection(
                        goals: goals,
                        completionRates: _completionRates,
                        reflectionAnswers: _reflectionAnswers,
                        periodStartYmd: _periodStartYmd,
                        periodEndYmd: _periodEndYmd,
                        goalChunkTotals: _goalChunkTotals,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Not enough data yet',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Keep using Canopy daily and your quarterly review will appear here.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section dots indicator
// ---------------------------------------------------------------------------

class _SectionDots extends StatelessWidget {
  const _SectionDots({
    required this.currentSection,
    required this.totalSections,
  });

  final int currentSection;
  final int totalSections;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(totalSections, (i) {
          final isActive = i == currentSection;
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
