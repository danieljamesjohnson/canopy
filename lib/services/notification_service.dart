import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Optional callback invoked when user taps a notification.
  static void Function(NotificationResponse)? onTapCallback;

  static Future<void> initialize() async {
    if (kIsWeb) return; // Web: no-op, in-app banner fallback used instead

    // Configure timezone
    tz.initializeTimeZones();
    if (!Platform.isLinux && !Platform.isWindows) {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false, // Defer until after first check-in
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );
  }

  static void _handleNotificationTap(NotificationResponse response) {
    onTapCallback?.call(response);
  }

  /// Requests iOS notification permissions (no-op on other platforms).
  /// Call after first successful mood check-in so user has experienced value.
  static Future<void> requestIOSPermissions() async {
    if (kIsWeb || !Platform.isIOS) return;
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Schedules a daily morning notification at [minutesFromMidnight].
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

  /// Schedules a daily mid-day nudge notification at [minutesFromMidnight].
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
      title: 'Mid-day check-in',
      body: 'How is your schedule going?',
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

  /// Cancels the morning notification.
  static Future<void> cancelMorningNotification() async {
    if (kIsWeb) return;
    await _plugin.cancel(id: 0);
  }

  /// Cancels the mid-day nudge notification.
  static Future<void> cancelMidDayNudge() async {
    if (kIsWeb) return;
    await _plugin.cancel(id: 1);
  }
}
