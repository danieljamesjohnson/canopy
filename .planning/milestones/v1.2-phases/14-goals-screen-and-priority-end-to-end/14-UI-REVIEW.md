# Phase 14 — UI Review

**Audited:** 2026-06-13
**Baseline:** 14-UI-SPEC.md (approved design contract)
**Screenshots:** Not captured — Flutter app, no browser dev server

---

## Pillar Scores

| Pillar | Score | Key Finding |
|--------|-------|-------------|
| 1. Copywriting | 4/4 | All spec-required strings match exactly |
| 2. Visuals | 3/4 | Drag handle AnimatedOpacity never changes — no MouseRegion wired |
| 3. Color | 2/4 | Two hardcoded Colors references in chunk_card.dart violate ColorScheme-only contract |
| 4. Typography | 3/4 | Code correct (labelMedium); 14-02-SUMMARY.md claims labelSmall — documentation mismatch |
| 5. Spacing | 3/4 | Heading bottom padding is 4dp; spec §Spacing says 8dp for heading row |
| 6. Experience Design | 3/4 | Drag hover brightening omitted; present in spec §Hover States but not wired |

**Overall: 18/24**

---

## Top 3 Priority Fixes

1. **Hardcoded Colors in chunk_card.dart** — completed/skipped bar uses `Colors.grey.shade400` (line 142) and completed status icon uses `Colors.green.shade600` (line 262); these bypass the `ColorScheme` system, will not adapt to mood theme changes, and violate the stated color contract ("All colors use ColorScheme tokens"). Replace with `colorScheme.outlineVariant` for the resolved bar and `colorScheme.primary` (or a semantic token) for the completed check icon.

2. **Desktop drag handle hover brightening not wired** — `AnimatedOpacity(opacity: 0.6)` is constructed with a fixed value and never driven by a `MouseRegion` state change. The spec §Hover States requires `opacity 0.6 → 1.0 on MouseRegion enter; 1.0 → 0.6 on exit`. As built, the animation widget exists but is inert. Add a `MouseRegion(onEnter/onExit)` around the drag handle container and drive the `AnimatedOpacity` opacity from a stateful boolean (same pattern as the GoalCard hover icons).

3. **14-02-SUMMARY.md contains a false typography decision** — the Decisions section states "_PriorityChip uses `textTheme.labelSmall`" but the code in chunk_card.dart:375 and active_chunk_card.dart:240 both use `textTheme.labelMedium`. Future developers reading the SUMMARY will be misled about which text role to use when modifying the chip. Correct the SUMMARY to state `labelMedium`.

---

## Detailed Findings

### Pillar 1: Copywriting (4/4)

All copywriting contract entries verified against source:

| Spec string | Location | Status |
|-------------|----------|--------|
| "Your goals" | goals_screen.dart:117 | PASS |
| "Drag to prioritize. Tap to edit." | goals_screen.dart:124 | PASS |
| "Regular time" | goals_screen.dart:136 | PASS |
| "Working toward" | goals_screen.dart:143 | PASS |
| "Daily habits" | goals_screen.dart:151 | PASS |
| "Drag to reorder" (tooltip) | goals_screen.dart:231 | PASS |
| "High" (chip) | goal_card.dart:249, chunk_card.dart, active_chunk_card.dart | PASS |
| "Low" (chip) | goal_card.dart:253, chunk_card.dart, active_chunk_card.dart | PASS |
| "Add goal" (FAB) | goals_screen.dart:168 | PASS |
| "No goals yet" | goals_screen.dart:305 | PASS |
| "Add your first goal" | goals_screen.dart:308 | PASS |
| "Complete" (button) | active_chunk_card.dart:155 | PASS |
| "Skip" (button) | active_chunk_card.dart:169 | PASS |

No generic labels ("Submit", "OK", "Cancel") found in audited files. Tone is direct and lowercase for labels as specified. No exclamation marks. No deviations from the copywriting contract.

### Pillar 2: Visuals (3/4)

**WARNING — Drag handle hover animation inert (desktop):**
`goals_screen.dart` lines 241–249 wraps the `Icons.drag_indicator` in `AnimatedOpacity(duration: 120ms, opacity: 0.6)` but the opacity value is hardcoded — there is no `StatefulWidget` field or `MouseRegion` callback that drives the value from 0.6 to 1.0. The animation widget fires once at construction and then never transitions. Spec §Hover States and §Animation table both require this transition. This was explicitly scoped out per research (14-01-SUMMARY.md: "Hover-brightening omitted — explicitly OUT of scope"), but the spec itself was not updated to remove the requirement. Impact: desktop users lose a subtle feedback cue that the handle is interactive.

