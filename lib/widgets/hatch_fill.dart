import 'package:flutter/material.dart';

/// Diagonal hatch behind a card's content — the visual mark of **time that is
/// not work**.
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
/// **Two tones, not one — his follow-up ruling, 2026-09-02:** *"the hatch
/// should only be during free time. breaks and short breaks should be
/// something different. can use a hatch maybe? but a different color."*
///
/// So the rule is no longer "diagonals mean not-work"; it is a three-way
/// vocabulary, which is what the day actually contains:
///
/// | Kind of time | Surface |
/// |---|---|
/// | Work | flat, `surfaceContainerLowest` — the solid brighter card |
/// | Free time | [freeTimeLines] — a NEUTRAL hatch: nothing is claimed here |
/// | Break | [breakLines] — a TINTED hatch: scheduled, but not work |
///
/// The first pass gave free time and breaks the identical neutral hatch,
/// which made the pair less separable than before — the exact question
/// `33-UAT.md` item 2 asks ("sitting next to a break card, are the two still
/// distinguishable?"). Colour is what separates them now; the diagonals are
/// what they still share, because both are still not-work.
///
/// Paints BEHIND [child]: [CustomPaint] runs `painter` before its child, so
/// the label and any Skip control sit on top of the hatch untouched. Both
/// call sites nest this inside a `Card(clipBehavior: Clip.antiAlias)`, which
/// is what confines the lines to the 12dp rounded rect.
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

  /// A break's hatch: the same diagonals in the scheme's **tertiary** accent,
  /// so a break reads as scheduled-but-not-work rather than as unclaimed time.
  ///
  /// **`secondary` was tried first and rejected on measurement, not taste.**
  /// In `ColorScheme.fromSeed`, `secondary` is the neutral-VARIANT hue — it
  /// lands within 2-4° of `onSurfaceVariant` at every mood seed this app uses
  /// (208° vs 210°, 160° vs 156°, 45° vs 43°) and differs only in saturation.
  /// At 20-ish percent alpha over `surfaceContainer` that is a different
  /// colour in the source and the same grey on the screen — the exact failure
  /// this ruling exists to fix. `tertiary` is rotated a real distance away
  /// (49°, 47°, 90° at those same seeds), which is what "a different color"
  /// means to an eye.
  ///
  /// `primary` was excluded on meaning rather than measurement: it is the
  /// work/action vocabulary (the default goal bar, `Complete`, the live row's
  /// fill). `error` is spoken for by the Skip rail sitting inside these very
  /// cards.
  ///
  /// **Known adjacency, stated rather than hidden:** a commitment work card
  /// fills with `tertiaryContainer` (`chunk_card.dart`). A break's tertiary
  /// hatch therefore shares a hue family with it. They are not confusable in
  /// practice — one is a solid fill on a card with a title and actions, the
  /// other is diagonal lines — but if a future phase leans harder on either,
  /// this is the collision to check.
  ///
  /// The alpha is well above [defaultOpacity] because `tertiary` is only
  /// mildly saturated (0.16-0.29 across the seeds); at 0.10 the hue rotation
  /// would not survive the blend. 0.28 was rendered first and measured on
  /// screen at rgb(202,213,214) — a real shift, but one that reads as extra
  /// *weight* rather than a different colour. **0.45 was chosen by looking at
  /// both**: free time's lines land at rgb(228,234,230) hue 140, a break's at
  /// rgb(180,195,199) hue 193, on the same card background. Those are the
  /// numbers to re-measure if this is ever retuned — not the alpha.
  static Color breakLines(ColorScheme scheme) =>
      scheme.tertiary.withValues(alpha: 0.45);

  final Widget child;

  /// Defaults to [freeTimeLines] — a scheme token, not a constant, because
  /// the whole app is re-seeded from the day's mood
  /// (`ThemeNotifier.currentTheme`) and a hardcoded grey would drift out of
  /// the palette every time the mood changes. Break call sites pass
  /// [breakLines].
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
