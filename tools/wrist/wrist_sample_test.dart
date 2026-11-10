// Dev tool, not part of the suite (lives outside test/): writes a REAL
// buildWristTimeline JSON centred on the current time, for the watch
// Simulator's DEBUG gallery (ios/CanopyWatch/DebugGallery.swift).
//
//   CANOPY_SAMPLE_OUT=/tmp/cw-sample.json flutter test tools/wrist/wrist_sample_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:canopy/data/models/daily_schedule.dart';
import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/services/wrist/wrist_timeline.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  test('write a sample wrist timeline', () {
    final now = DateTime.now();
    final s = now.hour * 60 + now.minute - 7; // "Deep work" began 7 min ago
    ScheduledChunk c(
      String id,
      ChunkType t,
      int start,
      int dur, {
      String? goal,
      String r = '',
      String? com,
    }) => ScheduledChunk(
      id: id,
      chunkTypeIndex: t.index,
      goalId: goal,
      durationMinutes: dur,
      syntheticStartMinutes: com == null ? start : null,
      anchoredStartMinutes: com == null ? null : start,
      rationale: r,
      commitmentId: com,
    );
    final chunks = [
      c('w0', ChunkType.work, s - 60, 50, goal: 'g2')..isCompleted = true,
      c('b0', ChunkType.shortBreak, s - 10, 10),
      c('w1', ChunkType.work, s, 25, goal: 'g1'),
      c('b1', ChunkType.shortBreak, s + 25, 5),
      c('m1', ChunkType.work, s + 30, 30, r: 'Design review', com: 'c1'),
      c('l1', ChunkType.meal, s + 70, 30, r: 'Lunch', com: 'c2'),
      c('w2', ChunkType.work, s + 100, 25, goal: 'g2'),
    ];
    final t = buildWristTimeline(
      schedule: DailySchedule(
        id: 's',
        dateYmd: DateFormat('yyyy-MM-dd').format(now),
        moodIndex: 3,
        chunks: chunks,
      ),
      goalName: (id) => {'g1': 'Deep work', 'g2': 'Spanish practice'}[id],
      now: now,
    );
    File(
      Platform.environment['CANOPY_SAMPLE_OUT'] ?? '/tmp/cw-sample.json',
    ).writeAsStringSync(jsonEncode(t.toJson()));
  });
}
