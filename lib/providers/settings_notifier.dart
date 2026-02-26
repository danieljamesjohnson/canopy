import 'package:flutter/foundation.dart';
import '../data/models/app_settings.dart';
import '../data/repositories/app_settings_repository.dart';
import '../data/repositories/hive_app_settings_repository.dart';

class SettingsNotifier extends ChangeNotifier {
  final AppSettingsRepository _repository = HiveAppSettingsRepository();

  bool _onboardingComplete = false;
  bool get onboardingComplete => _onboardingComplete;

  /// Reads persisted settings from Hive and caches the values.
  /// Call once at startup after HiveDatabase.init(), before runApp().
  Future<void> init() async {
    final settings = await _repository.getSettings();
    _onboardingComplete = settings?.onboardingComplete ?? false;
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
}
