// ResponsiveShell — adaptive shell for go_router's StatefulShellRoute that swaps
// between a bottom NavigationBar (< 720dp) and a side NavigationRail (>= 720dp).
//
// Phase 6 Decisions:
//   - D-11 (LOCK): 720dp inclusive breakpoint. `constraints.maxWidth >= 720`
//     triggers the rail; below 720dp the existing bottom NavigationBar is shown.
//   - UI-SPEC §Two-Column Adaptive Layout: at >= 720dp the layout is
//     [NavigationRail | VerticalDivider | Expanded(navigationShell)] with
//     Material 3 defaults (80dp rail width, surfaceContainer surface,
//     secondaryContainer selected indicator).
//   - UI-SPEC §Two-Column Adaptive Layout: NavigationRail uses
//     `NavigationRailLabelType.all` so labels are always visible (the mood
//     warming theme should always read on text — never icon-only).
//
// Phase 22 (D-09, UNIFY-02): the Phase 6 UI-SPEC's "four destinations locked"
// icon-library note is SUPERSEDED. Home and Schedule merged into one Today
// destination — see 22-UI-SPEC.md §Navigation contract (UNIFY-02) for the
// current three-destination contract (Today / Goals / Settings). Recorded
// here explicitly per D-09 rather than silently violating the old lock.
//
// This widget is intentionally PUBLIC (no leading underscore) so that
// `test/screens/responsive_layout_test.dart` (Plan 06) can import it directly
// and assert the rail-vs-bar swap at 480 / 720 / 1200 dp widths.
//
// State preservation: `StatefulNavigationShell` is the same widget instance in
// both branches; go_router's StatefulShellRoute keeps each branch's navigator
// tree alive regardless of which Scaffold parents the shell. See RESEARCH.md
// Pattern 4 for the verification reference.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Adaptive shell scaffold for the three primary branches (Today / Goals /
/// Settings). Swaps between a bottom [NavigationBar] (< 720dp)
/// and a side [NavigationRail] (>= 720dp) via [LayoutBuilder].
///
/// Used by `lib/router.dart` as the builder for
/// `StatefulShellRoute.indexedStack`. The 720dp threshold is locked by
/// Phase 6 Decision D-11; the three-destination contract is
/// 22-UI-SPEC.md §Navigation contract (UNIFY-02), which supersedes the
/// earlier four-destination UI-SPEC lock (D-09).
class ResponsiveShell extends StatelessWidget {
  const ResponsiveShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// The three primary destinations. Order matches the branch order in
  /// `createRouter` (Today=0, Goals=1, Settings=2). Superseded from the
  /// original four-destination UI-SPEC icon-library lock by Phase 22's
  /// merge — see 22-UI-SPEC.md §Navigation contract (UNIFY-02, D-09).
  static const List<({IconData icon, String label})> _destinations = [
    (icon: Icons.today_outlined, label: 'Today'),
    (icon: Icons.flag_outlined, label: 'Goals'),
    (icon: Icons.settings_outlined, label: 'Settings'),
  ];

  void _goBranch(int index) {
    // Preserves existing router.dart semantics (the goBranch initialLocation
    // flag re-pops to the branch's root if the user taps the active tab).
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // D-11 inclusive threshold: 720dp itself shows the rail.
        if (constraints.maxWidth >= 720) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: _goBranch,
                  // UI-SPEC: always-show labels so mood text stays readable.
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final d in _destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        label: Text(d.label),
                      ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: navigationShell),
              ],
            ),
          );
        }
        // Below 720dp: bottom NavigationBar (matches the pre-Phase-6 layout
        // 1-to-1 — same four destinations, same goBranch semantics).
        return Scaffold(
          body: navigationShell,
          bottomNavigationBar: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _goBranch,
            destinations: [
              for (final d in _destinations)
                NavigationDestination(icon: Icon(d.icon), label: d.label),
            ],
          ),
        );
      },
    );
  }
}
