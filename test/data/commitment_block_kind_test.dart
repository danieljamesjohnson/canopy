// Phase 37: CommitmentBlock gains `kind` (HiveField 9, nullable). A pre-37
// record on disk has 9 fields (0-8) and no field 9 at all; it must still load,
// as an ordinary (non-meal) commitment. Mutation log: 37-01-SUMMARY.md.

import 'dart:io';

import 'package:canopy/data/models/commitment_block.dart';
import 'package:canopy/utils/meals.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

/// Writes a CommitmentBlock in the PRE-37 (9-field) shape — field 9 is
/// physically absent, exactly as on an existing user's phone.
class _OldCommitmentBlockAdapter extends TypeAdapter<CommitmentBlock> {
  @override
  final typeId = 1;

  @override
  CommitmentBlock read(BinaryReader reader) =>
      throw UnimplementedError('write-only — only used to produce old bytes');

  @override
  void write(BinaryWriter writer, CommitmentBlock obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.daysOfWeek)
      ..writeByte(3)
      ..write(obj.startMinutes)
      ..writeByte(4)
      ..write(obj.endMinutes)
      ..writeByte(5)
      ..write(obj.color)
      ..writeByte(6)
      ..write(obj.date)
      ..writeByte(7)
      ..write(obj.externalEventId)
      ..writeByte(8)
      ..write(obj.isFromCalendar);
  }
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('hive_kind_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  test('a pre-37 (9-field) commitment loads with kind == null and is not a '
      'meal', () async {
    Hive.registerAdapter(_OldCommitmentBlockAdapter());
    final old = await Hive.openBox<CommitmentBlock>('cb_old');
    await old.put(
      'w',
      CommitmentBlock(
        id: 'w',
        name: 'Work',
        daysOfWeek: const [1, 2, 3, 4, 5],
        startMinutes: 540,
        endMinutes: 1020,
      ),
    );
    await old.close();

    Hive.registerAdapter(CommitmentBlockAdapter(), override: true);
    final box = await Hive.openBox<CommitmentBlock>('cb_old');
    final back = box.get('w')!;
    expect(back.kind, isNull);
    expect(back.isMeal, isFalse);
    expect(back.name, 'Work');
    expect(back.endMinutes, 1020);
  });

  test('a meal round-trips with its kind', () async {
    Hive.registerAdapter(CommitmentBlockAdapter(), override: true);
    final box = await Hive.openBox<CommitmentBlock>('cb_new');
    await box.put(
      'l',
      CommitmentBlock(
        id: 'l',
        name: 'Lunch',
        daysOfWeek: kAllWeekdays,
        startMinutes: 720,
        endMinutes: 780,
        kind: CommitmentBlock.kindLunch,
      ),
    );
    await box.close();
    final reopened = await Hive.openBox<CommitmentBlock>('cb_new');
    final back = reopened.get('l')!;
    expect(back.kind, CommitmentBlock.kindLunch);
    expect(back.isMeal, isTrue);
    expect(MealSlot.fromKind(back.kind), MealSlot.lunch);
  });
}
