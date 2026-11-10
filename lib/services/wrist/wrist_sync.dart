import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../providers/goals_notifier.dart';
import '../../providers/schedule_notifier.dart';
import 'wrist_timeline.dart';

/// Carries a timeline to the watch. On iOS this is the Swift `WatchBridge`
/// (`ios/Runner/WatchBridge.swift`) behind the `canopy/watch` channel.
abstract class WristTransport {
  Future<void> sendTimeline(String json);
}

/// The production transport. Every failure is swallowed: a phone with no
/// watch, or a build without the bridge (web, Android, desktop, tests), must
/// never be disturbed by the wrist feature.
class MethodChannelWristTransport implements WristTransport {
  const MethodChannelWristTransport();

  static const channel = MethodChannel('canopy/watch');

  @override
  Future<void> sendTimeline(String json) async {
    try {
      await channel.invokeMethod<void>('sendTimeline', json);
    } on MissingPluginException {
      // No bridge on this platform.
    } on PlatformException catch (e) {
      debugPrint('wrist: sendTimeline failed: ${e.code} ${e.message}');
    }
  }
}

/// True only where the watch bridge exists: a real iOS build. The
/// `PREVIEW_AS_IOS` Android preview overrides `defaultTargetPlatform`, so the
/// transport's own MissingPluginException guard backs this up.
bool get wristSyncSupported =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// Keeps the watch's copy of today in step with the phone.
///
/// It listens to [schedule] (check-in, re-check-in, complete, skip, defer,
/// calendar sync, meals and the day reset all end in its `notifyListeners`)
/// and to [goals] (a renamed goal changes a title). After a short debounce it
/// rebuilds the timeline and sends it, unless the content is identical to
/// the last one sent: `generatedAt` alone never causes a send, so a burst of
/// unrelated notifications costs the watch nothing.
class WristSync {
  WristSync({
    required this.schedule,
    required this.goals,
    required this.transport,
    required DateTime Function() now,
    this.debounce = const Duration(milliseconds: 400),
  }) : _now = now;

  final ScheduleNotifier schedule;
  final GoalsNotifier goals;
  final WristTransport transport;
  final Duration debounce;
  final DateTime Function() _now;

  Timer? _timer;
  String? _lastContent;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    schedule.addListener(_changed);
    goals.addListener(_changed);
    _changed();
  }

  void dispose() {
    _timer?.cancel();
    if (_started) {
      schedule.removeListener(_changed);
      goals.removeListener(_changed);
    }
  }

  void _changed() {
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(pushNow()));
  }

  /// Builds and sends immediately (skipping the debounce). Returns whether
  /// anything was sent.
  Future<bool> pushNow() async {
    final timeline = buildWristTimeline(
      schedule: schedule.hasScheduleToday ? schedule.todaySchedule : null,
      goalName: (id) => goals.goals.where((g) => g.id == id).firstOrNull?.name,
      now: _now(),
    );
    final json = timeline.toJson();
    final content = jsonEncode({...json, 'generatedAt': null});
    if (content == _lastContent) return false;
    _lastContent = content;
    await transport.sendTimeline(jsonEncode(json));
    return true;
  }
}
