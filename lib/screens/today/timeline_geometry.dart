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
/// **5.5 → 4.0 (2026-08-18, UAT: "the elements take up too much vertical
/// space").** The 5.5 above was correct arithmetic against a 126px card — but
/// it took the card's height as fixed and solved for the scale. The card was
/// compacted instead: the `full` tier now puts the clock-time range on the
/// title's own line and tightens its vertical padding to 8dp, which
/// **measured 70dp** for a work card in a real browser (headless Chromium,
/// debug build via `tools/serve-uat.py`, 500dp viewport at DPR 2 —
/// pixel-counted off the card's coloured accent bar, 2026-08-18).
///
/// `4.0` gives 100px for 25 minutes against that ~70dp card plus its 8dp of
/// Card margin — ~22px of slack, comfortably more than the ~11px the old
/// pairing ran on. A 12-hour day now renders ~2880px instead of ~3960px,
/// roughly a screen and a half shorter.
///
/// Note this lands back on the `26-UI-SPEC.md` value that PD-1 rejected. The
/// spec's number was right; its justification ("enough for a trimmed
/// Full-tier card") was not true of the card as it then existed. It is true
/// of the card as it exists now — which is the difference between reaching a
/// number by measurement and by assertion.
///
/// **Measure in a real browser, never in `flutter test`.** That harness's
/// placeholder font has no real Roboto metrics — the failure mode that took
/// `kGutterWidth` 46 → 75 → 52. Any change to `ChunkCard`'s `full` tier
/// content or typography invalidates this pairing; re-measure, then re-derive
/// this and [kFullTierMinHeight] together.
///
/// **Re-confirmed 2026-08-20 (plan 29-04, ROADMAP item 4 / D-06).** SEED-005
/// had flagged a 25-minute work chunk clipping 26dp inside its 100dp slot
/// (126dp natural vs. 100dp slot) — that figure came from `flutter test`'s
/// placeholder font. Re-measured in a real browser, same recipe as above: a
/// non-live "Side project, 9:00 AM – 9:25 AM" `full`-tier card, headless
/// Chromium, debug build on port `8143`, pixel-counted with
/// `.planning/phases/29-breaks-you-can-see/tools/measure_card_extent.py`
/// against `.planning/phases/29-breaks-you-can-see/shots/work-chunk-fit.png`.
/// **Measured ink extent: 90px** (band rows 513..602, the card's own outline
/// border top-to-bottom), inside its 100px slot (screenshot rows ~517..617)
/// with the bottom border band ending at row 602 — comfortably above the
/// slot's last row, not clipped. **Verdict: DISMISSED (harness artifact)** —
/// SEED-005's 126dp was the `flutter test` placeholder-font bound its own
/// caveat said it was, not a real on-device defect. No code change made;
/// this constant and the slot height are unchanged (D-03).
///
/// **4.0 -> 6.0 (D-32-01, LOCKED, owner-ruled, 2026-08-27).** Reverses this
/// constant's own D-03 verdict above — not because D-03 was wrong on its
/// terms (it was legibility evidence, and it held), but because a real thumb
/// failed twice on a 20dp break row (`31-UAT.md`, both rounds) and D-03
/// predates that evidence entirely. Chosen over three alternatives
/// specifically because it keeps the grid honest: every row still renders at
/// exactly `durationMinutes * kPixelsPerMinute` — a 5-min break becomes
/// 30dp (was 20dp), a 25-min work chunk becomes 150dp (was 100dp). The
/// rejected alternatives all bought a bigger break by making some row lie
/// about its duration. **Accepted cost, taken by the owner with eyes open:
/// the day is 50% taller to scroll** (an 8-hour day ~1920dp -> ~2880dp).
const double kPixelsPerMinute = 6.0;

/// Full-tier density threshold for a work-chunk row, expressed in pixels
/// (PD-3), not minutes.
///
/// **PD-3.** `26-UI-SPEC.md`'s original "≥ 20 min" threshold was derived
/// from `kPixelsPerMinute = 4.0`; a minute-based threshold silently rots if
/// the scale ever changes again (as it has, twice). Expressing it in pixel
/// slot height — the unit that actually decides whether the tier fits — is
/// what makes it survive a scale change.
///
/// **132.0 → 88.0 (2026-08-18).** Re-derived alongside [kPixelsPerMinute]
/// when the `full` tier was compacted: 70dp measured card + 8dp Card margin +
/// ~10dp slack. At the new 4.0 scale a standard 25-minute chunk gets a 100px
/// slot and still clears this, so it keeps its title, time, and action row —
/// the compaction shortens the day without demoting rows to title-only.
const double kFullTierMinHeight = 88.0;

