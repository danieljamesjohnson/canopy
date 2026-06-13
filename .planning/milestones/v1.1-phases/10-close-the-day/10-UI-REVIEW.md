---
phase: 10
slug: close-the-day
audited: 2026-06-11
baseline: 10-UI-SPEC.md (approved)
screenshots: not captured (no dev server detected)
---

# Phase 10 — UI Review

**Audited:** 2026-06-11
**Baseline:** 10-UI-SPEC.md (approved design contract)
**Screenshots:** Not captured — no dev server at localhost:3000/5173/8080. Audit is code-only.

---

## Pillar Scores

| Pillar | Score | Key Finding |
|--------|-------|-------------|
| 1. Copywriting | 4/4 | All contract strings match exactly; dismiss tooltip present |
| 2. Visuals | 3/4 | Card structure matches spec; dismiss icon color not explicitly set to onSurfaceVariant |
| 3. Color | 3/4 | Card background and button correct; dismiss IconButton missing explicit onSurfaceVariant color |
| 4. Typography | 4/4 | titleMedium/bold heading, bodySmall/onSurfaceVariant subtitle — exact spec pattern |
| 5. Spacing | 4/4 | All spacing values match declared scale; padding matches ReviewBanner pattern |
| 6. Experience Design | 4/4 | Dismissible wraps card, session state reset on schedule change, trigger logic extracted for testability |

**Overall: 22/24**

---

## Top 3 Priority Fixes

1. **Dismiss icon missing explicit `color: colorScheme.onSurfaceVariant`** — WARNING — The UI-SPEC declares the dismiss `IconButton` uses `onSurfaceVariant` (not accent/primary). The implemented `IconButton` at `end_of_day_card.dart:62–67` passes no `color:` argument and no `style:`. Material 3 will render the icon in `onSurfaceVariant` by default in most themes, but the contract explicitly requires this token; under certain mood seeds the default could resolve differently. Fix: add `color: colorScheme.onSurfaceVariant` to the `Icon(Icons.close)` or use `IconButton(style: IconButton.styleFrom(foregroundColor: colorScheme.onSurfaceVariant))`.

2. **`_formatMinutes` Evening subtitle shows `eveningMinutes` variable, not the literal `1200`** — WARNING (minor spec fidelity) — The spec says `_formatMinutes(1200)` (hardcoded) because the time is fixed this phase and there is no time picker. The implementation passes `eveningMinutes` (from `settings.eveningReminderMinutes`) at `settings_screen.dart:173`. If the persisted value drifts from 1200 (e.g., a future migration bug), the subtitle would silently show the wrong time. This is a defensive correctness concern, not a visual bug today since `eveningReminderMinutes` defaults to 1200. Acceptable at this phase, but worth noting.

3. **Section heading `fontWeight.w600` deviates from typography contract** — WARNING (minor) — `settings_screen.dart:77` uses `.copyWith(fontWeight: FontWeight.w600)` for the "Notifications" section heading. The typography table declares only `w400` and `w700` as the two weights in use. `w600` is a third weight not in the declared two-weight system. Impact is subtle (semibold vs bold), but it violates the "two-weight only" contract stated in the spec. The existing mid-day nudge section heading was already built this way (pre-existing), so this is not a regression introduced by Phase 10 — but it remains a contract deviation.

---

## Detailed Findings

### Pillar 1: Copywriting (4/4)

All copywriting contract strings are implemented exactly:

- `end_of_day_card.dart:55` — "How did today go?" — PASS
- `end_of_day_card.dart:71` — `'$resolved of $total chunks done'` — PASS (matches "X of Y chunks done" pattern)
- `end_of_day_card.dart:84` — "Close the day" — PASS
- `end_of_day_card.dart:65` — `tooltip: 'Dismiss'` — PASS (accessibility contract met)
- `settings_screen.dart:170` — `Text('Evening reminder')` — PASS
- `settings_screen.dart:173–174` — `'Opt-in reminder to close your day'` when off — PASS
- `settings_screen.dart:172` — `_formatMinutes(eveningMinutes)` when on (resolves to "8:00 PM" at default 1200) — PASS with caveat noted in Priority Fix #2

No generic labels ("Submit", "OK", "Cancel") found in new components.

### Pillar 2: Visuals (3/4)

Card structure matches the UI-SPEC layout pseudocode exactly:
- `Dismissible` wraps `Card` — PASS
- `Card` with `colorScheme.primaryContainer` — PASS
- `margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8)` — PASS
- `Row` with `Expanded` (text column) + `Padding`-wrapped `ElevatedButton` — PASS
- Inner `Row` with `Expanded(Text(...))` + `IconButton(Icons.close)` — PASS
- `Text(subtitle)` below heading row — PASS

