import 'package:flutter/material.dart';

/// How a [PresetChipGrid] treats a tap on an already-claimed preset.
///
/// - `createOnly` — goals and onboarding. A `Goal` carries type, budget and
///   priority and has real scheduling consequences (Ruling 6 in STATE.md
///   already shows the owner is sensitive to a control silently archiving
///   something). So once a preset matches an existing active goal, the chip
///   is hidden entirely — never shown selected, never disabled-but-visible,
///   and no tap can remove the underlying goal. The only way to remove one is
///   the existing, deliberate `Archive goal` control inside the form.
/// - `toggle` — restoratives. A `RestorativeItem` has no attributes to lose,
///   so this is its shipped, unchanged behaviour: `selected: true`, and
///   tapping again deletes it, no confirmation.
enum PresetChipMode { createOnly, toggle }

/// One `Wrap` of `FilterChip`s shared by three surfaces (Goals screen,
/// onboarding's goals beat, and restoratives) so the "pick from these common
/// options" idiom has exactly one implementation rather than three private
/// copies (34-CONTEXT.md, "Claude's discretion" + the reuse-and-extract
/// framing of 34-PATTERNS.md).
///
/// Every chip carries BOTH an emoji avatar and its word — never a bare glyph
/// (the same rule `_QuickPickSection` already enforced, UI-SPEC item 30).
class PresetChipGrid extends StatelessWidget {
  const PresetChipGrid({
    super.key,
    required this.presets,
    required this.existingNames,
    required this.mode,
    required this.onCreate,
    this.onRemove,
    this.heading,
    this.alignment = WrapAlignment.start,
  }) : assert(
         onRemove != null || mode != PresetChipMode.toggle,
         'onRemove is required when mode is PresetChipMode.toggle',
       );

  final List<(String name, String emoji)> presets;
  final Iterable<String> existingNames;
  final PresetChipMode mode;
  final void Function(String name, String emoji) onCreate;
  final void Function(String name)? onRemove;

  /// Rendered above the grid when non-null, e.g. 'Common'.
  final String? heading;

  final WrapAlignment alignment;

  /// The single definition of "is this preset already claimed" — trim and
  /// lowercase both sides, generalised from `_matchFor`/`_suggestionsFor` so
  /// it doesn't couple to `RestorativeItem` or `Goal` specifically. Callers
  /// use this static to decide whether the section renders at all, so the
  /// rule has exactly one definition.
  static List<(String name, String emoji)> unclaimed(
    List<(String, String)> presets,
    Iterable<String> existingNames,
  ) {
    final have = existingNames.map((n) => n.trim().toLowerCase()).toSet();
    return [
      for (final p in presets)
        if (!have.contains(p.$1.trim().toLowerCase())) p,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final visible = mode == PresetChipMode.createOnly
        ? unclaimed(presets, existingNames)
        : presets;

    if (visible.isEmpty) return const SizedBox.shrink();

    final claimed = existingNames.map((n) => n.trim().toLowerCase()).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (heading != null) Text(heading!, style: Theme.of(context).textTheme.titleSmall),
        if (heading != null) const SizedBox(height: 8),
        Wrap(
          alignment: alignment,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (name, emoji) in visible)
              _buildChip(name, emoji, claimed),
          ],
        ),
      ],
    );
  }

  Widget _buildChip(String name, String emoji, Set<String> claimed) {
    final isClaimed =
        mode == PresetChipMode.toggle &&
        claimed.contains(name.trim().toLowerCase());
    return FilterChip(
      avatar: Text(emoji),
      label: Text(name),
      selected: isClaimed,
      onSelected: (selected) {
        if (selected) {
          onCreate(name, emoji);
        } else {
          onRemove?.call(name);
        }
      },
    );
  }
}
