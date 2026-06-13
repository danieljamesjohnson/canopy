# Phase 8 — UI Review

**Audited:** 2026-06-10
**Baseline:** 08-UI-SPEC.md (approved design contract)
**Screenshots:** Not captured (no dev server — code-only audit)

---

## Pillar Scores

| Pillar | Score | Key Finding |
|--------|-------|-------------|
| 1. Copywriting | 2/4 | Empty-state AppBar wrong title; focus screen shows raw rationale strings; Deferred badge missing |
| 2. Visuals | 2/4 | Skipped section cards missing goalName/displayRationale — titles show raw generator strings |
| 3. Color | 3/4 | One hardcoded `Colors.amber` on empty-state icon; all ColorScheme assignments otherwise correct |
| 4. Typography | 3/4 | Short break card uses raw `fontSize: 12` instead of `textTheme.bodySmall` |
| 5. Spacing | 2/4 | `SizedBox(height: 2)` used in two places; break card `vertical: 2` margin — all below xs=4 minimum |
| 6. Experience Design | 2/4 | Focus screen rationale unmapped; Deferred badge absent from skipped section; skipped cards lose goal name |

**Overall: 14/24**

---

## Top 3 Priority Fixes

1. **Skipped section cards missing goalName and displayRationale** — Users see "Habit" and "Outcome goal" raw strings as titles for all skipped work chunks, directly breaking the READ-01 headline goal. In `schedule_screen.dart` line 158, change `ChunkCard(chunk: chunk, goalColor: goalColor)` to also pass `goalName: _lookupGoalName(context, chunk)` and `displayRationale: _toDisplayRationale(chunk.rationale)`.

2. **Focus screen shows raw rationale strings** — `displayRationale` on `focus_screen.dart` line 155 is `chunk?.rationale ?? ''` which exposes "Habit", "Outcome goal", "Weekly goal" to users. Replace with `ScheduleScreen._toDisplayRationale(chunk?.rationale ?? '')` or extract the mapping to a shared utility and call it here.

3. **Deferred badge absent from skipped section** — The spec declares `'Deferred'` as a visible chip/Text beside deferred chunks in the skipped section. `_buildSkippedSection` renders no deferred indicator. Add an `if (chunk.isDeferred) Chip(label: Text('Deferred'))` or equivalent `Text` widget inside the skipped section's chunk builder.

---

## Detailed Findings

### Pillar 1: Copywriting (2/4)

**WARNING — Empty-state AppBar title mismatch**
`schedule_screen.dart` line 229: `AppBar(title: const Text('Schedule'))` in `_buildEmptyState`. The contract specifies `'Today'` as the schedule screen AppBar title universally. The non-empty state correctly shows `'Today'` (line 44) but the empty state reverts to `'Schedule'`. Fix: change `Text('Schedule')` to `Text('Today')`.

**BLOCKER — Focus screen shows raw rationale strings**
`focus_screen.dart` line 155: `final displayRationale = chunk?.rationale ?? '';` This passes the unprocessed generator string ("Habit", "Outcome goal", "Weekly goal") directly into the body text of the focus screen. Users see internal vocabulary that the spec explicitly prohibits. The mapping function `_toDisplayRationale` exists in `schedule_screen.dart` but is not called from `focus_screen.dart`.

**WARNING — Deferred badge absent**
Copywriting contract specifies `'Deferred'` text as a chip or Text shown alongside deferred chunks in the skipped section. `_buildSkippedSection` in `schedule_screen.dart` (lines 156–159) builds `ChunkCard` without any check of `chunk.isDeferred` and without rendering any badge. The copy is specified but never rendered.

**PASS items:** All action button labels in `chunk_detail_sheet.dart` are exact contract matches. All timer state labels in `focus_screen.dart` match exactly. Break suggestion strings match exactly. Rationale mappings in `schedule_screen._toDisplayRationale` match exactly.

---

### Pillar 2: Visuals (2/4)

**BLOCKER — Skipped chunk cards show raw generator strings as titles**
`schedule_screen.dart` line 157–159: The skipped section builds `ChunkCard(chunk: chunk, goalColor: goalColor)` without `goalName` or `displayRationale`. Inside `_HoverableChunkContent`, when `goalName` is null, the title falls back to `chunk.rationale` (line 225–228). This means every skipped work card displays "Habit", "Outcome goal", or "Weekly goal" as the primary title — the exact illegibility that READ-01 was designed to fix. The skipped section is visually regressed compared to the active section.

**WARNING — No Deferred visual indicator**
The skipped section has no visual distinction between skipped and deferred chunks. A user who deferred a chunk cannot identify it in the list. The spec requires a visible badge.

**PASS items:** Drag handle dimensions match spec exactly (32×4, alpha 0.4, radius 2). Goal color mini-bar in detail sheet matches spec (4×48, radius 2). Left bar on work cards is 5dp via `Positioned(width: 5)` — correct. `primaryContainer` card on focus screen matches the Surface 4 spec. Circular progress indicator present with goal color. "Start focus" entry point in AppBar has correct `tooltip: 'Start focus'`. Break cards are visually unchanged.

---

### Pillar 3: Color (3/4)

