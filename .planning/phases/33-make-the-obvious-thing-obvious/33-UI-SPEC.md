# Phase 33: Make The Obvious Thing Obvious — UI Design Contract

**Written:** 2026-09-01
**Source:** transcribed from sketches 003, 004, 005 after the owner's verdicts — **not** derived by a
UI researcher. Every decision below was made by looking at a served mockup, not by reasoning in
prose.

> **Why this file is a transcription and not an analysis.** Phase 32 had a UI-SPEC that was written,
> reviewed, and passed `gsd-ui-checker` **6 of 6** — and still shipped a screen the owner rejected on
> sight, because every constant in it was defended in argument and nobody rendered a whole screen and
> looked at it. This spec therefore claims no authority of its own. Its authority is
> `.planning/sketches/00{3,4,5}-*/README.md`, where each decision is recorded against the mockup that
> produced it. **If this file and a sketch README ever disagree, the sketch README wins.**

---

## Scope

| Item | Screen | File |
|---|---|---|
| 1 | Today timeline — a chunk row's trailing status | `lib/screens/schedule/widgets/chunk_card.dart` |
| 1b | Today timeline — free time treatment | `lib/screens/today/widgets/free_time_row.dart` |
| 2+3 | Goals | `lib/screens/goals/goals_screen.dart`, `lib/screens/goals/widgets/goal_card.dart` |
| 4+5 | Restoratives + goal entry | `lib/screens/restoratives/restoratives_screen.dart`, `lib/screens/goals/goal_form_sheet.dart` |

---

## UI Considerations

Lift rule for the planner: each numbered item below is a **resolved (explicit)** decision → it belongs
in `must_haves.truths` as a plain string. Items marked **(backstop)** are structured flat-scalar
markers. Items marked **(unresolved)** are explicit assumptions to surface, not to silently drop.

### A. The chunk row says its own state — sketch 003, variant B

1. `_buildTrailingStatus()` in `chunk_card.dart` renders a **labelled chip in all three states**:
   `To do` (unresolved), `Done` (completed), `Skipped` (skipped). One vocabulary, three words.
2. **`Icons.radio_button_unchecked` no longer appears anywhere in `chunk_card.dart`.** This is the
   2026-06-12 complaint and the phase's headline requirement.
3. The chip is **display-only** — no `onTap`, no `InkWell`, no `IconButton`, nothing that reads as
   tappable. It is a status mark next to the already-labelled `Complete` / `Skip` buttons.
4. **No second way to complete a chunk is introduced.** `_buildActionRow()`'s `Complete` and `Skip`
   remain the only completion affordances. (Variant C was rejected precisely for adding one.)
5. Chip styling follows the existing container-role convention and **never uses the error slot** —
   `Done` on `primaryContainer`, `To do` on `surfaceContainerHighest` with an `outlineVariant`
   border, `Skipped` transparent with a dashed `outlineVariant` border.
6. **(backstop)** The chip must not push the title into ellipsis at the compact tier. The title keeps
   `Expanded` + `TextOverflow.ellipsis`; the chip is `flex: 0 0 auto`.

### B. Free time is a filled card — sketch 003

7. `FreeTimeRow` renders as a **filled card** matching the break vocabulary: a `surface` fill with a
   1dp `outlineVariant` border and the same 12dp radius, **not** `_DashedRegionPainter`'s outline.
   This restores the Phase 22 match that Phase 32 broke.
8. **Copy is unchanged and must not be reworded** — `Free until 8:30 AM` / `Free · 1h 40m`. Locked by
   the file's own comment and by `sketches/MANIFEST.md`.
9. `_DashedRegionPainter` becomes unused; delete it rather than leaving it dead.

### C. Goals reads as the priority order — sketch 004, variant D

10. Heading is **`Priority order`** — two words, and **no explanatory sub-line beneath it**. This
    heading alone is what satisfies OBVIOUS-02 ("the Goals screen states its own purpose").
11. **One list, not three type sections.** Goals are ordered by `priorityWeight` descending across
    every type, and each card carries a **rank number** (1..N) in a leading gutter. Rank is global
    because `reorderAllWithPriority()` writes one global order.
12. Goal type moves from a section header to a **chip on the card** — `◷ Regular time`,
    `⚑ Working toward`, `↻ Daily habit`.
13. The 5dp left border stops being `goal.color` and becomes a **vertical progress line** filling
    bottom-up in proportion to progress **this week**. Identity colour survives only as the small
    circular swatch beside the name.
