import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/commitments_notifier.dart';
import '../../utils/meals.dart';
import '../../widgets/meals_editor.dart';

/// Settings → Meals (Phase 37, D-37-05). The same three rows as the
/// onboarding meals beat, for anyone who has already finished onboarding.
///
/// Opens with the user's saved meals, or — when none are saved — the three
/// defaults switched on, so the first visit is the same one tap as
/// onboarding. "Looks good" saves and returns to Settings.
///
/// Saving does NOT rebuild today's schedule: an already-generated day is
/// only rebuilt by ⟳ Re-check-in (CLAUDE.md trap #4), and the confirmation
/// says so rather than letting the user think the change failed.
class MealsScreen extends StatefulWidget {
  const MealsScreen({super.key, this.pickTime = showMealTimePicker});

  final MealTimePicker pickTime;

  @override
  State<MealsScreen> createState() => _MealsScreenState();
}

class _MealsScreenState extends State<MealsScreen> {
  late final List<MealDraft> _drafts = MealDraft.fromBlocks(
    context.read<CommitmentsNotifier>().mealBlocks,
  );
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.maybeOf(context);
    final navigator = Navigator.of(context);
    try {
      await context.read<CommitmentsNotifier>().saveMeals(_drafts);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Meals saved. Tap ⟳ Re-check-in to see them on today.'),
        ),
      );
      if (router != null && router.canPop()) {
        router.pop();
      } else if (navigator.canPop()) {
        navigator.pop();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't save meals. Please try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = MealsEditor.allValid(_drafts);
    return Scaffold(
      appBar: AppBar(title: const Text('Meals')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                'Canopy keeps these free every day. Work gives way to a meal, '
                'and a meeting takes precedence over one.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              MealsEditor(
                drafts: _drafts,
                onChanged: () => setState(() {}),
                pickTime: widget.pickTime,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: (_saving || !valid) ? null : _save,
                child: const Text('Looks good'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
