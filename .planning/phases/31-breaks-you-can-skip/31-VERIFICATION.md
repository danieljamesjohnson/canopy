---
phase: 31-breaks-you-can-skip
verified: 2026-08-25T15:30:00Z
status: gaps_found
score: 12/12 code truths verified; human UAT judged 2026-08-26 — 2 of 3 items PASS, Item 1 (SKIPBREAK-01) FAILED
behavior_unverified: 0
overrides_applied: 0
behavior_unverified_items: []
human_verification:
  - test: "Item 1 (SKIPBREAK-01, 31-UAT.md): on a real phone/tablet, swipe a 5-minute break leftward five times at a natural thumb placement — does it reliably grab the break rather than the neighbouring work chunk, does the swipe complete (reveal + skip), and does it ever accidentally resolve the neighbour?"
    expected: "The break resolves to skipped; the neighbouring work chunk is never touched. flutter test proves this only for exact synthetic-drag coordinates (both slop bands, plus a no-theft negative case) — it does not and cannot model a fingertip's contact patch."
    why_human: "No assertion in this repository settles a real touch device's physical reliability; this project has twice shipped a green suite that a real thumb then contradicted (Phase 27, Phase 29)."
  - test: "Item 2 (D-31-04, 31-UAT.md): at arm's length, is a skipped break visually distinguishable from an unresolved one, and is the struck-through label still legible at Opacity(0.5) against onSurfaceVariant, sub-compact tier included?"
    expected: "Skipped state reads at a glance; the label is legible, not washed out."
    why_human: "Widget tests can assert the Opacity value is exactly 0.5 but cannot judge whether that value is legible on a real screen (31-02-SUMMARY.md coverage entry D6, flagged in advance as unsettleable from a desk)."
  - test: "Item 3 (D-31-03, 31-UAT.md): after Step 0 (⟳ Re-check-in) is performed, note the start time of the work chunk immediately after a break, skip that break, and confirm the start time is unchanged."
    expected: "No subsequent chunk moves. The engine-level guarantee (D-31-05's guard, no-Goal-write, no-other-chunk-move) is proven at the provider layer by plan 31-04's tests, but Item 3 is the end-to-end confirmation against a real generated day, gated on Step 0 having actually run (CLAUDE.md trap #4)."
    why_human: "Requires a live, real generated schedule and a human confirming the visual timeline; also requires confirming Step 0 was actually performed, which no test can do."
  - test: "PD-31-06 backstop truth (must_haves, plans 31-02/31-05): a currently-live break composing the live-row treatment with the skipped treatment (row keeps slot height, stays on timeline, does not move the now-line)."
    expected: "N/A as implemented — this is a recorded, deliberate exclusion, not a shipped behavior. `LiveRowCard.showActions` remains work-chunk-only (`chunk.chunkType == ChunkType.work`, today_screen.dart:1055), byte-for-byte unchanged from before this phase, and `LiveRowCard` itself has zero references to `isSkipped`/`isCompleted` anywhere in its source. A live break has no skip affordance at all, so the composition this truth describes cannot occur through any UI path this phase built."
    why_human: "This is a `verification: backstop` truth with no code path to exercise — per the honest-verifier contract it must ABSTAIN (insufficient_spec) rather than be silently marked passed. It is also PD-31-06, an explicitly recorded scope exclusion (31-01-PLAN.md), surfaced to the owner as UAT item 'Two things planning deliberately did NOT do #1' for his ruling (open a follow-up, seed it, or leave it) — that ruling has not yet been recorded in 31-UAT.md."
  - test: "PD-31-04-adjacent backstop truth (must_haves, plans 31-02/31-05): text-scale/long-text behavior at the 20dp sub-compact tier under this phase's changes."
    expected: "No new text length was introduced (strikethrough is a decoration flag; the full-tier swap to 'skipped' is shorter than 'N min'); large-text-scale behavior at sub-compact is inherited from Phase 29 and unchanged here."
    why_human: "verification: backstop — no held-out or property-based test exercises text-scale behavior at sub-compact in this phase's diff; grep/presence confirms no new string length was added, but per the honest-verifier contract that is not equivalent to confirmed evidence, so this abstains to insufficient_spec rather than a silent pass."
---

# Phase 31: Breaks You Can Skip — Verification Report

