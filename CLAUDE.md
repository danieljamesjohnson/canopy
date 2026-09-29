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
# Debug MODE (assertions on, DEBUG banner, source-mapped traces), single dart2js bundle.
# NOTE: --pwa-strategy=none is deprecated in Flutter 3.44 and does NOT prevent a service
# worker being registered here — it only empties the generated file. See trap #1.
flutter build web --debug --source-maps --pwa-strategy=none

# Serve statically, bound to all interfaces for the tailnet.
# Use tools/serve-uat.py, NOT `python3 -m http.server` — see trap #3:
python3 tools/serve-uat.py <port> --dir build/web
```

Reach it at `http://danserver:<port>/`. Use a port that has NEVER served a different
build type (see trap #1). Switch to `flutter build web --release` only once the basics
are solid.

**If the UAT involves adding a calendar feed URL, plain `http://` is NOT enough — you must
serve over HTTPS.** `IcsCalendarSource._requireHttps()` rejects any non-`https` feed URL
outright (Security V6) with *"feed URL must use HTTPS"*, and there is **no** localhost,
loopback or debug-mode exemption. A UAT that tells the owner to paste
`http://danserver:<port>/sample.ics` cannot pass step one. Front the static server with a
real tailnet certificate instead:

```bash
python3 tools/serve-uat.py 8161 --dir build/web
sudo tailscale serve --bg --https=8447 http://127.0.0.1:8161
# -> https://danserver.tailc2efd2.ts.net:8447/   (valid cert, tailnet only)
# tear down with: sudo tailscale serve --https=8447 off
```

**This is not hypothetical.** Phase 35's browser UAT shipped on 2026-09-17 instructing an
`http://` feed URL and sat "open, awaiting the owner" for twelve days while being impossible
to complete. It survived review because `35-06`'s verification drove the sync through the
`IcsFetcher` seam with an `https://example.com/...` URL while the document told the owner to
type an `http://` one — **the harness and the instructions were never pointed at the same
URL.** When you verify a UAT, drive the *exact* URL the human will type, through the real
fetcher, not the seam.

### Four traps that fake a broken build (none of them means the build is broken)

Traps #1 and #2 fake a *blank page*; traps #3 and #4 fake a *missing feature*. Rule them
out before concluding the build is broken:

1. **Service-worker cache collision — never swap build types on one origin/port.**
   Release builds register `flutter_service_worker.js` scoped to that origin
   (e.g. `danserver:8095`). If you later serve a *debug* build on the **same**
   port, the browser's service worker keeps intercepting requests and serving the
   cached **release** shell against a mismatched server → blank, and it persists
   across reloads and even incognito-after-install. **Dedicate a port per build
   type and never cross them.** If you must reuse an origin, first unregister the
   SW (DevTools → Application → Service Workers → Unregister, then Clear storage)
   or just pick a fresh port. A SW left over from a prior **release** build on the
   same port still will, so keep using fresh ports.

   **Corrected 2026-09-29 — this used to claim the `--pwa-strategy=none` debug build
   "never registers a SW". That is false, and the flag is now deprecated** (Flutter
   3.44.1 prints *"The --pwa-strategy option is deprecated and will be removed in a
   future Flutter release"*). Two things are true instead: the build still **emits**
   `flutter_service_worker.js` (as a **0-byte** file — the flag neuters its contents,
   not its existence), and this project's own committed `web/index.html` **deliberately
   registers it** with a hand-written `navigator.serviceWorker.register(...)` block, on
   every build. So a debug build *does* register a worker. In practice it is harmless
   and arguably protective: an empty worker has no `fetch` handler, so everything goes
   to network, and registering it **displaces** any stale worker previously on that
   origin. Do not "fix" the registration out of `web/index.html` — read the long comment
   above it first; it is there for the PWA/offline path served by `tools/serve-pwa.py`.
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
4. **Stale Hive data — the served bytes are correct, so trap #3's own check will not
   catch this one.** `ScheduleNotifier._loadToday()` reads today's schedule straight
   from Hive, and `ScheduleGeneratorService.generate()` only runs at check-in with
   silent-replace. An already-generated day is **never regenerated on load**, so a
   change to the scheduling engine is invisible in the running app until the user
   taps **⟳ Re-check-in** — even though `curl | grep` on `main.dart.js` will happily
   confirm the new code shipped, because it did. The served bytes being right is
   exactly what makes this trap convincing: an agent who has just run trap #3's
   diagnosis and gotten a clean, non-zero grep will reasonably but wrongly treat
   that as proof the feature is present, when all it proved is that the *code*
   shipped, not that the *data on screen* was produced by it.
   **This is not hypothetical.** On 2026-08-21 a UAT of an engine change omitted
   Re-check-in, judged a pre-fix day, and reported a false failure — costing the
   owner a round trip and letting the real defect survive three more days until he
   reported the identical symptom again on 2026-08-24.
   **The rule, not a suggestion:** any UAT that judges scheduling-engine output
   must ⟳ Re-check-in first, and any plan that writes such a UAT must put that step
   — first, marked mandatory — in the UAT's own instructions.

## Assertions that cannot fail — the recurring failure mode

This project's green suites have been contradicted by the owner's own eyes five times (Phases 27,
29, 31, and 32 twice). The cause is almost never a missing test; it is a test that **passes for a
reason unrelated to the defect**. Two concrete traps have been measured here, both worth checking
before you trust a new regression test:

1. **`find.byType(X)` does not match subclasses.** It compares `runtimeType` exactly. A test
   asserting `find.byType(Flexible), findsNothing` stays green when the widget is wrapped in
   `Expanded` — which *is* a `Flexible`. Use `find.byWidgetPredicate((w) => w is Flexible)` when
   you mean "any subtype". Found in Phase 33 by mutation-testing an assertion that had just been
   written.

2. **A tight-constrained harness reports the right number for the wrong reason.** Pumping a
   height-filling widget inside `SizedBox(height: N)` hands it a *tight* constraint, so it measures
   N whether or not it would have collapsed in production — where `TimelineRowTile`'s
   `Row(crossAxisAlignment: start)` + `Expanded` hands it **loose** constraints instead. Measured in
   Phase 33 with the collapse defect deliberately introduced: the tight harness read 232.0 and
   **passed**; the loose harness read 20.0 and **failed**. Pump through the real production widget.

**The rule:** when a plan says "observe this RED first", actually introduce the defect and watch the
test fail. A compile error is a weak form of red — it proves the API is missing, not that the
assertion discriminates. Mutation-test the load-bearing assertion and revert.

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
