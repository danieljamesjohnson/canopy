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

  /// Mood seed ARGB int value. Null = pre-check-in 'curious' state
  /// (UI-SPEC §Color §Pre-Check-in Curious Seed). Set when user taps a mood
  /// at check-in; cleared on daily rollover (Phase 6 D-10).
  @HiveField(5)
  int? moodSeedArgb;

  /// YYYYMMDD-encoded local date of the last `setMoodSeed` call. Read by
  /// `ThemeNotifier.init()` and on `AppLifecycleState.resumed` to enforce
  /// the no-carry-forward rule (D-10). Null = no mood ever set yet.
  @HiveField(6)
  int? lastMoodSetYmdInt;
}