/// Full-tier density threshold for a break row, expressed in pixels (PD-3).
///
/// **PD-3.** `88.0` = the measured 80px long-break content height plus
/// slack, expressed in pixel slot height rather than minutes, for the same
/// rot-resistance reason as [kFullTierMinHeight].
const double kFullBreakMinHeight = 88.0;

/// **RETIRED (Phase 32, D-32-02, TAPBREAK-01/03).** Used to gate Phase 29's
/// `subCompact` break tier (`ChunkCardDensity.subCompact`/`_SubCompactRow`,
/// `chunk_card.dart`) — a hairline-with-label treatment for a break slot too
/// small for the `compact` card. That tier is deleted outright this phase,
/// not re-thresholded: at `kPixelsPerMinute = 6.0` a 5-minute break's 30dp
/// slot would still have landed under this constant's old `32.0` value,
/// reproducing the exact hairline defect Phase 29 existed to fix, had the
/// threshold simply moved with the scale instead of the tier it gated being
/// removed. Nothing reads this constant once `subCompact` is gone — see
/// `32-RESEARCH.md` § "The retirement surface" for the verified reference
/// list this deletion closes out.

/// The Skip rail's fixed width (D-32-03, LOCKED, owner-ruled, 2026-08-27).
/// `64.0` sits on the existing 8-pt spacing scale (`64 = 8 x 8`). At the
/// smallest reachable break slot (a 5-minute break, 30dp at [kPixelsPerMinute]
/// = 6.0) this yields a **64 x 30 = 1920dp^2** rail — under Material's
/// 48 x 48 = 2304dp^2 touch-target guideline, and deliberately so: the owner's
/// own reasoning (ROADMAP, D-32-03) is that every pixel of a visible,
/// fixed-width rail is *painted*, and meeting a spec number with an invisible
/// hit-test envelope (this codebase's own Phase 31 approach, twice) is a
/// weaker guarantee than missing it slightly with a target the user can see.
/// Do not "fix" this by adding hit-test slop or a vertical overhang — that is
/// re-litigating a settled decision (both retired constants this replaces —
/// the invisible-envelope slop amount and the drag-target gate that decided
/// when it applied — are deleted, not merely unused, per this phase's own
/// "retire deliberately" charter).
const double kBreakSkipButtonWidth = 64.0;

/// **RETIRED (Phase 32, D-32-02, TAPBREAK-01).** Used to grow a break's
/// invisible swipe hit-test envelope beyond its painted slot (Phase 31,
/// D-31-02/D-31-06), paired with the drag-target gate this constant's own
/// former sibling (`kMinBreakDragTarget`) supplied. Breaks have no swipe
/// target to widen any more — button-only, D-32-02 — so neither constant has
/// a reader left. See `32-RESEARCH.md` § "The retirement surface" for the
/// verified reference list this deletion closes out.