14. **Colour bands, verbatim from the owner:** *"red when just started, yellow when below 70%, 70%
    and above green."* Implemented as `< 0.20` red, `0.20–0.699` yellow, `>= 0.70` green.
15. **There is no legend and no key on screen.** Red/yellow/green is a scale that needs no
    explanation; that is why it can carry meaning with no text beside it.
16. **Outcome goals show an empty grey track, never red.** They have no progress field in the model —
    only `deadline` and `outcomeDescription` — so red would assert "barely started", a claim the data
    cannot support.
17. Priority is carried by the **rank number alone**. `_PriorityChip` and its `pw >= 0.75 / <= 0.25`
    dead zone are removed — every goal's position is now unambiguous.
18. **(backstop)** The progress line must be implemented as a fixed-geometry fill, **not** a
    percentage of the card's own height. Card heights vary with chip count, so a proportional fill
    lets a 90% line render shorter than a 62% one. This defect was found in the sketch and must not
    be reintroduced.

### D. Progress is read, never computed anew — sketch 004

19. Weekly progress comes from **`CompletionLog` rows** (`event == completed`, this week, this goal),
    converted with the engine's own arithmetic: `chunks × 25 / 60` hours against
    `weeklyHourBudget`. Habits use `doneDays / frequencyPerWeek`.
20. **`schedule_generator.dart` is not modified.** If the arithmetic needs to be shared, extract a
    pure helper both call — do not reach into the generator and do not duplicate the constant
    silently.
21. **(unresolved)** `_completedChunksThisWeek` is currently private to `ScheduleGeneratorService`.
    Whether the Goals screen reads `CompletionLog` through a repository directly or through a small
    shared helper is the planner's call — but the phase must not end with two independent copies of
    `× 25 / 60`.

### E. Restoratives and the fork — sketch 005, variant B

22. The restoratives screen shows **nine common restoratives as tappable chips**: Walk outside,
    Music, Nap, Stretch, Shower, Read, Tea or coffee, Call someone, Sit in the sun. One tap adds,
    tapping an added chip removes it.
23. The list is **hard-coded**. No suggestion engine, no ranking, no LLM — Canopy is dumb on purpose
    (`CLAUDE.md`).
24. Adding a goal opens a **front-door fork first**, before any form: *Something to make time for*
    (goal) vs *Something that restores you* (restorative). Choosing the second never shows a goal
    form — name + emoji only, saved as a `RestorativeItem`.
25. The fork is **not** an inline nudge inside the goal form and **not** a fourth `EnergyValence`
    option. Both were built and both were rejected for putting the escape hatch somewhere you must
    already be inside a goal to find.
26. `RestorativeItem` (Hive typeId 7) is reused as-is. **No new aggregate, no new Hive type, no
    migration.** This is an entry-point change.
27. Each fork door states its own consequence in one line — the goal door says it gets a type, a
    budget and a priority and will be scheduled; the restorative door says it is never scheduled and
    never counted toward a budget or a streak.

---

## Text policy — settled across two rounds, applies to every screen above

**Instructions go. Labels stay.**

28. **Remove:** legends and keys, explanatory sub-lines under headings, and field helper text —
    specifically `goals_screen.dart`'s `'Enter after each, or paste a list — refine details later'`
    and the `'Drag to prioritize. Tap to edit.'` sub-line.
29. **Keep:** headings that name the screen's purpose (`Priority order`), field placeholders
    (`Add a goal`), and **chips as glyph + word** (`◷ Regular time`, `⚡ Gives`) — never a bare glyph.
30. **A bare glyph is forbidden on these screens.** A draft that reduced `⚡ Gives` to `⚡` was built
    and rejected the same round: it recreates the unlabelled-circle defect on a second screen, and on
    a phone there is no hover to reveal a tooltip. **Item 30 and item 2 are the same rule.**

---

## Deliberately out of scope — do not touch

- `schedule_generator.dart` and the scheduling engine (ROADMAP "must NOT do").
- The priority **model** — PRIORITY-02/03 reconciled it in v1.3. Item 3 is legibility only.
- `kPixelsPerMinute` — 6.0 passed round-two UAT, thumb count 5/5.
- The short break's 64×30dp Skip rail — measured, 5/5, settled (D-32-03).
- Any LLM or "smart" suggestion surface.

---

## Accepted risk, recorded rather than argued

With no key on screen (item 15), red/yellow/green carries its meaning with no text fallback. That is
an explicit owner decision for a single-user app, not an oversight. Recorded here so a future reader
does not "fix" it.
