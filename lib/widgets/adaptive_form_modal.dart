import 'package:flutter/material.dart';

/// Shows a form modal that adapts to the available viewport width.
///
/// At >= 720dp: opens a centered Material [Dialog] with [clipBehavior: Clip.antiAlias],
/// constrained to max 560dp wide and 80% of screen height. Interior is wrapped in
/// [SingleChildScrollView] with a fresh [ScrollController] injected into [builder].
/// [barrierDismissible] is true — tapping outside closes the dialog without saving.
///
/// At < 720dp: opens a [showModalBottomSheet] with [isScrollControlled: true] and
/// [useSafeArea: true], using [DraggableScrollableSheet] with the standard snapping
/// configuration. The sheet's [ScrollController] is injected into [builder].
///
/// The 720dp breakpoint matches [ResponsiveShell] (Phase 6 Decision D-11).
/// No new constant is introduced — the value is inlined to stay consistent with
/// responsive_shell.dart's existing inline usage.
Future<void> showAdaptiveFormModal({
  required BuildContext context,
  required Widget Function(ScrollController scrollController) builder,
}) async {
  final width = MediaQuery.of(context).size.width;
  final isDesktop = width >= 720;

  if (isDesktop) {
    // Capture screenHeight BEFORE entering showDialog — reading it inside the
    // Dialog builder uses the dialog's own layout constraints, not the screen.
    // (18-RESEARCH §Pitfall 1)
    final screenHeight = MediaQuery.of(context).size.height;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final scrollController = ScrollController();
        return Dialog(
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: screenHeight * 0.8,
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              child: builder(scrollController),
            ),
          ),
        );
      },
    );
  } else {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 1.0,
        expand: false,
        snap: true,
        snapSizes: const [0.6, 1.0],
        builder: (ctx, scrollController) => builder(scrollController),
      ),
    );
  }
}
