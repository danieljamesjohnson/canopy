import '../data/models/scheduled_chunk.dart';

/// The *reference* title for a chunk: what the Today screen calls it
/// everywhere except the live row, and what the watch shows.
///
/// A break returns its fixed literal ('Short break' / 'Long break'). Every
/// other chunk falls through goal name → rationale → 'Work block'. A
/// commitment chunk has no goal, and its rationale is the commitment's name
/// (`schedule_generator.dart` writes `rationale: block.name`), so it reads as
/// the meeting's title.
///
/// Extracted from `today_screen.dart`'s `_chunkTitle` in Phase 38 so the phone
/// and the wrist share one definition and can never name a chunk differently.
String chunkReferenceTitle(ScheduledChunk chunk, String? goalName) {
  if (chunk.chunkType == ChunkType.shortBreak) return 'Short break';
  if (chunk.chunkType == ChunkType.longBreak) return 'Long break';
  if (goalName != null && goalName.isNotEmpty) return goalName;
  return chunk.rationale.isNotEmpty ? chunk.rationale : 'Work block';
}
