# Phase 32 — Human UAT, round two (after the visual gap closure)

**Build:** `http://danserver:8143/` — rebuilt and re-served 2026-08-28.

**The item order is deliberate and is itself a fix.** Items 1 and 2 are the two questions that
have now gone unanswered across *three* rounds — not because they failed, but because they sat
behind items that failed first and the round ended before reaching them (`32-UAT.md` gaps G-32-03,
G-32-05). They are above the visual items now. **If you only have two minutes, do Items 1 and 2
and stop** — the visual work is the part I could already check myself, and did.

---

## Step 0 — **NOT required this round, and here is why rather than a boilerplate skip**

`CLAUDE.md` trap #4 makes ⟳ Re-check-in mandatory for any UAT that judges **scheduling-engine
output**, because an already-generated day is never regenerated on load. **This round changes no
engine code.** The diff is `chunk_card.dart`, `live_row_card.dart`, and one geometry constant —
all rendering. Your existing day's chunks and durations are unchanged; they are simply drawn by
the new code on load.

So: judge whatever day you already have. If you *want* a fresh one, ⟳ Re-check-in does no harm —
it is just not load-bearing this time. **If a future round touches the generator again, the rule
comes straight back.**

---

## Item 1 — the thumb count. Five short-break skips. (G-32-03)

**This is the project's central touch question and it has never actually been measured.** Round
one superseded it, round two never reached it, round three came back *"it does appear to be
working"* — which speaks to the mechanism firing, not to whether you can hit it. Nothing has ever
counted.

Nothing about the short break's Skip rail changed this round — still 64dp wide × 30dp tall on the
right edge of a 5-minute break. **That is the point: it is unmeasured, not unchanged-and-passing.**

- Skip **five** short breaks with a thumb, at a natural grip, not aiming carefully.
- **How many landed first time?** _____ / 5
- Did you ever hit the work block above or below instead? _______________
- Does the rail read as **one button**, or as two zones (an icon zone and a word zone)? Answer in
  your own words: _______________

---

## Item 2 — a break that is running right now (D-31-07, never judged by a human)

**Code-complete and test-proven since 2026-08-26; confirmed by a person zero times in three
rounds.** It keeps getting skipped because it is behind the failing items, which is why it is
second now.

Route to a live break: **Settings** → time-travel ("Set a specific time", or `+5m`/`+15m`) → set
the clock inside a break's window → back to **Today**. Stay inside the same calendar day. **Reset
to real time** when done.

- **(a)** On a running **30-minute** break: is there a Skip and no Complete, and does tapping it
  work? _______________
- **(b)** On a running **5-minute** break: is there a Skip rail at all? (Before this phase a live
  5-minute break had no button of any kind.) _______________
- **(c)** When you skip a running break, does the row stay put — same height, same position — and
  does the red now-line stay where it is rather than jumping? _______________

---

## Item 3 — the gaps (G-32-01)

**What changed.** Every row is now sized by its duration and its content adapts to the height it
gets. Concretely: a 25-minute work card fills its full 150dp slot, earns a goal/duration line
under the title, and puts Complete/Skip on its bottom edge. The live row does the same with its
content centred. Before, both laid out at their natural height and left ~67dp of dead background
underneath.

- Are the "huge gaps" gone? _______________
- The work card is now tall and mostly filled. Does it read as **calm**, or as **hollow** — a big
  card with air in the middle? (This is the exact trade-off that made variant A lose to variant C
  in the sketch; if it still reads hollow to you on a real screen, that is a real finding and the
  sketch's judgment was wrong.) _______________
- Does the day still read as *your day* at this scale, or is it now too big a scroll?
  _______________

---

## Item 4 — the long break's Skip (G-32-02)

**What changed.** *"The long break has too big of a skip"* — it was a 64dp-wide red rail running
the full 180dp height of the row. It is now the **same outlined "▶| Skip" button a work chunk
uses**, centred under the break's title. One vocabulary instead of two.

- Does the long break read right now? _______________
- Using the same button as a work chunk — does that read as consistent, or does a break now look
  too much like work? _______________

---

## Two things I checked myself, so you don't have to

Stated so you know what is already covered and can spend your attention on Items 1–2:

1. **I rebuilt and looked at the running app twice.** The first pass is what caught the live row
   still sitting in a hole after the work cards were fixed — `LiveRowCard._buildCompact` had the
   identical defect and reading the code had not revealed it. Screenshot:
   `shots/after-gap-closure.png`.
2. **The new "not a slab" test was proven able to fail** before being trusted: restoring the old
   stretch geometry makes it report a 142dp Skip inside a 150dp card against a 75dp bound. It is
   not a test that would go green either way.

**What I could NOT check, and no automation can:** everything in Items 1 and 2. A synthetic tap at
an exact coordinate cannot tell a hittable target from an unhittable one.

---

## Still open, deliberately not re-asked

- **The "Up next" transition** (`now_state.dart:176` delists a skipped live break, so the header
  moves on while the now-line stays). Pre-existing, unruled since Phase 31. Answer it under Item 2
  if you form an opinion; otherwise it stays open rather than being read as settled.
- **Free time vs breaks** still look different (dashed outline vs filled card). Untouched this
  round.

---

## Resume signal

**"approved"** if Items 1–4 all pass. Otherwise, per item — and **Item 1 needs its number even if
everything else passes**, because a fourth round of "it seems to work" leaves it unmeasured for a
fourth time.

## Summary

```
total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0
```
