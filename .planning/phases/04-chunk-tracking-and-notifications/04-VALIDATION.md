---
phase: 04
slug: chunk-tracking-and-notifications
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-02
---

# Phase 04 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (bundled with Flutter SDK) |
| **Config file** | none — uses `flutter test` runner directly |
| **Quick run command** | `flutter test` |
| **Full suite command** | `flutter test && flutter analyze` |
| **Estimated runtime** | ~10 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test`
- **After every plan wave:** Run `flutter test && flutter analyze`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 01 | 1 | markComplete appends CompletionLog | unit | `flutter test test/providers/schedule_notifier_test.dart` | ❌ W0 | ⬜ pending |
| 04-01-02 | 01 | 1 | markSkipped sets isSkipped flag | unit | `flutter test test/providers/schedule_notifier_test.dart` | ❌ W0 | ⬜ pending |
| 04-01-03 | 01 | 1 | CompletionLog append is idempotent | unit | `flutter test test/repositories/completion_log_repository_test.dart` | ❌ W0 | ⬜ pending |
| 04-02-01 | 02 | 1 | Dismissible does not remove card | widget | `flutter test test/screens/schedule_screen_test.dart` | ❌ W0 | ⬜ pending |
| 04-03-01 | 03 | 2 | JSON export produces valid JSON | unit | `flutter test test/services/export_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/providers/schedule_notifier_test.dart` — stubs for markComplete/markSkipped
- [ ] `test/repositories/completion_log_repository_test.dart` — append-only invariant
- [ ] `test/services/export_test.dart` — JSON serialization correctness
- [ ] `test/screens/schedule_screen_test.dart` — Dismissible widget behavior

*Existing infrastructure covers test runner and analyze; Wave 0 adds phase-specific test files.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Swipe right completes with haptic feedback | AC-1 | Haptic feedback requires physical device | Swipe right on a work chunk, verify haptic pulse and desaturated state |
| Morning notification fires at configured time | AC-3 | Scheduled notifications require real device clock | Set notification time to 1 min from now, wait, verify notification |
| Notification tap opens check-in screen | AC-3 | Deep link from notification requires device OS | Tap notification, verify app opens to mood check-in |
| Web banner appears when no schedule exists | AC-4 | Web-specific behavior | Open app in browser with no schedule, verify banner |
| Export downloads file on Web | AC-5 | Browser download behavior | Tap Export in settings on Web, verify JSON file downloads |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
