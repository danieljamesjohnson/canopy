# Phase 31 Plan 05 — Human UAT

**Status:** awaiting owner

**Served at:** `http://danserver:8143/`
**Debug build** (`flutter build web --debug --source-maps --pwa-strategy=none`), served via
`python3 tools/serve-uat.py 8143 --dir build/web` (never `python3 -m http.server` — CLAUDE.md trap
#3). Port 8143 has served debug builds only, across Phases 29 and 30 and now this one — never a
release build, so trap #1 (service-worker collision) cannot apply here.

## A note on how this file was produced

This document was written by an executor running inside a git worktree, which is force-removed the
moment it returns — any server it started would die with it, and `build/web` is gitignored, so a
build it produced would be discarded on return. The build, the serve step, and the served-vs-built
byte verification below were therefore performed by the orchestrator from the main working tree,
**after** merging this plan's commits — not by this executor. Everything above the `---` divider
after the pre-flight block, and the four verification lines inside it, are the orchestrator's
output, not this executor's invention. This split is recorded as a deviation in
`31-05-SUMMARY.md`.

Before writing this file, the executor confirmed the phase is actually ready to be looked at:

```
$ flutter test
...
00:18 +625: All tests passed!

$ flutter analyze
Analyzing agent-acfdfce245dd7a28f...
No issues found! (ran in 1.8s)
```

625/625 tests green, `flutter analyze` clean. Both captured in the worktree before the merge that
fed the orchestrator's build.

## Pre-flight — served bytes match built bytes, and contain this phase's own string

Build command (verbatim, exactly as CLAUDE.md prescribes — never `flutter run -d web-server`, never
a release build on this port):

```
flutter build web --debug --source-maps --pwa-strategy=none
```

Serve command (verbatim — never `python3 -m http.server`, which sends no `Cache-Control` and can
serve a stale bundle, trap #3):

```
python3 tools/serve-uat.py 8143 --dir build/web
```

Verification run by the orchestrator on **2026-08-25**, from the main working tree, after the
build above:

```
$ sha256sum build/web/main.dart.js
6cebe2e51062d93531d5238fe8e211c7ee9e1e12daee0beb632e41a43d1fcab7

$ curl -s http://danserver:8143/main.dart.js | sha256sum
6cebe2e51062d93531d5238fe8e211c7ee9e1e12daee0beb632e41a43d1fcab7

$ curl -s http://danserver:8143/main.dart.js | grep -c ", skipped"
3

$ curl -s http://danserver:8143/main.dart.js | grep -c "needsSlop"
3

$ curl -sI http://danserver:8143/main.dart.js | grep -i cache-control
Cache-Control: no-store, max-age=0
```

**✓ VERIFIED — the two sha256 values are identical, and both grep counts are non-zero.** The bytes
being served on 8143 are byte-for-byte the bundle just built, that bundle contains this phase's
`", skipped"` semantics string, and it contains the `needsSlop` predicate that gates the grown
hit-test envelope. `Cache-Control: no-store` is present, so trap #3 cannot apply. Proceed to Step 0.

**One thing worth knowing, because it nearly produced a false UAT.** Port 8143 was still held by a
server started on **2026-08-24 09:49** — left running since Phase 29/30. It was killed and replaced
with a fresh one pointing at the new build before the sha256 comparison above was taken. Had it been
left up, the comparison would have been run against a server the owner was not actually being shown,
which is the same class of mistake as trap #3 with an extra day of staleness on top.

A non-zero grep count proves the *code* shipped and NOT that the *data on screen* was produced by
it — that distinction is trap #4, it is exactly what Step 0 below exists for, and an agent who has
just run this grep is exactly the agent most likely to skip Step 0 because the grep felt like proof.

---

## What automation already proved, and why you're still being asked

625/625 tests pass and `flutter analyze` is clean, including three plans' worth of proof that
`flutter test` genuinely can settle: the top and bottom slop bands both resolve to the break and
never steal from the neighbouring work chunk (proven non-vacuous by temporarily deleting the fix
and watching a named thief show up in the failure), the painted grid never moved a pixel in any
resolved state, and skipping a break writes no Goal, moves no other chunk, and appends exactly one
un-attributed log entry — all proven, not assumed, with a guard-removal RED run captured for each.

None of that settles the one thing this checkpoint exists for: **whether a real thumb, on a real
touch device, can reliably start and complete a leftward swipe on an invisible 52dp band around a
20dp painted row, without also grabbing the work chunk next to it.** `flutter test` fires synthetic
drags at exact coordinates — it does not, and cannot, model a fingertip's contact patch. Phase 27
scored 16 of 17 automated items and then failed 2 of 3 human ones; Phase 29's suite went 587-green
while the owner looked at a screen with no breaks on it at all. Green tests have been wrong about
what a thumb experiences twice already in this project. This is that check.

**This must be done on a phone or tablet, not a desktop pointer.** A mouse cursor is a single pixel;
the entire question is what happens when the input is roughly 40dp of fingertip.

---

## STEP 0 — MANDATORY, DO THIS FIRST. Tap ⟳ Re-check-in.

This is not optional and it is not a formality. `ScheduleNotifier._loadToday()` reads today's
schedule straight from Hive, and `ScheduleGeneratorService.generate()` only runs at check-in with
silent-replace. **An already-generated day is never regenerated on load** — if today's schedule was
built before this phase's code landed, every item below would be judged against a pre-change day
while the new code sits unused in the bundle that was just proven present above. This exact omission
happened on 2026-08-21: a UAT judged a pre-fix day, reported a false failure, and let the real
defect survive three more days until the owner reported the identical symptom again on 2026-08-24.
Re-check-in first. Item 3 in particular is meaningless without it.

Record here whether Step 0 was performed, and the date. An unrecorded Step 0 invalidates Item 3
below and must be re-run, not assumed — the orchestrator cannot perform this step for you, because
it requires tapping ⟳ Re-check-in in the running app.

**Step 0 performed:** _pending — owner_
**Date:** _pending_

---

## Item 1 — Can a thumb skip a 5-minute break? (SKIPBREAK-01)

Find a 5-minute break on the timeline — the thin hairline row with "Short break" between two work
blocks. Using a thumb, not a fingernail and not a stylus, swipe it **leftward**. Then judge:

- **(a) Did the swipe start reliably?** Try it five times at a natural thumb placement. Count how
  many attempts grabbed the break versus grabbed the work block above or below it.
- **(b) Did the swipe complete?** A left swipe should reveal a red panel with a right-pointing arrow
  and mark the break skipped.
- **(c) Did skipping the break ever accidentally complete or skip the work chunk next to it?**

The target is an invisible band 16dp above and 16dp below the visible hairline, so the reachable
area is roughly 52dp against a 20dp visible row. If (a) is unreliable, say roughly how it fails —
"it grabs the block above" and "nothing happens at all" are different defects with different fixes.

**Verdict:** _pending_

---

## Item 2 — Is a skipped break legible? (D-31-04)

Look at a skipped 5-minute break next to an unresolved one, at arm's length.

- **(a) Can you tell at a glance which one is skipped?**
- **(b) Is the struck-through label still readable, or has half opacity on an already-grey label
  pushed it past readable?**

If (b) fails, the planned fix is to raise the opacity **for the sub-compact tier only** and document
the new value — do not raise it everywhere. This was flagged in advance as a plausible risk that
could not be settled from a desk (see `31-02-SUMMARY.md` coverage entry D6).

Also glance at a **30-minute long break** and skip one: it should read as skipped too, with its
trailing duration text replaced by the word "skipped".

**Verdict:** _pending_

---

## Item 3 — Did anything else move? (D-31-03) — requires Step 0

Before skipping anything, note the start time of the work chunk immediately AFTER a break. Skip
that break. Then check that same start time again.

It must be unchanged. Skipping a break does **not** hand those minutes back — the day is
duration-exact and time-anchored, so the next work chunk still starts exactly when it always did.
This is deliberate and it is counter-intuitive; if it reads as wrong to you, say so, because pulling
the day forward is a real option that was explicitly deferred rather than dismissed, and it would
need your decision to plan.

**Verdict:** _pending_

---

## Two things planning deliberately did NOT do — flagging them so you find out from us, not later

These are not bugs. They are scope calls made in advance, and they need your ruling, not a silent
assumption either way.

**1. A break that is currently running still has no skip affordance.** While the now-line is inside
a break's own slot, that row renders through the live-row card (`LiveRowCard`), which shows its
Complete/Skip buttons for **work chunks only**. That was already true before this phase and this
phase did not change it — it is `PD-31-06`, recorded and left alone on purpose, not discovered by
accident. If you want a running break to be skippable too, say so; it is a small, separate change,
not a defect in this one.

**What do you want done about this?** _pending — options: open a small follow-up change, seed it
for later, or leave it as-is._

**2. Break cards are still not tappable.** No detail sheet, at any density. That was your own
instruction on 2026-08-21 and it is enforced by a test, not by convention. Recorded here only so it
stays visible, not because it needs a decision today.

---

## Resume signal

Type "approved" if all three items pass. Otherwise describe what happened per item — for Item 1 say
roughly how the swipe failed ("it grabs the block above" and "nothing happens at all" are different
defects with different fixes); for Item 2 say whether the label was unreadable at sub-compact; for
Item 3 say whether the following chunk's start time moved. Also say what you want done about the two
deliberate exclusions above.

If you are unavailable, this phase records `verification_deferred_human` in `STATE.md` and stays
open rather than closing on a green suite alone — exactly what Phases 29 and 30 did before being
judged honestly a working day later.

---

## Remedies if an item fails

Any FAIL routes explicitly — to a gap-closure plan in this phase, or to a new phase — rather than
being noted and left. A recorded failure with no route is how Phase 24's DayComplete gap survived a
full plan cycle. Do not let a FAIL here sit unrouted.
