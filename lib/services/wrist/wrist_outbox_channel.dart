import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'wrist_outbox.dart';

/// The native outbox (Phase 40). Swift's `WatchBridge` writes each wrist tap
/// to its own file the moment WatchConnectivity delivers it, even if Dart is
/// not running. This reads and deletes those files over `canopy/watch`.
class MethodChannelWristOutboxStore implements WristOutboxStore {
  MethodChannelWristOutboxStore([
    this.channel = const MethodChannel('canopy/watch'),
  ]);

  final MethodChannel channel;

  @override
  Future<List<WristAction>> pending() async {
    try {
      final raw = await channel.invokeListMethod<Object?>('outboxPending');
      final out = <WristAction>[];
      for (final item in raw ?? const []) {
        Object? decoded;
        try {
          decoded = item is String ? jsonDecode(item) : item;
        } on FormatException {
          decoded = null;
        }
        final action = WristAction.tryParse(decoded);
        if (action != null) out.add(action);
      }
      return out;
    } on MissingPluginException {
      return const [];
    } on PlatformException catch (e) {
      debugPrint('wrist: outboxPending failed: ${e.code} ${e.message}');
      return const [];
    }
  }

  @override
  Future<void> remove(String id) async {
    try {
      await channel.invokeMethod<void>('outboxRemove', id);
    } on MissingPluginException {
      // Nothing to remove from.
    } on PlatformException catch (e) {
      debugPrint('wrist: outboxRemove failed: ${e.code} ${e.message}');
    }
  }
}

/// Decides WHEN to replay the outbox: once at start, every time the app
/// resumes, and whenever Swift says a new tap arrived while the engine is
/// alive (`outboxChanged` on the channel). The replay itself is
/// [WristOutboxReplayer], on the main isolate.
class WristOutboxCoordinator with WidgetsBindingObserver {
  WristOutboxCoordinator({
    required this.replayer,
    this.channel = const MethodChannel('canopy/watch'),
  });

  final WristOutboxReplayer replayer;
  final MethodChannel channel;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    channel.setMethodCallHandler((call) async {
      if (call.method == 'outboxChanged') await replayer.drain();
      return null;
    });
    unawaited(replayer.drain());
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    channel.setMethodCallHandler(null);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(replayer.drain());
  }
}
