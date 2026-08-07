import 'package:flutter/material.dart';

import '../../../utils/time_format.dart';

/// D-05 (LOCKED): free time is named, never collapsed to whitespace.
///
/// Renders no [Card] — just a quiet label behind a dotted left rule. Two
/// named constructors keep the leading-gap and mid-day-gap forms distinct so
/// a call site can't mix them up: [FreeTimeRow.until] for the day's first
/// activity ("Free until 8:00 AM"), [FreeTimeRow.gap] for a mid-day gap
/// ("Free · 1h 40m"). Both label strings are locked copy — do not reword.
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
    final ruleColor = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 2,
            height: 16,
            child: CustomPaint(painter: _DottedRulePainter(color: ruleColor)),
          ),
          const SizedBox(width: 8),
          Text(
            _resolveLabel(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// File-private ~2dp-wide dotted vertical rule for [FreeTimeRow].
class _DottedRulePainter extends CustomPainter {
  const _DottedRulePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width
      ..strokeCap = StrokeCap.round;
    const dotSpacing = 4.0;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, y + 2),
        paint,
      );
      y += dotSpacing;
    }
  }

  @override
  bool shouldRepaint(covariant _DottedRulePainter oldDelegate) =>
      oldDelegate.color != color;
}
