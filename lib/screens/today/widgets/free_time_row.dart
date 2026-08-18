import 'package:flutter/material.dart';

import '../../../utils/time_format.dart';

/// D-05 (LOCKED): free time is named, never collapsed to whitespace.
///
/// Renders no [Card] — just a quiet label behind a dotted left rule. Two
/// named constructors keep the leading-gap and mid-day-gap forms distinct so
/// a call site can't mix them up: [FreeTimeRow.until] for the day's first
/// activity ("Free until 8:00 AM"), [FreeTimeRow.gap] for a mid-day gap
/// ("Free · 1h 40m"). Both label strings are locked copy — do not reword.
///
/// **Phase 26 (CAL-01, `26-UI-SPEC.md` "Free / gap rows at proportional
/// height"):** the rule and label centre vertically within whatever height
/// the parent allocates, rather than top-aligning. Per D-02 an empty
/// stretch renders at its true duration-proportional height — a gap row can
/// be many hundreds of pixels tall — so a label pinned to the very top of
/// that void would be worse than one sitting where a scrolling eye lands.
///
/// **UAT 2026-08-18:** centring the label was not enough. D-05 says free time
/// is *named*, and it was — but a lone label adrift in 200+dp of background
/// still read as "a weird long stretch of white space", because nothing
/// marked where the free region began or ended. It now draws the same dashed
/// outline a break row uses, filling its whole allocated height, so the free
/// stretch is a bounded region on the timeline rather than an absence with a
/// caption. Same visual language as breaks, deliberately: both are "no chunk
/// scheduled here", and the label distinguishes them.
class FreeTimeRow extends StatelessWidget {
  const FreeTimeRow.until({super.key, required int untilMinutes})
    : _untilMinutes = untilMinutes,
      _durationMinutes = null;

  const FreeTimeRow.gap({super.key, required int durationMinutes})
    : _untilMinutes = null,
      _durationMinutes = durationMinutes;

  final int? _untilMinutes;
  final int? _durationMinutes;

  String _resolveLabel() {
    if (_untilMinutes != null) {
      return 'Free until ${formatMinutes(_untilMinutes)}';
    }
    return 'Free · ${formatDurationShort(_durationMinutes!)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Fills the parent's allocated height (the gap's true
    // duration-proportional extent) rather than sizing to the label, so the
    // outline marks where the free stretch starts and stops. `margin` matches
    // the break row's so a free region and a break line up on the timeline.
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      width: double.infinity,
      child: CustomPaint(
        painter: _DashedRegionPainter(
          color: theme.colorScheme.outlineVariant,
        ),
        child: Center(
          child: Text(
            _resolveLabel(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// File-private dashed rounded outline for [FreeTimeRow].
///
/// Visually matches `_DashedBorderPainter` in `chunk_card.dart` (same dash
/// rhythm and `outlineVariant` stroke) but is deliberately duplicated rather
/// than shared, following the `_PriorityChip` / `_ValenceBadge` precedent in
/// this codebase: that painter is file-private to the schedule widget and
/// carries break-specific stroke-width switching this row does not want.
class _DashedRegionPainter extends CustomPainter {
  const _DashedRegionPainter({required this.color});

  final Color color;

  static const double _radius = 8.0;
  static const double _dashWidth = 2.0;
  static const double _dashGap = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(_radius),
    );
    final path = Path()..addRRect(rrect);

    // Walk the outline and stamp dashes along it, so the rhythm stays even
    // around the corners instead of breaking at each edge.
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + _dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0.0, metric.length)),
          paint,
        );
        distance = next + _dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRegionPainter oldDelegate) =>
      oldDelegate.color != color;
}