/// **MEASURED (2026-08-18, plan 27-04).** The slot height at or above which
/// `LiveRowCard`'s compact tier fits; below it the single-line tier is used
/// (there is no third tier).
///
/// **Method:** headless Chromium (`--use-gl=swiftshader
/// --enable-unsafe-swiftshader`), viewport `430`×930 at DPR 1 (screenshot px
/// = logical px), debug build (`flutter build web --debug --source-maps
/// --pwa-strategy=none`) served through `tools/serve-uat.py` on port `8137`,
/// simulated clock parked 10 minutes (40%) into a live 25-minute Exercise
/// chunk (8:00–8:25 AM). A freshly onboarded profile generates its own day, so
/// the instant is chosen by position within the live chunk rather than by
/// literal clock time — the recipe's requirement is that a chunk is live and
/// the now-line sits inside the card, not that it is any particular hour.
/// Pixel-counted via `.planning/phases/27-true-grid/tools/
/// measure_card_fill.py` against `.planning/phases/27-true-grid/shots/
/// compact-uat-0810-work-live.png`.
///
/// **84.0 → 88.0 (re-measured 2026-08-19, after UAT).** The first measurement
/// (76px raw) was taken against 36×36dp Complete/Skip buttons. UAT on a real
/// touch device found those too small to hit reliably with a thumb, so
/// `kLiveActionTouchTarget` rose to 44dp — which raises the compact tier's
/// action row and therefore this measurement. **Re-measured raw natural
/// height: 80px** (fill band rows 226–305), taken the same way against a live
/// 8:00–8:25 AM chunk at a simulated 8:10 AM. `80 + 8 = 88.0`.
///
/// The `+8px` is an **explicit safety margin** — the upper end of this file's
/// already-established 4–8dp range (`kLiveRowReservedHeight`'s now-deleted
/// precedent was "224 measured + 8 explicit = 232.0") — affordable because the
/// clearance over a standard 25-minute chunk's 100px slot is still generous
/// (100 − 80 = 20px of natural slack).
///
/// **Relationship to [kFullTierMinHeight] (Pitfall 6, `27-RESEARCH.md`).**
/// This measurement lands on `88.0`, **numerically identical** to
/// [kFullTierMinHeight]. That triggers the "decide explicitly" rule, and the
/// decision is: **keep them separate, do not collapse them.**
///
/// The equality is a coincidence of two independent measurements, not a shared
/// cause. They threshold different card layouts with no shared content —
/// [LiveRowCard]'s compact tier (kicker, title, action icons, countdown) vs.
/// `ChunkCard`'s full tier (title, time range, action row) — so nothing makes
/// them move together. Note the history: they were *also* both `88.0` before
/// this phase, then this one measured to `84.0`, and now it has measured back
/// to `88.0`. Twice-coincidental is still coincidental.
///
/// **Do not "simplify" these into one constant.** Collapsing them would couple
/// two widgets that change independently, and the next content change to
/// either card would silently retune the other card's density tier — a bug
/// with no obvious cause at the call site.
///
/// **Single-line tier, confirmed separately:** the same profile's live
/// 5-minute break (8:25–8:30 AM, simulated 8:27 AM) renders one legible line
/// inside its 20px slot — unaffected by the touch-target change, since that
/// tier carries no buttons. See `single-line-uat-0827-break-live.png`.
///
/// **Do not derive this from `flutter test`.** This file already carries a
/// three-strikes history of constants that were wrong when set from that
/// harness's placeholder-font measurements: `kGutterWidth` (`timeline_row_
/// tile.dart`) went 46 → 75 → 52; [kPixelsPerMinute] went 4.0 → 5.5 → 4.0;
/// the live row's now-deleted reserved-height constant went 240 → 232
/// before this phase removed it outright.
///
/// **What would invalidate this value:** any change to the compact tier's
/// children (kicker, title, actions row, remaining-time line) or how many
/// there are; any typography change to `labelSmall` / `titleMedium` /
/// `bodySmall`; any change to `kLiveActionTouchTarget` or the icon-button
/// padding (that is exactly what invalidated the first measurement);
/// any change to the Card's `12`/`8` (horizontal/vertical) padding or its
/// `4`/`4` margin. Re-measure with `measure_card_fill.py` against a fresh
/// screenshot — never against `flutter test`.
const double kCompactLiveMinHeight = 88.0;

/// The now-line overlay's own box height — the 2dp rule and its time chip
/// are vertically centred inside a box this tall, so they land exactly on
/// the computed offset without needing a second layout pass.
const double kNowLineHeight = 28.0;

/// The hour-axis row's own box height, matching [kNowLineHeight]'s role for
/// the hour-boundary label + hairline.
const double kHourAxisHeight = 20.0;

