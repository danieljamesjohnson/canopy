import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/scheduled_chunk.dart';
import '../../data/repositories/hive_completion_log_repository.dart';
import '../../data/repositories/hive_quarterly_snapshot_repository.dart';
import '../../providers/schedule_notifier.dart';
import '../../services/quarterly_aggregation_service.dart';
import '../schedule/widgets/schedule_progress_bar.dart';
import 'widgets/review_banner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Map<int, Color> _moodColors = {
    1: Color(0xFF4A6275),
    2: Color(0xFF5C7A8A),
    3: Color(0xFF4A8C7A),
    4: Color(0xFF7AAF6A),
    5: Color(0xFFE8C547),
  };

  static const Map<int, String> _moodEmojis = {
    1: '\u{1F327}\uFE0F',
    2: '\u{1F325}\uFE0F',
    3: '\u26C5',
    4: '\u{1F324}\uFE0F',
    5: '\u2600\uFE0F',
  };

  static const Map<int, String> _moodDescriptions = {
    1: 'Low energy — keep it light today',
    2: 'Cloudy — a few things you can push through',
    3: 'Okay — steady and focused',
    4: 'Good energy — tackle some harder things',
    5: 'Great energy — go for your stretch goals',
  };

  bool _bannerDismissed = false;
  bool _inReviewWindow = false;

  @override
  void initState() {
    super.initState();
    _checkReviewWindow();
  }

  Future<void> _checkReviewWindow() async {
    final logs = await HiveCompletionLogRepository().getAll();
    final latest = await HiveQuarterlySnapshotRepository().getLatest();
    final service = QuarterlyAggregationService();
    if (mounted) {
      setState(() {
        _inReviewWindow = service.isInReviewWindow(
          latestSnapshot: latest,
          allLogs: logs,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheduleNotifier = context.watch<ScheduleNotifier>();

    if (!scheduleNotifier.hasScheduleToday) {
      return _buildEmptyState(context);
    }

    final schedule = scheduleNotifier.todaySchedule!;
    final mood = scheduleNotifier.moodIndex ?? 3;
    final moodColor = _moodColors[mood] ?? _moodColors[3]!;
    final moodEmoji = _moodEmojis[mood] ?? _moodEmojis[3]!;
    final moodDescription = _moodDescriptions[mood] ?? _moodDescriptions[3]!;

    final nextChunk = schedule.chunks
        .where((c) =>
            c.chunkType == ChunkType.work && !c.isCompleted && !c.isSkipped)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Canopy')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScheduleProgressBar(schedule: schedule, moodColor: moodColor),
          if (_inReviewWindow && !_bannerDismissed)
            ReviewBanner(
              onStart: () => context.push('/review'),
              onDismiss: () => setState(() => _bannerDismissed = true),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(moodEmoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    moodDescription,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Up next',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
            ),
          ),
          if (nextChunk == null)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'All done today!',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      nextChunk.rationale.isNotEmpty
                          ? nextChunk.rationale
                          : 'Work block',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${nextChunk.durationMinutes} min',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Canopy')),
      body: Column(
        children: [
          if (_inReviewWindow && !_bannerDismissed)
            ReviewBanner(
              onStart: () => context.push('/review'),
              onDismiss: () => setState(() => _bannerDismissed = true),
            ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No schedule yet',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start your morning check-in to generate today\'s schedule.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton(
                      onPressed: () => context.push('/schedule/checkin'),
                      child: const Text('Start your day'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
