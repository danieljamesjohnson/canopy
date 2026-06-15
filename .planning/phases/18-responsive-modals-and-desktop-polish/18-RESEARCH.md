# Phase 18: Responsive Modals and Desktop Polish — Research

**Researched:** 2026-06-14
**Domain:** Flutter adaptive layout — showDialog vs showModalBottomSheet, ConstrainedBox content width, Material 3 Dialog
**Confidence:** HIGH (all findings verified against actual codebase)

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| RESP-01 | Goal add/edit form renders as a centered, width-constrained dialog on desktop/web widths and as a bottom sheet on phone widths | Adaptive helper `showAdaptiveFormModal` switches on `MediaQuery.of(context).size.width >= 720`; both `_openAddSheet` and `_openEditSheet` in `goals_screen.dart` need replacing |
| RESP-02 | On desktop width, the goal form shows the type picker, all fields, Priority, and Save/Add with nothing clipped and no scroll required | Dialog height cap 80% of viewport; `GoalTypePicker` is `Column(mainAxisSize: MainAxisSize.min)` — fits within 560dp with no changes; `SingleChildScrollView` with fresh controller handles overflow if any |
| RESP-03 | Commitment add/edit and any other modal callers use the same shared adaptive dialog-vs-sheet helper | One additional caller: `_openAddSheet` in `commitments_screen.dart`; `ChunkDetailSheet` is explicitly out of scope |
| POLISH-01 | Primary screens (home, schedule, goals, check-in) use desktop-appropriate layout at wide widths — constrained content, not phone-stretched full-bleed | Home `body: Column(...)`, Schedule `body: Column(...)`, Goals `CustomScrollView` inside `Consumer` each need `ConstrainedBox(maxWidth: 720)` + `Align(topCenter)` wrap; check-in already at 480dp — no change |
| POLISH-02 | Residual UI nits from a fresh desktop walkthrough are triaged and the high-friction ones fixed | Copy fixes identified in UI-SPEC; desktop walkthrough required after helper is built |
</phase_requirements>

---

## Summary

Phase 18 is a pure Flutter UI change with no new dependencies and no data-layer impact. The work divides into three areas: (1) building a shared `showAdaptiveFormModal` helper at `lib/widgets/adaptive_form_modal.dart` that switches between `showDialog` and `showModalBottomSheet` based on the already-locked 720dp breakpoint, (2) constraining primary screen content width to 720dp on desktop, and (3) POLISH-02 copy fixes and any high-friction nits surfaced by a desktop walkthrough.

The codebase is clean for this change. Both form sheets (`GoalFormSheet`, `CommitmentFormSheet`) already use `SingleChildScrollView` + `ScrollController`, making the dialog path straightforward: inject a fresh `ScrollController()`, hide the drag handle via an `isDialog: bool` parameter, remove `viewInsets.bottom` padding, and wrap the scroll view in a `ConstrainedBox`/`Dialog` container. The three `showModalBottomSheet` callers are all identified and located. The 720dp breakpoint constant is already locked in `responsive_shell.dart` line 66 and used by `LayoutBuilder` — the adaptive helper reads `MediaQuery.of(context).size.width` to stay consistent.

The check-in screen already has `ConstrainedBox(maxWidth: 480)` inside a `Center` — confirmed at `checkin_screen.dart` lines 224–225. That pattern is the precedent for POLISH-01, scaled to 720dp for the home/schedule/goals screens.

**Primary recommendation:** Build `lib/widgets/adaptive_form_modal.dart` first; migrate goal callers; migrate commitment caller; then apply content-width constraints to the three primary screens; then do the POLISH-02 walkthrough and copy fixes last (can be done independently in a separate wave).

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Adaptive modal routing (dialog vs sheet) | Frontend (widget layer) | — | Pure presentation decision; no data or provider involvement |
| Form content (GoalFormSheet, CommitmentFormSheet) | Frontend (screen layer) | — | Already self-contained; helper only changes the container, not the content |
| Breakpoint detection | Frontend (widget layer) | — | `MediaQuery.of(context).size.width` — same source already used by `LayoutBuilder` in ResponsiveShell |
| Content width constraint | Frontend (screen layer) | — | `ConstrainedBox` wrap on the Scaffold `body` child |
| Copy label changes | Frontend (screen/widget layer) | — | String literals in form sheet `build()` methods |

---

## Codebase Inventory (Verified)

### Modal callers to migrate

All three callers confirmed by reading source files directly.

