---
phase: 6
slug: desktop-and-web-polish
status: draft
shadcn_initialized: false
preset: not applicable
created: 2026-05-12
---

# Phase 6 — UI Design Contract

> Visual and interaction contract for Phase 6: Desktop and Web Polish (and full-app mood theming deferred from Phase 3). Flutter / Material 3 project — shadcn does not apply.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none (Flutter Material 3, not a web/JS project) |
| Preset | not applicable |
| Component library | Flutter Material 3 (`useMaterial3: true`) |
| Icon library | `Icons.*_outlined` (Material Outlined, established convention from `lib/router.dart` + existing screens) |
| Font | Material 3 default Roboto on Android/Web, SF on Apple platforms, Segoe UI on Windows — accept platform defaults (do not override `fontFamily`) |

**Theming seam (locked):** Single `MaterialApp.router` `ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: <mood-or-curious>))` at `lib/main.dart`. Wrapped in `AnimatedTheme` for the mood-warming transition (D-09). No per-route theme overrides (D-02).

---

## Spacing Scale

Declared values (multiples of 4, drawn from existing codebase usage). The codebase already uses 2, 4, 5, 6, 8, 12, 16, 20, 24, 32 — Phase 6 locks the canonical scale and tolerates the existing 2dp/5dp/6dp/12dp/20dp exceptions where they are load-bearing for already-shipped pixel-perfect details.

| Token | Value | Usage |
|-------|-------|-------|
| xxs | 2px | Card vertical micro-stack (between adjacent break + work card — established) |
| xs | 4px | Icon/text inline gap inside card rows (`SizedBox(width:4–6)`) |
| sm | 8px | Compact element spacing (icon ↔ label, inline pad) |
| md | 12px | Card interior padding (`EdgeInsets.symmetric(horizontal: 12, vertical: 12)` — established) |
| lg | 16px | Default screen-edge margin, card outer horizontal margin |
| xl | 24px | Section padding, screen content padding |
| 2xl | 32px | Major section breaks (modal-sheet outer padding) |

**Phase 6 additions / locks:**

| Token | Value | Usage (Phase 6 specific) |
|-------|-------|--------------------------|
| `breakpoint.desktop` | 720dp | LayoutBuilder threshold for two-column adaptive layout (D-11) |
| `window.min.width` | 480 logical pixels | `window_manager` minimum on Windows/macOS/Linux (D-11) |
| `window.min.height` | 640 logical pixels | `window_manager` minimum on Windows/macOS/Linux (D-11) |
| `navRail.width` | 80dp | Material 3 default `NavigationRail` width — accept default at ≥720dp |
| `hoverArea.iconPadding` | 8px | Hover-revealed icon button hit padding (Material 3 IconButton default) |
| `leftColorBar.width` | 5px | Goal/chunk card left color bar (established Phase 2/3) |
| `card.borderRadius` | 12dp | Goal + chunk cards (established) |
| `card.outerMargin` | `EdgeInsets.symmetric(horizontal: 16, vertical: 4)` | Established |
| `card.shortBreak.height` | 48dp | Short break compact row (established) |
| `dragHandle.iconSize` | 24dp | `Icons.drag_handle` default size |
| `dragHandle.opacity.desktop` | 0.6 | Always-visible on desktop but recessive (does not compete with content) |
| `dragHandle.opacity.mobile` | 0.0 | Hidden — long-press triggers ReorderableListView |

**Exceptions (existing, not introduced this phase):**
- `5px` left color bar on goal cards / chunk cards — load-bearing visual identifier, do not change to 4 or 8
- `2px` vertical margin between adjacent short-break + work cards in schedule list — maintains rhythm
- `6px` icon ↔ label inline spacing inside card title rows — tightens hierarchy

---

## Typography

Use `Theme.of(context).textTheme` entries only — do not invent new scales. Material 3 default sizes are inherited; weight + line height come from the typeface defaults. Listing here so the planner/executor have an explicit map.

| Role | textTheme key | Size | Weight | Line Height | Used For |
|------|---------------|------|--------|-------------|----------|
| Display | `displayMedium` | 45sp | 400 | 1.16 | Mood emoji + ack text on check-in (existing) |
| Heading | `titleLarge` | 22sp | 400 | 1.27 | Home greeting, screen titles (existing) |
| Subheading | `titleMedium` | 16sp | 500 | 1.5 | Card titles — goal name, chunk rationale (existing) |
| Body | `bodyMedium` | 14sp | 400 | 1.43 | Default body copy, secondary card lines (existing) |
| Caption | `bodySmall` | 12sp | 400 | 1.33 | Duration labels, anchored times, hover tooltip text (existing) |
| Label | `labelMedium` | 12sp | 500 | 1.33 | NavigationBar / NavigationRail labels (Material default) |

