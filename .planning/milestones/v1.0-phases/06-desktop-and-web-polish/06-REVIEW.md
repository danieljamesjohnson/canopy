---
phase: 06-desktop-and-web-polish
reviewed: 2026-05-14T00:00:00Z
depth: standard
files_reviewed: 31
files_reviewed_list:
  - lib/data/database/migrations.dart
  - lib/data/models/app_settings.dart
  - lib/data/models/app_settings.g.dart
  - lib/data/repositories/in_memory_app_settings_repository.dart
  - lib/main.dart
  - lib/platform/window_setup.dart
  - lib/platform/window_setup_io.dart
  - lib/platform/window_setup_stub.dart
  - lib/providers/theme_notifier.dart
  - lib/router.dart
  - lib/screens/commitments/commitments_screen.dart
  - lib/screens/goals/goals_screen.dart
  - lib/screens/goals/widgets/goal_card.dart
  - lib/screens/home/home_screen.dart
  - lib/screens/quarterly_review/sections/adjustments_section.dart
  - lib/screens/quarterly_review/widgets/goal_adjustment_tile.dart
  - lib/screens/schedule/checkin_screen.dart
  - lib/screens/schedule/widgets/chunk_card.dart
  - lib/widgets/responsive_shell.dart
  - pubspec.yaml
  - test/platform/window_setup_test.dart
  - test/providers/theme_notifier_test.dart
  - test/screens/chunk_card_hover_test.dart
  - test/screens/goal_card_drag_handle_test.dart
  - test/screens/goal_card_hover_test.dart
  - test/screens/home_screen_breathing_pulse_test.dart
  - test/screens/quarterly_review_test.dart
  - test/screens/responsive_layout_test.dart
  - test/screens/router_redirect_test.dart
  - test/test_helpers/mood_pump.dart
  - test/test_helpers/viewport.dart
findings:
  critical: 2
  warning: 9
  info: 4
  total: 15
status: issues_found
---

# Phase 6: Code Review Report

**Reviewed:** 2026-05-14T00:00:00Z
**Depth:** standard
**Files Reviewed:** 31
**Status:** issues_found

## Summary

Phase 6 adds the cross-platform desktop/web polish layer: `window_manager` with min-size enforcement, `ThemeNotifier` (HSL time-of-day modulation + 20-min ticker + daily rollover seam), `ResponsiveShell` (720dp NavigationBar/NavigationRail swap), and a battery of hover/drag-handle/breathing-pulse affordances across seven screens.

The dispose/teardown discipline on `ThemeNotifier`, `BreathingPulseCta`, and the new test viewport helpers is solid — the obvious "tickers and animation controllers must be cancelled" risk is well managed.

However, two **BLOCKER** correctness defects exist:

1. **D-10 ("no carry forward") is broken when the app stays foregrounded across midnight.** The 20-min ticker fires `notifyListeners()` without calling `_resetIfDayChanged()`, so a user who leaves the app open past midnight will see yesterday's mood seed driving today's theme until the next pause/resume cycle. This is the *exact* invariant Phase 6 was supposed to protect.

2. **`AdjustmentsSection._finish()` is a non-atomic multi-step persistence** with a generic `catch (_)` block, no rollback, and append-only snapshot semantics that mint a new UUID on every retry. A failure between the archive loop, `reorderAll`, and `append` leaves goals half-archived, reorder partially applied, and (after a retry) duplicate quarterly snapshots — corrupting the very append-only history the comment promises to protect.

Nine **WARNING** findings cover hover-icon UX regressions (icons revealed at full opacity on resolved chunks, hover icons overlaying goal-color swatches), platform-gating gaps (touch-Windows / touch-ChromeOS users lose the always-visible delete affordance), the accessibility toggle not being observable mid-session in `BreathingPulseCta`, unwrapped startup failures in `main.dart`, and a missing test for `ResponsiveShell._goBranch`'s active-tab pop semantics.

## Critical Issues

### CR-01: Mid-foreground midnight rollover does not reset mood seed (D-10 broken)

