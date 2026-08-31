---
sketch: 004
name: goals-as-priority
question: "How does the Goals screen say it IS the priority order — and how should priority read on a card when identity colour is the loudest signal?"
winner: null
tags: [goals, priority, legibility, phase-33]
---

# Sketch 004: The Goals screen as a priority view

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
