import 'package:hive_ce/hive.dart';

part 'app_settings.g.dart';

/// Single-record box. Always stored at key 'settings'.
@HiveType(typeId: 6)
class AppSettings extends HiveObject {
  /// Morning notification time in minutes from midnight (default 450 = 7:30am).
  @HiveField(0)
  int morningNotificationMinutes = 450;

  /// Whether the user has completed onboarding.
  @HiveField(1)
  bool onboardingComplete = false;

  /// Whether the morning notification is enabled (default true).
  @HiveField(4)
  bool morningNotificationEnabled = true;

  /// Mid-day nudge opt-in (default false per ROADMAP.md).
  @HiveField(2)
  bool midDayNudgeEnabled = false;

  /// Mid-day nudge time in minutes from midnight (default 720 = 12:00pm).
  @HiveField(3)
  int midDayNudgeMinutes = 720;
}