| Caller | File | Method | Current call |
|--------|------|--------|--------------|
| Goal add | `lib/screens/goals/goals_screen.dart` | `_openAddSheet` | `showModalBottomSheet` with `DraggableScrollableSheet` |
| Goal edit | `lib/screens/goals/goals_screen.dart` | `_openEditSheet` | `showModalBottomSheet` with `DraggableScrollableSheet` |
| Commitment add/edit | `lib/screens/commitments/commitments_screen.dart` | `_openAddSheet` | `showModalBottomSheet` with `DraggableScrollableSheet` (handles both add and edit via optional `block` param) |

**Out of scope (confirmed):** `ChunkDetailSheet` at `lib/screens/schedule/widgets/chunk_detail_sheet.dart` — called directly via `showModalBottomSheet` in `schedule_screen.dart` lines 259–272. Informational only; no text input. UI-SPEC explicitly marks it as "migrate if time permits; not required for RESP-03."

**Already dialogs (no change):** `_confirmDelete` in `commitments_screen.dart` uses `showDialog<bool>` with `AlertDialog`. UI-SPEC confirms these are out of scope.

### Primary screens body structure

| Screen | File | Body widget | Constrained? |
|--------|------|-------------|-------------|
| Home | `lib/screens/home/home_screen.dart` | `body: Column(...)` at line 354 | No — full-bleed |
| Schedule | `lib/screens/schedule/schedule_screen.dart` | `body: Column(children: [ScheduleProgressBar, Expanded(ListView)])` at line 88 | No — full-bleed |
| Goals | `lib/screens/goals/goals_screen.dart` | `body: Consumer<GoalsNotifier>(builder: ... CustomScrollView(...))` | No — full-bleed |
| Check-in | `lib/screens/schedule/checkin_screen.dart` | `Center(child: ConstrainedBox(maxWidth: 480, ...))` at lines 222–225 | YES — already at 480dp; no change needed |

### Form sheet drag handle location

**GoalFormSheet** (`lib/screens/goals/goal_form_sheet.dart` lines 155–165):
```dart
Center(
  child: Container(
    width: 40,
    height: 4,
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: colorScheme.outlineVariant,
      borderRadius: BorderRadius.circular(2),
    ),
  ),
),
```
This is the first child of the `Column` inside `SingleChildScrollView`. Hidden by adding `isDialog: bool` parameter and wrapping it in `if (!widget.isDialog)`.

**CommitmentFormSheet** (`lib/screens/commitments/commitment_form_sheet.dart` lines 130–139):
```dart
Center(
  child: Container(
    width: 40,
    height: 4,
    decoration: BoxDecoration(
      color: colorScheme.outline,
      borderRadius: BorderRadius.circular(2),
    ),
  ),
),
```
Same pattern — first child of the scroll content `Column`. Hidden with the same `isDialog` parameter approach.

### viewInsets.bottom usage

**GoalFormSheet** (`goal_form_sheet.dart` line 144–149): padding includes `16 + MediaQuery.of(context).viewInsets.bottom` on the bottom. In dialog mode this must be plain `24` (no `viewInsets.bottom` addition — dialogs float above the keyboard per UI-SPEC).

**CommitmentFormSheet** (`commitment_form_sheet.dart` line 122): `padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + MediaQuery.viewInsetsOf(context).bottom)`. Same: in dialog mode, use fixed bottom padding only.

### GoalTypePicker structure

`lib/screens/goals/widgets/goal_type_picker.dart`: `Column(mainAxisSize: MainAxisSize.min, children: [_TypeCard, SizedBox(8), _TypeCard, SizedBox(8), _TypeCard])`. Each `_TypeCard` is a `Card` wrapping `InkWell` wrapping `ListTile`. No horizontal overflow risk at 560dp dialog width — confirmed by visual inspection. No changes to `GoalTypePicker` needed.

### Existing breakpoint constant

`lib/widgets/responsive_shell.dart` line 66: `if (constraints.maxWidth >= 720)`. This is the D-11 locked threshold. The adaptive helper must use the same value (`720`) via `MediaQuery.of(context).size.width >= 720`.

### Existing test infrastructure

| File | What it tests | Relevance |
|------|--------------|-----------|
| `test/test_helpers/viewport.dart` | `setViewport(tester, size)` — sets `physicalSize` + teardown reset | Use for all new responsive tests |
| `test/test_helpers/mood_pump.dart` | `pumpWithMood(tester, child, extraProviders)` — Material 3 + ThemeNotifier fixture | Use when pumping form sheets in tests |
| `test/screens/responsive_layout_test.dart` | NavigationBar/NavigationRail swap at 480/720/1200dp | Pattern reference for new dialog/sheet tests |
| `test/screens/goal_form_priority_test.dart` | `_pumpModal` (real showModalBottomSheet + DraggableScrollableSheet at 390x844) and `_pumpForm` (direct pump) | Both patterns relevant; dialog tests will use `showDialog` equivalent of `_pumpModal` |

