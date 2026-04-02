import 'package:flutter/foundation.dart';
import '../data/models/app_settings.dart';
import '../data/repositories/app_settings_repository.dart';
import '../data/repositories/hive_app_settings_repository.dart';

class SettingsNotifier extends ChangeNotifier {
  final AppSettingsRepository _repository = HiveAppSettingsRepository();

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

  /// Reads persisted settings from Hive and caches the values.
  /// Call once at startup after HiveDatabase.init(), before runApp().
  Future<void> init() async {
    final settings = await _repository.getSettings();
    _onboardingComplete = settings?.onboardingComplete ?? false;
    _morningNotificationMinutes = settings?.morningNotificationMinutes ?? 450;
    _morningNotificationEnabled = settings?.morningNotificationEnabled ?? true;
    _midDayNudgeEnabled = settings?.midDayNudgeEnabled ?? false;
    _midDayNudgeMinutes = settings?.midDayNudgeMinutes ?? 720;
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
}
