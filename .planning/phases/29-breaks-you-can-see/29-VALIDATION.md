---
phase: 29
slug: breaks-you-can-see
status: approved
nyquist_compliant: true
wave_0_complete: false
created: 2026-08-20
updated: 2026-08-20
---

# Phase 29 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (bundled with the Flutter SDK) — already wired; 579 tests green as of 2026-08-20 |
| **Config file** | none — standard `flutter test` discovery over `test/` |
| **Quick run command** | `flutter test test/screens/today_timeline_model_test.dart test/screens/today_screen_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | quick: a few seconds (two files); full: ~26 seconds (579 tests) |

> Flutter is not on the default non-login-shell PATH. Use
> `/home/dan/development/flutter/bin/flutter`.

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/screens/today_timeline_model_test.dart test/screens/today_screen_test.dart`
- **After every plan wave:** Run `flutter test` (baseline to beat: 579 green, `flutter analyze` clean)
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

**Phase gate is deliberately stricter than a green suite.** All four must hold: full suite green,
`flutter analyze` clean, `measure_hours.py` prints `UNIFORM` against a real-browser screenshot that
contains a sub-compact break, and the `checkpoint:human-verify` task returns a recorded verdict.
Phase 27 scored 16/17 automated and then failed 2 of 3 human items — a green suite does not close
this phase.

---

## Per-Task Verification Map

> Filled from the finalized plan set (29-01 … 29-04), verified by gsd-plan-checker on 2026-08-20.
> All `flutter` commands require `export PATH="$PATH:/home/dan/development/flutter/bin"` first.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 29-01-01 | 01 | 1 | SEEBREAK-01 (inert `subCompact` scaffold: enum value, placeholder constant, shared row widget, both `_WorkChunkContent` switch arms — renders nothing new) | — | N/A (pure layout, no I/O) | regression | `flutter test` (must stay 579 green) + `flutter analyze` | ✅ existing files | ⬜ pending |
| 29-01-02 | 01 | 1 | SEEBREAK-01 (five ChunkCard-level assertions about what a sub-compact break IS — proven RED) | — | N/A | widget | `flutter test test/screens/today_row_widgets_test.dart` | ✅ existing file, new group | ⬜ pending |
| 29-01-03 | 01 | 1 | SEEBREAK-02 (screen-level tier boundary + `heightFor()` ground-truth literals; RED evidence file) | — | N/A | widget + unit | `flutter test --concurrency=1 test/screens/today_screen_test.dart test/screens/today_timeline_model_test.dart` | ✅ existing files, new tests | ⬜ pending |
| 29-02-01 | 02 | 2 | SEEBREAK-01, SEEBREAK-02 (wire `_buildBreak`'s branch + the screen's three-band ternary — `lib/` only) | — | N/A | widget + unit | `flutter test` (587 expected) + `flutter analyze` | ✅ existing files | ⬜ pending |
| 29-02-02 | 02 | 2 | SEEBREAK-02 (by-name RED→GREEN cross-check; `git diff --stat` proves no test file moved) | — | N/A | evidence capture | `flutter test --concurrency=1` → `29-GREEN-final.txt` | ✅ produced by task | ⬜ pending |
| 29-03-01 | 03 | 3 | SEEBREAK-01 (real-browser measurement: port 8143, sha256 served-vs-built check, forced-compact screenshot, `measure_card_extent.py`) | — | N/A | manual-assisted (scripted, real browser) | `python3 .planning/phases/29-breaks-you-can-see/tools/measure_card_extent.py <shot>` | ❌ W0 — script written by this task | ⬜ pending |
| 29-03-02 | 03 | 3 | SEEBREAK-01 (set `kSubCompactBreakMinHeight` from the measurement, rewrite the doc comment, tear out the forcing edit) | — | N/A | unit + source assertion | `flutter test` + `grep -c UNMEASURED lib/screens/today/timeline_geometry.dart` → 0 for this constant | ✅ existing file | ⬜ pending |
| 29-04-01 | 04 | 4 | SEEBREAK-02 (grid `UNIFORM` in painted pixels with a sub-compact break present) | — | N/A | manual-assisted (scripted, real browser) | `python3 .../measure_hours.py shots/uniform-subcompact-break.png` | ❌ W0 — harness cribbed from Phase 27 | ⬜ pending |
| 29-04-02 | 04 | 4 | ROADMAP item 4 — 25-min work chunk's fit inside its 100dp slot; binary DISMISSED / REAL-DEFECT disposition | — | N/A | manual-assisted (real-browser screenshot) | `python3 .../measure_card_extent.py shots/work-chunk-fit.png` | ❌ W0 | ⬜ pending |
| 29-04-03 | 04 | 4 | Human UAT — a 5-minute break reads as *a break*, not a divider | — | N/A | manual (**blocking gate**) | `checkpoint:human-verify` on `http://danserver:8143/`, verdict recorded in `29-UAT.md`, pre-flight sha256 so no stale bundle is judged | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `.planning/phases/29-breaks-you-can-see/shots/` — screenshot output directory does not exist yet.
- [ ] `.planning/phases/29-breaks-you-can-see/tools/` — measurement harness adapted from Phase 27's
      `.planning/spikes/001-live-row-in-a-true-grid/tools/` (`drive.cjs` reusable verbatim,
      `measure_hours.py` reusable verbatim, band-detection adapted for a dashed outline rather than
      a solid fill).
- [ ] A throwaway mechanism to force the currently-unreachable `compact` break tier to render for
      measurement — built and torn down inside the measurement task, never left standing.
- [ ] No test-framework install needed — `flutter_test` is fully wired and green.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| A 5-minute break reads as *a break* to a human eye, not as a divider between two work cards | SEEBREAK-01 | Perceptual judgement; no assertion settles it. `flutter test`'s placeholder font inflates glyph metrics so a widget test can call a break legible when it is not, and headless Chromium's `CONTEXT_LOST_WEBGL` (CLAUDE.md trap #2) can return a blank screenshot readable as either a pass or a false failure. | Build `flutter build web --debug --source-maps --pwa-strategy=none`, serve with `python3 tools/serve-uat.py 8143 --dir build/web` (port 8143 — never previously used, avoids CLAUDE.md trap #1), open `http://danserver:8143/` on a real device, generate a mood-4 day, and judge whether each 5-minute break reads as a break. |
| The measured sub-compact threshold is a real-device number, not a harness bound | SEEBREAK-01 | STATE.md carry-forward invariant: text-driven measurements asserted in `flutter test` are harness bounds. Phase 27's `kCompactLiveMinHeight` went placeholder 88.0 → measured 84.0 by exactly this route. | Real-browser screenshot + pixel measurement; record the raw number, the method, and the conditions that would invalidate it in the constant's doc comment. |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references — the `tools/` script and `shots/` directory are created
      inline by 29-03 Task 1 before any measurement is trusted
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-08-20 (gsd-plan-checker, `## VERIFICATION PASSED`, 4 plans, 0 blockers)

`wave_0_complete` stays `false` deliberately — the measurement harness does not exist on disk yet;
29-03 Task 1 builds it. Flip it when that task lands.