/// Headroom reserved at BOTH the top and bottom of the rendered range so no
/// `Positioned` box can ever be clipped by the Stack's default
/// `Clip.hardEdge` (G-04/G-05, `26-10-PLAN.md`).
///
/// **Root cause:** `HourAxisLine` and `NowLineOverlay` are both positioned
/// as `Positioned(top: geometry.yFor(x) - <height>/2, height: <height>)` —
/// they straddle their own y. `hourBoundariesIn` always includes
/// `rangeStart` as the first boundary and `rangeEnd` as the last, and
/// (pre-this-constant) `yFor` mapped those to exactly `0` and `totalHeight`
/// — so the first/last hour-axis label straddled the Stack's own edge and
/// was sheared in half (G-04), and the now-line clipped identically
/// whenever `nowMinutes` landed within half a box-height of `rangeStart`/
/// `rangeEnd` — which is exactly `PreStart` and `DayComplete`, since those
/// two states derive `rangeStart`/`rangeEnd` from `nowMinutes` itself
/// (G-05).
///
/// **Rejected fix:** `clipBehavior: Clip.none` on the outer Stack. That
/// un-shears the labels but lets the top box paint above the Stack, into
/// the header block directly above it — trading a sheared label for one
/// that collides with body copy (`26-UI-REVIEW.md` Top Fix #1).
///
/// **This fix instead:** reserve `kTimelineEdgePadding` of blank space at
/// both ends of [TimelineGeometry.totalHeight] and shift every
/// [TimelineGeometry.yFor] result down by that amount, so the straddling
/// box's own half-height always has room inside `[0, totalHeight]`. Applied
/// in exactly one place (inside this file) — every consumer (rows, hour
/// hairlines, the now-line, the centre-on-open scroll target) inherits it
/// automatically through `yFor`/`totalHeight`; do NOT re-derive or add this
/// offset at an individual call site.
///
/// Sized to `max(kHourAxisHeight, kNowLineHeight) / 2` — the larger of the
/// two straddling widgets' half-heights — so both are covered by the same
/// single constant. `kNowLineHeight` (28.0) is currently the larger of the
/// two, so this evaluates to `14.0`; if either constant changes, this stays
/// correct without editing this value by hand.
const double kTimelineEdgePadding = kNowLineHeight > kHourAxisHeight
    ? kNowLineHeight / 2
    : kHourAxisHeight / 2;

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
  });

  /// The first minute rendered — always a whole-hour boundary at or before
  /// every relevant instant (now, the day's first chunk start).
  final int rangeStart;

  /// The last minute rendered — always a whole-hour boundary at or after
  /// every relevant instant (now, the day's last chunk end).
  final int rangeEnd;

  /// The live chunk's start minute, or null when there is no live row.
  ///
  /// **Phase 27 (GRID-01).** No code reads this field today — it has no
  /// consumer. It is retained anyway as the documented source a future
  /// now-line time chip's live-span predicate should read from
  /// (`today_screen.dart` ~1385-1397 names `liveStartMinutes`/
  /// `liveEndMinutes` by name as where to find it if that chip is ever
  /// restored), NOT because the geometry currently does anything with the
  /// live span. The old justification — "load-bearing for G-03 now-line-chip
  /// suppression" — is stale: that chip was retired in Phase 26
  /// (`today_screen.dart` ~1385-1397, "the `showChip` argument ... the chip
  /// is gone") and `grep -rn "liveStartMinutes" lib/` shows no reader.
  final int? liveStartMinutes;

  /// The live chunk's end minute, or null when there is no live row.
  ///
  /// See [liveStartMinutes]'s doc comment — same retained-for-a-future-
  /// consumer rationale, same no-current-reader fact.
  final int? liveEndMinutes;

  /// Builds the day's rendered range from raw schedule/clock data, per
  /// `26-UI-SPEC.md` "Scroll-on-open & the rendered vertical range." (Phase
  /// 27, GRID-01: no longer also builds a live-row exception — that
  /// mechanism is deleted.)
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

    return TimelineGeometry(
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      liveStartMinutes: liveStartMinutes,
      liveEndMinutes: liveEndMinutes,
    );
  }

  /// The pixel offset of [minutes] from the top of the rendered range, PLUS
  /// [kTimelineEdgePadding] (G-04/G-05) — every offset this method returns
  /// is shifted down by that fixed amount, so a box straddling `yFor(x)` by
  /// up to `kTimelineEdgePadding` on either side can never start above `0`
  /// or (per [totalHeight]) end below the Stack's own bottom edge.
  ///
  /// Clamps [minutes] into `[rangeStart, rangeEnd]` first — defensive:
  /// guarantees the pre-padding offset is never negative and never past
  /// the pre-padding total.
  ///
  /// **GRID-01 (Phase 27).** The mapping is unconditionally linear — no
  /// branch, no exception for the live row. It used to add a fixed pixel
  /// amount once the clamped minute reached or passed [liveEndMinutes], so
  /// exactly one hour per day (whichever one a chunk was live in) rendered
  /// far taller than every other hour's plain `60 * kPixelsPerMinute` — a
  /// defect no existing test could see, because every prior test asserted
  /// `yFor()` against this same arithmetic. That term is deleted, not
  /// zeroed; see git history / `27-01-PLAN.md` for the removed mechanism.
  double yFor(int minutes) {
    final clamped = minutes < rangeStart
        ? rangeStart
        : (minutes > rangeEnd ? rangeEnd : minutes);
    return (clamped - rangeStart) * kPixelsPerMinute + kTimelineEdgePadding;
  }

  /// The pixel height of a row spanning `[startMinutes, startMinutes +
  /// durationMinutes)`, clamped to a non-negative value (T-26-01 — guards
  /// against corrupt/out-of-order data yielding a negative duration).
  ///
  /// [kTimelineEdgePadding] cancels out of this difference (both [yFor]
  /// calls add the same constant), so a row's height stays exactly
  /// duration-implied — unaffected by the edge padding, as it must be
  /// (D-02). This includes the live row (GRID-01, Phase 27): every row is
  /// duration-exact now, with no exception.
  double heightFor(int startMinutes, int durationMinutes) {
    final height = yFor(startMinutes + durationMinutes) - yFor(startMinutes);
    return height < 0.0 ? 0.0 : height;
  }

  /// The rendered range's total pixel height, including
  /// [kTimelineEdgePadding] at BOTH the top (already folded into every
  /// [yFor] result, including this one) and the bottom (added explicitly
  /// here) — so the last hour-axis label and a `DayComplete` now-line have
  /// the same headroom below `rangeEnd` that the first label and a
  /// `PreStart` now-line have above `rangeStart`.
  double get totalHeight => yFor(rangeEnd) + kTimelineEdgePadding;

  /// Every whole-hour boundary minute inside the rendered range, ascending.
  List<int> get hourBoundaries => hourBoundariesIn(rangeStart, rangeEnd);
}
