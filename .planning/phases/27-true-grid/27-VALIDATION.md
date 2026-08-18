---
phase: 27
slug: true-grid
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-18
---

# Phase 27 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `27-RESEARCH.md` "Validation Architecture".

---

## The load-bearing split for this phase

Read this before writing any acceptance criterion. **This phase's defect is invisible to
`flutter test`** — 240dp and 372dp both satisfy all 560 existing tests, because those tests assert
`yFor()` against the same arithmetic the implementation performs. The grid is verified against
itself. So "the suite is green" is *not* evidence that this phase worked.

| Claim class | Where it is trustworthy | Examples in this phase |
|---|---|---|
| **Arithmetic / geometric** — computed from `int` minutes and `kPixelsPerMinute`, no glyph metrics | ✅ `flutter test` | `yFor()` is branch-free; `yFor(h+60) − yFor(h) == 60 × kPixelsPerMinute` at every boundary with a live chunk present; `heightFor(liveStart, liveDuration) == duration × kPixelsPerMinute`; `Positioned.height` values; `ClipRect`/`OverflowBox` presence |
| **Glyph / layout metric** — depends on real Roboto advance widths and line heights | ❌ **real browser only** | `kCompactLiveMinHeight`'s actual value; whether the compact tier fits its 100dp slot without clipping; whether the single-line tier stays under 20dp; title ellipsis behaviour; icon-button sizing |
| **Rendered-pixel** — what a human actually sees | ❌ **real browser only** | GRID-01 end-to-end: that the *painted* hour spacing is uniform, not merely that the geometry function is linear |

`flutter test`'s placeholder font has no real Roboto metrics — `kGutterWidth`'s own doc comment
records that `'1'`, `'i'`, `'W'`, `':'` and `'p'` all measure exactly 12.0px at fontSize 12. This
project has shipped a wrong constant from that harness three times (`kGutterWidth` 46→75→52,
`kPixelsPerMinute` 4.0→5.5→4.0, `kLiveRowReservedHeight` 240→232). **Do not make it four.**

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (bundled with the Flutter SDK) + a standalone real-browser measurement step that is **not** `flutter_test` |
| **Config file** | none — standard `flutter test` discovery of `test/**/*_test.dart` |
| **Quick run command** | `flutter test test/screens/today_timeline_model_test.dart` (pure geometry, no widget pump) |
| **Full suite command** | `flutter test` |
| **Independent ground truth** | `python3 .planning/spikes/001-live-row-in-a-true-grid/tools/measure_hours.py <screenshot.png>` — prints `UNIFORM` / `NOT UNIFORM` |
| **Screenshot driver** | `NODE_PATH=$(npm root -g) node .planning/spikes/001-live-row-in-a-true-grid/tools/drive.cjs <url> <profileDir> <out.png> --at=HH:MM` |
| **Estimated runtime** | full suite ~60s; the real-browser step ~4 min including a debug web build |

`flutter`/`dart` are at `/home/dan/development/flutter/bin`; node is nvm-only
(`export NVM_DIR=$HOME/.nvm && . $NVM_DIR/nvm.sh`).

---

## Sampling Rate

