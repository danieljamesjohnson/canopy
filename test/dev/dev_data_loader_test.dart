import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:canopy/dev/dev_data_loader.dart';

void main() {
  group('DevDataLoader.parseJson', () {
    test('happy path — known JSON yields expected entity counts', () {
      const json = '''
{
  "goals": [
    {"id": "g1", "name": "Health", "goalTypeIndex": 2, "color": "#4CAF50", "priorityWeight": 0.8, "sortOrder": 0, "frequencyPerWeek": 5},
    {"id": "g2", "name": "Spanish", "goalTypeIndex": 0, "color": "#2196F3", "priorityWeight": 0.7, "sortOrder": 1, "weeklyHourBudget": 4.0},
    {"id": "g3", "name": "Side project", "goalTypeIndex": 1, "color": "#FF9800", "priorityWeight": 0.9, "sortOrder": 2, "outcomeDescription": "Launch", "deadline": "2026-06-30T00:00:00.000Z"}
  ],
  "completion_logs": [
    {"id": "c1", "chunkId": "dev-health-w0-0", "goalId": "g1", "dateYmd": "2026-01-05", "eventIndex": 0},
    {"id": "c2", "chunkId": "dev-health-w0-1", "goalId": "g1", "dateYmd": "2026-01-06", "eventIndex": 0},
    {"id": "c3", "chunkId": "dev-spanish-w0-0", "goalId": "g2", "dateYmd": "2026-01-07", "eventIndex": 1},
    {"id": "c4", "chunkId": "dev-spanish-w1-0", "goalId": "g2", "dateYmd": "2026-01-12", "eventIndex": 0},
    {"id": "c5", "chunkId": "dev-side-w0-0", "goalId": "g3", "dateYmd": "2026-01-08", "eventIndex": 2}
  ],
  "quarterly_snapshots": []
}
''';
      final result = DevDataLoader.parseJson(json);
      expect(result.success, isTrue, reason: 'happy-path JSON must parse');
      expect(result.data, isNotNull);
      expect(result.data!.goals.length, 3);
      expect(result.data!.completionLogs.length, 5);
      expect(result.data!.snapshots.length, 0);
      expect(result.data!.goals.first.name, 'Health');
      expect(result.data!.goals.first.goalTypeIndex, 2);
      expect(result.data!.completionLogs.first.goalId, 'g1');
      expect(result.data!.completionLogs.first.eventIndex, 0);
    });

    test('sad path — malformed JSON returns failure without throwing', () {
      const bad = '{not valid json';
      late final DevIngestParseResult result;
      expect(() => result = DevDataLoader.parseJson(bad), returnsNormally);
      expect(result.success, isFalse);
      expect(result.error, isNotNull);
      expect(result.data, isNull);
    });

    test('sad path — wrong shape (goals as string) returns failure', () {
      const wrongShape =
          '{"goals": "not a list", "completion_logs": [], "quarterly_snapshots": []}';
      final result = DevDataLoader.parseJson(wrongShape);
      expect(result.success, isFalse);
      expect(result.error, isNotNull);
    });

    test('bundled scenario file — counts match documented range', () {
      // Tests run from project root; the asset is also a regular file we can read directly.
      final file = File('dev_data/typical_quarter.json');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'dev_data/typical_quarter.json must exist at project root',
      );
      final result = DevDataLoader.parseJson(file.readAsStringSync());
      expect(
        result.success,
        isTrue,
        reason: 'bundled scenario must parse cleanly',
      );
      expect(result.data!.goals.length, 3);
      expect(result.data!.completionLogs.length, inInclusiveRange(100, 120));
      expect(result.data!.snapshots.length, 0);
    });
  });
}