**Weight count:** 2 (400 regular, 500 medium). No additional weights introduced in Phase 6.

**Sizes used in this phase:** 4 (12, 14, 16, 22sp — `bodySmall`, `bodyMedium`, `titleMedium`, `titleLarge`). `displayMedium` already exists on check-in screen; not re-touched.

**No new TextStyles.** Hover-revealed icon buttons inherit the icon theme; tooltip text inherits `bodySmall`.

---

## Color

Color is **mood-derived at runtime** via `ColorScheme.fromSeed(seedColor: moodSeed)`. The 60/30/10 split is expressed in semantic Material 3 roles — these are stable contracts regardless of which mood is active.

### Mood Seed Palette (locked — Phase 3, do not modify)

| Mood | Seed Hex | Weather Metaphor |
|------|----------|------------------|
| 1 | `#4A6275` | Stormy (steel blue-grey) |
| 2 | `#5C7A8A` | Overcast (slate) |
| 3 | `#4A8C7A` | Partly cloudy (muted teal) |
| 4 | `#7AAF6A` | Clearing (soft green) |
| 5 | `#E8C547` | Sunny (warm amber) |

### Pre-Check-in "Curious" Seed (locked this phase)

| Property | Value |
|----------|-------|
| Seed hex | `#7A8FA3` (pale slate-blue) |
| HSL | H ≈ 210°, S ≈ 20%, L ≈ 56% |
| Justification | Cool-neutral; hue 210° sits outside the 5 mood seeds (mood seeds span hues ~195° → ~50°, the curious hue is on the cool blue side, ~30° away from mood 2's 200°-ish hue and clearly cooler than mood 3's teal); saturation 20% sits inside the D-07 "15–25% of full" guidance; lightness 56% reads as "pearl/soft slate," neither bright midday nor evening dim. Reads as "expectant," not "mood 3 set." |

### 60/30/10 Composition (Material 3 semantic roles)

| Role (60/30/10) | Material 3 ColorScheme key | Usage |
|-----------------|---------------------------|-------|
| Dominant (60%) | `surface` | App background, Scaffold body, schedule list background |
| Secondary (30%) | `surfaceContainerHighest` / `surfaceContainer` | Cards (goal, chunk, commitment), nav rail surface, modal sheet background |
| Accent (10%) | `primary` (derived from mood seed) | Primary CTAs (`FilledButton`), NavigationRail/Bar selected indicator, schedule progress bar fill, AppBar tint on check-in, Goal-card left color bar fallback when a goal has no per-goal hex assigned, focused outline |
| Destructive | `error` (Material 3 default red) | Delete commitment confirmation button (existing pattern in `commitments_screen.dart:57`); archive button is **not** destructive — uses default text style |

**Accent reserved for (explicit list, never "all interactive elements"):**
- `FilledButton` / `ElevatedButton` background (primary CTA only — "Start your day," "Generate schedule," "Save goal")
- `NavigationBar` / `NavigationRail` selected indicator
- `ScheduleProgressBar` filled portion
- `Icons.check_circle` completion state on chunk cards (currently `Colors.green.shade600` — see Mood 5 contrast note below)
- Focused-input outline (`InputDecoration` default Material 3)
- Drag handle on hover-active state (full opacity)

**NOT accent (use neutral `onSurfaceVariant`):**
- Hover-revealed icons (edit, archive, skip, checkbox) before hover-active — recessive grey
- Secondary text (duration labels, anchored times, secondary card lines)
- Drag handle in resting state

### Time-of-Day Modulation (locked this phase)

Per D-04 / D-05 / D-06. Hue stays fixed (mood seed); lightness and saturation modulate.

