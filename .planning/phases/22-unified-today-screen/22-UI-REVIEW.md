---
phase: 22-unified-today-screen
audited: 2026-08-07
baseline: 22-UI-SPEC.md (design contract, sketch 001 variant A)
screenshots: provided (agent-captured, pre-existing — desktop 1280x900, phone 390x844, empty states)
status: reviewed
pillars:
  copywriting: 4
  visuals: 3
  color: 2
  typography: 3
  spacing: 3
  experience_design: 3
overall: 18/24
---

# Phase 22 — UI Review

**Audited:** 2026-08-07
**Baseline:** `.planning/phases/22-unified-today-screen/22-UI-SPEC.md`
**Screenshots:** captured (5 PNGs, desktop/phone/scroll/empty states — read pixel-by-pixel, not code-only)

---

## Pillar Scores

| Pillar | Score | Key Finding |
|--------|-------|-------------|
| 1. Copywriting | 4/4 | Locked copy (free-time strings, mood chip, TONE-01) renders verbatim; no generic labels found. |
| 2. Visuals | 3/4 | Live row reads as a genuine focal point, but five preamble elements precede the first content row and per-goal colour bars add an unspec'd third accent language. |
| 3. Color | 2/4 | `swipeable_chunk_card.dart`'s swipe-reveal backgrounds are still raw `Colors.green.shade400`/`Colors.orange.shade300`/`Colors.white` — the exact violation the UI-SPEC calls out by name as tech debt, left unclosed one file over from where it was "fully closed." |
| 4. Typography | 3/4 | 8 distinct Material text-style tokens in play across the screen family, no rogue custom `fontSize` in the row/list flow (one harmless inline `fontSize: 16` on a restoratives chip emoji). |
| 5. Spacing | 3/4 | Spacing values are mostly 4/8/16/24/32 rhythm-consistent; a few one-off values (2, 6, 10, 12) break the implied 4pt-adjacent scale without being declared anywhere. |
| 6. Experience Design | 3/4 | Empty, active, and edge-state (PreStart) coverage all confirmed live; centre-on-open scroll behavior remains genuinely unverified (UAT test 2 still pending). |

**Overall: 18/24**

---

## Top 3 Priority Fixes

1. **Swipe-gesture background colors are still hardcoded** — `lib/screens/schedule/widgets/swipeable_chunk_card.dart:89,92,95,98` (`Colors.green.shade400`, `Colors.white`, `Colors.orange.shade300`) bypass the mood-seeded `ColorScheme` entirely. On a Stormy (mood 1) or Sunny (mood 5) day these two hardcoded hues will visually clash against whatever palette the rest of the screen is using during a swipe gesture — the one interaction moment where the user's eye is most focused on that exact strip of pixels. Fix: swap to `colorScheme.tertiaryContainer`/`onTertiaryContainer` (complete) and `colorScheme.errorContainer`/`onErrorContainer` or a dedicated "skip" semantic slot (skip), matching the precedent already set in `chunk_card.dart`.

2. **Five preamble elements before the first content row** — `lib/screens/today/today_screen.dart` header stack renders progress bar → "Today"+date → mood chip → restoratives card (mood ≤2) → free-time row, all before a user reaches an actual scheduled activity. On the mood-1 desktop screenshot this preamble consumes ~290px of a 900px-tall viewport before "RIGHT NOW" appears — nearly a third of the fold. The UI-SPEC's own "Structure" section describes only two things ("Header" then "The day"); the restoratives card is real functionality but is visually indistinguishable in weight from the header proper. Fix: differentiate the restoratives card's visual weight (smaller, dismissible, or collapsed by default) so mood-gated content doesn't compete with the header for the same visual register, or confirm with Dan that this reflects an intentional trade he's accepted — it isn't called out in 22-UAT.md as tested.

3. **Per-goal left-border-bar accent colors are an unspec'd third accent channel** — `chunk_card.dart:215` (`goalColor ?? theme.colorScheme.primary`) paints a ~4px colored left bar per chunk (visible as orange/blue bars on "Creative time"/"Reading" in the desktop screenshot) that is not in the UI-SPEC's Row Types table at all — the table specifies only `surfaceContainer` + outline for upcoming work chunks. Combined with the live row's `primaryContainer` swell and the commitment rows' `tertiaryContainer` fill, the screen now carries three simultaneous accent languages (live-card blue, goal-color bars, tertiary commitments) fighting for "this is important" attention on one screen. This reads as visually busier than the sketch 001 reference render, which shows plain outlined cards with no left-bar accent. Fix: confirm this is an intentional carryover from `schedule_screen.dart` that Dan wants kept, or drop it — as implemented it dilutes the live row's claim to being the sole focal point (finding #1 in the visuals section below).