> **UPDATE 2026-08-26 — the human verification came back, and it changed the verdict.**
> This report's `status` moved `human_needed` -> `gaps_found`. The owner judged the three UAT items
> on a real phone after a real ⟳ Re-check-in: **Items 2 and 3 PASS, Item 1 FAILS.**
>
> - **Item 1 (SKIPBREAK-01) — FAIL.** *"hard to do this with a thumb."* Clarified on follow-up as an
>   **acquisition** failure (hard to grab the row), not a completion failure. `kBreakHitSlop = 16.0`
>   gives a 52dp band that clears both platform minimums on paper — but SKIPBREAK-02 makes that band
>   **invisible**, and those minimums assume a target the user can see. Full root cause and the
>   bounded-headroom analysis are in `31-UAT.md`'s Gaps section.
> - **Item 2 (D-31-04) — PASS.** The `Opacity(0.5)` sub-compact legibility risk, flagged in advance
>   as unsettleable from a desk, did not materialise. No per-tier adjustment needed.
> - **Item 3 (D-31-03) — PASS.** Nothing else on the day moved. The counter-intuitive
>   mark-skipped-and-move-on default is confirmed correct against a real generated day.
>
> The two `verification: backstop` truths that abstained below are **partially resolved** by this:
> the sub-compact text/legibility one is now positively confirmed by Item 2's PASS. The PD-31-06
> live-break one remains **unruled** — the owner did not answer it, and no answer has been inferred.
>
> This is the third time in this project that a green suite was contradicted by a thumb (Phase 27,
> Phase 29, now Phase 31). The checkpoint earned its cost again.

**Phase Goal:** A break can be skipped the same way a work chunk can — at every density, including
the 5-minute one — without the timeline lying about how long anything takes.
**Verified:** 2026-08-25
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