**PASS — Mobile drag handle always visible:**
`Icons.drag_indicator` (size 20, `outlineVariant` color) rendered unconditionally on Android/iOS with `ReorderableDelayedDragStartListener`. Correct per spec §Adaptive Layout.

**PASS — SizedBox(44,44) touch target on desktop:**
goals_screen.dart lines 237–239 wrap the icon in `SizedBox(width: 44, height: 44)` with `Center`. Meets minimum touch target.

**PASS — Semantics label on drag handle:**
Both branches wrap with `Semantics(label: 'Drag to reorder', button: false)` — correct per §Accessibility.

**PASS — Priority chip accessibility:**
All three `_PriorityChip` instances use icon + label text, not color alone. Screen readers will encounter meaningful content.

**NEEDS HUMAN REVIEW (4 UAT items, not statically verifiable):**
- Priority tier visual distinctness at runtime (High vs Low chip contrast)
- Drag affordance subjective clarity (whether `outlineVariant` icon reads as draggable)
- Whether "Your goals" heading communicates screen purpose to first-time users
- End-to-end observability: does a priority change in the form produce a visible chip and a measurable schedule shift?

### Pillar 3: Color (2/4)

**BLOCKER — Hardcoded Colors in chunk_card.dart:**

`lib/screens/schedule/widgets/chunk_card.dart`:
- Line 142: `Colors.grey.shade400` — used as `barColor` for completed/skipped chunks. This is not a `ColorScheme` token. On a custom mood theme with a dark seed, `grey.shade400` may produce incorrect contrast or clash with the surface color.
- Line 262: `Colors.green.shade600` — used for the completed `Icons.check_circle`. Green is a semantic choice for "completed" but `green.shade600` is not theme-adaptive. The app's `ColorScheme.fromSeed` generates a dynamic color set; a seed near red/orange (the current `Colors.deepOrangeAccent`) produces a green complementary color that may differ from `Colors.green.shade600`.

Replacements per spec:
- `Colors.grey.shade400` → `colorScheme.outlineVariant` (communicates "resolved/inactive" using theme-aware muted color)
- `Colors.green.shade600` → `colorScheme.tertiary` or a dedicated semantic token; alternatively `Colors.green.shade600` can be retained if the team explicitly accepts it as a universal "success green" outside the theme system — but this must be a documented exception, not a silent deviation.

**PASS — Priority chip colors:**
All three `_PriorityChip` instances use spec-compliant color tokens:
- High: `colorScheme.primaryContainer` / `colorScheme.onPrimaryContainer`
- Low: `colorScheme.surfaceContainerHighest` / `colorScheme.onSurfaceVariant`

**PASS — "Now" badge:**
`active_chunk_card.dart` line 126: `colorScheme.primary` fill, `colorScheme.onPrimary` text. Correct accent usage within the 10% budget.

**PASS — Color-only check:**
Priority differentiation uses icon + label in addition to chip color. Accessible.

### Pillar 4: Typography (3/4)

**WARNING — 14-02-SUMMARY.md documents wrong text role:**
The Decisions section of 14-02-SUMMARY.md (line 26) states: "_PriorityChip uses `textTheme.labelSmall` (not labelMedium) per the PATTERNS.md §goal_card.dart spec." However, the actual code in all three files uses `textTheme.labelMedium`:
- goal_card.dart:272 — `textTheme.labelMedium?.copyWith(...)`
- chunk_card.dart:375 — `textTheme.labelMedium?.copyWith(...)`
- active_chunk_card.dart:240 — `textTheme.labelMedium?.copyWith(...)`

The code is correct. The summary is wrong. This is a documentation integrity failure that will mislead future developers about which text role the chip uses.

**PASS — Chip typography correct in code:**
`labelMedium` = 12sp per Material 3 spec. Spec §Typography says "Priority chip label: labelMedium 12sp w600". All three implementations match.

**PASS — Heading typography:**
goals_screen.dart:118 — `theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)` — matches spec "titleMedium 16sp w600".

**PASS — Subhead typography:**
goals_screen.dart:125 — `theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)` — matches spec.

**PASS — Section headers:**
`titleSmall` in `colorScheme.primary` — matches spec "existing — retain".

Two weights in use across audited files: w400 (body/label default) and w600 (headings, chips). Matches the two-weight constraint.

