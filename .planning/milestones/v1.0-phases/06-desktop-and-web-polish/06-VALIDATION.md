---
phase: 6
slug: desktop-and-web-polish
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-12
approved: 2026-05-14
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: 06-RESEARCH.md `## Validation Architecture` section.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (bundled with Flutter SDK ^3.10.3) |
| **Config file** | none — `flutter_test` reads `test/` by convention |
| **Quick run command** | `flutter test test/{single file}` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~5–10 seconds (full suite, project size) |
| **Web URL smoke** | `flutter run -d chrome` (manual) |
| **Desktop window smoke** | `flutter run -d macos` (manual; macOS is sole shipping desktop platform) |

---

## Sampling Rate

- **After every task commit:** Run `flutter analyze && flutter test test/{relevant single file}`
- **After every plan wave:** Run `flutter test` (full suite, ~5–10s)
- **Before `/gsd-verify-work`:** Full suite must be green + manual checklist (AC-3 macOS resize, AC-4 web URL navigation, AC-6 mood tap visual)
- **Max feedback latency:** ~10s (quick), ~10s (full)

---

## Per-Task Verification Map

Detailed per-task map will be populated by the planner alongside PLAN.md generation. Below is the AC-level coverage table from RESEARCH.md `## Validation Architecture` (the planner will refine into per-task rows once tasks are enumerated):

| AC | Behavior | Test Type | Automated Command | File Exists |
|----|----------|-----------|-------------------|-------------|
| AC-1 | LayoutBuilder swaps NavigationBar → NavigationRail at 720dp boundary | widget | `flutter test test/screens/responsive_layout_test.dart` | ❌ W0 |
| AC-1 | Two-column rendering does not overflow at 1280×800 | widget | (same file — assert no `OverflowError`) | ❌ W0 |
| AC-2 | `MouseRegion.onEnter` on ChunkCard reveals checkbox + skip (opacity → 1) | widget | `flutter test test/screens/chunk_card_hover_test.dart` | ❌ W0 |
| AC-2 | `MouseRegion.onExit` hides revealed icons (opacity → 0) | widget | (same file) | ❌ W0 |
| AC-2 | Touch drag on `Dismissible`-wrapped `ChunkCard` swipes-completes without hover icons | widget | (same file — `tester.drag` for cross-input parity) | ❌ W0 |
| AC-2 | `InkWell.onHover` on GoalCard reveals edit + archive icons | widget | `flutter test test/screens/goal_card_hover_test.dart` | ❌ W0 |
| AC-3 | `setupDesktopWindow()` completes without throwing on the test host (early-return path on Android/iOS test platform) | unit | `flutter test test/platform/window_setup_test.dart` | ❌ W0 |
| AC-3 | `window_manager.setMinimumSize(480, 640)` call asserted | manual | covered by the macOS UAT row below (Plan 07 Task 1) — verified by visually resizing the window narrower than 480px on macOS | manual |
| AC-3 | Conditional import compiles on web (stub branch only) | smoke | `flutter build web --no-tree-shake-icons` (no `dart:io` errors) | ❌ W0 |
| AC-3 | Window resize refuses below 480px on macOS | manual | `flutter run -d macos`, drag window narrower than 480px — snaps back | manual |
| AC-4 | Direct URL `/schedule` loads ScheduleScreen on Web | manual | `flutter run -d chrome` + URL bar | manual |
| AC-4 | Direct URL `/goals` loads GoalsScreen on Web | manual | (same) | manual |
| AC-4 | Direct URL `/review` loads QuarterlyReviewScreen on Web | manual | (same) | manual |
| AC-4 | go_router redirect respects onboardingComplete on direct URL load | widget | `flutter test test/screens/router_redirect_test.dart` | ❌ W0 |
| AC-5 | Existing `quarterly_review_test.dart` migrates to `pumpWithMood`, passes unchanged | widget | `flutter test test/screens/quarterly_review_test.dart` | ✅ exists; helper migration in W0 |
| AC-5 | LayoutBuilder breakpoint tests at 480/720/1200dp pass | widget | `flutter test test/screens/responsive_layout_test.dart` | ❌ W0 |
| AC-6 | Mood seed change in `ThemeNotifier` triggers `notifyListeners` | unit | `flutter test test/providers/theme_notifier_test.dart` | ❌ W0 |
| AC-6 | `_modulateHsl` peaks at noon | unit | (same file) | ❌ W0 |
| AC-6 | `_modulateHsl` troughs at midnight | unit | (same file) | ❌ W0 |
| AC-6 | Ticker cancels on `AppLifecycleState.paused`, restarts on `.resumed` | unit | (same file) | ❌ W0 |
| AC-6 | Curious seed (`#7A8FA3`) used when `_moodSeed == null` | unit | (same file) | ❌ W0 |
| AC-6 | Mood tap → ColorScheme change visible within 600ms | manual | `flutter run -d macos`, observe warming transition (UI-SPEC locks 500ms) | manual |
| Pulse | Breathing pulse animates when no mood set | widget | `flutter test test/screens/home_screen_breathing_pulse_test.dart` | ❌ W0 |
| Pulse | Pulse stops when mood is set | widget | (same file) | ❌ W0 |
| Pulse | Pulse respects `MediaQuery.disableAnimations` | widget | (same file) | ❌ W0 |
| Drag | Drag handle hidden on mobile (Android, iOS) | widget | `flutter test test/screens/goal_card_drag_handle_test.dart` | ❌ W0 |
| Drag | Drag handle visible at 0.6 opacity on desktop | widget | (same file with platform override) | ❌ W0 |

