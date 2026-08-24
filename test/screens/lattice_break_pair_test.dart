// D-06 (28-CONTEXT.md): the lattice fix introduces a cardinality nothing in
// this codebase has ever produced — a cadence-boundary work chunk keeps its
// own 5-minute short break AND is immediately followed by a separate
// 30-minute long break, rather than the long break replacing the short one.
// `28-PATTERNS.md`'s exhaustive grep of `reservedBreakMinutes` found no
// production consumer outside `schedule_generator.dart` itself, so the real
// risk is not a field reader — it is downstream code (the row model, the
// pixel geometry, the break card) that has only ever seen a single non-work
// chunk between two work chunks and may silently assume that shape.
//
// Every test below generates its fixture day from the REAL
// `ScheduleGeneratorService` — never a hand-built `ScheduledChunk` list. A
// mock day can be made to say anything; only the real engine's output proves
// the engine actually emits the pair the fix is supposed to produce. This
// file is proven RED against the unfixed engine (plan 28-02); plan 28-03
// lands the engine fix and turns it green.

import 'package:canopy/data/models/commitment_block.dart';
import 'package:canopy/data/models/goal.dart';
import 'package:canopy/data/models/scheduled_chunk.dart';
import 'package:canopy/providers/schedule_notifier.dart';
import 'package:canopy/screens/schedule/widgets/chunk_card.dart';
import 'package:canopy/screens/today/now_state.dart';
import 'package:canopy/screens/today/timeline.dart';
import 'package:canopy/screens/today/timeline_geometry.dart';
import 'package:canopy/screens/today/widgets/timeline_row_tile.dart';
import 'package:canopy/services/schedule_generator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_helpers/mood_pump.dart';

// ─── Fakes (per-file convention — see today_row_widgets_test.dart) ─────────

/// Stubs `init()` to avoid Hive I/O — this file never touches persistence,
/// it only needs a `ScheduleNotifier` instance to satisfy `ChunkCard`'s
/// `context.read<ScheduleNotifier>()` call inside its action row.
class _FakeScheduleNotifier extends ScheduleNotifier {
  @override
  Future<void> init() async {}
}

// ─── Fixture ────────────────────────────────────────────────────────────

/// Generates a day from the REAL `ScheduleGeneratorService`, reusing the
/// `BREAK-01: mood=1` fixture shape verbatim
/// (`test/services/schedule_generator_test.dart` lines 1859-1876,
/// `28-PATTERNS.md` § "Representative full test #2"):
///
/// lighterDay: false -> cap=4, habitCeiling=ceil(4/2)=2 (CAP-01). 2 habits
/// fill the habitCeiling exactly (2 chunks). mood=1 is low-mood, so FILL-01
/// clamps each time-target to 1 chunk: 2 time-targets -> 2 chunks. Total
/// discretionary = 2 + 2 = 4 work chunks (== cap). N=2 is mood 1's cadence
/// (`_moodBreakCadence`), so chunks 2 and 4 are BOTH cadence boundaries —
/// this single fixture exercises the D-06 pair twice in one day.
///
/// Under the FIXED engine (28-CONTEXT.md `<lattice_arithmetic>`) the day is:
///   W@480(25) SB@505(5) W@510(25) SB@535(5) LB@540(30)
///   W@570(25) SB@595(5) W@600(25) SB@625(5) LB@630(30)
/// — 10 chunks, containing two short->long break pairs (indices 3,4 and
/// 8,9). Under the UNFIXED engine the same fixture yields 7 chunks with a
/// single 25-minute long break that REPLACES the short break at the first
/// boundary, so no adjacent break pair exists anywhere — this is exactly
/// what makes every test below fail today.
List<ScheduledChunk> _latticeDay() {
  final sut = ScheduleGeneratorService();
  final goals = [
    ...List.generate(
      2,
      (i) => Goal(name: 'Habit $i', goalTypeIndex: GoalType.habit.index),
    ),
    ...List.generate(
      2,
      (i) => Goal(
        name: 'Regular $i',
        goalTypeIndex: GoalType.timeTarget.index,
        weeklyHourBudget: 5,
      ),
    ),
  ];
  return sut.generate(
    goals: goals,
    blocks: [],
    moodIndex: 1,
    date: DateTime(2026, 3, 23), // Monday — every generator test's fixture day
    completionLogs: [],
    lighterDay: false,
  );
}