| Property | Value |
|----------|-------|
| Modulation type | HSL-space delta applied to seed before `ColorScheme.fromSeed` |
| Recompute interval | **20 minutes** (every :00, :20, :40 of the hour, debounced — inside the 15–30min D-05 budget; 3 rebuilds/hour is imperceptible and cheap) |
| Curve shape | Cosine peaking at **solar noon (12:00 local)**, troughing at **midnight (00:00)** |
| Lightness swing | ±5% absolute lightness around seed's natural L (so peak L = base L + 5, trough L = base L − 5) |
| Saturation swing | ±10% absolute saturation around seed's natural S (peak S = base S + 10, trough S = base S − 10) |
| Combined perceptual delta | ≈20% swing peak-to-trough across both axes — sits inside the D-06 "15–25%" guidance |
| Math (per recompute) | `t = cos(2π × (minutesSinceMidnight / 1440 − 0.5))` → `t ∈ [−1, +1]`. `L' = clamp(L + 5 × t, 0, 100)`. `S' = clamp(S + 10 × t, 0, 100)`. Convert back to RGB; pass as seed to `ColorScheme.fromSeed`. |
| Applied to | The seed used for `ColorScheme.fromSeed` only. The output ColorScheme is then handed to `AnimatedTheme`. |
| Test fixture | Time-of-day modulation **disabled** under `flutter test` — tests pin a fixed `DateTime.now()` equivalent or inject the seed directly (see Widget Test Strategy below). |

### Contrast Floors — Mood 5 Amber Risk

Mood 5 (`#E8C547`) is the riskiest pair against a light Material 3 ColorScheme. `ColorScheme.fromSeed` algorithmically picks `onPrimary` for legibility, but the `primary` itself may appear at AppBar / progress-bar fill / selected indicator where it must coexist with text.