**File:** `lib/providers/theme_notifier.dart:184-192`
**Issue:** The 20-minute ticker fires `notifyListeners()` unconditionally without invoking `_resetIfDayChanged()`. Combined with `_resetIfDayChanged()` being called *only* from `init()` and `didChangeAppLifecycleState(.resumed)`, a user who keeps the app foregrounded across midnight will continue to see yesterday's mood seed driving the ColorScheme.fromSeed indefinitely. This violates **D-10 "no carry-forward"** — the explicit Phase 6 invariant that the rollover seam exists to enforce. The defect is the most likely-to-fire bug in the phase because users frequently leave Canopy open as a background task on desktop.

**Fix:**
```dart
void _startTicker() {
  _ticker?.cancel();
  if (!_timeModulationEnabled || !_isForeground) return;
  _ticker = Timer.periodic(const Duration(minutes: 20), (_) {
    // D-10: must re-check day boundary on every tick so a foregrounded
    // app correctly clears the in-memory mood seed at the local midnight
    // crossing without requiring a pause/resume cycle.
    _resetIfDayChanged();
    notifyListeners();
  });
}
```
(Optional: cache `_ymdToday()` and only `notifyListeners()` if the day flipped OR the modulation factor changed — but unconditional notify is safe and matches the AC-6 contract.)

---

### CR-02: AdjustmentsSection._finish is non-atomic with no rollback, leaves data partial on retry

**File:** `lib/screens/quarterly_review/sections/adjustments_section.dart:67-120`
**Issue:** The `_finish()` method performs four destructive operations in sequence with a single bare `catch (_)`:
1. Loop over `_archivedIds` calling `notifier.archiveGoal(id)` (each is a Hive write)
2. `notifier.reorderAll(orderedIds)` (a second Hive write batch)
3. `HiveQuarterlySnapshotRepository().append(snapshot)`
4. `Navigator.pop`

If any step throws, the catch sets `_isSaving = false` and a generic "try again" error. But:
- A failure mid-loop in (1) leaves goals partially archived.
- A failure in (2) after (1) succeeded leaves stale archived state plus the old sort order.
- The "Retry" button re-runs `_finish()` from the top, re-archiving already-archived goals (idempotency unverified) and minting a **new** `QuarterlySnapshot.id` via `_uuid.v4()` (see `lib/data/models/quarterly_snapshot.dart:15`). The Hive box is `_box.put(snapshot.id, snapshot)` (see `lib/data/repositories/hive_quarterly_snapshot_repository.dart:18`), so the retry creates a **duplicate** snapshot row rather than overwriting the failed attempt.

The comment on line 95 ("append-only — never overwrite") doubles as the bug: append-only history with retry-on-failure → duplicate quarter rows in past-reviews.

**Fix:** Either (a) construct the `QuarterlySnapshot` *once*, cache its id, and reuse on retry; or (b) write the snapshot *first* (so the quarter is recorded even if archive/reorder partially fail) and then perform archive/reorder as a recoverable follow-up; or (c) add an idempotency key derived from `periodStartYmd + periodEndYmd` so retries `_box.put` the same key.
```dart
class _AdjustmentsSectionState extends State<AdjustmentsSection> {
  QuarterlySnapshot? _pendingSnapshot; // cache id across retries

  Future<void> _finish() async {
    if (_isSaving) return;
    setState(() { _isSaving = true; _saveError = null; });
    try {
      final notifier = context.read<GoalsNotifier>();
      for (final id in _archivedIds) {
        await notifier.archiveGoal(id);
      }
      final orderedIds = _orderedGoals
          .where((g) => !_archivedIds.contains(g.id))
          .map((g) => g.id)
          .toList();
      await notifier.reorderAll(orderedIds);
      final prioritySnapshot = {
        for (var i = 0; i < orderedIds.length; i++) orderedIds[i]: i,
      };
      // Reuse cached snapshot id on retry so append() overwrites the same row.
      _pendingSnapshot ??= QuarterlySnapshot(
        periodStartYmd: widget.periodStartYmd,
        periodEndYmd: widget.periodEndYmd,
      );
      _pendingSnapshot!
        ..goalChunkTotals = Map.of(widget.goalChunkTotals)
        ..reflectionAnswers = List.of(widget.reflectionAnswers)
        ..goalPrioritySnapshot = prioritySnapshot
        ..archivedGoalIds = _archivedIds.toList();
      await HiveQuarterlySnapshotRepository().append(_pendingSnapshot!);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveError = "Something went wrong saving your review. Your answers are not lost — try again.";
        });
      }
    }
  }
}
```
(Also consider logging the original exception instead of swallowing it with `catch (_)` — a silent failure on a quarterly review is opaque to support.)

