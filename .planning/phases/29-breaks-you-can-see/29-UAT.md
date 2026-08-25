# Phase 29 Plan 04 — Human UAT

**Served at:** `http://danserver:8143/`
**Debug build** (`flutter build web --debug --source-maps --pwa-strategy=none`), served via
`python3 tools/serve-uat.py 8143 --dir build/web` (never `python3 -m http.server` — CLAUDE.md trap
#3). Port 8143 has served debug builds only, this phase and 29-03.

## Pre-flight — served bytes match built bytes (T-29-05 / PD-29-05)

Checked after Task 1's rebuild, again after Task 2's doc-comment-only `lib/` edit (rebuilt to be
certain rather than assume a comment change can't affect dart2js output — it didn't; both hashes
below are identical to Task 1's), and a third time immediately before presenting this checkpoint.

```
$ curl -s http://localhost:8143/main.dart.js | sha256sum
12ba918e2a3e0e4dd4533a5c76c2d2f8619ece375cb5e9285a96eea6f4b67d07  -
$ sha256sum build/web/main.dart.js
12ba918e2a3e0e4dd4533a5c76c2d2f8619ece375cb5e9285a96eea6f4b67d07  build/web/main.dart.js
```

**Identical.** The build you are about to judge is the build that was measured in Tasks 1 and 2.

---

## Already verified automatically (you do not need to re-check these)

- The timeline's hour spacing is still uniform with the sub-compact tier rendering
  (`measure_hours.py`: `VERDICT: UNIFORM`, 240.0/240.0px spacing, spread 0.0).
- The sub-compact break row's painted ink (10px) fits comfortably inside its 20dp slot.
- The 25-minute work card's own fit inside its 100dp slot has been re-measured in the browser
  (90px ink extent, DISMISSED — not a real clipping defect).

## What automation cannot tell us, and why you are being asked

`flutter test`'s font has no real glyph metrics, so it can call a break legible when it is not;
headless Chromium can blank the canvas outright and return a screenshot that reads as either a
pass or a false failure. Phase 27 scored 16 of 17 automated checks and then failed 2 of 3 on
exactly this kind of look.

---

## ⚠ ATTEMPT 1's DIAGNOSIS WAS WRONG — corrected 2026-08-24. Read this first.

The stale-Hive explanation written below on 2026-08-21 is **incorrect** and is kept verbatim
rather than deleted, because how it was reached matters more than the conclusion.

The owner re-checked-in on 2026-08-24 and dropped a second screenshot
(`~/feedback-drop/canopy/inbox/2026-08-24_13-07-23/`) of a **freshly generated** day. It still had
no breaks between his work chunks — but it *did* show one "Short break" hairline, between a
discretionary `Creative time` chunk and the first `Work` chunk.

That one break is the tell. Breaks were being emitted and Phase 29's sub-compact tier was rendering
them correctly. What was missing was breaks between **commitment-block** chunks — the owner's
`Work` is a commitment block, and `schedule_generator.dart` Step 1 walks a commitment window with a
bare `cursor += 25`, no break, no lattice. STEP C then passes those chunks straight through under
the comment "commitment chunks (no breaks between them)". **Phase 28's lattice was only ever
applied to the discretionary packing loop.** Reproduced exactly; full analysis and root cause are
in the ROADMAP under **Phase 30: Breaks In Committed Time**.

**Why the 2026-08-21 diagnosis was wrong, specifically.** The probe run that day swept all five
moods and both goal types and found correct 25+5 lattice output every time — and concluded the
generator was clean. It never constructed a **commitment block**. The commitment path was the one
half of the code path not exercised, and it was the broken half. A probe that covers only the
branch you already believe is fine does not license a conclusion about the whole function;
"generator is structurally incapable of producing that layout" was asserted from a sample that
excluded the producing branch. The existing suite's own `makeBlock` fixture (540–600, two chunks)
would have surfaced it immediately.

The cost was one wasted round trip for the owner and a second report of the same symptom three
days later.

**Phase 29 itself is unaffected** — its render work is correct, and the visible "Short break" in
the 08-24 screenshot is that work doing its job. This UAT was held until Phase 30 landed, so that a
full day's worth of breaks existed to look at. **It was judged on 2026-08-25 and passed all three
items** — see the verdicts below.

---

## ATTEMPT 1 — VOID. 2026-08-21. (Diagnosis below superseded — see correction above.)

The first UAT attempt could not be judged, and the reason is worth recording because it will
recur.

The owner opened `http://danserver:8143/`, saw work chunks running back-to-back with no breaks at
all, and reported it via feedback-drop (`~/feedback-drop/canopy/inbox/2026-08-21_13-03-39/`):
*"for work sections there are no 5 minute breaks."* The annotated screenshot circles the gap
between `Work 9:00–9:25` and `Work 9:25–9:50` — contiguous, no break — with the same pattern
continuing at 9:50 / 10:15 / 10:40.

**This was not a defect in Phase 29 or Phase 28.** The current generator is structurally incapable
of producing that layout. Probed directly across all five moods and both goal types
(outcome / time-target), every single output is on the 30-minute lattice:

```
WORK 09:00-09:25 (25m)      <- reported screenshot: 09:00-09:25
  SB 09:25-09:30 (5m)       <- reported screenshot: nothing
WORK 09:30-09:55 (25m)      <- reported screenshot: 09:25-09:50
```

Back-to-back 25s with no break is the **pre-Phase-28** packing. `ScheduleNotifier._loadToday()`
(`schedule_notifier.dart:83`) reads today's schedule from Hive; `generate()` runs only at check-in
with silent-replace. So the browser was showing a day generated before the lattice fix landed and
persisted in IndexedDB ever since. **Resolution: re-check-in (the ⟳ action) to regenerate today.**

**Why the phase's own automated evidence did not catch it, and could not have.** Every screenshot
this phase measured came from a freshly generated day, so the stale-day case never entered the
sample. `measure_hours.py` legitimately printed `UNIFORM` and the sub-compact tier legitimately
rendered — against a day that was not the day the owner was looking at. The build was correct and
the measurement was correct; the *data* was old. This is the third time this project has been
bitten by a stale artifact masquerading as a missing feature (CLAUDE.md traps #1 and #3 are the
other two, both build-layer). **Trap #4, data layer: an already-generated day is never
regenerated on load — a schedule-shape change is invisible until re-check-in.** Any future UAT
that tests generator output must re-check-in first, and say so in its own instructions.

Items 1–3 below are unchanged and still pending; attempt 2 begins after a re-check-in.

**Also raised in the same drop, and routed out of this phase:** *"Breaks are fully functional
features, with timers, etc."* — followed by the scope call *"don't add tappable then. Just make it
skippable like the other ones."* This is a genuine gap (breaks are excluded from swipe-to-skip by
an explicit early return at `swipeable_chunk_card.dart:75`) but it is an *interactivity*
requirement, not a visibility one, and it applies to every break tier rather than only the
sub-compact one. Opened as **Phase 30 — Breaks You Can Skip** rather than widened into this phase.

---

## ✅ UNBLOCKED 2026-08-24 — Phase 30 has landed. Judge this now.

Phase 30 shipped the same day: `buildCommitmentChunks` now applies the 25+5 lattice inside
commitment windows, and `addEventToday` was found duplicating the same defect and fixed too.
598/598 tests green. **A full day now has breaks in it**, so items 1–3 below are real questions with
something to look at.

Both this phase's UAT and Phase 30's are served by the **same build** on `http://danserver:8143/`
(the debug bundle contains both phases' work — verified in the served bytes). Judge them in one
sitting: Phase 30's `30-UAT.md` asks whether the breaks are *there*; this file asks whether the
5-minute one *reads as a break*. **⟳ Re-check-in first** — trap #4, now in CLAUDE.md.

## Item 1 — Does a 5-minute break read as a break?

Scroll through the morning. Between two work cards there should be a thin line with "Short break"
sitting on it. The question is not "can I find it" — it is: glancing at the day, does that row say
*break*, or does it read as a divider, a separator, or the edge of the card above it? If it reads
as a divider, say so plainly; that is the exact complaint that opened this phase and a near-miss is
a fail here.

**Verdict:** PASS — 2026-08-25. Owner confirmed a 5-minute break reads as a *break* at a glance,
not as a divider, a separator, or the edge of the card above. This is the exact complaint that
opened the phase ("there's no 5 minute breaks in between"), and it is now answered against a day
that genuinely has breaks in it — which only became possible once Phase 30 landed. A near-miss
would have been a fail here; the owner did not hesitate.

## Item 2 — Is the label actually legible at this size?

Look at the words themselves, not the layout. Is "Short break" cut off at the top or bottom,
crowded by the cards above and below, or too faint against the background? Try it once at a larger
system text scale. If the text is fine but feels weak, say which: too small, too pale, or too
tight.

**Verdict:** PASS — 2026-08-25. Owner confirmed the "Short break" label is clearly readable — not
clipped top or bottom, not crowded by the neighbouring cards, not too faint. The sub-compact tier's
ink fits its 20dp slot in a real browser, which is what `kSubCompactBreakMinHeight = 32.0` was
measured for. Note the harness caveat this vindicates: `flutter test`'s placeholder font could not
have settled this either way.

## Item 3 — Does the day still look right around it?

Scroll a full day. Hour brackets should all look the same height. Nothing should overlap, no card
should be clipped mid-glyph, and a 30-minute long break should still look clearly heavier than a
5-minute one. If a long break and a short break ever sit next to each other, they should not read
as the same thing.

**Verdict:** PASS — 2026-08-25. Owner confirmed the day still looks right: hour brackets even
(GRID-01 intact), nothing overlapping or clipped mid-glyph, and a 30-minute long break still reads
as clearly heavier than a 5-minute one. The two break tiers do not read as the same thing.

---

Worth a glance while you are there: what a 5-minute break looks like while it is the *current*
activity (the live row has its own separate treatment from Phase 27 and is deliberately not
changed by this phase) — if the two now disagree in a way that looks wrong, that is worth
recording even though it is out of scope.

## Remedies if item 1 fails

In order: raise the label's contrast or weight within the existing `onSurfaceVariant`/`bodySmall`
contract, or revisit the sub-compact layout. **Off the table:** raising `kPixelsPerMinute` (D-03,
rejected on evidence) and letting the card exceed its slot (D-05). Any failure routes to a
gap-closure plan, not a fix inside this checkpoint.