**Key test pattern note (from goal_form_priority_test.dart line 287 comment):** When scrolling inside modal content, use `find.byType(Scrollable).first` as the scrollable argument to `scrollUntilVisible`. `SingleChildScrollView` is not a `Scrollable` — using it causes a type-cast error at runtime. This pattern must carry over to dialog-mode tests.

---

## Standard Stack

No new packages are introduced. This phase is pure Flutter SDK widget composition.

| Widget / API | Where used | Notes |
|--------------|-----------|-------|
| `showDialog<T>` | `adaptive_form_modal.dart` desktop path | Returns `Future<T?>`, barrier dismissible |
| `Dialog` | Dialog container | `clipBehavior: Clip.antiAlias`, Material 3 tonal elevation level 3 |
| `ConstrainedBox` | Dialog sizing + screen content width | `BoxConstraints(maxWidth: 560)` for dialog, `BoxConstraints(maxWidth: 720)` for screen content |
| `SingleChildScrollView` | Form scroll in dialog | Fresh `ScrollController()` injected; same as sheet path |
| `Align(alignment: Alignment.topCenter)` | Screen content centering | Wraps `ConstrainedBox` in screen bodies |
| `MediaQuery.of(context).size.width` | Breakpoint detection | Read at call site in `showAdaptiveFormModal` |
| `showModalBottomSheet` | Mobile path in helper | Existing behavior preserved exactly |
| `DraggableScrollableSheet` | Mobile path in helper | Existing config preserved |

**Installation:** None required.

---

## Package Legitimacy Audit

Not applicable — this phase installs no external packages. All components are Flutter SDK widgets.

---

## Architecture Patterns

### System Architecture Diagram

```
Caller (goals_screen / commitments_screen)
  |
  v
showAdaptiveFormModal(context, builder)
  |
  +-- MediaQuery.size.width >= 720 -----> showDialog()
  |                                          |
  |                                          v
  |                                       Dialog (clipBehavior, Corner R=28)
  |                                          |
  |                                       ConstrainedBox (maxW=560, maxH=80%vh)
  |                                          |
  |                                       SingleChildScrollView (fresh SC)
  |                                          |
  |                                       builder(scrollController)
  |                                          |
  |                                    GoalFormSheet(isDialog: true)
  |                                    or CommitmentFormSheet(isDialog: true)
  |                                    [drag handle hidden, viewInsets omitted]
  |
  +-- MediaQuery.size.width < 720 -----> showModalBottomSheet()
                                            |
                                         DraggableScrollableSheet
                                            |
                                         builder(scrollController)
                                            |
                                         GoalFormSheet(isDialog: false)
                                         or CommitmentFormSheet(isDialog: false)
                                         [drag handle visible, viewInsets applied]
```

### Recommended File Additions

```
lib/widgets/
└── adaptive_form_modal.dart    # new — showAdaptiveFormModal helper
```

**Modified files:**
```
lib/screens/goals/goal_form_sheet.dart       # add isDialog param, hide handle, fix padding
lib/screens/goals/goals_screen.dart          # replace _openAddSheet/_openEditSheet
lib/screens/commitments/commitment_form_sheet.dart  # add isDialog param, hide handle, fix padding
lib/screens/commitments/commitments_screen.dart     # replace _openAddSheet
lib/screens/home/home_screen.dart            # wrap body Column in ConstrainedBox
lib/screens/schedule/schedule_screen.dart    # wrap body content in ConstrainedBox
lib/screens/goals/goals_screen.dart          # wrap CustomScrollView in ConstrainedBox
```

### Pattern 1: Adaptive Form Modal Helper

**What:** A top-level function that routes to `showDialog` or `showModalBottomSheet` based on viewport width.

**When to use:** Any time a user-facing form is shown modally (goal, commitment — not informational sheets or alert dialogs).

