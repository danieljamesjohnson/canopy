---
phase: 23-live-activity-tracking
source: 23-UAT.md Gaps section (Dan, 23-04 sign-off gate, 2026-08-08)
type: diagnosis-only — no code changed
---

# Phase 23 UAT Gap Analysis

Investigation only, per instructions — nothing in `lib/` or `test/` was modified. A scratch widget
test was written and run to settle G-03, then deleted (`test/screens/_scratch_g03_test.dart` no
longer exists).

Ranked by priority: **G-03 > G-05 > G-04 > G-02 > G-07 > G-01 > G-06.** G-03 is the only outright
defect with user-visible data loss potential (a task silently not tracked live). G-05 is a real
behaviour request but collides head-on with a named, deliberate invariant test. G-04 is a genuine
small bug. G-02/G-07/G-01/G-06 are copy/visual polish with low risk.

---

## G-03 — Live row didn't appear at 9:15 without a manual refresh (BUG, highest priority)

**Reported:** Opened the app at 9:13 with a chunk starting at 9:15. The live row never appeared;
Dan had to refresh the browser to see it.

**Files:** `lib/screens/today/today_screen.dart:68-166` (timers + lifecycle), `lib/screens/today/now_state.dart:116-208` (`resolveNowState`).

### What I proved, concretely

I wrote `test/screens/_scratch_g03_test.dart`: a schedule with one work chunk starting at 9:15,
an injectable clock starting at 9:13, pumped `TodayScreen` once, then advanced the clock and called
`tester.pump(Duration(minutes: 1))` **twice** (no second `pumpWidget`, i.e. no remount) to fire the
real `Timer.periodic(Duration(minutes: 1))` in `_startNowTimer` (today_screen.dart:126-131) exactly
as it fires in production.

Result: **the test passed.** At 9:13 the screen showed "Nothing until 9:15 AM" and no `LiveRowCard`.
After the first tick (9:14) it was still PreStart. After the second tick (9:15) `LiveRowCard`
appeared and the PreStart text was gone — the minute timer alone, with no remount, carried
PreStart → Active exactly as designed.

This is not a coincidence specific to my test: the identical scenario is already covered by an
existing, currently-green test — `test/screens/today_screen_now_state_test.dart:843-855`
("Timer tick at 8:01 must transition from pre-start to active (NOW-01)") — plus a paired
no-double-timer regression at lines 880-910 (WR-03) that cycles `paused`→`resumed` twice and asserts
`_startNowTimer`'s cancel-then-restart stays idempotent. I also confirmed via `git show 48af6bf`
that `nowDt` is sampled fresh once per `build()` call (not cached across ticks in a stale closure) —
that WR-01 fix rules out the "stale closure" explanation the task asked me to check.

**Verdict on the task's "prime suspect":** falsified. `_syncFastTimer` (today_screen.dart:139-148)
never touches `_nowTimer`; it only starts/stops the separate 1-second `_fastTimer`, and it is a
no-op in `PreStart` because `_liveSecondsRemaining` returns `null` when `nowState is! Active`
(today_screen.dart:636). The minute timer's `setState` callback (line 128-130) is unconditional —
no state check, no early return — so it fires and rebuilds in every `NowState`, including
`PreStart`. Categories (a) timer never fires, (b) timer fires but no rebuild, and (c) timer
cancelled/no-op in PreStart are all **ruled out** by direct proof.

### What's left: (d) lifecycle-related — the one mechanism that *can* produce "stuck until refresh"

`didChangeAppLifecycleState` (today_screen.dart:150-166) is asymmetric:

- `paused` → cancels **both** `_nowTimer` and `_fastTimer` unconditionally (lines 161-165).
- `resumed` → the *only* place either timer gets restarted (line 153, via `_startNowTimer()`).