**WARNING — Hardcoded `Colors.amber` for empty-state icon**
`schedule_screen.dart` line 258: `color: Colors.amber` on the empty-state `Icon`. This is not a `ColorScheme` token. Replace with `colorScheme.tertiary` or `colorScheme.primary` to stay within the theme system.

**PASS items:** Accent (`colorScheme.primary`) is used only on: left bar fallback, `FilledButton` fills (Mark complete, Start timer), and the countdown ring — all approved by the contract. `Defer to later` uses `colorScheme.error` as foreground, consistent with the destructive badge intent. Break cards use `surfaceContainerHighest` — no accent bleed. `Colors.green.shade600` for completed check icon — preserved as specified. `Colors.grey.shade400` for resolved left bar — preserved. Mood colors in AppBar are unchanged from prior phases.

---

### Pillar 4: Typography (3/4)

**WARNING — Short break card uses hardcoded `fontSize: 12`**
`chunk_card.dart` lines 89–92: `TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)`. The spec states "Do not introduce custom `TextStyle` sizes — rely on the theme's scale." `bodySmall` from Material 3 defaults to 12sp and carries the correct line-height and letter-spacing. Replace with `theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)`.

**PASS items:** `titleMedium + FontWeight.w600` applied correctly on chunk card primary text (line 229–231), detail sheet heading (line 80–82), and focus screen goal name (line 194–196). `bodySmall` for secondary text on cards — correct. `bodyMedium` for rationale in sheet and focus screen — correct. `displaySmall + FontWeight.w300` for timer display (line 237–239) — exact match. Long break card uses `bodyMedium` — correct. Exactly 4 TextTheme roles in use as specified.

---

### Pillar 5: Spacing (2/4)

**WARNING — Sub-scale `SizedBox(height: 2)` used in two locations**
`chunk_card.dart` line 249: `const SizedBox(height: 2)` between title and secondary rationale text.
`chunk_detail_sheet.dart` line 85: `const SizedBox(height: 2)` between goal name and rationale.
The spec's minimum spacing token is xs = 4dp. A 2dp gap is not in the spacing scale. Replace both with `const SizedBox(height: 4)` (xs token).

**WARNING — Break card vertical margin is 2dp (non-standard)**
`chunk_card.dart` line 73: `margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 16)`. The vertical margin of 2dp is below the 4dp minimum. Should be `vertical: 4` to match the work card margin and meet the spacing scale minimum.

**PASS items:** Card horizontal margin `horizontal: 16` — correct md token. Drag handle padding `top: 12, bottom: 8` — exact spec match. Focus screen body padding `horizontal: 24` — within the lg token range. `SizedBox(height: 48)` for timer gaps — correct 2xl token. `SizedBox(height: 24)` for empty-state section gaps — correct lg token. `EdgeInsets.symmetric(horizontal: 32)` for empty-state horizontal padding — correct xl token. Left bar width 5dp — preserved as specified exception. Work card vertical padding `vertical: 12` — preserved as specified exception.

---

### Pillar 6: Experience Design (2/4)

**BLOCKER — Skipped section loses goal name resolution**
Discussed under Pillar 2. All skipped work cards show raw rationale strings. This is the primary UX goal of the phase, broken in the skipped section.

**WARNING — Focus screen rationale not human-readable**
`focus_screen.dart` line 155 uses unprocessed `chunk?.rationale`. When the focus screen is entered on a "Habit" chunk, the body text inside the `primaryContainer` card reads "Habit" — internal vocabulary exposed to the user.

**WARNING — Deferred chunks not visually distinguished**
The `isDeferred` field exists (it is referenced in `notifier.markDeferred`) but `_buildSkippedSection` never reads it. A user cannot tell which chunks they deferred vs. skipped. The `'Deferred'` badge specified in the contract is absent.

**PASS items:** Timer `dispose()` correctly cancels `_timer` (line 50). `_popScheduled` guard prevents double-pop on resolved-chunk arrival. Post-timer `_markedComplete` guard disables "Mark complete" after first tap — idempotency protected. Two-tap confirmation for destructive actions (sheet open → tap Skip/Defer) is the correct intentional flow. `showModalBottomSheet` with `isDismissible: true` (default) — correct. Focus screen auto-pops immediately if chunk is already resolved. Empty state with actionable "Start your day" CTA is present. `GestureDetector` is correctly inside `Dismissible` child via the `_HoverableChunkContent` → `SwipeableChunkCard` nesting, preserving swipe gestures.

---

## Registry Safety

Not applicable — Flutter/Dart project with no shadcn registry.

---

## Files Audited

- `/home/dan/CodeProjects/canopy/lib/screens/schedule/widgets/chunk_card.dart`
- `/home/dan/CodeProjects/canopy/lib/screens/schedule/widgets/chunk_detail_sheet.dart`
- `/home/dan/CodeProjects/canopy/lib/screens/schedule/schedule_screen.dart`
- `/home/dan/CodeProjects/canopy/lib/screens/focus/focus_screen.dart`
- `/home/dan/CodeProjects/canopy/.planning/phases/08-a-schedule-you-can-read/08-UI-SPEC.md`
- `/home/dan/CodeProjects/canopy/.planning/phases/08-a-schedule-you-can-read/08-CONTEXT.md`
