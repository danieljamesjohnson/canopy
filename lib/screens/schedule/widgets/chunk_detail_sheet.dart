import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/scheduled_chunk.dart';
import '../../../providers/schedule_notifier.dart';

/// Bottom sheet displayed when the user taps an unresolved work chunk.
/// Shows goal name, rationale, and Complete/Skip/Defer action buttons.
///
/// For resolved chunks shows goal name + rationale + a status badge only
/// (no action buttons).
///
/// The [notifier] is passed in by the caller (schedule_screen.dart) rather
/// than resolved from context to avoid ProviderNotFoundException when the
/// sheet is built outside the Provider subtree (Pitfall 5 / T-08-04).
class ChunkDetailSheet extends StatelessWidget {
  const ChunkDetailSheet({
    super.key,
    required this.chunk,
    required this.notifier,
    this.goalColor,
    this.goalName,
    required this.displayRationale,
  });

  final ScheduledChunk chunk;
  final ScheduleNotifier notifier;
  final Color? goalColor;
  final String? goalName;
  final String displayRationale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isResolved = chunk.isCompleted || chunk.isSkipped;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle (goal_form_sheet.dart pattern)
          Center(
            child: Container(
              width: 32,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Goal color mini-bar + name/rationale row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: goalColor ?? colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goalName ?? displayRationale,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (displayRationale.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        displayRationale,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          if (!isResolved) ...[
            // Start focus entry point (above action buttons)
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                icon: const Icon(Icons.center_focus_strong_outlined),
                label: const Text('Start focus'),
                onPressed: () {
                  context.pop();
                  context.push('/focus', extra: chunk.id);
                },
              ),
            ),
            const SizedBox(height: 8),
            // Mark complete
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Mark complete'),
                onPressed: () {
                  notifier.markComplete(chunk.id);
                  context.pop();
                },
              ),
            ),
            const SizedBox(height: 8),
            // Skip chunk
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.skip_next_outlined),
                label: const Text('Skip chunk'),
                onPressed: () {
                  notifier.markSkipped(chunk.id);
                  context.pop();
                },
              ),
            ),
            const SizedBox(height: 8),
            // Defer to later
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                icon: const Icon(Icons.schedule_outlined),
                label: const Text('Defer to later'),
                style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                onPressed: () {
                  notifier.markDeferred(chunk.id);
                  context.pop();
                },
              ),
            ),
          ] else ...[
            // Resolved state — show status badge, no action buttons.
            Text(
              chunk.isCompleted ? 'Completed' : 'Skipped',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
