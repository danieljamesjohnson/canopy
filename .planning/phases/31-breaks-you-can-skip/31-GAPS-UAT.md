# Phase 31 Plan 08 — Round Two Human UAT (Gap Closure)

**Status:** pending human verdict. This is round **two** of the Phase 31 UAT, closing the gaps
round one (`31-UAT.md`, judged 2026-08-26) left open: Item 1 **FAILED** ("hard to do this with a
thumb"), and the deliberate exclusion PD-31-06 (a live break has no skip affordance) was surfaced
unruled and then **RULED** the same day as **D-31-07** — fold it in. Round one's Items 2 and 3
**PASSED** and are **not re-asked** below except as a "did anything look different" carry-forward,
per D-31-06/D-31-07 in `31-CONTEXT.md`.

**Served at:** `http://danserver:8143/`

---

## A note on how this document was produced

This document was written by an executor (plan 31-08) running inside a git worktree, which is
**force-removed the instant it returns**. Any server it started would die with it, and `build/web`
is gitignored, so a build it produced would be discarded on return. Per this plan's own
`<precondition>` and the explicit division-of-labour instruction it carries, the executor **did
not** build, serve, or run the byte-verification commands below — those steps, and the numbers
they produce, are the **orchestrator's** output, generated from the main working tree after
merging plans 31-06, 31-07, and this plan's commits. This split is the same one recorded as a
deviation in `31-05-SUMMARY.md`, except this time it is the plan's design, not an improvisation.

**Everything under "Pre-flight" below, up to and including the killed-server record and the two
sha256 digests and grep counts, is the orchestrator's output, not this executor's invention. Do
not read it as something this executor ran or verified.**

What the executor *did* verify directly, inside the worktree, before writing this document:

```
$ flutter test
...
00:18 +639: All tests passed!

$ flutter analyze
Analyzing agent-af6b6c0db48e1a81f...
No issues found! (ran in 1.8s)
```

**639/639 tests green, `flutter analyze` clean**, captured in the worktree at the merged tip of
31-06 + 31-07 before this document was written.

---

## Pre-flight — served bytes match built bytes, and contain this closure's own symbols

**To be filled in by the orchestrator, from the main working tree, after merging this wave.**
Do not treat any line in this block as true until the orchestrator has replaced every placeholder
below with a real, verbatim command and its real output.

**Reclaim the port first.** A server from round one (`31-05-SUMMARY.md`) or from Phase 29/30 may
still be listening on 8143 — round one found a two-day-old server squatting this exact port and
came within one step of a false UAT. Check and kill before building anything:

```
$ lsof -i :8143
_TO BE FILLED BY ORCHESTRATOR_
```

**Killed PID:** `_TO BE FILLED BY ORCHESTRATOR_`
**Killed server's start time:** `_TO BE FILLED BY ORCHESTRATOR_`

Build command (verbatim — never `flutter run -d web-server`, never a release build on this port):

```
flutter build web --debug --source-maps --pwa-strategy=none
```

Serve command (verbatim — never `python3 -m http.server`, trap #3):

```
python3 tools/serve-uat.py 8143 --dir build/web
```

Byte-verification, run by the orchestrator after the build and serve above:

```
$ sha256sum build/web/main.dart.js
_TO BE FILLED BY ORCHESTRATOR_

$ curl -s http://danserver:8143/main.dart.js | sha256sum
_TO BE FILLED BY ORCHESTRATOR_

$ curl -s http://danserver:8143/main.dart.js | grep -c SwipeableRowShell
_TO BE FILLED BY ORCHESTRATOR_

$ curl -s http://danserver:8143/main.dart.js | grep -c showComplete
_TO BE FILLED BY ORCHESTRATOR_

$ curl -sI http://danserver:8143/main.dart.js | grep -i cache-control
_TO BE FILLED BY ORCHESTRATOR_
```

**If either grep above returns zero:** do not proceed and do not quietly substitute a different
string. Pick another symbol from the "Artifacts this phase produces" tables in `31-06-PLAN.md`
(`kSubCompactGripSize`, `Icons.drag_indicator`) or `31-07-PLAN.md` (`LiveRowCard.showComplete`,
`class SwipeableRowShell`), re-run the grep, and record here which symbol was used and why the
first one returned zero. A pre-flight that quietly changes its own success criterion is worse than
no pre-flight.

**Expected result once filled in:** the two sha256 digests are identical, and both grep counts are
non-zero.

**The distinction that matters most, stated plainly (trap #4):** a non-zero grep count proves the
**code** shipped. It does **not** prove that the **data on screen** was produced by that code — an
already-generated Hive day is rendered by whatever code is running now, without necessarily having
been *generated* by it, because `ScheduleNotifier._loadToday()` reads straight from Hive and
`ScheduleGeneratorService.generate()` only runs at check-in with silent-replace. That is exactly
what **Step 0** below exists for, and the agent who has just run a clean grep and felt relief is
the agent most likely to skip Step 0 because the grep felt like proof. It is not proof of that.

---

## STEP 0 — MANDATORY, DO THIS FIRST. Tap ⟳ Re-check-in.

This is not optional and it is not a formality. `ScheduleNotifier._loadToday()` reads today's
schedule straight from Hive, and `ScheduleGeneratorService.generate()` only runs at check-in with
silent-replace. **An already-generated day is never regenerated on load** — if today's schedule
was built before this gap closure's code landed, every item below would be judged against a
pre-change day while the new code sits unused in the bundle the pre-flight above just (once filled
in) proved present.

This exact omission happened on **2026-08-21**: a UAT judged a pre-fix day, reported a false
failure, and let the real defect survive three more days until the owner reported the identical
symptom again on **2026-08-24**. Do not repeat it.

**Step 0 performed:** _pending_
**Date:** _pending_

An unrecorded Step 0 invalidates every item below and must be re-run, not assumed — the
orchestrator cannot perform this step; it requires tapping the control in the running app.

---

## Do this on a phone or tablet, not a desktop pointer

A mouse cursor is a single pixel. The entire question below is what happens when the input is
roughly 40dp of fingertip, so a trackpad or mouse verdict does not answer it.

---

## What automation already proved, and why you're still being asked

639/639 tests pass and `flutter analyze` is clean — that total includes three plans' worth of
proof `flutter test` genuinely can settle: the 68dp band discriminates from the old 52dp one at a
literal coordinate (proven both green and RED), the neighbouring work chunk's own retained band is
guarded against ever dropping under 48dp, the grip glyph is present/absent at the right times and
costs exactly zero painted pixels (also proven both green and RED), a live break now offers Skip
and never Complete, and truth #14's composition claim (slot height, timeline position, and the
now-line's position all unchanged across the live-to-skipped transition) is proven rather than
assumed.

None of that settles the one thing this checkpoint exists for: **whether a real thumb, on a real
touch device, can now reliably start and complete a leftward swipe on a break's row, without also
grabbing the work chunk beside it, and whether there is now something visible to aim at.**
`flutter test` fires synthetic drags at exact coordinates — it cannot, by construction, distinguish
a 52dp acquisition band from a 68dp one, and it cannot judge whether a 14dp glyph "reads as
grabbable" to a human eye. This is the third time in this project a green suite has been
contradicted by a physical device: Phase 27 scored 16/17 automated and then failed 2 of 3 human
items; Phase 29 went 587-green while the owner looked at a screen showing no breaks at all; Phase
31 went 625-green and 12/12 verified and a thumb still could not grab the row. Green tests have
been wrong about what a thumb experiences three times now. This is that check, again.

---

## Item 1 — Can a thumb GRAB a 5-minute break now? (SKIPBREAK-01, D-31-06)

Find a 5-minute break on the timeline — the thin hairline row labelled `Short break` between two
work blocks. With a **thumb**, not a fingernail and not a stylus, swipe it **leftward**.

- **(a) Try it five times at a natural thumb placement.** Count how many of the five grabbed the
  break, versus grabbed the work block above or below it. Round one's answer was *"hard to do this
  with a thumb"* — this is the number that has to move.

  **Attempts (round two):** _pending_ / 5 grabbed the break.

- **(b) Did the swipe complete?** A red panel with a right-pointing arrow, and the break marked
  skipped.

  **Verdict:** _pending_

- **(c) Did skipping the break ever accidentally complete or skip the work chunk next to it?**

  **Verdict:** _pending_

**The new geometry, stated honestly.** The reachable band is now **24dp above and 24dp below** the
visible hairline — roughly **68dp** against the 20dp painted row, up from roughly 52dp in round
one. This ceiling is real, not a feel-based choice: the break wins the contested band under the
Layer 1b pass, so every dp of slop is taken from the neighbouring work chunk. The neighbouring
25-minute work chunk retains **52dp** of its own target at this value, and would drop under the
48dp Material minimum at 32dp of slop. **"Make it bigger again" is not an available answer if this
still fails** — that headroom is gone. If Item 1 fails again, say specifically how ("it grabs the
block above" and "nothing happens at all" are different defects with different fixes), because the
fix this time would have to be structural (a different affordance, not a bigger invisible band),
not a repeat of the D-31-06 slop increase.

**Round-two verdict:** _pending_

---

## Item 2 — Can you SEE what to grab? (D-31-06 part 2)

This is the new question, and it is the one that addresses the actual root cause round one
uncovered: 52dp already cleared **both** Material's 48dp and iOS's 44pt minimums **on paper**, and
those minimums assume a target the user can **see**. SKIPBREAK-02 forbids painting into the slop,
so before this change the thumb had to land within ±16dp of a 20dp hairline by feel alone, with
nothing to look at.

- **(a) Is there a small grip glyph visible at the left end of the `Short break` label?**

  **Verdict:** _pending_

- **(b) Does it read as "grab here" — or as decoration, an artifact, or a rendering glitch?**

  **Verdict:** _pending_

- **(c) At arm's length, can you find the break's grab point without hunting for it?**

  **Verdict:** _pending_

- **(d) It deliberately disappears once a break is already skipped.** Does that read as correct,
  or does its absence look like something is missing/broken?

  **Verdict:** _pending_

**Round-two verdict:** _pending_

---

## Item 3 — Can a break that is RUNNING RIGHT NOW be skipped, and does the now-line stay put? (D-31-07)

Ruled by the owner on 2026-08-26: fold this into the gap closure, Skip only — a break can never be
"completed" in this app.

**Reaching a live break without waiting for one.** Note a break's start time from the timeline, go
to **Settings**, use the Phase 25 time-travel control to set the simulated clock to a minute inside
that break's window, and return to Today. **Stay within the same calendar day** — crossing
midnight changes the "today" key and you would be looking at a different (or empty) schedule.
Reset the dev clock in Settings when you are done.

- **(a) On the running break's card, is there a Skip action and no Complete action?** A 30-minute
  long break shows a Skip icon on its live card. A 5-minute break's row is too short for any
  button to fit, so there the gesture is the **same leftward swipe** used everywhere else — this is
  intentional, not a missing button; don't hunt for one that cannot fit in a 20dp row.

  **Verdict:** _pending_

- **(b) Skip it. Does the row stay exactly where it was on the timeline, at the same height?**

  **Verdict:** _pending_

- **(c) Does the red now-line stay in the same place, or does it jump?**

  **Verdict:** _pending_

- **(d) Is there any visible sign the skip landed — the title struck through?**

  **Verdict:** _pending_

**A behaviour to judge honestly, flagged in advance rather than left for you to stumble on.** When
a live break is skipped, `resolveNowState`'s pre-existing "advance past resolved chunks" loop
(`now_state.dart:176`) delists it from "current" — so the row stops rendering as a **live** card
and the header switches from showing the break as active to showing the next chunk as **"Up
next."** The **now-line itself does not move** (it is clock-anchored, and a test asserts its
position is unchanged across this transition) — what changes is which chunk is framed as "now."
This is **pre-existing behaviour for every chunk type**, not something this gap closure
introduced; a live work chunk that gets completed or skipped does the identical thing today. Ask
yourself whether that reads as correct for a break too, rather than assuming it does just because
it is pre-existing.

**Does the "Up next" transition read as correct for a skipped live break?**

**Verdict:** _pending_

**Round-two verdict:** _pending_

---

## Carried forward, not re-asked

Round one's Items 2 and 3 (skipped-break legibility at `Opacity(0.5)`, and nothing else moving
when a break is skipped) both **PASSED** on 2026-08-26 and are **settled**. `Opacity(0.5)` stands
uniformly; D-31-03's "mark it skipped and move on, minutes are not handed back" is confirmed and
is **not up for re-litigation** here. This closure touched the same rows, so say something only if
either now looks **different** than it did in round one — otherwise no action needed.

Break cards are still not tappable — the owner's own instruction from 2026-08-21 — and that
remains enforced by a test, not by convention. Not a question; recorded so it stays visible.

---

## Resume signal

Type **"approved"** if all three items above pass. Otherwise describe what happened per item — for
Item 1 give the five-attempt count and say roughly how it still fails ("it grabs the block above"
vs. "nothing happens at all" are different defects with different fixes); for Item 2 say whether
the grip is visible at all and whether it reads as something to grab; for Item 3 say whether the
running break offered Skip, whether the row moved, and whether the now-line jumped.

If you are unavailable, this phase records `verification_deferred_human` in `STATE.md` and stays
open rather than closing on a green suite alone — exactly what Phases 29 and 30 did before being
judged honestly a working day later, and exactly what round one of this UAT itself did.

---

## Remedies if an item fails

Any FAIL routes explicitly — to a further gap-closure plan in this phase, or to a new phase —
rather than being noted and left. A recorded failure with no route is how Phase 24's DayComplete
gap survived a full plan cycle. If Item 1 fails again, the remedy cannot be "raise the slop
further" (the 48dp neighbour-minimum ceiling forecloses that); it would need a structural
alternative (e.g. a persistent affordance, a different gesture, or a decision to stop trying to
make the 5-minute row itself draggable and expose skip some other way) and that alternative would
need to be planned, not improvised in this document. If Item 2 fails, the remedy is a follow-up
plan to redesign the glyph (size, contrast, icon choice) rather than abandoning the visibility
approach. If Item 3 fails on the "Up next" transition reading wrong, that is a product decision
(D-31-07's scope) and needs an explicit owner ruling before any code changes, not a unilateral fix.

---

## Summary

```
total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0
```

(Counts above reflect the state at the time this document was written by the executor — all three
items pending a human verdict. The orchestrator/owner should update this block once verdicts are
recorded.)

## Gaps

<!-- YAML for /gsd-plan-phase 31 --gaps consumption -->

- truth: "A real thumb, on a real touch device, can reliably GRAB a 5-minute break's row (SKIPBREAK-01, D-31-06 round two)"
  status: pending
  reason: "Awaiting human verdict — round two of the Item 1 five-attempt test, re-asked in the same form as round one for direct before/after comparison."
  severity: major
  test: 1
  root_cause: ""
  artifacts:
    - path: "lib/screens/today/timeline_geometry.dart"
      issue: "kBreakHitSlop raised 16.0 -> 24.0 (31-06); this is the change under judgment"
  owner_ruling: ""
  missing: []
  debug_session: ""

- truth: "The grip glyph is findable by eye and reads as a grab affordance (D-31-06 part 2)"
  status: pending
  reason: "Awaiting human verdict — new question round one could not ask, addressing the root cause (an invisible target met platform minimums on paper but still failed)."
  severity: major
  test: 2
  root_cause: ""
  artifacts:
    - path: "lib/screens/schedule/widgets/chunk_card.dart"
      issue: "kSubCompactGripSize / Icons.drag_indicator glyph added inside _SubCompactRow (31-06); this is the change under judgment"
  owner_ruling: ""
  missing: []
  debug_session: ""

- truth: "A break that is currently running can be skipped, and the now-line does not move when it is (D-31-07)"
  status: pending
  reason: "Awaiting human verdict — including whether the pre-existing 'Up next' delisting transition reads as correct for a skipped live break, not just whether the skip itself works."
  severity: minor
  test: 3
  root_cause: ""
  artifacts:
    - path: "lib/screens/today/widgets/live_row_card.dart"
      issue: "showComplete/isSkipped added (31-07); this is the change under judgment"
    - path: "lib/screens/schedule/widgets/swipeable_chunk_card.dart"
      issue: "SwipeableRowShell extraction and live-break wiring (31-07); this is the change under judgment"
  owner_ruling: ""
  missing: []
  debug_session: ""
</content>