```dart
// lib/widgets/adaptive_form_modal.dart
// Source: UI-SPEC §Adaptive Modal Contract (approved 2026-06-14)

Future<void> showAdaptiveFormModal({
  required BuildContext context,
  required Widget Function(ScrollController scrollController) builder,
}) async {
  final width = MediaQuery.of(context).size.width;
  final isDesktop = width >= 720;

  if (isDesktop) {
    final screenHeight = MediaQuery.of(context).size.height;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final scrollController = ScrollController();
        return Dialog(
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: screenHeight * 0.8,
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              child: builder(scrollController),
            ),
          ),
        );
      },
    );
  } else {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 1.0,
        expand: false,
        snap: true,
        snapSizes: const [0.6, 1.0],
        builder: (ctx, scrollController) => builder(scrollController),
      ),
    );
  }
}
```

**CAUTION:** `MediaQuery.of(context).size.height` must be read inside the outer `builder` (before `showDialog`), not inside the `Dialog`'s builder, to use the screen's height not the dialog's own constraints.

### Pattern 2: isDialog Parameter for Form Sheets

**What:** Add `isDialog: bool = false` to `GoalFormSheet` and `CommitmentFormSheet` constructors. When `true`, (a) hide the drag handle container, (b) use fixed padding without `viewInsets.bottom`.

```dart
// Modification to GoalFormSheet — before/after the drag handle
// Source: codebase inspection + UI-SPEC §Desktop path

// BEFORE (goal_form_sheet.dart lines 155-165):
Center(
  child: Container(width: 40, height: 4, ...),  // always visible
),

// AFTER:
if (!widget.isDialog)
  Center(
    child: Container(width: 40, height: 4, ...),
  ),
```

```dart
// BEFORE (goal_form_sheet.dart lines 143-149):
padding: EdgeInsets.fromLTRB(
  16, 16, 16,
  16 + MediaQuery.of(context).viewInsets.bottom,
),

// AFTER:
padding: EdgeInsets.fromLTRB(
  24, 24, 24,
  widget.isDialog ? 24 : 16 + MediaQuery.of(context).viewInsets.bottom,
),
```

### Pattern 3: Content Width Constraint on Primary Screens

**What:** Wrap the Scaffold `body` child (the scrollable/list) in a centered `ConstrainedBox`. The `AppBar` and `ScheduleProgressBar` remain full-width.

**Precedent:** `checkin_screen.dart` lines 222–225 uses `Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 480), child: ...))`.

```dart
// Source: checkin_screen.dart precedent + UI-SPEC §Primary Screen Content Width Constraint

// Home screen — body: is currently Column; wrap the Column:
body: Align(
  alignment: Alignment.topCenter,
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 720),
    child: Column(  // existing body Column
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [...],
    ),
  ),
),

// Goals screen — body is Consumer<GoalsNotifier> returning CustomScrollView:
body: Consumer<GoalsNotifier>(
  builder: (context, notifier, _) {
    ...
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: CustomScrollView(slivers: [...]),
      ),
    );
  },
),

// Schedule screen — body is Column with ScheduleProgressBar + Expanded(ListView):
// NOTE: ScheduleProgressBar stays full-width; only the Expanded(ListView) is constrained
body: Column(
  children: [
    ScheduleProgressBar(schedule: schedule, moodColor: moodColor),  // full-width
    Expanded(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(...),
        ),
      ),
    ),
  ],
),
```

**IMPORTANT for Schedule screen:** The `ScheduleProgressBar` should remain full-width (it is a horizontal progress indicator that spans the top). Only the `ListView` inside `Expanded` is constrained. This is different from Home where the entire `Column` body can be constrained (no full-width progress bar in that position).

### Pattern 4: Copy Label Changes (POLISH-02)

All copy changes are string literal replacements in the form sheet `build()` methods. They do not affect logic.

| File | Location | Old text | New text |
|------|----------|----------|----------|
| `goal_form_sheet.dart` | Title text | `'Edit goal'` / `'Add goal'` | `'Edit Goal'` / `'Add Goal'` |
| `goal_form_sheet.dart` | ElevatedButton label | `_isEditMode ? 'Save' : 'Add goal'` | `_isEditMode ? 'Save Goal' : 'Add Goal'` |
| `goal_form_sheet.dart` | Cancel TextButton | `'Cancel'` | `'Discard'` |
| `goal_form_sheet.dart` | Archive TextButton | `'Archive'` | `'Archive goal'` |
| `commitment_form_sheet.dart` | Cancel (if exists) | any `'Cancel'` | `'Discard'` |
| `commitments_screen.dart` | Delete confirm cancel | `'Cancel'` | `'Keep commitment'` |
| `commitments_screen.dart` | Delete confirm action | `'Delete'` | `'Delete commitment'` |

