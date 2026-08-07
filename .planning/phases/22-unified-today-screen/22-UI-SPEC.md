---
phase: 22
slug: unified-today-screen
status: approved
shadcn_initialized: false
preset: none
created: 2026-08-07
reviewed_at: 2026-08-07
source: sketch 001 (variant A), reviewed and chosen by Dan
---

# Phase 22 — UI Design Contract

> Visual and interaction contract for Phase 22: Unified Today Screen.
> **Not agent-generated.** Derived from `.planning/sketches/001-unified-today/` variant A,
> which Dan reviewed and selected on 2026-08-07. Treat these as decided, not proposed.
>
> **Framework note:** Flutter / Material 3 with a mood-seeded `ColorScheme.fromSeed`
> (`lib/providers/theme_notifier.dart`). All colour references below are semantic
> `ColorScheme` slots, never raw hex — the palette shifts with the user's mood and the
> time of day, so hardcoded colour is a bug (see the standing `chunk_card.dart`
> `Colors.green.shade600` tech-debt item; do not add more of it).

---

## Structure

One scrollable list. Top to bottom:

1. **Header** — "Today" + the date, then the mood chip (e.g. "Steady day · 9 chunks").
   Stays put; not a collapsing app bar.
2. **The day** — a single vertically scrolling list of rows, in clock order, covering the
   whole day: activities, breaks, commitments, and named free time.

There is **no** separate "now" panel, hero card, or sticky band. The current row lives in
the list at its own clock position.

## Row types

| Row | Treatment |
|---|---|
| Work chunk, upcoming | `surfaceContainer` card, outlined, title + duration |
| Work chunk, completed | Same card, dimmed (~50% opacity), title struck through, trailing ✓ in `primary` |
| Work chunk, skipped | Dimmed, struck through, trailing "skipped" in `onSurfaceVariant` |
| Break (short or long) | Transparent fill with a **dashed** outline; title in `onSurfaceVariant` at regular weight — breaks are not achievements |
| Commitment | `tertiaryContainer` / `onTertiaryContainer`, no outline — reads as anchored, not discretionary |
| Free time | No card. A quiet label indented behind a dotted left rule, `onSurfaceVariant` |
| **Current activity** | See "The live row" below |

**Time gutter:** a fixed-width left column (~46dp) holding the row's start time, monospace,
`bodySmall`, `onSurfaceVariant`, top-aligned to the row. Free-time rows leave the gutter
empty when they precede the day's first activity.

## Free time (LOCKED)

Gaps are **named, never collapsed to whitespace**:

- Before the day's first activity: **"Free until 8:00am"**
- Between activities: **"Free · 1h 40m"**

Suppress gaps shorter than ~10 minutes — a 5-minute seam is noise, and short breaks already
occupy those.

Rationale, so it isn't optimised away later: unscheduled time being *visibly yours* is part
of the product's promise. Dan called this out specifically as something he liked.

## The live row

The current activity **swells in place** — same list position, larger card:

- `primaryContainer` / `onPrimaryContainer`, ~16dp radius, soft elevation.
- Kicker line, `labelSmall`, uppercase, ~72% opacity: "RIGHT NOW" — or
  "RIGHT NOW — RESTING" during a break.
- Title, `titleLarge`-ish, semibold.
- Remaining-time line, monospace, ~82% opacity (granularity is Phase 23 / LIVE-02).
- A progress bar filling across the activity's window.
- Actions row — Complete / Skip — **for work chunks only**.
- A "Next · <title> at <time>" line when a later activity exists.

**On open, the list scrolls the current row to centre.** That is the entire mechanism for
finding "now". No sticky bar, no floating pill, no jump button.

## Navigation contract (UNIFY-02)

This supersedes the Phase 18 UI-SPEC's "four destinations locked" note.

- Shell destinations drop from four to **three**: the merged Today screen, Goals, Settings.
  `NavigationRail` ≥720dp / `NavigationBar` below, `NavigationRailLabelType.all` retained —
  labels always visible, per the standing mood-readability rule.
- The merged destination's label is **not** "Home".
- `/schedule` must keep resolving. A redirect to the unified route is acceptable; a dead
  route is not. **`lib/main.dart:86` (`router.go('/schedule')` on notification tap) is a
  daily-use path** — a Chunk reminder must land on the working screen.
- `lib/screens/home/home_screen.dart:495`'s "see full schedule" affordance is removed, not
  repointed — it would link the screen to itself.

## Inherited contracts — do not regress

- **Adaptive modals (Phase 18, RESP-01/02/03):** any modal opened from this screen still
  routes through `showAdaptiveFormModal` — centred dialog ≥720dp, bottom sheet below.
- **720dp content constraint (POLISH-01):** the merged screen constrains its content width
  on desktop like the screens it replaces.
- **Labelled chunk actions (SCHED-03, v1.2):** Complete / Skip stay labelled and
  hover-free — no hover-only affordances.
- **Mood theming:** every colour comes from the active `ColorScheme`.

## Copywriting Contract

- Never tell the user they are behind, short, or owing. TONE-01 removes the one existing
  instance; do not introduce new ones on this screen.
- Free time is framed as the user's: "Until then the time is yours."
- Breaks are described as resting, not as tasks.

## Checker Sign-Off

Design chosen by the product owner from a working sketch rather than proposed by an agent.
`gsd-ui-checker` should verify *conformance to this contract*, not re-open the direction.
