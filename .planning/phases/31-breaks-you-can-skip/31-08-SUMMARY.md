---
phase: 31-breaks-you-can-skip
plan: 08
subsystem: ui
tags: [flutter, uat, human-verification, gap-closure]

# Dependency graph
requires:
  - phase: 31-05
    provides: the round-one UAT structure, wording, and the FAIL verdict on Item 1 this round is directly comparable against
  - phase: 31-06
    provides: kBreakHitSlop=24.0 and the sub-compact grip glyph — the D-31-06 changes Item 1/Item 2 judge
  - phase: 31-07
    provides: LiveRowCard.showComplete/isSkipped and SwipeableRowShell — the D-31-07 change Item 3 judges
provides:
  - "31-GAPS-UAT.md — the round-two human UAT script, with Step 0 mandatory and first, a pre-flight block left as explicit orchestrator placeholders, Item 1 re-asked in the same five-attempts form as round one, a new grip-findability item, a new live-break-skip item (with the now-state 'Up next' delisting transition flagged honestly), round one's PASSes carried forward as not-to-be-re-litigated, and every verdict field left pending"
affects: ["31 (phase cannot close until Task 2's human verdict is recorded)"]

# Actuals (#2632)
actuals:
  tokens: 4200
  tasks: 1
  commits: 1

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Division-of-labour UAT documents: when the executor runs inside a worktree that is force-removed on return and the artifact under test (build/web) is gitignored, the UAT script itself states which lines are the executor's and which are the orchestrator's, with unfilled sections marked as explicit placeholders rather than fabricated — carried forward from 31-05's precedent as a repeatable pattern rather than a one-off improvisation."

key-files:
  created:
    - .planning/phases/31-breaks-you-can-skip/31-GAPS-UAT.md
  modified: []

key-decisions:
  - "No verdict was self-answered anywhere in the document — every PASS/FAIL field is left as literal `_pending_`, including the Summary block's counts, which report the pre-verdict state (0 passed / 3 pending) rather than assuming an outcome."
  - "Item 3 includes an explicit, advance-flagged question about the pre-existing 'Up next' now-state delisting transition (now_state.dart's advance-past-resolved-chunks loop), rather than only asking whether the skip mechanically works — per the plan's instruction to have the owner judge whether that pre-existing behaviour reads as correct for a break, not just assume it does because it is unchanged for other chunk types."
  - "The pre-flight byte-verification grep targets were fixed to SwipeableRowShell and showComplete, matching the exact symbols named in this plan's own <action> and <verify> blocks, with the documented fallback (kSubCompactGripSize, Icons.drag_indicator, class SwipeableRowShell) left in place for the orchestrator to use if either returns zero."
  - "Round one's Items 2 and 3 (Opacity(0.5) legibility, nothing-else-moves) and D-31-03 are explicitly marked not-to-be-re-litigated, with a narrow carve-out: say something only if either now looks different, since this closure touched the same rows."

requirements-completed: []

coverage: []

# Metrics
duration: ~25min
completed: 2026-08-26
status: halted
---

# Phase 31 Plan 08: Round-Two Gap-Closure UAT Script Summary

**Wrote `31-GAPS-UAT.md`, the round-two blocking human UAT covering D-31-06 (acquisition band + grip glyph) and D-31-07 (live-break skip) — Task 1 only; Task 2 is a `checkpoint:human-verify` gate requiring a real touch device and is not yet answered.**

## Performance

