---
phase: 31
slug: breaks-you-can-skip
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-25
---

# Phase 31 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Seeded from `31-RESEARCH.md` § Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (bundled with the Flutter SDK — no install needed) |
| **Config file** | none — standard `flutter test` discovery over `test/**/*_test.dart` |
| **Quick run command** | `flutter test test/screens/today_row_widgets_test.dart test/providers/schedule_notifier_break_extension_test.dart test/screens/today_screen_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | quick ~20s · full suite ~90s (598 tests green as of Phase 30) |

---

## Sampling Rate

- **After every task commit:** Run the quick command above
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite green **and** `flutter analyze` clean
- **Max feedback latency:** ~20 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 31-01-T1 | 31-01 | 1 (Wave-0 gap) | SKIPBREAK-01 (the end-to-end tracer drag, proven RED first) | — | N/A | widget | `flutter test test/screens/today_screen_test.dart` | ❌ W0 — no `tester.drag` pattern exists anywhere in this repo | ⬜ pending |
| 31-01-T2 | 31-01 | 1 | SKIPBREAK-01 + SKIPBREAK-02 (the vertical slice: constants, promoted `Dismissible`, grown envelope, Layer 1b pass) | T-31-01, T-31-02 | `markSkipped`'s `chunkId` is app-generated, never external input | widget | `flutter test test/screens/today_screen_test.dart test/screens/today_row_widgets_test.dart` | ✅ after 31-01-T1 | ⬜ pending |
| 31-02-T1 | 31-02 | 2 | D-31-04 (skipped visual at full / compact / sub-compact) | T-31-04, T-31-05 | new `Semantics` labels carry no user-authored content | widget | `flutter test test/screens/today_row_widgets_test.dart` | ✅ extend `break densities` group (~:629) | ⬜ pending |
| 31-02-T2 | 31-02 | 2 | SKIPBREAK-01 prohibition (a break stays untappable and uncompletable at every density) | — | N/A | widget | `flutter test test/screens/today_row_widgets_test.dart` | ✅ new group | ⬜ pending |
| 31-04-T1 | 31-04 | 2 | D-31-05 (`_absorbReclaimedTimeIntoNextBreak` never moves an already-skipped break) | T-31-07 | guard prevents silent persisted-state divergence | unit | `flutter test test/providers/schedule_notifier_break_extension_test.dart --concurrency=1` | ✅ extend `G-05 no-op guards` — **must be proven RED first** | ⬜ pending |
| 31-04-T2 | 31-04 | 2 | D-31-05 (the fix; original G-05 absorption preserved) | T-31-07 | one-line guard, no other behavioural change | unit | `flutter test test/providers/schedule_notifier_break_extension_test.dart` | ✅ | ⬜ pending |
| 31-04-T3 | 31-04 | 2 | Streak inertness + D-31-03 (skipping a break writes no `Goal` and moves no chunk) | T-31-08, T-31-03 | habit-streak write-back proven unreachable from a break skip | unit | `flutter test test/providers/` | ✅ guard already exists; the assertion converts it from assumed to proven | ⬜ pending |
| 31-03-T1 | 31-03 | 3 | SKIPBREAK-01 (both slop bands resolve to the break; negative no-theft case; below-threshold drag) | T-31-02, T-31-06 | contested-overlap resolution pinned against a silent re-merge of the Layer 1b pass | widget | `flutter test test/screens/today_screen_test.dart` | ❌ W0 (extends 31-01-T1's group) | ⬜ pending |
| 31-03-T2 | 31-03 | 3 | SKIPBREAK-02 (painted extent per resolved state, adjacency, total timeline height, break-free day, mixed day) | — | N/A | widget | `flutter test && flutter analyze` | ✅ SEEBREAK-02's test is the template | ⬜ pending |
| 31-05-T1 | 31-05 | 4 | Served bytes == built bytes, and this phase's own string is in the bundle | T-31-10 | sha256 + bundle grep before the owner is asked to look | shell | `test "$(sha256sum build/web/main.dart.js \| cut -d' ' -f1)" = "$(curl -s http://danserver:8143/main.dart.js \| sha256sum \| cut -d' ' -f1)"` | n/a | ⬜ pending |
| 31-05-T2 | 31-05 | 4 | SKIPBREAK-01 + SKIPBREAK-02 + D-31-03/04 (human) | T-31-09, T-31-10 | mandatory ⟳ Re-check-in Step 0 (CLAUDE.md trap #4) | manual | none — blocking `checkpoint:human-verify` on a real touch device | n/a | ⬜ pending |

*Task IDs are filled in by the planner. Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] A new widget-test group covering the **grown hit-test envelope** — `grep` for
      `tester.drag` / `dragFrom` returns **zero** hits in this codebase, so this is genuinely new
      test territory, not an extension of an existing pattern. `31-RESEARCH.md` § Code Examples has
      a starting sketch, not a finished pattern.
- [ ] D-31-05's regression test, **proven RED against the unfixed guard list first**. Extends
      `test/providers/schedule_notifier_break_extension_test.dart`'s `G-05 no-op guards` group;
      fixture pattern already established, no new helper needed.
- [ ] The `checkpoint:human-verify gate="blocking"` task itself.

*No framework install gap — `flutter_test` is already wired.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| A real thumb can actually skip a 5-minute break's 20dp row | SKIPBREAK-01 | `flutter test` fires synthetic drags at exact coordinates and **does not model finger size**. A 52dp *invisible* band whose edges the user cannot see is a physical question no assertion settles. Phase 27 scored 16/17 automated then failed 2 of 3 human items; Phase 29 went 587-green while the owner looked at a screen with no breaks on it. | Build `flutter build web --debug --source-maps --pwa-strategy=none`; serve with `python3 tools/serve-uat.py 8143 --dir build/web` (port 8143 already claimed for this project's debug builds, per Phase 29/30); open on a **phone**, not a desktop pointer. |
| Sub-compact skipped state is legible at `Opacity(0.5)` | D-31-04 | The sub-compact divider/label already render at `outlineVariant`/`onSurfaceVariant` — low-contrast tones. Halving opacity again is a plausible legibility risk no desk analysis settles. If unreadable, raise the opacity **for that tier only** and document the new value. | Same served build; compare a skipped 5-minute break against an unresolved one at arm's length. |
| Nothing else on the day moved when a break was skipped | D-31-03 | The engine claim ("mark it skipped and move on" — the day is **not** pulled forward) is only trustworthy against a real generated day. | **⟳ Re-check-in FIRST — mandatory, CLAUDE.md trap #4.** Note the start time of the work chunk following the break, skip the break, confirm that start time is unchanged. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 20s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
