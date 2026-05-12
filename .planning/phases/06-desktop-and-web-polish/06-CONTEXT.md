# Phase 6: Desktop and Web Polish - Context

**Gathered:** 2026-05-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Canopy is genuinely good on Windows, macOS, Linux, and Web — adaptive layouts at large screens, mouse/keyboard interaction parity for the mobile swipe/long-press flows, window-size minimums that prevent layout breakage, and bookmarkable Web URLs that load the correct screen and state.

**Scope expansion (this discussion):** Phase 3 explicitly deferred "full app mood theming throughout the day" to Phase 6. Confirmed in this session — mood theming is now part of Phase 6 alongside the desktop/Web mechanics. The ROADMAP entry for Phase 6 must be updated to reflect this (action captured in `<deferred>`).

</domain>

<decisions>
## Implementation Decisions

### Mood Theming — Depth and Reach

- **D-01:** Full mood theming via `ColorScheme.fromSeed(<mood-color>)` applied at the `MaterialApp` level. The whole app's primary/secondary/tertiary/surface/surfaceTint derive from today's mood seed. Not screen-by-screen styling — a single theme swap.
- **D-02:** Every theme-able screen follows the daily mood: home, schedule, goals, settings, onboarding, review, commitments, end-of-day summary. No per-route theme overrides. Strongest sense of identity per mood with the least plumbing.
- **D-03:** Mood palette locked (from Phase 3): mood 1 #4A6275 → mood 2 #5C7A8A → mood 3 #4A8C7A → mood 4 #7AAF6A → mood 5 #E8C547. These seed `ColorScheme.fromSeed`.

### Mood Theming — Time Evolution

- **D-04:** Two-axis color: **hue from mood** (the seed), **brightness/saturation modulated by time of day**. Bright/saturated midday; dimmer/desaturated morning and evening. The day "breathes" within the mood the user set.
- **D-05:** Theme refresh is **debounced** — the time-driven modulation updates the ColorScheme on a coarse interval (e.g., every 15–30 minutes), not per second/frame. Avoid global `MaterialApp` rebuilds on a fast timer. Researcher should validate the exact interval against perceived smoothness vs. cost.
- **D-06:** The time-of-day curve is **bounded and gentle** — the same mood at 8am vs. 8pm should feel like the same room at a different hour, not like two different moods. Aim for a brightness/saturation swing of roughly 15–25% across the day, not full inversion.

### Mood Theming — Pre-Check-in State ("Curious / Waiting")

- **D-07:** Before today's mood is set (morning before check-in, or for first-time users with no prior mood), the app uses a **"curious" theme** — cool-neutral, low-saturation, expectant. Drifts toward a pale slate-blue or soft pearl. Specifically: a hue just outside the mood palette so it doesn't read as "mood 3 set"; saturation ~15–25% of full.
- **D-08:** The pre-check-in theme has a **breathing pulse on the check-in CTA** — subtle shadow expand/contract on a slow ~2–3s loop so the "listening" quality is felt, not just stated. Lives only on the check-in CTA button; nothing else animates. (Newly scoped this discussion — flag the small added test surface for the planner.)
- **D-09:** Tapping a mood **warms into the chosen palette** over 400–600ms — `AnimatedTheme` or `TweenAnimationBuilder` for the ColorScheme. The app "answers" the user. Not a snap.
- **D-10:** No "yesterday's mood carries forward" — the pre-check-in curious theme is the every-morning baseline. (Simpler, more deliberate; the daily check-in is the moment that sets color.)

### Desktop & Web Mechanics (Claude's Discretion — see below)

- **D-11:** ROADMAP-locked: LayoutBuilder two-column at ≥720dp (single-column below); window_manager minimum 480×640 on Windows/macOS/Linux (conditional imports — not on mobile/Web); go_router Web URL verification for existing routes; no Web Push API (in-app banner stays the Web notification).

### Claude's Discretion (left to planner/researcher within these guard rails)

