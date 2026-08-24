---
phase: 30
slug: breaks-in-committed-time
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-08-24
---

# Phase 30 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Seeded from `30-RESEARCH.md` § "Validation Architecture".

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (bundled — Flutter 3.44.1 / Dart 3.12.1) |
| **Config file** | none — standard `flutter test` convention |
| **Quick run command** | `flutter test test/services/schedule_generator_test.dart --concurrency=1` |
| **Full suite command** | `flutter test --concurrency=1` |
| **Estimated runtime** | ~5s quick / ~60s full (587 tests at baseline) |

**`--concurrency=1` is not optional for the RED→GREEN evidence capture.** At default concurrency
the expanded reporter drops and duplicates per-test-name lines at this suite's scale, which makes a
by-name RED→GREEN cross-check unverifiable. Established in Phase 28 (`28-03-SUMMARY.md`),
re-confirmed by this phase's research.

**PATH note:** `flutter`/`dart` are not on the default shell PATH on this machine —
`export PATH="$PATH:/home/dan/development/flutter/bin"` first.

---

## Sampling Rate

- **After every task commit:** `flutter test test/services/schedule_generator_test.dart --concurrency=1`
- **After every plan wave:** `flutter test --concurrency=1` (full suite)
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** ~5 seconds (quick), ~60 seconds (full)

The full suite at every wave boundary is deliberate and not redundant here: this phase's verified
blast radius is 4 tests in one file, but commitment-block breaks flow through
`buildTimeline`/`chunk_card.dart` for the **first time**, so the D-06 render-layer tests
(`lattice_break_pair_test.dart`) need re-confirming even though nothing in `lib/screens/` changes.

---

## Per-Task Verification Map

Task IDs are filled in by the planner. Both requirements are automatable in full — this is integer
arithmetic, not glyph metrics, so `flutter test` assertions are trustworthy here (STATE.md
carry-forward invariant).

| Req | Behavior | Test Type | Automated Command | File Exists | Status |
|-----|----------|-----------|-------------------|-------------|--------|
| COMMITBREAK-01 | A break is emitted between consecutive work chunks inside a commitment block, on the 25+5 lattice | unit | `flutter test test/services/schedule_generator_test.dart --concurrency=1` | ✅ extended with the COMMITBREAK-01 group (30-01) | ✅ green — both entry points: generator (wave 2, 30-03) and `addEventToday` (wave 3, 30-04, `COMMITBREAK-01/ADD-EVENT`) |
| COMMITBREAK-02 | The commitment's own start and end times are unchanged (D-01 preserved) | unit | same file — assert `block.startMinutes`/`endMinutes` unchanged across every fixture in the research's tail-arithmetic table | ✅ extended existing `LATTICE-01/D-01` GUARD 7, plus `COMMITBREAK-02/D-01` (30-01) and `COMMITBREAK-02/ADD-EVENT` (30-02) | ✅ green — both entry points |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

Full evidence: `.planning/phases/30-breaks-in-committed-time/30-GREEN-wave2.txt` (generator
path, wave 2) and `30-GREEN-final.txt` (notifier path + phase-closing full-suite
cross-check, wave 3). 597 tests, 597 passed, 0 failed; `flutter analyze` clean.

---

## Wave 0 Requirements

None. `test/services/schedule_generator_test.dart` already exists with a rich fixture library
(`makeBlock`, `makeHabit`, …) that this phase's regression tests extend directly.

**But do not make `makeBlock`'s default 60-minute window the primary fixture** — it produces the
degenerate zero-remainder case and would prove almost nothing about the tail. The primary fixture
should be the ROADMAP's own reproduction (`Work` 09:00–11:40, a 160-minute window), which exercises
the boundary, the cadence interaction, and a non-trivial tail stretch in one go — and is the exact
shape the owner's screenshot matched.

*Existing infrastructure otherwise covers all phase requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| A generated day, seen in the running app, has breaks inside the committed `Work` block | COMMITBREAK-01 | **Not** because the assertions are untrustworthy — they are trustworthy, this is the same arithmetic category as Phase 28, which needed no human gate. Because the owner has now reported this exact symptom **twice** (2026-08-21, 2026-08-24) and only a generated-day screenshot closes it credibly. | Build debug + serve on port 8143 (`flutter build web --debug --source-maps --pwa-strategy=none`, then `python3 tools/serve-uat.py 8143 --dir build/web`). **The instructions MUST tell the human to ⟳ Re-check-in first** — see below. |

### Trap #4, data layer — required in the UAT's own text

`ScheduleNotifier._loadToday()` reads today's schedule from Hive, and `generate()` runs only at
check-in. **An already-generated day is never regenerated on load**, so any engine change is
invisible in the running app until ⟳ Re-check-in. A UAT that tests generator output and omits this
produces a false failure — it already did exactly that on 2026-08-21, costing the owner a round
trip and letting the real defect survive three more days.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (n/a — none)
- [x] No watch-mode flags
- [x] Feedback latency < 60s
- [x] Primary regression fixture is a **commitment block**, not a goal
- [ ] UAT instructions include the ⟳ re-check-in step (trap #4) — belongs to plan 30-05, not yet run
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** automated verification complete (597/597 tests, `flutter analyze` clean, both
entry points GREEN by name — see `30-GREEN-wave2.txt` and `30-GREEN-final.txt`); the UAT
screenshot itself (Manual-Only Verifications table above) is deferred to plan `30-05` per the
phase's own sequencing.
