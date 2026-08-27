---
phase: 32
slug: breaks-you-can-tap
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-27
---

# Phase 32 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `32-RESEARCH.md` § Validation Architecture. Where this file and the research
> disagree, the research is the measured source and this file is wrong.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (bundled with Flutter SDK, `pubspec.yaml:44-45`) |
| **Config file** | none — Flutter's default test runner, no custom config |
| **Quick run command** | `flutter test test/screens/today_screen_test.dart test/screens/today_timeline_model_test.dart test/screens/today_row_widgets_test.dart test/screens/today_screen_now_state_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~16 seconds full suite (measured this session: 639 tests, green) |

**Note:** `flutter`/`dart` are at `/home/dan/development/flutter/bin` and are on PATH in login
shells. In a non-login shell, resolve them explicitly before running any command above.

---

## Sampling Rate

- **After every task commit:** Run the quick run command (4 files).
- **After every plan wave:** Run `flutter test` in full — 16s is cheap enough that there is no
  reason to ever run a partial suite at a wave boundary.
- **Before `/gsd-verify-work`:** Full suite green, **plus** the real-browser screenshot check,
  **plus** the human UAT. **None of the three substitutes for either of the others** — this is the
  whole lesson of Phases 27, 29, and 31.
- **Max feedback latency:** ~16 seconds.

---

## Per-Task Verification Map

> Task IDs are assigned by the planner. This table records the requirement→test-type mapping the
> plans must satisfy; the planner fills in Task ID / Plan / Wave.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | TBD | TBD | TAPBREAK-01 | — | N/A | widget (`tester.tap()`) | `flutter test test/screens/today_row_widgets_test.dart` | ❌ new this phase | ⬜ pending |
| TBD | TBD | TBD | TAPBREAK-01 (negative — no drag path survives on a break) | — | N/A | widget, negative assertion | `flutter test test/screens/today_screen_test.dart` | ❌ new this phase | ⬜ pending |
| TBD | TBD | TBD | TAPBREAK-02 | — | N/A | widget + pure-arithmetic unit | `flutter test test/screens/today_timeline_model_test.dart test/screens/today_screen_test.dart` | ✅ exists — 3 literals + `kPixelsPerMinute` need re-derivation | ⬜ pending |
| TBD | TBD | TBD | TAPBREAK-03 (structural — Card, not hairline) | — | N/A | widget (structural) | `flutter test test/screens/today_row_widgets_test.dart test/screens/today_screen_test.dart` | ❌ tier-boundary test needs rewriting — its 3-tier premise is retired | ⬜ pending |
| — | — | — | TAPBREAK-03 (perceptual — "reads as a section of the day") | — | N/A | **manual only** | none — structurally unautomatable | n/a | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

**None.** The test framework, harness, and every helper the phase needs
(`_FakeScheduleNotifierWithSchedule`, `pumpLiveRowCard`, `breakBoundaryFixture`,
`skipTracerFixture`) already exist and are reused, not built new.

*Existing infrastructure covers all phase requirements.*

---

## Manual-Only Verifications

**This section is the point of this file.** Three claims this phase makes cannot be settled by
`flutter test` at all — not "are hard to test," but *structurally cannot be tested*. This project
has been contradicted by a real thumb on a green suite three times (Phase 27, Phase 29, Phase 31
round one), and once by a defect no assertion could ever catch (Phase 31 round two: an icon that was
perfectly legible and meant the wrong verb).

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| The compact tier's real content — one `bodySmall` line, zero margin, inside a bordered `Card` at 30dp — fits without clipping or visually crowding the border | TAPBREAK-03 | `flutter test`'s placeholder font inflates glyph metrics. This project's own history proves the harness gets this wrong: `kGutterWidth` (46→75→52) and `kCompactLiveMinHeight` (88→84→88) were both *wrong* when first set from it. A widget test asserting "no `RenderFlex overflow` exception" passes happily while real Roboto text crowds the border — no exception is thrown for ugly. | Real-browser screenshot. `flutter build web --debug --source-maps --pwa-strategy=none`, serve with `python3 tools/serve-uat.py 8143 --dir build/web`, render headless Chromium with `--use-gl=swiftshader --enable-unsafe-swiftshader`. **Kill whatever is squatting 8143 first** — a stale server from Phase 31's UAT (started 2026-08-26 08:06:46) was still listening as of this research. |
| The redesigned break card "reads as a section of the day" rather than merely "is not clipped" | TAPBREAK-03 | A perceptual judgment, structurally identical to Phase 29's own stated boundary ("can a person see that this is a break") and to Phase 31 round two's defect class — a rendered, legible, structurally-correct element that communicates the wrong thing to a human. | Human UAT on a real device. |
| The Skip rail reads unambiguously as **one** tappable unit at 30dp, not two separate zones | TAPBREAK-01 | Exactly the category of defect that ended Phase 31: a glyph choice that is legible but misleading. A widget test can prove the rail is one `InkWell` (mechanically one tap target); it cannot prove a human perceives it as one. | Human UAT on a real device. Ask directly, do not infer from "no complaints." |
| D-31-07's `LiveRowCard` compact-tier Skip button still works and reads correctly under the new surface | (inherited from Phase 31) | Code-complete and test-proven at 639/639, but **never confirmed by a human on a device** — the owner did not reach Item 3 of Phase 31's round-two UAT, and this phase changes the surface underneath it. | Human UAT. Re-ask it explicitly; it is not settled. |
| The "Up next" transition when a live break is skipped | (open question, unruled) | `resolveNowState`'s advance-past-resolved loop (`now_state.dart:176`) delists a skipped live break from "current," so the header switches to the next chunk while the now-line does not move. Whether that is right is a design judgment the owner has not made. | Human UAT — surface it as a question, not a pass/fail item. Flagged in Phase 31's round-two UAT and still unanswered. |

**MANDATORY, not a suggestion (CLAUDE.md trap #4):** any UAT that judges timeline or
scheduling-engine output **must ⟳ Re-check-in first**, and that step must appear **first and marked
mandatory** in the UAT's own instructions. `ScheduleNotifier._loadToday()` reads today's schedule
straight from Hive and an already-generated day is never regenerated on load — so a
`kPixelsPerMinute` change is invisible in the running app until Re-check-in, *even though*
`curl | grep` on `main.dart.js` will correctly confirm the new code shipped. On 2026-08-21 this
exact omission produced a false failure and let a real defect survive three more days.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or are listed under Manual-Only above
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references *(n/a — no Wave 0 gaps)*
- [ ] No watch-mode flags
- [ ] Feedback latency < 20s
- [ ] Every pixel assertion derives from `kPixelsPerMinute` rather than restating a literal
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
