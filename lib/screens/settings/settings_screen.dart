import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../data/repositories/hive_completion_log_repository.dart';
import '../../dev/dev_data_loader.dart';
import '../../providers/settings_notifier.dart';
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
        ],
      ),
    );
  }
}
