# Phase 32 — Code Review (Breaks You Can Tap)

**Reviewed:** 2026-08-28, against `master` @ `402e1e7`.
**Scope:** the phase's production and test diff, `4aa3598..HEAD` — 10 files, +1308 / −1910.
**Suite at review time:** `flutter analyze` clean, `flutter test` **621/621 green** (re-run on this
tree, not quoted from a summary).

**Why this file exists.** Phases 29 and 31 each got a code review before their UAT; Phase 32's plan
list has no review wave, so it reached its human gate without one. This closes that gap. It does
**not** substitute for the human UAT — every item in `32-UAT.md` is still open and still requires a
thumb.

**Verdict: no blockers.** One low-severity finding (below), plus one observation routed into the
UAT rather than into code.

---

## What was checked, and what the check actually proves

- **The retirement sweep is real, not nominal.** `kBreakHitSlop`, `kMinBreakDragTarget`,
  `kSubCompactBreakMinHeight`, `kSubCompactGripSize`, `ChunkCardDensity.subCompact`, `_SubCompactRow`
  and the break-side `Dismissible` have **no live references** left in `lib/` or `test/` — the only
  surviving mentions are retirement doc-comments and historical test commentary. The one
  `Icons.drag_indicator` still in the tree is `goals_screen.dart`'s goal-reorder handle, an unrelated
  feature where the six-dot grip means the correct verb. The phase's own "delete, don't leave
  uncalled" charter was honoured.

- **The suite was reconciled by classification, not by retyping numbers** — the carried-forward
  defect class this project names explicitly. 35 symbolic `kPixelsPerMinute` references remain (they
  follow the constant); the removed tests are the swipe/grip/sub-compact ones whose *mechanism* was
  deleted, not assertions that were softened. Spot-checked the two behavioural invariants most at
  risk of being lost in that churn — **both were re-homed, not dropped**: "a break never reaches
  `markComplete`" now lives at `today_screen_now_state_test.dart:1277` and
  `today_row_widgets_test.dart:1236`, and the skipped-break `lineThrough` treatment retains 10+
  assertions across three files including both positive and `isNot` cases.

- **TAPBREAK-02's grid-honesty assertion is symbolic** (`5 * kPixelsPerMinute`,
  `today_screen_test.dart:2870`) and would go red against a minimum-height floor. Noted honestly:
  that assertion measures a `ClipRect` that `_confineContent` makes `visualHeight` tall **by
  construction** — the same shape Phase 31 correctly called vacuous *for a fit question*. It is
  **not** vacuous for this question (it proves the slot computation still equals duration × scale),
  and the phase did not lean on it for fit — `32-UAT.md`'s real-browser pixel measurement (30px card,
  9/11px clearance, zero clipping) is what answers fit. **The division of labour is right.**

- **`markSkipped` is called fire-and-forget** from `BreakSkipButton` — matching `chunk_card.dart:691`
  and `live_row_card.dart:231` exactly. The doc comment's claim that the notifier owns the
  revert-and-rethrow contract checks out against `schedule_notifier.dart:687`. **Consistent with the
  two existing call sites; not a new inconsistency.**

- **`FittedBox(scaleDown)` under accessibility text scale — checked, not a regression.** At large
  text scales the label scales up first and the whole column then scales down to fit 30dp, netting
  *larger* rendered text than default, not smaller. At default scale it renders at ~88% of natural.
  No finding.

- **Both `Semantics` deviations** (`container: true` + `ExcludeSemantics`, and the `FittedBox`) are
  recorded in-code as Rule-1 deviations with their reasoning, rather than silently applied.

---

## Finding 1 — LOW — **FIXED 2026-08-31** (`live_row_card.dart`, `break_skip_button.dart`)

Held deliberately while the UAT gate was open, because the fix touches a file under judgement and
changing served bytes mid-UAT invalidates the byte-verification the owner is judging against.
Applied once round two closed 4/4. The unreachable `BreakSkippedIndicator` branch is **deleted**,
not left uncalled — the same charter D-32-02 applied to Phase 31's slop machinery, applied to code
this phase introduced itself. The class doc that claimed the 64dp slot survives a skip is
**corrected** to say what is actually true: that holds in `chunk_card.dart` (both tiers keep the
`SizedBox` and swap only the child) and never held in `live_row_card.dart`. 621/621 green,
`flutter analyze` clean after the change. Original finding preserved below.

### Original finding — a dead branch, and a doc comment that is false at one of its two call sites

**Where:** `lib/screens/today/widgets/live_row_card.dart:395-401`, and the class doc at
`lib/widgets/break_skip_button.dart:117-122`.