- **Two-column layout structure** — Pick nav rail + content pane as the simplest path that satisfies the ROADMAP. Master-detail (Goals list + edit pane; Schedule list + chunk detail) is a nice-to-have but not required. Default to keeping bottom sheets as bottom sheets at all widths unless the planner finds a sharper choice.
- **Hover & always-visible affordances** — Per ROADMAP: chunk cards show checkbox + drag handle on hover; goal list rows show edit/archive on hover; drag handle always visible on desktop for ReorderableListView; long-press-only on mobile. Implementation specifics (MouseRegion vs. Focus, tooltip text, card elevation on hover) are planner's choice within Material 3 norms.
- **Swipe replacements** — Mobile swipe-to-complete and swipe-to-skip on chunks: desktop equivalent is **always-visible checkbox on hover + a "skip" button in the same revealed area**. No right-click context menu in v1 (consistency with mobile pattern).
- **Keyboard shortcuts** — Out of scope for Phase 6. Captured as deferred. Phase 6 ships mouse/touch parity only.
- **Web deep-link UX** — If user lands on `/schedule` with no schedule for today, show the existing empty state ("Start your day" CTA). If `/review` lands without enough data, show "Not enough data yet" (already implemented in Phase 5). Defaults to the screens' existing empty states; no special "deep link missed state" UI needed.
- **Mood theming color details** — Specific HSL math for the time-of-day modulation curve, contrast checking for text against the strongest moods (mood 5 amber + light scheme is the riskiest pair), exact pre-check-in hue choice within the "curious" guidance above.
- **AnimatedTheme curve and timing** — 400–600ms is the budget; specific curve (`Curves.easeInOut` vs. `Curves.easeOutCubic`) and exact duration left to planner.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase Spec
- `.planning/ROADMAP.md` §Phase 6 — Locked deliverables, key technical decisions (720dp threshold, 480×640 window min, conditional window_manager, no Web Push), and acceptance criteria. **Note:** ROADMAP does not yet include mood theming — needs update (see `<deferred>` action).

