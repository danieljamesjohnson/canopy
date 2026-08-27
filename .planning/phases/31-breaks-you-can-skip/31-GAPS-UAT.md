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
$ ss -ltnp | grep ':8143'
LISTEN 0 5 0.0.0.0:8143 0.0.0.0:* users:(("python3",pid=2357258,fd=3))
```

**It was squatting the port again — the same failure round one caught, one round later.**
PID `2357258` is the *round-one* server, still listening. It was started on **2026-08-24 09:49**
(recorded in `31-UAT.md`, which noted it had already been left running since Phase 29/30) and was
still serving the **pre-fix** bundle — the build the owner judged FAIL on Item 1. Had it been left
up, the owner would have re-tested the exact bundle that already failed and concluded the fix did
not work.

**Killed PID:** `2357258`
**Killed server's start time:** `2026-08-24 09:49` (per `31-UAT.md`; ~2 days stale at kill time)
**Replacement PID:** `3484010`, serving the bundle built below.

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
f3abc81396156c87a019ab676bad96116e80b81cf16c536ed81d08febc4c1811  build/web/main.dart.js

$ curl -s http://danserver:8143/main.dart.js | sha256sum
f3abc81396156c87a019ab676bad96116e80b81cf16c536ed81d08febc4c1811  -

$ curl -s http://danserver:8143/main.dart.js | grep -c SwipeableRowShell
10

$ curl -s http://danserver:8143/main.dart.js | grep -c showComplete
2

$ curl -sI http://danserver:8143/main.dart.js | grep -i cache-control
Cache-Control: no-store, max-age=0
```

**✓ VERIFIED.** The two sha256 digests are identical, both greps are non-zero, and
`Cache-Control: no-store` is present so trap #3 cannot apply. The bytes on 8143 are byte-for-byte
the bundle built above, and it carries wave 2's `SwipeableRowShell` and `showComplete`.

### Two greps DID return zero, and this is the honest account of why

The instruction above says not to quietly substitute a symbol until one passes. So, recorded rather
than swept up: **`drag_indicator` and `kSubCompactGripSize` — wave 1's grip glyph, the half of
D-31-06 that Item 2 below asks about — each grep `0` in the served bundle.**

That is not a missing feature. It is the wrong probe for that *kind* of symbol. `dart2js`
const-folds both: `kSubCompactGripSize` is a `const double` that inlines to a bare literal, and
`Icons.drag_indicator` is a `const IconData` that survives only as its **codepoint**, never its Dart
identifier. Verified against the SDK and then against the served bytes:

```
$ grep -n "static const IconData drag_indicator " $FLUTTER/packages/flutter/lib/src/material/icons.dart
8411:  static const IconData drag_indicator = IconData(0xe207, fontFamily: 'MaterialIcons');

$ curl -s http://danserver:8143/main.dart.js | grep -c 57863     # 0xe207 == 57863
4
```

**So the grip did ship** — the identifier just is not what ships. Both wave-1 and wave-2 symbols are
confirmed present in the served bytes by a probe appropriate to each. Note this is a general trap for
any future UAT here: **a name-grep is only a valid presence probe for symbols dart2js preserves.**
For a const, an icon, or an inlined literal, a zero count means "wrong probe," not "absent" — and
treating it as "absent" would have sent a working build back for a rebuild.

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

**Step 0 performed:** **not recorded.** The owner reported using his thumb on the served build but
did not state whether he tapped ⟳ Re-check-in first, and it is not inferred here.

**Does it invalidate anything?** For **Item 2** — the one item that produced a verdict — no. That
finding is about what an icon *means*, which is a pure render concern: the glyph is present in the
bundle (codepoint `0xe207`, verified above) and paints identically on a pre- or post-change day.
Item 3 is the one that genuinely needed Step 0, and Item 3 went unanswered anyway. So no verdict
recorded below rests on an unperformed Step 0 — stated explicitly rather than left as a loose end,
because trap #4 has already cost this project one false failure and three lost days.
**Date:** 2026-08-27 (verdicts recorded)

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

  **Attempts (round two):** **not counted — the owner rejected the approach rather than scoring
  the increment.** He confirmed he used his thumb (*"Ok I used my thumb"*) but gave no attempt
  count, and none is inferred here. See the round-two verdict below.

- **(b) Did the swipe complete?** A red panel with a right-pointing arrow, and the break marked
  skipped.

  **Verdict:** **unanswered.** Not reported either way.

- **(c) Did skipping the break ever accidentally complete or skip the work chunk next to it?**

  **Verdict:** **unanswered.** Not reported either way.

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

