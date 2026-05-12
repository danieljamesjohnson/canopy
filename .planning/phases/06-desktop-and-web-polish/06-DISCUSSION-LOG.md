# Phase 6: Desktop and Web Polish - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-12
**Phase:** 06-desktop-and-web-polish
**Areas discussed:** Scope expansion (mood theming), Mood theming aggressiveness & reach (with 4 sub-questions)

---

## Scope Expansion — Mood theming carry-forward from Phase 3

Phase 3 CONTEXT.md flagged "full app mood theming throughout the day" as deferred to Phase 6, but the ROADMAP-locked Phase 6 deliverables don't include it. Raised at the top of discussion.

| Option | Description | Selected |
|--------|-------------|----------|
| Defer mood theming again | Keep Phase 6 strictly as roadmap-scoped (desktop/web polish only). Move mood theming into a backlog item or v1.1 phase. | |
| Expand Phase 6 to include it | Pull mood theming into Phase 6. Adds another gray area to discuss and bumps phase size. | ✓ |
| Carve a new Phase 7 | Keep Phase 6 lean (ship desktop polish for v1) and add a Phase 7 for mood theming. Updates ROADMAP. | |

**User's choice:** Expand Phase 6 to include it
**Notes:** ROADMAP §Phase 6 needs an update to add the mood theming deliverable. Surfaced for the planner to action — not silently rewritten here.

---

## Gray Area Selection

| Option | Description | Selected |
|--------|-------------|----------|
| Two-column layout structure | At ≥720dp: nav rail + single content pane, or master-detail on tabs that need it? | |
| Hover & desktop affordances | What reveals on hover for chunk/goal/commitment cards; what's always-visible; tooltips. | |
| Swipe replacements & keyboard shortcuts | Desktop equivalents for swipe-to-complete/swipe-to-skip; keyboard shortcuts in scope? | |
| Mood theming aggressiveness & reach | How aggressive, what reach, time evolution, pre-check-in state. | ✓ |

**User's choice:** Mood theming only — the other three left to Claude's discretion within ROADMAP guard rails.

---

## Mood theming — Q1: Depth

| Option | Description | Selected |
|--------|-------------|----------|
| Accent-only (current) | Keep Phase 3: AppBar tint + progress bar only. Low risk. | |
| Wash background, neutral cards | Subtle full-screen background tint at low opacity; cards neutral. Mid-risk. | |
| Full mood theming | ColorScheme regenerated from mood seed each day. Whole app reflects mood. Highest risk. | ✓ |

**User's choice:** Full mood theming
**Notes:** App-level Theme change via `ColorScheme.fromSeed`. "Feels like a different room each morning."

---

## Mood theming — Q2: Reach

| Option | Description | Selected |
|--------|-------------|----------|
| Everything theme-able | Whole app follows daily mood. Simplest plumbing. | ✓ |
| Today-screens only | Home + Schedule only; rest stays neutral. Per-route Theme override. | |
| All in-shell, not full-screen routes | Bottom-nav screens follow mood; pushed routes stay neutral. Middle ground. | |

**User's choice:** Everything theme-able
**Notes:** No per-route theme overrides; full app identity per mood.

---

## Mood theming — Q3: Time evolution

| Option | Description | Selected |
|--------|-------------|----------|
| Fixed all day (Recommended) | Tap-set color holds until tomorrow's check-in. Simple, predictable. | |
| Desaturates toward evening | Color fades to muted/grey by ~9pm. Mood signal weakens through the day. | |
| Time-of-day tinting layered on mood | Two-axis color: hue from mood, brightness/saturation from time. Most "alive," most complex. | ✓ |

**User's choice:** Time-of-day tinting layered on mood
**Notes:** Flagged two planner concerns inline: (1) verification surface = 5 moods × N time states, all existing color-asserting widget tests will need a pinned-mood fixture or relative assertions; (2) the time-driven theme listener must be debounced (e.g., 15–30 min interval) to avoid global rebuilds on a per-frame/per-second timer. Brightness/saturation swing should be bounded to ~15–25% so the same mood still reads as the same mood across the day.

---

## Mood theming — Q4: Pre-check-in state

| Option | Description | Selected |
|--------|-------------|----------|
| Yesterday's mood (Recommended) | Carry last mood's palette forward until today's check-in. | |
| Neutral / default seed | Material 3 default with current deepOrangeAccent seed until check-in. | |
| Pre-dawn desaturated mid-mood | Middle mood (#4A8C7A) at low saturation. "Waiting room." | |
| Other (free text) | — | ✓ |

**User's free-text answer:** "Yeah I think it should be a curious mood. Like it's waiting for you to tell it"

**Interpretation reflected back and confirmed:**
- Cool-neutral, low-saturation theme — pale slate-blue or soft pearl. Hue deliberately outside the 5-mood palette so it doesn't read as "mood 3 set." Saturation ~15–25% of full.
- Subtle breathing pulse on the check-in CTA (~2–3s loop, shadow expand/contract) so the "listening" quality is felt, not just stated.
- 400–600ms warming transition into the chosen mood when the user taps — `AnimatedTheme` / `TweenAnimationBuilder`. The app "answers."

**Follow-up confirmation (yes/no on two adds):**
1. Breathing pulse on check-in CTA → **Yes** (included in Phase 6)
2. Warming transition on mood tap → **Yes** (included in Phase 6)

---

## Claude's Discretion

Areas user delegated entirely:

- **Two-column layout structure (≥720dp)** — Default: nav rail + single content pane (simplest path that meets ROADMAP). Master-detail explicitly deferred.
- **Hover & desktop affordances** — Implementation specifics within Material 3 norms (MouseRegion vs. InkWell.onHover, tooltip text, hover elevation). Behaviors locked by ROADMAP.
- **Swipe replacements** — Always-visible checkbox + "skip" button on hover (no right-click context menu in v1).
- **Keyboard shortcuts** — Out of scope for Phase 6 (deferred).
- **Web deep-link UX** — Fall back to existing screens' empty states; no special "deep link miss" UI needed.
- **Mood theming color specifics** — HSL math for time-of-day curve, contrast checks (mood 5 amber + light scheme is riskiest), exact pre-check-in hue.
- **AnimatedTheme curve and timing** — within 400–600ms budget.

## Deferred Ideas

- Keyboard shortcuts (v1.1 / Phase 7)
- Master-detail layouts on Goals/Schedule at wide widths (v1.1)
- Right-click context menus on chunk cards (v1.1)
- "Carry yesterday's mood forward" pre-check-in alternative

## ROADMAP Action

`.planning/ROADMAP.md` §Phase 6 needs a "full app mood theming" deliverable added. Concrete wording proposed in CONTEXT.md's `<deferred>` section. Planner to action.
