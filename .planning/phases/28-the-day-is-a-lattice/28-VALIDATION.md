---
phase: 28
slug: the-day-is-a-lattice
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-19
---

# Phase 28 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `28-RESEARCH.md` § Validation Architecture.

**This phase is 100% automatable.** It is integer arithmetic over minutes with no glyph metrics
anywhere near it. **No real-browser step is required.** Phase 27 needed pixel measurement because
its grid was verified against itself; that ceremony must NOT be copied here. If a task in this phase
proposes a headless-Chromium measurement, that is a planning error.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (bundled with Flutter SDK 3.44.1) — already wired, 567 passing tests today |
| **Config file** | none — standard `flutter test` discovery over `test/` |
| **Quick run command** | `flutter test test/services/schedule_generator_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | <1s quick (62 tests); ~17s full (567 tests) |

`flutter` is at `/home/dan/development/flutter/bin` — not on PATH in non-login shells. Add it
explicitly.

---

## Sampling Rate

- **After every task commit:** `flutter test test/services/schedule_generator_test.dart`
- **After every plan wave:** `flutter test` (full suite)
- **Before `/gsd-verify-work`:** full suite green AND `flutter analyze` clean
- **Max feedback latency:** ~17 seconds (full suite)

Baseline to beat, recorded 2026-08-19 at `0cba546`: **567 tests green, `flutter analyze` clean.**
The suite must not shrink — the ~10 tests that go RED under this change are to be **rewritten to the
new lattice shape, not deleted.**

---

## Per-Task Verification Map

Task IDs are assigned by the planner; this map fixes the requirement-to-proof contract the plans
must satisfy. Every row is automatable — there are no exceptions in this phase.

| Requirement / Decision | Behavior to prove | Test Type | Automated Command | File Exists | Status |
|---|---|---|---|---|---|
| LATTICE-01 | Every generated chunk's start minute ≡ 0 (mod 30), across all 5 moods | unit | `flutter test test/services/schedule_generator_test.dart` | ✅ file / ❌ new assertion group — W0 | ⬜ pending |
| LATTICE-01 / D-02 | The invariant still holds for chunks scheduled *after* a fixed commitment ends off-boundary | unit | same | ❌ new — W0 | ⬜ pending |
| LATTICE-01 / D-03 | The invariant still holds on a mid-day start (`startFloorMinutes` rounds to 30, not 5) | unit | same | ⚠️ existing test pins the WRONG value — must be rewritten, proven RED first | ⬜ pending |
| LATTICE-01 / D-01 | A fixed commitment's own start time is NOT rounded — it keeps its wall-clock minute | unit | same | ❌ new — W0 | ⬜ pending |
| LATTICE-02 | Exactly the expected number of 30-minute long breaks emitted, each exactly 30 min, all 5 moods | unit | same | ❌ new — W0 | ⬜ pending |
| LATTICE-02 / D-05 | A long break landing on the day's LAST chunk is still emitted — the owner's exact day (mood 3, N=4, 4 chunks) produces a long break, not zero | unit | same | ❌ new — W0; **this is the regression that reproduces the reported bug** | ⬜ pending |
| LATTICE-02 | The Nth work chunk still closes its own 30-min cell with a 5-min break, AND the 30-min break follows as its own cell (not instead of it) | unit | same | ❌ new — W0 | ⬜ pending |
| D-04 | Chunk counts per mood are unchanged — `_moodCap` and day end did not move | unit | same | ⚠️ existing count assertions serve as the guard | ⬜ pending |
| D-06 | Two consecutive break chunks at a cadence boundary render without breaking any downstream consumer | widget | `flutter test` | ❌ new — W0 | ⬜ pending |
| Regression | Full suite still green, no test deleted | suite | `flutter test` | ✅ | ⬜ pending |
| Regression | Static analysis clean | lint | `flutter analyze` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] New assertion group in `test/services/schedule_generator_test.dart` for the mod-30 invariant
      across all 5 moods (LATTICE-01) — no such test exists today.
- [ ] New assertion group for long-break count and duration across all 5 moods (LATTICE-02),
      **including a fixture where the cadence boundary is the day's literal last chunk.**
- [ ] Rewrite (do not delete) the ~10 existing tests named in `28-RESEARCH.md` § Blast Radius:
      Test 6, Test 7, all five `BREAK-01` mood tests, `BREAK-02`, and the `startFloorMinutes`
      rounding test. **Each must be proven RED against the unfixed code before the fix lands** —
      this project's carried-forward convention, and the only thing that distinguishes a real
      regression test from one that was written to match whatever the code already did.
- [ ] A widget-level test for the two-consecutive-break-chunks shape (D-06).

*Existing infrastructure otherwise covers this phase — no framework install needed.*

---

## Manual-Only Verifications

**All phase behaviors have automated verification.**

This is a deliberate, stated contract, not an oversight. Unlike Phase 27, nothing here depends on
rendered pixels, touch targets, or perceptual judgement. Do not add a human checkpoint to this
phase; if one seems necessary, the plan has drifted into UI work that belongs elsewhere.

---

## Validation Sign-Off

- [ ] All tasks have automated verify or a Wave 0 dependency
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references above
- [ ] No watch-mode flags (`flutter test` runs once and exits)
- [ ] Feedback latency < 20s
- [ ] Rewritten regression tests were each proven RED before the fix
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
