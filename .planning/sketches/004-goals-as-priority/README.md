---
sketch: 004
name: goals-as-priority
question: "How does the Goals screen say it IS the priority order — and how should priority read on a card when identity colour is the loudest signal?"
winner: "D (synthesis: A rank + C ribbon, ribbon reassigned to progress)"
tags: [goals, priority, legibility, phase-33]
---

# Sketch 004: The Goals screen as a priority view

## Outcome — ★ Variant D, a synthesis built during review (Dan, 2026-09-01)

**Neither A nor C survived alone; D is what the review produced.** Dan picked C first, then
immediately amended: *"i think i want rank + ribbons. showing what's complete can help you re rank
(maybe)."* Rank and ribbon do different jobs — **rank says the order, the line says the magnitude**
— and 3rd vs 4th could be 0.62 and 0.60 (a hair) or 0.62 and 0.21 (a chasm), which rank alone
cannot express.

**Then the line changed meaning.** Shown rank + priority-ribbon + a horizontal progress bar, the
verdict was *"shouldn't double up on progress. just the line on the left going up and down. and
color coded."* Two bars on one card read as two progress meters whatever they encode. So the
horizontal bar was deleted and **the left line was reassigned from priority to progress** — priority
is now carried by the rank number alone, which is sufficient because rank IS the priority order.

**The colour rule, verbatim:** *"red when just started, yellow when below 70%, 70% and above
green."* Implemented as three discrete bands — **red < 20%, yellow 20–69%, green ≥ 70%** — with the
band edges recorded here rather than on screen.

**No key, and that is the point.** Red/yellow/green is the one colour scale that does not need a
legend, which is why it can carry meaning with no text beside it. An earlier draft had a four-swatch
legend; it was cut on sight.

**What the progress line buys, and it is the reason the amendment was right:** on the fixture,
**rank 6 (Admin) is green at 100% while rank 1 (Deep work) is yellow at 63%.** The least important
goal is finished and the most important is not. That is a re-rank prompt that no ordering of the
list can produce on its own.

### Text policy, settled over two rounds

*"kill all the text and the key blah blah"* → then, after a draft that turned the type and energy
chips into bare glyphs, *"ok - cut too much text. glyphs + text description is fine. just no text
instructions."*

**The line: instructions go, labels stay.**

- **Cut:** the legend, the heading's explanatory sub-line, the per-card progress readout
  ("6.3 of 10.0 hrs this week"), and the quick-add helper *"Enter after each, or paste a list —
  refine details later"*.