There is no third mechanism anywhere in the file that revives a dead `_nowTimer` — no
staleness check in `build()`, no independent visibility listener. So the code's correctness for
"the live row updates on its own" is entirely conditional on the browser reliably delivering a
`resumed` callback after any `paused`. If a `paused`-equivalent lifecycle event fires (Flutter Web
maps this from document visibility/focus changes) and the matching `resumed` is missed, delayed, or
never delivered — e.g. a brief window/tab blur during the debug build's own ~20s single-bundle
parse-and-first-paint window (documented in this project's `CLAUDE.md`), a devtools panel stealing
focus, or any of the known rough edges in how Flutter Web derives `AppLifecycleState` from browser
visibility events for quick focus changes — both timers stay dead **permanently**, and a full page
reload (new `initState`) is the only way to revive them. That matches Dan's exact fix ("I had to
refresh the browser") precisely, and it is consistent with 23-UAT.md's own framing that this class
of thing needs a real GPU-backed browser to observe (`flutter_test`'s
`tester.binding.handleAppLifecycleStateChanged` always delivers cleanly — it cannot simulate a
*missed* event, so this cannot be proven or disproven with a widget test; only the mechanism that
would explain it can be shown).

I cannot cite a specific dropped event from this session's logs (none were captured), so I'm not
claiming 100% certainty — but it is the only failure mode in the code capable of producing a
silent, permanent, refresh-only-fixes-it symptom, and everything else in the timer/render path is
proven correct above.

### Recommended fix

1. **Primary:** stop cancelling `_nowTimer` on `paused`. It fires once a minute; the code's own doc
   comment (today_screen.dart:63-67) already argues this costs effectively nothing. Only
   `_fastTimer` (the 1-second ticker, the actual battery concern per its doc comment at lines 70-76)
   needs pause/resume gating. This removes the single point of failure for the path that matters
   (PreStart → Active) without touching the battery-sensitive fast path.
2. **Belt-and-suspenders (optional, medium effort):** add a redundant recovery path independent of
   `AppLifecycleState` — e.g. a `visibilitychange`/focus listener via `package:web`, or a staleness
   self-heal in `didChangeDependencies`/`build()` that restarts `_nowTimer` if `!_nowTimer.isActive`.
   Worth doing given `CLAUDE.md` already flags "web browsers throttle timers in background tabs" as
   a known risk class for this app.

**Blast radius:** `lib/screens/today/today_screen.dart` only. Existing tests to re-check: the WR-03
no-double-timer test (today_screen_now_state_test.dart:880-910) and the paused/resumed-doesn't-throw
assertions around lines 874-878 — neither pins "paused stops `_nowTimer`" as behavior, so removing
that cancel should not break them. Add a new test asserting the minute tick still fires while
"paused" (if item 1 is taken) to lock in the fix.

**Effort:** Low (item 1) to Medium (item 2, if pursued).

---

## G-05 — Completing a chunk early should land in "break," not a gap (BEHAVIOUR — conflicts with a named invariant)

**Reported:** "Once I've completed a task I should be in 'break'." Today, completing a work chunk
before the following break's scheduled window has opened returns `GapBeforeNext`, not `Active`.

**File:** `lib/screens/today/now_state.dart:116-208`, specifically the `while (active.isCompleted ||
active.isSkipped)` advance loop (lines 175-193) and its guard at line 180: `if
(candidate.displayStartMinutes! > currentMinutes)`.

### Current behavior, exactly

When the current chunk resolves (completed/skipped) and the next scheduled chunk's window hasn't
opened yet, `resolveNowState` returns `GapBeforeNext(next)` — never `Active(next)` — regardless of
whether `next` is a break. The doc comment right above the loop (lines 169-174) states the rule in
plain terms: **"only promote a chunk to active/overdue if its window has already opened... Never
show a future chunk as 'Now'."**

This exact scenario — a work chunk completed early, before a break's window opens — is not just
covered incidentally, it has its own **named regression test**:
`test/screens/today_screen_now_state_test.dart:470-487`, titled *"gap-before-next can target a
break (KEY INVARIANT: an unopened break window is never promoted to Active)"*. It asserts
`resolveNowState` returns `GapBeforeNext` with `next.id == 'b1'` (the break), not `Active`, for the
identical case Dan hit. This is a deliberate, hand-named protection, not an oversight.

### What this invariant is protecting against

Traced to Phase 17 (`17-UI-SPEC.md` "State Boundary Handling", referenced in now_state.dart:53) and
carried forward through Phase 22/23's `KEY INVARIANT` comment (now_state.dart:102-104): "clock-window
is found FIRST by time, THEN resolution is checked." The point is to prevent re-introducing a
"first-unresolved-chunk" bug class where the screen shows something as "RIGHT NOW" that the clock
says hasn't started. Concretely, `_liveSecondsRemaining` (today_screen.dart:635-645) computes
remaining time from the chunk's own `displayStartMinutes`/`durationMinutes` — it does **not** check
whether `now` is actually inside that window. If `resolveNowState` were changed to promote an
unopened break to `Active` the moment the prior chunk resolves, `_liveSecondsRemaining` would happily
compute `end - now` against the break's *originally scheduled* end time even though `now` is earlier
than the break's scheduled start — clamped to full duration, so the countdown would silently show
"5 min left · until 9:45" while the wall clock is really, say, 9:35, ten minutes before that break
was ever meant to start. That's a second, independent landmine on top of reopening the very bug this
invariant exists to prevent.

### Conflict with already-verified behavior

This is the same invariant LIVE-01/LIVE-03 were UAT-verified against (23-UAT.md Notes table: "LIVE-03
... PreStart / DayComplete" verified unchanged, and the gap banner's Decision P-1 explicitly kept
`GapBeforeNext` as-is). Implementing G-05 literally means reopening a decision that was just
re-affirmed at this same sign-off gate.

### What would actually satisfy the request without breaking the invariant

- **Option A (cheap, safe — recommended):** leave `resolveNowState`'s classification alone (keep
  `GapBeforeNext`), but change the *presentation* when `next` is specifically a break — style/copy
  the edge-state line (`_buildEdgeStateLine`'s `GapBeforeNext` case, today_screen.dart:391-423) to
  read as "you're on a break" rather than neutral "Up next" copy, when the gap is honestly a
  which-is-true statement (the break hasn't clock-started but the user is behaviourally resting
  now). This is copy/presentation only — no state-machine change, no countdown-math risk.
- **Option B (real fix, large — a new phase, not a UAT patch):** make completing early actually
  *shift* the break to start now — i.e. a scheduling-semantics change in `ScheduleNotifier.markComplete`
  that re-anchors the following break's (and possibly the rest of the day's) `displayStartMinutes`.
  This has real knock-on effects on every subsequent chunk's clock position and deserves its own
  design pass, not a quick fix under this gap-analysis.

