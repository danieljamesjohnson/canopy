import 'package:flutter/material.dart';

/// Width of the time gutter reserved on the left of every timeline row
/// (D-06's ~46px time column).
///
/// **Do not size this from a `flutter test` text measurement.** That harness
/// renders with a placeholder font that draws every glyph as a fixed
/// `fontSize`-wide box (probed directly: '1', 'i', 'W', ':' and 'p' all
/// measure exactly 12.0px at fontSize 12 — real proportional Roboto metrics
/// are not loaded). Measuring "12:45p" there yields 72px, which is a property
/// of the harness, not of the app.
///
/// UAT G-04 was fixed by giving the gutter the same 16dp inset every other
/// element already had — **the clipping was never a width problem.** A first
/// pass also bumped this constant 46 → 75 on the strength of that fake
/// measurement; a real-browser check (per this project's CLAUDE.md) showed
/// "12:10p" rendering ~40px in actual Roboto, so 75 reserved ~35dp of dead
/// space and pushed every card right, which was visible on screen.
///
/// **52.0 → 40.0 (2026-08-17, Dan's call during UAT.)** The old 52 was sized
/// for the now-line's time *chip* ("12:45p", the compact format's 6-character
/// maximum, ~40px real-browser + padding), NOT for the hour-axis labels that
/// are the only thing left in this column. Measured in the served debug build:
/// the chip filled 51 of the 52dp, while "9 AM" renders just 27dp — so "12 PM"
/// and "10 AM", the widest labels `HourAxisLine` can produce, need ~34dp.
///
/// 40.0 = that ~34dp worst case plus ~6dp slack for larger text-scale
/// settings. The chip was retired (see `now_line.dart`) precisely so this
/// could shrink and hand the width back to every chunk card, which is the
/// whole point of the change — **restoring a chip here would need 52 again.**
///
/// Verified visually in the served debug build, not just in tests.
const double kGutterWidth = 40.0;

/// The horizontal inset every element on the Today timeline shares — the
/// header, the hour axis, each row, the now-line, and the live row.
///
/// Single source of truth deliberately: the two elements the screen positions
/// `left: 0, right: 0` (the now-line overlay and the live row) do NOT inherit
/// [TimelineRowTile]'s padding and must reapply this themselves. Both did so
/// with their own literal `16`, and both got it wrong at least once — the
/// now-line ran 16dp past every card off the viewport edge, and the live row
/// bled to the raw screen edge. Reference this rather than re-typing 16.
const double kTimelineRowInset = 16.0;

/// Diameter of the now-line's terminus dot (the Google Calendar current-time
/// idiom). 10dp reads clearly against the 2dp rule without exceeding
/// `kNowLineHeight`'s 28dp band.
const double kNowDotDiameter = 10.0;

/// Where the now-line starts: [kTimelineRowInset] plus the reserved
/// [kGutterWidth] column. The rule and its dot both begin here — clear of the
/// gutter, which belongs to the hour axis, and clear of every card (see
/// [kNowDotClearance]).
const double kNowContentEdge = kTimelineRowInset + kGutterWidth;

/// Blank ground reserved between [kNowContentEdge] and where any card begins,
/// so the now-line's dot and the start of its rule land on empty background
/// rather than on top of a card.
///
/// **This is the fix for the defect that took four rounds of UAT.** The dot
/// used to sit exactly on the content edge, which was also the left edge of
/// an ordinary card — and the live row started further left still, so the dot
/// landed inside it, on its title. A line that *begins* inside a card reads as
/// a strike-through; the same line reads as a calendar now-line as soon as its
/// dot sits in open space to the left of everything. The rule crossing a card
/// after that is fine and expected (Google Calendar does it, and so does
/// Dan's own sketch of this fix) — it is only the origin that must be clear.
///
/// Consequence, and the reason both card types got narrower: every card is
/// pushed right by this, the live row included. Do not "reclaim" it by
/// zeroing one of these — the dot then lands back on a card.
const double kNowDotClearance = 4.0;

/// Left inset of the live row — the leftmost, widest card on the timeline.
/// Sits clear of the now-line's dot ([kNowContentEdge] + [kNowDotDiameter] +
/// [kNowDotClearance]) and nothing closer: this is the edge the dot is
/// measured against.
const double kLiveCardLeftInset =
    kNowContentEdge + kNowDotDiameter + kNowDotClearance;

/// How much wider the live row is than an ordinary row. This is all that is
/// left of "let now break the grid" (22-UI-SPEC.md) as a horizontal effect —
/// the live row can no longer reach further left than the now-line's dot, so
/// it earns its distinct silhouette from this offset plus its square corners,
/// content-driven height, and fill.
const double kLiveRowGridBreak = 12.0;

/// Left inset of an ordinary timeline card.
const double kCardLeftInset = kLiveCardLeftInset + kLiveRowGridBreak;

/// D-06's ~46dp time gutter, and explicitly NOT D-04's rejected vertical
/// rail: no connector line, no dot, no continuous stroke down the gutter.
/// Anyone adding one is re-opening a rejected sketch variant.
///
/// **Phase 26 (CAL-01, PD-5, `26-02-PLAN.md`):** this is now a PURE
/// 16dp-inset + [kGutterWidth]-reserved-blank-column wrapper. It no longer
/// renders any text in the gutter column — the column stays reserved (so
/// every row's content still starts at the same horizontal offset) but
/// shows nothing, because the persistent hour axis
/// (`lib/screens/today/widgets/hour_axis.dart`) now owns everything drawn
/// in that column. Do not "restore" a per-row time label here; a
/// duration-driven row (as small as a 5-minute break's ~27.5px slot) has no
/// room for one, and the hour axis is the one source of time reference in
/// that column now.
///
/// Owns a 16dp horizontal inset on the whole row (UAT G-04) — this matches
/// `_buildHeader`'s `EdgeInsets.fromLTRB(16, ...)` in `today_screen.dart` so
/// the gutter column lines up with the "Today" heading above it, instead of
/// sitting flush against the viewport edge. Before this inset existed, the
/// gutter was the one element on the screen at x=0 while everything else
/// (header, edge-state line, free time) inset by 16. Because the inset now
/// lives here, [child] and its siblings (`FreeTimeRow`, `LiveRowCard`,
/// `ChunkCard`) carry vertical margin/padding ONLY — adding a horizontal
/// inset back onto one of them would double it.
class TimelineRowTile extends StatelessWidget {
  const TimelineRowTile({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kTimelineRowInset),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: kGutterWidth, child: const SizedBox.shrink()),
          // Blank ground for the now-line's dot and the start of its rule, so
          // neither lands on this card. Kept as its own SizedBox rather than
          // folded into kGutterWidth: the gutter is the hour axis's column and
          // HourAxisLine sizes its label off that constant, so widening it
          // would drag the hour labels and the now-line's own origin right
          // too — the offset has to sit AFTER the gutter, not inside it.
          const SizedBox(width: kCardLeftInset - kNowContentEdge),
          Expanded(child: child),
        ],
      ),
    );
  }
}
