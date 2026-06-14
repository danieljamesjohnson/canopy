---
phase: 17
slug: time-anchored-home
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-13
---

# Phase 17 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (pure unit tests for `resolveNowState` + widget tests for Home) |
| **Config file** | none — built into Flutter SDK |
| **Quick run command** | `flutter test test/screens/home_now_state_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run the quick command for the touched test file(s)
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| _to be filled by planner_ | | | | unit/widget | | | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] NEW pure unit test file covering `resolveNowState(chunks, now)` across the four states: pre-start (now before first window), active (now in a window), between/overdue (now between windows or past an unresolved window), day-complete (now after last window). Use injectable `now` — no global DateTime mocking.
- [ ] Widget test(s) for HomeScreen at simulated times (6am→pre-start, 8am→active, 6pm-nothing-done→time-anchored-not-8am, after-last→day-complete) and timer/lifecycle (pause on background, resume on foreground).
- [ ] Update the existing `active_chunk_card_test.dart` "All done today!" assertion to expect the new day-complete copy ("That's a wrap").

*Existing helpers (`pumpWithMood`) cover infrastructure; no new framework install.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Now/Next update live as wall-clock time passes | NOW-01 | Real elapsed time + app foreground | Leave Home open across a chunk boundary; confirm Now advances without manual action |
| Pre-start and day-complete states render correctly on device | NOW-02 | Visual confirmation | Open Home before first chunk (pre-start) and after last chunk window (day-complete) |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