**Blast radius (Option A):** `today_screen.dart`'s `_buildEdgeStateLine` only; no `now_state.dart`
change, so the KEY INVARIANT test at line 470-487 keeps passing untouched.

**Effort:** Option A — Low. Option B — High (new phase).

---

## G-04 — Time gutter labels clip at the viewport edge (BUG)

**Reported:** Gutter times like "4:10p"/"5:35p" clip at the edge.

**Files:** `lib/screens/today/widgets/timeline_row_tile.dart:44-56` (the gutter widget),
`lib/screens/today/today_screen.dart:940-957` (where the day's row list is laid out).

### Root cause

`TimelineRowTile` renders the compact time label in a `SizedBox(width: kGutterWidth /* 46.0 */)` as
the first child of a `Row`, with **zero leading inset** — no `Padding`, no margin. That row is placed
directly into the `Column` inside `SingleChildScrollView` at today_screen.dart:940-957, which itself
has **no horizontal padding** of its own. Compare that to every other element on the screen:
`_buildHeader` uses `EdgeInsets.fromLTRB(16, 8, 16, 8)` (today_screen.dart:280),
`_buildEdgeStateLine` uses `EdgeInsets.fromLTRB(16, 4, 16, 12)` (lines 348, 397, 425), and even
`FreeTimeRow` insets itself by 16 (`free_time_row.dart:37`). The timeline rows are the one place on
the screen with no left inset at all, so the gutter text sits flush against x=0 — the physical
device/viewport edge on phone widths (< 720dp, where the screen's `ConstrainedBox(maxWidth: 720)`
doesn't kick in), and flush against the edge of the centred 720dp content column on desktop. That
"jammed to the edge with zero breathing room, misaligned 16dp left of the header directly above it"
is what reads as "clipping."

Secondary, lower-confidence risk worth checking in a real browser: `kGutterWidth` is 46.0 and the
widest labels `formatMinutesCompact` produces are 6 characters ("12:45p", "10:45p" — see the doc
comment's own examples at `time_format.dart:39-40`). The gutter text uses `tabularFigures()` plus a
monospace `fontFamilyFallback` (timeline_row_tile.dart:38-42), but that fallback only activates for
glyphs missing from the primary Material theme font — digits/colon/`p` are always present in the
primary font, so tabular figures ride on the theme's proportional font, not a wider monospace one.
This is probably not the dominant cause (the reported strings "4:10p"/"5:35p" are 5 characters, not
the 6-character worst case), but it's cheap to verify once the padding fix lands — if "12:45p" still
wraps/clips at 46dp with the app's actual `bodySmall` size, bump `kGutterWidth` a few dp.

### Recommended fix

Wrap the timeline rows' `Column` (today_screen.dart, inside the `SingleChildScrollView` at line
940-957) — or more precisely the whole scroll region — in the same `16` horizontal inset every other
element on this screen already uses, so the gutter column lines up with the header/edge-state text
above it instead of touching the raw edge. Re-verify the 46dp gutter width against the widest label
("12:45p"/"10:45p") once that's done, at both 390dp phone and desktop widths, per the task's ask.

**Blast radius:** `today_screen.dart` layout only (one `Padding` wrapper); no logic change. Every
existing timeline-row test that checks for text/widget presence (not literal pixel offsets) should
be unaffected; any test asserting exact `Scrollable` pixel offsets (the centre-on-open tests at
today_screen_test.dart:494-543) may need re-checking since the scroll content's horizontal metrics
don't change but it's worth a spot-check.

**Effort:** Low.

---

## G-02 — A 25-min long break reads identically to a 5-min short break (DESIGN)

**Reported:** No visual weight difference between short and long breaks.

**File:** `lib/screens/schedule/widgets/chunk_card.dart:90-130` (`_buildBreak`).

### Current implementation

Phase 22-02 deliberately collapsed the old `_buildShortBreak`/`_buildLongBreak` pair into one
`_buildBreak` (confirmed in `.planning/phases/22-unified-today-screen/22-02-SUMMARY.md`), giving both
the exact same treatment: `Container(margin: symmetric(vertical:4, horizontal:16))` wrapping a
`CustomPaint(_DashedBorderPainter)` with `Padding(symmetric(horizontal:16, vertical:12))`, a `Row`
with the title (`bodyMedium`, `onSurfaceVariant`) on the left and `'${chunk.durationMinutes} min'`
(`bodySmall`) on the right. The **only** difference between a short and long break today is the
title string ("Short break" vs "Long break") and the numeral in the duration text — font size,
padding, border weight, and color are all identical. That 22-02 change was itself a deliberate fix
for a *different* Phase 21 problem (a short-break pill next to a long-break elevated Card reading as
mismatched), and its summary explicitly notes "No collapse/accordion affordance added, per the
explicit prohibition in the execution note" — confirming the constraint the task flagged still
applies today.

### Recommended fix

Scale visual weight by `chunk.durationMinutes` within the *same* dashed vocabulary — no new
interaction, no accordion, matching the explicit prohibition:

- Bump vertical padding for `longBreak` (e.g. `12` → `20-24`) so the card is visibly taller.
- Bump the title's text style up a step for `longBreak` (`bodyMedium` → `titleSmall`/`bodyLarge`,
  and/or `FontWeight.w500`) — short break stays as-is.
- Optionally add a small icon for `longBreak` only (e.g. `Icons.self_improvement` or similar) to add
  visual mass without adding a new gesture.
- Optionally widen the dash pitch or stroke (`_DashedBorderPainter`'s `_strokeWidth`/`_dashWidth`)
  very slightly for `longBreak` so the outline itself reads heavier, keeping "dashed, not a filled
  Card" for both.

All of this stays within `_buildBreak`'s existing `if (chunk.chunkType == ...)` branching that
already distinguishes the title string — it's a natural extension point, not a new one.

**Blast radius:** `chunk_card.dart` only (`_buildBreak`). No test currently pins the two breaks'
identical visual weight that I found; existing tests exercise text content
("Short break"/"Long break"/duration text), which is unaffected by padding/typography changes.

**Effort:** Low.

---

## G-07 — Mood choice doesn't explain its consequence (DESIGN)

**Reported:** Choosing a day type should say what it means (more chunks / fewer long breaks for a
sunny day, the reverse for a low day).

**Files:** `lib/screens/schedule/checkin_screen.dart:33-39, 140-168, 328-408`,
`lib/screens/schedule/acknowledgment_screen.dart` (dead code — see below),
`lib/screens/today/today_screen.dart:271-319` (`_buildHeader` mood chip),
`lib/services/schedule_generator.dart:24-48, 660-750`.

### Where the copy actually lives (and a duplicate that doesn't)

The live acknowledgment copy Dan quoted ("Stormy day — keeping it light. 3 chunks. Starting with
Exercise.") is produced by `_CheckinScreenState._buildAckText` (checkin_screen.dart:140-168), using
the `_moodPrefix` map (lines 33-39) and rendered inline in `_buildAcknowledgmentBody`
(lines 328-408) — this is the real, routed surface (`CheckinScreen`, reached via check-in).

`lib/screens/schedule/acknowledgment_screen.dart` has a near-byte-identical duplicate of
`_moodPrefix` and `_buildAckText`/`_firstChunkName`, but its own doc comment says it plainly: *"In
the current Phase 3 flow the acknowledgment content is shown inline inside CheckinScreen... this
widget exists for potential future standalone use."* It is not referenced from `router.dart` or
anywhere else — it's dead code. Any copy fix must land in `checkin_screen.dart`; the duplicate in
`acknowledgment_screen.dart` should either be updated in lockstep or deleted to stop it silently
drifting out of sync (it already differs cosmetically — e.g. "Tap or swipe up to begin" in the live
screen vs "Swipe up to begin" in the dead one).

The Today mood chip (`_buildHeader`, today_screen.dart:271-319) is a second, always-visible mood
touchpoint, but per G-06 below it's already over-full (mood + emoji + chunk count) and is the
*wrong* place to add an explanation — it's meant to be a glanceable, permanent chip, not a moment to
read prose. The acknowledgment screen (a dedicated, one-time, full-screen moment right after picking
mood) is the natural home for the "why" — it already has a captive audience and open space.

### The actual mapping, so any copy is accurate

From `lib/services/schedule_generator.dart:24-48`:

- `_moodCap = {1: 4, 2: 6, 3: 8, 4: 9, 5: 11}` — max discretionary work chunks by mood (1=lowest,
  5=sunniest).
- `_moodBreakCadence = {1: 2, 2: 3, 3: 4, 4: 4, 5: 5}` — work chunks between long breaks.

I traced the break-insertion pass (`_assignSyntheticStartTimes`, lines 731-750): `breakCount`
increments once per placed work chunk, and `isLong = breakCount % longBreakEvery == 0` — so the
**fraction of breaks that are long is exactly `1/longBreakEvery`**. Mood 1: every 2nd break is long
(50%). Mood 5: every 5th break is long (20%). So Dan's framing is quantitatively correct: sunnier
days get proportionally fewer long breaks relative to the (larger) amount of work, not just
"more chunks" — copy along the lines of "more chunks, breaks spaced further apart" for high moods
and "fewer chunks, more frequent long breaks" for low moods is accurate to the generator, not just a
vibe.

### Recommended fix

Extend `_buildAckText` in `checkin_screen.dart` (and, if kept, the dead duplicate) to append one
short clause stating the consequence, sourced from a small static per-mood-tier description (it
doesn't need to read the generator's actual constants at runtime — the tables are fixed) — e.g.
appending a clause to the existing `_moodPrefix` strings or as a trailing sentence after
`$countText$startText`. Keep the existing 0-chunk reassurance branch (lines 154-157) untouched.

**Blast radius:** Copy-only in `checkin_screen.dart`. No test in this repo asserts the exact
`_moodPrefix`/ack-text strings (grepped `test/` for "Stormy day", "Overcast", "Starting with" —
only structural assertions like "Tap or swipe up to begin" and gesture behavior exist in
`test/screens/checkin_screen_widget_test.dart`), so this is low-risk to existing coverage. Decide
in the same pass whether to delete `acknowledgment_screen.dart` (dead code, unreferenced) or update
it to match — leaving it as-is guarantees a future drift bug.

**Effort:** Low (copy only); Medium if `acknowledgment_screen.dart` is also reconciled/removed.

---

## G-01 — Onboarding valence order should be Drains / Neutral / Lifts (POLISH)

**Reported:** Segmented control reads `Lifts | Neutral | Drains`; should be `Drains | Neutral | Lifts`.

**File:** `lib/screens/onboarding/onboarding_screen.dart:378-396` (`_EnergyRow`, onboarding beat 3 —
"3. Energy — which of those goals lift you up, and which drain you?", per the file header comment at
line 18).

### Current implementation and change site

```
segments: const [
  ButtonSegment(value: EnergyValence.gives, label: Text('Lifts'), icon: Icon(Icons.bolt, size: 18)),
  ButtonSegment(value: EnergyValence.neutral, label: Text('Neutral'), icon: Icon(Icons.remove, size: 18)),
  ButtonSegment(value: EnergyValence.costs, label: Text('Drains'), icon: Icon(Icons.battery_2_bar, size: 18)),
],
```
(onboarding_screen.dart:380-395). Fix is reordering these three list entries: `costs` first, `gives`
last.

### Test impact

`test/screens/onboarding_flow_test.dart:200-202` taps `find.text('Drains')` and asserts
`goals.goals.single.energyValence == EnergyValence.costs` — this finds by text, not position, so
reordering the list is **safe**; the test keeps passing unmodified.

### The same control elsewhere — and a pre-existing inconsistency this would make worse

`lib/screens/goals/goal_form_sheet.dart:261-278` (`_EnergyRow` inside the goal-edit form, reached
from the Goals screen) has the **same control with different labels**: "Gives energy" / "Neutral" /
"Costs energy" (not "Lifts"/"Drains") — this is a pre-existing wording inconsistency, independent of
G-01. Its segment order today is the same left-to-right sense as onboarding's current order
(positive first, negative last): `gives → neutral → costs`.

**If only onboarding is flipped, the app ends up inconsistent in *order* between the two screens**
(onboarding: drains-left/lifts-right; goal form: gives-left/costs-right) where today they at least
agree on order (if not wording). Recommend flipping **both** controls' order together
(`goal_form_sheet.dart:261-278` segments reordered to `costs, neutral, gives`) so the app is
consistent app-wide, per the task's explicit ask. Reconciling the wording mismatch ("Lifts/Drains"
vs "Gives energy/Costs energy") is a separate, pre-existing issue outside G-01's scope, but worth a
one-line flag to Dan since he's looking at this exact control family right now.

`test/screens/goal_form_valence_test.dart` (grepped) only asserts by label text (`find.text('Gives
energy')` etc.), not position — reordering there is equally safe.

**Blast radius:** `onboarding_screen.dart` (required), `goal_form_sheet.dart` (recommended, for
app-wide consistency). No test changes required in either file.

**Effort:** Low.

---

## G-06 — Chunk count rendered twice at the top (POLISH)

**Reported:** "0 of 9 Chunks" progress bar + "Sunny day · 9 chunks" mood chip both show the count.

**Files:** `lib/screens/schedule/widgets/schedule_progress_bar.dart:32-37` (`'$completed of $total
Chunks'`), `lib/screens/today/today_screen.dart:309-315` (mood chip:
`'$moodEmoji $moodLabel · $workChunkCount $chunkWord'`).

### Current layout and where each count comes from

`TodayScreen.build()` (today_screen.dart:917-932) renders, top to bottom: `ScheduleProgressBar` →
(banners) → `_buildHeader` (which contains the mood chip) → the edge-state line → the day list.
`ScheduleProgressBar` shows *both* the total **and** completed count plus a `LinearProgressIndicator`
— strictly more information than the mood chip's total-only count.

Notably, `.planning/phases/22-unified-today-screen/22-UI-SPEC.md:26-31` ("Structure") describes the
screen as exactly two elements — "Header" (with the mood chip, whose locked example is literally
`"Steady day · 9 chunks"`) and "The day" — and **does not mention `ScheduleProgressBar` at all**.
That strongly suggests `ScheduleProgressBar` is a carry-over from the old pre-Phase-22
`schedule_screen.dart` that survived the merge without being re-specified, rather than a deliberate
Phase 22 design decision — which is consistent with it visually sitting *above* "Today" (i.e.,
above the header the spec calls the first element), an odd position for something the spec doesn't
even describe.

### Recommended de-duplication

Keep `ScheduleProgressBar` — it's strictly richer (completed/total + visual bar, not just total) —
and drop the redundant `$workChunkCount $chunkWord` suffix from the mood chip
(today_screen.dart:309-315), leaving it as `'$moodEmoji $moodLabel'` (e.g. "☀️ Sunny day"). This
keeps 100% of the progress information the task asked to preserve, sourced from a single place.

**Conflict to flag plainly:** this means diverging from the literal example string locked in
`22-UI-SPEC.md` line 30 ("Steady day · 9 chunks"). That line should be updated alongside the code
change so the spec stays honest (per this project's own documentation ethos) rather than describing
a chip that no longer matches. I did not find any UAT/verification doc that re-locks that exact
string for Phase 23, so this reads as a safe, narrow amendment to a Phase 22 example rather than a
reversal of a Phase 23 decision.

**Blast radius:** `today_screen.dart` (`_buildHeader`, one string), `22-UI-SPEC.md` (one example
string, doc-only). Grepped `test/screens/today_screen_test.dart` and
`today_screen_now_state_test.dart` for the chip's exact text — no test asserts it, so no test
changes required.

**Effort:** Low.
