import '../../data/models/scheduled_chunk.dart';

// ─── NowState sealed hierarchy ───────────────────────────────────────────────
//
// Top-level, public result types for "what is happening now" in the day's
// schedule. Kept PUBLIC (no leading underscore) so unit tests can assert
// `isA<PreStart>()` without a widget pump. This is the single source of
// truth for "what is happening now" on the unified Today screen.

/// Discriminated result of [resolveNowState]. Exactly one subtype is
/// returned based on the current wall-clock time relative to the day's
/// scheduled chunk windows.
sealed class NowState {}

/// Before the first chunk window. [firstChunk] is the upcoming chunk.
class PreStart extends NowState {
  final ScheduledChunk firstChunk;
  PreStart(this.firstChunk);
}

/// Current time falls within an active chunk window. [current] is the matched
/// chunk; [next] is the first unresolved chunk after it (or null).
class Active extends NowState {
  final ScheduledChunk current;
  final ScheduledChunk? next;
  Active(this.current, this.next);
}

/// Current time is past a chunk's window end but that chunk is still
/// unresolved. [overdue] is that chunk; [next] is the upcoming chunk (or null).
class Overdue extends NowState {
  final ScheduledChunk overdue;
  final ScheduledChunk? next;
  Overdue(this.overdue, this.next);
}

/// Current chunk is resolved and the next chunk's window has not yet opened.
/// The day is NOT complete — future unresolved work remains.
///
/// [next] is the first upcoming unresolved chunk (guaranteed non-null;
/// [DayComplete] is returned instead when no unresolved future chunks remain).
class GapBeforeNext extends NowState {
  final ScheduledChunk next;
  GapBeforeNext(this.next);
}

/// All chunk windows have passed, or all chunks are resolved, or there are
/// no chunks with a clock time.
///
/// Deliberate departure from 17-UI-SPEC.md §State Boundary Handling: when
/// ALL work chunks have `displayStartMinutes == null` (degenerate edge case),
/// this returns [DayComplete] rather than re-introducing the old
/// "first unresolved" fallback that this phase exists to remove.
/// RESEARCH Open Question 1 (RESOLVED): this case is effectively unreachable
/// in practice because the generator always assigns syntheticStartMinutes.
class DayComplete extends NowState {}

// ─── resolveNowState ─────────────────────────────────────────────────────────

