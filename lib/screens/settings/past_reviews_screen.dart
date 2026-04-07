import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/quarterly_snapshot.dart';
import '../../data/repositories/hive_quarterly_snapshot_repository.dart';

class PastReviewsScreen extends StatefulWidget {
  const PastReviewsScreen({super.key});

  @override
  State<PastReviewsScreen> createState() => _PastReviewsScreenState();
}

class _PastReviewsScreenState extends State<PastReviewsScreen> {
  List<QuarterlySnapshot>? _snapshots;

  @override
  void initState() {
    super.initState();
    _loadSnapshots();
  }

  Future<void> _loadSnapshots() async {
    final all = await HiveQuarterlySnapshotRepository().getAll();
    // Sort descending by completedAt
    all.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    if (mounted) {
      setState(() => _snapshots = all);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Past reviews')),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final snapshots = _snapshots;

    if (snapshots == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshots.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'No reviews yet -- complete your first quarterly review to see it here.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Build list sorted descending (already sorted); compute Q numbers from oldest
    // Q1 = oldest, Q2 = second oldest, etc.
    final oldestFirst = snapshots.reversed.toList();

    return ListView.builder(
      itemCount: snapshots.length,
      itemBuilder: (context, index) {
        final snapshot = snapshots[index];
        // Q number is 1-based from oldest: find position in oldestFirst list
        final qNumber = oldestFirst.indexOf(snapshot) + 1;

        final periodStart = DateTime.parse(snapshot.periodStartYmd);
        final monthYear = DateFormat('MMM yyyy').format(periodStart);

        final totalChunks =
            snapshot.goalChunkTotals.values.fold(0, (sum, v) => sum + v);

        return ListTile(
          title: Text('Q$qNumber -- $monthYear'),
          trailing: Text(
            '$totalChunks chunks completed',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        );
      },
    );
  }
}
