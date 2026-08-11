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
/// **G-02 (26-08-PLAN.md) — REAL-BROWSER measurement, 2026-08-11, 430px
/// viewport.** The prior `240.0` was derived from a `flutter test` pump
/// (PD-2 below) — a placeholder-font harness measurement, exactly the class
/// of quantity `26-VALIDATION.md` routes to the manual-only gate. Measured
/// instead in a real GPU-backed browser (headless Chromium,
/// `--use-gl=swiftshader`, debug build served via `tools/serve-uat.py`),
/// screenshot-pixel-counted against `LiveRowCard`'s `primaryContainer` fill:
///
/// - **Work variant (the tallest — carries the Complete/Skip action row;
///   this is what the reservation is sized against)**: 200px of
///   `primaryContainer` fill + this card's own 24px vertical margin
///   (`EdgeInsets.symmetric(vertical: 12)`, itself part of the natural size
///   `Positioned` lays out against since it has no `height:` constraint) =
///   **224px natural height**.
/// - **Break variant (for contrast only — Phase 23's LIVE-01 omits the
///   action row for breaks, so this is shorter)**: 158px fill + 24px margin
///   = **182px natural height**. Comfortably under the reservation below;
///   not what the reservation is sized against.
///
/// `232.0` = 224 (measured work-variant natural height) + an explicit
/// **8px margin** (the tight end of the plan's stated 8–16px range) to
/// absorb minor cross-renderer/DPI anti-aliasing variance. This margin is
/// NOT enough to fully absorb a goal title wrapping to a second
/// `headlineSmall` line (~28–32px) — that remains a documented residual
/// risk, not a claim this constant covers.
///
/// **Do NOT re-derive this from `flutter test`.** Its placeholder font has
/// no real Roboto metrics and inflates/distorts measured glyph geometry —
/// the same failure mode that took `kGutterWidth` 46 → 75 (harness) → 52
/// (real-browser correction), and the reason the harness-derived `230.0`
/// below undershot what a real browser draws by only a little rather than a
/// lot, which is itself not something to trust without re-measuring.
///
/// **What would invalidate this value:** any change to `LiveRowCard`'s
/// children (kicker/title/remaining/progress/actions/next-line), its
/// typography (`theme.textTheme.headlineSmall`/`bodyMedium`/`bodySmall`), or
/// whether the action row renders for work chunks.
///
/// ---
///
/// **PD-2 (superseded 2026-08-11, kept for history).** `LiveRowCard` (kicker
/// + title + remaining + progress + actions + next-line) measures 230.0px
/// (measured 2026-08-10 via a `flutter test` pump — the UI-SPEC's
/// "200–220px" estimate was low). `240.0` reserved a small margin above
/// that measurement. This is a fixed estimate, not a two-pass
/// measure-then-`setState` flow (`26-RESEARCH.md` Pitfall 3, option (a)) —
/// rejected because a `GlobalKey`/`RenderBox` measure-then-correct flow
/// buys ~10px of precision at the cost of a correction frame and a whole
/// class of one-frame-snap bugs. **That mechanism choice still stands** —
/// only the number changed (G-02, above).
const double kLiveRowReservedHeight = 232.0;

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