Every code-level truth this phase's five plans committed to is verified against the actual
codebase, not against SUMMARY.md's prose. The suite was run fresh by this verifier
(625/625 passing, `flutter analyze` clean), not taken on the executors' word. The phase's own
ROADMAP text is explicit that this cannot close on that alone: **"This phase MUST end in a human
UAT checkpoint"** — Phase 27 scored 16/17 automated and failed 2/3 human items; Phase 29 went
587-green while the owner looked at a screen with no breaks on it. `31-UAT.md` exists, is fully
written, and its build is byte-verified and being served — but every verdict field in it is still
`_pending_`. The phase is therefore correctly `human_needed`, not `passed`, regardless of the score
below.

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | SKIPBREAK-01 / D-31-01: a leftward drag started inside a break's row calls `markSkipped`, one-directional (`endToStart` only) | ✓ VERIFIED | `test/screens/today_screen_test.dart` tracer test passes; `grep -c "chunkType != ChunkType.work"` (filtered) = 0; `grep -c "Dismissible("` = 1 in `swipeable_chunk_card.dart` |
| 2 | D-31-01: no break ever offers `startToEnd`/`horizontal`; `isCompleted` stays permanently false for breaks | ✓ VERIFIED | `direction: resolved ? DismissDirection.none : (isWork ? horizontal : endToStart)` confirmed by direct read; test cases assert `endToStart` for unresolved break, `none` for skipped, paired against work's `horizontal` |
| 3 | D-31-02: `kBreakHitSlop` applied only when slot < `kMinBreakDragTarget` (48.0), never to work chunks | ✓ VERIFIED | `_needsSlop` predicate (today_screen.dart:697) gates on `isBreak` and `heightFor(...) < kMinBreakDragTarget`; test cases (zero-breaks, mixed-day) confirm |
| 4 | D-31-02: slop-bearing breaks added to Stack AFTER the normal row loop and BEFORE the now-line (ordering is the mechanism) | ✓ VERIFIED | Direct read of `today_screen.dart:1460-1522` (Layer 1a excludes `_needsSlop` rows, Layer 1b emits exactly them, both before the now-line `Positioned`); **non-vacuity proven**: plan 31-03 temporarily deleted the Layer 1b pass and observed the bottom-band case fail with a named thief (`Expected: b1, Actual: w2`), captured verbatim in 31-03-SUMMARY.md, restored byte-identical before commit |
| 5 | SKIPBREAK-02: growing the hit-test envelope changes no painted pixel | ✓ VERIFIED | `test/screens/today_screen_test.dart` `SKIPBREAK-02 — the grid is unchanged` group: duration-exact `ClipRect` extent at 2 tiers x 2 resolved states, exact row adjacency cross-checked against `TimelineGeometry.yFor`, unchanged total Stack height |
| 6 | UI-SPEC E1 loading: no spinner/skeleton/disabled state; `confirmDismiss` returns false and springs back | ✓ VERIFIED | `confirmDismiss` closure unchanged from work-chunk pattern (direct read); below-threshold drag case (31-03) confirms spring-back with no state change |
| 7 | UI-SPEC E1 error: `markSkipped`'s WR-05 revert-and-rethrow reused verbatim, no new error surface | ✓ VERIFIED | `git diff --stat lib/providers/schedule_notifier.dart` for plan 31-01 is empty (confirmed via plan's own acceptance criteria and code review); `markSkipped` body unmodified except the unrelated Guard-9 insertion in a different function |
| 8 | UI-SPEC E1 populated: every break row at every tier is swipeable, sub-compact included | ✓ VERIFIED | `SwipeableChunkCard` promote deletes the `chunkType != work` early return (grep confirms 0 occurrences outside comments); test coverage at full/compact/subCompact |
| 9 | UI-SPEC E1 partial: below-threshold drag springs back, stays unresolved, no CompletionLog write | ✓ VERIFIED | plan 31-03 Case 3: `Offset(-8, 0)` drag, asserts both `lastSkippedId`/`lastCompletedId` null and break unresolved |
| 10 | UI-SPEC E1 overflow: reveal + icon confined to slot via `Align(center)` + `SizedBox` + clamped icon size | ✓ VERIFIED | `_confineReveal`/`_confineContent` in `swipeable_chunk_card.dart` (direct read); `revealIconSize` clamp `math.max(12.0, math.min(20.0, visualHeight! - 4.0))` present |
| 11 | Pattern 4: `ScheduleNotifier.markSkipped` unmodified by plan 31-01; goalId streak guard inert for breaks — asserted, not assumed | ✓ VERIFIED | plan 31-04 Task 3 Case 1: recording fake proves zero `Goal.save()` calls on break skip; **non-vacuity proven**: guard temporarily bypassed (`chunk.goalId ?? ''`), observed fail (`Expected: empty, Actual: [Instance of 'Goal']`), restored byte-identical |
| 12 | D-31-05: `_absorbReclaimedTimeIntoNextBreak` never moves/extends an already-skipped break; original G-05 absorption still works for unresolved breaks | ✓ VERIFIED | `grep -n "next.isSkipped" lib/providers/schedule_notifier.dart` = line 581, positioned between the anchored-check and window-open guards as specified; RED captured pre-fix in `31-RED-d3105.txt`; both regression cases pass post-fix |
| 13 | D-31-03: skipping a break moves no other chunk's start time; appends exactly one un-attributed CompletionLog entry | ✓ VERIFIED | plan 31-04 Task 3 Cases 2–3: five-chunk snapshot before/after, element-wise comparison; single CompletionLog entry with empty `goalId` asserted |
| 14 (backstop) | UI-SPEC E2 partial: a live break composes the live-row treatment with the skipped treatment | ⚠️ insufficient_spec | `LiveRowCard` has zero references to `isSkipped`/`isCompleted` (grep, zero hits); `showActions: chunk.chunkType == ChunkType.work` unchanged (today_screen.dart:1055) — no UI path exists to exercise this truth at all. This is PD-31-06, a recorded deliberate exclusion, not a silently dropped one. Routed to human verification. |
| 15 (backstop) | UI-SPEC E2 long-text: no text-length growth at any tier; sub-compact large-text-scale inherited from Phase 29, unchanged | ⚠️ insufficient_spec | Presence evidence only (shorter 'skipped' string, decoration-flag strikethrough) — no held-out/property test exercises text-scale rendering in this diff, so per the honest-verifier contract this abstains rather than passing on presence alone. Routed to human verification. |

