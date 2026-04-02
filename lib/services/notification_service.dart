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
  /// - iOS: defers permission request until [requestIOSPermissions] is called.
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
    const ios = DarwinInitializationSettings(
      // Defer permission request until after first successful check-in.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const linux = LinuxInitializationSettings(
      defaultActionName: 'Open',
    );
    const settings = InitializationSettings(
      android: android,
      iOS: ios,
      linux: linux,
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
      int minutesFromMidnight) async {
    if (kIsWeb) return;
    await _plugin.cancel(id: 0);
    final hour = minutesFromMidnight ~/ 60;
    final minute = minutesFromMidnight % 60;

    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
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
    await _plugin.cancel(id: 1);
    final hour = minutesFromMidnight ~/ 60;
    final minute = minutesFromMidnight % 60;

    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
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

  /// Requests iOS notification permissions.
  ///
  /// Call this after the first successful mood check-in. No-op on Web and
  /// non-iOS platforms. iOS silently ignores if permissions already granted.
  static Future<void> requestIOSPermissions() async {
    if (kIsWeb) return;
    if (!Platform.isIOS) return;
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }
}
