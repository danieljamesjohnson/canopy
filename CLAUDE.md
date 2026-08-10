# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Product position (read before proposing features)

Canopy is a **dumb app on purpose**. It exists to give the user control over their own time, so the
scheduling engine is rule-based and deterministic and stays that way — **do not propose or add LLM
calls, "smart" suggestions, or any in-app AI surface.** A schedule the user can't predict is one
they won't trust. The only sanctioned AI shape is *at the edge*: a possible future MCP server that
lets an external assistant read and update the schedule under the same rules the app already
enforces. See "Out of Scope" in `.planning/PROJECT.md`.

The repo is public as a work sample, and the AI angle here is that **AI is the developer** — the
`.planning/` trail is part of what's on display, so keep it honest and current rather than
flattering.

## Commands

```bash
# Get dependencies
flutter pub get

# Run the app (debug)
flutter run

# Run on a specific device
flutter run -d <device_id>

# Build for a platform
flutter build apk        # Android
flutter build ios        # iOS
flutter build web        # Web
flutter build windows    # Windows

# Run all tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Analyze and lint
flutter analyze

# Format code
dart format lib/

# Clean build artifacts
flutter clean
```

## Local hosting for UAT

While we're still getting through the basics (early UAT), **host the DEBUG build, not
release** — diagnostics over speed, deliberately. Debug web builds emit full, unminified
Dart stack traces; release minifies everything to `main.dart.js:<n>`, which is unreadable
when something throws (this is exactly what blocked the stale-Hive-data crash triage). Do
**not** optimize for load speed at this stage — that concern was premature.

**Build a single-bundle debug build and serve it statically — do NOT use
`flutter run -d web-server`.** That command uses the DDC incremental compiler, which
fans the app out into ~866 separate module files. Over tailscale latency, the browser's
~6-connections-per-origin limit turns that into minutes of serial round-trips → blue
loading strip → white. It only "worked before" when the app was small (few modules). The
app outgrew it. (Measured: at 80ms emulated latency the DDC build's `load` event never
fired in 90s / 877 requests; the single-bundle debug build below fired in ~21s / 9
requests.)

```bash
# Debug MODE (assertions on, DEBUG banner, source-mapped traces), single dart2js bundle,
# no service worker (so it can never collide on an origin):
flutter build web --debug --source-maps --pwa-strategy=none

# Serve statically, bound to all interfaces for the tailnet.
# Use tools/serve-uat.py, NOT `python3 -m http.server` — see trap #3:
python3 tools/serve-uat.py <port> --dir build/web
```

Reach it at `http://danserver:<port>/`. Use a port that has NEVER served a different
build type (see trap #1). Switch to `flutter build web --release` only once the basics
are solid.

### Three traps that fake a broken build (none of them means the build is broken)

Traps #1 and #2 fake a *blank page*; trap #3 fakes a *missing feature*. Rule them
out before concluding the build is broken:

1. **Service-worker cache collision — never swap build types on one origin/port.**
   Release builds register `flutter_service_worker.js` scoped to that origin
   (e.g. `danserver:8095`). If you later serve a *debug* build on the **same**
   port, the browser's service worker keeps intercepting requests and serving the
   cached **release** shell against a mismatched server → blank, and it persists
   across reloads and even incognito-after-install. **Dedicate a port per build
   type and never cross them.** If you must reuse an origin, first unregister the
   SW (DevTools → Application → Service Workers → Unregister, then Clear storage)
   or just pick a fresh port. The `--pwa-strategy=none` debug build above never
   registers a SW, so it can't *create* this collision — but a SW left over from a
   prior **release** build on the same port still will, so keep using fresh ports.
2. **Headless Chromium exhausts the GPU → `CONTEXT_LOST_WEBGL` → blank.**
   Repeatedly launching headless Chromium (e.g. automated screenshot loops)
   triggers WebGL context loss, so CanvasKit can't draw and never reaches
   `main()`. This is an automation artifact, **not** a real-browser bug. Verify in
   a real GPU-backed browser, or force stable software WebGL for headless runs
   (`--use-gl=swiftshader --enable-unsafe-swiftshader`). Don't conclude "debug is
   unreliable" from a headless blank.
3. **A stale browser cache serves the PREVIOUS bundle — use `tools/serve-uat.py`.**
   `python3 -m http.server` sends **no `Cache-Control` header**. Browsers are then
   free to apply *heuristic* caching and keep serving a cached `main.dart.js`
   without ever revalidating. On a 13 MB debug bundle this reliably means you
   rebuild, reload, and still see the old build — then reasonably conclude the
   change never landed. This is not hypothetical: it cost a round trip during
   Phase 25's UAT, where the new feature was present in the served bytes while
   the browser showed a two-day-old build. `tools/serve-uat.py` sends
   `Cache-Control: no-store` and strips `If-Modified-Since`/`If-None-Match`, so a
   cache entry created before the switch can't win a `304` either.
   **Diagnosis first, always:** if a change seems missing from the running app,
   `curl -s http://danserver:<port>/main.dart.js | grep -c '<a new string>'`.
   Non-zero means the server is serving the right bytes and it's a client-side
   cache — not a broken build, and not a missing feature.

## Architecture

This is a Flutter app targeting Android, iOS, Web, Windows, Linux, and macOS. Code is organized in layers under `lib/`:

- `lib/data/` — persistence. `database/` (Hive setup, migrations, `resilient_box`), `models/` (Hive-adapter models + generated `*.g.dart`), `repositories/` (an interface per aggregate with `hive_*` and `in_memory_*` implementations).
- `lib/providers/` — `ChangeNotifier` state holders (`schedule_notifier`, `goals_notifier`, `commitments_notifier`, `settings_notifier`, `theme_notifier`).
- `lib/screens/` — one folder per feature (home, onboarding, schedule, goals, commitments, focus, end_of_day, quarterly_review, settings).
- `lib/services/` — `schedule_generator`, `notification_service`, `export_service`, `quarterly_aggregation_service`.
- `lib/widgets/` (`responsive_shell`), `lib/platform/` (desktop window setup via conditional io/stub imports), `lib/utils/`, `lib/dev/` (dev data loader).
- `lib/main.dart` (~180 lines) is bootstrap only: window setup → `HiveDatabase.init` → construct notifiers → `runApp`. `lib/router.dart` builds the routing.

Key choices:

- **State management**: Provider + `ChangeNotifier` for cross-screen state (notifiers in `lib/providers/`); `StatefulWidget` + `setState()` for screen-local state only.
- **Routing**: `go_router` (`createRouter` in `lib/router.dart`) with a `refreshListenable` on `SettingsNotifier` and a `redirect` that gates everything behind `/onboarding` until `onboardingComplete`. A `rootNavigatorKey` lets notification taps navigate without a `BuildContext`.
- **Persistence**: Hive (per-aggregate boxes) for app data; `SharedPreferences` for settings bootstrap.
- **Theme**: Material 3 with `ColorScheme.fromSeed(Colors.deepOrangeAccent)`.
- **Linting**: `package:flutter_lints` via `analysis_options.yaml`.
- **Dart SDK**: `^3.10.3` | **Flutter**: `>=3.18.0-18.0.pre.54`.

Tests are in `test/` using `flutter_test`.
