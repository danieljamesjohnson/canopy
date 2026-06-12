import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/goal.dart';
import '../../providers/goals_notifier.dart';
import 'widgets/goal_card.dart';

class ArchivedGoalsScreen extends StatefulWidget {
  const ArchivedGoalsScreen({super.key});

  @override
  State<ArchivedGoalsScreen> createState() => _ArchivedGoalsScreenState();
}

class _ArchivedGoalsScreenState extends State<ArchivedGoalsScreen> {
  List<Goal> _archivedGoals = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadArchived());
  }

  Future<void> _loadArchived() async {
    final goals = await context.read<GoalsNotifier>().getArchivedGoals();
    if (mounted) {
      setState(() {
        _archivedGoals = goals;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Archived Goals')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _archivedGoals.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.archive_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No archived goals',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _archivedGoals.length,
              itemBuilder: (context, index) {
                return GoalCard(goal: _archivedGoals[index]);
              },
            ),
    );
  }
}
