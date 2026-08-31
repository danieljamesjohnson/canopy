---
gsd_state_version: 1.0
milestone: none
current_phase: 32
current_phase_name: Breaks You Can Tap
status: complete
stopped_at: Phase 32 COMPLETE — round-two UAT 4/4 on 2026-08-31, thumb count 5/5, D-31-07 confirmed. No phase in progress.
last_updated: "2026-08-31T12:00:00.000Z"
last_activity: 2026-08-31
last_activity_desc: Phase 32 closed — 4/4 UAT, both long-running gaps closed
state_head: 62cfa62
progress:
  total_phases: 6
  completed_phases: 5
  total_plans: 30
  completed_plans: 30
milestone_name: milestone
---

# Execution State

**Project:** Canopy
**Created:** 2026-02-24
**Last session:** 2026-08-27T15:22:43.488Z

---

## Current Position

Phase: 32 (Breaks You Can Tap) — **COMPLETE 2026-08-31.** No phase in progress.

**Round two: 4 of 4 PASS** (`32-UAT-R2.md`). Items 1, 3, 4 by the owner; Item 2 agent-verified
structurally, recorded as such rather than flattened into the count.

**Two gaps that had survived three rounds are closed, and each closed a different way — the
difference is the lesson.**

- **G-32-03 (the thumb count) closed by finally asking for the number, in a form that took one
  tap.** Three rounds returned "it seems to work," which is the mechanism firing, not the target
  being hittable. The answer is **5/5 on a 64×30dp visible rail**. That turns D-32-03's deliberate
  trade — 1920dp² of *painted* target against Material's 2304dp² guideline — from an argument into
  a measurement. Phase 31 met the number twice with an *invisible* band and failed a thumb both
  times; "a visible target that misses the spec slightly beats an invisible one that meets it" is
  now evidence rather than reasoning.
