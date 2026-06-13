---
phase: 06-desktop-and-web-polish
plan: 03
subsystem: platform-glue
tags: [conditional-import, window_manager, desktop, web-stub, dart.library.io]

requires:
  - phase: 06-desktop-and-web-polish
    plan: 01
    provides: window_manager ^0.5.1 dependency available on desktop targets
provides:
  - lib/platform/window_setup.dart — conditional re-export entry point
  - lib/platform/window_setup_io.dart — desktop real impl, locks Size(480, 640) min on Windows/macOS/Linux
  - lib/platform/window_setup_stub.dart — Web no-op stub with matching `setupDesktopWindow()` signature
  - setupDesktopWindow() top-level symbol — uniformly callable from main.dart at compile time per platform
affects: [lib/main.dart (Plan 04 wires the call), test/platform/window_setup_test.dart (Plan 06 adds tests)]

tech-stack:
  added: []
  patterns:
    - "Pattern 3 (RESEARCH.md): three-file `dart.library.io` conditional-import idiom (stub default; io guarded)"
    - "Pattern B (PATTERNS.md): kIsWeb early-return BEFORE Platform.is* to keep dart:io's Platform out of Web's runtime reach (defense-in-depth even though _io is compiled out on Web)"

key-files:
  created:
    - lib/platform/window_setup.dart
    - lib/platform/window_setup_io.dart
    - lib/platform/window_setup_stub.dart
  modified: []

key-decisions:
  - "Stub kept doc comment free of the literal substrings `dart:io` and `window_manager` — the plan's verify gate `! grep -E '(dart:io|window_manager)' lib/platform/window_setup_stub.dart` is intentionally strict and a documentation reference would have tripped it. The intent is documented with neutral phrasing ('platform-specific imports', 'IO library', 'native window plugin')."
  - "`library;` directive added above each file's doc comment because Dart requires a library or library-identifier directive when a file's first declaration is preceded by a doc comment with no other library-level target. This is the canonical no-name `library;` form (preferred over a named library in Dart 3+)."
  - "`dart format` auto-collapsed the export in `window_setup.dart` from two lines to one (`export 'window_setup_stub.dart' if (dart.library.io) 'window_setup_io.dart';`) — accepted as canonical; the plan's grep gates use substring match (`'window_setup_stub.dart'` and `if (dart.library.io) 'window_setup_io.dart'`), both still pass."

requirements-completed: [AC-3]
threat-refs: [T-platform-1, T-06-03-1, T-06-03-2]

duration: 2m
completed: 2026-05-13
---

# Phase 06 Plan 03: window_setup Conditional-Import Trio Summary

**`setupDesktopWindow()` is now a single import point — Plan 04 can call it from `main.dart` and the right body resolves automatically per platform at compile time: real `windowManager.setMinimumSize(Size(480, 640))` on Windows/macOS/Linux (D-11), guarded no-op on Android/iOS, web stub on Web (zero `dart:io` / `window_manager` references — the conditional-export invariant).**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-05-13T10:52:49Z
- **Completed:** 2026-05-13T10:55:01Z
- **Tasks:** 1/1 committed
- **Files created:** 3 (zero modified)

## Accomplishments

- Created the three-file `dart.library.io` conditional-import trio under `lib/platform/`.
- `window_setup.dart` (12 lines): canonical re-export — stub by default, `_io.dart` when `dart:io` is available. The single statement that crosses to the impl file is the standard 1-line Dart idiom (`dart format` canonicalized it from a 2-line source).
- `window_setup_io.dart` (25 lines): `kIsWeb` early-return → `Platform.is{Windows,MacOS,Linux}` disjunction → `windowManager.ensureInitialized()` → `windowManager.setMinimumSize(const Size(480, 640))`. Order of guards matches PATTERNS.md §Pattern B verbatim. Doc comment cites D-11 + UI-SPEC §Window Minimums.
- `window_setup_stub.dart` (15 lines): top-level `Future<void> setupDesktopWindow() async` with identical signature; zero imports; zero references to `dart:io` or `window_manager` in source — both source and identifiers (the verify gate `! grep -E "(dart:io|window_manager)"` passes).
- `flutter analyze lib` reports **0 issues** across the three new files (baseline was also 0 — no regressions).

## Task Commits

Each task was committed atomically:

1. **Task 1: Create the three window_setup files** — `7ee039f` (feat)

## Files Created

| File | Lines | Role |
|------|------:|------|
| `lib/platform/window_setup.dart` | 12 | Conditional re-export entry point (the only file `main.dart` imports) |
| `lib/platform/window_setup_io.dart` | 25 | Desktop real impl — `windowManager.setMinimumSize(Size(480, 640))` on Windows/macOS/Linux |
| `lib/platform/window_setup_stub.dart` | 15 | Web no-op — matching `setupDesktopWindow()` signature, zero forbidden imports |
| **Total** | **52** | |

## Verification

All plan-specified gates green:

