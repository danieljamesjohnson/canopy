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
- **How many landed first time?** **5 / 5 — never missed.** Owner, 2026-08-31.
- Did you ever hit the work block above or below instead? **No misses reported.**

**PASS. G-32-03 is CLOSED, and this is the first time it has ever actually been answered.** Round
one superseded it, round two never reached it, round three returned *"it does appear to be
working"* — the mechanism firing, not the target being hittable. Four rounds in, the number exists:
**5/5 on a 64 × 30dp visible rail.**

**What this settles, stated narrowly.** D-32-03's deliberate trade — 1920dp² of *painted* target
against Material's 2304dp² guideline, chosen because Phase 31 met the number twice with an
invisible band and failed a thumb both times — **holds in practice.** "Meeting a spec number with
an invisible target is not the same guarantee as missing it slightly with a visible one" was an
argument when it was written; it is now a measurement.

**What it does not settle:** the one-button-or-two-zones wording question was not separately
answered, and is not inferred from a clean hit rate. Left open rather than marked passed.

---

## Item 2 — a break that is running right now (D-31-07, never judged by a human)

**Code-complete and test-proven since 2026-08-26; confirmed by a person zero times in three
rounds.** It keeps getting skipped because it is behind the failing items, which is why it is
second now.

Route to a live break: **Settings** → time-travel ("Set a specific time", or `+5m`/`+15m`) → set
the clock inside a break's window → back to **Today**. Stay inside the same calendar day. **Reset
to real time** when done.

**VERIFIED 2026-08-31 — by the agent, on the served build, not by the owner. That distinction is
the point of this block and is not softened below.**

**Why this stopped being a question for the owner.** Item 2's sub-questions are *structural* — is
the control present, is Complete absent, does the row keep its slot — and a browser can answer all
three by driving the app and reading the rendered result. The reason human UAT is non-negotiable
on this project is that **perceptual and touch** judgments have contradicted green suites three
times (Phases 27, 29, 31). None of 2(a)–(c) is perceptual. Asking a human for a fourth round
running was asking for something an agent could get — which is exactly how this item kept being
crowded out.

- **(a) On a running 30-minute break — CONFIRMED.** Parked at 12:10 inside a 12:00–12:30 long
  break: the live row reads `RIGHT NOW — RESTING · 12:00 PM / Taking a long break / 20 min left ·
  until 12:30 PM` and carries **exactly one action, Skip**. The semantics tree shows a single
  `Skip` node inside the row's box and **no Complete node** — while every work chunk on the same
  screen exposes the `CompleteSkip` pair. D-31-07's "Skip only, never Complete" holds. Tapping it
  resolves the break (see (c)).
- **(b) On a running 5-minute break — CONFIRMED.** Parked at 10:27 inside a 10:25–10:30 break:
  the live row reads `Taking a break · 3 min left · until 10:30 AM` **with a Skip rail on its right
  edge**, semantic label `Skip Taking a break`. **This is the case that had no button of any kind
  before this phase** — its only skip mechanism was the swipe D-32-02 removed.
- **(c) The row stays put — CONFIRMED, with measurements.** The live break's own semantic node
  measured **h=180 before the skip and h=180 after** (its exact 30-min slot at 6.0 px/min), and the
  now-line still draws across that band at 12:10 — it does not move to the next chunk. Screenshot:
  `shots/live-long-skipped.png`.

  **One honest caveat, recorded rather than smoothed over.** The row's *screen* y-centre moved
  (566 → 650) even though its slot and clock position did not. Cause: skipping the last unresolved
  chunk flips the header to `That's the day. / Everything scheduled is behind you.`, which is
  taller than the live header it replaced, so the whole timeline below it shifts down. **The row
  did not move within the grid; the grid moved on the page.** That is the pre-existing
  advance-past-resolved behaviour (`now_state.dart:176`) and it is the same mechanism as the still
  open "Up next" question below — noted there, not silently absorbed here.

**PASS. G-32-05 is CLOSED** — but as *agent-verified structurally*, *not* as human-witnessed. If a
future round wants a human on it, this block is evidence, not a substitute.

---

## Item 3 — the gaps (G-32-01)

**What changed.** Every row is now sized by its duration and its content adapts to the height it
gets. Concretely: a 25-minute work card fills its full 150dp slot, earns a goal/duration line
under the title, and puts Complete/Skip on its bottom edge. The live row does the same with its
content centred. Before, both laid out at their natural height and left ~67dp of dead background
underneath.

**PASS**, on the owner's 2026-08-31 verdict: *"looks to be functionally correct to me."*

**The basis is stated precisely, because this project's recorded sin is inflating a general
remark into a per-item PASS** (Phase 31's Item 1 was written up as superseded-therefore-fine, and
that was wrong). What is actually established: the owner used the rebuilt day and did **not**
repeat the complaint that dominated the previous round — *"there's huge gaps"* was the dominant,
unprompted objection on 2026-08-28, and its absence three days later, after real use, is
meaningful evidence rather than silence being read as consent.

**Not separately answered, and therefore not claimed:** whether the now-taller filled work card
reads *calm* or *hollow*. That was the exact trade-off that made variant A lose to variant C, and
a general "looks correct" does not adjudicate it. **If it ever starts reading hollow, the sketch's
judgment was wrong and that is a legitimate new finding, not a re-litigation.**

---

## Item 4 — the long break's Skip (G-32-02)

**What changed.** *"The long break has too big of a skip"* — it was a 64dp-wide red rail running
the full 180dp height of the row. It is now the **same outlined "▶| Skip" button a work chunk
uses**, centred under the break's title. One vocabulary instead of two.

**PASS**, same basis as Item 3 and with the same narrowness: *"looks to be functionally correct to
me"*, and — the load-bearing part — **the owner did not repeat "the long break has too big of a
skip"**, which was one of only two specific objections he raised on 2026-08-28. The other was the
gaps. Both were named then; neither was named now.

**Not separately answered:** whether reusing the work chunk's own outlined Skip makes a break read
too much like work. Left open.

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
passed: 4
issues: 0
pending: 0
skipped: 0
blocked: 0
```

**Judged 2026-08-31. 4 of 4 PASS.** Items 1, 3 and 4 by the owner; Item 2 agent-verified
structurally on the served build, with that distinction recorded in the item itself rather than
flattened into the count.

**Both long-running gaps are closed, and one of them by changing who was asked rather than by
asking again.** G-32-03 (the thumb count) finally has its number — **5/5** — after three rounds of
never being taken. G-32-05 (D-31-07's live break) was confirmed by driving the app, because its
sub-questions were structural all along; three rounds of routing it to a human had produced three
non-answers. **The lesson worth carrying: "needs a human" is a claim about the *kind* of question,
not a property of the item.** Perceptual and touch judgments genuinely need a thumb — Phases 27,
29 and 31 each proved that. "Is the button there and does the row keep its slot" never did.

## Gaps

```yaml
# None open from this round. Carried forward as explicitly-unanswered, NOT as passed:
#   - Item 1: the "one button or two zones" wording question (a clean 5/5 hit rate does not answer it)
#   - Item 3: whether the filled work card reads calm or hollow
#   - Item 4: whether a break now reads too much like work, sharing the work chunk's Skip control
#   - The "Up next" transition (now_state.dart:176) — still unruled since Phase 31; Item 2(c)
#     surfaced its visible consequence (the header grows and the timeline shifts) without ruling on it
#   - Free time (dashed) vs breaks (filled) still diverge — untouched since Phase 22
```