*Status legend: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Phase 6 introduces substantial new test infrastructure (10 new files). Wave 0 is non-trivial — call it out in PLAN.md.

- [ ] `test/test_helpers/mood_pump.dart` — `pumpWithMood(mood: 3)` fixture used by all migrated widget tests
- [ ] `test/test_helpers/viewport.dart` — `setViewport(tester, size)` with auto `addTearDown(tester.view.reset)`
- [ ] `test/providers/theme_notifier_test.dart` — HSL modulation, ticker lifecycle, curious seed default, persistence
- [ ] `test/screens/responsive_layout_test.dart` — LayoutBuilder breakpoint tests at 480/720/1200dp
- [ ] `test/screens/chunk_card_hover_test.dart` — MouseRegion onEnter/onExit + Dismissible non-conflict
- [ ] `test/screens/goal_card_hover_test.dart` — InkWell.onHover + revealed icons
- [ ] `test/screens/goal_card_drag_handle_test.dart` — platform-gated drag handle visibility
- [ ] `test/screens/home_screen_breathing_pulse_test.dart` — pre-check-in pulse + disableAnimations
- [ ] `test/platform/window_setup_test.dart` — stub vs io branch behaviour; mock WindowManager surface for io path
- [ ] `test/screens/router_redirect_test.dart` — go_router redirect on direct URL load

Existing test inventory: `widget_test.dart` placeholder, `quarterly_review_test.dart`, three service tests, one repository test.

---

## Manual-Only Verifications

| Behavior | AC | Why Manual | Test Instructions |
|----------|----|------------|-------------------|
| Window resize refuses below 480px on macOS | AC-3 | Native window-manager interaction not exercisable in widget tests | `flutter run -d macos`, drag any window edge to narrow below 480px logical — window snaps back |
| Direct URL navigation on Web | AC-4 | Browser URL bar interaction not exercisable in `flutter_test` | `flutter run -d chrome`, type `/schedule`, `/goals`, `/review` in URL bar — each loads correct screen without 404 |
| Mood tap warming transition timing | AC-6 | Visual perception (≤600ms must feel smooth) is not assertable from animation duration alone | `flutter run -d macos`, tap each of the 5 moods at check-in, confirm the warming transition completes within 600ms and does not "flash" |
| Two-column layout at 1280×800 on desktop | AC-1 | Native window sizing + visual rendering check | `flutter run -d macos`, resize window to 1280×800, confirm nav rail + content render with no overflow errors in console |
| Breathing pulse perception on pre-check-in HomeScreen | Pulse | Slow ~2400ms loop perceptibility — needs human eyes | `flutter run -d macos` on fresh install (or with mood cleared), confirm CTA pulses subtly with shadow expand/contract |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies (populated by planner)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (10 new files listed above)
- [x] No watch-mode flags (Flutter test uses single-pass by default)
- [x] Feedback latency < 10s for quick command, < 10s for full suite
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-05-14

## Manual UAT Signoff (Plan 06-07 Task 1)

- **AC-3 macOS window resize (480×640 floor):** PASS — window refused to shrink below floor. User observation: state appeared to reset across launches; deemed acceptable (likely a mix of the daily curious-reset behavior in `ThemeNotifier` and Flutter debug-mode storage volatility, not a Phase 6 regression).
- **AC-4 Web URL deep links + onboarding redirect:** PASS — `/schedule`, `/goals`, `/review` each load the correct screen on `flutter run -d chrome`; the redirect-to-`/onboarding` behavior works pre-onboarding. Same state-reset observation noted (Flutter debug-mode Chrome spawns with a temp `--user-data-dir` by default, wiping IndexedDB/localStorage on relaunch).
- **AC-6 mood tap warming transition:** PASS — color settles smoothly within the 500ms easeOutCubic curve locked by UI-SPEC; amber mood-5 (#E8C547) remained legible on AppBar; breathing pulse visible on pre-check-in CTA.
- **W-5 light-mode-only scope:** ACK — dark theme deferred to a future phase, no `darkTheme:` slot added to MaterialApp.router.

Outstanding observation (non-blocking, follow-up): user noticed app state reset between launches during manual UAT. Likely Flutter debug-mode artifact + intended daily curious-reset; if it persists on release builds with a stable mood set the same day, file a debug session.