- **G-32-05 (D-31-07's live break) closed by driving the app instead of asking a fourth time.**
  Its sub-questions were structural — is the control present, is Complete absent, does the row keep
  its slot — and a browser answers all three. **"Needs a human" is a claim about the *kind* of
  question, not a property of the item.** Perceptual and touch judgments genuinely need a thumb
  (Phases 27, 29, 31 each proved it); "is the button there" never did, and routing it to a human
  three times produced three non-answers. Verified: a live 30-min break exposes exactly one `Skip`
  node and **no** Complete while work chunks on the same screen expose `CompleteSkip`; a live 5-min
  break has a rail at all (it had no button of any kind before this phase); and the row measured
  **h=180 before the skip and h=180 after**, with the now-line staying on its clock position.
  Screenshots in `shots/`.

**Round one failed 0-of-4 on appearance, and the cause was mechanical, not stylistic.** Every
timeline row was laid out at its card's NATURAL height and top-aligned inside a duration-exact
slot (`OverflowBox(alignment: topCenter, maxHeight: infinity)`), so a ~83dp work card in a 150dp
slot trailed ~67dp of dead background. **D-32-01 did not create this** — at 4.0 the same mechanism
left ~17dp and read as ordinary card spacing. Raising the scale made a pre-existing flaw visible
everywhere at once, which is why reverting to 4.0 would have hidden the symptom and handed back
the hairline break two phases existed to remove.

**The process answer, asked and answered on 2026-08-28: `/gsd-sketch`, not a new tool.** Phase 32
HAD a UI-SPEC — written, reviewed, passed a checker 6/6. Every constant in it was derived and
defended in prose, and the phase's one "real-browser measurement" was a **tight crop of the single
card being optimised**. Nobody rendered a full day and looked at it. That is the identical failure
shape as Phase 31's `drag_indicator`: locally provable, wrong at the altitude a human sees. Sketch
002 served three whole-screen variants at the real geometry; the owner chose **C · Adaptive fill**.

**What shipped (`0d9777c`).** A row is sized by its duration; its content adapts to the height it
gets. The fix re-uses the explicit `durationMinutes * kPixelsPerMinute` height that `_buildBreak`
had already proved in the same file — which is precisely why breaks never showed the defect. `full`
work cards earn a goal/duration line above `kRoomyWorkMinHeight` (120dp) and pin their actions to
the bottom edge; the long break's full-height `errorContainer` slab becomes the same centred
`OutlinedButton.icon` a work chunk uses, which also closes the two-arrangements-one-vocabulary
observation. The short break's 64×30 rail is untouched — nothing contradicted it.

**Looking, not reading, found the second half of the bug.** After `chunk_card.dart` was fixed the
work chunks stopped leaving holes and a screenshot showed the LIVE row still sitting in one:
`LiveRowCard._buildCompact` returned a bare `Card` sized by `MainAxisSize.min` while its own
sibling `_buildSingleLine` already wrapped itself in `SizedBox(height: slotHeight)` — **two tiers
of one widget disagreeing about whether a row owns its slot.** Code review had not surfaced it; a
rebuild-and-look did, on the first pass.

**Two tests repointed, and the second repoint matters more than the first.** Both pumped a
5-minute break at `full` density — 30dp — a combination the app *cannot produce* (`full` is only
picked at ≥88dp). **Testing the tall tier at its smallest unreachable size is how "one shape fits
both tiers" survived review.** They now use a reachable long break and assert the reported defect:
the Skip must be under half the card's height. Proven non-vacuous by restoring the stretch
geometry and watching it fail — 142dp Skip in a 150dp card against a 75dp bound.

**Three gaps remain OPEN and are why round two exists.** G-32-03: the five-attempt thumb count has
**never been taken in any round** — round one superseded it, round two never reached it, round
three answered "it appears to be working," which is not a count. G-32-05: D-31-07's live-break
Skip is test-proven since 2026-08-26 and confirmed by a human **zero** times, always because it
sits behind the items that fail first. **Both now lead `32-UAT-R2.md`, above the visual items** —
ordering is the fix, since three rounds of good intentions did not get to them. G-32-04 (the
method gap) is closed by the sketch itself.

**Step 0 is deliberately NOT required this round, and the reason is recorded rather than assumed.**
Trap #4 binds any UAT judging *scheduling-engine output*; this diff is `chunk_card.dart`,
`live_row_card.dart` and one geometry constant — all rendering. A previously-generated day renders
through the new code on load. If a future round touches the generator, the rule returns.

**Code review is clean** (`32-REVIEW.md`, no blockers). One LOW finding stands, deliberately
unfixed while the UAT gate is open: `live_row_card.dart`'s `BreakSkippedIndicator` branch is
unreachable because `showActions: isBreak ? !chunk.isSkipped : true` drops the whole `SizedBox`.
Route it with whatever round two produces.


**2026-08-28 — nothing moved, and the reason is not a blocker an agent can clear.** The gate is
Dan's thumb on `http://danserver:8143/`; every item in `32-UAT.md` is perceptual by construction.
Re-verified rather than assumed: the server is still up (PID 1100897, started 2026-08-27 10:20) and
the bytes on the wire still match the built bundle exactly (sha `3ec8946…af943` both sides), so the
pre-flight recorded in `32-UAT.md` is still true today and does **not** need re-running. Suite
re-run on this tree: `flutter analyze` clean, **621/621 green**.

**The one gate that could be closed without him was, and it is now closed.** Phases 29 and 31 each
got a code review before their human UAT; Phase 32's plan list has no review wave and reached its
gate without one. `32-REVIEW.md` (2026-08-28) — **no blockers**, one LOW finding, one observation
routed into the UAT.

- **The LOW finding is dead code this phase added while deleting Phase 31's.**
  `live_row_card.dart:395-401` gates the whole rail `SizedBox` on `showActions` and *then* branches
  on `isSkipped` inside it, but the only call site passes
  `showActions: isBreak ? !chunk.isSkipped : true` — so `BreakSkippedIndicator` there is
  unreachable, and unreachable for work chunks too (that tier needs <14.67 min; the generator only
  emits 25). No user-visible failure: `resolveNowState` delists a skipped chunk, which the tests
  already say out loud in Case C's own name. It matters because `BreakSkippedIndicator`'s class doc
  claims *"the rail's own 64dp slot keeps its exact width"* — **true in `chunk_card.dart`, false in
  `live_row_card.dart`**, so a future reader who makes that state reachable inherits a silent
  reflow. **Deliberately not fixed**: the file is under an open UAT gate and changing served bytes
  would invalidate the pre-flight Dan is about to judge against. Route it after the verdict.

- **The observation is a surface Dan would otherwise meet cold at Item 4(a).** A *running*
  30-minute break shows D-31-07's preserved **icon-only** Skip (word only in the tooltip), not the
  labelled pink rail Items 1–3 show him. That is ruled by the ROADMAP's own "must NOT do" list, not
  a defect — but the item asks "is there a Skip action," so he is told before he judges. Added as
  the third orchestrator observation in `32-UAT.md`.

**What review could NOT do, stated plainly:** none of this touches whether the rail reads as one
button or two zones, or whether a thumb lands it five times out of five. Green suites have been
contradicted by Dan's thumb in Phase 27, Phase 29, and Phase 31 — twice in 31. The verdict is his.

Phase 31 is **superseded, not failed**: 31-06 and 31-07 shipped and are green, 31-08's UAT was
judged, and the owner replaced the approach rather than repairing it.

**Round-two UAT judged 2026-08-27, and it found something no test could.** The owner used his thumb
on the served build and reported: *"the icon you're using makes it look like you can drag and drop
the short break, not hold and slide. Let's just make the thing 50% bigger, have a skip button on the
side, and make it look like a small section similar to work."*

**The defect is semantic, not dimensional.** `Icons.drag_indicator` is Material's six-dot *reorder*
grip — it means "pick this up and move it," while the wired gesture was swipe-to-dismiss. The glyph
was picked for fitting inside a 20dp row, which was the constraint under optimisation, and **nobody
asked what it says.** It was perfectly legible and completely wrong. This class of defect is
invisible to the entire suite by construction: `flutter test` can assert an `Icon` with codepoint
`0xe207` renders and has no opinion on what a human thinks it means. **Item 2 therefore split — PASS
on visibility, FAIL on meaning.**

**Item 1 was superseded, not scored, and that is recorded honestly.** The owner rejected the swipe
approach rather than counting five attempts, so whether 68dp beat 52dp for raw acquisition is
**permanently unmeasured**. It is not written up as a PASS just because a redesign followed it.
**Item 3 (D-31-07, live-break skip) was never reached** — code-complete, test-proven at 639/639
including verification truth #14's composition, and still never confirmed by a human on a device.

**Two owner rulings, both reversing standing decisions, both asked rather than assumed:**

- **D-32-01 — `kPixelsPerMinute` 4.0 → 6.0**, reversing Phase 29 D-03. Chosen over three
  alternatives *because it keeps the grid honest*: every row still renders at exactly
  `durationMinutes × kPixelsPerMinute`, so nothing lies about its duration. Accepted cost: the day
  is 50% taller to scroll. The rejected options all bought a bigger break by making some row lie.

- **D-32-02 — breaks become button-only**, reversing D-31-01's `Dismissible` for breaks and making
  **all of D-31-06 dead** — slop, drag target, Layer 1b pass, grip glyph. Phase 32 must *retire*
  that machinery, not merely stop calling it. Accepted inconsistency: work chunks stay swipeable, so
  breaks and work no longer share a gesture vocabulary; the owner was shown that and took it.

**The sharpest trap waiting in Phase 32:** `kPixelsPerMinute` is load-bearing for every pixel
assertion in a 639-test suite, and many hardcode geometry derived from 4.0. **A find-and-replace of
those expected values is exactly how a suite stops being able to fail** — the carried-forward defect
class of this whole project. Re-derive from the constant; justify each remaining literal per test.
Second trap: `kSubCompactBreakMinHeight` (32.0), `kMinBreakDragTarget` (48.0) and
`kCompactLiveMinHeight` (88.0) were all tuned against 4.0. At 6.0 a 5-min break is 30dp — **still
under the 32dp sub-compact threshold, so it would still render as the hairline the owner is trying
to get rid of** unless the thresholds move too.

**The stale-server trap fired again, one round later.** Round one found a two-day-old server
squatting port 8143 and nearly judged the wrong bundle. That same server (PID 2357258, started
2026-08-24 09:49) was *still* listening at the start of this UAT — still serving the pre-fix bundle
the owner already judged FAIL. It was killed and replaced before verification. Anyone serving this
project on a reused port should check the port before trusting what is on it; this has now happened
twice.

**A presence-probe trap worth carrying forward.** The pre-flight's name-greps for wave 1's grip
(`drag_indicator`, `kSubCompactGripSize`) both returned **zero** on a bundle that definitely contains
it. `dart2js` const-folds both — an icon survives only as its codepoint (`0xe207` = 57863, present 4×
in the served bytes), and a `const double` inlines to a literal. **A name-grep is only a valid
presence probe for symbols dart2js preserves.** Reading a zero as "the feature is missing" would have
sent a working build back for a pointless rebuild.

**One deviation, verified rather than accepted.** Plan 31-07's literal Case B asked for a break that
is simultaneously live and skipped. That state is unreachable: `now_state.dart:176`
(`while (active.isCompleted || active.isSkipped)`) unconditionally advances past a resolved chunk of
any type, even mid-window — pre-existing and already tested. The executor proved the reachable claim
instead (the same chunk's confined band keeps its 20dp slot height and Stack-relative position across
the live→resolved transition, and the now-line does not move) and documented it, rather than editing
a heavily-tested state machine or quietly softening the assertion. Verification truth #14 is now
proven rather than abstaining — but `/gsd-verify-work` should re-score it against that deviation.

**Breaks can be skipped — but not reliably by a thumb, which is the whole point.** All five plans
executed, 625 tests green, `flutter analyze` clean, code review no blockers, 12/12 code truths
verified. Then the owner picked up a phone: Items 2 and 3 PASS, **Item 1 FAILS** — the 20dp break
row is too hard to grab. **Resume with `/gsd-execute-phase 31 --gaps-only`.**

**Gap closure planned 2026-08-26, on two rulings the owner was asked for rather than assumed.**
`/gsd-plan-phase 31 --gaps` stopped before planning and put both open questions to him, because the
UAT's own gap list flagged one as "a genuine design question, not a constant tweak" and left the
other explicitly *unruled* rather than reading silence as consent:

- **D-31-06** — the Item 1 acquisition fix is **both** `kBreakHitSlop` 16.0 → 24.0 **and** a visible
  grip glyph inside the existing 20dp label row. Slop-only was offered and declined, and that
  matters: 52dp already cleared Material's 48dp and iOS's 44pt *on paper*, and those minimums assume
  a target the user can **see** — SKIPBREAK-02 makes this one invisible by construction. 24 is also
  a derived ceiling, not a preference; at 32 the neighbouring work chunk drops to 36dp and the defect
  simply moves next door. `dismissThresholds` stays untouched — the reported failure is acquisition,
  not completion.

- **D-31-07** — resolves PD-31-06: a currently-live break becomes skippable, **Skip only, never
  Complete**, shipping with the Item 1 fix so one human UAT re-run covers both.

**The plan is larger than D-31-07's literal wording, deliberately and with the reason recorded.**
`LiveRowCard` picks its tier from `slotHeight` — `_buildCompact` at/above 88dp, `_buildSingleLine`
below — so a live 30-minute break gets buttons and a live **5-minute** break gets none at all. Since
5-minute breaks arrive every 25 minutes, the button-only fix would have shipped a Skip the owner
rarely meets. 31-07 therefore also extracts the shipped `Dismissible` into `SwipeableRowShell` so
live rows get the same leftward swipe. The plan-checker read `LiveRowCard` directly and judged the
extraction **necessary, not scope creep**.

**One vacuity trap caught at planning time.** The existing `SKIPBREAK-02 — the grid is unchanged`
test measures a `ClipRect` that `_confineContent` makes `visualHeight` tall *by construction,
regardless of its child* — it would stay green if the grip inflated the row by 10dp. Replaced with
an unbounded natural-height measurement. Relatedly, 31-06's new band test uses a bare literal `22`
rather than symbolic `kBreakHitSlop`, because every existing symbolic origin moves with the constant
and therefore could never have distinguished a 52dp band from a 68dp one — which is exactly why 625
green tests missed this defect.

**This gap closure ends in another blocking human UAT, and that is not negotiable.** The defect being
fixed is invisible to automation by construction: a synthetic drag at an exact coordinate cannot tell
a 52dp band from a 68dp one. Green suites have now been contradicted by a thumb three times in this
project (Phase 27, Phase 29, Phase 31).

**Phase 31 (Breaks You Can Skip)** deleted `SwipeableChunkCard`'s `chunkType != ChunkType.work`
early return so every chunk row gets one unconditional `Dismissible` (the `promote` decision — work
chunks keep `startToEnd`, the second reveal, and `onTap` as additive variant details; breaks get
skip only, and stay untappable by the owner's instruction). A 5-minute break's 20dp row now clears
the 48dp touch minimum via `kBreakHitSlop = 16.0`, which grows the row's `Positioned` hit box while
`Align(center) + SizedBox(height: slot)` confines every painted pixel to the exact duration slot —
SKIPBREAK-02 intact, proven per-tier per-state. Guard 9 (`next.isSkipped`) closed a D-31-05 gap this
phase's own skippability newly made reachable.

**Two corrections worth remembering, both found after the artifact that asserted otherwise had
already been approved.** (1) The UI-SPEC's central hit-test proof was half wrong: `RenderBox.hitTest`
bounds every box to its own `size` regardless of clip, so the envelope could not be grown inside the
existing `ClipRect` — the `Positioned` itself had to grow with the clip pushed down inside it.
(2) The same proof claimed the mechanism was "independent of z-order." It is not. `Stack` resolves
overlap by last-added-child-wins, and `timelineRows` is chronological, so the break beat the
*preceding* work chunk but **lost to the following one** — halving the real target to ~36dp, still
under both platform minimums, and it would have shipped looking green. Fixed with a dedicated
Layer 1b `Stack` pass, and pinned by a test proven non-vacuous by deleting the pass and watching
the named thief (`w2`) appear in the failure. The plan-checker had passed that spec 6/6 before
research existed — **a design contract approved before its research is not yet load-bearing.**

**Phase 29 (Breaks You Can See)** gave the break card a sub-compact density tier, so a 5-minute
break's 20dp slot renders a legible hairline-with-label instead of being clipped by `ClipRect` to a
divider-like sliver. `kSubCompactBreakMinHeight = 32.0`, measured in a real browser, not estimated.
Owner's verdict: reads as a break at a glance, label legible, day still looks right around it.

**Phase 30 (Breaks In Committed Time)** fixed the defect the owner reported *twice*. Phase 28's
lattice had only ever been applied to the discretionary packing loop; `schedule_generator.dart`
Step 1 walked a commitment window with a bare `cursor += 25`, so a committed `Work` block ran
back-to-back 25-minute chunks all day. Now `ScheduleGeneratorService.buildCommitmentChunks` applies
the 25+5 lattice inside the window, seeded from the block's own *unrounded* start, with its own
independent long-break cadence counter (D-30-01). D-01 held: the block's start and end never move —
confirmed by the owner against his real appointment times.

**Three defects were caught that the plans did not anticipate, and the pattern is worth keeping:**

1. Research found STEP E's trailing trim could silently delete a tail-stretched *commitment* break,
   erasing real covered minutes from inside the user's window. Narrowed to `commitmentId == null`.

2. Research also found `schedule_notifier.dart:addEventToday` duplicating the identical
   `cursor += 25` defect via a second path reaching the same timeline. Fixed by **deleting** the
   duplicate and sharing the helper (D-30-03) — the drift vector removed, not patched. A deliberate
   scope extension beyond the ROADMAP's `schedule_generator.dart`-only boundary, taken because this
   bug had already been missed twice by scoping too narrowly.

3. Code review caught a blocker **the phase itself introduced**: `_trimTrailingNonWork` got the
   `commitmentId` narrowing but not the matching `shortBreak` guard, so any day ending on a
   discretionary long break lost that break *and* its preceding short break from persisted Hive
   state on every `addEventToday` call. 597/597 passed with that live — no test seeded that shape.
   Fixed with a regression test proven RED first.

**Why this took three attempts, and what changed.** The 2026-08-21 diagnosis blamed stale Hive data
and was wrong. The probe that day swept all five moods and both goal types — but never built a
commitment block, which was the one half of the code path that was broken. **A probe that covers
only the branch you already believe is fine does not license a conclusion about the whole
function.** Trap #4 (data layer: an already-generated day is never regenerated on load) is now
promoted into `CLAUDE.md`, and every UAT that tests generator output must say so in its own
instructions.

Next: **close Item 1's gap.** `/gsd-plan-phase 31 --gaps`. The design question is real — a bigger
invisible band has a hard ceiling (~24–26dp) before it starves the neighbouring work chunk, so
"raise the constant" may not be the whole answer. One owner ruling is also still outstanding
(PD-31-06, the live-break affordance). Phases 27–31 all sit outside any milestone; v1.6 is not yet
defined.

Status: Executing Phase 32
Last activity: 2026-08-27 — Phase 32 execution started

```
v1.0 ✅  v1.1 ✅  v1.2 ✅  v1.3 ✅  v1.4 ✅  v1.5 ✅  →  27 ✅  →  28 ✅  →  29 ✅  →  30 ✅  →  31 ⚠ gap  →  v1.6 not yet defined
```

**Uncommitted-to-a-milestone work is deliberate here.** Phases 27–31 sit outside any milestone. If a
v1.6 is opened before it ships, fold it in rather than leaving it orphaned.

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-08-14)

**Core value:** Generate a usable daily schedule every morning — one that reflects your real goals and how you actually feel.
**Current focus:** Phase 32 — Breaks You Can Tap

## Shipped Milestones

| Milestone | Phases | Shipped | Archive |
|-----------|--------|---------|---------|
| v1.0 Core Product Loop | 1-6 | 2026-02 | `milestones/v1.0-phases/` |
| v1.1 Actually Daily | 7-11 | — | `milestones/v1.1-phases/` |
| v1.2 Make It Usable | 12-14 | 2026-06-13 | `milestones/v1.2-ROADMAP.md` |
| v1.3 An Honest Day | 15-17 | 2026-06-14 | `milestones/v1.3-ROADMAP.md` |
| v1.4 Energy-Aware | 18-20 | 2026-06-15 | `milestones/v1.4-ROADMAP.md` |
| v1.5 Right Now | 21-26 | 2026-08-14 | `milestones/v1.5-ROADMAP.md` |

## Carry-Forward Invariants (read before touching lib/screens/today/)

These cost real effort to establish across v1.5 and are the specific regressions this codebase
guards against:

- **One now-detector.** `resolveNowState` — one definition (`lib/screens/today/now_state.dart`),
  one call site (`lib/screens/today/today_screen.dart`). Doc-comment cross-references elsewhere are
  fine. Phase 22 eliminated parallel detectors; a code review caught a third.

- **One minute→pixel authority.** `TimelineGeometry` — rows, hour axis, now-line and the scroll
  target all derive offsets from it, so they can never disagree about where a minute sits. No
  independent offset arithmetic anywhere.

- **The tick contract (Phase 23).** All-day ticker is 1-minute and survives `paused`; a 1-second
  ticker exists ONLY inside the final minute of the current activity; `_isBackgrounded` guards the
  fast tick; `build()` self-heals a dead timer. Do not add an all-day faster ticker.

- **Clock injection.** Never call `DateTime.now()` in `lib/screens/today/` — use the injectable
  `_nowFn`, sampled once per `build()`. Phase 25's `DevClock` depends on this; bypassing it silently
  breaks time-travel for whatever surface does so.

- **Test-harness caveat.** `flutter test`'s placeholder font inflates glyph widths. Any *text-driven*
  measurement asserted in a widget test is a harness bound, not a device requirement — verify in a
  real browser. `kGutterWidth` went 46 → 75 (harness) → 52 (corrected). Geometric assertions
  (heights and offsets computed from arithmetic) ARE trustworthy.

- **Regression tests must be proven RED.** v1.5 shipped two defects behind green tests, both
  assertions that could not fail — one scoped to the wrong widget type, one counting widgets instead
  of checking painted rects. Observe red against the unfixed code before accepting a regression test.

## Accumulated Context

### Roadmap Evolution

- **Phase 27 added 2026-08-18: True Grid.** Out of post-v1.5 UAT on the Today timeline. Added as a
  standalone phase, not a milestone — owner judged it too small to open v1.6. Build-vs-buy was
  settled at add time (searched pub.dev; `kalender` credible but rejected — see the phase entry in
  ROADMAP.md for the reasoning and the conditions that would flip it).

- **Phase 28 added 2026-08-19, completed same day: The Day Is a Lattice.** Out of Phase 27's UAT —
  the owner said "the schedule still isn't functioning right." Engine-side, not UI. Also standalone
  rather than opening v1.6. Adaptivity was raised and explicitly declined: N stays set once from the
  morning check-in mood.

- **Phase 29 added 2026-08-20: Breaks You Can See.** Out of Phase 28's UAT — the owner reported "no
  5 minute breaks in between." Diagnosed before adding: the engine is correct, the breaks are
  emitted on the lattice, but a 5-minute break's slot is 20dp (`5 × kPixelsPerMinute`) while its card
  needs more, so `ClipRect` silently clips it to a divider-like sliver. **Pre-existing, from Phase
  27's duration-exact slots — not a Phase 28 regression.** Approach decided at add time (option 1, a
  sub-compact density tier); options 2 and 3 recorded with the reasons they lost. Evidence:
  `.planning/seeds/SEED-005-five-minute-breaks-clip-to-a-sliver.md`.