---

## Detailed Findings

### Pillar 1: Copywriting (4/4)

- Free-time copy matches the LOCKED contract exactly: `"Free until 4:05 PM"` and `"Free until 4:10 PM"` visible verbatim in both screenshots (`lib/screens/today/widgets/free_time_row.dart`).
- Mood chip copy confirmed at both scale ends per 22-UAT.md test 3 (`🌧 Low day · 3 chunks`, `☀️ Sunny day · 9 chunks`) — matches the desktop/phone screenshots pixel-for-pixel.
- TONE-01 verified live: chunk rationale reads `"Working toward 3.0h this week"`, never "behind." No new instance of behind/short/owing language found anywhere in `lib/screens/today/` or `chunk_card.dart` (grep clean).
- Edge-state copy ("Your day starts at 4:10 PM") renders on the PreStart phone shot, matching the carried-forward `home_screen.dart` content per 22-03-SUMMARY.
- No generic labels (`Submit`, `Click Here`, `OK`, `Cancel`) found in the audited files (grep clean).
- Empty-state copy — "Plan your day in 30 seconds." / "Tell us how you're feeling and we'll build your schedule." / "Start your day" / "Add an event" — all render, already UAT-confirmed; not re-litigated here.

### Pillar 2: Visuals (3/4)

- **Focal point**: the live row does swell distinctly — `primaryContainer` fill against `surfaceContainer`/transparent siblings gives it real separation on both desktop and phone. This is working as designed.
- **Preamble depth**: five stacked elements (progress bar, header, mood chip, restoratives card, first free-time row) precede the timeline's first activity on the desktop mood-1 shot — see Priority Fix #2. This is real "too much before the point" weight, not a nitpick: at mood 1 the restoratives card is ~120px tall on its own.
- **Icon-only buttons**: the `+` (add event) and refresh icons in the AppBar have no visible label or tooltip in the screenshot; not verified whether `Tooltip`/`Semantics` wraps them in code (not re-checked here since 22-UAT didn't flag it, but flagging as unverified rather than passed).
- **Third accent channel**: goal-color left bars compete with the live row and tertiary commitment fill for visual "this matters" signaling — see Priority Fix #3. This is a real hierarchy dilution versus the sketch 001 reference, which shows plain outlined cards.
- Not a repeat of the Phase 21 pill-vs-Card mismatch — confirmed closed per 22-02-SUMMARY and 22-UAT.md Notes; both break variants render identically dashed in both screenshots.

### Pillar 3: Color (2/4)

- `chunk_card.dart` itself is genuinely clean — grep confirms zero raw `Colors.*` literals, and the UI-SPEC's row-type colors (`surfaceContainer`, `tertiaryContainer`, `primaryContainer`, `onSurfaceVariant`) are used correctly per the code and match what's on screen.
- **But `swipeable_chunk_card.dart` (same row-vocabulary family, wraps `ChunkCard` for the exact same rows on this screen) still hardcodes `Colors.green.shade400`, `Colors.white`, `Colors.orange.shade300`** at lines 89/92/95/98. The UI-SPEC explicitly names this class of bug ("the standing `chunk_card.dart` `Colors.green.shade600` tech-debt item; do not add more of it") and 22-02-SUMMARY claims it as "fully closed" via a grep gate scoped only to `chunk_card.dart` — the gate didn't cover the file that wraps it. This is a real, unaddressed instance of the exact debt the contract calls out by name, just moved one file over.
- Not visible in the static screenshots provided (only appears mid-swipe-gesture), so this is a code-level finding rather than a pixel-level one — still real, since it directly affects mood-theming consistency (the whole point of the "every colour comes from ColorScheme" rule) at the one interaction point that reveals it.
- Goal-color left bars (`chunk_card.dart:215`) pull in caller-supplied colors outside the ColorScheme's declared roles — not necessarily a violation (goal colors are presumably user-set data, not decorative color), but not called out anywhere in the UI-SPEC's Row Types table either. Ambiguous provenance; flagged for confirmation, not scored as a hard violation.

### Pillar 4: Typography (3/4)

- Distinct Material text-style tokens found in the today/chunk-card files: `titleLarge`, `titleMedium`, `titleSmall`, `bodyMedium`, `bodySmall`, `labelSmall`, `labelMedium` — 7 semantic tokens, all theme-derived rather than raw point sizes, which is the right pattern for a Material 3 app and is more defensible than a flat "count of sizes" grep against a design-token system.
- One raw `TextStyle(fontSize: 16)` at `today_screen.dart:440`, used only for an emoji glyph inside a restoratives `Chip` avatar (no text-style token supports emoji-as-avatar cleanly) — minor, contained, not part of the row/list reading flow. Not scoring this down further; noting it so it isn't silently normalized as more sizes are added elsewhere.
- Font weights: consistent use of `FontWeight.w600` for emphasis and `FontWeight.bold` in 2 spots — worth checking whether `w600`/`bold` divergence (2 different weight tokens doing similar "emphasized title" work) is intentional or accidental drift; not a blocker.
- Screenshots show consistent hierarchy: header ("Today") is clearly the largest text, live-row title is next, row titles below that, gutter times and durations smallest — this reads correctly at both viewport sizes.

### Pillar 5: Spacing (3/4)

- Dominant spacing values across `today_screen.dart` are 4/8/16/24/32 — a coherent 4pt-multiple rhythm, and the UI-SPEC's stated 46dp gutter is implemented exactly (`kGutterWidth = 46.0`).
- Several one-off values appear that don't fit that rhythm as cleanly: `SizedBox(height: 2)` (line 342), `EdgeInsets.symmetric(horizontal: 10, vertical: 6)` (line 269), `SizedBox(height: 6)` (line 88), `SizedBox(height: 10)` (lines 96, 109, 144). None of these are declared anywhere as an intentional secondary scale (the UI-SPEC has no spacing-scale table at all for this phase, unlike some other phases' contracts) — they read as ad hoc micro-adjustments rather than a deliberate half-step scale.
- Pixel evidence: the desktop screenshot's rows have visually consistent vertical rhythm down the list — gutter times sit top-aligned to each row per spec, and the live card's extra padding reads intentional (not accidental over-spacing). The gap between the header block and the first free-time row is the one place spacing reads heavier than necessary, compounding Priority Fix #2's preamble-depth finding.

