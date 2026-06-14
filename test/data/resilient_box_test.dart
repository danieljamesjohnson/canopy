// Regression tests for the stale-Hive-data startup crash
// (.planning/debug/stale-hive-data-startup-crash.md).
//
// A browser/profile holding Canopy data from an older app version can contain a
// record the current adapters cannot deserialize. Opening that box eagerly
// deserializes the bad frame and threw an uncaught error → blank screen.
// openBoxResilient must instead discard the incompatible data and reopen empty.

import 'dart:io';

import 'package:canopy/data/database/resilient_box.dart';
import 'package:canopy/data/models/goal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
// A fresh HiveImpl gives the integration test an isolated adapter registry, so
// it can write a Goal record and then reopen the box as a "build" that has no
// GoalAdapter — reproducing the unknown-typeId deserialization failure.
import 'package:hive_ce/src/hive_impl.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Unit: recovery control flow (no real Hive I/O — fully deterministic)
  // ---------------------------------------------------------------------------

  group('openBoxResilient control flow', () {
    test('returns the box directly when the first open succeeds', () async {
      var opens = 0;
      var deletes = 0;
      final sentinel = await openBoxResilient<int>(
        'ok',
        (_) async {
          opens++;
          return _FakeBox<int>();
        },
        (_) async => deletes++,
      );

      expect(sentinel, isA<Box<int>>());
      expect(opens, 1, reason: 'no retry when the first open works');
      expect(deletes, 0, reason: 'healthy data must never be deleted');
    });

    test('resets the box and reopens when the first open throws', () async {
      var opens = 0;
      final deleted = <String>[];
      final box = await openBoxResilient<int>(
        'corrupt',
        (_) async {
          opens++;
          if (opens == 1) throw HiveError('cannot read, unknown typeId: 0');
          return _FakeBox<int>();
        },
        (name) async => deleted.add(name),
      );

      expect(box, isA<Box<int>>());
      expect(opens, 2, reason: 'open is retried after the reset');
      expect(
        deleted,
        ['corrupt'],
        reason: 'the incompatible box is deleted from disk before reopening',
      );
    });

    test('rethrows if the box still cannot open after a reset', () async {
      expect(
        () => openBoxResilient<int>(
          'unrecoverable',
          (_) async => throw HiveError('still broken'),
          (_) async {},
        ),
        throwsA(isA<HiveError>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Integration: real Hive recovery from an undeserializable old-schema record
  // ---------------------------------------------------------------------------

  group('openBoxResilient with real Hive', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('resilient_box_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('recovers when a box holds a record the app can no longer read',
        () async {
      const boxName = 'goals';

      // 1. An "old app version" persists a Goal (typeId 0) to disk.
      final oldApp = HiveImpl();
      oldApp.init(tempDir.path);
      oldApp.registerAdapter(GoalAdapter());
      final oldBox = await oldApp.openBox<Goal>(boxName);
      await oldBox.put('g1', Goal(name: 'legacy goal', goalTypeIndex: 0));
      await oldApp.close();

      // 2. A "new build" with no GoalAdapter registered cannot deserialize the
      //    persisted frame — this is the crash the bug report captured. Verify
      //    a plain open really throws, then close so its file locks release.
      final crashingApp = HiveImpl();
      crashingApp.init(tempDir.path);
      await expectLater(
        crashingApp.openBox(boxName),
        throwsA(isA<HiveError>()),
        reason: 'sanity: the stale record really does break a plain open',
      );
      await crashingApp.close();

      // 3. The resilient open discards the unreadable data and boots clean.
      final recoveryApp = HiveImpl();
      recoveryApp.init(tempDir.path);
      final recovered = await openBoxResilient(
        boxName,
        (n) => recoveryApp.openBox(n),
        (n) => recoveryApp.deleteBoxFromDisk(n),
      );
      expect(recovered.isEmpty, isTrue,
          reason: 'incompatible data is reset, app continues to a clean state');
      await recoveryApp.close();
    });
  });
}

/// Minimal [Box] stand-in for the control-flow tests. Only the identity of the
/// returned object matters there, so every member throws if exercised.
class _FakeBox<E> implements Box<E> {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
