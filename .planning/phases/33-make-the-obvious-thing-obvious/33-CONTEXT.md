# Phase 33: Make The Obvious Thing Obvious - Context

**Gathered:** 2026-08-31
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped via `workflow.skip_discuss=true`) — the ROADMAP entry is
the spec, and it is unusually specific because it was scoped from a seed-backlog audit rather than
from a fresh idea.

<domain>
## Phase Boundary

**Goal:** Every control on screen says what it does. No unlabelled affordances, no colour that
carries meaning it can't express, no screen whose purpose you have to infer.

**Five items, plus one small one.** All perceptual — this is a legibility phase, not a behaviour
phase.

1. **The unlabelled circle.** `chunk_card.dart:769`, inside `_buildTrailingStatus()`. Every
   *unresolved* work row renders `Icon(Icons.radio_button_unchecked)` in `onSurfaceVariant`. The
   same method renders `Icons.check_circle` when completed and the word `skipped` when skipped —
   so the resolved states say what they are and the unresolved state does not. Owner, verbatim
   (2026-06-12): *"there's a little circle next to it — really unclear UI for a human."* It looks
   tappable and is not; it sits next to a row that already has explicit **Complete** and **Skip**
   buttons in `_buildActionRow()`. Decide what it is: a real control, a status glyph that earns
   its place, or nothing.

2. **The Goals screen doesn't read as a prioritisation view.** `goals_screen.dart`. The page is
   titled "Goals", carries a heading "Your goals" and the hint *"Drag to prioritize. Tap to
   edit."*, then three type sections (Regular time / Working toward / Daily habits), each a
   `ReorderableListView` whose drag writes `priorityWeight` via `reorderAllWithPriority`. So
   dragging IS the priority model, and the screen says so only in a 4-word `bodySmall` hint.
   Owner: *"I don't know about this goals page."*

3. **Priority colour doesn't carry priority.** `goal_card.dart`. `goalColor` is the goal's own
   user-chosen `goal.color` (falling back to `colorScheme.primary`) and it paints three things:
   the 5dp left border, the type icon, and a 16dp circular swatch. Priority is expressed
   *elsewhere* — a `_PriorityChip` that renders only at the extremes (`pw >= 0.75` → "High",
   `pw <= 0.25` → "Low", nothing in between) plus the row's drag position. So the loudest visual
   signal on the card is identity colour, and the user reads it as meaning. Owner: *"the colors
   are changing, it's not making a ton of sense."* **Legibility only — PRIORITY-02/03 already
   reconciled the drag-continuous and form-discrete models in v1.3. Do not re-open the model.**

4. **Quick-pick common restoratives.** `restoratives_screen.dart`. Adding one today means: FAB →
   `AlertDialog` → type a name → optionally type an emoji → Add. The Goals screen already has the
   frictionless counterpart (`QuickAddField`: type, Enter, keep going). Offer ~9 tappable common
   restoratives so the common case is a tap, not typing. Raised 2026-07-02 on the live build.

5. **Energizing ≠ a goal — the guitar friction.** Declaring something energy-giving is only
   reachable from inside a *goal*: the `EnergyValence.gives` control lives in
   `goal_form_sheet.dart:277` and `onboarding_screen.dart:395`. So "guitar energizes me" forces
   guitar to become a goal with a type, a budget and a priority. `RestorativeItem` (Hive typeId 7)
   already exists for exactly this and is deliberately never scheduled and never counted toward
   budgets or streaks. **This is an entry-point fix, not a new aggregate** — give an explicit
   choice at the moment of entry.

**Also in scope, small:** free time renders as a dashed outline (`free_time_row.dart`,
`_DashedRegionPainter`) while breaks are now filled cards. Phase 22 deliberately made them match;
Phase 32 pulled them apart, and the divergence is more visible at 6.0 px/min. Left open at the end
of Phase 32 rather than ruled on — rule on it here.

</domain>

<decisions>
## Implementation Decisions

### Locked by the ROADMAP — these are constraints, not preferences

**What this phase must NOT do:**

- **Do not re-open the priority model.** Item 3 is legibility. `schedule_generator.dart` is not
  touched by this phase at all.
- **Do not lower `kPixelsPerMinute`.** 6.0 passed round-two UAT and the thumb count came back 5/5.
- **Do not re-litigate the short break's 64×30dp Skip rail.** Measured, 5/5, settled.
- **Do not add an LLM or any "smart" suggestion.** See CLAUDE.md — Canopy is dumb on purpose. The
  ~9 common restoratives in item 4 are a hard-coded list, not a suggestion engine.

### Method — non-negotiable and earned, not stylistic preference

