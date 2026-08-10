import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/repositories/hive_completion_log_repository.dart';
import '../../dev/dev_clock.dart';
import '../../dev/dev_data_loader.dart';
import '../../providers/commitments_notifier.dart';
import '../../providers/goals_notifier.dart';
import '../../providers/schedule_notifier.dart';
import '../../providers/settings_notifier.dart';
import '../../providers/theme_notifier.dart';
import '../../services/export_service.dart';
import '../../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _exporting = false;

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final suffix = h < 12 ? 'AM' : 'PM';
    final hour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$hour:${m.toString().padLeft(2, '0')} $suffix';
  }

  /// Reloads every startup notifier from the (now-modified) Hive boxes so the
  /// in-memory provider state matches disk after a dev wipe. Notifiers are
  /// constructed in main() before runApp, so clearing a box does not update
  /// them until these reload entry points run.
  Future<void> _reloadNotifiers(BuildContext context) async {
    // Capture every notifier synchronously before any await so we never reach
    // through BuildContext across an async gap.
    final goals = context.read<GoalsNotifier>();
    final commitments = context.read<CommitmentsNotifier>();
    final schedule = context.read<ScheduleNotifier>();
    final settings = context.read<SettingsNotifier>();
    final theme = context.read<ThemeNotifier>();
    await goals.loadGoals();
    await commitments.loadBlocks();
    await schedule.init();
    await settings.init();
    await theme.init();
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              confirmLabel,
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _snack(BuildContext context, String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: error ? 6 : 4),
      ),
    );
  }

  Future<void> _handleResetSchedule(BuildContext context) async {
    final ok = await _confirm(
      context,
      title: "Reset today's schedule?",
      body:
          "Clears today's generated plan (schedule + chunks). Your goals, "
          'commitments, logs, and settings are kept — the next morning '
          'check-in will regenerate from scratch.',
      confirmLabel: 'Reset',
    );
    if (!ok || !context.mounted) return;
    final result = await DevDataLoader.resetTodaySchedule();
    if (!context.mounted) return;
    if (!result.success) {
      _snack(context, 'Reset failed: ${result.error}', error: true);
      return;
    }
    await _reloadNotifiers(context);
    if (!context.mounted) return;
    _snack(context, "Today's schedule cleared. Run the morning check-in.");
  }

  Future<void> _handleFactoryReset(BuildContext context) async {
    final ok = await _confirm(
      context,
      title: 'Factory reset?',
      body:
          'Wipes EVERYTHING — goals, commitments, schedules, chunks, logs, '
          'snapshots, and settings — and returns the app to a fresh first '
          'launch (onboarding). This cannot be undone.',
      confirmLabel: 'Erase everything',
    );
    if (!ok || !context.mounted) return;
    final result = await DevDataLoader.factoryReset();
    if (!context.mounted) return;
    if (!result.success) {
      _snack(context, 'Factory reset failed: ${result.error}', error: true);
      return;
    }
    await _reloadNotifiers(context);
    if (!context.mounted) return;
    _snack(
      context,
      'Wiped ${result.recordsCleared} records across '
      '${result.boxesCleared} boxes. Starting fresh.',
    );
    context.go('/onboarding');
  }

  // ── Phase 25 (Time Travel) — debug clock override ──────────────────────
  //
  // After any DevClock mutation, ScheduleNotifier.reloadToday() re-fetches
  // today's schedule against the (possibly now-different) "today" key, and
  // setState() forces this screen's own status tile to repaint immediately.
  // Everywhere else in the app, the existing 1-minute ticker plus setState
  // does the rest (Today screen's `_startNowTimer`) — no new polling is
  // introduced here.
  Future<void> _afterDevClockChange(BuildContext context) async {
    final schedule = context.read<ScheduleNotifier>();
    await schedule.reloadToday();
    if (!context.mounted) return;
    setState(() {});
  }

  Future<void> _handleDevClockShift(
    BuildContext context,
    Duration delta,
  ) async {
    await DevClock.shift(delta);
    if (!context.mounted) return;
    await _afterDevClockChange(context);
  }

  Future<void> _handleDevClockJumpTo9pm(BuildContext context) async {
    final now = DevClock.now();
    final target = DateTime(now.year, now.month, now.day, 21);
    await DevClock.setSimulatedNow(target);
    if (!context.mounted) return;
    await _afterDevClockChange(context);
  }

  Future<void> _handleDevClockReset(BuildContext context) async {
    await DevClock.clear();
    if (!context.mounted) return;
    await _afterDevClockChange(context);
  }

  Future<void> _handleDevClockSetAbsolute(BuildContext context) async {
    final current = DevClock.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(current.year - 5),
      lastDate: DateTime(current.year + 5),
    );
    if (pickedDate == null || !context.mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (pickedTime == null || !context.mounted) return;
    final target = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    await DevClock.setSimulatedNow(target);
    if (!context.mounted) return;
    await _afterDevClockChange(context);
  }

  Future<void> _handleExport(BuildContext context) async {
    setState(() => _exporting = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Preparing export...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    try {
      final logs = await HiveCompletionLogRepository().getAll();
      await ExportService.exportCompletionLog(logs);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Export failed. Try again.'),
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsNotifier>();
    final morningEnabled = settings.morningNotificationEnabled;
    final morningMinutes = settings.morningNotificationMinutes;
    final midDayEnabled = settings.midDayNudgeEnabled;
    final midDayMinutes = settings.midDayNudgeMinutes;
    final eveningEnabled = settings.eveningReminderEnabled;
    final eveningMinutes = settings.eveningReminderMinutes;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Notifications section heading
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Notifications',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),

          // Morning reminder row
          ListTile(
            leading: const Icon(Icons.alarm),
            title: const Text('Morning reminder'),
            subtitle: Text(
              morningEnabled ? _formatMinutes(morningMinutes) : 'Off',
            ),
            trailing: Switch(
              value: morningEnabled,
              onChanged: (val) async {
                await context
                    .read<SettingsNotifier>()
                    .setMorningNotificationEnabled(val);
                if (val) {
                  await NotificationService.scheduleMorningNotification(
                    morningMinutes,
                  );
                } else {
                  await NotificationService.cancelMorningNotification();
                }
              },
            ),
            onTap: morningEnabled
                ? () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: morningMinutes ~/ 60,
                        minute: morningMinutes % 60,
                      ),
                    );
                    if (picked != null && context.mounted) {
                      final newMinutes = picked.hour * 60 + picked.minute;
                      await context
                          .read<SettingsNotifier>()
                          .setMorningNotificationMinutes(newMinutes);
                      await NotificationService.scheduleMorningNotification(
                        newMinutes,
                      );
                    }
                  }
                : null,
          ),

          // Mid-day nudge row
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Mid-day nudge'),
            subtitle: Text(
              midDayEnabled
                  ? _formatMinutes(midDayMinutes)
                  : 'Opt-in reminder to check your schedule',
            ),
            trailing: Switch(
              value: midDayEnabled,
              onChanged: (val) async {
                await context.read<SettingsNotifier>().setMidDayNudgeEnabled(
                  val,
                );
                if (val) {
                  await NotificationService.scheduleMidDayNudge(midDayMinutes);
                } else {
                  await NotificationService.cancelMidDayNudge();
                }
              },
            ),
            onTap: midDayEnabled
                ? () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: midDayMinutes ~/ 60,
                        minute: midDayMinutes % 60,
                      ),
                    );
                    if (picked != null && context.mounted) {
                      final newMinutes = picked.hour * 60 + picked.minute;
                      await context
                          .read<SettingsNotifier>()
                          .setMidDayNudgeMinutes(newMinutes);
                      await NotificationService.scheduleMidDayNudge(newMinutes);
                    }
                  }
                : null,
          ),

          // Evening reminder row
          ListTile(
            leading: const Icon(Icons.nights_stay_outlined),
            title: const Text('Evening reminder'),
            subtitle: Text(
              eveningEnabled
                  ? _formatMinutes(eveningMinutes)
                  : 'Opt-in reminder to close your day',
            ),
            trailing: Switch(
              value: eveningEnabled,
              onChanged: (val) async {
                await context
                    .read<SettingsNotifier>()
                    .setEveningReminderEnabled(val);
                if (val) {
                  await NotificationService.scheduleEveningReminder(
                    eveningMinutes,
                  );
                } else {
                  await NotificationService.cancelEveningReminder();
                }
              },
            ),
            onTap: null, // no time picker this phase — fixed 8:00pm
          ),

          // Android battery note
          if (!kIsWeb && Platform.isAndroid)
            ListTile(
              dense: true,
              subtitle: Text(
                'Reminders may arrive up to 15 minutes early due to device battery settings.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),

          const Divider(indent: 16, endIndent: 16),

          // Data section heading
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Data',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),

          // Export data row
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Export data'),
            subtitle: const Text(
              'Download a JSON file of all your completion history',
            ),
            trailing: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _exporting ? null : () => _handleExport(context),
          ),

          const Divider(indent: 16, endIndent: 16),

          // Reviews section heading
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Reviews',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),

          // Past reviews row
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Past reviews'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/past-reviews'),
          ),

          // Debug section heading — dev builds only (divider + heading gated
          // together so neither shows in release).
          if (kDebugMode) ...[
            const Divider(indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Debug',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],

          // Dev-only: Phase 25 (Time Travel) clock override. Stripped in
          // release — every control below routes through DevClock, whose
          // mutators are themselves kDebugMode-gated (DEV-03 belt-and-braces).
          if (kDebugMode)
            ListTile(
              leading: Icon(
                Icons.schedule_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: const Text('Time travel'),
              subtitle: Text(
                DevClock.isActive
                    ? 'Simulated: '
                          '${DateFormat('EEE d MMM, h:mm a').format(DevClock.now())}'
                    : 'Off — showing real time',
              ),
            ),
          if (kDebugMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => _handleDevClockShift(
                      context,
                      const Duration(hours: -1),
                    ),
                    child: const Text('-1h'),
                  ),
                  OutlinedButton(
                    onPressed: () =>
                        _handleDevClockShift(context, const Duration(hours: 1)),
                    child: const Text('+1h'),
                  ),
                  OutlinedButton(
                    onPressed: () => _handleDevClockJumpTo9pm(context),
                    child: const Text('Jump to 9pm today'),
                  ),
                  OutlinedButton(
                    onPressed: DevClock.isActive
                        ? () => _handleDevClockReset(context)
                        : null,
                    child: const Text('Reset to real time'),
                  ),
                ],
              ),
            ),
          if (kDebugMode)
            ListTile(
              leading: const Icon(Icons.edit_calendar_outlined),
              title: const Text('Set a specific time'),
              subtitle: const Text('Pick an exact simulated date & time'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _handleDevClockSetAbsolute(context),
            ),

          // Dev-only: open quarterly review directly (UAT shortcut). Stripped in release.
          if (kDebugMode)
            ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Open quarterly review (dev)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/review'),
            ),

          // Dev-only: ingest a canned scenario into Hive. Stripped in release.
          if (kDebugMode)
            ListTile(
              leading: const Icon(Icons.cloud_download_outlined),
              title: const Text('Ingest dev data'),
              subtitle: const Text(
                'Loads the typical_quarter scenario into Hive',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final result = await DevDataLoader.ingest();
                if (!context.mounted) return;
                if (result.success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Loaded ${result.goalsLoaded} goals, '
                        '${result.logsLoaded} logs, '
                        '${result.snapshotsLoaded} snapshots.',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Ingest failed: ${result.error}'),
                      duration: const Duration(seconds: 6),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),

          // Dev-only: wipe goals/logs/snapshots from Hive. Stripped in release.
          if (kDebugMode)
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined),
              title: const Text('Clear all dev data'),
              subtitle: const Text(
                'Wipes goals, logs, and snapshots from Hive',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear all dev data?'),
                    content: const Text(
                      'This wipes all goals, completion logs, and quarterly '
                      'snapshots from local storage. Settings, schedules, '
                      'and commitment blocks are not affected. This cannot '
                      'be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text(
                          'Clear',
                          style: TextStyle(
                            color: Theme.of(ctx).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
                if (!context.mounted) return;
                final result = await DevDataLoader.clearAll();
                if (!context.mounted) return;
                if (result.success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Cleared ${result.goalsCleared} goals, '
                        '${result.logsCleared} logs, '
                        '${result.snapshotsCleared} snapshots.',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Clear failed: ${result.error}'),
                      duration: const Duration(seconds: 6),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),

          // Dev-only: clear just today's generated plan, keep goals. Re-run the
          // morning check-in to regenerate. Stripped in release.
          if (kDebugMode)
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text("Reset today's schedule"),
              subtitle: const Text(
                'Clears the generated plan; keeps goals & commitments',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _handleResetSchedule(context),
            ),

          // Dev-only: full wipe back to first-launch onboarding. Stripped in
          // release.
          if (kDebugMode)
            ListTile(
              leading: Icon(
                Icons.restart_alt,
                color: Theme.of(context).colorScheme.error,
              ),
              title: const Text('Factory reset (fresh onboarding)'),
              subtitle: const Text(
                'Wipes everything and returns to first launch',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _handleFactoryReset(context),
            ),
        ],
      ),
    );
  }
}
