import '../../utils/time_format.dart';

/// Pure minute-to-pixel geometry for Phase 26's proportional Today surface
/// (CAL-01/CAL-02/CAL-03).
///
/// INVARIANT (mirrors `timeline.dart`'s INVARIANT 1): this file NEVER reads
/// the clock — `DateTime` must not appear anywhere in it. Every "now" value
/// arrives as an injected `int` minutes-from-midnight, derived from
/// `build()`'s single `nowDt` sample. This file only does arithmetic on
/// already-known `int`s; it has no opinion about what time it is.

/// Pixels per minute of the timeline's vertical scale (CAL-01).
///
/// **PD-1 (26-01-PLAN.md "Locked planner decisions").** Supersedes
/// `26-UI-SPEC.md`'s `4.0`, which was justified by the stated claim that "a
/// 25-minute work chunk renders 100px — enough for a trimmed Full-tier card
/// (title + time range + action row)." That claim is measurably false: a
/// `ChunkCard` work card carrying exactly title + time range + the
/// Complete/Skip row, rendered at a width wide enough that no text wraps,
/// measures 126.0px (measured during planning, 2026-08-10, via
/// `tester.getSize(find.byType(ChunkCard))`). At `4.0`, every standard
/// 25-minute chunk would overflow its slot by 26px. `5.5` gives 137.5px for
/// 25 minutes — the card fits with ~11px of slack for real-Roboto line
/// metrics, and a 12-hour day still renders ~3960px (≈5 mobile screens),
/// squarely inside D-02's "the user scrolls through it."
///
/// This mirrors the `kGutterWidth` 46→75→52 correction precedent
/// (`timeline_row_tile.dart`) — a constant justified by an arithmetic claim
/// gets corrected when the claim is measured.
///
/// **This value is PROVISIONAL.** It is derived from a `flutter test`
/// measurement of `ChunkCard`'s rendered height, which uses a placeholder
/// font (no real Roboto metrics — see `kGutterWidth`'s own doc comment for
/// the precedent of this harness lying about text-driven sizing). A
/// real-browser check via `tools/serve-uat.py` (planned for Phase 26 Plan
/// 06) is the actual authority on whether `5.5` holds up, not this
/// `flutter test` measurement.
const double kPixelsPerMinute = 5.5;

/// Fixed reserved pixel height for the live row's card (CAL-01's one named
/// exception — "let now break the grid," carried forward unchanged from
/// `LiveRowCard`, see `26-UI-SPEC.md` "The live row exception").
///
/// **PD-2.** `LiveRowCard` (kicker + title + remaining + progress + actions
/// + next-line) measures 230.0px (measured 2026-08-10 — the UI-SPEC's
/// "200–220px" estimate was low). `240.0` reserves a small margin above
/// that measurement. This is a fixed estimate, not a two-pass
/// measure-then-`setState` flow (`26-RESEARCH.md` Pitfall 3, option (a)) —
/// rejected because a `GlobalKey`/`RenderBox` measure-then-correct flow
/// buys ~10px of precision at the cost of a correction frame and a whole
/// class of one-frame-snap bugs.
const double kLiveRowReservedHeight = 240.0;

/// Full-tier density threshold for a work-chunk row, expressed in pixels
/// (PD-3), not minutes.
///
/// **PD-3.** `26-UI-SPEC.md`'s original "≥ 20 min" threshold was derived
/// from `kPixelsPerMinute = 4.0`; a minute-based threshold silently rots if
/// the scale ever changes again (as it just did, PD-1). `132.0` = the
/// measured 126px Full-tier work card content height plus slack, expressed
/// in the unit (pixel slot height) that actually decides whether the tier
/// fits.
const double kFullTierMinHeight = 132.0;

/// Full-tier density threshold for a break row, expressed in pixels (PD-3).
///
/// **PD-3.** `88.0` = the measured 80px long-break content height plus
/// slack, expressed in pixel slot height rather than minutes, for the same
/// rot-resistance reason as [kFullTierMinHeight].
const double kFullBreakMinHeight = 88.0;

/// The now-line overlay's own box height — the 2dp rule and its time chip
/// are vertically centred inside a box this tall, so they land exactly on
/// the computed offset without needing a second layout pass.
const double kNowLineHeight = 28.0;

/// The hour-axis row's own box height, matching [kNowLineHeight]'s role for
/// the hour-boundary label + hairline.
const double kHourAxisHeight = 20.0;

/// The minute-to-pixel authority for Phase 26's proportional Today surface.
///
/// Pure and immutable: every method is arithmetic on the `int`/`double`
/// fields captured at construction — no clock read, no widget-tree access,
/// no side effects. [forDay] is the only place `nowMinutes`,
/// `firstStartMinutes`, and `lastEndMinutes` are consulted; every other
/// method only reads `this`'s already-resolved fields.
class TimelineGeometry {
  const TimelineGeometry({
    required this.rangeStart,
    required this.rangeEnd,
    this.liveStartMinutes,
    this.liveEndMinutes,
    this.liveExtraPx = 0.0,
  });