**Round-two verdict: ⊘ SUPERSEDED — the owner rejected the swipe approach itself, 2026-08-27.**

Not a PASS and not a FAIL: he did not score the increment, he replaced the question. His words, in
full: *"Ok I used my thumb. I think the icon you're using makes it look like you can drag and drop
the short break, not hold and slide. Let's just make the thing 50% bigger, have a skip button on
the side, and make it look like a small section similar to work. If that should be another phase
thats fine."*

**Whether 68dp beat 52dp for raw acquisition is now unknown and will stay unknown** — it stopped
mattering the moment breaks became button-only. Recorded as unmeasured rather than quietly
converted into a PASS by the redesign that followed it.

**This is exactly the escape hatch this item wrote for itself.** The paragraph above says: *"if
Item 1 fails again... the fix this time would have to be structural (a different affordance, not a
bigger invisible band)."* That is precisely what the owner chose. The prediction was right; the
remaining headroom was correctly described as gone; the structural answer arrived on schedule. See
**D-32-01** and **D-32-02** in ROADMAP Phase 32.

---

## Item 2 — Can you SEE what to grab? (D-31-06 part 2)

This is the new question, and it is the one that addresses the actual root cause round one
uncovered: 52dp already cleared **both** Material's 48dp and iOS's 44pt minimums **on paper**, and
those minimums assume a target the user can **see**. SKIPBREAK-02 forbids painting into the slop,
so before this change the thumb had to land within ±16dp of a 20dp hairline by feel alone, with
nothing to look at.

- **(a) Is there a small grip glyph visible at the left end of the `Short break` label?**

  **Verdict: ✅ PASS.** He saw it, identified it specifically, and described what it communicates —
  none of which is possible if it were invisible. The visibility half of D-31-06 part 2 worked.

- **(b) Does it read as "grab here" — or as decoration, an artifact, or a rendering glitch?**

  **Verdict: ❌ FAIL — and this is the finding of round two.** Owner, 2026-08-27: *"the icon you're
  using makes it look like you can drag and drop the short break, not hold and slide."*

  Not decoration and not a glitch — **the wrong verb.** `Icons.drag_indicator` is Material's
  six-dot reorder grip, whose established meaning is *pick this up and move it somewhere else* (the
  drag handle in a reorderable list). The gesture actually wired to it is a horizontal
  swipe-to-dismiss. The glyph was chosen for being *visible and small enough to fit a 20dp row* —
  the constraint everyone was optimising against — and nobody checked what it *says*. It was
  legible and it was wrong, which is a harder failure to catch than an invisible one and is
  invisible to every test in the suite: `flutter test` can assert an `Icon` with codepoint `0xe207`
  renders, and has no opinion whatsoever about what a human thinks that icon means.

- **(c) At arm's length, can you find the break's grab point without hunting for it?**

  **Verdict: unanswered.** Not reported separately; (b)'s finding overtook it.

- **(d) It deliberately disappears once a break is already skipped.** Does that read as correct,
  or does its absence look like something is missing/broken?

  **Verdict: unanswered.** Not reported.

**Round-two verdict: ❌ FAIL on meaning, PASS on visibility.** The glyph is plainly visible and the
owner read it instantly — but read it as the wrong gesture. D-31-06 part 2 solved *findability* and
introduced a *semantics* defect in its place. The whole affordance is superseded by **D-32-02**
(a labelled Skip button, no glyph, no swipe).

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

  **Verdict: unanswered.**

- **(b) Skip it. Does the row stay exactly where it was on the timeline, at the same height?**

  **Verdict: unanswered.**

- **(c) Does the red now-line stay in the same place, or does it jump?**

  **Verdict: unanswered.**

- **(d) Is there any visible sign the skip landed — the title struck through?**

  **Verdict: unanswered.**

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

**Verdict: unanswered.** Flagged in advance precisely so it would not be stumbled on later, and it
still needs a ruling. Carried into Phase 32 rather than assumed either way.