| Gate | Result |
|------|--------|
| `lib/platform/window_setup.dart` exists | OK |
| `lib/platform/window_setup_io.dart` exists | OK |
| `lib/platform/window_setup_stub.dart` exists | OK |
| `grep -q "export 'window_setup_stub.dart'"` | OK |
| `grep -q "if (dart.library.io) 'window_setup_io.dart'"` | OK |
| `grep -q "Future<void> setupDesktopWindow() async"` in `_io.dart` | OK |
| `grep -q "Future<void> setupDesktopWindow() async"` in `_stub.dart` | OK |
| `grep -q "setMinimumSize(const Size(480, 640))"` in `_io.dart` | OK |
| `grep -q "Platform.isWindows \|\| Platform.isMacOS \|\| Platform.isLinux"` in `_io.dart` | OK |
| `grep -q "windowManager.ensureInitialized"` in `_io.dart` | OK |
| `! grep -E "(dart:io\|window_manager)" lib/platform/window_setup_stub.dart` | OK (zero matches) |
| `flutter analyze lib` | 0 issues (clean) |
| `dart format lib/platform/` | accepted (no further changes) |

## Stub Zero-Import Invariant (the conditional-export contract)

The Web build's correctness rests on **`window_setup_stub.dart` containing zero references to `dart:io` and `window_manager`** — neither in imports nor in source. This is verified by:

```bash
! grep -E "(dart:io|window_manager)" lib/platform/window_setup_stub.dart
```

The doc comment in the stub was intentionally worded to avoid the literal substrings `dart:io` and `window_manager` (using "IO library" / "native window plugin" / "platform-specific imports" instead) so the gate stays a true invariant — not a documentation-string match.

## Threat Surface

No new threat surface beyond what the plan's `<threat_model>` enumerated. All three dispositions hold:

- **T-platform-1 (Tampering, accept):** Out-of-process window-manager tampering is out-of-scope for a single-user local Flutter app. The 480×640 lock is a UX guarantee, not a security boundary.
- **T-06-03-1 (DoS, mitigate):** Web stub has zero `dart:io` / `window_manager` references (grep gate green) — Web compilation cannot pull these symbols.
- **T-06-03-2 (Tampering, mitigate):** Same grep gate is the runtime check against a future contributor adding a `dart:io` import to the stub; Plan 06's `test/platform/window_setup_test.dart` will exercise the stub branch at test time per VALIDATION.md.

## Deviations from Plan

**1. [Rule 1 — Bug] Stub doc comment originally tripped the verify gate.**

- **Found during:** Verify step after Write.
- **Issue:** The plan's PATTERNS.md / RESEARCH.md guidance for the stub doc comment suggested phrasing like "MUST NOT import package:window_manager or dart:io". I wrote that verbatim. The plan's verify gate `! grep -E "(dart:io|window_manager)" lib/platform/window_setup_stub.dart` is `grep` (not `grep -F` and not import-line-only) — it would match the literal substrings inside the doc comment, failing the invariant.
- **Fix:** Reworded the stub's doc comment to express the same constraint with neutral phrasing ("platform-specific imports", "IO library", "native window plugin"). Re-ran the gate — zero matches, invariant holds. The intent is preserved and the gate now actually tests the import situation, not the doc text.
- **Files modified:** `lib/platform/window_setup_stub.dart` (pre-commit, single iteration before first commit).
- **Commit:** rolled into `7ee039f`.

**2. [Rule 3 — Blocking] `library;` directive added.**

- **Found during:** Write step. Dart 3 requires a `library;` directive when a file starts with a doc comment but has no other library-level declarations the comment can attach to (would otherwise produce an "unused element" / "documentation comment is not attached to anything" warning, depending on rule set).
- **Fix:** Added a bare `library;` directive (canonical no-name form, preferred in Dart 3+) below the file-level doc comment in `window_setup.dart` and `window_setup_stub.dart`. `window_setup_io.dart` does not need it because its doc comment is attached to the `setupDesktopWindow` function declaration.
- **Verification:** `flutter analyze lib` 0 issues.
- **Commit:** rolled into `7ee039f`.

**3. [Cosmetic — accepted] `dart format` collapsed the export.**

- **Found during:** Format step (PATTERNS.md follows formatter output as the source of truth).
- **Detail:** `window_setup.dart` was originally written with the export on two lines (matching RESEARCH.md Pattern 3's printed form). `dart format` collapsed it to a single line: `export 'window_setup_stub.dart' if (dart.library.io) 'window_setup_io.dart';`. Both substrings the verify gate looks for are present.
- **Action:** Accepted the formatter's output. Not a deviation from intent — purely whitespace canonicalization.

## What Plan 04 Will Do

Plan 04 modifies `lib/main.dart` to:

1. `import 'platform/window_setup.dart';`
2. Call `await setupDesktopWindow();` after `WidgetsFlutterBinding.ensureInitialized()` and before `runApp(...)`.

On Web the call resolves to the stub no-op; on Windows/macOS/Linux it resolves to the real impl and the window minimum size is locked at 480×640 per D-11. No `#if`-style branching needed in `main.dart`.

## Self-Check: PASSED

- `lib/platform/window_setup.dart` exists (FOUND)
- `lib/platform/window_setup_io.dart` exists (FOUND)
- `lib/platform/window_setup_stub.dart` exists (FOUND)
- Commit `7ee039f` exists in `git log --oneline --all` (FOUND)
- `flutter analyze lib` reports 0 issues (CLEAN)
- `! grep -E "(dart:io|window_manager)" lib/platform/window_setup_stub.dart` returns exit 1 (INVARIANT HOLDS)