/// Generates a day from the REAL `ScheduleGeneratorService` around a single
/// commitment block, no discretionary goals — Phase 30's own reproduction
/// window (COMMITBREAK-01/RENDER, D-30-04). 540-700 is a 160-minute window;
/// at mood 3 (N=4) this reaches a cadence boundary partway through, so the
/// generated day contains BOTH a shortBreak and a longBreak, each carrying
/// the block's own `commitmentId` (D-30-04) — the exact shape this test
/// needs to settle whether that changes how a break renders.
List<ScheduledChunk> _commitmentDay() {
  final sut = ScheduleGeneratorService();
  return sut.generate(
    goals: const [],
    blocks: [
      CommitmentBlock(
        name: 'Work',
        daysOfWeek: const [1],
        startMinutes: 540,
        endMinutes: 700,
      ),
    ],
    moodIndex: 3,
    date: DateTime(2026, 3, 23), // Monday — every generator test's fixture day
    completionLogs: [],
  );
}

/// Returns the index `i` where `chunks[i]` is a `shortBreak` immediately
/// followed by `chunks[i + 1]` being a `longBreak` — the D-06 cadence-
/// boundary pair — or `-1` if no such adjacency exists. Callers must assert
/// this is non-negative with an explicit `reason` BEFORE indexing, so a RED
/// run reads as a clean assertion failure (the pair doesn't exist yet), not
/// a `StateError` from `firstWhere`/`[]` on a bad index.
int _firstBreakPairIndex(List<ScheduledChunk> chunks) {
  for (var i = 0; i + 1 < chunks.length; i++) {
    if (chunks[i].chunkType == ChunkType.shortBreak &&
        chunks[i + 1].chunkType == ChunkType.longBreak) {
      return i;
    }
  }
  return -1;
}

