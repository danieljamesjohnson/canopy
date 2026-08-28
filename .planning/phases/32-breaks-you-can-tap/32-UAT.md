# Phase 32 — Human UAT (Breaks You Can Tap)

**What shipped, in one paragraph.** Breaks are now tapped, not swiped, at a timeline scale of
6.0 px/min (up from 4.0) — a 5-minute break is a real 30dp bordered card, not a hairline, carrying
a visible 64dp-wide Skip rail on its right edge; a 30-minute break carries the same shape at 180dp;
a *live* break (including a live 5-minute one, which previously had no button of any kind) carries
the identical rail; and the swipe gesture is gone from breaks entirely (work chunks keep it
unchanged). **Two items below are inherited from Phase 31, not raised by this phase**: D-31-07 (a
live break's Skip button has never been confirmed by a human on a device, across two prior UAT
rounds) and the "Up next" transition question (flagged in round two of Phase 31's UAT, still
unruled). This phase changes the surface beside both, so both are re-asked here rather than assumed
settled.

---

## A note on how this document was produced, and by whom

This document was written by an executor (plan 32-03) running inside a git worktree, which is
**force-removed the instant it returns**. Per this plan's own division-of-labour instruction, the
durable build served to the owner at `http://danserver:8143/` — including reclaiming that port from
whatever is squatting it, and the byte-verification pre-flight against it — is **the
orchestrator's** job, run from the main tree **after** this wave is merged. This executor did not
touch port 8143 at all (confirmed below) and did not serve anything there.

What this executor **did** do, entirely inside the isolated worktree, on a **scratch port (8153)**,
against a build produced from the exact same merged source (32-01 + 32-02; this plan's own commits
add no production code): built the debug bundle, served it with the repo's own `serve-uat.py`,
byte-verified it, and used it to take the real-browser measurement of the compact break card that
Task 1 exists to produce. Those numbers are reported below as **this executor's own scratch-port
verification**, not as the port-8143 verification the owner will actually look at — the two builds
are expected to be byte-identical in content (same source tree) but come from different serving
instances, and this document does not claim otherwise.

**The pre-flight block immediately below, for port 8143, is a placeholder for the orchestrator to
fill in verbatim after merge.** Do not read any line in it as true until every bracketed field has
been replaced with a real command and its real output.

---

## Pre-flight, Part A — port 8143 (the owner's build) — ORCHESTRATOR TO FILL IN

**Reclaim the port first.** At the time this document was written, port 8143 was held by:

```
$ lsof -i :8143
COMMAND     PID USER   FD   TYPE    DEVICE SIZE/OFF NODE NAME
python3 3484010  dan    3u  IPv4 152576800      0t0  TCP *:8143 (LISTEN)

$ ps -o pid,lstart,cmd -p 3484010
    PID                  STARTED CMD
3484010 Wed Aug 26 08:06:46 2026 python3 tools/serve-uat.py 8143 --dir build/web
```

This is the leftover server from plan 31-08's round-two UAT (started 2026-08-26 08:06:46,
serving Phase 31's bundle) — the same server this document's own author observed but did **not**
kill, per this plan's division-of-labour instruction. **Orchestrator: kill this PID (or whatever
PID holds 8143 by the time you run this) before building anything, and record here what you
killed and when:**