## Warnings

### WR-01: BreathingPulseCta does not react to mid-session accessibility toggle

**File:** `lib/screens/home/home_screen.dart:248-291`
**Issue:** `_animationsDisabled` reads `platformDispatcher.accessibilityFeatures.disableAnimations` only in `initState` and `didUpdateWidget`. If the user toggles "Reduce motion" in OS settings while the app is open, `BreathingPulseCta` keeps animating until the parent rebuilds with a different `enabled` value. The widget should register a `WidgetsBindingObserver` and override `didChangeAccessibilityFeatures()` to stop/start the controller in lockstep with the platform.

**Fix:**
```dart
class _BreathingPulseCtaState extends State<BreathingPulseCta>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _applyState();
  }

  @override
  void didChangeAccessibilityFeatures() => _applyState();

  void _applyState() {
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
}
```

---

### WR-02: Resolved chunks reveal hover icons at full opacity with disabled taps

**File:** `lib/screens/schedule/widgets/chunk_card.dart:127-264`
**Issue:** When `chunk.isCompleted || chunk.isSkipped` (`isResolved == true`), `onMarkComplete` and `onMarkSkipped` are set to `null` (lines 133-139), so the IconButtons are disabled. But the wrapping `AnimatedOpacity` is still gated only on `_hovered` (line 245), so on hover the disabled icons fade to full opacity 1.0. The user sees actionable-looking check/skip icons that do nothing on tap — confusing UX.

**Fix:** Suppress the hover-icon overlay when the chunk is resolved.
```dart
if (!isResolved)
  Positioned(
    right: 0, top: 0, bottom: 0,
    child: AnimatedOpacity(
      opacity: _hovered ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Row(/* ...IconButtons... */),
    ),
  ),
```

---

### WR-03: Hover icons in GoalCard overlap the goal-color swatch and secondary text

**File:** `lib/screens/goals/widgets/goal_card.dart:167-192`
**Issue:** The hover-revealed edit + archive IconButtons (~48dp each = 96dp wide) are `Positioned(right: 0, top: 0, bottom: 0)` over the card Stack. On hover their opacity goes to 1.0 and they paint over the content area's right edge, which contains the 16dp color swatch (line 141-148) and the "X.X hrs/week" / "N-day streak" secondary line (line 152). Important visual context disappears the moment the user hovers.

**Fix:** Either (a) hide the swatch on hover via the same `_hovered` flag, (b) reduce the content's right padding when hovered so the swatch tucks left, or (c) overlay the icons with a frosted/scrim background so the swatch remains visible underneath. Option (a) is cheapest:
```dart
const SizedBox(width: 6),
if (!_hovered)
  Container(width: 16, height: 16, ...),
```

---

### WR-04: Touch-Windows / touch-ChromeOS users lose delete + edit affordance

**File:** `lib/screens/commitments/commitments_screen.dart:198-200` (and the same pattern in `lib/screens/goals/widgets/goal_card.dart`, `lib/screens/schedule/widgets/chunk_card.dart`)
**Issue:** The `isMobileTouch` test gates `defaultTargetPlatform == TargetPlatform.android || iOS`. On a touch-screen Windows tablet or ChromeOS device, `defaultTargetPlatform` returns `windows`/`linux`, falling through to the hover-only branch. Without hover events (touch only), the edit + delete IconButtons stay at opacity 0 forever and are effectively hidden — the user has **no way** to delete a commitment, archive a goal, or skip a chunk.

**Fix:** Detect input modality (or treat `Theme.of(context).platform` decisions as orthogonal to input modality). Either use `MediaQuery.of(context).gestureSettings` heuristics, expose a "show actions" tap target unconditionally, or wrap the icons in a long-press secondary menu for touch users. A minimal first fix is to always render the actions but at reduced opacity until hovered:
```dart
// Always paint the row; fade rather than gate by platform.
AnimatedOpacity(
  opacity: _hovered ? 1.0 : (isMobileTouch ? 1.0 : 0.0),
  duration: const Duration(milliseconds: 120),
  child: Row(/* ... */),
),
```
(This keeps the desktop fade-in UX while ensuring touch platforms always have visible affordances. Long-term, gate on input modality not platform.)

---