### Pillar 6: Experience Design (3/4)

- Empty state: all four affordances (Start your day, Add an event, check-in banner, headline) confirmed present and usable at both viewport widths — already UAT-verified, not re-litigated, but screenshots corroborate it.
- Active state: live row, break rows, upcoming rows, free-time rows all render correctly with real data at both viewport widths (desktop mood 1 / phone mood 5) — corroborates 22-UAT.md test 1.
- PreStart edge state confirmed live on the phone screenshot ("Your day starts at 4:10 PM") — matches carried-forward copy.
- **Centre-on-open scroll behavior remains genuinely unverified** — 22-UAT.md test 2 is still `pending`, and none of the five screenshots provided demonstrate a live row positioned below the fold with the scroll having settled it to center (in every capture the live row is already the first/near-first row, so the mechanism this pillar most wants proof of — "does it actually centre a live row buried 6 rows down" — has no visual evidence either way in this audit). This is the correct thing to flag as still open rather than silently assumed passing.
- No loading-state or error-state widgets found in the audited files' happy-path code (not necessarily wrong for a purely local-data screen, but also not verified as intentionally absent vs. simply missing — Hive read/write against a corrupt or resilient-box-recovered state isn't visibly handled in `today_screen.dart`).
- Complete/Skip actions are labelled buttons (not hover/icon-only) per SCHED-03 — confirmed on desktop screenshot ("Complete"/"Skip" text visible), meeting the inherited contract.

Registry audit: no `components.json` present — shadcn is not in use in this Flutter project. Registry Safety section not applicable, skipped per the audit's own gating rule.

---

## Files Audited

- `lib/screens/today/today_screen.dart`
- `lib/screens/today/widgets/timeline_row_tile.dart`
- `lib/screens/today/widgets/free_time_row.dart`
- `lib/screens/today/widgets/live_row_card.dart`
- `lib/screens/today/widgets/breathing_pulse_cta.dart`
- `lib/screens/today/widgets/end_of_day_card.dart`
- `lib/screens/today/widgets/review_banner.dart`
- `lib/screens/today/now_state.dart`
- `lib/screens/today/timeline.dart`
- `lib/screens/schedule/widgets/chunk_card.dart`
- `lib/screens/schedule/widgets/swipeable_chunk_card.dart`
- `lib/widgets/responsive_shell.dart`
- `lib/router.dart`
- Screenshots: `tl-desktop.png`, `phone-timeline.png`, `scroll-down1.png`, `today-empty-desktop.png`, `phone-empty.png`
