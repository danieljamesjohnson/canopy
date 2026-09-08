# Phase 34: Adding a Goal Feels Like Onboarding - Context

**Gathered:** 2026-09-08
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped via workflow.skip_discuss) — but the one decision discuss
existed to take was already taken by the owner on 2026-09-08. See below.

<domain>
## Phase Boundary

Adding a goal from the Goals screen offers the same guided start onboarding does — a set of
pre-chosen options you can tap, plus a frictionless way to type your own.

The owner's words: *"i want when you press the button for it to be the same flow as onboarding.
with the pre chosen options plus an easy way for you to add your own."*

**In scope:** the goal door of the add-goal fork on the Goals screen; the shared preset-chip widget
extracted from onboarding's `_ChipCloud` and the restoratives screen's `_QuickPickSection`;
`kCommonGoals` as `(name, emoji)` pairs; the created-goal row showing its budget.

**Out of scope, and each of these is a prohibition with a reason:**

- **No bare quick-add field on the Goals screen.** That control was deleted on 2026-09-08 (commit
  `1587fff`) for creating goals with an unchosen 3.0 hrs/week budget. "Add your own" lives *inside*
  the guided flow, past the fork.
- **No second add-goal entry point.** `goals_add_fork_test.dart` asserts there is exactly one and it
  is at the top. That assertion is load-bearing.
- **No `schedule_generator.dart`.** Nothing here needs the engine.
- **No LLM, no "smart" suggestions.** The presets are a hard-coded list. See CLAUDE.md — Canopy is a
  dumb app on purpose.

</domain>

<decisions>
## Implementation Decisions

### RULED BY THE OWNER — do not re-open

**Tapping a preset creates the goal immediately, with defaults: option (a).**

Ruled 2026-09-08 after the owner saw all three options built and clickable side by side in
`sketches/006-adding-a-goal/` (served on `http://danserver:8150/`). The on-file recommendation was
(b) — open the form pre-filled — and **he overrode it**. He did so with variant A's cost rendered on
screen in a red callout: `type=timeTarget`, `budget=3.0 hrs/week`, `priority=Normal`, labelled *"the
defect deleted on 2026-09-08, re-opened."* This was informed, not incidental.

**Build (a). Do not build (b) and call it (a).** Concretely: if a plan finds itself adding a
confirmation step, a pre-create form, or any interruption between the chip tap and the goal
existing, it has drifted. One tap creates.

### The mitigation that makes (a) safe, and the reasoning behind it

The "help" defect was **not** that a default existed. It was that no screen ever said "3.0
hrs/week", so the owner could not know what he had agreed to until the scheduler acted on it. The
failed property is **visibility**, not absence-of-defaults. So (a) ships with:

1. **The created goal row states its weekly budget on its face.** One tap to create, zero taps to
   see what you got.
2. **Tapping the row opens the full form.** Changing it is one tap from the thing just made.

This is inside (a), not a softening of it — nothing interrupts creation.

### GOALADD-03 was amended, and the amendment matters to the tests

Original: *"no add path creates a goal with attributes the user did not choose."* Under (a) that is
**unsatisfiable** — it silently encoded (b) as a requirement. Amended to: *"no add path creates a
goal with attributes that are **hidden from** the user."*

**What this means for the test that proves it:** assert the budget is **findable as text on the
created row**. Do **not** assert `budget == 3.0` — that is a symbolic assertion derived from the
constant, it moves with the constant, and it cannot fail. This project has been bitten by exactly
that shape twice (`kBreakHitSlop` in Phase 31; the progress-track constants inside Phase 33). See
CLAUDE.md, "Assertions that cannot fail".

### The preset list

Eight names unchanged from `_goalPresets`, each gaining the emoji shown in sketch 006 and not
objected to:

🏃 Exercise · 📚 Reading · 👨‍👩‍👧 Family time · 💻 Side project · 🌱 Learn something · 🌲 Outdoors ·
🎨 Creative time · 😴 Rest

**Onboarding shares this list and therefore gains the emoji too — that is the point, not a side
effect.** The wording remains a taste call the owner may revise on sight; it is one const in one
file, so a later rewrite is cheap and should not be pre-negotiated.

### Claude's discretion

Widget naming, file placement of the extracted chip widget, and test structure are unconstrained —
follow codebase conventions and the patterns already present in the two implementations being
merged.

</decisions>

<code_context>
## Existing Code Insights

This is a **reuse-and-extract** job. The pattern already ships twice; the Goals screen is the only
add-surface without it. A third private copy is the wrong answer — extract one shared widget, the
same "delete the duplicate, share the source of truth" move as D-30-03 and IN-01.

| Surface | What exists today |
|---|---|
| Onboarding, goals step | `_ChipCloud` of presets — `onboarding_screen.dart:644`, list at `:138` |
| What restores you | `_QuickPickSection` with emojis — `restoratives_screen.dart:262`, `kCommonRestoratives` at `:18` |
| **Goals screen** | nothing — the fork, then a blank form |

`kCommonRestoratives` is the shape to copy: `const List<(String name, String emoji)>`.

**Why restoratives can be one-tap and goals could not:** a `RestorativeItem` has no attributes
(`{id, name, emojiTag, sortOrder}`); a `Goal` has type, budget and priority. That asymmetry is the
whole reason this needed a ruling — and the ruling accepts the defaults while requiring they be
visible.

Fork placement: the fork stays in front (UI-SPEC item 24). The preset row sits **after** "Something
to make time for", not before it.

</code_context>

<specifics>
## Specific Ideas

1. **A preset row inside the goal door of the fork** — after "Something to make time for".
2. **`kCommonGoals` as `(name, emoji)` pairs**, seeded from `_goalPresets`, shared with onboarding.
3. **An easy way to add your own** alongside the presets — the second half of the owner's sentence,
   and the thing chips alone do not give.
4. **One shared preset-chip widget** replacing the two private copies.
5. **The created goal row shows its weekly budget**, and tapping it opens the form.

</specifics>

<deferred>
## Deferred Ideas

- **Revising the preset wording/emoji.** Deliberately deferred to the owner's first sight of it on
  screen rather than negotiated now. One const, one file.
- **Item 5's restorative tap count** (nine chips, thumb-hittability) — asked five times across
  Phases 32 and 33 and closed unmeasured when Phase 33 was accepted by owner review. If this phase's
  shared chip widget changes the restoratives screen's chip geometry, that unknown becomes live
  again and should be raised at UAT. It is **not** established by any prior phase.

</deferred>

<uat>
## This phase MUST end in a human UAT checkpoint

It is a flow change judged by feel — the class this project's green suites have missed six times
(27, 29, 31, 32×2, 33).

**Serving:** reuse port 8143. Kill whatever is on it first **and verify it died** — a stale server
has squatted that port twice. Build per CLAUDE.md: `flutter build web --debug --source-maps
--pwa-strategy=none`, served with `tools/serve-uat.py`, started with the sandbox disabled so it
binds `0.0.0.0` rather than loopback.

**Trap #4 (⟳ Re-check-in) — state the reason, do not copy the rule.** Nothing in this phase touches
`schedule_generator.dart`, so **Re-check-in is NOT required for this phase's own items**. If a round
also judges scheduling output, it binds and must be stated then.

</uat>
