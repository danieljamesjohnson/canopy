import 'package:flutter/foundation.dart';
import '../data/models/app_settings.dart';
import '../data/repositories/app_settings_repository.dart';
import '../data/repositories/hive_app_settings_repository.dart';

class SettingsNotifier extends ChangeNotifier {
  SettingsNotifier({AppSettingsRepository? repository})
    : _repository = repository ?? HiveAppSettingsRepository();

  final AppSettingsRepository _repository;

  bool _onboardingComplete = false;
  bool get onboardingComplete => _onboardingComplete;

  int _morningNotificationMinutes = 450;
  int get morningNotificationMinutes => _morningNotificationMinutes;

  bool _morningNotificationEnabled = true;
  bool get morningNotificationEnabled => _morningNotificationEnabled;

  bool _midDayNudgeEnabled = false;
  bool get midDayNudgeEnabled => _midDayNudgeEnabled;

  int _midDayNudgeMinutes = 720;
  int get midDayNudgeMinutes => _midDayNudgeMinutes;

  bool _eveningReminderEnabled = false;
  bool get eveningReminderEnabled => _eveningReminderEnabled;

  int _eveningReminderMinutes = 1200;
  int get eveningReminderMinutes => _eveningReminderMinutes;

  List<String> _selectedCalendarIds = [];
  List<String> get selectedCalendarIds => List.unmodifiable(_selectedCalendarIds);

  List<String> _icsUrls = [];
  List<String> get icsUrls => List.unmodifiable(_icsUrls);

  DateTime? _lastCalendarSyncAt;
  DateTime? get lastCalendarSyncAt => _lastCalendarSyncAt;

  /// Reads persisted settings from Hive and caches the values.
  /// Call once at startup after HiveDatabase.init(), before runApp().
  Future<void> init() async {
    final settings = await _repository.getSettings();
    _onboardingComplete = settings?.onboardingComplete ?? false;
    _morningNotificationMinutes = settings?.morningNotificationMinutes ?? 450;
    _morningNotificationEnabled = settings?.morningNotificationEnabled ?? true;
    _midDayNudgeEnabled = settings?.midDayNudgeEnabled ?? false;
    _midDayNudgeMinutes = settings?.midDayNudgeMinutes ?? 720;
    _eveningReminderEnabled = settings?.eveningReminderEnabled ?? false;
    _eveningReminderMinutes = settings?.eveningReminderMinutes ?? 1200;
    _selectedCalendarIds = settings?.selectedCalendarIds ?? [];
    _icsUrls = settings?.icsUrls ?? [];
    _lastCalendarSyncAt = settings?.lastCalendarSyncAt;
    notifyListeners();
  }

  /// Persists [value] to the AppSettings Hive box and notifies listeners.
  Future<void> setOnboardingComplete(bool value) async {
    _onboardingComplete = value;
    AppSettings settings = await _repository.getSettings() ?? AppSettings();
    settings.onboardingComplete = value;
    await _repository.saveSettings(settings);
    notifyListeners(); // triggers go_router redirect re-evaluation
  }

  Future<void> setMorningNotificationMinutes(int value) async {
    _morningNotificationMinutes = value;
    final settings = await _repository.getSettings() ?? AppSettings();
    settings.morningNotificationMinutes = value;
    await _repository.saveSettings(settings);
    notifyListeners();
  }

  Future<void> setMorningNotificationEnabled(bool value) async {
    _morningNotificationEnabled = value;
    final settings = await _repository.getSettings() ?? AppSettings();
    settings.morningNotificationEnabled = value;
    await _repository.saveSettings(settings);
    notifyListeners();
  }

  Future<void> setMidDayNudgeEnabled(bool value) async {
    _midDayNudgeEnabled = value;
    final settings = await _repository.getSettings() ?? AppSettings();
    settings.midDayNudgeEnabled = value;
    await _repository.saveSettings(settings);
    notifyListeners();
  }

  Future<void> setMidDayNudgeMinutes(int value) async {
    _midDayNudgeMinutes = value;
    final settings = await _repository.getSettings() ?? AppSettings();
    settings.midDayNudgeMinutes = value;
    await _repository.saveSettings(settings);
    notifyListeners();
  }

  Future<void> setEveningReminderEnabled(bool value) async {
    _eveningReminderEnabled = value;
    final settings = await _repository.getSettings() ?? AppSettings();
    settings.eveningReminderEnabled = value;
    await _repository.saveSettings(settings);
    notifyListeners();
  }

  Future<void> setEveningReminderMinutes(int value) async {
    _eveningReminderMinutes = value;
    final settings = await _repository.getSettings() ?? AppSettings();
    settings.eveningReminderMinutes = value;
    await _repository.saveSettings(settings);
    notifyListeners();
  }

  /// Replaces the full CAL-02 calendar selection.
  Future<void> setSelectedCalendarIds(List<String> value) async {
    _selectedCalendarIds = List.unmodifiable(value);
    final settings = await _repository.getSettings() ?? AppSettings();
    settings.selectedCalendarIds = List.of(value);
    await _repository.saveSettings(settings);
    notifyListeners();
  }

  /// Adds [url] to the subscribed feed list, unless it's already present.
  Future<void> addIcsUrl(String url) async {
    if (_icsUrls.contains(url)) return;
    _icsUrls = List.unmodifiable([..._icsUrls, url]);
    final settings = await _repository.getSettings() ?? AppSettings();
    settings.icsUrls = List.of(_icsUrls);
    await _repository.saveSettings(settings);
    notifyListeners();
  }

  /// Removes [url] from the subscribed feed list, if present.
  Future<void> removeIcsUrl(String url) async {
    _icsUrls = List.unmodifiable(
      _icsUrls.where((existing) => existing != url),
    );
    final settings = await _repository.getSettings() ?? AppSettings();
    settings.icsUrls = List.of(_icsUrls);
    await _repository.saveSettings(settings);
    notifyListeners();
  }

  /// Records when the last calendar sync completed (or clears it).
  Future<void> setLastCalendarSyncAt(DateTime? value) async {
    _lastCalendarSyncAt = value;
    final settings = await _repository.getSettings() ?? AppSettings();
    settings.lastCalendarSyncAt = value;
    await _repository.saveSettings(settings);
    notifyListeners();
  }
}