### WR-05: main.dart does not guard setupDesktopWindow() against transient failures

**File:** `lib/main.dart:20`
**Issue:** `await setupDesktopWindow();` is unwrapped. If the `window_manager` plugin fails at startup (transient platform-channel error, OS version mismatch, sandboxed-Linux quirk), the app fails to launch with a raw stack trace before Hive even initializes. The `window_setup_test.dart` already documents that `MissingPluginException` is the test-host outcome — but the production path has no such tolerance.

**Fix:**
```dart
try {
  await setupDesktopWindow();
} catch (e, st) {
  // Window-min-size enforcement is a polish nice-to-have, not a startup
  // blocker. Log and continue so Hive + providers still initialize.
  debugPrint('setupDesktopWindow failed (continuing): $e\n$st');
}
```

---

### WR-06: ThemeNotifier.init() does not guard against repository failure

**File:** `lib/providers/theme_notifier.dart:94-103`
**Issue:** `init()` calls `_repo.getSettings()` without a try/catch. If the Hive box is not open (e.g., partial migration failure in `runMigrations`), the call throws. `init()` then never reaches `addObserver` or `_startTicker` — but the caller in `main.dart:36-37` (`await themeNotifier.init();`) propagates the exception, crashing the app before `runApp`. Combined with WR-05, a corrupted Hive state can hard-brick the app on launch.

**Fix:** Wrap repository I/O in try/catch and fall back to defaults:
```dart
Future<void> init() async {
  try {
    final settings = await _repo.getSettings();
    final argb = settings?.moodSeedArgb;
    _moodSeed = (argb == null) ? null : Color(argb);
    _lastMoodSetYmd = settings?.lastMoodSetYmdInt;
    _resetIfDayChanged();
  } catch (e, st) {
    debugPrint('ThemeNotifier.init failed (defaulting to curious): $e\n$st');
    _moodSeed = null;
    _lastMoodSetYmd = null;
  }
  WidgetsBinding.instance.addObserver(this);
  _startTicker();
  notifyListeners();
}
```

---

### WR-07: resetToCurious does not clear _lastMoodSetYmd or persist it

**File:** `lib/providers/theme_notifier.dart:120-129`
**Issue:** `resetToCurious()` clears `_moodSeed` and persists `moodSeedArgb = null`, but does **not** touch `_lastMoodSetYmd` (in-memory) or `s.lastMoodSetYmdInt` (Hive). Effects:
- The in-memory `_lastMoodSetYmd` still points to the previous mood's date. If `setMoodSeed` is called next on the same day, `_lastMoodSetYmd` is overwritten to today — fine. But if the user resets on day N and the app is foregrounded into day N+1, `_lastMoodSetYmd == N`, `_ymdToday() == N+1`, `_resetIfDayChanged()` sets `_moodSeed = null` (already null) — benign, but state is misleading for debugging.
- The persisted Hive `lastMoodSetYmdInt` remains stale across the reset, breaking any future "last mood event" telemetry that might be derived from this field.

**Fix:**
```dart
Future<void> resetToCurious() async {
  _moodSeed = null;
  _lastMoodSetYmd = null;
  final s = await _repo.getSettings() ?? AppSettings();
  s.moodSeedArgb = null;
  s.lastMoodSetYmdInt = null;
  await _repo.saveSettings(s);
  notifyListeners();
}
```

---

### WR-08: Migration runner does not validate currentSchemaVersion bounds

**File:** `lib/data/database/migrations.dart:36-42`
**Issue:** `runMigrations` reads `storedVersion` and iterates `for (int i = storedVersion; i < currentSchemaVersion; i++)`. If a future build is downgraded (i.e., the app is rolled back to a version with a *lower* `currentSchemaVersion`) while Hive's `schemaVersion` pref is from a *newer* schema, the loop simply doesn't run, but `prefs.setInt('schemaVersion', currentSchemaVersion)` then **downgrades** the persisted version. The next future-build run will mistakenly attempt forward migrations starting at the downgraded version, replaying steps that already ran. No assertion guards against `storedVersion > currentSchemaVersion`.

