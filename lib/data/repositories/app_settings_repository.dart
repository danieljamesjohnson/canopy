import '../models/app_settings.dart';

/// Single-record repository. Box key is 'settings'.
abstract class AppSettingsRepository {
  Future<AppSettings?> getSettings();
  Future<void> saveSettings(AppSettings settings);
}