**Current commitment form sheet:** `CommitmentFormSheet` has no cancel/discard button — it only has a `FilledButton` for save. The Discard button needs to be added (as a `TextButton` above the `FilledButton`) in both add and edit modes.

### Anti-Patterns to Avoid

- **Wrapping the AppBar in ConstrainedBox:** Material 3 convention is AppBar spans full width. Only `body:` content is constrained.
- **Reading viewInsets inside the dialog builder:** In dialog mode, `MediaQuery.of(context).viewInsets.bottom` is not 0 — the outer context still has keyboard insets from the originating screen. Always use the `isDialog` flag to skip the insets addition rather than reading viewInsets inside the dialog.
- **Using `showModalBottomSheet` with `isScrollControlled: false` for dialog:** The adaptive helper routes to `showDialog`, not a re-styled bottom sheet. Do not try to simulate a dialog with a bottom sheet.
- **Placing ConstrainedBox outside the Scaffold:** The constraint must be on the `body:` child, not around the `Scaffold` itself. Constraining `Scaffold` breaks AppBar, FAB, and NavigationBar layouts.
- **Using `Center` instead of `Align(topCenter)` for constrained screen content:** `Center` vertically centers the constrained column, which makes it float on short content. `Align(alignment: Alignment.topCenter)` keeps it top-aligned (same as normal scroll behavior).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Responsive dialog-vs-sheet routing | Custom overlay/widget | `showDialog` + `showModalBottomSheet` | Flutter's own modal APIs handle focus, barrier, accessibility, back-navigation |
| Dialog border radius | Custom ClipRRect | `Dialog(clipBehavior: Clip.antiAlias)` | `Dialog` clips to its own shape; explicit `ClipRRect` double-clips and is redundant |
| Breakpoint constant | Hardcoded `720` in multiple files | Single constant or read from `ResponsiveShell` | D-11 is a locked decision; duplicating the magic number creates drift risk |
| Dialog content scroll | ListView inside Dialog | `SingleChildScrollView` | `ListView` inside `Dialog` has known sizing issues; `SingleChildScrollView` with `ConstrainedBox(maxHeight)` on the Dialog is the correct pattern |

---

## Common Pitfalls

### Pitfall 1: Dialog height not constrained → unbounded height crash

**What goes wrong:** `Dialog` by default sizes to its content. A `SingleChildScrollView` child with `mainAxisSize: MainAxisSize.min` content can exceed the screen, causing a layout error or content that scrolls off-screen with no visual boundary.

**Why it happens:** `Dialog` does not apply a max-height by default. `SingleChildScrollView` reports infinite intrinsic height if unconstrained.