### Mood Theming Foundations (from earlier phases)
- `.planning/phases/03-schedule-generation-and-morning-check-in/03-CONTEXT.md` — Mood palette (#4A6275 → #E8C547), weather metaphor, mood color set on tap at check-in; deferred-to-Phase-6 carry-forward note. **The palette must come from here, not be re-invented.**
- `lib/screens/onboarding/onboarding_screen.dart:574` — The only existing `LayoutBuilder` in the codebase; reference for adaptive-layout pattern.
- `lib/screens/schedule/widgets/chunk_card.dart` — Phase 3 mood color accent on schedule screen lives here (AppBar tint + progress bar); the file the full-theming work will subsume.

### Routing & Shell
- `lib/router.dart` — `createRouter(SettingsNotifier)` with StatefulShellRoute. Existing branches: `/home`, `/goals` (+`/archived`), `/schedule` (+`/checkin`), `/settings` (+`/past-reviews`). Outside shell: `/onboarding`, `/review`, `/commitments`, `/summary`. URL surface for go_router Web URL verification is already in place.
- `lib/main.dart` — Where `MaterialApp.router` is constructed; the `ColorScheme.fromSeed(Colors.deepOrangeAccent)` line is where the mood-seeded theme will hook in.

### Cards & Affordances
- `lib/screens/schedule/widgets/chunk_card.dart` — Needs hover affordances (checkbox + drag handle reveal on desktop).
- `lib/screens/goals/widgets/goal_card.dart` — Needs hover affordances (edit + archive icons reveal on desktop). Establishes the 5dp left color bar + 12dp rounded card pattern.
- `lib/screens/commitments/commitments_screen.dart` — Commitment list rows, same hover treatment.

### Platform / Web Affordances
- `lib/services/notification_service.dart` — `kIsWeb` early returns already in place at lines 34, 87, 129, 169, 175, 185 (Phase 4). The Web in-app banner fallback that Phase 6 acceptance criterion #5 references.
- `lib/services/export_service.dart:3,26` — kIsWeb branching pattern reference.

### Project Constraints
- `.planning/PROJECT.md` — All six Flutter platforms must work; local-only storage; no LLM/state-mgmt lib. Phase 6 must not violate any of these.

No external ADRs/specs — design decisions captured in this CONTEXT.md.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ColorScheme.fromSeed(...)` is already the theming primitive in `main.dart` — swapping the seed argument is the lowest-friction path for full mood theming.
- `AnimatedTheme` (Flutter built-in) handles ColorScheme cross-fade — useful for D-09's warming transition.
- `MoodCheckinScreen` already stores the mood index on tap (Phase 3); the same write becomes the trigger to update the seeded ColorScheme app-wide.
- Existing one `LayoutBuilder` at `onboarding_screen.dart:574` as a reference for the adaptive-layout pattern.
- `InkWell` is used in 5 spots — provides the existing hover/press affordance baseline (Material's built-in `onHover` callback on `InkWell` covers many of the desktop hover cases without adding `MouseRegion`).
- `kIsWeb` already gates Web-specific code in 5 files — the conditional-platform pattern is established.

### Established Patterns
- `ChangeNotifier` (Provider) for app state — a `ThemeNotifier` or extension of `SettingsNotifier` is the natural home for the current mood-derived ColorScheme.
- `Platform.is...` + `kIsWeb` gating for desktop-only code (current pattern in `notification_service.dart`).
- Hive-persisted SettingsNotifier — the last mood for "carry forward" was rejected (D-10) but the pattern would be available if reconsidered later.
- Goal-color cards with 5dp left bar — chunk cards and goal cards already share the structural pattern; hover-reveal icons should respect the existing visual hierarchy.

### Integration Points
- **`main.dart`** — `MaterialApp.router` theme construction is the single seam where mood-seeded ColorScheme is applied app-wide. Add a `ThemeNotifier` (or extend `SettingsNotifier`) listenable; wrap the theme in `AnimatedTheme` for D-09.
- **`MoodCheckinScreen` save flow** — On mood-tap (Phase 3 already writes the mood), call into the new theme notifier to update the seed. The warming transition (D-09) happens automatically if `AnimatedTheme` wraps the theme.
- **`ChunkCard`, `GoalCard`, commitment list rows** — Wrap with `MouseRegion` (or `InkWell.onHover`) to drive the reveal/hide of hover-only affordances. Drag-handle visibility gating uses `defaultTargetPlatform` (desktop = always visible; mobile = long-press-only).
- **`ReorderableListView`** usages in Goals and Quarterly Review — drag handle visibility must respect platform per D-11.
- **`window_manager` setup** — conditional import; runs in `main.dart` after `WidgetsFlutterBinding.ensureInitialized()`, before `runApp`. Only on Windows/macOS/Linux (use `if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux))`).
- **Existing widget tests** — Phase 4 and Phase 5 widget tests assert specific colors (e.g., `colorScheme.primary` for bar chart rods). Full mood theming will change `colorScheme.primary` at runtime depending on test setup. Planner must decide: (a) tests pin a fixed mood via test helper, or (b) tests assert relative relationships rather than absolute colors. Acceptance criterion 5 requires all existing widget tests pass.

</code_context>

<specifics>
## Specific Ideas

- **"Curious, waiting"** is the user's phrase for the pre-check-in state. Translates to cool-neutral, low-saturation, expectant — not a mood-3 teal, not the default deepOrangeAccent. A pale slate-blue or soft pearl. The breathing pulse on the check-in CTA (D-08) is the explicit visual cue that the app is "listening." When the user taps their mood, the app "answers" by warming into that palette (D-09).
- **The app feels different each morning.** Full theming (D-01, D-02) is intentional — the user wants identity per mood, not subtle accenting. Combined with the time-of-day modulation (D-04), the app should feel alive within a single mood, not static.
- **Not knobby.** Mood is the only color knob the user controls. The time-of-day modulation is automatic and gentle (D-06) — never a feature the user has to manage.

</specifics>

<deferred>
## Deferred Ideas

- **Keyboard shortcuts** (space-to-complete focused chunk, cmd/ctrl-N for new goal, etc.) — explicitly out of Phase 6. Capture for v1.1 / Phase 7 backlog if the user wants. Mouse/touch parity is the v1 bar.
- **Master-detail layouts on Goals and Schedule at wide widths** — Phase 6 ships nav rail + single content pane. Goals-edit-side-panel and schedule-detail-pane are nice-to-have v1.1 improvements that go beyond the ROADMAP ≥720dp two-column commitment.
- **Right-click context menus on chunk cards** — left out of Phase 6 in favor of hover-reveal checkbox + skip button. Reasonable v1.1 addition.
- **"Carry yesterday's mood forward"** as an alternative to the curious pre-check-in theme — considered, not chosen. Could revisit if the every-morning curious theme feels too abrupt in practice.

## ROADMAP Action Required

**Update `.planning/ROADMAP.md` §Phase 6** to add mood theming to the deliverables list. Suggested addition:

> - **Full app mood theming (deferred from Phase 3):** `ColorScheme.fromSeed` swap driven by today's mood with time-of-day brightness/saturation modulation; pre-check-in "curious" theme with breathing pulse on the check-in CTA; ~400–600ms warming transition into the chosen mood on tap. Palette: #4A6275 / #5C7A8A / #4A8C7A / #7AAF6A / #E8C547 (locked Phase 3).

Acceptance criteria 1–5 stay; add a 6th: "Tapping each of the 5 moods at check-in changes the app-wide ColorScheme within 600ms; all existing widget tests pass (with a test fixture that pins a known mood)."

This action belongs to the planner — do not silently write it into ROADMAP here. Surface in confirm_creation.

</deferred>

---

*Phase: 06-desktop-and-web-polish*
*Context gathered: 2026-05-12*