  /// The first minute rendered — always a whole-hour boundary at or before
  /// every relevant instant (now, the day's first chunk start).
  final int rangeStart;

  /// The last minute rendered — always a whole-hour boundary at or after
  /// every relevant instant (now, the day's last chunk end).
  final int rangeEnd;

  /// The live chunk's start minute, or null when there is no live row.
  final int? liveStartMinutes;

  /// The live chunk's end minute, or null when there is no live row.
  final int? liveEndMinutes;

  /// Extra pixels the live row's card claims beyond its duration-implied
  /// slot height — folded into every consumer (rows, hour axis, now-line,
  /// scroll target) at and after [liveEndMinutes], per
  /// `26-UI-SPEC.md` "The live row exception."
  final double liveExtraPx;

  /// Builds the day's rendered range and live-row exception from raw
  /// schedule/clock data, per `26-UI-SPEC.md` "Scroll-on-open & the
  /// rendered vertical range."
  ///
  /// `rangeStart`/`rangeEnd` are defined so "now" is always inside the
  /// rendered range, by construction: each bound is a `min`/`max` against
  /// [nowMinutes] itself, rounded outward to a whole-hour boundary for a
  /// clean hour-axis top/bottom.
  factory TimelineGeometry.forDay({
    required int nowMinutes,
    required int? firstStartMinutes,
    required int? lastEndMinutes,
    int? liveStartMinutes,
    int? liveEndMinutes,
  }) {
    final rawStart = firstStartMinutes == null
        ? nowMinutes
        : (nowMinutes < firstStartMinutes ? nowMinutes : firstStartMinutes);
    final rawEnd = lastEndMinutes == null
        ? nowMinutes
        : (nowMinutes > lastEndMinutes ? nowMinutes : lastEndMinutes);

    final rangeStart = floorToHour(rawStart);
    var rangeEnd = ceilToHour(rawEnd);
    // Defensive: a degenerate day (e.g. rawStart == rawEnd, both already
    // hour-aligned) still gets a paintable hour of surface, mirroring
    // timeline.dart's T-22-03 posture of emitting nothing rather than a
    // negative-size row.
    if (rangeEnd <= rangeStart) {
      rangeEnd = rangeStart + 60;
    }

    double liveExtraPx = 0.0;
    if (liveStartMinutes != null && liveEndMinutes != null) {
      final liveDurationPx =
          (liveEndMinutes - liveStartMinutes) * kPixelsPerMinute;
      final extra = kLiveRowReservedHeight - liveDurationPx;
      liveExtraPx = extra > 0.0 ? extra : 0.0;
    }

    return TimelineGeometry(
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      liveStartMinutes: liveStartMinutes,
      liveEndMinutes: liveEndMinutes,
      liveExtraPx: liveExtraPx,
    );
  }

  /// The pixel offset of [minutes] from the top of the rendered range.
  ///
  /// Clamps [minutes] into `[rangeStart, rangeEnd]` first — defensive:
  /// guarantees no negative offset and no offset past [totalHeight]. Adds
  /// [liveExtraPx] once the clamped minute reaches or passes
  /// [liveEndMinutes]. The `>=` (not `>`) is load-bearing: it makes the
  /// live chunk's own slot exactly [kLiveRowReservedHeight] tall, and makes
  /// the row starting at the live chunk's end minute begin immediately
  /// below the swelled card rather than underneath it.
  double yFor(int minutes) {
    final clamped = minutes < rangeStart
        ? rangeStart
        : (minutes > rangeEnd ? rangeEnd : minutes);
    var offset = (clamped - rangeStart) * kPixelsPerMinute;
    if (liveEndMinutes != null && clamped >= liveEndMinutes!) {
      offset += liveExtraPx;
    }
    return offset;
  }

  /// The pixel height of a row spanning `[startMinutes, startMinutes +
  /// durationMinutes)`, clamped to a non-negative value (T-26-01 — guards
  /// against corrupt/out-of-order data yielding a negative duration).
  double heightFor(int startMinutes, int durationMinutes) {
    final height = yFor(startMinutes + durationMinutes) - yFor(startMinutes);
    return height < 0.0 ? 0.0 : height;
  }

  /// The rendered range's total pixel height.
  double get totalHeight => yFor(rangeEnd);

  /// Every whole-hour boundary minute inside the rendered range, ascending.
  List<int> get hourBoundaries => hourBoundariesIn(rangeStart, rangeEnd);
}