**How to avoid:** Wrap the `SingleChildScrollView` (or the Dialog's child) in `ConstrainedBox(constraints: BoxConstraints(maxHeight: screenHeight * 0.8))`. The `screenHeight` must be read from `MediaQuery` before entering the `showDialog` call (see Pattern 1 above).

**Warning signs:** "RenderFlex overflowed" or "Viewport was given unbounded height" error in the debug console.

### Pitfall 2: ConstrainedBox on a CustomScrollView body causes double-scroll

**What goes wrong:** Wrapping a `CustomScrollView` in `ConstrainedBox` and then in a parent scroll view creates two scroll layers.

**Why it happens:** `CustomScrollView` is itself a scroll view; if placed inside another scrollable, only one layer scrolls.

**How to avoid:** The `ConstrainedBox` wraps the `CustomScrollView` directly as the sole scrollable — it must NOT be inside another `SingleChildScrollView` or `ListView`. In Goals screen, `Consumer` returns the `Align(ConstrainedBox(CustomScrollView))` — no outer scroll wrapper. Confirmed this is the current structure (no outer scroll wrapper).

### Pitfall 3: `viewInsets.bottom` leaking into dialog padding

**What goes wrong:** Dialog content has extra bottom padding that shifts content up when keyboard appears, or content appears offset on screens without a software keyboard.

**Why it happens:** The `context` passed to `showDialog`'s builder may inherit `MediaQuery` with non-zero `viewInsets.bottom` from the page behind the dialog.

**How to avoid:** Use the `isDialog` flag to select fixed padding (24dp bottom) rather than `viewInsets.bottom`-based padding. Never read `viewInsets` inside dialog content.

### Pitfall 4: `setViewport` not called in new dialog-path tests → flakey breakpoint behavior

**What goes wrong:** A new test that exercises the desktop dialog path runs at the default flutter_test viewport (800×600 or 1024×768), which happens to be >= 720dp, and the test passes — but then another test that doesn't call `setViewport` gets the side-effect size and the modal assertion fails.

**Why it happens:** `tester.view.physicalSize` persists across tests in the same group unless `tester.view.reset` is called in a teardown.

**How to avoid:** Always use `setViewport(tester, size)` from `test/test_helpers/viewport.dart` — it auto-registers the teardown. Never set `tester.view.physicalSize` directly.

### Pitfall 5: `find.byType(Scrollable).first` required for `scrollUntilVisible` inside modal

**What goes wrong:** `tester.scrollUntilVisible(..., scrollable: find.byType(SingleChildScrollView))` throws a type-cast error at runtime.

**Why it happens:** `scrollUntilVisible` casts the found widget to `Scrollable` directly. `SingleChildScrollView` is not a `Scrollable` subtype — it creates a `Scrollable` internally.

**How to avoid:** Always use `find.byType(Scrollable).first` as the `scrollable:` argument. This is documented in the existing `goal_form_priority_test.dart` comment (line 287) and the STATE.md accumulated context entry.

### Pitfall 6: Navigator.pop inside dialog form doesn't close the dialog

**What goes wrong:** `Navigator.pop(context)` in `GoalFormSheet._save()` / `GoalFormSheet._archive()` works for bottom sheets (which push a route-like entry) but for dialogs opened with `showDialog`, the same `Navigator.pop(context)` call should work — HOWEVER, if the `context` passed to the form is the modal context (inner), it may not resolve to the dialog's route correctly if the widget tree is structured incorrectly.

**Why it happens:** `showDialog` uses `Navigator.push` internally so `Navigator.pop` should work. But if `CommitmentFormSheet._save()` calls `Navigator.of(context).pop()` using the form's own context (which it does, line 109), and the dialog has its own navigator scope, the pop resolves correctly.

**How to avoid:** No change needed to pop logic — `Navigator.pop(context)` and `Navigator.of(context).pop()` both resolve correctly inside a `showDialog` builder on the same navigator stack. Verified by Flutter's `showDialog` implementation which uses the root navigator by default.

---

## Code Examples

### showAdaptiveFormModal call site (goal add)

```dart
// lib/screens/goals/goals_screen.dart — replacement for _openAddSheet
// Source: UI-SPEC §Helper API + codebase inspection

void _openAddSheet(BuildContext context) {
  showAdaptiveFormModal(
    context: context,
    builder: (scrollController) =>
        GoalFormSheet(scrollController: scrollController),
  );
}

void _openEditSheet(BuildContext context, Goal goal) {
  showAdaptiveFormModal(
    context: context,
    builder: (scrollController) =>
        GoalFormSheet(scrollController: scrollController, goal: goal),
  );
}
```

### GoalFormSheet with isDialog parameter

```dart
// lib/screens/goals/goal_form_sheet.dart — constructor signature change
// Source: codebase inspection + UI-SPEC §Desktop path

class GoalFormSheet extends StatefulWidget {
  const GoalFormSheet({
    super.key,
    required this.scrollController,
    this.goal,
    this.isDialog = false,   // NEW
  });

  final ScrollController scrollController;
  final Goal? goal;
  final bool isDialog;   // NEW
  ...
}
```

### Content width constraint (Home screen body)

```dart
// lib/screens/home/home_screen.dart — wrap existing Column
// Source: checkin_screen.dart precedent + UI-SPEC §Primary Screen Content Width Constraint

body: Align(
  alignment: Alignment.topCenter,
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 720),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ... all existing children unchanged
      ],
    ),
  ),
),
```

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| setSurfaceSize() for test viewport sizing | `tester.view.physicalSize` + `tester.view.reset` teardown (via `setViewport` helper) | All new tests must use `setViewport` — `setSurfaceSize` is deprecated and removed |
| showBottomSheet (non-modal) | `showModalBottomSheet` with `isScrollControlled: true` | Current codebase already on correct API |
| `Dialog.fullscreen` for large content | `Dialog` + `ConstrainedBox` max-height | For form content at 80% height, constrained Dialog is the correct pattern (fullscreen is for full-page workflows) |

**Deprecated/outdated:**
- `setSurfaceSize`: removed in recent flutter_test — all existing tests already migrated (see `goal_form_priority_test.dart` GOALFORM-02 comment). Do NOT use.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| — | — | — | — |

**All claims in this research were verified against the actual codebase source files or the approved UI-SPEC. No assumptions required.**

---

## Open Questions (RESOLVED)

1. **CommitmentFormSheet cancel button**
   - What we know: `CommitmentFormSheet.build()` currently has no "Cancel"/"Discard" button — only a `FilledButton` for save.
   - What's unclear: Should a Discard button be added to both the dialog and sheet paths, or just the dialog path?
   - Recommendation: Add "Discard" TextButton above the FilledButton in both paths (the UI-SPEC copywriting table lists it as a FIX for both contexts). This is a 3-line addition.

2. **ScheduleProgressBar width on schedule screen**
   - What we know: The schedule screen body is `Column([ScheduleProgressBar, Expanded(ListView)])`. The progress bar is a full-width indicator.
   - What's unclear: Should the progress bar also be constrained at 720dp, or remain full-width?
   - Recommendation: Keep `ScheduleProgressBar` full-width per Material 3 convention (same as AppBar); only constrain the `ListView` inside `Expanded`. If the walkthrough reveals the full-width bar looks odd, it can be addressed in POLISH-02.

3. **Home screen empty-state body**
   - What we know: `home_screen.dart` has TWO `body:` assignments — one at line 354 (active schedule state) and one at line 660 (empty state / `_buildEmptyState`). The empty state is already using `Center` + `Padding(horizontal: 32)`.
   - What's unclear: Does the empty state also need the 720dp constraint?
   - Recommendation: Apply the constraint to the active-schedule body only (line 354); the empty state is naturally centered and narrow enough that a 720dp constraint has no visible effect.

---

## Environment Availability

This phase has no external dependencies beyond the Flutter SDK. The build and test commands are available.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | Build + test | ✓ | at `/home/dan/development/flutter/bin` | — |
| `flutter_test` | Widget tests | ✓ | bundled with Flutter | — |
| Python 3 (http.server) | UAT web serve | ✓ | system python3 | — |

**UAT note (from CLAUDE.md):** Desktop-width testing uses the debug single-bundle web build: `flutter build web --debug --source-maps --pwa-strategy=none` then `cd build/web && python3 -m http.server <port> --bind 0.0.0.0`. Use a fresh port not previously used for a release build.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (bundled with Flutter SDK) |
| Config file | none — uses `pubspec.yaml` dev_dependencies |
| Quick run command | `flutter test test/screens/adaptive_form_modal_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| RESP-01 | At 720dp width, `showAdaptiveFormModal` opens a `Dialog` (not a bottom sheet) | widget | `flutter test test/screens/adaptive_form_modal_test.dart` | ❌ Wave 0 |
| RESP-01 | At 719dp width, `showAdaptiveFormModal` opens `ModalBottomSheet` (not a dialog) | widget | `flutter test test/screens/adaptive_form_modal_test.dart` | ❌ Wave 0 |
| RESP-02 | At 720dp width, GoalFormSheet in dialog: drag handle absent, type picker visible, Priority visible, Save button visible (no scroll required) | widget | `flutter test test/screens/adaptive_form_modal_test.dart` | ❌ Wave 0 |
| RESP-02 | Dialog contains `ConstrainedBox` with maxWidth 560 | widget | `flutter test test/screens/adaptive_form_modal_test.dart` | ❌ Wave 0 |
| RESP-03 | CommitmentFormSheet caller routes through helper — shows Dialog at 720dp | widget | `flutter test test/screens/adaptive_form_modal_test.dart` | ❌ Wave 0 |
| POLISH-01 | Goals screen body contains `ConstrainedBox` with maxWidth 720 | widget | `flutter test test/screens/content_width_constraint_test.dart` | ❌ Wave 0 |
| POLISH-01 | Home screen body contains `ConstrainedBox` with maxWidth 720 | widget | `flutter test test/screens/content_width_constraint_test.dart` | ❌ Wave 0 |
| POLISH-02 | Copy labels in goal form: "Add Goal", "Save Goal", "Discard", "Archive goal" | widget | `flutter test test/screens/goal_form_copy_test.dart` | ❌ Wave 0 |
| POLISH-02 | Copy labels in commitment delete: "Delete commitment", "Keep commitment" | widget | `flutter test test/screens/goal_form_copy_test.dart` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `flutter test test/screens/adaptive_form_modal_test.dart test/screens/content_width_constraint_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/screens/adaptive_form_modal_test.dart` — covers RESP-01, RESP-02, RESP-03
- [ ] `test/screens/content_width_constraint_test.dart` — covers POLISH-01 (home + goals)
- [ ] `test/screens/goal_form_copy_test.dart` — covers POLISH-02 copy assertions

*(Schedule screen content-width constraint test can fold into `content_width_constraint_test.dart`)*

**Existing tests that must remain green:** `flutter test test/screens/goal_form_priority_test.dart` — the GOALFORM-02 modal tests exercise `GoalFormSheet` via `showModalBottomSheet`; adding `isDialog = false` default must not break them.

---

## Security Domain

> `security_enforcement` is not set to `false` in config — evaluating ASVS categories.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | This phase is UI presentation only; no auth changes |
| V3 Session Management | No | No session state touched |
| V4 Access Control | No | Modal content is the same as the existing screens |
| V5 Input Validation | No — carry-forward | Input validation is unchanged; existing `_canSave` guards remain |
| V6 Cryptography | No | No crypto involved |

**Assessment:** This phase presents no new security surface. It is a widget-layer restructuring with no changes to data flow, auth, or persistence. All existing input guards (`_canSave`, `_canSave` in commitment form) are preserved unchanged.

---

## Project Constraints (from CLAUDE.md)

The following directives from `./CLAUDE.md` apply to this phase:

1. **Debug web build for UAT:** Use `flutter build web --debug --source-maps --pwa-strategy=none` then `python3 -m http.server <port> --bind 0.0.0.0`. Test at desktop width in a real GPU-backed browser, not headless Chromium.
2. **Never swap build types on the same port:** Fresh port for the debug build — do not reuse a port that has served a release build.
3. **Provider + ChangeNotifier for cross-screen state:** No new state management patterns introduced in this phase.
4. **Test command:** `flutter test` (full suite) and `flutter analyze`.
5. **Format command:** `dart format lib/` after all changes.
6. **Dart SDK `^3.10.3` / Flutter `>=3.18.0-18.0.pre.54`:** No language features beyond these versions.

---

## Sources

### Primary (HIGH confidence — verified against codebase)

- `/home/dan/CodeProjects/canopy/lib/screens/goals/goals_screen.dart` — `_openAddSheet`, `_openEditSheet` call sites and body structure
- `/home/dan/CodeProjects/canopy/lib/screens/goals/goal_form_sheet.dart` — drag handle location, viewInsets usage, form content structure
- `/home/dan/CodeProjects/canopy/lib/screens/commitments/commitments_screen.dart` — `_openAddSheet` call site
- `/home/dan/CodeProjects/canopy/lib/screens/commitments/commitment_form_sheet.dart` — drag handle, viewInsets, save-only button
- `/home/dan/CodeProjects/canopy/lib/widgets/responsive_shell.dart` — 720dp breakpoint D-11
- `/home/dan/CodeProjects/canopy/lib/screens/schedule/checkin_screen.dart` — 480dp ConstrainedBox precedent
- `/home/dan/CodeProjects/canopy/lib/screens/home/home_screen.dart` — body Column structure
- `/home/dan/CodeProjects/canopy/lib/screens/schedule/schedule_screen.dart` — body Column + ListView structure
- `/home/dan/CodeProjects/canopy/lib/screens/goals/widgets/goal_type_picker.dart` — Column(mainAxisSize.min) layout confirmed
- `/home/dan/CodeProjects/canopy/test/test_helpers/viewport.dart` — setViewport pattern
- `/home/dan/CodeProjects/canopy/test/test_helpers/mood_pump.dart` — pumpWithMood pattern
- `/home/dan/CodeProjects/canopy/test/screens/goal_form_priority_test.dart` — Scrollable.first requirement, modal pump pattern
- `/home/dan/CodeProjects/canopy/.planning/phases/18-responsive-modals-and-desktop-polish/18-UI-SPEC.md` — approved design contract

### Secondary (MEDIUM confidence — project documentation)

- `/home/dan/CodeProjects/canopy/.planning/phases/18-responsive-modals-and-desktop-polish/18-CONTEXT.md` — requirements scope
- `/home/dan/CodeProjects/canopy/.planning/REQUIREMENTS.md` — RESP-01/02/03, POLISH-01/02 definitions
- `/home/dan/CodeProjects/canopy/.planning/STATE.md` — accumulated context and phase history

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new packages; all Flutter SDK APIs verified against existing usage in codebase
- Architecture: HIGH — all call sites and form structures read directly from source; patterns confirmed by existing tests
- Pitfalls: HIGH — pitfalls derived from actual bugs documented in STATE.md and test comments (Scrollable.first, setSurfaceSize deprecation, setViewport teardown)

**Research date:** 2026-06-14
**Valid until:** 2026-07-14 (stable Flutter widget APIs — no expiry risk within a month)
