import '../models/app_settings.dart';
import 'app_settings_repository.dart';

/// In-memory implementation of [AppSettingsRepository] for tests.
///
/// Mirrors the `HiveAppSettingsRepository` contract without disk I/O so
/// that unit tests can exercise `ThemeNotifier`, `SettingsNotifier`, and
/// any other consumer of `AppSettingsRepository` without bootstrapping
/// Hive boxes. Published under `lib/` (rather than `test/`) so multiple
/// test files can share the same fake without test-to-test imports.
///
/// Plan 06 Task 1 — sibling of `InMemoryGoalRepository` from
/// `test/repositories/goal_repository_test.dart`.
class InMemoryAppSettingsRepository implements AppSettingsRepository {
  AppSettings? _stored;

  @override
  Future<AppSettings?> getSettings() async => _stored;

  @override
  Future<void> saveSettings(AppSettings settings) async => _stored = settings;
}
