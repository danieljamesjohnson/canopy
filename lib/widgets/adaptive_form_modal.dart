import 'package:flutter/material.dart';

/// Shows a form modal that adapts to the available viewport width.
///
/// At >= 720dp: opens a centered Material [Dialog] with [clipBehavior: Clip.antiAlias],
/// constrained to max 560dp wide and 80% of screen height. The [ScrollController]
/// is owned by [_DialogForm] and properly disposed when the dialog closes.
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
      builder: (ctx) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: _DialogForm(
          builder: builder,
          maxHeight: screenHeight * 0.8,
        ),
      ),
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

/// Private StatefulWidget that owns and disposes the [ScrollController] used
/// by dialog-mode forms (CR-01 / WR-01 fix).
///
/// Rationale:
/// - The outer [SingleChildScrollView] that previously wrapped [builder] output
///   caused nested scrolling with the form's own [SingleChildScrollView] (CR-01).
/// - Creating the controller inside the [showDialog] builder closure leaked it
///   because there was no corresponding [dispose] (WR-01).
///
/// This widget provides proper lifecycle management: the controller is created
/// once in [initState] and disposed in [dispose]. The [ConstrainedBox] that
/// previously lived in the dialog builder now lives here, keeping the 560dp /
/// 80%-height constraints in one place.
class _DialogForm extends StatefulWidget {
  const _DialogForm({required this.builder, required this.maxHeight});

  final Widget Function(ScrollController) builder;
  final double maxHeight;

  @override
  State<_DialogForm> createState() => _DialogFormState();
}

class _DialogFormState extends State<_DialogForm> {
  late final ScrollController _sc = ScrollController();

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 560, maxHeight: widget.maxHeight),
      // No SingleChildScrollView here — the builder (GoalFormSheet,
      // CommitmentFormSheet) already provides a scrollable root.
      child: widget.builder(_sc),
    );
  }
}