**Fix:**
```dart
Future<void> runMigrations(SharedPreferences prefs) async {
  final int storedVersion = prefs.getInt('schemaVersion') ?? 0;
  assert(storedVersion <= currentSchemaVersion,
      'Stored schema version $storedVersion is ahead of currentSchemaVersion '
      '$currentSchemaVersion — refusing to downgrade. This usually means the '
      'app was rolled back; uninstall + reinstall is required.');
  if (storedVersion > currentSchemaVersion) return; // skip in release
  for (int i = storedVersion; i < currentSchemaVersion; i++) {
    await _migrations[i]();
  }
  await prefs.setInt('schemaVersion', currentSchemaVersion);
}
```

---

### WR-09: ResponsiveShell._goBranch active-tab pop semantics are untested

**File:** `lib/widgets/responsive_shell.dart:52-56`, `test/screens/responsive_layout_test.dart`
**Issue:** Line 55 passes `initialLocation: index == navigationShell.currentIndex` — meaning re-tapping the active tab pops to the branch's root. This is a non-trivial UX contract that's easy to silently break (e.g., a future refactor inverting the condition would pop on *any* tap, blowing away nested state on every navigation). `test/screens/responsive_layout_test.dart` exercises the rail/bar swap but never taps a destination, so this branch has zero test coverage.

**Fix:** Add a regression test that pushes a sub-route, taps the active branch's destination, and asserts the route popped to root. Optionally extract the conditional into a `_shouldPopToRoot` helper to make the intent grep-able.

## Info

### IN-01: ChunkCard short-break and long-break variants lack hover affordances

**File:** `lib/screens/schedule/widgets/chunk_card.dart:33-91`
**Issue:** Only `ChunkType.work` is wrapped in `_HoverableChunkContent`. Short-break and long-break cards (which appear in the same scroll list as work chunks) have no hover icons, no Material InkWell ripple, and no edit/skip affordances. This is intentional per Phase 4 — breaks aren't user-actionable — but the asymmetry is a UX cliff that should be documented in the widget header (currently the header only mentions the work variant's hover spec).

**Fix:** Update the file-level dartdoc to call out the deliberate asymmetry.

---

### IN-02: hexToColor is duplicated across goal_card.dart and chunk_card.dart

**File:** `lib/screens/goals/widgets/goal_card.dart:5-7`, `lib/screens/schedule/widgets/chunk_card.dart:7-9`
**Issue:** Two file-local `hexToColor` functions with identical bodies. Drift risk if one is later patched (e.g., to validate the parsed length or handle 4-char shorthand).

**Fix:** Extract to `lib/utils/color_utils.dart` (or `lib/utils/hex_color.dart`) and import in both call sites. Also strengthens the GoalsNotifier reuse in `adjustments_section.dart:60-65` which has its own bespoke `int.parse(palette[...].replaceFirst('#', '0xFF'))` parsing.

---

### IN-03: window_setup_io.dart kIsWeb guard is dead code

**File:** `lib/platform/window_setup_io.dart:21`
**Issue:** The file is only compiled when `dart.library.io` resolves (per `window_setup.dart:12`'s conditional export). On Web, `dart.library.io` is unavailable, so this file is never imported — `kIsWeb` will always be `false` here. The comment acknowledges this is defensive, but the dead branch creates a misleading impression that the same file runs on Web. Consider removing or replacing with an `assert(!kIsWeb)` to encode the invariant.

**Fix:**
```dart
Future<void> setupDesktopWindow() async {
  assert(!kIsWeb,
      'window_setup_io.dart must only compile when dart.library.io is present');
  if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) return;
  await windowManager.ensureInitialized();
  await windowManager.setMinimumSize(const Size(480, 640));
}
```

---

### IN-04: theme_notifier_test daily-rollover test mutates Hive then ignores the read

**File:** `test/providers/theme_notifier_test.dart:317-322`
**Issue:** The third rollover test ("didChangeAppLifecycleState(resumed) on a stale day...") mutates `repo` via `s!.lastMoodSetYmdInt = 20260511; await repo.saveSettings(s);` and then immediately discards that work (lines 322-336) because the in-memory `_lastMoodSetYmd` is what `_resetIfDayChanged` actually reads. The comment on line 326-330 acknowledges this, but the leading lines 317-321 still execute and dirty the in-memory fake repository. This is wasted work + misleading scaffolding — a future reader will assume those lines matter.

**Fix:** Remove lines 317-321 entirely, or move the comment block above them so the dead-mutation is clearly flagged before the code runs.

---

_Reviewed: 2026-05-14T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