- **Duration:** ~25 min
- **Completed:** 2026-08-26
- **Tasks:** 1 of 2 (Task 2 is the plan's own blocking checkpoint, not executable by this agent)
- **Files modified:** 1 created

## Why this plan halts here

`31-08-PLAN.md` has exactly two tasks: Task 1 (`type="auto"`) writes the UAT document, and Task 2
(`type="checkpoint:human-verify"`, `gate="blocking"`) is the owner's thumb on a real phone or
tablet. The plan's own `<precondition>` and the objective this executor was given both state the
division of labour explicitly: this executor runs inside a git worktree that is force-removed the
instant it returns, and `build/web` is gitignored, so it **cannot** build, serve, or byte-verify
anything itself — those steps are the orchestrator's, from the main working tree, after this
wave's commits merge. Per the plan's `<action>`, "Do not record a verdict for any item yourself.
This task writes the document and stands up the build; Task 2 is where a human answers it." No
verdict was recorded. This plan is `status: halted`, not `complete` — Task 2 remains open and the
phase cannot close until a human answers it on a real device.

## Accomplishments

- `flutter test` (639/639) and `flutter analyze` (clean) confirmed directly in the worktree, at the
  merged tip of plans 31-06 and 31-07, before writing the document — the tree being documented is
  actually the tree that's green.
- `.planning/phases/31-breaks-you-can-skip/31-GAPS-UAT.md` written, containing, in order: the
  division-of-labour note (executor vs. orchestrator); a pre-flight block with the exact build/serve
  commands from `CLAUDE.md` and explicit `_TO BE FILLED BY ORCHESTRATOR_` placeholders for the
  server-reclaim record, both sha256 digests, both grep counts, and the `Cache-Control` check; the
  trap #4 sentence (code shipped vs. data on screen) immediately after the pre-flight block; a
  mandatory, dated Step 0 (⟳ Re-check-in) ahead of every item, naming the 2026-08-21/2026-08-24
  incident; an automation-limits section explaining why three green suites (Phase 27, 29, 31) have
  already been contradicted by a thumb; Item 1 re-asked in the identical five-attempts form as round
  one, with the 68dp-vs-52dp geometry and the 48dp neighbour-minimum ceiling stated honestly; a new
  Item 2 asking whether the grip glyph is findable and reads as "grab here"; a new Item 3 routing the
  owner through Settings' time-travel controls to reach a live break, asking about Skip-without-
  Complete, row position, now-line stability, and strikethrough — plus an explicit, advance-flagged
  question about whether the pre-existing "Up next" now-state delisting transition reads as correct
  for a skipped break; a carried-forward section marking round one's Items 2-3 and D-31-03 as settled
  and not re-litigated; a resume signal; a remedies section routing any FAIL to a further plan rather
  than leaving it noted; and a `## Summary` / `## Gaps` block in the YAML shape `/gsd-plan-phase 31
  --gaps` consumes, with every status `pending`.
- Every verdict field in the document is literally `_pending_` — no self-answered verdict, no
  fabricated command output. The Summary block's own counts (0 passed / 3 pending) reflect that
  honestly rather than assuming an outcome.

## Task Commits

1. **Task 1: Build, reclaim port 8143, serve, byte-verify, and write the round-two UAT** (document
   portion only — build/serve/byte-verify deferred to the orchestrator, per the plan's own
   precondition) - `347bf4e` (docs)

_No separate plan-metadata commit — this plan runs inside a git worktree; the orchestrator commits
STATE.md/ROADMAP.md centrally after the wave merges, per this executor's explicit instructions not
to touch either._

## Files Created/Modified

- `.planning/phases/31-breaks-you-can-skip/31-GAPS-UAT.md` — the round-two human UAT script,
  currently all-pending

## Decisions Made

- **Grep targets fixed to `SwipeableRowShell` and `showComplete`**, matching this plan's own
  `<action>`/`<verify>` blocks exactly, with the documented fallback symbols
  (`kSubCompactGripSize`, `Icons.drag_indicator`, `class SwipeableRowShell`) left in the pre-flight
  block's instructions for the orchestrator to use if either returns zero — per the plan's explicit
  warning not to silently substitute without recording why.
- **The now-state "Up next" delisting transition is flagged as its own judgment question**, not
  folded silently into "does the skip work" — `now_state.dart`'s advance-past-resolved-chunks loop
  is pre-existing and unconditional for every chunk type, and 31-07-SUMMARY.md's own test-design
  corrections already establish this is the reachable, load-bearing behaviour. The UAT asks the
  owner to judge it as a real, visible product behaviour rather than assuming pre-existing means
  automatically correct.
- **Round one's Items 2-3 and D-31-03 marked explicitly out of scope for re-litigation**, with a
  narrow "say something only if it now looks different" carve-out, per the plan's instruction and
  `31-CONTEXT.md`'s framing of D-31-06/D-31-07 as the only two open questions.

## Deviations from Plan

None — plan executed exactly as written for Task 1. The division-of-labour split (executor writes
the document with placeholders; orchestrator fills the pre-flight block after merge) is not a
deviation — it is what `31-08-PLAN.md`'s own `<precondition>` and this executor's objective
explicitly instructed, matching the identical split already recorded as a deviation in
`31-05-SUMMARY.md` for round one.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required. Task 2 requires the **owner's** action (a real
touch device on the tailnet), which is the blocking checkpoint itself, not a setup step.

## Known Stubs

None — the pre-flight placeholders are not stubs in the "unfinished implementation" sense; they are
explicitly documented handoff points to the orchestrator, per the plan's own division-of-labour
instruction, and are clearly marked as such in the document.

## Next Phase Readiness

- The document is ready for the orchestrator to build `flutter build web --debug --source-maps
  --pwa-strategy=none` from the merged main working tree, reclaim port 8143, serve with
  `python3 tools/serve-uat.py 8143 --dir build/web`, fill in the pre-flight placeholders in
  `31-GAPS-UAT.md`, and then route Task 2 to the owner as a blocking human-verify checkpoint.
- Phase 31 **cannot close** until Task 2's human verdict is recorded in `31-GAPS-UAT.md` and
  `STATE.md` is updated accordingly (owner said explicitly this is a follow-up step the orchestrator
  owns, not this executor).
- If Task 2 comes back with any FAIL, the `## Gaps` YAML block in `31-GAPS-UAT.md` is pre-populated
  with `status: pending` entries for all three truths, ready to be updated to `failed`/`passed` and
  consumed by `/gsd-plan-phase 31 --gaps` if a third round is needed.

---
*Phase: 31-breaks-you-can-skip*
*Completed: 2026-08-26 (Task 1 only — Task 2 pending)*

## Self-Check: PASSED

- `.planning/phases/31-breaks-you-can-skip/31-GAPS-UAT.md` — FOUND
- Commit `347bf4e` (docs: round-two gap-closure UAT script) — FOUND in `git log`
</content>