**Round-two verdict: ⊘ UNJUDGED.** The owner did not reach Item 3. D-31-07's live-break skip is
code-complete and test-proven (639/639, including truth #14's composition) but **has never been
confirmed by a human on a device**. Phase 32 changes this surface again — the compact-tier Skip
button survives D-32-02, the live-break *swipe* does not — so Phase 32's UAT must re-ask it.

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
issues: 1
pending: 0
skipped: 0
blocked: 2
```

Judged by the owner **2026-08-27**. One real verdict, and it is not the one this round expected.

- **Item 1 — SUPERSEDED, not scored.** The owner rejected the swipe approach rather than measuring
  whether 68dp beat 52dp. That number is now permanently unknown, and is recorded as unmeasured
  rather than quietly upgraded to a PASS by the redesign that replaced it.
- **Item 2 — the finding. Visible (PASS) but semantically wrong (FAIL).** `Icons.drag_indicator`
  reads as *reorder*, not *swipe away*. D-31-06 part 2 fixed findability and introduced a meaning
  defect in its place.
- **Item 3 — UNJUDGED.** Never reached. D-31-07 is code-complete and test-proven but has still
  never been confirmed by a human on a device.

## Gaps

<!-- YAML for gap consumption. NOTE: these do NOT route to `/gsd-plan-phase 31 --gaps`.
     The owner's ruling replaces the mechanism rather than repairing it, and one of the two
     decisions reverses a locked Phase 29 constraint, so the work is Phase 32. -->

- truth: "A real thumb can reliably GRAB a 5-minute break's row by swiping (SKIPBREAK-01, D-31-06 round two)"
  status: superseded
  reason: "Owner, 2026-08-27, after testing with his thumb: he did not score the five attempts, he replaced the approach. Breaks become button-only (D-32-02), so raw swipe-acquisition on a 20dp row stops being a question this project needs answered."
  severity: major
  test: 1
  root_cause: "Not established, and now never will be. Whether kBreakHitSlop 24.0's 68dp band outperformed 16.0's 52dp is unmeasured. Recorded as unmeasured rather than inferred."
  artifacts:
    - path: "lib/screens/today/timeline_geometry.dart"
      issue: "kBreakHitSlop = 24.0 and kMinBreakDragTarget become dead code once breaks are button-only (D-32-02). Retire deliberately in Phase 32; do not leave an unused invisible-band mechanism in the tree."
  owner_ruling: "SUPERSEDED by D-32-01/D-32-02. Scale the whole timeline 50% and replace the swipe with a visible Skip button."
  missing:
    - "Phase 32 must retire the slop machinery it makes dead, not merely stop using it."
  debug_session: ""

- truth: "The grip glyph is findable by eye and reads as a grab affordance (D-31-06 part 2)"
  status: failed
  reason: "Owner, 2026-08-27: 'the icon you're using makes it look like you can drag and drop the short break, not hold and slide.' Findability PASSED - he saw it and named it unprompted. Meaning FAILED."
  severity: major
  test: 2
  root_cause: "Icons.drag_indicator is Material's six-dot REORDER grip; its established meaning is 'pick this up and move it', while the wired gesture is horizontal swipe-to-dismiss. The glyph was selected for fitting inside a 20dp row - the constraint under optimisation - and its semantics were never evaluated. No test in the suite can catch this: flutter test asserts an Icon with codepoint 0xe207 renders and has no opinion on what a human thinks it means."
  artifacts:
    - path: "lib/screens/schedule/widgets/chunk_card.dart"
      issue: "kSubCompactGripSize / Icons.drag_indicator inside _SubCompactRow. Removed entirely by D-32-02 - a labelled Skip button needs no grip glyph."
  owner_ruling: "RULED 2026-08-27 (D-32-02): drop the glyph and the swipe. A visible Skip button on the side, breaks styled as a small section like work."
  missing:
    - "Remove the grip glyph and its tests along with the swipe path."
    - "Carry the lesson, not just the fix: an affordance can be perfectly legible and still say the wrong verb, and this class of defect is invisible to the entire test suite by construction."
  debug_session: ""

- truth: "A break that is currently running can be skipped, and the now-line does not move when it is (D-31-07)"
  status: unjudged
  reason: "The owner never reached Item 3. Code-complete and test-proven (639/639, including verification truth #14's composition proof) but never confirmed by a human on a device."
  severity: minor
  test: 3
  root_cause: ""
  artifacts:
    - path: "lib/screens/today/widgets/live_row_card.dart"
      issue: "showComplete/isSkipped - the compact-tier Skip button SURVIVES D-32-02 and is closer to what the owner asked for than the swipe ever was."
    - path: "lib/screens/schedule/widgets/swipeable_chunk_card.dart"
      issue: "SwipeableRowShell live-break wiring - the live-break SWIPE path does NOT survive D-32-02."
  owner_ruling: ""
  missing:
    - "Phase 32's UAT must re-ask this. It was never answered, and Phase 32 changes the surface underneath it."
    - "The 'Up next' delisting transition (now_state.dart:176) still needs an explicit owner ruling - flagged in advance, still unanswered."
  debug_session: ""
