---
phase: 06-desktop-and-web-polish
plan: 04
subsystem: app-shell
tags: [responsive-layout, navigation, theme-wiring, app-entry, go-router, material3]
requires:
  - "Plan 02 (06-02): ThemeNotifier in lib/providers/theme_notifier.dart"
  - "Plan 03 (06-03): setupDesktopWindow() conditional re-export in lib/platform/window_setup.dart"
  - "go_router (already in pubspec): StatefulNavigationShell / StatefulShellRoute"
provides:
  - "lib/widgets/responsive_shell.dart — public ResponsiveShell widget (LayoutBuilder, 720dp inclusive breakpoint)"
  - "lib/main.dart — setupDesktopWindow() call before runApp, ThemeNotifier construction + init, Consumer<ThemeNotifier> wrap, themeAnimationDuration: 500ms easeOutCubic"
  - "lib/router.dart — StatefulShellRoute builder uses ResponsiveShell"
affects:
  - "Plan 05 (next wave): hover affordances + breathing pulse — will read theme.currentTheme from the now-wired Consumer<ThemeNotifier>"
  - "Plan 06 (tests wave): responsive_layout_test.dart can now `import 'package:canopy/widgets/responsive_shell.dart'` and assert rail/bar swap at 480/720/1200 dp"
tech-stack:
  added: []  # no new pubspec dependencies — all glue between existing Plan 02 + Plan 03 artifacts
  patterns:
    - "LayoutBuilder branching at constraints.maxWidth >= 720 (inclusive D-11 threshold)"
    - "Consumer<ThemeNotifier> wrapping MaterialApp.router (narrows rebuild scope vs wrapping MultiProvider — T-06-04-1 mitigation)"
    - "MaterialApp.themeAnimationDuration + themeAnimationCurve (Material 3 idiom; supersedes AnimatedTheme — RESEARCH.md anti-pattern line 604-606)"
    - "Static-const record list of (icon, label) destinations — shared across rail + bar branches in ResponsiveShell"
key-files:
  created:
    - lib/widgets/responsive_shell.dart  # 102 lines
  modified:
    - lib/main.dart   # +29 / -10 net (105 lines)
    - lib/router.dart # +1 import / -27 deleted class / +1 builder swap (117 lines)
decisions:
  - "Made ResponsiveShell PUBLIC (no underscore) so Plan 06 widget tests can import it. PATTERNS.md landmine line 314 surfaced the public-vs-private choice; RESEARCH.md §Project Structure recommended public; plan ratified that recommendation."
  - "Used MaterialApp.themeAnimationDuration/Curve (NOT AnimatedTheme) per RESEARCH.md anti-pattern line 604-606. UI-SPEC §Mood Warming Transition lock (500ms easeOutCubic) is satisfied by both, but the MaterialApp idiom avoids the awkward 'wrap something with no child' problem."
  - "Wrapped MaterialApp.router in Consumer<ThemeNotifier> (NOT the entire MultiProvider). RESEARCH.md anti-pattern line 607: rebuilding the MultiProvider every 20-min tick would cause unnecessary rebuilds of GoalsNotifier/CommitmentsNotifier subtrees."
metrics:
  duration: ~10 minutes
  completed: 2026-05-13
  tasks_completed: 2
  files_created: 1
  files_modified: 2
  lines_added: ~110 (102 new + 29 main.dart + 1 router.dart import + 1 builder swap)
  lines_removed: ~37 (27-line _ScaffoldWithNavBar deleted + 10-line theme block replaced)
---

# Phase 6 Plan 04: Adaptive Shell + Theme/Window Wiring Summary