WARNING: The dismiss `IconButton` at `end_of_day_card.dart:62–67` does not explicitly set `color:` on the `Icon` or `foregroundColor` on the button style. The spec states the dismiss icon uses `onSurfaceVariant`. While Material 3 defaults often produce this color, it is not guaranteed across all mood-seeded `ColorScheme` variants. The `ElevatedButton` (accent element) appears adjacent, so if the dismiss icon renders with primary color instead of muted onSurfaceVariant, the visual hierarchy (accent reserved for CTA only) would be violated.

Settings row at `settings_screen.dart:168–192` mirrors the mid-day nudge row structure exactly as specified — icon, title, subtitle, Switch, `onTap: null`. PASS.

### Pillar 3: Color (3/4)

Card:
- `colorScheme.primaryContainer` for card background (`end_of_day_card.dart:37`) — PASS, matches ReviewBanner continuity requirement
- `ElevatedButton` inherits `colorScheme.primary` fill by Material 3 default — PASS, accent correctly reserved for single CTA
- `colorScheme.onSurfaceVariant` on subtitle text (`end_of_day_card.dart:73`) — PASS

WARNING: Dismiss icon color not explicitly set — see Pillar 2 and Priority Fix #1. Under the 60/30/10 contract, accent (`colorScheme.primary`) must be reserved for the ElevatedButton only. An unstyled `IconButton` in Material 3 uses `onSurfaceVariant` as default in most themes, but the contract requires it to be explicit.

No hardcoded hex values found in new components. No `Colors.` static color references in the in-scope files' new code.

### Pillar 4: Typography (4/4)

End-of-day card:
- Heading: `Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)` at `end_of_day_card.dart:56–59` — exact pattern from spec and ReviewBanner
- Subtitle: `Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)` at `end_of_day_card.dart:72–74` — exact pattern from spec
- Button label: standard `ElevatedButton` child `Text('Close the day')` inheriting `labelLarge` — PASS

Settings row: uses standard `ListTile` title/subtitle which inherits Material 3 `bodyLarge`/`bodyMedium` — PASS, no custom type overrides on new rows.

The `w600` in section headings (`settings_screen.dart:77`) is a pre-existing deviation not introduced by Phase 10. Noted under Priority Fixes but scored against the pre-existing code, not the new evening row.

No arbitrary font sizes (no `TextStyle(fontSize: N)`) in new components.

### Pillar 5: Spacing (4/4)

End-of-day card spacing breakdown against the declared scale (xs=4, sm=8, md=16, lg=24):

- `Card margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8)` → md horizontal, sm vertical — PASS (matches ReviewBanner `review_banner.dart` horizontal pattern)
- `Padding(padding: EdgeInsets.symmetric(vertical: 8))` — sm vertical — PASS
- `Padding(padding: EdgeInsets.only(left: 16))` on text column — md left — PASS
- `Padding(padding: EdgeInsets.only(right: 16, left: 8))` on button — md right, sm left — PASS

No arbitrary spacing values (`[Npx]`, `[Nrem]`) in new code.

Settings row uses ListTile default spacing (Material 3 standard) — appropriate, no custom spacing overrides.

### Pillar 6: Experience Design (4/4)

State coverage:
- Trigger-not-met: card not rendered — `home_screen.dart:122` guards on `_shouldShowEodCard(schedule.chunks)` — PASS
- Dismissed in-session: `_eodCardDismissed` bool, set by both `onDismiss` callback and `Dismissible.onDismissed` — PASS
- New schedule resets dismissal: `home_screen.dart:62–64` resets `_eodCardDismissed = false` in `didChangeDependencies` when `dateYmd` changes — PASS (the spec's "reappears on next app launch" behavior is covered)
- Empty-state branch: `_buildEmptyState` does not include `EndOfDayCard` — PASS (spec: "Do NOT show the card when `hasScheduleToday` is false")
- Swipe-to-dismiss: `Dismissible(direction: DismissDirection.horizontal, onDismissed: (_) => onDismiss())` — PASS
- X button tap: `onPressed: onDismiss` — PASS (redundant keyboard/accessible path alongside swipe)
- Dismiss tooltip: `tooltip: 'Dismiss'` — PASS (accessibility contract)
- ElevatedButton routes to `/summary` via callback `onGoToSummary: () => context.push('/summary')` — PASS
- Evening toggle: `onChanged` calls both `SettingsNotifier.setEveningReminderEnabled` and `NotificationService.scheduleEveningReminder`/`cancelEveningReminder` — PASS
- `onTap: null` on evening ListTile (no time picker) — PASS per spec

Trigger logic extracted to `shouldShowEodCard()` top-level function with injected `now` parameter for testability — exceeds spec requirement.

---

## Registry Safety

Not applicable. Flutter project with no third-party component registries. No shadcn, npm, or external design-system packages introduced in this phase.

---

## Files Audited

- `lib/screens/home/widgets/end_of_day_card.dart` (new component, full audit)
- `lib/screens/home/home_screen.dart` (insertion point, lines 44–46, 122–127, 237–239)
- `lib/screens/settings/settings_screen.dart` (evening reminder row, lines 63–64, 168–192)
- `.planning/phases/10-close-the-day/10-UI-SPEC.md` (design contract baseline)