- **Phase 30 added 2026-08-24, completed 2026-08-25: Breaks In Committed Time.** Out of Phase 29's
  UAT — the owner reported "no 5 minute breaks" a second time, on a freshly generated day. The
  2026-08-21 diagnosis (stale Hive data) was **wrong** and is kept in `29-UAT.md` rather than
  deleted, because how it was reached matters: the probe that day swept all five moods and both goal
  types but never constructed a commitment block, which was the broken half. Real cause:
  `schedule_generator.dart` Step 1 walked a commitment window with a bare `cursor += 25` — Phase 28's
  lattice was only ever applied to the discretionary packing loop. Scope was deliberately extended
  beyond the ROADMAP's `schedule_generator.dart`-only boundary to also fix `addEventToday`, which
  duplicated the identical defect via a second path (D-30-03).

- **Phase 31 added 2026-08-21: Breaks You Can Skip.** Out of the same 2026-08-21 feedback drop
  ("Breaks are fully functional features, with timers, etc."), with the owner's own scope call:
  *"don't add tappable then. Just make it skippable like the other ones."* Tappable is explicitly
  out. Gated on Phase 29's UAT verdict, which cleared 2026-08-25. Not started.

### Decisions

Key decisions are in PROJECT.md. Decisions relevant to v1.5:

