---
created: 2026-06-14T19:50:21Z
title: Goal form (and modals) don't adapt to desktop — phone bottom sheet everywhere
area: ui/goals
surfaced_during: v1.2 Phase 13 UAT (scenario 8, GOALFORM-01)
severity: moderate
resolves_phase: 18
resolved: 2026-08-04
resolution: Shipped in Phase 18 (v1.4, RESP-01/02/03). Verified 2026-08-04 —
  `showAdaptiveFormModal` (lib/widgets/adaptive_form_modal.dart) switches
  centered dialog vs bottom sheet at 720dp; both goal paths
  (goals_screen.dart:40 add, :51 edit) route through it, as do the commitment
  form (commitments_screen.dart:31) and the schedule's caller
  (schedule_screen.dart:404) — so the "audit other modals" ask is covered too.
files:
  - lib/screens/goals/goals_screen.dart
  - lib/screens/goals/goal_form_sheet.dart
  - lib/screens/goals/widgets/goal_type_picker.dart
---

## Problem

The Add/Edit goal form is shown as a phone bottom sheet on every platform:

```dart
// goals_screen.dart:28-62
showModalBottomSheet(
  isScrollControlled: true,
  builder: (ctx) => DraggableScrollableSheet(
    initialChildSize: 0.6, minChildSize: 0.4, maxChildSize: 1.0, ...
    builder: (_, sc) => GoalFormSheet(scrollController: sc),
  ),
);
```

There's no `MediaQuery` width branch, so on desktop/web — the primary dogfood
surface — it renders the exact same cramped 60%-height draggable sheet a phone
gets. Confirmed in UAT: identical with Chrome device emulation on or off. At the
0.6 initial height the GoalTypePicker's 3rd card ("I want to build a daily
habit") clips at the bottom, and Priority + the Add/Save button fall below the
fold, requiring scroll — contrary to GOALFORM-01's "reachable without scrolling"
intent. User read it immediately: "it's like trying to be a mobile screen not a
PC screen."

## Solution

Branch the presentation on viewport width:
- **Wide / desktop** (e.g. width >= ~600px): centered `Dialog` (or
  `showDialog`) with a constrained max width (~480-560px) and natural/intrinsic
  height, so the whole form — type picker, fields, Priority, Save — is visible
  without scrolling.
- **Narrow / phone**: keep the current bottom sheet.

Extract a small helper (e.g. `showGoalForm(context, {goal})`) that picks dialog
vs sheet, so the edit and add paths stay in sync.

Audit other modals for the same phone-only assumption (commitment add/edit, any
other `showModalBottomSheet` callers) and apply the same adaptive pattern.

## Acceptance

On a desktop-width browser window, opening Add/Edit goal shows a centered dialog
where the type picker, Priority control, and Save/Add button are all visible
without scrolling and nothing clips at the bottom. On a narrow/phone width it
still uses the bottom sheet.
