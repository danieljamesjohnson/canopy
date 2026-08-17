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
/// 52.0 = the real-browser ~40px worst case ("12:45p", the compact
/// time-format's 6-character maximum) plus ~12dp slack for larger
/// text-scale settings.
/// Verified visually in the served debug build, not just in tests.
const double kGutterWidth = 52.0;

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
          Expanded(child: child),
        ],
      ),
    );
  }
}
