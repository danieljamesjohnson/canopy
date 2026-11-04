import 'package:canopy/providers/theme_notifier.dart';
import 'package:flutter/material.dart';

/// The schedule's own, FIXED colour scheme (owner, 2026-11-04: the mood
/// "shouldn't affect the way the schedule looks, just the way the app
/// looks").
///
/// The app theme is re-seeded by the day's mood and drifts with the time of
/// day (`ThemeNotifier`). That is fine for the frame around the day, but it
/// meant every card on the timeline changed colour with the mood: a
/// hand-entered commitment was blue-green on one day and violet on another,
/// and on the blue-grey "Low day" it turned the same lavender as an imported
/// calendar meeting. A colour code is only a code if it holds still, so the
/// timeline is themed from one seed instead — the pre-check-in "curious"
/// seed, unmodulated — and only the brightness follows the app.
///
/// The mood's look is a separate, later piece of work; this keeps it out of
/// the schedule until then.
ColorScheme scheduleColorScheme(Brightness brightness) =>
    ColorScheme.fromSeed(
      seedColor: ThemeNotifier.curiousSeed,
      brightness: brightness,
    );

/// [app] with its colour scheme replaced by [scheduleColorScheme]. Wrap the
/// timeline in a `Theme` with this; everything outside it keeps the mood.
ThemeData scheduleTheme(ThemeData app) =>
    app.copyWith(colorScheme: scheduleColorScheme(app.brightness));
