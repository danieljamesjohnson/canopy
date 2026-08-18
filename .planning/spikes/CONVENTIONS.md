# Spike Conventions

Patterns established across spike sessions. New spikes follow these unless the
question requires otherwise.

## Stack

Spikes here are **variants of the real app**, not throwaway projects. Canopy's
open questions are about how its own widgets behave against its own geometry
under real font metrics, and a standalone HTML mock cannot answer that. So a
spike is a `--dart-define` switch in `lib/`, built with the project's own debug
web build, and the diff is saved to the spike directory as `variants.patch`
before `lib/` is reverted.

```dart
const String kSpikeVariant =
    String.fromEnvironment('SPIKE_VARIANT', defaultValue: 'baseline');
```

One working tree, one flag, N builds — so the screenshots differ only in the
variant being spiked, never in the fixture. Always build `baseline` too, and
always confirm it reproduces the known-bad number before trusting the harness.

## Structure

```
.planning/spikes/NNN-name/
  README.md         frontmatter + Investigation Trail + Results
  variants.patch    the exact lib/ diff the builds came from (artefact, not a patch to apply)
  tools/            drivers and measurement scripts
  shots/            evidence PNGs, named <variant>-<HHMM>-<state>.png
```

Port **8134** is the spike UAT port. Debug, `--pwa-strategy=none`, served with
`tools/serve-uat.py` (never `python3 -m http.server` — see CLAUDE.md trap #3).
Keep one build type per port forever (trap #1).

## Patterns

**Driving the app headlessly.** Flutter web paints to canvas, so there is no DOM
to select. Click `flt-semantics-placeholder` once to switch on the semantics
tree, then match `flt-semantics` nodes by exact `aria-label`. Semantic nodes
nest — an ancestor carries the concatenated text of everything under it — so
always pick the **smallest** matching box; that is the leaf that handles the
tap. `tools/drive.cjs` in spike 001 does all of this and is worth copying.

**Setting the clock precisely.** Write
`localStorage['flutter.dev_clock_offset_micros']` and reload, rather than
clicking the debug UI's `+1h`/`-1h` buttons. `DevClock` persists through
`SharedPreferences`, which on web is `localStorage` with a `flutter.` prefix.
Technique originates in `26-08-SUMMARY.md`.

**Reusing app state.** Use `launchPersistentContext` with a fixed profile
directory. The app's data is in IndexedDB keyed by origin, so onboarding and the
morning check-in run **once** and every subsequent build served on the same port
sees the identical day. That is what makes cross-variant screenshots comparable.

**Measuring, not eyeballing.** Any claim about a distance, a height, or a
spacing gets a script that pixel-counts it and prints a pass/fail verdict, and
that script gets committed with the spike. Derive background colour from the
image rather than hard-coding it so it survives a theme change.

**Never measure layout in `flutter test`.** Its placeholder font has no real
Roboto metrics. This has burned this project three times — `kGutterWidth`
46→75→52, `kPixelsPerMinute` 4.0→5.5→4.0, `kLiveRowReservedHeight` 240→232.
Real browser or it does not count.

## Tools & Libraries

- **Playwright** — global npm install. Prefix with
  `export NVM_DIR=$HOME/.nvm && . $NVM_DIR/nvm.sh` then `NODE_PATH=$(npm root -g)`;
  node is nvm-only and not on a non-login shell's PATH.
- **Chromium launch args** — `--use-gl=swiftshader --enable-unsafe-swiftshader`,
  to avoid the `CONTEXT_LOST_WEBGL` blank page (CLAUDE.md trap #2). Viewport
  430×930 at DPR 1, so screenshot pixels are logical pixels.
- **Pillow** (system python3) for measurement scripts. No venv needed.