- [v1.5 roadmap]: Phase 21 (engine + copy) is parallel-safe with Phase 22 (screen merge) — no shared surface, so either can run first.
- [v1.5 roadmap]: Phase 23 (live activity tracking) sequenced after Phase 22 (unified screen) — the live readout is layered onto the merged screen's now-state rather than built against the soon-to-be-replaced split Home/Schedule screens.
- [v1.5 roadmap]: LIVE-02's tick granularity (per-minute vs. per-second) deliberately left open — flagged for Phase 23 planning to decide and justify, not inherited silently from the existing 1-min `Timer.periodic`.
- [Phase 14-02]: Priority drives composite score (remainingHours × priorityWeight) for time-targets; habit sort pre-filtered by priority.
- [Phase 19-energy-valence]: EnergyValence is a plain Dart enum with no @HiveType — stored as int index in Goal.energyValenceIndex (HiveField 12) — Follows existing GoalType/ChunkType pattern; no new typeId needed; neutral=0 ensures old records read correctly via getter default.
- [Phase ?]: Align(topCenter)+ConstrainedBox(maxWidth: 720) applied to Home, Goals, Schedule body content for POLISH-01 — relevant precedent for whatever layout Phase 22's merged screen uses.
- [Phase ?]: Valence colors: tertiaryContainer for gives, secondaryContainer for costs — colorScheme.error excluded per UI-SPEC.
- [Phase 21-01]: Cadence table locked to {1:2, 2:3, 3:4, 4:4, 5:5}; isLowMood preserved unmodified, cadence lookup keyed on moodIndex directly (BREAK-01/02)
- [Phase 28 / D-01]: LATTICE-01 governs *generated* chunks only. A user's fixed commitment keeps its own wall-clock time and is never rounded onto :00/:30 — rounding it would move the user's actual appointment.
- [Phase 28 / D-04]: Neither `_moodCap` nor the day's end moves to pay for the lattice. Decided on a simulation of the real packing loop: the lattice costs 10-20 extra minutes across a whole day and every mood fits the 840-minute window with 455-695 minutes of slack.
- [Phase 28 / D-05]: The long break is never *silently* suppressed. A capacity-driven partial reservation is allowed (a slot too narrow for the 35-minute footprint reserves the short break only), and it is proven capacity-driven by a paired fixture whose only difference is 30 minutes of slot width — not by a comment.
- [Phase 28]: N stays set once from the morning check-in mood. Adaptivity (reacting to how the day goes, or carrying over from yesterday) was offered to the owner on 2026-08-19 and declined. It is a different phase, not a smaller version of this one.
- [Phase 21-02]: Reworded the TONE-01 guard assertion's reason string to keep grep -c "TONE-01:" at exactly 2, matching the plan's acceptance criteria; no behavior/coverage change
- [Phase 22-01]: active_chunk_card_test.dart's now_state.dart import kept per plan though unused in executable code today; suppressed with ignore comment to satisfy both the plan's verify grep and a clean flutter analyze — Both the plan's automated verify (grep for the import) and its analyze-clean done criterion are explicit gates in the same task; dropping the import fails the former, leaving it unmarked fails the latter
- [Phase 22-02]: Collapsed chunk_card's _buildShortBreak/_buildLongBreak into one _buildBreak on a single dashed CustomPainter — resolves both D-06's break treatment and the Phase 21 UI review's pill-vs-elevated-Card mismatch, no collapse affordance added
- [Phase 22-03]: Single reconciled AppBar helper shared by TodayScreen's empty and active states makes 'exactly one refresh action' true by construction; Add-an-event stays reachable pre-check-in
- [Phase 22-03]: Task 2's fixture uses a work-typed 5-minute 'live' chunk rather than a real break — resolveNowState's work-only filter is untouched per scope boundary; Phase 23 (LIVE-01) widens it, not this plan
- [Phase 22-04]: Kept /schedule declared (building TodayScreen) instead of deleting it, so /schedule/checkin keeps a parent and the notification-tap path has a defensive fallback if the redirect regresses — T-22-14: belt-and-braces dead-route prevention
- [Phase 22-04]: Generalized the WR-03 no-double-timer test from a hardcoded 1-call assumption to a captured per-tick baseline, since TodayScreen reads the clock from 3 call sites per build vs HomeScreen's 1 — The actual invariant (no leaked duplicate Timer.periodic) is preserved; only the call-count magnitude assumption was wrong for the new screen's structure
- [Phase ?]: [Phase 23-01] Broadened resolveNowState by dropping the ChunkType.work filter clause (single-line fix); the KEY INVARIANT ordering and minute-only clock sampling are unchanged — Extends the single now-detector rather than adding a parallel path, per Phase 22's single-detector invariant
- [Phase ?]: [Phase 23-01] _liveKicker checks the two break ChunkType values explicitly rather than != ChunkType.work, to keep the plan's ChunkType.work occurrence-count acceptance criterion exact — Task 2's _liveKicker legitimately added a fourth ChunkType.work site that Task 3's acceptance criteria (written against only 3 pre-existing sites) didn't anticipate
- [Phase 23-02]: _liveSecondsRemaining reads nowState directly (nowState is Active, then nowState.current) rather than taking chunk/start/end as separate parameters — keeps the single-source contract explicit
- [Phase 23-02]: Progress bar formula changed to 1 - secondsRemaining / (durationMinutes * 60), derived from the same secondsRemaining the label uses, so the two can never disagree (D-04)
- [Phase 23-02]: Resume rebuilds via setState rather than re-deriving the <60s condition inline in didChangeAppLifecycleState — keeps _syncFastTimer's build() call site the only place the fast-timer decision is made, and fixes a pre-existing resume-staleness bug
- [Phase ?]: [Phase 23-03]: GapBeforeNext banner unchanged from Phase 22 (P-1) — 23-CONTEXT.md decision 3 supplied verbatim copy for PreStart/DayComplete but only a description for the gap; recorded as a comment-only doc-comment diff above the case
- [Phase ?]: [Phase 23-03]: TodayScreenState._nowFn is late final (set once in initState); multi-state widget tests must force a full unmount (pumpWidget(SizedBox.shrink())) between pumps of different clocks, or the second state's now closure is silently ignored
- [Phase 23-live-activity-tracking]: [Phase 23-05]: G-03 fix stops cancelling _nowTimer on paused (resumed was the only revival path); added _isBackgrounded guard on the fast-timer call site and a build()-time self-heal — resolves the UAT-reported live row stranding without touching the fast-timer battery contract
- [Phase 23-live-activity-tracking]: [Phase 23-05]: Widget tests for AppLifecycleState.paused must deliver AppLifecycleState.inactive before observing rendered state, since SchedulerBinding disables ALL frame scheduling on hidden/paused/detached (packages/flutter/lib/src/scheduler/binding.dart:414-428) and only re-enables it on resumed/inactive — inactive re-enables frame drawing without invoking this app's own resumed handler, isolating what a fix actually contributes
- [Phase 23]: [Phase 23-06]: G-05 implemented as a write-side-only mutation in ScheduleNotifier.markComplete (_absorbReclaimedTimeIntoNextBreak) — moves the following break's start to now and extends its duration to preserve the original end, so resolveNowState reaches Active(break) through its existing unmodified path and the Phase 17 KEY INVARIANT test needs zero changes — Dan's decision (23-UAT.md): 'extend the break to fill' dissolves the conflict the gap analysis flagged between G-05 and the named Phase 17 invariant, since the break's window genuinely opens at now because we moved it
- [Phase 23-08]: G-01 flipped both onboarding_screen.dart and goal_form_sheet.dart energy-valence segmented controls to Drains -> Neutral -> Lifts, per Dan's explicit sign-off decision to keep the two surfaces agreeing on order — Flipping only onboarding would leave the two surfaces disagreeing about which end means drains, the exact failure Dan's decision exists to avoid
- [Phase 23-08]: G-07 placed the mood consequence line in checkin_screen.dart's _buildCheckinBody (pre-commit, above Let's go), not in the acknowledgment text as 23-GAP-ANALYSIS.md suggested — Check-in is a two-step flow; the acknowledgment only renders after generation, so the explanation needs to be visible before commit so Dan can compare moods
- [Phase 23]: kGutterWidth bumped 46.0 -> 75.0 (G-04) — flutter test's placeholder font (no real Roboto metrics loaded) inflates measured glyph width to a fixed fontSize-wide box per character; the widest-label fit test forced a bump documented as a test-harness bound, not a real-device requirement -- flagged for a real-browser recheck.
- [Phase 23]: Chunk count owned solely by ScheduleProgressBar; mood chip states mood only (G-06) — ScheduleProgressBar (completed-of-total + bar) is strictly richer than the chip's bare total, so the chip dropped its duplicate count; 22-UI-SPEC.md amended with a dated note rather than left contradicting the shipped chip.
- [Phase ?]: [Phase 24-01]: buildTimeline's nowMinutes kept optional (int?, default null) rather than required, preserving all 16 pre-existing call sites unchanged (24-RESEARCH.md Pitfall 2)
- [Phase ?]: [Phase 24-01]: Added a minimal NowMarkerRow case to today_screen.dart's exhaustive TimelineRow switch outside this plan's declared file scope -- Dart's sealed-class switch-statement exhaustiveness is a compile error, not a lint, so the app failed to build the moment the fourth subtype existed; the case is unreachable until 24-02 threads a real nowMinutes value into build()
- [Phase 24-02]: nowMinutes = minutesOfDay(nowDt) threaded from build()'s single clock sample into buildTimeline, making the 24-01-added NowMarkerRow switch case reachable; the corrected NOW-02 test proves the leading free row disappears once its window closes
- [Phase 24-02]: New Phase 24 now-marker test group nested inside Task 2's group (not immediately after the day-complete test in Task 3) to reuse Task 2's pumpDay/buildDayFixture helpers directly, avoiding a duplicated clock literal or a diff-inflating hoist to module scope
- [Phase 24-where-am-i]: 24-03 UAT verdict: PARTIAL PASS -- mid-day/between-activities now-marker confirmed by Dan; DayComplete state fails to scroll marker into view (root cause: today_screen.dart:971-972 gates centre-on-open behind hasLiveRow, never true for DayComplete/PreStart/GapBeforeNext); fix routed to gap-closure plan 24-04, not re-opened here
- [Phase 24-where-am-i]: Dan routed two forward ideas (auto-scroll past items, time-proportional calendar view with a moving red now-line) to a new future phase, explicitly out of phase 24 scope
- [Phase 24]: 24-04: separate _didCentreMarker flag (not reused _didCentreLiveRow) fallback-centres the now-marker for PreStart/GapBeforeNext/DayComplete, closing Dan's DayComplete UAT gap; verified via a dedicated two-flag regression test
- [Phase 25-time-travel]: DevClock holds a Duration OFFSET, never a frozen instant — the defining design constraint (DEV-02), so the existing 1-minute ticker keeps advancing under simulated time and Phase 26's moving now-line stays testable
- [Phase 25-time-travel]: Added ScheduleNotifier.reloadToday() (new method, extracted from init()'s load step) rather than calling init() again after a DevClock mutation — init() also registers a WidgetsBindingObserver, and calling it repeatedly would stack duplicate observers
- [Phase 25-time-travel]: This phase had no PLAN.md — the /gsd-execute-phase prompt itself was the plan (design pre-decided, "do not relitigate" per the prompt). SUMMARY.md written to `.planning/phases/25-time-travel/25-01-SUMMARY.md` per the same numbering convention as planned phases
- [Phase 26-01]: kPixelsPerMinute corrected to 5.5 (PD-1), superseding UI-SPEC's 4.0 -- measured 126px Full-tier ChunkCard overflows a 4.0-scale 25min slot by 26px
- [Phase 26-01]: kLiveRowReservedHeight=240.0 as a fixed estimate (PD-2), not a two-pass GlobalKey/RenderBox measurement -- measured LiveRowCard height is 230px
- [Phase 26-01]: Density tiers (kFullTierMinHeight/kFullBreakMinHeight, PD-3) expressed in pixels not minutes, so they do not rot if the scale changes again
- [Phase ?]: [Phase 26-02]: PD-4/PD-5 implemented as specified — ChunkCardDensity defaults to detailed (today's card byte-for-byte); TimelineRowTile.startMinutes deleted outright, gutter column reserved-but-blank — Keeps the four standalone chunk_card_*_test.dart files untouched while making the density/gutter machinery ready for plan 04's Stack wiring
- [Phase 26-03]: NowMarkerRow deleted outright (D-01) — the day now renders as a fixed-height Stack of TimelineGeometry-positioned rows; showStartTime flipped false->true now that the per-row gutter is gone
- [Phase ?]: 26-04: The now-line renders unconditionally in every NowState (PD-12) — Phase 24's Active-suppression rule is deleted from the render path outright, not relocated. — CAL-02's premise is that a proportional layout can place the line truthfully mid-chunk; suppression only ever existed to hide the old between-rows marker at a boundary, which no longer applies.
- [Phase ?]: 26-04: Semantics wraps IgnorePointer at the now-line/hour-axis call sites, not the reverse (PD-13). — Modern IgnorePointer strips its subtree from the semantics tree too — nesting the label inside it would silently delete the 'Now — <time>' screen-reader announcement (24-REVIEW.md WR-01).
- [Phase 26-05]: One _didCentreOnOpen flag and one arithmetic animateTo (stackTop via RenderAbstractViewport.getOffsetToReveal + geometry.yFor(nowMinutes), clamped to maxScrollExtent read only post-layout) replace Phase 24's two flags/GlobalKeys/ensureVisible blocks — the now-line always exists at a computable offset in every NowState, closing the DayComplete UAT gap by construction
- [Phase 26-05]: PD-19: a NowState transition on an already-mounted tree deliberately does NOT re-centre — only a new dateYmd or a DevClock.offset jump re-arms the single flag; a fresh mount always re-centres correctly regardless of state
- [Phase 26-07]: Now-line chip confined to kGutterWidth (SizedBox width, mirroring HourAxisLine), copy switched to formatMinutesCompact; 2dp rule and full-time Semantics label left untouched — Dan's decision (26-UAT.md G-01): honour the UI-SPEC's intent (chip in the time column) and change the string, not the column -- rejected deleting the chip and rejected widening the gutter to ~101dp
- [Phase ?]: 26-08: kLiveRowReservedHeight corrected 240.0->232.0 via real-browser measurement (G-02) — measured LiveRowCard's work variant (tallest, has action row) at 224px natural height in headless Chromium, +8px explicit margin; documented that the correction is smaller than the ~80px original estimate because this card's height is dominated by fixed-size elements rather than text-driven wrapping — Dan chose tightening the fixed-estimate constant over two-pass measurement (26-UAT.md, 2026-08-11); liveExtraPx mechanism and TimelineGeometry API left unchanged
- [Phase 26-the-day-has-a-shape]: G-03: chip suppressed only inside the live row's span (not the whole overlay); rule unchanged — LiveRowCard already states the current time in its own copy, so the chip is redundant there; the rule alone still marks the position
- [Phase 26-the-day-has-a-shape]: 26-10: kTimelineEdgePadding = max(kHourAxisHeight, kNowLineHeight) / 2 reserved at both ends of TimelineGeometry's rendered range, applied in yFor()/totalHeight() only — Closes G-04 (sheared first/last hour-axis label) and G-05 (now-line clipped at PreStart/DayComplete) from 26-UI-REVIEW.md; rejected the one-line Clip.none fix because it would let the top label paint into the header block above the Stack
- [Phase 26-the-day-has-a-shape]: 26-10: formatMinutesCompact gained an 'a' AM suffix, mirroring the existing 'p' for PM — Closes G-06 (26-UI-REVIEW.md) — the now-line chip is the app's most prominent, always-on-screen element and previously showed AM times with no meridiem cue
- [Phase 27-01]: Deleted TimelineGeometry.liveExtraPx and kLiveRowReservedHeight outright rather than zeroing them; yFor() is now unconditionally linear — The defect was the existence of a live-row exception term, not a wrong value -- 240dp/372dp both satisfied every prior test because they all asserted yFor() against the same arithmetic the implementation performed
- [Phase 27-01]: kCompactLiveMinHeight ships as an explicitly UNMEASURED PLACEHOLDER (88.0, PD-27-05) — Wave 2 needs a constant to compile the density-tier switch against; plan 27-04 measures the real value in a real browser and replaces both the number and the doc comment before the phase closes
- [Phase 27-01]: Fixed a pre-existing today_screen_test.dart test by invoking ChunkCard.onTap directly instead of a geometric tester.tap() — This plan's own intermediate_state_notice predicts LiveRowCard now overlaps the row beneath it (today_screen.dart's height fix is out of scope, reserved for plan 27-02); a geometric tap on the row below the live row landed on the overlapping live card instead of the intended row
- [Phase ?]: LiveRowCard's Complete/Skip IconButtons use IconButton.styleFrom(tapTargetSize: shrinkWrap) instead of visualDensity.compact to actually measure 36x36 (Material 3's IconButton always wraps a separate tap-target padding layer that constraints alone can't override)
- [Phase ?]: PD-27-06's live-row tap gate duplicates _buildChunkCard's goal lookups inline at the _buildLiveRow call site rather than sharing a closure, per the plan's explicit instruction
- [Phase ?]: 27-03: Fixed the 8th unforecast failing test (a running break gets the same countdown treatment) rather than deferring it -- 27-02-SUMMARY.md had already investigated and cleared it as the single-line tier's Row/Expanded split rendering the countdown in its own Text with a leading ' . ' prefix, not a regression
- [Phase ?]: 27-03: Deleted the two progress-bar tests outright (D-04 live-break bar, bar-tracks-label) rather than repointing them -- the bar is gone from both live-row tiers by design, the now-line's position within a duration-exact card IS the fraction elapsed
- [Phase 27-04]: kCompactLiveMinHeight measured in a real browser and set to 84.0 (76px raw fill + 8px explicit safety margin), replacing the 88.0 UNMEASURED PLACEHOLDER -- kept separate from kFullTierMinHeight (88.0, 4dp apart, different card layouts, Pitfall 6 resolved explicitly in the doc comment)
- [Phase 27-04]: measure_card_fill.py's fill-colour derivation filters to (saturated AND light/pastel, min channel > 100), not saturated alone -- the naive filter picked the ordinary ChunkCard's darker FilledButton colorScheme.primary background over the live row's lighter primaryContainer fill on the single-line-tier screenshot, since non-live cards outnumber the live row in raw pixel count
- [Phase 27-04]: measure_hours.py prints UNIFORM (240.0/240.0, no 132.0 spread) against the build containing the measured constant, for both a live work chunk and a live break -- GRID-01 proven end-to-end in pixels, not just arithmetic
- [Phase 27-04]: Plan 27-04 Task 3 (human-verify checkpoint: 36dp touch targets on a real device, now-line legibility, uniform grid) is PENDING as of 2026-08-18 -- Tasks 1-2 committed (1ca4204, 7d0a1e6), 27-04-SUMMARY.md documents the paused state; do not treat this plan or Phase 27 as complete until a human verdict is recorded
- [Phase 28-01]: Corrected the plan's commitment-block-chunking assumption (45-min window emits ONE anchored chunk stretched over the window, not two of 25+20) via empirical verification; re-derived the D-01 GUARD and narrow-slot fallback fixtures accordingly
- [Phase 28-02]: Task 2's render test uses testWidgets(), not test() -- required for tester.pumpWidget(); this makes the plan's own grep-based acceptance criterion (expects 4 'test(' lines) structurally unsatisfiable while remaining correct, documented as a plan-authoring inconsistency rather than distorted to fit
- [Phase 28-03]: No wave-1 test correction needed -- all 20 RED tests and 50 pre-existing tests passed on first verification of both engine tasks, a direct consequence of 28-01/28-02's simulation-derived (not hand-derived) fixtures
- [Phase 28-03]: Captured 28-GREEN-final.txt with flutter test --concurrency=1 rather than default concurrency -- default concurrency's expanded reporter drops/duplicates per-test-name lines at scale (schedule_generator_test.dart never appeared by name despite passing), making the required by-name RED-to-GREEN cross-check unverifiable without it
- [Phase 29-01]: Corrected kCompactLiveMinHeight's cited three-strikes history from an unverifiable 60→84→88 to the git-verified 88.0 (UNMEASURED PLACEHOLDER) → 84.0 (first measurement) → 88.0 (re-measured after UAT) in kSubCompactBreakMinHeight's new doc comment
- [Phase 29-01]: _SubCompactRow's two Dividers written as separate inline literals (not a shared variable) so both the plan's height:1/thickness:1 grep criteria and 29-UI-SPEC.md's widget tree are matched exactly
- [Phase 29-02]: Task 1's kFullTierMinHeight-in-diff acceptance criterion needed correction, not the code — default git diff context pulls the unchanged work-branch line into the same hunk as the edit; git diff -U0 confirms the work branch is byte-identical
- [Phase 29-03]: kSubCompactBreakMinHeight measured in a real browser and set to 32.0 (22px raw ink extent + 8.0px explicit margin, rounded up to nearest 4dp), replacing the 24.0 estimate; kept separate from kNowLineHeight (28.0, 4dp apart) as an explicit coincidental-proximity decision

### Engine Constraints (carry-forward for Phase 21)

- Rule-based only — no LLM
- Hive migrations are additive-only (new fields with defaults, never remove/rename)
- Long-break cadence is currently a single constant: `final int longBreakEvery = isLowMood ? 3 : 4;` (`lib/services/schedule_generator.dart:220`) — BREAK-01 replaces this with a `_moodBreakCadence` lookup keyed on `moodIndex`; mapping locked during Phase 21 planning at `{1:2, 2:3, 3:4, 4:4, 5:5}`
- **CORRECTED 2026-08-07:** the earlier note that "three existing tests (~lines 492–543) assert the every-4 cadence and must change" is **stale and wrong**. 21-RESEARCH.md verified empirically (patched the constant, ran the suite) that all 54 tests in `test/services/schedule_generator_test.dart` pass unchanged under the new mapping. There is currently **zero** test coverage that discriminates cadence behavior — so the new tests are the substance of Phase 21, not a formality. Lines 492–543 today are the WR-01 test (mood=3), which is cadence-insensitive.
- The "behind" string lives at `lib/services/schedule_generator.dart:190`; its sibling branch already reads "On track this week" — use that framing as the model
- Schedule generator lives in `lib/services/schedule_generator.dart` — deterministic, covered by unit tests

### UI Constraints (carry-forward for Phase 23)

**REWRITTEN 2026-08-07 after Phase 22 landed.** The previous notes pointed at `home_screen.dart` and
`schedule_screen.dart`, both of which are now **deleted**. Every path below is verified against the
post-Phase-22 tree — do not chase the old ones.

- `resolveNowState` now lives at **`lib/screens/today/now_state.dart:97`** (relocated verbatim from
  `home_screen.dart`; algorithm unchanged). It still filters to **work chunks only** — this remains
  LIVE-01's extension point, and is exactly why a running break is currently invisible to "now".

- It is the **single** now-detector in the codebase. Phase 22 deleted `_buildActiveChunkItems` (the old
  first-unresolved-chunk scan) with `schedule_screen.dart`, and a code review caught and fixed a third
  one (the AppBar "Start focus" button, commit `8bb253a`). `grep -rn "resolveNowState" lib/` shows one
  definition and one call site. **Phase 23 must extend this one function, not add a parallel path** —
  reintroducing a second detector is the specific regression this milestone spent effort eliminating.

- `lib/screens/today/timeline.dart` holds the pure `buildTimeline` + `TimelineRow` sealed hierarchy.
  `isLive` is derived **only** from the injected `NowState`, never re-scanned. LIVE-01's "a running
  break reads as a break" almost certainly lands here plus `now_state.dart`, not in the widget layer.

- Now-tick is a 1-minute `Timer.periodic` inside `lib/screens/today/today_screen.dart` — **LIVE-02's
  granularity (per-minute vs per-second) is still an open design decision**, deliberately left for
  Phase 23 to decide and justify rather than inherit silently.

- `today_screen.dart` is ~900 lines and uses an injectable clock (`_nowFn`) throughout — Phase 23 should
  use that seam for any countdown, not `DateTime.now()` directly. A code review already corrected one
  drift from this discipline (`1035339`).

- Routing settled: shell has **three** destinations (Today/Goals/Settings); `/today` is canonical;
  a bare `/schedule` **exact-match** redirects to `/today` (a `startsWith` would break
  `/schedule/checkin`); `/schedule` also builds `TodayScreen` as a defensive fallback. Notification taps
  (`lib/main.dart:86`) still call `router.go('/schedule')` and resolve correctly through that redirect.

- **RESOLVED Phase 22-02:** Phase 21 UI review flagged that mood-1 days insert a long break every 2 chunks, rendering a 48px short-break pill immediately followed by an elevated long-break `Card` roughly every 4th row. `chunk_card.dart`'s `_buildShortBreak`/`_buildLongBreak` are now collapsed into a single `_buildBreak` on one dashed `CustomPainter` treatment (D-06), so both break variants read the same visual weight when adjacent. Confirmed live in the running app: at a cadence boundary the long break *replaces* the short break rather than stacking after it, so the feared adjacency never occurs. No collapse/accordion affordance was added, per the explicit prohibition.

### Blockers / Concerns

None. **Phase 31's gate is cleared.** Its ROADMAP entry required Phase 29's UAT verdict first —
Phase 31 attaches a swipe gesture to the 20dp sub-compact hairline, so a verdict that changed that
layout would have changed the gesture target. The verdict came back PASS on 2026-08-25 (reads as a
break, label legible, day looks right), so the sub-compact layout is settled and Phase 31 can attach
to it as-is. Ready for `/gsd-plan-phase 31`.

## Deferred Verification

| Phase | State | Resume |
|-------|-------|--------|
| 31 | superseded — gaps will not be closed in 31 | (none — work routed to Phase 32) |

**Superseded 2026-08-27.** This row previously read `verification_gaps` / `/gsd-plan-phase 31
--gaps`. That resume command is now wrong and must not be run: the round-two UAT verdict replaced
the swipe approach rather than repairing it, and Phase 32 (`Breaks You Can Tap`) carries the work.
The gap analysis below is retained because Phase 32 inherits its lesson, not because Phase 31 will
act on it.

**Phase 31's UAT was judged on 2026-08-26 and Item 1 FAILED.** The owner, on a real phone after a
real ⟳ Re-check-in: *"hard to do this with a thumb."* Clarified on follow-up as an **acquisition**
failure — hard to *grab* the 20dp row, not hard to complete the swipe once grabbed. Items 2
(legibility at `Opacity(0.5)`) and 3 (nothing else moves) both PASS.

**The root cause is a real lesson, not a tuning miss.** `kBreakHitSlop = 16.0` yields a 52dp
acquisition band, clearing Material's 48dp and iOS's 44pt. Three widget tests prove a synthetic drag
anywhere in that band resolves to the break. All true; none of it sufficient. **Those platform
minimums assume a target the user can SEE.** SKIPBREAK-02 forbids painting into the slop, so the
band is invisible by construction and the thumb must land within ±16dp of a 20dp hairline by feel
alone. Meeting a platform minimum with an invisible target is a weaker guarantee than meeting it
with a visible one — and the gap between those two guarantees is exactly what a thumb found and
625 tests could not.

**The fix has a bounded ceiling, so it needs planning rather than a constant bump.** The Layer 1b
pass makes the break *win* the contested band, so every dp added to the slop is taken from the
neighbouring work chunk's own target. A 25-minute work chunk is 100dp; with a break on both sides it
loses 2× the slop. At 16 it keeps 68dp, at 24 → 52dp, at 32 → 36dp, which pushes the *work* chunk
under the 48dp minimum and just moves the defect next door. Safe ceiling ≈ 24–26dp. A slop increase
alone may therefore be insufficient, and making the target *findable* rather than merely larger runs
into SKIPBREAK-02. That tension is the actual design question. Full analysis in `31-UAT.md` Gaps.

**Do NOT lower `dismissThresholds` on this evidence** — the owner reported acquisition difficulty,
not completion difficulty. The ROADMAP named that lever; the UI-SPEC declined to pull it without
evidence; that evidence still does not exist.

**Still unruled:** whether a *currently running* break should be skippable (PD-31-06). Surfaced to
the owner in this UAT; he judged the three numbered items and did not answer it. Recorded as unruled
rather than read as consent either way.

*Third time in this project a green suite was contradicted by a thumb — Phase 27, Phase 29, now
Phase 31. The blocking checkpoint earned its cost again.*

The build is **live now** at `http://danserver:8143/` (debug, `--pwa-strategy=none`), served by
`tools/serve-uat.py`, and byte-verified before anyone was asked to look: built and served
`main.dart.js` sha256 both `6cebe2e5…`, and the served bundle greps non-zero for this phase's
`", skipped"` string and its `needsSlop` predicate. `31-UAT.md` has three items plus two deliberate
exclusions to rule on, and its Step 0 is a **mandatory ⟳ Re-check-in** (trap #4).

*Note for whoever runs the next UAT:* port 8143 was still held by a server started **2026-08-24**,
left over from Phase 29/30. It was killed and replaced before the sha256 comparison was taken. Had
it not been, the verification would have described a server the owner was not actually being shown —
trap #3 with an extra day of staleness on top. **Check `lsof -i :<port>` before trusting a serve.**

## Resolved Verification

| Phase | State | Resolved |
|-------|-------|----------|
| 29 | ✅ passed | Human UAT 2026-08-25 — all 3 items PASS (`29-UAT.md`) |
| 30 | ✅ passed | Human UAT 2026-08-25 — all items PASS (`30-UAT.md`) |

Both were `verification_deferred_human` for one working day. Phase 29's was deferred deliberately
rather than skipped: item 1 asks whether a 5-minute break reads *as a break*, and on a day built
around a committed `Work` block there were no breaks to look at until Phase 30 landed. Both were
then judged in a single sitting against the same served build on port 8143.

**How the UAT was closed, for the next one's benefit.** Served bytes were sha256-checked against
built bytes before the owner was asked to look at anything (`84ef9419…`, identical), and the served
`main.dart.js` was grepped for `buildCommitmentChunks` to prove the change was actually in the
bundle. No re-check-in was needed on the day because the calendar had rolled over, so the owner's
check-in necessarily ran through the fixed engine — but trap #4 stays in `CLAUDE.md` and in every
generator-output UAT's own Step 0, because a same-day UAT will need it.

## Deferred Items

Items acknowledged and deferred at milestone close on 2026-06-15 (v1.4) — carried forward, not yet routed to v1.5 (out of this milestone's scope per REQUIREMENTS.md Future Requirements / Out of Scope):

| Category | Item | Status |
|----------|------|--------|
| todo | Onboarding screens full-bleed at desktop width | Candidate for future polish phase — not in v1.5 scope |
| todo | Onboarding commitment-step day chips ambiguous (M/T/W/T/F/S/S) | Candidate for future polish phase — not in v1.5 scope |
| tech-debt | FILL-02 high-priority monopoly edge | documented-accepted (3+ goals at weight ≥0.75 can starve lower-priority time-targets) |
| tech-debt | Nyquist VALIDATION frontmatter drafts (15/16/17) | tests green; `nyquist_compliant: false` metadata only |
| tech-debt | chunk_card.dart hardcoded `Colors.green.shade600` / `Colors.grey.shade400` | **RESOLVED Phase 22** — `chunk_card.dart` closed in 22-02 (`colorScheme.primary`/`outlineVariant`). The 22 UI review then caught that its wrapper `swipeable_chunk_card.dart` still held 4 raw literals for the swipe-reveal backgrounds; fixed post-review to `colorScheme.primary`/`onPrimary` (complete) and `error`/`onError` (skip), matching ChunkCard's own button semantics. Zero raw `Colors.*` now remain in either file. Remaining `Colors.white` uses in `checkin_screen.dart`/`acknowledgment_screen.dart` are deliberate contrast-on-mood-background computation, not debt. |
| product | Start/stop focus timer per chunk (clock-in tracking) | deferred — see REQUIREMENTS.md Future Requirements |
| product | Drag-to-reorder restoratives | deferred — see REQUIREMENTS.md Future Requirements |
| product | Restoratives in onboarding (screen 4 invite) | deferred — see REQUIREMENTS.md Future Requirements |

Carried from earlier milestones (v1.0–v1.2), still open:

| Category | Item | Status |
|----------|------|--------|
| uat | Phase 12 12-UAT.md | testing — 5 pending visual scenarios |
| uat | Phase 13 13-UAT.md | testing — 8 pending visual scenarios |
| uat | Phase 14 14-UAT.md | testing — 4 pending visual scenarios |
| uat | Phases 04/05/06/09/10/11 UAT | carried over from v1.0/v1.1 |
| verification | Phases 01/06/07/09/10/11/12/13/14 | human visual sign-off pending |

## Quick Tasks Completed

| Date | Slug | Outcome |
|------|------|---------|
| 2026-06-14 | fix-stale-hive-data-startup-crash | Resilient Hive box open — incompatible old-version data is reset instead of blanking the app at startup. `.planning/quick/20260614-fix-stale-hive-data-startup-crash/` |

## Session Continuity

**Resume file:** .planning/phases/32-breaks-you-can-tap/32-UAT.md

Last session: 2026-08-25
Stopped at: Phase 32 wave 3 halted at blocking human UAT — build served on 8143, pre-flight verified
Resume at: open `http://danserver:8143/` **on a phone or tablet** (not a desktop pointer — the whole
question is fingertip size). Tap **⟳ Re-check-in first** — mandatory, trap #4, Item 3 is meaningless
without it. Then walk `31-UAT.md`'s three items, rule on its two deliberate exclusions, record each
verdict in that file, and run `/gsd-verify-work 31`.

If the server is no longer up:
`flutter build web --debug --source-maps --pwa-strategy=none --no-pub` then
`python3 tools/serve-uat.py 8143 --dir build/web`. Check `lsof -i :8143` first — a stale server from
a previous phase was squatting that port this session.

## Performance Metrics

| Phase | Plan | Duration | Notes |
|-------|------|----------|-------|
| Phase 15-engine-honesty P01 | 6 | 3 tasks | 2 files |
| Phase 15-engine-honesty P02 | 230 | 1 tasks | 2 files |
| Phase 16-priority-model-reconciliation P01 | 25 | 2 tasks | 2 files |
| Phase 17-time-anchored-home P01 | 7 | 3 tasks | 3 files |
| Phase 18-responsive-modals-and-desktop-polish P02 | 3 | 2 tasks | 3 files |
| Phase 18-responsive-modals-and-desktop-polish P03 | 3min | 1 tasks | 2 files |
| Phase 18-responsive-modals-and-desktop-polish P04 | 20min | 2 tasks | 3 files |
| Phase 18-responsive-modals-and-desktop-polish P05 | 25 | 2 tasks | 4 files |
| Phase 19-energy-valence P01 | 6 | 2 tasks | 5 files |
| Phase 19-energy-valence P02 | 5min | 2 tasks | 6 files |
| Phase 19-energy-valence P04 | 4 | 2 tasks | 4 files |
| Phase 19-energy-valence P05 | 15min | 2 tasks | 2 files |
| Phase 20-valence-aware-engine P01 | 2min | 2 tasks | 1 files |
| Phase 20-valence-aware-engine P02 | 3min | 3 tasks | 1 files |
| Phase 21 P01 | 5min | 2 tasks | 2 files |
| Phase 21-mood-scaled-breaks-honest-rationale P02 | 4min | 2 tasks | 2 files |
| Phase 22-unified-today-screen P01 | 7min | 2 tasks | 6 files |
| Phase 22 P02 | 8min | 3 tasks | 8 files |
| Phase 22-unified-today-screen P03 | 16min | 3 tasks | 5 files |
| Phase 22-unified-today-screen P04 | 9min | 3 tasks | 20 files |
| Phase 23 P01 | 10min | 3 tasks | 5 files |
| Phase 23-live-activity-tracking P02 | 15min | 2 tasks | 2 files |
| Phase 23-live-activity-tracking P03 | 25min | 2 tasks | 3 files |
| Phase 23-live-activity-tracking P05 | 32min | 3 tasks | 3 files |
| Phase 23 P06 | ~20min | 2 tasks | 2 files |
| Phase 23-live-activity-tracking P08 | ~10min | 2 tasks | 6 files |
| Phase 23 P07 | 35min | 3 tasks | 8 files |
| Phase 24 P01 | 30min | 3 tasks | 7 files |
| Phase 24-where-am-i P02 | 12min | 3 tasks | 3 files |
| Phase 24-where-am-i P03 | ~15min | 2 tasks | 1 files |
| Phase 24 P04 | 35min | 2 tasks | 2 files |
| Phase 25-time-travel P01 | ~45min | 6 tasks | 8 files |
| Phase 26-the-day-has-a-shape P01 | 41min | 3 tasks | 8 files |
| Phase 26-the-day-has-a-shape P02 | 45min | 2 tasks | 7 files |
| Phase 26-the-day-has-a-shape P3 | ~35min | 2 tasks | 7 files |
| Phase 26-the-day-has-a-shape P04 | 45min | 2 tasks | 2 files |
| Phase 26-the-day-has-a-shape P05 | ~30min | 2 tasks | 2 files |
| Phase 26-the-day-has-a-shape P07 | ~20min | 3 tasks | 4 files |
| Phase 26-the-day-has-a-shape P08 | ~45min | 3 tasks | 3 files |
| Phase 26-the-day-has-a-shape P09 | ~25min | 3 tasks | 4 files |
| Phase 26 P10 | 90min | 4 tasks | 7 files |
| Phase 27-true-grid P01 | ~20min | 2 tasks | 3 files |
| Phase 27 P02 | ~45min | 3 tasks | 3 files |
| Phase 27-true-grid P03 | ~35min | 2 tasks | 2 files |
| Phase 27-true-grid P04 | ~55min (Tasks 1-2; Task 3 pending) | 2/3 tasks | 1 file modified, 7 created |
| Phase 28-the-day-is-a-lattice P01 | ~15min | 2 tasks | 2 files |
| Phase 28-the-day-is-a-lattice P02 | ~8min | 2 tasks | 2 files |
| Phase 28-the-day-is-a-lattice PP03 | ~8min | 3 tasks | 2 files |
| Phase 29-breaks-you-can-see P01 | ~20min | 3 tasks | 5 files |
| Phase 29-breaks-you-can-see P02 | ~15min | 2 tasks | 3 files |
| Phase 29-breaks-you-can-see P03 | ~35min | 2 tasks | 3 files |