- **After every task commit:** `flutter test test/screens/today_timeline_model_test.dart test/screens/today_screen_test.dart` — the two files this phase touches.
- **After every plan wave:** `flutter test` (full suite) — catches anything else importing `kLiveRowReservedHeight`.
- **Phase gate (mandatory, cannot be skipped, cannot be substituted by a green suite):**
  1. full `flutter test` green, and
  2. `measure_hours.py` prints **`UNIFORM`** against a real-browser screenshot taken **while a chunk is live**, from a debug build (`flutter build web --debug --source-maps --pwa-strategy=none`) served by `tools/serve-uat.py` on a **fresh, never-before-used port** (CLAUDE.md trap #1 — 8134 has now served spike builds, so pick a new one).
- **Max feedback latency:** ~60s for the automated half.

---

## Per-Task Verification Map

> Task IDs are filled in by `gsd-planner`. The Test Type column is the binding part: any row
> marked **real-browser** must not be signed off on a `flutter test` result.

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------|-------------------|--------|
| {27-01-01} | 01 | 1 | GRID-01 | unit (arithmetic) | `flutter test test/screens/today_timeline_model_test.dart` | ⬜ pending |
| {27-01-02} | 01 | 1 | GRID-01 | unit (arithmetic) — equidistance, the test the suite has always been missing | `flutter test test/screens/today_timeline_model_test.dart` | ⬜ pending |
| {27-0x} | — | — | GRID-02 | widget (structural) | `flutter test test/screens/today_screen_test.dart` | ⬜ pending |
| {27-0x} | — | — | GRID-02 | **real-browser** — `kCompactLiveMinHeight` measurement | screenshot + pixel count (see recipe) | ⬜ pending |
| {27-0x} | — | — | GRID-01 | **real-browser** — end-to-end uniformity | `measure_hours.py` → `UNIFORM` | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

No new test *files* and no fixture work are needed — both consumer test files already exist with
the relevant groups, and `today_screen_test.dart`'s `buildDayFixture()` / `longDayFixture()` /
`twoChunkFixture()` helpers already cover the live-chunk durations this phase needs (a 5-minute
break for the single-line tier, a 25-minute work chunk for the compact tier).

- [x] Test infrastructure exists — `flutter_test`, no install needed.
- [x] Measurement tooling exists — `drive.cjs` and `measure_hours.py`, reusable unmodified.
- [ ] **The real-browser measurement task must be scheduled explicitly**, sequenced *after* the
      compact tier lands (its natural height cannot be measured before it exists). This is not a
      missing framework — it is a categorically different verification step that `flutter test`
      cannot cover, and it must appear as its own task rather than being folded into a
      "run the tests" step.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Rendered hour spacing is uniform while a chunk is live | GRID-01 | Placeholder-font harness cannot see rendered pixels; this is the exact bug class the suite is blind to | Debug web build → `serve-uat.py` on a fresh port → `drive.cjs --at=<mid-chunk>` → `measure_hours.py` must print `UNIFORM` |
| `kCompactLiveMinHeight`'s value | GRID-02 | Roboto-glyph-driven natural height; three prior constants were wrong when derived from the harness | Follow `27-UI-SPEC.md`'s 9-step re-measurement recipe; pixel-count the `primaryContainer` fill; set the constant from the result, not from the `88.0` placeholder |
| Compact tier does not clip inside its 100dp slot | GRID-02 | Same glyph-metric class | Visual inspection of the real-browser screenshot at a live 25-min work chunk |
| Single-line tier stays legible in a 20dp slot | GRID-02 | Same | Real-browser screenshot at a live 5-minute break |
| Now-line crossing the live card remains legible | GRID-02 | Subjective legibility judgement | Screenshot at two points in the same chunk (early and late) so the rule lands in different places |
| 36×36dp Complete/Skip targets are usable | GRID-02 (UI-SPEC declared exception) | Below WCAG 44dp; accepted as a stated trade, flagged by the UI checker for UAT confirmation | Confirm during UAT, including at a larger text scale |

**Not covered by this phase's verification, and deliberately so** (inherited from the spike's own
"What This Does NOT Claim"): dark theme, desktop widths, large accessibility text scales, and the
`Overdue` live state. The GRID-01 arithmetic holds across all of them; the *fit* claims do not
automatically.

---

## Validation Sign-Off

- [ ] All tasks have an `<automated>` verify command or an explicit real-browser measurement step
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Every **real-browser** row was signed off on a screenshot, not on a green suite
- [ ] The equidistance test asserts against `60 × kPixelsPerMinute` — an independent ground
      truth — and **never** re-derives `liveExtraPx`, or it inherits the same blindness
- [ ] `measure_hours.py` printed `UNIFORM` with a chunk live
- [ ] No watch-mode flags
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