Wired Plan 02 (`ThemeNotifier`) and Plan 03 (`setupDesktopWindow`) into the running app at the integration seam, and built `ResponsiveShell` — the public `LayoutBuilder` widget that swaps between bottom `NavigationBar` (< 720dp) and side `NavigationRail` (>= 720dp). After this plan, AC-1 (two-column at >= 720dp), AC-3 (window minimum is active), AC-4 (Web URLs continue to work — route table untouched), and the AC-6 500ms `easeOutCubic` mood cross-fade are functionally in place; only the breathing pulse + hover affordances (Plan 05) and tests (Plan 06) remain.

## What Was Built

### New file

**`lib/widgets/responsive_shell.dart`** (102 lines)

Public `ResponsiveShell extends StatelessWidget` with a `StatefulNavigationShell navigationShell` field. `build` returns a `LayoutBuilder` that branches on `constraints.maxWidth >= 720`:

- **>= 720dp (D-11 inclusive):** `Scaffold(body: Row([NavigationRail, VerticalDivider, Expanded(navigationShell)]))`. `NavigationRail` uses `NavigationRailLabelType.all` (UI-SPEC always-show labels) and Material 3 defaults for width (80dp), surface (`surfaceContainer`), and selected indicator (`secondaryContainer`).
- **< 720dp:** `Scaffold(body: navigationShell, bottomNavigationBar: NavigationBar(...))` — 1-to-1 with the pre-Phase-6 `_ScaffoldWithNavBar`.

Both branches share a static-const list of `(icon, label)` records and a private `_goBranch(int)` that preserves `goBranch(index, initialLocation: index == navigationShell.currentIndex)` semantics.

### Modified files

**`lib/main.dart`** (105 lines)
- Imports `platform/window_setup.dart` and `providers/theme_notifier.dart`.
- `await setupDesktopWindow()` immediately after `WidgetsFlutterBinding.ensureInitialized()` — safe on every platform (web stub, mobile no-op, desktop real).
- Constructs `themeNotifier = ThemeNotifier()` and `await themeNotifier.init()` before `runApp`.
- `runApp(CanopyApp(... themeNotifier: themeNotifier))` — new required named param on `CanopyApp`.
- `MultiProvider.providers` now includes `ChangeNotifierProvider<ThemeNotifier>.value(value: themeNotifier)`.
- `MaterialApp.router` is now wrapped in `Consumer<ThemeNotifier>(builder: (context, theme, _) => MaterialApp.router(...))`. Inside: `theme: theme.currentTheme`, `themeAnimationDuration: const Duration(milliseconds: 500)`, `themeAnimationCurve: Curves.easeOutCubic`.
- The previous hardcoded `ColorScheme.fromSeed(seedColor: Color(0xFF3D6B4F))` line is removed (grep `0xFF3D6B4F` lib/main.dart returns nothing).

**`lib/router.dart`** (117 lines)
- Imports `widgets/responsive_shell.dart`.
- StatefulShellRoute builder now returns `ResponsiveShell(navigationShell: navigationShell)` instead of `_ScaffoldWithNavBar(navigationShell: navigationShell)`.
- The entire `_ScaffoldWithNavBar` class (formerly lines 117-143) is deleted; grep `_ScaffoldWithNavBar` lib/router.dart returns nothing.
- The route table, redirect logic, `refreshListenable: settingsNotifier`, and `rootNavigatorKey` export are all untouched — AC-4 (Web URL direct-load + redirect chain) preserved.

## Verification Results