- **Killed PID:** `3484010`
- **Killed server's start time:** `Wed Aug 26 08:06:46 2026` — confirmed by `ps -o pid,lstart,cmd -p 3484010` immediately before the kill, matching the PID and start time recorded above. It was still serving Phase 31's bundle, i.e. the exact build the owner already judged FAIL.
- **Replacement PID (this build's server):** `1100897` — `python3 tools/serve-uat.py 8143 --dir build/web`, started 2026-08-27 from the merged `master` tree at commit `1e9864b`.

*Third time this trap has fired on this project. It is no longer a surprise; it is a step.*

Build command (verbatim — never `flutter run -d web-server`, never a release build on this port):

```
flutter build web --debug --source-maps --pwa-strategy=none
```

Serve command (verbatim — never `python3 -m http.server`, trap #3):

```
python3 tools/serve-uat.py 8143 --dir build/web
```

Byte-verification (paste every command with its verbatim output):

```
$ sha256sum build/web/main.dart.js
3ec894695b56acfe417aa8657b45a6af4bfa277b029c0ba29c0ddeabda7af943  build/web/main.dart.js

$ curl -s http://danserver:8143/main.dart.js | sha256sum
3ec894695b56acfe417aa8657b45a6af4bfa277b029c0ba29c0ddeabda7af943  -

$ curl -s http://danserver:8143/main.dart.js | grep -c BreakSkipButton
11

$ curl -sI http://danserver:8143/main.dart.js | grep -i cache-control
Cache-Control: no-store, max-age=0
```

**VERIFIED — 2026-08-27.** The two sha256 digests are identical (`3ec8946…af943`), so the bytes on
the wire are the bytes just built from the merged `master` tree; `BreakSkipButton` appears **11**
times in the served bundle, matching the scratch-build count exactly; and `Cache-Control` is
`no-store, max-age=0`, so a cache entry created before this build cannot win a `304`.

**What this does and does not prove.** It proves the *code* shipped and that the browser cannot
serve you a stale copy of it. It proves **nothing** about what the schedule on screen was generated
by — that is Step 0's job, and Step 0 is not optional. Reading a clean pre-flight as "the feature is
present on screen" is precisely the mistake that produced a false FAILURE on 2026-08-21 and let a
real defect survive three more days.

### Why `BreakSkipButton`, not `kBreakSkipButtonWidth` — the presence-probe trap, again

This project's own carried-forward lesson (`31-GAPS-UAT.md`): `dart2js` const-folds a `const
double` to a bare literal, so grepping for `kBreakSkipButtonWidth` (the new geometry constant) on
this executor's own scratch build returned **zero** even though the constant is very much in the
compiled bundle — the identifier just isn't what ships. `BreakSkipButton` (the new widget *class*
this phase introduces) is not const-folded and returned **11** non-comment occurrences on the
scratch build below. Use `BreakSkipButton` as the presence probe; do not read a zero on
`kBreakSkipButtonWidth` as "the feature is missing" if you try it — it means "wrong probe," exactly
as it did for wave 1's grip glyph.

**⟳ Re-check-in reminder before this pre-flight is complete:** a non-zero grep proves the code
shipped. It does **not** prove the schedule on screen was produced by it — see Step 0 below, which
must run before any item is judged, on the same freshly served build.

---

## Pre-flight, Part B — scratch port 8153 (this executor's own measurement build)

Confirms this executor's real-browser measurement (below) was taken against a build free of the
known staleness traps, on a port this executor owns exclusively for the duration of this task and
which is **shut down before this plan returns** (confirmed at the end of this section).

```
$ lsof -i :8153        # before build — confirms the scratch port was free
(no output — nothing was listening)

$ flutter build web --debug --source-maps --pwa-strategy=none
✓ Built build/web

$ nohup python3 tools/serve-uat.py 8153 --dir build/web &
serving build/web on 0.0.0.0:8153 with Cache-Control: no-store

$ sha256sum build/web/main.dart.js
3ec894695b56acfe417aa8657b45a6af4bfa277b029c0ba29c0ddeabda7af943  build/web/main.dart.js

$ curl -s http://localhost:8153/main.dart.js | sha256sum
3ec894695b56acfe417aa8657b45a6af4bfa277b029c0ba29c0ddeabda7af943  -

$ curl -sI http://localhost:8153/main.dart.js | grep -i cache-control
Cache-Control: no-store, max-age=0

$ curl -s http://localhost:8153/main.dart.js | grep -c BreakSkipButton
11

$ curl -s http://localhost:8153/main.dart.js | grep -c kBreakSkipButtonWidth
0    # expected — const-folded, see above; not a missing-feature signal
```

**✓ VERIFIED (scratch build only).** Built and served sha256 are identical; `BreakSkipButton`
greps non-zero; `Cache-Control: no-store` is present. `flutter test` (621/621) and `flutter
analyze` (clean) were re-run against this exact merged tree immediately before this build — see
"Suite status" below.

**Distinguishing code-shipped from data-on-screen, stated in this document's own words (trap #4,
CLAUDE.md):** every check above proves the running JavaScript is the code this phase wrote. None of
it proves that *today's rendered schedule* was generated by that code — a schedule generated before
this build landed would still render, silently, against the old 4.0 scale, because
`ScheduleNotifier._loadToday()` reads straight from local storage and the generator only runs at
check-in with silent replace. That is exactly what **Step 0** exists for, and the person who just
watched a clean grep scroll by is the person most likely to skip it because the grep felt like
proof. It is not proof of that. Both port-8143 and port-8153 builds carry this identical risk —
Step 0 is not a port-8143-only requirement.

**Scratch server shut down before this plan returned:**

```
$ kill 1060962
$ lsof -i :8153
(no output — confirmed down)
```

### Suite status on this merged tree (re-run immediately before the scratch build above)

```
$ flutter analyze
No issues found! (ran in 0.8s)

$ flutter test
...
00:14 +621: All tests passed!
```

621/621 green, `flutter analyze` clean — the same totals `32-02-SUMMARY.md` recorded, confirming
this plan's own read-only measurement work introduced no regression (this plan modifies no
production source; `files_modified` in its own frontmatter is this document alone).

---

## Real-browser measurement — the compact (30dp) break card, TAPBREAK-03's backstop truth

Measured against this executor's own scratch build (port 8153), headless Chromium,
`--use-gl=swiftshader --enable-unsafe-swiftshader`, viewport 390×844 CSS px at
`deviceScaleFactor: 1` (so 1 image pixel == 1 dp, no retina scaling to divide out). The app was
driven end-to-end through onboarding and a real morning check-in (mood 3 of 5, no fixed
commitment) to reach an actually-generated schedule containing a real 5-minute break between two
Exercise chunks — not a synthetic fixture.

**Screenshots:** `.planning/phases/32-breaks-you-can-tap/shots/today-timeline-full.png` (full
page), `.planning/phases/32-breaks-you-can-tap/shots/compact-break-30dp-crop.png` (tight crop of
the measured row), `.planning/phases/32-breaks-you-can-tap/shots/compact-break-30dp-zoomed.png`
(4× enlarged for visual inspection). The measured row, in words:

```
[11 AM] ┌────────────────────────────────────────┬────────┐
        │              Short break                │  ▶│   │
        │                                          │ Skip  │
        └────────────────────────────────────────┴────────┘
        [Exercise 11:00 AM – 11:25 AM ...]
```

**Pixel measurements (all in device-independent pixels, 1:1 with image pixels at this capture):**

| Quantity | Measured value | Expected / reasoned value | Verdict |
|---|---|---|---|
| Card painted height (top border row → bottom border row, inclusive) | **30px** (row 628 → row 657) | `5 min × kPixelsPerMinute(6.0) = 30dp` exactly | **MATCH — no clipping, no overflow into the next row** |
| Label text ink extent (core solid ink rows, excluding anti-aliased fringe) | **8px** (rows 638–645); with AA fringe, 637–646 (10px) | UI-SPEC's reasoned estimate: "one `bodySmall` line is typically 16–18dp with real Roboto metrics" (line-box, not bare ink) | Ink-only extent is smaller than a full line-box by design (ink excludes ascender/descender padding); **not directly comparable 1:1, but consistent with a normal single line rendering inside the slot, not an oversized or wrapped one** |
| Clearance: card top border → ink top | **9px** (628 → 637) | UI-SPEC's estimate implied comfortable single-digit-to-low-teens clearance | **Comfortable — no crowding against the border** |
| Clearance: ink bottom → card bottom border | **11px** (646 → 657) | (same) | **Comfortable — no crowding against the border** |
| Skip rail width (errorContainer fill, left edge → right edge before border) | **63px** (x=310 → x=372, border at x=373) | `kBreakSkipButtonWidth = 64.0` | **MATCH within 1px (border anti-aliasing)** |
| Skip rail height | Same 30px span as the card (rail fill starts/ends at the identical rows as the card's own top/bottom border, confirmed by column scan at x=340) | Full row height via `CrossAxisAlignment.stretch`, per 32-01/32-02's own commits | **MATCH** |

**Fit verdict: CONFIRMS the UI-SPEC's reasoned expectation.** The compact tier's real content —
one `bodySmall` label line, zero card margin, inside a bordered `Card` at a 30dp slot — fits with
comfortable, roughly symmetric clearance (9dp above the ink, 11dp below it) and with **zero pixels
of clipping or overflow** into the neighbouring Exercise row (confirmed by the clean transition
back to page background between the break card's bottom border, row 657, and the following card's
own top border, row 662). This is a **real-device measurement, not a restated estimate** — the
9px/11px clearance numbers and the exact 30px card height were read directly from a screenshot
pixel buffer, not inferred from `flutter test`'s placeholder-font metrics.

**This measurement does not, and cannot, answer** whether the card "reads as a section of the day"
or whether the Skip rail "reads as one tappable unit" — those are the two perceptual judgments
Task 2 exists for. This block only closes the geometric half of TAPBREAK-03 (does it fit), not the
perceptual half (does it read right).

---

## Three orchestrator observations — stated so you don't meet them cold

Recorded from the served build before handing this over. **Neither is a verdict** — both are exactly
the kind of perceptual call this document exists to put to you, and saying "I noticed it looks fine"
would be me judging an item I am not allowed to judge. Flagging them so Items 1–2 start from what is
actually on screen.

1. **The Skip rail is a different colour from the card body** — the label sits on the card's grey
   `surfaceContainer` fill, the rail on a pink `errorContainer` fill, meeting at a hard vertical
   edge. That is the design contract working as written (D-32-03's rail is meant to be visible), and
   it is also precisely the thing Item 2 asks about: a two-tone split can read as *one control with
   an action end*, or as *two separate zones*. You are the only one who can say which. Look before
   you read Item 2's wording.

2. **The break's Skip and a work chunk's Skip use the same icon and word but different layouts** —
   both are `skip_next` (▶|) + "Skip", but the break stacks them (icon above label, to fit 30dp)
   while the work chunk sets them inline. Same vocabulary, different arrangement. Possibly
   invisible in use; possibly reads as two different controls. Not covered by any numbered item, so
   mention it under Item 2 if it bothers you.

3. **A *running* 30-minute break's Skip looks different from every other break's Skip — and that is
   ruled, not broken.** Items 1–3 show you a 64dp pink rail with the word "Skip" under the icon. When
   you get to Item 4(a), a break that is **running** and is 30 minutes long shows the older
   **icon-only** button instead (same `skip_next_outlined` glyph, but the word "Skip" lives only in
   its tooltip, not on screen). That is D-31-07's button, which this phase's own charter explicitly
   preserves — *"Do not remove `LiveRowCard`'s compact-tier Skip button. It survives."* A running
   **5-minute** break gets the labelled rail, same as everywhere else. So there are two appearances
   in play, on purpose. **Flagged so you don't read it as a bug in Item 4** — but if the
   inconsistency itself bothers you, say so under Item 4 and it becomes its own scoped follow-up.
   (Found during the 2026-08-28 code review, `32-REVIEW.md`.)

**What is NOT in doubt:** the glyph is no longer `Icons.drag_indicator`. Phase 31's round-two defect
was a six-dot *reorder grip* on a control that could not be reordered — an icon that meant the wrong
verb. `skip_next` means skip. That specific defect is gone; whether the new arrangement has its own
is what Item 2 is for.

---

## STEP 0 — MANDATORY, DO THIS FIRST. Tap ⟳ Re-check-in.

**Not optional and not a formality.** `ScheduleNotifier._loadToday()` reads today's schedule
straight from local storage, and the generator only runs at check-in with silent replace. **An
already-generated day is never regenerated on load.** If today's schedule on your device was
generated before this build landed, every item below would be judged against a stale,
pre-6.0-scale day — even though the pre-flight above (once the orchestrator fills it in) will
correctly prove the new code shipped. Code shipping and today's data reflecting it are two
different facts, and only one of them is proven by a grep.

**This exact omission happened on 2026-08-21**: a UAT judged a pre-fix day, reported a false
failure, and let the real defect survive three more days until the owner reported the identical
symptom again on 2026-08-24. Do not repeat it.

**Step 0 performed:** _______________ (owner: record the date here, in your own hand, before
judging anything below)

**An unrecorded Step 0 invalidates every item below and must be re-run, not assumed** — this is not
something the orchestrator or this executor can perform on your behalf; it requires tapping the
control in the running app on your device.

---

## Do this on a phone or tablet — not a desktop pointer

A mouse cursor is a single pixel. The entire question below is what happens when the input is
roughly 40dp of fingertip, so a trackpad or mouse verdict does not answer it.

---

## Item 1 — does a 5-minute break read as a section of the day? (TAPBREAK-03)

- **(a)** Does the short break read as a real, small section of the day — or does it still read as
  a line between two blocks?
- **(b)** Does it still read as a **break**, now that it wears the same card container a work block
  wears?
- **(c)** Is the label comfortably legible inside the card, or does it crowd the border? (This
  executor's own real-browser measurement above found 9–11dp of clearance on each side and zero
  clipping — but whether that *reads* as comfortable to a human eye is your call, not this
  document's.)
- **(d)** The whole day is now 50% taller to scroll — an 8-hour day goes from roughly 1920dp to
  roughly 2880dp. Does that trade feel right in the hand, not just on paper?

**Verdict: FAIL (d), and a defect this item did not think to ask about.** Judged by the owner
2026-08-28 on the served build: *"it does appear to be working, but the ui looks much worse. there's
huge gaps and the long break has too big of a skip. this should all be designed to be pretty."*

- **(a)/(b)/(c) — not separately scored, and that is recorded rather than inferred.** The owner's
  objection was to the *whole screen*, not to the short break's own card. Nothing he said
  contradicts (a), (b) or (c), and nothing he said confirms them either. **Do not write these up as
  PASS because the complaint landed elsewhere** — that is the "superseded ≠ passed" error this
  project already made once, on Phase 31's Item 1.
- **(d) — FAIL.** The 50%-taller day was accepted on paper as "more scrolling." What it actually
  produced is **dead space inside the day**, which is a different cost than the one that was
  approved, and it is the dominant visual defect.

**Root cause, found in code the same day (not eyeballed).** `today_screen.dart:840` wraps every
timeline row in `OverflowBox(alignment: Alignment.topCenter, minHeight: 0, maxHeight:
double.infinity)` — the card lays out at its **natural** height and is top-aligned inside the slot;
`ClipRect` only prevents overflow, it never fills. A 25-minute work chunk's card is ~83dp of content
in what is now a 150dp slot, so **~67dp of empty background trails every work chunk.** At
`kPixelsPerMinute = 4.0` the same mechanism left ~17dp and read as ordinary card spacing; D-32-01
did not create this, it **made it visible everywhere at once**.

**This was foreseeable and nobody looked.** The phase re-derived every *break* constant against 6.0
with real care, and never asked what a 50%-taller slot does to a card whose content height does not
scale. The phase's own real-browser measurement measured a single 30dp break card **in a tight
crop** — the thing under optimisation — and never rendered a full day and looked at it.

---

## Item 2 — does the Skip rail read as ONE tappable thing, and can a thumb hit it? (TAPBREAK-01, D-32-03)

**This is the item that carries the defect class that ended the last round** — an element that was
perfectly legible and meant the wrong verb (`Icons.drag_indicator`, read as "drag to reorder"
instead of the swipe it triggered). There is no icon-meaning risk this time (the rail carries no
ambiguous glyph — a `skip_next_outlined` icon over the word "Skip"), but "is this ONE button or TWO
zones" is a new, different question this design raises, and it is asked directly rather than
inferred from "no complaints."

- **(a)** Does the rail read as a single button, or as two separate zones (an icon zone and a word
  zone)?
- **(b)** Does the icon plus the word say "skip this break" to you, or does it say something else?
- **(c)** Skip five short breaks with a thumb at a natural placement. How many landed first time?
- **(d)** Did skipping a break ever accidentally hit the work block above or below it?

**The geometry, stated honestly.** The rail is about **64dp wide by 30dp tall** on a short break —
roughly **1920dp²** against Material's 48×48 = 2304dp² guideline. Deliberately under, and
deliberately so: every pixel of the 1920dp² is **painted, visible fill** (`colorScheme.errorContainer`),
not an invisible slop band. The previous approach (Phase 31) met the 48×48 number with an invisible
acquisition band and still failed a thumb twice. This trades some area for total visibility; whether
that trade actually works is exactly what (c) above measures.

**Verdict: UNMEASURED — explicitly not a PASS.** The owner's 2026-08-28 report was *"it does appear
to be working"*, which speaks to the mechanism functioning, **not** to acquisition. He gave no
five-attempt count and no one-button-or-two-zones answer, and neither is inferable from "it works."

**Five-attempt count:** not taken. **One button or two zones:** not answered.

**This is the third consecutive round in which this project's central touch question has gone
unmeasured** (Phase 31 round one superseded it, round two never reached it, this round returned
"works" without a count). **It must be asked again, first, in the next round** — a redesign that
follows a complaint is not evidence the underlying target was ever acquirable.

---

## Item 3 — the long break's rail (a planner default, not your ruling)

On a 30-minute break the rail is the same 64dp wide but **180dp tall** — the identical shape as the
short break's rail, just stretched to fill a much taller row. Applying one shape to both tiers was
chosen for simplicity and because the owner's own words were "have a skip button on the side,"
stated without qualifying it to one tier — it was never re-litigated as a locked decision. The
30dp case is the one the geometry in Item 2 was derived against (the worst case); the 180dp rail is
never a *smaller* target, only a more generous one.

- Does the full-height rail on the 30-minute break read sensibly, or does it look odd?

**A "looks odd" answer here is new evidence, not a contradiction of anything settled** — record it
plainly either way.

**Verdict: FAIL.** Owner, 2026-08-28: *"the long break has too big of a skip."*

The planner's own reasoning is what failed, and it is worth naming precisely. D-32-03 fixed the rail
at 64dp wide and let `CrossAxisAlignment.stretch` take the height from whatever row it lands in.
That was derived entirely from the **worst case** — the 30dp short break, where the rail has to earn
its touch area from width because it cannot get it from height. Applying the identical shape to the
30-minute break was justified as "never a *smaller* target, only a more generous one," which is true
about **touch** and says nothing about **appearance**. A 64dp-wide error-coloured slab running the
full height of a 180dp row is not a generous button; it is a large red panel that outweighs the
break it belongs to. **"Never worse for the thumb" was silently treated as "never worse," and the
two are not the same claim.**

Routed, not noted: the remedy is a tier-specific rail treatment for the long break, folded into the
same visual pass Item 1(d) requires — not a re-litigation of the short break's 64×30 geometry, which
nothing in this round contradicted.

---

## Item 4 — a break that is running RIGHT NOW (D-31-07, never yet judged by a human)

**You ruled this in on 2026-08-26 (D-31-07) and never reached it in the last round** — the owner's
UAT stopped at Item 2 before reaching the live-break item. This phase changes the surface
immediately beside it (the short break's whole card was rebuilt), so it is re-asked here rather than
assumed still correct.

**A practical route to a live break, without waiting for one:**

1. Note a break's start time from the timeline (e.g. the "Short break" row you just looked at in
   Item 1/2).
2. Go to **Settings**.
3. Use the **time-travel** control ("Set a specific time", or the `+5m`/`+15m`/`+30m` quick-shift
   buttons) to set the simulated clock to a minute inside that break's window.
4. Return to **Today**.
5. **Stay inside the same calendar day** — crossing midnight changes which day's schedule you are
   looking at.
6. **Reset the clock** ("Reset to real time" in Settings) when you are done.

- **(a)** On a running **30-minute** break, is there a Skip action and no Complete action, and does
  tapping it work?
- **(b)** On a running **5-minute** break, is there a Skip rail at all? **This is new** — until this
  phase, a live 5-minute break had no button of any kind; its only skip mechanism was the swipe
  that has now been removed from every break.
- **(c)** When you skip a running break, does the row stay exactly where it was on the timeline (same
  height, same position), and does the red now-line stay put rather than jumping?

**Verdict: NOT REACHED — for the third round running.** The owner's 2026-08-28 report stopped at the
visual defects and does not mention the time-travel route, a live break, or the now-line. Reaching
this item requires deliberately shifting the simulated clock in Settings, and nothing in his report
indicates that happened. **(30-min case):** not reached. **(5-min case):** not reached.

**D-31-07 has now been code-complete and test-proven since 2026-08-26 and confirmed by a human
zero times, across three UAT rounds** (Phase 31 round two stopped before it; this round stopped
before it). It is not failing — it is simply never being got to, because it sits behind the items
that keep failing. **In the next round it must move above them**, or it will be skipped a fourth
time for the same structural reason.

---

## Two open questions — answer them, but they are not pass/fail

### (a) The "Up next" transition

When you skip a break that is running, the header stops calling it "now" and switches to the next
chunk, while the red now-line stays exactly where it is. This is **pre-existing behaviour**
(`resolveNowState`'s advance-past-resolved loop, `now_state.dart:176`) — not something this phase
added — and nobody has ruled on whether it is right. It was flagged in Phase 31's round-two UAT and
is still unanswered.

**What should happen?** _______________

### (b) Free time still looks different from a break

Free/gap regions on the timeline still render as dashed outlines, while breaks are now filled
cards. An earlier UAT (Phase 22) deliberately made those two visually match; this phase's own "make
breaks look like work" instruction has pulled them apart again — a foreseeable side effect, not an
accident.

**Acceptable, or does it want its own phase?** _______________

---

## Two things carried forward, not questions

- **Skipped-break legibility at half opacity**, and **"skipping a break does not hand the minutes
  back"** both passed human UAT in Phase 31 and are settled. This phase rebuilt the same rows, so
  say something only if either now looks **different** than it did before — otherwise no action
  needed.
- **Break cards are still not tappable**, by the owner's own standing instruction from 2026-08-21,
  enforced by a test rather than by convention. Not a question; recorded so it stays visible.

---

## Resume signal

Type **"approved"** if Items 1–4 all pass. Otherwise describe what happened per item:

- **Item 1:** whether it reads as a section of the day, and whether it still reads as a break.
- **Item 2:** the five-attempt count, and whether the rail read as one button or two zones — quote
  what the icon-plus-word said to you, in your own words.
- **Item 3:** whether the tall rail looks right or odd on the long break.
- **Item 4:** whether each of the 30-minute and 5-minute live cases offered a Skip, and whether the
  row/now-line stayed put when you used it.

Answer both open questions in your own words, or explicitly record them as still unanswered rather
than leaving them silent — silence is not read as consent either way.

If either carried-forward item now looks different, say that too.

---

## Remedies if an item fails

**Any FAIL routes explicitly — to a further gap-closure plan in this phase, or to a new phase —
never noted and left.** A recorded failure with no route is how Phase 24's DayComplete gap survived
a full plan cycle, and it is exactly what this phase's own `must_haves.prohibitions` forbid.

- If **Item 1** fails (doesn't read as a section, or doesn't read as a break), the remedy is a
  design follow-up to the card's visual weight or copy — not a geometry tweak, since the geometry is
  already measured and confirmed to fit.
- If **Item 2** fails (reads as two zones, or the icon+word say the wrong thing, or the thumb
  misses repeatedly), the remedy is a rework of the rail's visual grouping or icon choice — exactly
  the kind of defect a widget test cannot catch, per this project's own three-strikes history
  (Phase 27, Phase 29, Phase 31).
- If **Item 3** fails ("looks odd"), the remedy is a tier-specific rail treatment for the long break
  — a scoped follow-up, not a re-litigation of D-32-03's short-break geometry.
- If **Item 4** fails, the remedy depends on which sub-case: a missing live 5-minute Skip rail is a
  Rule-1-class bug (regression against 32-02's own committed work); a UX objection to the
  transition is a product decision requiring an explicit owner ruling before any code changes.
- Either open question, if it comes back with a clear preference, becomes its own scoped follow-up
  — neither is a "just fix it" item.

---

## Summary

```
total: 4
passed: 0
issues: 2
pending: 2
skipped: 0
blocked: 0
```

**Judged 2026-08-28 by the owner on the served build (port 8143).** Item 1 FAIL (on (d); (a)–(c)
deliberately unscored, not passed), Item 2 UNMEASURED (mechanism reported working; acquisition never
counted), Item 3 FAIL, Item 4 NOT REACHED. **Zero items passed.** The mechanism works; the result is
not something the owner wants to look at.

**The one-line summary, in his words:** *"it does appear to be working, but the ui looks much worse
... this should all be designed to be pretty."*

## Gaps

```yaml
- id: G-32-01
  item: 1(d)
  severity: high
  summary: >
    Every timeline row is top-aligned at its card's NATURAL height inside a duration-exact slot
    (today_screen.dart:840, OverflowBox alignment topCenter / maxHeight infinity), so a ~83dp
    work card sits in a 150dp slot and trails ~67dp of dead background. D-32-01's 4.0 -> 6.0
    did not create this; it made a pre-existing 17dp slack into a 67dp hole on every work chunk.
  not_a_fix: >
    Reverting kPixelsPerMinute alone. That re-hides the defect at the cost of the 30dp break the
    owner asked for, and returns the short break to the hairline two prior phases existed to fix.
  route: visual gap-closure — decide by looking, not by arithmetic (see G-32-04)

- id: G-32-02
  item: 3
  severity: medium
  summary: >
    The Skip rail's one-shape-fits-both-tiers rule (D-32-03 + CrossAxisAlignment.stretch) makes a
    64dp-wide errorContainer slab run the full 180dp height of a long break. Derived from the 30dp
    worst case, where the rail must earn touch area from width; never re-examined for appearance
    at the tall tier.
  route: tier-specific rail treatment for the full break tier; short break's 64x30 geometry is
    NOT re-litigated (nothing this round contradicted it)

- id: G-32-03
  item: 2
  severity: high
  summary: >
    The five-attempt thumb-acquisition count has never been taken, in any round, for any break
    design. Round one superseded it, round two never reached it, round three reported "it appears
    to be working" without counting. This is the project's central touch question and it is
    unmeasured, not passed.
  route: must be Item 1 of the next UAT, above every visual item, so it cannot be crowded out again

- id: G-32-04
  item: 1, 3 (method, not a screen)
  severity: high
  summary: >
    This phase's design contract was arithmetic that was never looked at. Every constant was
    derived and defended in prose; the one real-browser measurement was a TIGHT CROP of the single
    card under optimisation. No full day at 6.0 was ever rendered and viewed before it shipped to
    the owner. This is the same failure shape as Phase 31's drag_indicator: locally correct,
    wrong at the altitude a human actually sees.
  route: mock the whole screen visually (throwaway HTML, served on the tailnet) and have the owner
    choose a look BEFORE any Dart changes

- id: G-32-05
  item: 4
  severity: medium
  summary: >
    D-31-07 (live-break Skip, both the 30-min and the new 5-min case) is code-complete and
    test-proven since 2026-08-26 and has been confirmed by a human ZERO times across three rounds.
    It is never reached because it sits behind the items that keep failing.
  route: move above the visual items in the next UAT's ordering
```

<!-- Open questions (a) "Up next" transition and (b) free-time vs break styling remain unanswered.
     Question (b) is now entangled with G-32-01 — the dashed free-time regions are 50% taller too,
     and are part of what the owner is seeing as "huge gaps." Do not answer it separately from the
     visual pass. -->
