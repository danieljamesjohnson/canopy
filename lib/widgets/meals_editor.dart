import 'package:flutter/material.dart';

import '../utils/meals.dart';
import '../utils/time_format.dart';

/// Picks a time of day, returning minutes from midnight, or null when the
/// user cancels. The default shows the platform time picker; tests inject a
/// fake so they can set a time without driving the dial.
typedef MealTimePicker =
    Future<int?> Function(BuildContext context, int currentMinutes);

Future<int?> showMealTimePicker(
  BuildContext context,
  int currentMinutes,
) async {
  final result = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(
      hour: currentMinutes ~/ 60,
      minute: currentMinutes % 60,
    ),
  );
  return result == null ? null : result.hour * 60 + result.minute;
}

/// The three meal rows (Phase 37) — shared verbatim by the onboarding meals
/// beat and Settings → Meals, so both offer exactly the same thing (D-37-05).
///
/// Each row is a switch plus tappable start and end times. The editor mutates
/// the [drafts] it is given and calls [onChanged] so the owner can rebuild
/// and re-check validity; it holds no state of its own.
class MealsEditor extends StatelessWidget {
  const MealsEditor({
    super.key,
    required this.drafts,
    required this.onChanged,
    this.pickTime = showMealTimePicker,
  });

  final List<MealDraft> drafts;
  final VoidCallback onChanged;
  final MealTimePicker pickTime;

  /// True when every switched-on meal is at least [kMinMealMinutes] long.
  static bool allValid(List<MealDraft> drafts) =>
      drafts.every((d) => d.isValid);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final d in drafts)
          _MealRow(draft: d, onChanged: onChanged, pickTime: pickTime),
      ],
    );
  }
}

class _MealRow extends StatelessWidget {
  const _MealRow({
    required this.draft,
    required this.onChanged,
    required this.pickTime,
  });

  final MealDraft draft;
  final VoidCallback onChanged;
  final MealTimePicker pickTime;

  Future<void> _pick(
    BuildContext context,
    int current,
    void Function(int) set,
  ) async {
    final picked = await pickTime(context, current);
    if (picked == null) return;
    set(picked);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = draft.slot.kind;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(draft.slot.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  draft.slot.label,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Switch(
                key: Key('meal-switch-$kind'),
                value: draft.enabled,
                onChanged: (v) {
                  draft.enabled = v;
                  onChanged();
                },
              ),
            ],
          ),
          if (draft.enabled) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: _TimeButton(
                    key: Key('meal-start-$kind'),
                    label: 'Start',
                    minutes: draft.startMinutes,
                    onTap: () => _pick(
                      context,
                      draft.startMinutes,
                      (v) => draft.startMinutes = v,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeButton(
                    key: Key('meal-end-$kind'),
                    label: 'End',
                    minutes: draft.endMinutes,
                    onTap: () => _pick(
                      context,
                      draft.endMinutes,
                      (v) => draft.endMinutes = v,
                    ),
                  ),
                ),
              ],
            ),
            if (!draft.isValid)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'End needs to be at least $kMinMealMinutes minutes after '
                  'the start.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    super.key,
    required this.label,
    required this.minutes,
    required this.onTap,
  });

  final String label;
  final int minutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(formatMinutes(minutes), style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