| Check | Command | Result |
|-------|---------|--------|
| Static analysis | `flutter analyze` | 0 issues |
| Unit/widget tests | `flutter test` | 54/54 passed |
| Web build smoke (conditional-import stub branch compiles) | `flutter build web --no-tree-shake-icons` | exit 0 |
| Source: 720dp inclusive | `grep "constraints.maxWidth >= 720" lib/widgets/responsive_shell.dart` | present |
| Source: NavigationRail + NavigationBar both present | grep | both present |
| Source: `NavigationRailLabelType.all` | grep | present |
| Source: `await setupDesktopWindow` in main.dart | grep | present |
| Source: `Consumer<ThemeNotifier>` wraps MaterialApp.router | grep | present |
| Source: `themeAnimationDuration: const Duration(milliseconds: 500)` | grep | present (literal 500) |
| Source: `themeAnimationCurve: Curves.easeOutCubic` | grep | present |
| Source: `theme: theme.currentTheme` | grep | present |
| Source: old `0xFF3D6B4F` removed | `! grep "ColorScheme.fromSeed(seedColor: Color(0xFF3D6B4F))" lib/main.dart` | not found |
| Source: `ResponsiveShell(navigationShell: navigationShell)` in router | grep | present |
| Source: `_ScaffoldWithNavBar` deleted from router | `! grep "_ScaffoldWithNavBar" lib/router.dart` | not found |
| Source: ResponsiveShell file length >= 60 (`min_lines` artifact) | `wc -l` | 102 lines ✓ |

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | `2e8196c` | feat(06-04): add ResponsiveShell widget with 720dp NavigationRail/NavigationBar swap |
| 2 | `d53d63f` | feat(06-04): wire ThemeNotifier + setupDesktopWindow into main.dart and switch router to ResponsiveShell |

## Deviations from Plan

None — both tasks executed exactly as written. One minor formatting choice: `_goBranch` in `ResponsiveShell` is inlined to a single statement so the plan's verification assertion `grep "goBranch(index, initialLocation:"` matches without needing multi-line grep. Functionally identical to the multi-line `navigationShell.goBranch(index, initialLocation: ...)` it replaces from `_ScaffoldWithNavBar`.

## Threat Model Compliance

- **T-router-1 (EoP / direct URL load):** unaffected — the route table and the `redirect:` block in `createRouter` are byte-for-byte unchanged. Plan 06 adds the `router_redirect_test.dart` defense-in-depth.
- **T-platform-1 (T / desktop resize below 480x640):** accept disposition from Plan 03 — Plan 04 just wires the call into `main()`.
- **T-06-04-1 (DoS / ThemeNotifier rebuild storm):** **mitigated.** `Consumer<ThemeNotifier>` wraps only `MaterialApp.router`, so the 20-min ticker triggers `notifyListeners` → only `MaterialApp.router` rebuilds → Flutter's `themeAnimationDuration` lerps the ColorScheme. The MultiProvider node (and its `GoalsNotifier` / `CommitmentsNotifier` subtrees) are NOT rebuilt. Verified by source assertion `grep "Consumer<ThemeNotifier>" lib/main.dart`.
- **T-06-04-2 (Info disclosure / multi-user OS leak):** accept — Hive box lives in the app's local sandboxed storage; PROJECT.md establishes single-user-per-OS-account.

## Threat Flags

None — Plan 04 introduces no new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries. Pure UI wiring.

## Known Stubs

None.

## What's Next

- **Plan 05 (Wave 3):** hover affordances + breathing pulse for the curious pre-checkin state. Will read `theme.currentTheme` from the Consumer<ThemeNotifier> wired here.
- **Plan 06 (tests wave):** add `responsive_layout_test.dart` (asserts the rail/bar swap at 480/720/1200 dp using `tester.view.physicalSize`), `pumpWithMood` helper, and `router_redirect_test.dart` defense-in-depth.
- **Plan 07 (verification wave):** manual UAT smoke — `flutter run -d macos` + `flutter run -d chrome` to verify the 480x640 minimum, the 720dp rail/bar swap, and the 500ms warming cross-fade.

## Self-Check: PASSED

- `lib/widgets/responsive_shell.dart` — FOUND (102 lines)
- `lib/main.dart` (modified) — FOUND
- `lib/router.dart` (modified) — FOUND
- Commit `2e8196c` — FOUND in `git log --oneline`
- Commit `d53d63f` — FOUND in `git log --oneline`
- `flutter analyze` clean
- `flutter test` 54/54 pass
- `flutter build web --no-tree-shake-icons` exits 0