`_buildSingleLine` gates the entire rail `SizedBox` on `showActions`, then branches on `isSkipped`
inside it:

```dart
if (showActions)
  SizedBox(
    width: kBreakSkipButtonWidth,
    child: isSkipped ? const BreakSkippedIndicator() : BreakSkipButton(...),
  ),
```

The only call site passes `showActions: isBreak ? !chunk.isSkipped : true`
(`today_screen.dart:1016`). So for a **break**, `isSkipped == true` implies `showActions == false`,
which drops the `SizedBox` entirely — **the `BreakSkippedIndicator` branch is unreachable.** It is
not reachable via a work chunk either: `_buildSingleLine` only runs below `kCompactLiveMinHeight`
(88dp), i.e. under 14.67 minutes at 6.0 px/min, and every work chunk the generator emits is exactly
25 minutes (`buildCommitmentChunks`' tail-stretch only ever *lengthens* the last chunk) — the same
reachability argument Phase 31 made for `kBreakHitSlop`'s clamp, re-checked here rather than assumed.

**Failure scenario, stated honestly: there isn't a user-visible one.** `resolveNowState`'s
advance-past-resolved loop (`now_state.dart:176`) delists a chunk the moment it is skipped, so a
live-and-skipped break never renders at all. The tests already know this and route the coverage
through the non-live arm on purpose — `today_screen_now_state_test.dart:1443` ("Case C") says so in
its own name. **Nothing is broken.**

**Why it is still worth recording, rather than waved off:**

1. It is exactly the "uncalled machinery left in the tree" that D-32-02 and this phase's own charter
   forbid — the phase deleted Phase 31's dead code and then added a small piece of its own.
2. `BreakSkippedIndicator`'s class doc asserts *"the rail's own 64dp slot keeps its exact width and
   only its content swaps to this."* That is **true in `chunk_card.dart`** (both tiers preserve the
   `SizedBox(width: kBreakSkipButtonWidth)` — lines 223 and 314) and **false in
   `live_row_card.dart`**, where the slot vanishes with `showActions`. A future reader who trusts the
   doc and makes the live-skipped state reachable inherits a silent horizontal reflow.

**Remedy (deliberately not applied):** either drop the unreachable ternary and render
`BreakSkipButton` directly, or move the `showActions` gate inside the `SizedBox` so the slot is
preserved the way the doc claims. **Not fixed in this pass** — it touches a file under an open human
UAT gate, and changing served bytes mid-UAT would invalidate `32-UAT.md`'s byte-verification
pre-flight (sha `3ec8946…af943`, verified live on port 8143). Route it after the UAT verdict, folded
into whatever gap-closure the verdict produces, or as a standalone cleanup if everything passes.

---

## Observation — routed to the UAT, not to code

**A break's Skip control now has two different appearances depending on whether it is running**, and
Item 4(a) is the first place Dan will meet the second one:

| Break state | Tier | Control |
|---|---|---|
| Not running, 5-min (30dp) or 30-min (180dp) | `chunk_card.dart` | 64dp pink `errorContainer` rail, `skip_next_outlined` **over the word "Skip"** |
| Running, 30-min (180dp ≥ 88dp) | `LiveRowCard._buildCompact` | icon-only `IconButton`, `skip_next_outlined`, **word only in the tooltip** |
| Running, 5-min (30dp < 88dp) | `LiveRowCard._buildSingleLine` | the same 64dp labelled rail |

**This is ruled, not accidental** — the ROADMAP's own "What this phase must NOT do" says *"Do not
remove `LiveRowCard`'s compact-tier Skip button (D-31-07). It survives."* So the icon-only control on
a running 30-minute break is the preserved D-31-07 button behaving exactly as ruled.

It is still worth Dan seeing it *before* he judges Item 4(a), because that item asks "is there a Skip
action" and he will have spent Items 1–3 looking at a labelled pink rail. Added to `32-UAT.md` as a
third orchestrator observation — **stated as a fact about the surface, not as a verdict**, in keeping
with that document's own rule that the orchestrator does not judge items it is not allowed to judge.

---

## Summary

```
blockers: 0
high: 0
medium: 0
low: 1
observations: 1 (routed to 32-UAT.md)
```

The phase's code is in good shape and its own stated disciplines were followed — the constant
migration was re-derived rather than retyped, the dead mechanism was deleted rather than orphaned,
and both in-code deviations were documented instead of hidden. **The one thing standing between
Phase 32 and done is still the human UAT**, which no amount of review can substitute for: the last
three phases each went green and were then contradicted by a thumb.
