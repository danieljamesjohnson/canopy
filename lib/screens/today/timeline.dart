import '../../data/models/scheduled_chunk.dart';
import 'now_state.dart';

/// Minimum gap, in minutes, between two chunks that surfaces as its own
/// named free-time row. Gaps shorter than this are suppressed as noise
/// (D-05, 22-UI-SPEC.md "Free time (LOCKED)").
const int kMinGapMinutes = 10;

/// A single row in the unified Today timeline.
///
/// Exactly three subtypes, so the render layer can use an exhaustive switch
/// with no default branch.
sealed class TimelineRow {}

/// A single scheduled chunk (work, break, or commitment), rendered in clock
/// order. [isLive] is true for exactly the chunk [buildTimeline]'s injected
/// [NowState] identifies as current — never re-derived from the clock.
class ChunkRow extends TimelineRow {
  final ScheduledChunk chunk;
  final bool isLive;
  ChunkRow(this.chunk, {this.isLive = false});
}

/// Free time before the day's first chunk with a clock position
/// ("Free until 8:00am").
class LeadingFreeRow extends TimelineRow {
  final int untilMinutes;

  /// True once `nowMinutes` has reached or passed [untilMinutes] — the window
  /// this row describes is over.
  ///
  /// **NOW-02, amended 2026-08-18.** This used to suppress the row outright,
  /// on the sound reasoning that "Free until 9:45 AM" is not truthful copy
  /// once 9:45 has been and gone. But suppressing the row did not remove the
  /// time it covered — the day is laid out proportionally, so the region
  /// stayed exactly as tall and simply went blank, and that unexplained
  /// stretch of background is what UAT flagged. The row is now always built;
  /// the caller reads this flag and switches to the duration copy
  /// ("Free · 45m"), which is true before and after the fact. The original
  /// concern is honoured — do NOT render `until` copy when this is true.
  final bool windowPassed;

  LeadingFreeRow(this.untilMinutes, {this.windowPassed = false});
}

/// Free time between two chunks, named rather than collapsed to whitespace
/// ("Free · 1h 40m") — D-05.
class GapFreeRow extends TimelineRow {
  final int startMinutes;
  final int durationMinutes;
  GapFreeRow(this.startMinutes, this.durationMinutes);
}

/// Builds the unified Today timeline's row list from the day's [chunks] and
/// a [NowState].
///
/// INVARIANT 1: this function NEVER reads the clock — DateTime must not
/// appear anywhere in this file outside a doc comment. The only source of
/// "now" is the injected [nowState], which is the single now-detector
/// (22-PATTERNS.md section 5 / threat T-22-01): there is no code path by
/// which this row list can disagree with [resolveNowState] about which
/// chunk is current. [nowMinutes] is likewise an injected clock position in
/// minutes-from-midnight, computed by the caller from the same single
/// [nowState]-classifying `nowDt` sample — it is never obtained from a
/// clock read inside this file.
///
/// INVARIANT 2: the incoming [chunks] order is preserved and never
/// re-sorted — the schedule generator already emits clock order
/// (schedule_generator.dart STEP D), and re-sorting here would silently
/// reposition untimed chunks.
List<TimelineRow> buildTimeline({
  required List<ScheduledChunk> chunks,
  required NowState nowState,
  int? nowMinutes,
  int minGapMinutes = kMinGapMinutes,
}) {
  if (chunks.isEmpty) return [];

  final String? liveId = switch (nowState) {
    Active(:final current) => current.id,
    Overdue(:final overdue) => overdue.id,
    _ => null,
  };

  final rows = <TimelineRow>[];
  int? prevEnd;

  for (final chunk in chunks) {
    final start = chunk.displayStartMinutes;

    if (start != null) {
      if (prevEnd == null) {
        // First chunk with a clock position — leading free row if the day
        // doesn't start at minute 0.
        //
        // NOW-02 (amended 2026-08-18): the row is always built. It used to be
        // suppressed once the window had passed, for want of truthful copy —
        // but the layout is duration-proportional, so suppressing it left the
        // region just as tall and blank. There IS truthful alternate copy: the
        // duration form. Flag it and let the caller pick.
        if (start > 0) {
          rows.add(
            LeadingFreeRow(
              start,
              windowPassed: nowMinutes != null && nowMinutes >= start,
            ),
          );
        }
      } else if (start - prevEnd >= minGapMinutes) {
        // T-22-03: only a positive gap meeting the threshold produces a row,
        // so out-of-order/overlapping chunks silently emit nothing rather
        // than a negative-duration row.
        rows.add(GapFreeRow(prevEnd, start - prevEnd));
      }
      prevEnd = start + chunk.durationMinutes;
    }

    rows.add(ChunkRow(chunk, isLive: chunk.id == liveId));
  }

  return rows;
}