/// Classifies the current moment in the day's chunk schedule.
///
/// Pure function — no side effects. Injectable [now] enables unit testing
/// at arbitrary wall-clock times without sleeping or mocking DateTime.now.
///
/// [now] is called exactly once per invocation; callers may supply any stable
/// supplier (e.g., `() => DateTime.now()` or a test-frozen constant).
///
/// Algorithm:
/// 1. Filter to chunks with a non-null [ScheduledChunk.displayStartMinutes],
///    then sort ascending by that value. As of LIVE-01, breaks participate
///    here too (the filter used to exclude them) — this is what lets a
///    running break resolve to [Active] instead of a false [GapBeforeNext].
///    Two independent generation paths both guarantee the last scheduled
///    chunk is work-typed, so the [DayComplete] window check below is
///    unaffected by breaks joining the input set: (a) `schedule_generator
///    .dart` STEP E trims any trailing non-work chunk after a full-day
///    `generate()`, and (b) `ScheduleNotifier._reflowDiscretionaryWork`
///    (which mutates the day's chunks directly, without calling
///    `generate()`, from `addEventToday`) only ever emits a break *between*
///    two movable work chunks (`if (i + 1 < movable.length)`), so it can
///    never leave a trailing break either. A future edit to either
///    mechanism that breaks this guarantee would silently regress
///    [DayComplete] here — keep them in sync.
/// 2. Empty result → [DayComplete] (documented departure — see class doc).
/// 3. currentMinutes < first chunk start → [PreStart].
/// 4. currentMinutes ≥ last chunk end → [DayComplete].
/// 5. Otherwise: find the most-recent chunk whose window has started, advance
///    past resolved (completed/skipped) chunks, then:
///    - If the next chunk's window hasn't opened and unresolved work remains →
///      [GapBeforeNext] (day is NOT over; future work pending).
///    - If the next chunk's window hasn't opened and no unresolved work remains
///      → [DayComplete].
///    - If still inside the window → [Active].
///    - If past the window end → [Overdue].
///
/// KEY INVARIANT: clock-window is found FIRST by time, THEN resolution is
/// checked. This prevents re-creating the "first unresolved" bug (RESEARCH
/// Anti-pattern / Pitfall 3).
///
/// FRAME-OF-REFERENCE NOTE: [displayStartMinutes] is intentionally compared
/// against LOCAL wall-clock minutes-from-midnight (never `.toUtc()`). This
/// matches the way [formatMinutes] renders chunk times in the UI — both the
/// "Now" label and the visible start-time label are derived from the same
/// un-converted minutes value, so they always agree. The ScheduledChunk model
/// doc comment for [anchoredStartMinutes] says "UTC", but the display layer
/// (formatMinutes, chunk_card.dart, "Your day starts at…") never converts —
/// making the effective frame of reference LOCAL for all UI purposes. Fixing
/// the UTC label is a pre-existing issue in the display layer, out of scope
/// for Phase 17; resolveNowState is intentionally consistent with the UI.
NowState resolveNowState({
  required List<ScheduledChunk> chunks,
  required DateTime Function() now,
}) {
  // Sample now() exactly once to avoid a race at minute boundaries.
  // If now() were called twice (e.g. `now().hour * 60 + now().minute`),
  // a rollover at 8:59→9:00 could yield hour=8 from the first call and
  // minute=0 from the second, producing 480 instead of 540.
  final nowDt = now();
  final currentMinutes = nowDt.hour * 60 + nowDt.minute;

  // Filter to chunks (work AND breaks) that have a clock position, sort by
  // window start. LIVE-01 dropped the work-only clause: the algorithm below
  // has no work-chunk-specific logic, so breaks slot in for free.
  final scheduled = chunks.where((c) => c.displayStartMinutes != null).toList()
    ..sort((a, b) => a.displayStartMinutes!.compareTo(b.displayStartMinutes!));

  // Degenerate: no chunks with clock times → day-complete.
  if (scheduled.isEmpty) return DayComplete();

  // Before the first chunk's window.
  if (currentMinutes < scheduled.first.displayStartMinutes!) {
    return PreStart(scheduled.first);
  }

  // Past the last chunk's window end.
  if (currentMinutes >=
      scheduled.last.displayStartMinutes! + scheduled.last.durationMinutes) {
    return DayComplete();
  }

  // Find the chunk whose window has started most recently.
  final candidates = scheduled
      .where((c) => c.displayStartMinutes! <= currentMinutes)
      .toList();
  var active = candidates.last;

  // Advance past resolved chunks (completed or skipped).
  // Window is found by clock time first — resolution checked after.
  //
  // INVARIANT: only promote a chunk to active/overdue if its window has
  // already opened (displayStartMinutes <= currentMinutes). If the next
  // chunk's window hasn't started yet we are in a post-resolved gap —
  // return GapBeforeNext(upcoming) when unresolved future work remains (an
  // honest "up next" state, NOT day-complete), and DayComplete only when no
  // unresolved future chunk remains. Never show a future chunk as "Now".
  while (active.isCompleted || active.isSkipped) {
    final idx = scheduled.indexOf(active);
    if (idx + 1 >= scheduled.length) return DayComplete();
    final candidate = scheduled[idx + 1];
    // Only promote if the next window has already opened.
    if (candidate.displayStartMinutes! > currentMinutes) {
      // Gap: current chunk resolved, next window not yet open.
      // Find the first unresolved chunk with a future window — if one exists
      // the day is NOT complete, just paused between windows.
      final remaining = scheduled
          .sublist(idx + 1)
          .where((c) => !c.isCompleted && !c.isSkipped)
          .firstOrNull;
      if (remaining != null) return GapBeforeNext(remaining);
      // All future chunks are also resolved — the day genuinely is done.
      return DayComplete();
    }
    active = candidate;
  }

  // Find the next unresolved chunk after the active one.
  final activeIdx = scheduled.indexOf(active);
  final next = scheduled
      .sublist(activeIdx + 1)
      .where((c) => !c.isCompleted && !c.isSkipped)
      .firstOrNull;

  // Within the window → Active; past the window end → Overdue.
  final windowEnd = active.displayStartMinutes! + active.durationMinutes;
  if (currentMinutes >= windowEnd) {
    return Overdue(active, next);
  }
  return Active(active, next);
}