- **Kept:** the `Priority order` heading (two words — and it is the whole of OBVIOUS-02, "the Goals
  screen states its own purpose"), the `Add a goal` placeholder, and the chips as **glyph + word**
  (`◷ Regular time`, `⚡ Gives`).

**The glyph-only draft was a real defect, caught by showing it.** Reducing `⚡ Gives` to a bare `⚡`
recreated the exact fault this phase exists to remove — a mark that means something next to nothing
that says what — on a second screen. It also fails on a phone, where there is no hover to reveal a
tooltip. Reverted the same round.

### Grouping: one list

Ranks run 1–6 unbroken with type as a chip. Under type sections the ranks are still global and
therefore jump (1, 3, 6 down the first section), which reads as an error rather than as information.

### Outcome goals are grey, not red

`Ship the redesign` and `Tax return` have **no progress field anywhere in the model** — only
`deadline` and `outcomeDescription`. Red would assert "you have barely started", which the data
cannot support; an empty grey track asserts nothing, which is true. Inventing a percentage would be
new state and out of scope.

### One accepted risk, recorded rather than argued

With the key removed, red/yellow/green carries its meaning alone and there is no text fallback.
That is fine for a universally-known scale on a single-user app, and it is the owner's explicit
call — noted here so a future reader knows it was a decision, not an oversight.


## Design Question

Two of Phase 33's items are the same screen, so they are one sketch.

**The screen doesn't say what it is.** Dan: *"I don't know about this goals page."* It is titled
"Goals", carries the heading "Your goals" and the hint *"Drag to prioritize. Tap to edit."* in 12px
grey, then three type sections. Dragging **is** the priority model — `onReorderItem` calls
`reorderAllWithPriority()` — and the screen says so in four words, once, quietly.

**Colour doesn't carry priority.** Dan: *"the colors are changing, it's not making a ton of
sense."* The loudest thing on a goal card is a 5dp left border in the goal's own identity colour
(`goal.color`, falling back to `colorScheme.primary`), repeated in the type icon and again in a 16dp
swatch — three instances of a colour that means nothing but "this goal." Priority itself only
appears as a chip at the extremes: `pw >= 0.75` → High, `pw <= 0.25` → Low. **In the fixture on
screen, two of six goals fall in that dead zone and show nothing about their own priority at all.**

**This is legibility only.** PRIORITY-02/03 reconciled the drag-continuous and form-discrete models
in v1.3 and that reconciliation is not on the table. All four tabs describe the *same* underlying
weights — they are four ways of saying it out loud.

## How to View

    http://danserver:8103/004-goals-as-priority/index.html

Or locally: `open .planning/sketches/004-goals-as-priority/index.html`

## Variants

- **A: Ranked** — the type sections go. One list, numbered 1–6, ordered by priority across every
  type, which is what `reorderAllWithPriority()` already writes. The heading names the page:
  *Priority order*. Type demotes to a chip.
- **B: Tiers** — three named bands (High / Normal / Low) replace the type sections, and dragging
  across a band boundary is what changes priority. No goal is ever unlabelled, so the dead zone
  disappears.
- **C: Ribbon** — smallest change, and the path of least resistance in Flutter. Type sections stay
  exactly as they are; the 5dp left border stops being identity colour and becomes a priority
  ribbon that fills in proportion to `priorityWeight`. Identity colour survives as the dot beside
  the name.
- **As shipped** — the reference column.

## What to Look For

1. **A's number is a verdict.** It is the only variant that makes priority unambiguous, and the
   only one that tells you something is *sixth*. Six goals is a small enough list that a rank might
   read as a leaderboard you are losing. Worth feeling before deciding.
2. **What you give up in A and B: the type grouping.** Both drop "all my Regular time goals
   together" in favour of a priority-first order. C keeps it. If the type sections are doing work
   for you, that is a reason to prefer C that no amount of priority legibility outweighs.
3. **C is the direct answer to the actual complaint.** After it, colour means exactly one thing.
   The open risk is legibility: judge whether a 6dp partially-filled bar reads at a glance, or
   whether it needs the words as well — compare Guitar (0.62) against Tax return (0.35) and see if
   you can tell them apart without counting pixels.
4. **The heading copy, in all four.** Each variant rewrites it, and the rewrite may be doing more
   work than the layout. If one heading fixes "I don't know about this goals page" on its own, that
   is worth knowing — it would make this a copy change, not a layout change.
5. **Mood 1 and mood 5.** Priority is drawn in `primary` / `primaryContainer` in every variant, and
   those move with the seed. Mood 5's yellow is the stress case for C's ribbon.

**A flaw in C, found while looking at it rather than while writing it.** The ribbon is a
*percentage of its own card*, and cards are not all the same height — a goal with a stat line and
two chips is visibly taller than a bare one. So a 90% ribbon on a short card can be fewer actual
pixels of green than a 62% ribbon on a tall one, and the eye compares pixels, not percentages. In
the fixture on screen the ordering happens to survive; it is not guaranteed to. If C wins, it needs
a fixed-height track rather than a proportional one — worth knowing before it becomes a build.

## Grounding — what is real here and what is not

**Real:** the goal set is a plausible six with real `priorityWeight` values, and every variant sorts
by those same weights. The three goal types and their display order (timeTarget → outcome → habit)
match `_buildFullOrderedIds`. The shipped tab's chip rule is the shipped rule, including its dead
zone. The quick-add field, the ⋮ menu and the extended FAB are all really there.

**Not real:** drag is not wired — the grip toasts instead. Flutter's Roboto metrics. The exact
`ColorScheme.fromSeed` output (the theme tokens approximate it).
