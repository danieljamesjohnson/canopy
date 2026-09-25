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

  /// Evening reminder opt-in (default false — opt-in per CLOSE-01).
  @HiveField(7)
  bool eveningReminderEnabled = false;

  /// Evening reminder time in minutes from midnight (default 1200 = 8:00pm).
  @HiveField(8)
  int eveningReminderMinutes = 1200;

  /// The calendar ids the user has chosen to import from, out of the full
  /// list the current [CalendarSource] reports via `listCalendars()`
  /// (CAL-02). Additive field — old records deserialize with an empty list,
  /// i.e. an upgrading user has no calendar selected until they visit the
  /// new calendar settings screen.
  @HiveField(9, defaultValue: <String>[])
  List<String> selectedCalendarIds = [];

  /// Subscribed `.ics` feed URLs (desktop/web path, D-35-12) — one row per
  /// URL in the calendar settings screen. Additive field — old records
  /// deserialize with an empty list, i.e. an upgrading user has no feeds
  /// configured until they add one.
  @HiveField(10, defaultValue: <String>[])
  List<String> icsUrls = [];

  /// When the last calendar sync completed, for the "synced {relative
  /// time}" status line. Additive field — old records deserialize with
  /// null, i.e. an upgrading user has never synced.
  @HiveField(11)
  DateTime? lastCalendarSyncAt;

  /// The persisted Google OAuth access token (CALAUTH-01/02). Additive
  /// field — old records deserialize with null, i.e. an upgrading user has
  /// no Google connection until they sign in.
  @HiveField(12)
  String? googleAccessToken;

  /// The persisted Google OAuth refresh token, used to obtain a fresh access
  /// token without re-prompting the user (CALAUTH-01/02). Additive field —
  /// old records deserialize with null.
  @HiveField(13)
  String? googleRefreshToken;

  /// When [googleAccessToken] expires, in UTC. Additive field — old records
  /// deserialize with null.
  @HiveField(14)
  DateTime? googleAccessTokenExpiresAt;

  /// True when the stored Google credential has been found dead (e.g. an
  /// expired 7-day refresh token) and the user must reconnect (CALAUTH-03).
  /// Additive field — old records deserialize with false, i.e. an upgrading
  /// user with no Google connection is correctly not shown a reconnect
  /// prompt.
  ///
  /// Carries `defaultValue: false` DELIBERATELY, unlike this class's other
  /// bool fields (Deviation from plan: measured, not assumed — a genuinely
  /// old 9-field record fed through `AppSettingsAdapter.read` crashes with
  /// `type 'Null' is not a subtype of type 'bool'` on the generated
  /// `fields[15] as bool` cast when this annotation is absent, because
  /// unlike a NULLABLE field's `as bool?`, hive_ce_generator emits a
  /// non-nullable cast for a plain `bool` with no default and does not
  /// itself supply a `false` fallback. Proven by
  /// `test/providers/settings_notifier_calendar_test.dart`'s existing old
  /// -record round-trip, which failed until this annotation was added — see
  /// 36-01-SUMMARY.md for the observed stack trace and WINDOWS.md entry 3,
  /// which already flagged this exact latent risk in this class's other
  /// bool fields.
  @HiveField(15, defaultValue: false)
  bool googleReconnectNeeded = false;
}
