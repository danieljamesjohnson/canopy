import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

part 'restorative_item.g.dart';

const _uuid = Uuid();

// ORDER IS FIXED — fields stored by HiveField index; never reorder.
// @HiveField 0: id (String)
// @HiveField 1: name (String)
// @HiveField 2: emojiTag (String?)
// @HiveField 3: sortOrder (int)

/// A restorative activity that helps the user recharge — deliberately NOT a
/// goal. Restoratives never enter the scheduling engine, never count toward
/// goal budgets, streaks, or the weekly plan, and never appear in the Goals
/// list. They exist only to be surfaced as gentle, no-pressure suggestions on
/// low-energy days (mood 1–2), when a reminder of "what restores you" helps
/// most. This is the counterpart to flagging a *goal* as energy-giving
/// (`EnergyValence.gives`): a goal that also restores stays a goal; a pure
/// restorative (e.g. "listen to music") lives here instead.
@HiveType(typeId: 7)
class RestorativeItem extends HiveObject {
  RestorativeItem({
    String? id,
    required this.name,
    this.emojiTag,
    this.sortOrder = 0,
  }) : id = id ?? _uuid.v4();

  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  /// Optional single-emoji tag shown beside the name. null = no emoji.
  @HiveField(2)
  String? emojiTag;

  /// Position within the restoratives list for display ordering.
  @HiveField(3)
  int sortOrder;
}
