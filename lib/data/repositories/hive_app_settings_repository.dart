import 'package:hive_ce/hive.dart';
import '../models/app_settings.dart';
import 'app_settings_repository.dart';

class HiveAppSettingsRepository implements AppSettingsRepository {
  Box<AppSettings> get _box => Hive.box<AppSettings>('app_settings');

  @override
  Future<AppSettings?> getSettings() async => _box.get('settings');

  @override
  Future<void> saveSettings(AppSettings settings) async =>
      _box.put('settings', settings);
}
