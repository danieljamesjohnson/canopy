import 'package:flutter/material.dart';

import '../../../utils/time_format.dart';

/// Width of the time gutter reserved on the left of every timeline row
/// (D-06's ~46px time column).
///
/// Bumped from 46.0 to 75.0 (UAT G-04) after a widest-label fit test proved
/// "12:45p" — `formatMinutesCompact`'s 6-character worst case — does not fit
/// 46dp under `flutter test`. Caveat recorded here so nobody "corrects" this
/// back down without re-reading it: `flutter test` renders text with a
/// placeholder font that draws every glyph as a fixed `fontSize`-wide box
/// (confirmed by probing single-character widths — '1', 'i', 'W', ':' and
/// 'p' all measured exactly 12.0px at fontSize 12, i.e. real proportional
/// Roboto metrics are NOT loaded in this harness), so the measured fit bound
/// is a conservative, test-harness-driven upper limit, not a real-device
/// measurement — a real device likely needs meaningfully less. 75.0 errs
/// wide on purpose (never risk re-introducing the clip this gap closes);
/// revisit with a real-browser check (per this project's CLAUDE.md) if the
/// wider gutter reads as too roomy in practice.
const double kGutterWidth = 75.0;

/// D-06's ~46dp time gutter, and explicitly NOT D-04's rejected vertical
/// rail: no connector line, no dot, no continuous stroke down the gutter.
/// Anyone adding one is re-opening a rejected sketch variant.
///
/// Reserves a fixed-width left column holding the row's compact start time
/// (or nothing, when [startMinutes] is null — the gutter stays reserved,
/// not collapsed, so every row's content still starts at the same
/// horizontal offset), then lays out [child] beside it.
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
  const TimelineRowTile({
    super.key,
    required this.startMinutes,
    required this.child,
  });

  /// Minutes-from-midnight for the row's start time. Null renders no time
  /// text but still reserves the gutter width.
  final int? startMinutes;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Tabular figures deliver the column alignment the UI-SPEC's "monospace"
    // is actually buying — no monospace font asset ships with the app, and
    // adding one would be a new dependency for a single text style. The
    // platform monospace family is used where it exists via the fallback
    // list; tabularFigures does the real work everywhere else.
    final gutterStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
      fontFamilyFallback: const ['monospace', 'RobotoMono', 'Courier New'],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: kGutterWidth,
            child: startMinutes != null
                ? Text(formatMinutesCompact(startMinutes!), style: gutterStyle)
                : const SizedBox.shrink(),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
