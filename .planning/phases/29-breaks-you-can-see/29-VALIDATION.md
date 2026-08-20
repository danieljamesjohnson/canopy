---
phase: 29
slug: breaks-you-can-see
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-20
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

> Task IDs are assigned by the planner. This map is keyed on requirement + behavior; the planner
> fills the Task ID column as plans are written.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | TBD | 1 | SEEBREAK-01 | — | N/A (pure layout, no I/O) | widget | `flutter test test/screens/today_screen_test.dart` | ✅ existing file, new group | ⬜ pending |
| TBD | TBD | 1 | SEEBREAK-01 (tier boundary: `subCompact` below threshold, `compact` at/above) | — | N/A | widget | `flutter test test/screens/today_screen_test.dart` | ✅ existing file, new test | ⬜ pending |
| TBD | TBD | 1 | SEEBREAK-01 (a11y label restates duration) | — | N/A | widget | `flutter test test/screens/today_screen_test.dart` | ✅ existing file, new test | ⬜ pending |
| TBD | TBD | 1 | SEEBREAK-02 (`heightFor()` equals ground-truth literals, not self-referential arithmetic) | — | N/A | unit | `flutter test test/screens/today_timeline_model_test.dart` | ✅ existing file, new test | ⬜ pending |
| TBD | TBD | 2 | SEEBREAK-02 (rendered grid `UNIFORM` in pixels with a sub-compact break present) | — | N/A | manual-assisted (scripted, real browser) | `python3 .planning/phases/29-breaks-you-can-see/tools/measure_hours.py <shot>` | ❌ W0 | ⬜ pending |
| TBD | TBD | 2 | ROADMAP item 4 — 25-min work chunk stays inside its 100dp slot, no visible clipping | — | N/A | manual-assisted (real-browser screenshot) | screenshot via `drive.cjs`, inspected with Read | ❌ W0 | ⬜ pending |
| TBD | TBD | final | Human UAT — a 5-minute break reads as *a break*, not a divider | — | N/A | manual | `checkpoint:human-verify` on the served debug build | N/A | ⬜ pending |

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

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
