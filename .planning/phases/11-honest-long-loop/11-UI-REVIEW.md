# Phase 11 — UI Review

**Audited:** 2026-06-11
**Baseline:** 11-UI-SPEC.md (approved design contract)
**Screenshots:** not captured (no dev server detected)

---

## Pillar Scores

| Pillar | Score | Key Finding |
|--------|-------|-------------|
| 1. Copywriting | 4/4 | All three new legend label strings match spec exactly |
| 2. Visuals | 3/4 | Archived-goal slice order follows map iteration, not spec-required alpha sort |
| 3. Color | 4/4 | Commitments (#607D8B) and Other (#BDBDBD) match spec; palette-collision risk documented in code |
| 4. Typography | 4/4 | New legend rows use bodySmall for both label and pct; no new text roles introduced |
| 5. Spacing | 2/4 | Legend row vertical padding is 2px; UI-SPEC declares sm (8px) for this token |
| 6. Experience Design | 4/4 | Zero-value slice guard on all five slice types; totalValue > 0 divide-by-zero guard; allLogs.isEmpty empty-state guard wired |

**Overall: 21/24**

---

## Top 3 Priority Fixes

1. **Legend row vertical padding is 2px, not 8px** — Legend rows are cramped relative to the spec-declared sm (8px) token; on a device with many slices (3+ goals + archived + Commitments + Other + Time not spent) the dot and text run together visually, reducing scan speed. Change `EdgeInsets.symmetric(vertical: 2)` at `donut_chart.dart:195` to `EdgeInsets.symmetric(vertical: 4)` to use xs, or to `EdgeInsets.symmetric(vertical: 4)` with a row min-height, or exactly `vertical: 8` to match the sm token. WARNING.

2. **Archived-goal slice order does not guarantee alphabetical legend rows** — The UI-SPEC §Donut Chart Slice Contract states archived slices appear "sorted alphabetically by name." The implementation iterates `goalChunkTotals.entries` (a `HashMap`, unordered) and resolves against `archivedGoalMap`; the resulting legend order is insertion-order-dependent, not alphabetical. A user with multiple archived goals will see them in an arbitrary order. Fix: sort `archivedGoals` by name before building `archivedGoalMap`, or collect archived entries into a list and sort by `goal.name` before appending to `sections`/`legendEntries`. WARNING.

3. **legend row padding deviation produces a compounded visual issue when the "Time not spent" row is present** — The existing "Time not spent" row (inherited from Phase 5) also uses `vertical: 2`, so the full legend block is consistently tight. This is technically a pre-existing inherited issue; however Phase 11 adds new rows (Commitments, archived-goal, Other) that make the legend taller, amplifying the cramped appearance. Fixing item 1 above resolves this. WARNING.

---

## Detailed Findings

### Pillar 1: Copywriting (4/4)

All three new legend label strings match the copywriting contract exactly:

- `donut_chart.dart:106` — `'${goal.name} (archived)'` — matches spec `"{Goal Name} (archived)"`, space before parenthetical, no special casing. PASS.
- `donut_chart.dart:132` — `'Commitments'` — title case, no suffix. PASS.
- `donut_chart.dart:149` — `'Other'` — single word. PASS.

Inherited locked strings confirmed present:
- `data_section.dart:141` — `'Next: Reflect'` — unchanged. PASS.

No generic CTAs ("Submit", "OK", "Save") found in changed files. No new error states introduced. The existing empty-state copy path is unchanged. No findings.

### Pillar 2: Visuals (3/4)

**WARNING: Archived-goal slice sort order** — `donut_chart.dart:84–113`: the classification loop iterates `goalChunkTotals.entries`. Dart's `Map` (defaulting to `LinkedHashMap` for map literals, but `HashMap` when built via `{for ... }`) does not guarantee alphabetical iteration order. The `archivedGoalMap` is built as `{for (final g in archivedGoals) g.id: g}` at line 60; iteration order mirrors the `archivedGoals` list order, which comes from `GoalsNotifier.getArchivedGoals()`. If that method returns goals in creation order rather than alphabetical order, the legend rows for archived goals will be non-alphabetical, violating UI-SPEC §Donut Chart Slice Contract ("sorted alphabetically by name").

No other visual hierarchy issues introduced. The donut's `centerSpaceRadius: 60`, `radius: 50`, `sectionsSpace: 2`, and `CircleAvatar(radius: 6)` for legend dots are all consistent with the established Phase 5 design. No icon-only buttons added. The chart height `SizedBox(height: 200)` is unchanged.

### Pillar 3: Color (4/4)

New hardcoded color values are both spec-compliant:

- `donut_chart.dart:120` — `const Color(0xFF607D8B)` — matches spec "Blue-Grey 500" value exactly.
- `donut_chart.dart:139` — `const Color(0xFFBDBDBD)` — matches spec "Grey 400" value exactly.

The palette-collision risk for `0xFF607D8B` (shared with `GoalsNotifier.colorPalette` index 7) is documented in a code comment at line 117–118, as required by the spec. The "Time not spent" slice continues to use `theme.colorScheme.outlineVariant` (unchanged, Phase 5 D-02). No use of `Colors.primary` or any accent color on chart slices or legend dots — compliant with the spec's accent-reserved-for-CTA-only rule. No findings.

### Pillar 4: Typography (4/4)

New legend rows in `donut_chart.dart`:

- Label text at line 203: `style: theme.textTheme.bodySmall` — matches spec "Body (legend label)" role (12sp, Regular 400). PASS.
- Percentage text at line 209: `style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)` — same role, correct muted color. PASS.

No new text roles introduced. All four declared typography roles (`bodySmall`, `bodyMedium`, `titleMedium`, `titleLarge` with fontSize override) remain at their correct usages in `data_section.dart`. No findings.

### Pillar 5: Spacing (2/4)

**WARNING: Legend row vertical padding deviates from spec.**

UI-SPEC spacing table, `data_section.dart` column, declares `sm = 8px` for "Legend row vertical padding." Implementation uses `EdgeInsets.symmetric(vertical: 2)` at `donut_chart.dart:195` — a 2px value that does not appear in the spacing scale at all (scale: 4, 8, 16, 24, 32, 48, 64). The 2px value is below xs (4px).

Other spacing values in the changed files are compliant:
- `SizedBox(height: 8)` between chart and legend at `donut_chart.dart:186` — `sm` token, PASS.
- `EdgeInsets.symmetric(horizontal: 16)` on legend padding at `donut_chart.dart:189` — `md` token, PASS.
- `SizedBox(width: 8)` between dot and label at `donut_chart.dart:199` — `sm` token, PASS.
- All `data_section.dart` spacing (32, 24, 16, 48) maps to xl, lg, md, 2xl respectively — PASS.

The one deviation is `vertical: 2` on each legend row. With 7 rows possible (5 goal types + Commitments + Other + Time not spent), the aggregate cramping is visible: 7 rows × 4px total vertical (2 top + 2 bottom) = 28px vs the spec-declared 7 rows × 16px = 112px. The legend block would be approximately 84px shorter than intended, making the rows difficult to tap and scan on mobile.

**Concrete fix:** `donut_chart.dart:195` — change `EdgeInsets.symmetric(vertical: 2)` to `EdgeInsets.symmetric(vertical: 4)` at minimum (xs token) or `EdgeInsets.symmetric(vertical: 8)` to match the spec's sm token declaration.

### Pillar 6: Experience Design (4/4)

Zero-value slice guard is correctly applied on all five slice types:
- Active goal slices: `donut_chart.dart:70` — `if (count == 0) continue`
- Archived goal slices: `donut_chart.dart:87` — `if (entry.value == 0) continue`
- Commitments slice: `donut_chart.dart:119` — `if (commitmentTotal > 0)`
- Other slice: `donut_chart.dart:138` — `if (otherTotal > 0)`
- Time not spent slice: `donut_chart.dart:153` — `if (notSpentCount > 0)`

Divide-by-zero guard on percentage calculation: `totalValue > 0 ? ... : 0.0` applied at lines 72, 95, 121, 140, 154. PASS.

Empty-state guard fix confirmed: `quarterly_review_screen.dart` now uses `allLogs.isEmpty` (REVIEW-03), replacing the broken `totalCompleted == 0 && goals.isEmpty` condition. PASS.

`reorderAllWithPriority` correctly handles the `n == 1` edge case (single goal gets `0.75`, no division by zero). PASS.

No new user-facing states require loading spinners or error boundaries — the data changes are in-process reads of already-loaded providers. Inherited states (screen-level loading, empty state, Hive error paths) are unchanged and not in scope for this phase.

Registry audit: not applicable — Flutter project, no shadcn, no npm registries. `fl_chart` is a pre-existing pub.dev dependency with no version change in this phase.

---

## Files Audited

- `lib/screens/quarterly_review/widgets/donut_chart.dart`
- `lib/screens/quarterly_review/sections/data_section.dart`
- `lib/screens/quarterly_review/quarterly_review_screen.dart` (call sites only)
- `.planning/phases/11-honest-long-loop/11-UI-SPEC.md`
- `.planning/phases/11-honest-long-loop/11-01-SUMMARY.md`
- `.planning/phases/11-honest-long-loop/11-02-SUMMARY.md`
