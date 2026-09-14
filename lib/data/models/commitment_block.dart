import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

part 'commitment_block.g.dart';

const _uuid = Uuid();

@HiveType(typeId: 1)
class CommitmentBlock extends HiveObject {
  CommitmentBlock({
    String? id,
    required this.name,
    required this.daysOfWeek,
    required this.startMinutes,
    required this.endMinutes,
    this.date,
    this.externalEventId,
    this.isFromCalendar = false,
  }) : id = id ?? _uuid.v4();

  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  /// List of weekday integers: 1=Monday ... 7=Sunday (ISO 8601)
  @HiveField(2)
  List<int> daysOfWeek;

  /// Start time as minutes from midnight, LOCAL wall-clock (e.g. 540 =
  /// 9:00am local time). No `.toUtc()` call exists anywhere this field is
  /// written — the only writer (`commitment_form_sheet.dart`'s
  /// `showTimePicker`) returns device-local time, and
  /// `schedule_generator.generateToday` builds its date at local midnight
  /// and matches [daysOfWeek] against a local weekday. Phase 35: a
  /// calendar-imported occurrence must convert to local wall-clock the same
  /// way before landing here — see `CalendarSyncService` (D-35-08).
  @HiveField(3)
  int startMinutes;

  /// End time as minutes from midnight, LOCAL wall-clock (e.g. 1020 =
  /// 5:00pm local time). See [startMinutes] — same local-not-UTC basis.
  @HiveField(4)
  int endMinutes;

  @HiveField(5)
  String color = '#FF5722'; // default deep orange

  /// Optional specific calendar date for a ONE-OFF commitment (e.g. a dentist
  /// appointment this Thursday). When non-null the block is anchored only on
  /// that single day and [daysOfWeek] is ignored; when null the block is a
  /// recurring weekly commitment driven by [daysOfWeek]. Additive field — old
  /// records deserialize with date == null and stay recurring.
  @HiveField(6)
  DateTime? date;

  /// Stable identity of the calendar occurrence this block was imported
  /// from (`'ics:<urlHash>:<uid>:<recurrenceId>'`, or an equivalent key for
  /// a device-calendar source), or null for a hand-entered commitment.
  /// Phase 35: `CalendarSyncService` upserts on this field so a repeat sync
  /// of an unchanged feed updates the existing block in place rather than
  /// creating a duplicate. Additive field — old records deserialize with
  /// externalEventId == null and are treated as hand-entered.
  @HiveField(7)
  String? externalEventId;

  /// True when this block was imported from a calendar rather than entered
  /// by hand. Phase 35: drives read-only treatment in the commitments UI
  /// (D-35-14) and the "from calendar" indicator on the timeline (D-35-11).
  /// Additive field — old records deserialize with isFromCalendar == false.
  @HiveField(8)
  bool isFromCalendar;

  /// True when this is a single-date commitment rather than a recurring one.
  bool get isOneOff => date != null;
}
