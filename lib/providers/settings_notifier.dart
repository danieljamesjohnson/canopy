import 'package:flutter/foundation.dart';

class SettingsNotifier extends ChangeNotifier {
  // Phase 1 stub. Holds onboarding completion flag for router redirect.
  // Will be wired to shared_preferences in plan 01-04.
  bool _onboardingComplete = false;
  bool get onboardingComplete => _onboardingComplete;

  void setOnboardingComplete(bool value) {
    _onboardingComplete = value;
    notifyListeners(); // triggers go_router redirect re-evaluation
  }
}