> **Note on row 14, dated 2026-08-26 (plan 31-07).** This truth's abstention was justified above on two factual claims: "`LiveRowCard` has zero references to `isSkipped`/`isCompleted`" and "`showActions: chunk.chunkType == ChunkType.work` unchanged (today_screen.dart:1055)". **Neither is factual as of plan 31-07 (D-31-07).** `LiveRowCard` now takes `showComplete`/`isSkipped` parameters and applies `TextDecoration.lineThrough` from `isSkipped` at both density tiers; `_buildLiveRow`'s call site now reads `showActions: isBreak ? !chunk.isSkipped : true`, not the work-chunk-only form this row quotes. The evidence now lives in `test/screens/today_row_widgets_test.dart`'s `D-31-07 — LiveRowCard Skip without Complete` group (widget-level: showComplete/isSkipped composition, both density tiers) and `test/screens/today_screen_now_state_test.dart`'s `D-31-07 — a live break can be skipped` group (screen-level: Cases A-D, including the truth's own three-part composition claim in Case B). Case B's own commentary documents two corrections to the truth's literal wording — `resolveNowState` delists a resolved chunk from "current" even mid-window (a pre-existing, deliberate, already-tested invariant, not a defect this plan introduced or changed), so the proof measures the SAME chunk's confined-band height and timeline position across the live-to-resolved transition rather than asserting the literal chunk stays `LiveRowCard`-rendered while `isSkipped`. The re-verification and scoring of this row belongs to `/gsd-verify-work`, per this plan's own instruction — this note only records that the abstention's stated justification is stale.

**Score:** 13/13 non-backstop code truths verified. 2 backstop truths abstain to `insufficient_spec` (not counted toward score, not failed). 0 truths ⚠️ PRESENT_BEHAVIOR_UNVERIFIED in the Step 3 sense (all state-transition/ordering claims that could be tested were proven non-vacuous by an executed RED experiment, not left on presence alone).

### The Two Adversarial Claims This Report Was Asked to Stress-Test

**1. "Both slop bands resolve to the break — the bottom band is not vacuous."** Verified directly,
not taken on the SUMMARY's word. `today_screen.dart`'s Layer 1a/1b split was read in full: Layer 1a
excludes any row `_needsSlop` calls true for; Layer 1b emits exactly those rows, after Layer 1a and
before the now-line. Plan 31-03's SUMMARY documents an executed experiment — not merely a claim —
where the Layer 1b loop and its Layer 1a exclusion were temporarily deleted from the *production*
file, the suite was rerun, and the bottom-band case failed with a named thief
(`Expected: 'b1' / Actual: 'w2'`) while the top-band tracer, the negative case, and the
below-threshold case all stayed green. The file was restored byte-identical
(`git diff` empty) before any commit. This is exactly the falsifiable proof the phase goal demands:
a naive implementation (chronological loop, no Layer 1b) would pass the top band and silently fail
the bottom one, and that is the specific failure this project's own carried-forward defect class
("green test that could not fail") would have hidden. I re-ran the current (fixed) suite myself
(625/625 green) rather than trusting the captured transcript alone.

**2. "No break's painted height changed, in any resolved state, at any density."** Verified via the
`SKIPBREAK-02 — the grid is unchanged` test group (plan 31-03), which asserts the *confined*
`ClipRect` rect — not the grown `Positioned` — equals `durationMinutes * kPixelsPerMinute` exactly,
across a 2x2 table (5-min sub-compact / 30-min full tier, x unresolved/skipped). The acceptance
criteria for that plan explicitly forbid measuring the outer `Positioned` (`grep -c
"getSize(.*Positioned"` must be 0), which the test file honors. Row adjacency is cross-checked
against `TimelineGeometry.yFor`'s own authority, not just a neighbour's edge, and the Stack's total
height is asserted unchanged. The Phase 29 `SEEBREAK-02` painted-extent test — this phase's
predecessor invariant — passes with a zero-line diff to its own body, confirmed by direct git
history read.

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `lib/screens/today/timeline_geometry.dart` — `kBreakHitSlop`/`kMinBreakDragTarget` | consts with doc comments | ✓ VERIFIED | present, with PD-31-01 rationale recorded in comment |
| `lib/screens/schedule/widgets/swipeable_chunk_card.dart` — `visualHeight` param | optional `double?`, default `null` | ✓ VERIFIED | present; `_confineReveal`/`_confineContent` helpers implement the confinement |
| `lib/screens/today/today_screen.dart` — `_needsSlop` + Layer 1b pass | predicate + new Stack loop | ✓ VERIFIED | both present, wired, non-vacuity proven (see above) |
| `test/screens/today_screen_test.dart` — Phase 31 SKIPBREAK group | tracer + bottom-band + negative + threshold + grid-unchanged cases | ✓ VERIFIED | all present, all passing in a suite run I executed myself |
| `.planning/phases/31-breaks-you-can-skip/31-RED-tracer.txt` | captured RED evidence | ✓ VERIFIED | file exists |
| `lib/screens/schedule/widgets/chunk_card.dart` — `_SubCompactRow.isSkipped`, compact `Semantics` | new param + wrapper | ✓ VERIFIED | present, `Semantics(` count +1 confirmed via code review's own independent SDK-level check |
| `lib/providers/schedule_notifier.dart` — Guard 9 | `if (next.isSkipped) return null;` | ✓ VERIFIED | present at line 581, correctly positioned per code review's independent placement check |
| `.planning/phases/31-breaks-you-can-skip/31-RED-d3105.txt` | captured RED evidence | ✓ VERIFIED | file exists |
| `.planning/phases/31-breaks-you-can-skip/31-UAT.md` | UAT script, served-bytes proof, per-item verdict | ⚠️ PARTIAL | script + Step 0 + served-bytes proof (sha256 match, non-zero `", skipped"` grep) are complete and were independently re-confirmed (server still running on 8143, `pgrep` shows it live); **every verdict field is `_pending_`** — this is the reason for `human_needed`, not a defect |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `today_screen.dart` Layer 1b pass | Stack hit-test z-order | later-pass ordering | ✓ WIRED | confirmed by direct read + the executed non-vacuity deletion experiment |
| `Positioned(height: slot + 2*kBreakHitSlop)` | `Dismissible`'s own `GestureDetector` size | grown outer box, confined inner paint | ✓ WIRED | `_buildPositionedRow`'s break arm read directly; `visualHeight: slot` passed through `_buildChunkCard` |
| `SwipeableChunkCard.visualHeight` | reveal AND card content, confined independently | `_confineReveal`/`_confineContent` | ✓ WIRED | both helpers present and distinct, per PD-31-03 |
| `markSkipped` (UI-reachable) | `_absorbReclaimedTimeIntoNextBreak` (reachable from `markComplete`) | Guard 9 | ✓ WIRED | both paths traced; guard confirmed to intercept |
| `chunk.goalId == null` for breaks | `markSkipped`'s streak write-back | existing guard, asserted not assumed | ✓ WIRED | recording-fake test + executed guard-removal RED proof |

### Anti-Patterns Found

None. Scanned all five files this phase modified for `TBD`/`FIXME`/`XXX`/`TODO`/`HACK`/`PLACEHOLDER` — zero hits. No stub returns, no hardcoded-empty state flowing to render in the new code paths.

Code review (`31-REVIEW.md`, standard depth, 8 files) found 2 non-blocking issues, both stale doc-comment/test-title accuracy problems, not functional defects: WR-01 (two pre-existing test titles reference a code branch this phase deleted) and IN-01 (a comment says "eight existing guards" after this same phase added a ninth). Neither affects correctness; both are documentation hygiene. Confirmed via the review's own direct SDK/diff-level checks, not just narrative.

### Requirements Coverage

No milestone `REQUIREMENTS.md` exists for this project (standalone phases track requirements directly in ROADMAP.md, consistent with Phases 27–30). Both declared requirements are covered by plan `requirements:` frontmatter and coverage entries:

| Requirement | Source Plans | Status | Evidence |
|---|---|---|---|
| SKIPBREAK-01 | 31-01, 31-02, 31-03, 31-04 | ✓ Code-complete, human verdict pending | gesture, rendering, and engine-inertness proofs all verified above; Item 1 of `31-UAT.md` is the outstanding physical claim |
| SKIPBREAK-02 | 31-01, 31-03 | ✓ Code-complete, human verdict pending | painted-grid invariants verified above; Item 2/3 of `31-UAT.md` are the outstanding visual/day-shape claims |

### Human Verification Required

See `human_verification` in the frontmatter (5 items): the three `31-UAT.md` items (thumb
reliability, legibility, nothing-else-moved) plus the two `verification: backstop` truths, one of
which (PD-31-06, the live-break composition claim) is a recorded deliberate exclusion rather than a
gap — confirmed by direct code inspection that `LiveRowCard` has no `isSkipped` awareness at all,
so there is no code path this claim could even exercise yet. The owner's ruling on that exclusion
(open a follow-up, seed it, or leave it) is itself one of the pending items in `31-UAT.md`.

### Gaps Summary

No code-level gaps. Every truth this phase's plans committed to — including the two adversarial
claims flagged for special scrutiny (non-vacuous bottom-slop-band win, zero painted-pixel movement)
— is verified against the actual codebase and an executed, non-vacuous proof (not a green test that
could never fail), independently re-confirmed by this verifier via a fresh 625/625 `flutter test`
run and `flutter analyze` clean pass, plus direct reads of the production source at every claimed
line. The single reason this phase is not `passed` is that its own ROADMAP-mandated blocking human
UAT checkpoint (`31-UAT.md`) has a complete, byte-verified, currently-served build and a
fully-written script, but every verdict field is still `_pending_`. That is the correct and
expected state per this phase's own design — Task 2 of plan 31-05 is a `checkpoint:human-verify
gate="blocking"` task that was deliberately reached, not answered, and the executor explicitly
declined to self-answer or fabricate a verdict. Recommend: present `http://danserver:8143/` to the
owner on a real touch device, per `31-UAT.md`'s Step 0 instructions, and record verdicts before
closing the phase.

---

_Verified: 2026-08-25_
_Verifier: Claude (gsd-verifier)_
