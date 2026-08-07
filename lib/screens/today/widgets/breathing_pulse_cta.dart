import 'package:flutter/material.dart';

/// A subtle breathing-pulse decoration around a CTA. Drives a 2400ms easeInOut
/// AnimationController that fades a [BoxShadow] from 8px to 16px blur (UI-SPEC
/// §Breathing Pulse, D-08). Only animates when [enabled] is true AND when
/// MediaQuery/PlatformDispatcher reduced-motion is NOT requested.
///
/// Extracted as a public top-level widget so Plan 06 Task 3 can pump it in
/// isolation without the old Home screen's full provider tree (W-3
/// resolution). Moved out of home_screen.dart into its own file in Phase 22
/// Plan 03 so it survives home_screen.dart's deletion (Phase 22 Plan 04) —
/// the unified Today screen's empty state keeps using it.
class BreathingPulseCta extends StatefulWidget {
  const BreathingPulseCta({
    super.key,
    required this.enabled,
    this.onPressed,
    required this.child,
  });

  /// True when the pulse should animate (pre-check-in state per
  /// `ThemeNotifier.isPreCheckin`). False settles the controller at the
  /// midpoint (no animation).
  final bool enabled;

  /// Optional outer-tap callback. When non-null, a [GestureDetector] wraps
  /// the animated container so that tapping anywhere in the glow ring also
  /// fires the callback. Callers should still attach the callback to [child]
  /// directly to keep the inner tap target valid on all platforms.
  final VoidCallback? onPressed;

  /// The CTA being decorated (typically an [OutlinedButton]).
  final Widget child;

  @override
  State<BreathingPulseCta> createState() => _BreathingPulseCtaState();
}

class _BreathingPulseCtaState extends State<BreathingPulseCta>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;

  bool get _animationsDisabled => WidgetsBinding
      .instance
      .platformDispatcher
      .accessibilityFeatures
      .disableAnimations;

  @override
  void initState() {
    super.initState();
    // WR-01: register as a binding observer so a mid-session toggle of
    // the OS "reduce motion" / accessibility-disable-animations setting
    // is reflected in the controller's run state without waiting for a
    // parent rebuild with a different `enabled` value.
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _applyAnimationState();
  }

  @override
  void didUpdateWidget(covariant BreathingPulseCta oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      _applyAnimationState();
    }
  }

  @override
  void didChangeAccessibilityFeatures() {
    // Re-evaluate the run state in lockstep with the OS toggle.
    _applyAnimationState();
  }

  /// Single source of truth for the controller's run state.
  ///
  /// UI-SPEC §Breathing Pulse — when disabled OR reduced-motion is on,
  /// render the pulse at midpoint (blur 12px) and do not animate.
  void _applyAnimationState() {
    if (widget.enabled && !_animationsDisabled) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0.5;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      builder: (context, child) {
        final t = _controller.value;
        final blur = 8.0 + 8.0 * t;
        return GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.25),
                  blurRadius: blur,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
