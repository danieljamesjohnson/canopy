import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Service wrapper around [FlutterLocalNotificationsPlugin].
///
/// Call [initialize] once in `main()` before `runApp()`. On Web this is a
/// no-op — use the in-app `MaterialBanner` fallback on that platform.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Callback invoked when the user taps a notification.
  ///
  /// Set this in `main()` after [initialize] to wire navigation.
  static void Function(NotificationResponse)? onTapCallback;

  static void _onNotificationTapped(NotificationResponse response) {
    onTapCallback?.call(response);
  }

  /// Initializes the notification plugin.
  ///
  /// - Web: returns immediately (banner fallback).
  /// - iOS/macOS: defers permission request until [requestDarwinPermissions]
  ///   is called.
  /// - Windows/Linux: skips timezone setup (no notification scheduling on
  ///   those platforms requires TZDateTime).
  static Future<void> initialize() async {
    if (kIsWeb) return;

    // Configure timezone database.
    tz.initializeTimeZones();
    if (!Platform.isLinux && !Platform.isWindows) {
      try {
        final tzInfo = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
      } catch (_) {
        // Fallback: use UTC if timezone lookup fails.
        tz.setLocalLocation(tz.UTC);
      }
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    // macOS and iOS share a Darwin settings instance — same deferred-permission
    // semantics for both. requestDarwinPermissions() handles the explicit request
    // after the first successful check-in.
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const linux = LinuxInitializationSettings(defaultActionName: 'Open');
    // Windows toast notification identity. The GUID is a stable v4 — do NOT
    // regenerate per-build; it is the activation callback identifier and must
    // remain stable across versions for in-flight scheduled notifications to
    // resolve. appUserModelId follows the reverse-DNS pattern recommended by
    // https://docs.microsoft.com/en-us/windows/win32/shell/appids.
    const windows = WindowsInitializationSettings(
      appName: 'Canopy',
      appUserModelId: 'com.canopy.app.Canopy',
      guid: 'a3f7c2e8-9b1d-4a6f-8c5e-2d4b7f9a1c3e',
    );
    const settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
      linux: linux,
      windows: windows,
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Schedules the daily morning reminder at [minutesFromMidnight].
  ///
  /// Cancels any existing morning notification (ID 0) first.
  static Future<void> scheduleMorningNotification(
    int minutesFromMidnight,
  ) async {
    if (kIsWeb) return;
    // LOOP-04: zonedSchedule is not supported on Linux or Windows desktop —
    // degrade gracefully so the app does not crash when running on those
    // platforms. iOS and Android are the real targets.
    if (Platform.isLinux || Platform.isWindows) return;
    await _plugin.cancel(id: 0);
    final hour = minutesFromMidnight ~/ 60;
    final minute = minutesFromMidnight % 60;

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: 0,
      title: 'Good morning',
      body: 'Ready to plan your day?',
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'morning_reminder',
          'Morning reminder',
          channelDescription: 'Daily morning schedule reminder',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Schedules an optional mid-day nudge at [minutesFromMidnight].
  ///
  /// Cancels any existing mid-day nudge (ID 1) first.
  static Future<void> scheduleMidDayNudge(int minutesFromMidnight) async {
    if (kIsWeb) return;
    // LOOP-04: zonedSchedule is not supported on Linux or Windows desktop —
    // degrade gracefully so the app does not crash when running on those
    // platforms. iOS and Android are the real targets.
    if (Platform.isLinux || Platform.isWindows) return;
    await _plugin.cancel(id: 1);
    final hour = minutesFromMidnight ~/ 60;
    final minute = minutesFromMidnight % 60;

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: 1,
      title: "How's your day going?",
      body: 'Check in on your schedule.',
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'midday_nudge',
          'Mid-day nudge',
          channelDescription: 'Optional mid-day schedule reminder',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Cancels the morning notification (ID 0).
  static Future<void> cancelMorningNotification() async {
    if (kIsWeb) return;
    await _plugin.cancel(id: 0);
  }

  /// Cancels the mid-day nudge (ID 1).
  static Future<void> cancelMidDayNudge() async {
    if (kIsWeb) return;
    await _plugin.cancel(id: 1);
  }

  /// Schedules an opt-in evening reminder at [minutesFromMidnight].
  ///
  /// Cancels any existing evening reminder (ID 2) first.
  static Future<void> scheduleEveningReminder(int minutesFromMidnight) async {
    if (kIsWeb) return;
    // T-10-05: zonedSchedule is not supported on Linux or Windows desktop —
    // degrade gracefully so the app does not crash when running on those
    // platforms. iOS and Android are the real targets.
    if (Platform.isLinux || Platform.isWindows) return;
    await _plugin.cancel(id: 2);
    final hour = minutesFromMidnight ~/ 60;
    final minute = minutesFromMidnight % 60;

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: 2,
      title: 'Canopy',
      body: 'Time to close the day. See how your chunks went.',
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'evening_reminder',
          'Evening reminder',
          channelDescription: 'Opt-in evening schedule reminder',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Cancels the evening reminder (ID 2).
  static Future<void> cancelEveningReminder() async {
    if (kIsWeb) return;
    await _plugin.cancel(id: 2);
  }

  /// Requests notification permissions on Darwin platforms (iOS and macOS).
  ///
  /// Call this after the first successful mood check-in. No-op on Web and
  /// non-Darwin platforms. Darwin platforms silently ignore if permissions
  /// are already granted.
  static Future<void> requestDarwinPermissions() async {
    if (kIsWeb) return;
    if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return;
    }
    if (Platform.isMacOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return;
    }
    // Android/Linux/Windows: no-op. Android requests permission via
    // AndroidInitializationSettings at install time on API < 33; Android 13+
    // permission is requested at first scheduling attempt automatically by
    // the plugin. Linux and Windows do not require a runtime permission.
  }

  /// Back-compat alias for [requestDarwinPermissions].
  ///
  /// Retained so existing callers in `lib/screens/schedule/checkin_screen.dart`
  /// continue to compile without modification. Prefer the Darwin name in new
  /// code.
  static Future<void> requestIOSPermissions() => requestDarwinPermissions();
}