**Locked contrast requirements:**
- Text on `colorScheme.primary` surfaces (AppBar title, FilledButton label): rely on `colorScheme.onPrimary` (Material 3 picks white or dark per WCAG 4.5:1). Do not override `onPrimary` to a hard-coded value.
- `Icons.check_circle` completion indicator on chunk cards: keep `Colors.green.shade600` (existing — semantic green, not accent — readable on all 5 mood schemes including Mood 5's amber-cast surfaces). Document in code comment that this color is intentionally outside the mood scheme for semantic completion clarity.
- Schedule progress bar text (`X of Y chunks`): use `Theme.of(context).colorScheme.onSurface` over the surface background, never over the filled primary segment.
- Validate Mood 5 manually before phase verifies: open the app, tap mood 5, walk every screen (home, schedule, goals, commitments, settings, review). Any text or icon that fails the 4.5:1 eye-test gets rerouted to `onSurface` / `onSurfaceVariant`.

### Goal Per-Card Color

Existing pattern: each Goal has an optional `color` field (hex). `GoalCard` and `ChunkCard` render the 5dp left color bar from this per-goal hex when present, falling back to `colorScheme.primary` (which is now mood-derived). Phase 6 changes nothing here — but be aware that the fallback color now shifts with mood, which is the desired behaviour.

---

## Copywriting Contract

Phase 6 introduces few new copy strings — mostly tooltips for the new hover-revealed icon buttons and a few Web-fallback messages. Reuse existing strings from the Phase 3/4/5 screens wherever possible.

| Element | Copy |
|---------|------|
| Primary CTA (pre-check-in, home screen) | `Start your day` (existing — already shipped Phase 3) |
| Hover-revealed icon button: chunk complete | Tooltip: `Mark complete` (Icon: `Icons.check_circle_outline`) |
| Hover-revealed icon button: chunk skip | Tooltip: `Skip` (Icon: `Icons.skip_next_outlined`) |
| Hover-revealed icon button: goal edit | Tooltip: `Edit goal` (Icon: `Icons.edit_outlined`) |
| Hover-revealed icon button: goal archive | Tooltip: `Archive goal` (Icon: `Icons.archive_outlined`) |
| Hover-revealed icon button: commitment edit | Tooltip: `Edit commitment` (Icon: `Icons.edit_outlined`) |
| Hover-revealed icon button: commitment delete | Tooltip: `Delete commitment` (Icon: `Icons.delete_outline`) |
| Drag handle (desktop, always visible) | Tooltip: `Drag to reorder` (Icon: `Icons.drag_handle`) |
| Empty state (deep-link `/schedule` with no schedule today) | Heading: `No schedule yet today` · Body: `Tap below to check in and plan your day.` · CTA: `Start your day` (reuses existing Phase 3 empty state — do not duplicate) |
| Empty state (deep-link `/review` with insufficient data) | Reuses existing Phase 5 string: `Not enough data yet` (already shipped) |
| Empty state (deep-link `/goals` with no goals) | Reuses existing Phase 2 empty state — do not duplicate |
| Web in-app banner (no schedule today) | Reuses existing Phase 4 banner copy — Phase 6 verifies, does not author |
| Destructive confirmation: archive goal | Title: `Archive this goal?` · Body: `{goal name}` · Confirm: `Archive` · Cancel: `Cancel` (existing Phase 2) |
| Destructive confirmation: delete commitment | Title: `Delete commitment?` · Body: `{commitment name}` · Confirm: `Delete` · Cancel: `Cancel` (existing Phase 2) |
| Error state (window-too-small on desktop before window_manager kicks in) | Not surfaced — window_manager prevents the resize; no user-facing error needed |

**Copy rules carried through:**
- Goal-type taxonomy ("time-target", "outcome", "habit") never appears in UI — plain-language only (locked Phase 2)
- "Just survive today" never appears — communicated by mood-1/2 ack-text prefixes (locked Phase 3)
- Tone: celebratory, not evaluative — "Here's what you built" not "Here's what you missed" (locked Phase 5)

---

## Interaction Contracts (Phase 6 specific)

### Hover Reveals

**Mechanism choice (locked):** Use `InkWell.onHover` callback where an `InkWell` already wraps the target widget (`GoalCard`, `_CommitmentTile` if it gets an `InkWell` wrap, the goal-type picker tiles). Use `MouseRegion` only where no `InkWell` exists (`ChunkCard` work variant has no `InkWell` — wrap in `MouseRegion`). Rationale: `InkWell.onHover` covers Material's native focus/hover ring for free and avoids two overlapping hover detectors; `MouseRegion` is the fallback when adding an `InkWell` would change tap semantics.

| Target | Wrapper | Trigger | Reveal | Hide |
|--------|---------|---------|--------|------|
| `ChunkCard` (work variant) | `MouseRegion` (no existing InkWell) | `onEnter` | Checkbox + skip button in a 80px trailing slot, fade `Opacity 0 → 1` over 120ms | `onExit` fade back |
| `GoalCard` | `InkWell.onHover` (existing InkWell) | `onHover(true)` | Edit + archive icons in trailing slot, fade `Opacity 0 → 1` over 120ms | `onHover(false)` fade back |
| Commitment list row | `InkWell.onHover` (wrap if not already) | `onHover(true)` | Edit + delete icons in trailing slot, fade 120ms | `onHover(false)` fade back |
| Card elevation on hover | Material 3 default (elevation `1 → 2`) | Material handles automatically when hovered | — | — |

**Mobile (touchscreen):** Hover callbacks do not fire on touch — these icons stay at `opacity 0` on mobile, which preserves the swipe-to-complete / swipe-to-skip Phase 4 affordance. `defaultTargetPlatform` is not used to gate hover icons — pointer presence determines reveal, which is correct cross-platform.

**Animation delta (locked):**
- `Opacity 0 → 1` on icon group, `Duration: 120ms`, `Curve: Curves.easeOut`
- Card elevation: Material 3 default (no override)
- No scale / no translation — opacity-only reveal to keep layout stable

### Drag Handle Visibility

| Platform | Visibility | Reorder Trigger |
|----------|-----------|-----------------|
| Desktop (Windows/macOS/Linux/Web with mouse) | Always visible at `Opacity 0.6`, full `Opacity 1.0` on hover | Click-and-drag the handle |
| Mobile (Android/iOS touch) | Hidden (`Opacity 0.0`) | Long-press anywhere on the card (`ReorderableListView` default) |
| Gating | `defaultTargetPlatform == TargetPlatform.android \|\| iOS` → hide; else show | — |

### Breathing Pulse (pre-check-in CTA only — D-08)

Locked timing:

| Property | Value |
|----------|-------|
| Target widget | The check-in CTA button on `HomeScreen` (Start your day) when no mood is set for today |
| Animation | Shadow `BoxShadow(blurRadius)` expand/contract: `8px → 16px → 8px` cycle |
| Shadow color | `colorScheme.primary.withOpacity(0.25)` (curious-theme primary during pre-check-in) |
| Loop duration | `2400ms` (within D-08 "~2–3s loop") |
| Curve | `Curves.easeInOut` |
| Implementation | `AnimatedBuilder` with `AnimationController..repeat(reverse: true)` |
| Scope | **Check-in CTA only.** No other widget pulses. Pulse stops the moment mood is tapped (controller disposes after `MoodCheckinScreen` writes mood). |
| Mobile/desktop parity | Same animation on all platforms (it is decoration, not interaction) |
| Reduced motion | Respect `MediaQuery.disableAnimations` — if true, render pulse at midpoint (shadow blur = 12px) and do not animate |

### Mood Warming Transition (D-09 — locked)

| Property | Value |
|----------|-------|
| Wrapper | `AnimatedTheme` at `MaterialApp.router` `theme` slot |
| Duration | **500ms** (centred in D-09's 400–600ms budget) |
| Curve | `Curves.easeOutCubic` — decelerating; the app "settles into" the new mood, not a linear ramp |
| Trigger | `ThemeNotifier.setMoodSeed(seed)` writes the new seed and notifies listeners; `AnimatedTheme` cross-fades automatically |
| Scope | Entire `ColorScheme` (primary, secondary, tertiary, surface, surfaceContainer*, onPrimary, etc.) — Material 3 handles per-channel interpolation |
| Time-of-day re-modulation during transition | Suppressed for the 500ms transition window — the cosine clock resumes at the next 20-min recompute after the transition completes (prevents two overlapping animations) |

### Two-Column Adaptive Layout (D-11 — locked)

| Width range | Layout | Components |
|-------------|--------|-----------|
| `< 720dp` | Single column (mobile/portrait tablet) | Current `_ScaffoldWithNavBar` with `NavigationBar` at the bottom (unchanged) |
| `≥ 720dp` | Two column | `Row` of (`NavigationRail` selected destinations on the left, content `Expanded` on the right). No bottom `NavigationBar`. |
| Implementation | `LayoutBuilder` in `_ScaffoldWithNavBar` — branch on `constraints.maxWidth >= 720` | — |
| NavigationRail spec | Material 3 default: 80dp width, icon-only with label-on-extended hovered; 4 destinations (Home, Goals, Schedule, Settings) — same icons + labels as existing `NavigationBar` | — |
| NavigationRail surface | `colorScheme.surfaceContainer` (Material 3 default — sits in the "30% secondary" band) | — |
| Selected indicator | Material 3 default pill, `colorScheme.secondaryContainer` background | — |
| Scaffolds outside the shell (`/onboarding`, `/review`, `/commitments`, `/summary`) | Full-screen, no nav rail (existing) — these remain single-column at all widths | — |
| Content max-width at ≥720dp | No max-width clamp in v1 (content fills the right pane). Defer "centered narrow column at very wide widths" to v1.1. | — |

### Window Minimums (D-11 — locked)

| Platform | Minimum | Default opening size |
|----------|---------|---------------------|
| Windows | 480 × 640 logical px (via `window_manager.setMinimumSize`) | Platform default (do not override) |
| macOS | 480 × 640 logical px | Platform default |
| Linux | 480 × 640 logical px | Platform default |
| Web | Not applicable (browser controls window) | — |
| Mobile (iOS/Android) | Not applicable | — |
| Gating code | `if (!kIsWeb && (Platform.isWindows \|\| Platform.isMacOS \|\| Platform.isLinux))` — pattern established in `lib/services/notification_service.dart` | — |

### Mouse / Touch Interaction Parity Map

| Mobile gesture | Desktop equivalent |
|----------------|-------------------|
| Swipe right on chunk → complete | Hover-revealed checkbox button → click |
| Swipe left on chunk → skip | Hover-revealed skip button → click |
| Long-press on goal/chunk → drag-reorder | Click-and-drag the always-visible drag handle |
| Tap card → open detail sheet | Click card → open detail sheet (unchanged — InkWell already handles) |
| (no right-click menu in v1) | (no right-click menu in v1 — explicitly deferred) |
| (no keyboard shortcuts in v1) | (no keyboard shortcuts in v1 — explicitly deferred) |

### Web Deep-Link Empty States

| URL hit with insufficient state | Behaviour |
|--------------------------------|-----------|
| `/schedule` with no schedule today | Show existing Phase 3 empty state with `Start your day` CTA — no new "deep link missed" UI |
| `/review` without 90-day window | Show existing Phase 5 `Not enough data yet` state |
| `/goals` with no goals | Show existing Phase 2 empty state |
| `/onboarding` after onboarding complete | go_router redirect to `/goals` (existing) |
| Any unmatched URL | go_router default 404 (existing) |

### Widget Test Mood-Pinning Strategy (locked)

Phase 6 acceptance criterion 5 ("all existing widget tests pass") requires a strategy.

**Locked: Strategy (a) — test helper that injects a known mood seed.**

| Component | Spec |
|-----------|------|
| Test helper file | `test/test_helpers/mood_pump.dart` (new file in this phase) |
| Helper function | `Future<void> pumpWithMood(WidgetTester tester, Widget child, {int moodIndex = 3})` — wraps `child` in a `MaterialApp` with `ColorScheme.fromSeed(seedColor: _moodSeed(moodIndex))` and disables time-of-day modulation. |
| Default mood for existing tests | **mood 3** (`#4A8C7A` — muted teal). Mood 3 is the median weather, has balanced contrast in both light and dark schemes, and is closest to the previous deepOrangeAccent in perceived neutrality. |
| Migration path | Phase 6 sweeps existing widget tests that construct a bare `MaterialApp` — replace with `pumpWithMood(tester, ...)` (or its convenience wrapper). Tests that asserted hard-coded colors against the old deepOrangeAccent must be updated to assert relative relationships against `Theme.of(context).colorScheme.primary` or to the mood-3 derived value. |
| Why not (b) (relative-color asserts only) | Existing Phase 4/5 tests assert specific `colorScheme.primary` for bar chart rods — rewriting those to "relative" would weaken coverage. (a) is one helper to add and a small change-per-test (one line). |

---

## Component Inventory (this phase's surface area)

These are the widgets the planner must touch. Each is a known existing file or a small new file.

| Widget | File | Phase 6 change |
|--------|------|----------------|
| `CanopyApp` / `MaterialApp.router` | `lib/main.dart` | Replace `ColorScheme.fromSeed(Color(0xFF3D6B4F))` with `ThemeNotifier`-driven seed wrapped in `AnimatedTheme` (500ms easeOutCubic) |
| `ThemeNotifier` (new) | `lib/providers/theme_notifier.dart` (new) | Holds current mood seed (or curious seed when unset); recomputes time-of-day-modulated seed on 20-min ticker; notifies listeners |
| `MoodCheckinScreen` save flow | `lib/screens/schedule/checkin_screen.dart` | On mood tap, call `context.read<ThemeNotifier>().setMoodSeed(...)` after writing the mood (existing write stays) |
| `HomeScreen` check-in CTA | `lib/screens/home/home_screen.dart` | Add breathing pulse (`AnimatedBuilder` + `BoxShadow` blur 8→16) when no mood set; stop pulse when mood is set |
| `ChunkCard` (work variant) | `lib/screens/schedule/widgets/chunk_card.dart` | Wrap in `MouseRegion`; add hover-revealed checkbox + skip button (`Opacity 0→1`, 120ms easeOut) |
| `SwipeableChunkCard` | `lib/screens/schedule/widgets/swipeable_chunk_card.dart` | Swipe stays on mobile; on desktop the Dismissible still wraps but hover icons are the discoverable affordance |
| `GoalCard` | `lib/screens/goals/widgets/goal_card.dart` | Use existing `InkWell.onHover` to fade-in edit + archive icons in trailing slot |
| Commitment list row | `lib/screens/commitments/commitments_screen.dart` | Wrap row in `InkWell.onHover`; fade-in edit + delete icons (replaces always-on icons if any) |
| `_ScaffoldWithNavBar` | `lib/router.dart` | Wrap in `LayoutBuilder`; branch at `maxWidth >= 720` to `NavigationRail` + content; below 720 keeps current `NavigationBar` |
| ReorderableListView usages | `lib/screens/goals/goals_screen.dart`, `lib/screens/quarterly_review/sections/adjustments_section.dart` | Drag handle visible on desktop only (`Opacity 0.6`); long-press unchanged on mobile |
| `window_manager` setup | `lib/main.dart` | Conditional desktop-only init before `runApp`, setMinimumSize(480, 640) |
| `pumpWithMood` test helper | `test/test_helpers/mood_pump.dart` (new) | Existing tests migrated to use the helper with mood 3 fixture |

---

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| n/a (Flutter project, not shadcn) | — | not applicable |

No third-party UI registries. All widgets are first-party (Flutter SDK) or already-vendored pub.dev packages (`fl_chart` Phase 5, `flutter_local_notifications` Phase 4). Phase 6 adds **one** new pub.dev package: `window_manager` (desktop-only window-size minimum). Not a UI registry — out of scope for this safety gate.

---

## Checker Sign-Off

- [ ] Dimension 1 Copywriting: PASS
- [ ] Dimension 2 Visuals: PASS
- [ ] Dimension 3 Color: PASS
- [ ] Dimension 4 Typography: PASS
- [ ] Dimension 5 Spacing: PASS
- [ ] Dimension 6 Registry Safety: PASS

**Approval:** pending