### Pillar 5: Spacing (3/4)

**WARNING — Heading bottom padding 4dp vs spec 8dp:**
goals_screen.dart line 111: `EdgeInsets.fromLTRB(16, 16, 16, 4)`. The spec §Spacing "Screen header section" entry says `Padding(fromLTRB(16, 16, 16, 8))`. The bottom padding is 4dp in code vs 8dp in spec — half the specified gap between the subhead and the first section header. Visual impact: the subhead sits slightly tight above the first section label. Minor but measurable spacing deviation.

**PASS — Priority chip internal spacing:**
All three chips: `EdgeInsets.symmetric(horizontal: 8, vertical: 4)` and `SizedBox(width: 4)` icon gap. Matches spec exactly (8/4 padding, 4dp gap).

**PASS — Card border radius:** 12dp all cards — goal_card.dart:82, chunk_card.dart:154, active_chunk_card.dart:55.

**PASS — Left bar widths:**
- GoalCard: `width: 5` (goal_card.dart:96) — matches spec "5dp exception"
- ChunkCard: `width: 4` (chunk_card.dart:165) — matches spec "4dp"
- ActiveChunkCard: `width: 4` (active_chunk_card.dart:66) — matches spec

**PASS — Touch target:** goals_screen.dart:237 `SizedBox(width: 44, height: 44)` — meets 44dp minimum.

**PASS — Section header content padding:** `fromLTRB(16, 16, 16, 4)` for section headers is consistent with existing phase conventions.

**PASS — Card margins:** `EdgeInsets.symmetric(horizontal: 16, vertical: 4)` on goal cards; same on chunk cards. Consistent.

No arbitrary pixel values (`[Xpx]` style or raw `px` constants) found in audited Dart files.

### Pillar 6: Experience Design (3/4)

**WARNING — AnimatedOpacity hover transition not driven:**
Described in Pillar 2 but scored here as the interaction-design finding. The `AnimatedOpacity` widget exists at goals_screen.dart:241 but `opacity` is always `0.6` — no state transitions occur. This means desktop users get no hover feedback on the drag affordance, reducing discoverability. The animation infrastructure is present but dormant.

**PASS — Empty state:**
`_EmptyState` widget (goals_screen.dart:290–316): `Icons.flag_outlined` at 64dp (matches spec "3xl token = 64dp"), "No goals yet" in `titleMedium`, "Add your first goal" in `bodyMedium` with `outline` color. All three required elements present.

**PASS — Priority chip show/hide logic:**
`showPriorityChip = pw >= 0.75 || pw <= 0.25` (goal_card.dart:79) — correct guard. `pw` null-coalesced to 0.5 before check. Commitment chunks pass `null` → no badge.

**PASS — Reorder writes priority:**
`_buildReorderableSection` wires `onReorderItem` to `reorderAllWithPriority` via `_buildFullOrderedIds` helper. Priority weight cascade on drag confirmed at goals_screen.dart:258–264.

**PASS — No loading state (acceptable per spec):**
Spec explicitly states no shimmer/skeleton needed for Phase 14. `GoalsNotifier.loadGoals()` called in `addPostFrameCallback`; notifier's `_goals` is pre-seeded in tests via `InMemoryGoalRepository`.

**PASS — Destructive action (archive):**
No confirmation dialog, per spec "archive is reversible — retain as-is." Error snackbar copy pre-existing, not changed.

**PASS — Commitment chunk nil priority:**
`chunk.goalId == null` path returns `null` for `goalPriorityWeight` in both `schedule_screen.dart` (via `_lookupGoalPriorityWeight`) and `active_chunk_card.dart` (via `_lookupGoalPriorityWeight`). No badge rendered. Correct.

---

## Files Audited

- `lib/screens/goals/goals_screen.dart` (317 lines)
- `lib/screens/goals/widgets/goal_card.dart` (282 lines)
- `lib/screens/schedule/widgets/chunk_card.dart` (384 lines)
- `lib/screens/home/widgets/active_chunk_card.dart` (249 lines)
- `.planning/phases/14-goals-screen-and-priority-end-to-end/14-UI-SPEC.md`
- `.planning/phases/14-goals-screen-and-priority-end-to-end/14-01-SUMMARY.md`
- `.planning/phases/14-goals-screen-and-priority-end-to-end/14-02-SUMMARY.md`

Registry audit: not applicable (Flutter project, no shadcn, no third-party component registries per UI-SPEC §Registry Safety).