**Sketch before building.** Every item here is perceptual, which is the exact class this project's
green suites have missed five times (Phases 27, 29, 31, and 32 twice). Phase 32 HAD a UI-SPEC:
written, reviewed, passed a checker 6/6 — and still shipped a screen the owner rejected on sight,
because every constant in it was defended in prose and nobody rendered a whole screen and looked at
it. Use `/gsd-sketch`, serve the variants on the tailnet, and have the owner pick.
`sketches/002-timeline-at-6/` is the worked example; `sketches/MANIFEST.md` carries the locked
visual decisions this phase inherits and must not contradict.

**Never an Artifact.** Global CLAUDE.md: host sketches locally over the tailnet
(`python3 tools/serve-uat.py <port> --dir <dir>` or `python3 -m http.server`), hand over a
`http://danserver:<port>` URL. Do not call the Artifact tool.

**Look at the running app before claiming anything works.** Phase 32's gap closure was half-wrong
until a screenshot showed the live row still sitting in a hole that code review had missed twice.
Driver: `.planning/spikes/001-live-row-in-a-true-grid/tools/drive.cjs` — onboards a persistent
Chromium profile, parks at a simulated clock time (`--at=HH:MM`), and dumps the semantics tree
(`--dump`). "Needs a human" is a claim about the *kind* of question: perceptual and touch judgments
need a thumb, but "is the control present / is it labelled / what does the semantics tree say" is a
question a browser answers, and routing those to a human is how G-32-05 produced three
non-answers in a row.

### Gate shape — deliberate, and the reason is recorded

**Exactly ONE human UAT gate, on port 8143**, at the end. Four items would otherwise mean four
builds to judge; Phase 32 alone took four rounds. Bundling them behind one gate is the point of
this phase's shape. Kill whatever is squatting 8143 first. Serve the **debug** build per CLAUDE.md
(`flutter build web --debug --source-maps --pwa-strategy=none`, then `tools/serve-uat.py`).

The sketch pick is a *decision* gate, not a UAT gate — it is the one other place the owner is
asked for input, and it happens before any code is written.

**Trap #4 (stale Hive data): ⟳ Re-check-in is NOT required for this UAT**, and the reason is
stated rather than copied. Trap #4 binds any UAT that judges *scheduling-engine output*. Nothing in
this phase touches `schedule_generator.dart`; every item is rendering, an entry form, or a list
screen, and a previously-generated day renders through the new code on load. **If the plan comes to
touch the generator, the rule returns and Step 0 becomes mandatory.**

### Claude's discretion

Within those constraints, implementation choices — exact widgets, copy, the specific 9
restoratives, whether the circle becomes a control or disappears — are Claude's, informed by the
sketch verdict and existing codebase conventions.

</decisions>

<code_context>
## Existing Code Insights

**Item 1 — `lib/screens/schedule/widgets/chunk_card.dart` (927 lines).**
`_buildTrailingStatus(ThemeData)` around line 757 is the whole surface: a three-way ternary
(completed → `Icons.check_circle` in `primary`; skipped → the word `skipped` in `bodySmall`;
otherwise → `Icons.radio_button_unchecked` in `onSurfaceVariant`). It is called from the compact
title row (resolved chunks only) and from the taller tiers. `_buildActionRow()` immediately below
already provides labelled `Complete` (FilledButton.icon) and `Skip` (OutlinedButton.icon, error
foreground) buttons, both wrapped in `Tooltip`. Whatever replaces the circle must not add a third
competing way to complete a chunk.

**Item 2 — `lib/screens/goals/goals_screen.dart` (358 lines).** Structure is a `CustomScrollView`
under a 720dp `ConstrainedBox`: `QuickAddField` → (empty state | heading + three
`_buildReorderableSection` groups) → extended FAB "Add goal". The heading sliver is tagged
GOALS-01 and is where purpose lives today. Drag handles are `Icons.drag_indicator` — note Phase 31
learned the hard way that this glyph means *reorder*, which here is actually correct (it does
reorder), but reordering IS re-prioritising and the screen barely says so. `onReorderItem` calls
`notifier.reorderAllWithPriority(allOrdered)` across all three type groups via
`_buildFullOrderedIds` — order is timeTarget → outcome → habit and must stay that way (Pitfall 2).

