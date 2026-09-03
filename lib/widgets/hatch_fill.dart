import 'package:flutter/material.dart';

/// Diagonal hatch behind a card's content — **the mark of free time, and of
/// nothing else.**
///
/// **Phase 33 gap closure (owner's verdict 2026-09-02):** *"i wanted the
/// breaks to have the diagonal lines in them like the sketch."* Sketch 003
/// (`.planning/sketches/003-the-unlabelled-circle/index.html:131`) gave the
/// filled free-time block a `repeating-linear-gradient(135deg, …)`; the
/// Flutter row copied the break card's `color`/`shape`/`clipBehavior`
/// verbatim and dropped the hatch, and nobody caught it because the sketch's
/// own hatch is 2.2% black — effectively invisible on a laptop. The owner's
/// annotation draws it boldly, so [defaultOpacity] is pitched well above the
/// sketch's value rather than matching it literally.
///
/// The day's three kinds of time now read three different ways:
///
/// | Kind of time | Surface |
/// |---|---|
/// | Work | flat `surfaceContainerLowest` — the solid brighter card |
/// | Free time | `surfaceContainer` + **this hatch** — nothing has claimed it |
/// | Break | flat, tinted `secondaryContainer` (`chunk_card.dart`) |
///
/// **It took three passes to get here, and the retired attempts are the
/// reason this doc is long.** Pass 1 hatched free time AND breaks identically
/// — which made the pair *less* separable than before, the exact question
/// `33-UAT.md` item 2 asks out loud. Pass 2 kept both hatched and gave the
/// break its own hue (a `breakLines` tone, `tertiary` at 0.45; measured on
/// screen at rgb(180,195,199) against free time's rgb(228,234,230)). The
/// owner's verdict on that was *"i still feel like free time and break look
/// too similar"* — so `breakLines` is **deleted, not left unreferenced**, per
/// this codebase's own retire-deliberately charter.
///
/// **The lesson worth keeping: two cards of the same colour with different
/// stripes are a spot-the-difference puzzle.** Texture is a weak channel for
/// "these are different kinds of thing"; fill is a strong one. Do not answer
/// a future "these look alike" report by re-tuning a hatch.
///
/// Paints BEHIND [child]: [CustomPaint] runs `painter` before its child, so
/// the label sits on top of the hatch untouched. The one call site nests this
/// inside a `Card(clipBehavior: Clip.antiAlias)`, which is what confines the
/// lines to the 12dp rounded rect.
class HatchFill extends StatelessWidget {
  const HatchFill({
    super.key,
    required this.child,
    this.lineColor,
    this.spacing = defaultSpacing,
    this.strokeWidth = defaultStrokeWidth,
  });

  /// Perpendicular gap between adjacent lines, in logical pixels.
  static const double defaultSpacing = 12.0;

  static const double defaultStrokeWidth = 1.0;

  /// Alpha applied to [ColorScheme.onSurfaceVariant] when [lineColor] is not
  /// given. The sketch used 0.022 of black; that reads as a clean surface at
  /// arm's length on a phone, which is exactly the gap this widget exists to
  /// close.
  static const double defaultOpacity = 0.10;

  /// Free time's hatch: neutral, drawn from the same token as its label.
  /// Free time is the stretch nothing has claimed, so it gets no hue.
  static Color freeTimeLines(ColorScheme scheme) =>
      scheme.onSurfaceVariant.withValues(alpha: defaultOpacity);

  // `breakLines` lived here (Phase 33, 2026-09-02 → deleted 2026-09-03): the
  // same diagonals in `tertiary` at 0.45 alpha, for the one pass where breaks
  // were hatched too. Deleted rather than left unreferenced now that a break
  // is a tinted card — see this class's own doc comment for the measurements
  // and the reason, and `chunk_card.dart`'s `_breakFill` for what replaced
  // it. One finding from it is worth keeping even though the code is gone:
  // `secondary` is the neutral-VARIANT hue in `ColorScheme.fromSeed`, within
  // 2-4° of `onSurfaceVariant` at every mood seed here, so it is never a
  // usable "different colour" for a LINE. As a CONTAINER it is fine — which
  // is exactly where it ended up.

  final Widget child;

  /// Defaults to [freeTimeLines] — a scheme token, not a constant, because
  /// the whole app is re-seeded from the day's mood
  /// (`ThemeNotifier.currentTheme`) and a hardcoded grey would drift out of
  /// the palette every time the mood changes. Left configurable rather than
  /// hardcoded because the painter is general; the app has one call site.
  final Color? lineColor;

  final double spacing;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomPaint(
      painter: HatchPainter(
        color: lineColor ?? freeTimeLines(theme.colorScheme),
        spacing: spacing,
        strokeWidth: strokeWidth,
      ),
      child: child,
    );
  }
}

/// Computes the hatch's line segments for a box of [size].
///
/// Pure and public **so the geometry can be asserted directly** rather than
/// through a widget test that can only prove a [CustomPaint] exists. Lines
/// run top-left → bottom-right at 45°, matching the direction drawn on the
/// owner's annotation (`shots/07-owner-annotation-2026-09-02.png`).
///
/// Each line satisfies `x - y = c`. Stepping `c` by `spacing * sqrt(2)` makes
/// the PERPENDICULAR distance between neighbours exactly [spacing] — stepping
/// it by `spacing` instead would silently draw them ~1.41x closer than asked,
/// which is the kind of error a "does it look hatched" test cannot catch.
List<(Offset, Offset)> hatchSegments(Size size, double spacing) {
  if (spacing <= 0 || size.isEmpty) return const [];
  // Every intercept whose line crosses the box: the top-left corner sits at
  // c = 0 and the bottom-right at c = width - height, so c ranges over
  // [-height, width].
  final step = spacing * 1.4142135623730951;
  final segments = <(Offset, Offset)>[];
  for (var c = -size.height; c <= size.width; c += step) {
    segments.add((Offset(c, 0), Offset(c + size.height, size.height)));
  }
  return segments;
}

/// Paints [hatchSegments]. Separate from [HatchFill] and public for the same
/// reason the geometry is: so a test can drive it without a widget tree.
class HatchPainter extends CustomPainter {
  const HatchPainter({
    required this.color,
    this.spacing = HatchFill.defaultSpacing,
    this.strokeWidth = HatchFill.defaultStrokeWidth,
  });

  final Color color;
  final double spacing;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    // The lines are computed past both edges of the box (see hatchSegments),
    // so clip rather than trusting the parent Card's own clip — this painter
    // is usable outside a clipping ancestor.
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final (start, end) in hatchSegments(size, spacing)) {
      canvas.drawLine(start, end, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant HatchPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.spacing != spacing ||
      oldDelegate.strokeWidth != strokeWidth;
}