void main() {
  group('D-06: a cadence boundary emits two consecutive break chunks', () {
    test(
      'D-06: the engine emits a 5-minute break immediately followed by a '
      '30-minute break',
      () {
        final day = _latticeDay();
        final pairIndex = _firstBreakPairIndex(day);
        expect(
          pairIndex,
          greaterThanOrEqualTo(0),
          reason:
              'no shortBreak->longBreak adjacency found in the generated '
              'day — the unfixed engine replaces the short break with the '
              'long one instead of following it (28-CONTEXT.md D-06)',
        );

        final shortBreak = day[pairIndex];
        final longBreak = day[pairIndex + 1];

        expect(shortBreak.durationMinutes, 5);
        expect(longBreak.durationMinutes, 30);
        expect(
          longBreak.displayStartMinutes,
          shortBreak.displayStartMinutes! + 5,
          reason:
              'the long break must start exactly where the short break '
              'ends — the two are adjacent cells, not one stretched cell',
        );
      },
    );

    test(
      'D-06: buildTimeline renders the pair as two adjacent ChunkRows with '
      'no gap row between',
      () {
        final day = _latticeDay();
        final pairIndex = _firstBreakPairIndex(day);
        expect(
          pairIndex,
          greaterThanOrEqualTo(0),
          reason:
              'no shortBreak->longBreak adjacency found in the generated '
              'day — cannot exercise buildTimeline against a pair that '
              'does not exist',
        );

        final shortBreak = day[pairIndex];
        final longBreak = day[pairIndex + 1];

        final rows = buildTimeline(chunks: day, nowState: DayComplete());

        // Every chunk gets exactly one row — none swallowed, none
        // duplicated.
        expect(rows.whereType<ChunkRow>().length, day.length);

        final shortRowIndex = rows.indexWhere(
          (r) => r is ChunkRow && r.chunk.id == shortBreak.id,
        );
        final longRowIndex = rows.indexWhere(
          (r) => r is ChunkRow && r.chunk.id == longBreak.id,
        );
        expect(shortRowIndex, isNot(-1));
        expect(longRowIndex, isNot(-1));
        expect(
          longRowIndex,
          shortRowIndex + 1,
          reason:
              'the long-break row must sit immediately after the '
              'short-break row — no GapFreeRow (or anything else) between '
              'them, since the pair has a zero-minute gap',
        );
      },
    );

    test(
      'D-06: TimelineGeometry positions the pair abutting exactly — no '
      'overlap, no dead space',
      () {
        final day = _latticeDay();
        final pairIndex = _firstBreakPairIndex(day);
        expect(
          pairIndex,
          greaterThanOrEqualTo(0),
          reason:
              'no shortBreak->longBreak adjacency found in the generated '
              'day — cannot exercise TimelineGeometry against a pair that '
              'does not exist',
        );

        final shortBreak = day[pairIndex];
        final longBreak = day[pairIndex + 1];

        final firstStart = day.first.displayStartMinutes!;
        final lastChunk = day.last;
        final lastEnd =
            lastChunk.displayStartMinutes! + lastChunk.durationMinutes;

        final geometry = TimelineGeometry.forDay(
          nowMinutes: firstStart,
          firstStartMinutes: firstStart,
          lastEndMinutes: lastEnd,
        );

        final shortStart = shortBreak.displayStartMinutes!;
        final longStart = longBreak.displayStartMinutes!;

        // Arithmetic assertions on a linear mapping — trustworthy in the
        // test harness, unlike any text-driven measurement (STATE.md
        // test-harness caveat).
        expect(
          geometry.yFor(longStart),
          geometry.yFor(shortStart) + geometry.heightFor(shortStart, 5),
          reason:
              'the long break must start exactly where the short break '
              'row ends — no overlap, no dead space between them',
        );
        expect(
          geometry.heightFor(longStart, 30),
          greaterThan(geometry.heightFor(shortStart, 5)),
          reason: 'a 30-minute break row must render taller than a '
              '5-minute one',
        );
      },
    );
  });

  group('D-06: the pair renders', () {
    testWidgets(
      'D-06: a 5-minute break card and a 30-minute break card render '
      'adjacently without throwing',
      (tester) async {
        final day = _latticeDay();
        final pairIndex = _firstBreakPairIndex(day);
        expect(
          pairIndex,
          greaterThanOrEqualTo(0),
          reason:
              'no shortBreak->longBreak adjacency found in the generated '
              'day — cannot render a pair that does not exist. This is a '
              '30-minute longBreak size no downstream widget has ever been '
              'handed.',
        );

        final shortBreak = day[pairIndex];
        final longBreak = day[pairIndex + 1];

        final firstStart = day.first.displayStartMinutes!;
        final lastChunk = day.last;
        final lastEnd =
            lastChunk.displayStartMinutes! + lastChunk.durationMinutes;
        final geometry = TimelineGeometry.forDay(
          nowMinutes: firstStart,
          firstStartMinutes: firstStart,
          lastEndMinutes: lastEnd,
        );

        await pumpWithMood(
          tester,
          Column(
            children: [
              SizedBox(
                height: geometry.heightFor(
                  shortBreak.displayStartMinutes!,
                  shortBreak.durationMinutes,
                ),
                child: TimelineRowTile(child: ChunkCard(chunk: shortBreak)),
              ),
              SizedBox(
                height: geometry.heightFor(
                  longBreak.displayStartMinutes!,
                  longBreak.durationMinutes,
                ),
                child: TimelineRowTile(child: ChunkCard(chunk: longBreak)),
              ),
            ],
          ),
          extraProviders: [
            ChangeNotifierProvider<ScheduleNotifier>.value(
              value: _FakeScheduleNotifier(),
            ),
          ],
        );
        await tester.pump();

        // "Renders fine" is unverifiable unless checked: no thrown
        // exception (a RenderFlex overflow surfaces through
        // takeException()), and exactly two ChunkCards present. No
        // assertion on text width, glyph metric, or label layout — the
        // harness's placeholder font inflates those (STATE.md carry-forward
        // invariant).
        expect(tester.takeException(), isNull);
        expect(find.byType(ChunkCard), findsNWidgets(2));
      },
    );
  });

  group('COMMITBREAK-01/RENDER — a commitment break renders as a break', () {
    testWidgets(
      'COMMITBREAK-01/RENDER: a break carrying commitmentId renders as a '
      'break, not a commitment-tinted work card (D-30-04)',
      (tester) async {
        final day = _commitmentDay();

        final shortBreaks = day
            .where((c) => c.chunkType == ChunkType.shortBreak)
            .toList();
        final longBreaks = day
            .where((c) => c.chunkType == ChunkType.longBreak)
            .toList();

        expect(
          shortBreaks,
          isNotEmpty,
          reason:
              'the generated day contains no short break yet — the '
              'unfixed engine never applies the lattice inside a '
              'commitment window (COMMITBREAK-01)',
        );
        expect(
          longBreaks.length,
          1,
          reason:
              'the generated day does not contain exactly one long break '
              'yet — cannot exercise the render guard against a pair that '
              "doesn't exist (COMMITBREAK-01/RENDER)",
        );
        expect(
          shortBreaks.every((c) => c.commitmentId != null),
          isTrue,
          reason:
              'D-30-04: every commitment-emitted break must carry the '
              "block's commitmentId",
        );
        expect(
          longBreaks.every((c) => c.commitmentId != null),
          isTrue,
          reason:
              'D-30-04: every commitment-emitted break must carry the '
              "block's commitmentId",
        );

        final shortBreak = shortBreaks.first;
        final longBreak = longBreaks.first;

        final firstStart = day.first.displayStartMinutes!;
        final lastChunk = day.last;
        final lastEnd =
            lastChunk.displayStartMinutes! + lastChunk.durationMinutes;
        final geometry = TimelineGeometry.forDay(
          nowMinutes: firstStart,
          firstStartMinutes: firstStart,
          lastEndMinutes: lastEnd,
        );

        await pumpWithMood(
          tester,
          Column(
            children: [
              SizedBox(
                height: geometry.heightFor(
                  shortBreak.displayStartMinutes!,
                  shortBreak.durationMinutes,
                ),
                child: TimelineRowTile(child: ChunkCard(chunk: shortBreak)),
              ),
              SizedBox(
                height: geometry.heightFor(
                  longBreak.displayStartMinutes!,
                  longBreak.durationMinutes,
                ),
                child: TimelineRowTile(child: ChunkCard(chunk: longBreak)),
              ),
            ],
          ),
          extraProviders: [
            ChangeNotifierProvider<ScheduleNotifier>.value(
              value: _FakeScheduleNotifier(),
            ),
          ],
        );
        await tester.pump();

        // If ChunkCard.build() ever routed a commitmentId-carrying break
        // into _WorkChunkContent (30-RESEARCH.md Pitfall 6's premise),
        // this card would show the chunk's rationale (empty for a break),
        // not a break title — 'Long break' would not be found. This is a
        // tree assertion (title presence), not a metric one, so it is safe
        // under the harness's placeholder font (STATE.md carry-forward
        // invariant).
        expect(find.text('Long break'), findsOneWidget);
        expect(find.byType(ChunkCard), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      },
    );
  });
}