**Item 3 — `lib/screens/goals/widgets/goal_card.dart`.** `_PriorityChip` and `_ValenceBadge` are
file-private, display-only, and already use container colour roles correctly (`primaryContainer` /
`surfaceContainerHighest` for priority; `tertiaryContainer` / `secondaryContainer` for valence —
never the error slot). The chip's dead zone is the problem: `showPriorityChip = pw >= 0.75 || pw <=
0.25`, so the majority of goals show nothing at all where priority should be. `hexToColor` comes
from `utils/time_format.dart`.

**Item 4 — `lib/screens/restoratives/restoratives_screen.dart` (308 lines).**
`RestorativesNotifier.saveItem` / `deleteItem` / `loadItems`; there is already a bulk-ish helper
that constructs `RestorativeItem(name: name, sortOrder: nextSort++)` in the notifier (~line 54),
which is the natural hook for a multi-select quick-pick. `_RestorativeRow` mirrors the commitments
row (hover icons on desktop, always-visible delete on mobile). Default emoji when none is set is
`🌿`. `QuickAddField` (`lib/widgets/quick_add_field.dart`) is the existing frictionless-entry
widget used by Goals and is the obvious analog to reuse.

**Item 5 — entry points.** `goal_form_sheet.dart:277` and `onboarding_screen.dart:395` are the only
two places `EnergyValence.gives` can be set, and both are inside goal creation.
`lib/data/models/restorative_item.dart` documents the intended split in its class doc: *"a goal
that also restores stays a goal; a pure restorative (e.g. 'listen to music') lives here instead."*
The model is right; the UI never offers the fork. Restoratives are reachable today only via Goals →
overflow menu → "What restores you" (`goals_screen.dart:75-77`, route `/restoratives`) — which is
itself part of why the fork is invisible.

**Small item — `lib/screens/today/widgets/free_time_row.dart`.** `_DashedRegionPainter` is
file-private and its doc says it visually matches `_DashedBorderPainter` in `chunk_card.dart` (same
dash geometry). Label copy is locked: `'Free until ${formatMinutes(...)}'` and
`'Free · ${formatDurationShort(...)}'` — **do not reword**, per the file's own comment and
`sketches/MANIFEST.md` ("Free time is named"). Only the *treatment* is open. `today_screen.dart:712`
carries NOW-02: "Free until \<time\>" is only truthful while that time is still ahead.

**Infrastructure.** `.planning/spikes/001-live-row-in-a-true-grid/tools/drive.cjs` is the live
driver. `tools/serve-uat.py` is the no-store static server (trap #3). Tests live in `test/`; the
suite was 621/621 green at the end of Phase 32. Node is nvm-only — non-login shells need
`export PATH="$HOME/.nvm/versions/node/v24.16.0/bin:$PATH"`; Flutter is at
`/home/dan/development/flutter/bin`.

</code_context>

<specifics>
## Specific Ideas

**Start with the circle.** The owner named it as the single most embarrassing item and asked for it
first, explicitly: it has been on screen since he complained on 2026-06-12, is visible in
`phases/32-breaks-you-can-tap/shots/after-gap-closure.png`, and survived 2.5 months **not because
it is hard but because no phase ever aimed at it**. Do not let it slip again.

**Carried-forward open questions from Phase 32** — none blocking, but do not treat silence as
consent, and prefer resolving them in the sketch rather than in code:

- whether the break rail reads as one button or two zones;
- whether the filled work card reads calm or hollow;
- whether a break now reads too much like work, sharing the work chunk's Skip;
- the "Up next" transition (`now_state.dart:176`), unruled since Phase 31.

**Requirements this phase must satisfy:**

- **OBVIOUS-01** — no unlabelled affordance on a chunk row.
- **OBVIOUS-02** — the Goals screen states its own purpose and its priority language is legible.
- **OBVIOUS-03** — adding a restorative is tappable, and declaring something energizing does not
  force it to be a goal.

**Depends on:** Phase 32, which owns the row geometry and the break vocabulary this phase must not
disturb.

</specifics>

<deferred>
## Deferred Ideas

- **Overnight / midnight-crossing commitments** — deliberately out of scope project-wide; do not
  slip it in as a bugfix.
- **The Phase 32 LOW review finding** (`live_row_card.dart:395-401`: `BreakSkippedIndicator` is
  unreachable because the call site passes `showActions: isBreak ? !chunk.isSkipped : true`). It
  was left unfixed only because Phase 32's UAT gate was open and changing served bytes would have
  invalidated the pre-flight. That gate is now closed, so this is a cheap cleanup — take it if a
  plan already touches the file, but it is not a Phase 33 requirement and must not grow the diff on
  its own.
- **Phase 32 has no `32-VERIFICATION.md`** — its verdict lives in `32-UAT-R2.md`, which is why
  `gsd-tools` reports `verification_status: missing` for it. Bookkeeping, not work; not this
  phase's job.

</deferred>
