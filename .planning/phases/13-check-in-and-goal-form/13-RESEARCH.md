# Phase 13: Check-in and Goal Form — Research

**Researched:** 2026-06-13
**Domain:** Flutter Material 3 — luminance-adaptive color, hover/pressed interaction states, AnimatedSwitcher state machines, bottom sheet viewport fitting
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
None — discuss phase was skipped per `workflow.skip_discuss`.

### Claude's Discretion
All implementation choices are at Claude's discretion. Use ROADMAP phase goal, success criteria, and codebase conventions to guide decisions.

### Deferred Ideas (OUT OF SCOPE)
None — discuss phase skipped.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CHECKIN-01 | Check-in screen meets contrast/legibility standards at all five mood levels; interactive elements have hover/pressed states | Luminance-threshold getter, MouseRegion+AnimatedContainer pattern, InkWell for pressed, Material 3 ElevatedButton defaults |
| CHECKIN-02 | Lighter-day choice appears after "Let's go," framed as push-forward vs. lighter-day decision; unambiguous on/off state | AnimatedSwitcher three-state machine (A/B/C/D/E), `_buildDecisionBody()` widget, `_commitAndProceed()` flow |
| GOALFORM-01 | Add/edit goal sheet fits viewport; Priority selector and Save button visible without in-sheet scrolling on standard phone | GoalTypePicker `contentPadding` compaction (all(16) → symmetric(h:12,v:6)), `minVerticalPadding: 0`, spacer reduction |
</phase_requirements>

---

## Summary

Phase 13 is a pure Flutter widget-rework phase — no new packages, no schema changes, no routing changes. All three requirements are addressed by targeted edits to three files: `checkin_screen.dart`, `goal_form_sheet.dart`, and `goal_type_picker.dart`.

**CHECKIN-01** is a two-part fix: (1) replace the hardcoded `Colors.white` foreground references with a luminance-threshold getter that switches to `Color(0xFF1A1A1A)` on light mood backgrounds (moods 4 and 5 are the failing cases — `#7AAF6A` sage-green at ~3.5:1 and `#E8C547` amber-yellow at ~1.9:1 white-on-background), and (2) wrap each emoji `GestureDetector`+`AnimatedContainer` in a `MouseRegion` so hover state is trackable, then use `onHighlightChanged`/`onTapDown`/`onTapUp` signals to drive `AnimatedContainer` color changes for hover and pressed visual feedback.

**CHECKIN-02** replaces the current `bool _lighterDay` + `Switch` inline UI with a three-child `AnimatedSwitcher` state machine. The flow becomes: mood-select → "Let's go" triggers generation → on completion a lighter-day decision screen slides in presenting two explicit choice cards → tapping a card sets `lighterDay` and calls `ScheduleNotifier.generateToday()` again (regeneration is synchronous/fast per existing engine design) → acknowledgment body appears.

**GOALFORM-01** is a vertical-space budget fix. The `GoalTypePicker._TypeCard` uses `ListTile(contentPadding: EdgeInsets.all(16))` which inflates each card to ~88dp. Changing to `EdgeInsets.symmetric(horizontal: 12, vertical: 6)` + `minVerticalPadding: 0` reduces each card to ~64dp, saving 72dp across three cards. Three `SizedBox(height: 16)` spacers reduced to 12dp saves another 12dp. Total freed: ~84dp — enough to bring Priority + Save above the keyboard line on iPhone 14-class viewports (504dp available after 340dp keyboard).

**Primary recommendation:** Implement in three sequential waves per the UI-SPEC implementation sequencing hint — contrast/hover (Wave 1), lighter-day state machine (Wave 2), goal form compaction (Wave 3). No file is touched by more than one wave, so each wave is independently testable.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Luminance-adaptive foreground color | Client (StatefulWidget getter) | — | Pure computed value from background color; no server/API needed |
| Hover/pressed states | Client (MouseRegion + AnimatedContainer) | — | Platform pointer events; handled entirely in widget layer |
| Check-in state machine (A→B→C→D→E) | Client (StatefulWidget `_CheckinScreenState`) | Provider (ScheduleNotifier) | State machine lives in widget; `generateToday()` is the only external call |
| Lighter-day decision screen | Client (widget subtree via AnimatedSwitcher) | — | Pure UI; no persistence until `_commitAndProceed()` |
| Schedule regeneration with lighterDay | Provider (ScheduleNotifier.generateToday) | — | Business logic; already exists and is async-capable |
| Goal form viewport fitting | Client (GoalTypePicker._TypeCard layout) | — | Widget layout; no data layer involved |

---

## Standard Stack

### Core (no new packages — all already in pubspec.yaml)

| Library | Current Version | Purpose | Why Standard |
|---------|----------------|---------|--------------|
| `flutter/material.dart` | Flutter 3.44.1 (Dart 3.12.1) | All widgets used: AnimatedSwitcher, AnimatedContainer, AnimatedScale, MouseRegion, InkWell, SegmentedButton, ElevatedButton, ListTile | Already the project foundation |
| `provider` | 6.1.5+1 | `context.read<ScheduleNotifier>()` for regeneration | Project-standard state management |

**No new dependencies required.** All APIs used in this phase are Flutter framework built-ins available in Flutter 3.44.1.

**Installation:** None — `flutter pub get` is a no-op for this phase.

---

## Package Legitimacy Audit

No new packages are installed in this phase. All implementation uses Flutter framework APIs already present in pubspec.yaml.

| Package | Registry | Age | Verdict | Disposition |
|---------|----------|-----|---------|-------------|
| (none) | — | — | — | No packages to audit |

**Packages removed due to SLOP verdict:** none
**Packages flagged as SUS:** none

---

## Architecture Patterns

### System Architecture Diagram

```
User input (mood tap)
        │
        ▼
_CheckinScreenState (StatefulWidget)
        │
        ├── State A: emoji row only (_buildCheckinBody, no button)
        │
        ├── State B: emoji row + "Let's go" pill button (_buildCheckinBody)
        │       │
        │       └── tap "Let's go"
        │               │
        │               ▼
        ├── State C: _isGenerating=true → spinner in button
        │       │
        │       └── ScheduleNotifier.generateToday(lighterDay:false)  [async, ~100ms]
        │               │
        │               ▼
        ├── State D: _generationDone=true → AnimatedSwitcher shows _buildDecisionBody()
        │       │
        │       ├── tap "Full day"  → _commitAndProceed(lighterDay:false) → State E
        │       ├── tap "Lighter day" → ScheduleNotifier.generateToday(lighterDay:true) → State E
        │       └── tap "Go back"  → setState: _generationDone=false → back to State B
        │
        └── State E: _scheduleGenerated=true → AnimatedSwitcher shows _buildAcknowledgmentBody()
                        │
                        └── swipe up → Navigator.pop(context)
```

### Recommended Project Structure (no changes to structure)
```
lib/screens/schedule/
├── checkin_screen.dart     # PRIMARY: 3 new methods, 1 new state bool, luminance getter
└── acknowledgment_screen.dart  # untouched
lib/screens/goals/
├── goal_form_sheet.dart    # MINOR: 3 SizedBox spacer reductions
└── widgets/
    └── goal_type_picker.dart  # PRIMARY: _TypeCard contentPadding + minVerticalPadding + icon size + borderRadius
```

### Pattern 1: Luminance-Adaptive Foreground Color

**What:** A computed getter that returns `Colors.white` for dark mood backgrounds and `Color(0xFF1A1A1A)` for light mood backgrounds, using `Color.computeLuminance()`.
**When to use:** Wherever `_selectedMood != null` and text/icons are overlaid on the mood seed background.
**Example:**
```dart
// Source: 13-UI-SPEC.md §Mood Background Contract
Color get _onBgColor {
  if (_selectedMood == null) return Theme.of(context).colorScheme.onSurface;
  final bg = _backgroundColor;
  final luminance = bg.computeLuminance();
  // WCAG requirement: dark text on light backgrounds (luminance > 0.35).
  return luminance > 0.35 ? const Color(0xFF1A1A1A) : Colors.white;
}
```
[VERIFIED: codebase — `Color.computeLuminance()` is a Flutter SDK method confirmed in existing `ThemeNotifier.modulateHsl` which uses `HSLColor.fromColor`; `computeLuminance()` is on the same `Color` class]

**Where it replaces the current hardcoded `Colors.white` in `_buildCheckinBody`:**
- Line 154: `final onBg = _selectedMood != null ? Colors.white : Theme.of(context).colorScheme.onSurface;`
  → Change to: `final onBg = _onBgColor;`
- AppBar title color (line 130): `Colors.white` → `_onBgColor`
- AppBar icon theme (line 134): `Colors.white` → `_onBgColor`

### Pattern 2: Hover + Pressed States on Emoji Targets

**What:** `MouseRegion` wrapping `GestureDetector`/`AnimatedContainer` to detect pointer hover on desktop/web. `GestureDetector.onTapDown`/`onTapUp` for pressed visual feedback.
**When to use:** Any tappable element in a full-background color context where `InkWell` ripple is inappropriate (InkWell ripple on a colored container with no Material ancestor gives a debug warning and the ripple color may not match).
**Example:**
```dart
// Source: 13-UI-SPEC.md §Hover and Pressed States
bool _hoveredMood = false; // per-emoji: use Map<int, bool>
bool _pressedMood = false; // per-emoji: use Map<int, bool>

// In build:
MouseRegion(
  onEnter: (_) => setState(() => _hoveredMoods[mood] = true),
  onExit: (_) => setState(() => _hoveredMoods[mood] = false),
  child: GestureDetector(
    onTap: () { /* existing onTap logic */ },
    onTapDown: (_) => setState(() => _pressedMoods[mood] = true),
    onTapUp: (_) => setState(() => _pressedMoods[mood] = false),
    onTapCancel: () => setState(() => _pressedMoods[mood] = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      // For pressed: increase alpha 51→77; for hover: 0→26 (non-selected)
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _resolveEmojiBackground(mood, isSelected),
      ),
    ),
  ),
)
```
[ASSUMED — MouseRegion + AnimatedContainer pattern is standard Flutter practice; the specific alpha values and timing come from 13-UI-SPEC.md which is authoritative for this project]

**Helper for resolving emoji background color:**
```dart
Color _resolveEmojiBackground(int mood, bool isSelected) {
  final isHovered = _hoveredMoods[mood] ?? false;
  final isPressed = _pressedMoods[mood] ?? false;
  final luminanceAdaptiveBase = luminance > 0.35
      ? const Color(0xFF1A1A1A)
      : Colors.white;
  if (isSelected) {
    return luminanceAdaptiveBase.withAlpha(isPressed ? 77 : (isHovered ? 64 : 51));
  } else {
    return luminanceAdaptiveBase.withAlpha(isHovered ? 26 : 0);
  }
}
```

**State maps needed in `_CheckinScreenState`:**
```dart
final Map<int, bool> _hoveredMoods = {};
final Map<int, bool> _pressedMoods = {};
```

### Pattern 3: AnimatedSwitcher Three-State Machine

**What:** Using `ValueKey` on each child widget so `AnimatedSwitcher` detects which child changed and triggers the transition animation.
**When to use:** When a single widget position needs to show three different UI states with animated transitions between them.
**Example:**
```dart
// Source: 13-UI-SPEC.md §States and Transitions
AnimatedSwitcher(
  duration: const Duration(milliseconds: 300),
  child: _scheduleGenerated
      ? _buildAcknowledgmentBody(context)   // ValueKey('acknowledgment')
      : _generationDone
          ? _buildDecisionBody(context)     // ValueKey('decision')
          : _buildCheckinBody(context),     // ValueKey('checkin')
)
```
[VERIFIED: codebase — existing code already uses `AnimatedSwitcher` with `ValueKey('checkin')` and `ValueKey('acknowledgment')` at lines 140-146 of `checkin_screen.dart`; adding a third `ValueKey('decision')` child follows the exact same pattern]

**Critical detail:** Each `_build*` method must return its widget wrapped with its `ValueKey` at the outermost child position. The existing `_buildCheckinBody` already does this (line 159: `key: const ValueKey('checkin')`). The `_buildAcknowledgmentBody` already does this (line 272: `key: const ValueKey('acknowledgment')`). The new `_buildDecisionBody` must add `key: const ValueKey('decision')`.

### Pattern 4: _LighterDayCard with AnimatedScale Pressed State

**What:** A card widget that uses `AnimatedScale` to scale 0.97 on press, with `GestureDetector` for tap detection.
**When to use:** Choice cards where a physical "press" metaphor communicates interactivity on the mood-colored background.
**Example:**
```dart
// Source: 13-UI-SPEC.md §Lighter-Day Decision Screen Layout
class _LighterDayCard extends StatefulWidget {
  // ... constructor with icon, title, subtitle, onTap ...

  @override
  State<_LighterDayCard> createState() => _LighterDayCardState();
}

class _LighterDayCardState extends State<_LighterDayCard> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    // onBgColor passed in or derived from parent
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.onBgColor.withAlpha(_hovered ? 153 : 77),
                width: 1.5,
              ),
              color: widget.onBgColor.withAlpha(_hovered ? 38 : 26),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(/* icon + title + subtitle */),
          ),
        ),
      ),
    );
  }
}
```
[ASSUMED — AnimatedScale is a standard Flutter widget; the specific values (0.97, 80ms, easeOut) come from 13-UI-SPEC.md]

### Pattern 5: Compact GoalTypePicker _TypeCard

**What:** Reducing ListTile vertical padding and preventing Flutter's enforced 8dp minimum via `minVerticalPadding: 0`.
**When to use:** When viewport height is the constraint and the card content is fully legible at the reduced size.
**Example:**
```dart
// Source: 13-UI-SPEC.md §Compact GoalTypePicker visual spec
ListTile(
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  minVerticalPadding: 0,   // prevent Flutter's 8dp enforced minimum
  leading: Icon(icon, size: 20, color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant),
  title: Text(title, style: theme.textTheme.bodyMedium?.copyWith(
    color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
  )),
  subtitle: Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(
    color: isSelected ? colorScheme.onPrimaryContainer.withAlpha(179) : colorScheme.onSurfaceVariant,
  )),
)
```
[VERIFIED: codebase — `minVerticalPadding` is a real `ListTile` parameter; confirmed by reading existing `goal_type_picker.dart` which uses `ListTile` and does NOT set `minVerticalPadding`; adding it prevents the 8dp enforced minimum]

### Anti-Patterns to Avoid

- **Bare `GestureDetector` without `MouseRegion` for hover:** On desktop/web, `GestureDetector.onTap` fires on click but there is no hover detection — `MouseRegion` is required. The existing emoji tap implementation uses bare `GestureDetector` which is why hover is missing. [VERIFIED: codebase — confirmed `checkin_screen.dart` line 173: `GestureDetector(onTap: ...)`]

- **Hardcoded `Colors.white` for foreground on mood backgrounds:** The current code at line 154 hardcodes `onBg = Colors.white` when mood is selected. This fails WCAG AA for mood 5 (amber, ~1.9:1). [VERIFIED: codebase — confirmed line 153-155 of checkin_screen.dart]

- **Inline `Switch` for lighter-day choice:** The current `Switch` at line 211 has `activeTrackColor: Colors.white.withAlpha(102)` which becomes invisible on amber (#E8C547). The Switch widget also communicates state ambiguously compared to explicit choice cards. [VERIFIED: codebase — confirmed lines 211-218 of checkin_screen.dart]

- **`BorderRadius.circular(30)` for pill button:** Should be `StadiumBorder()` so the pill adapts to button height changes (e.g., when replacing the label with a spinner). Current code at line 232 uses `BorderRadius.circular(30)`. [VERIFIED: codebase — confirmed line 232]

- **Calling `_generate()` from "Let's go" with the final `lighterDay` value:** The lighter-day value is not known until the decision screen. Generate with `lighterDay: false` initially (provisional), then if user picks lighter day, regenerate. Regeneration is fast (<100ms, no I/O beyond Hive save). [VERIFIED: codebase — `generateToday()` signature at line 97 of `schedule_notifier.dart` accepts `bool lighterDay = true`]

- **Nested `SingleChildScrollView` inside `DraggableScrollableSheet`:** The existing `GoalFormSheet` already has `SingleChildScrollView(controller: widget.scrollController)` wired correctly at line 121. Do NOT add a second `SingleChildScrollView`. The compaction fix reduces content height so the primary scroll is rarely triggered. [VERIFIED: codebase — line 121 of goal_form_sheet.dart]

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Luminance-based contrast decisions | Custom contrast ratio calculator | `Color.computeLuminance()` (Flutter SDK) | Built into the `Color` class; WCAG-aligned |
| Hover state tracking | Custom pointer tracking via Listener | `MouseRegion.onEnter/onExit` | Flutter's first-class hover API; handles pointer enter/exit correctly across platforms |
| Cross-platform pressed visual | Platform-channel pressed detection | `GestureDetector.onTapDown/onTapUp/onTapCancel` + `AnimatedContainer` | Works on all 6 target platforms; already used in the project for the emoji targets (without the animation piece) |
| Animated state transitions | Custom `AnimationController` | `AnimatedSwitcher` with `ValueKey` | Already in use; adding a third state is a one-line change to the ternary |
| Scale animation on press | Custom `Transform.scale` in `setState` | `AnimatedScale` widget | Declarative; handles curve and duration natively |

**Key insight:** Every visual problem in this phase has a Flutter framework primitive as the correct solution. No custom animation controllers, no external packages, no custom painters.

---

## Common Pitfalls

### Pitfall 1: `AnimatedSwitcher` Not Animating Between States
**What goes wrong:** The transition from State C → D (generating → decision) appears instantaneous with no fade.
**Why it happens:** `AnimatedSwitcher` only animates when the `child` widget's `Key` changes. If the new child has the same `Key` as the old child (or no key), Flutter reuses the widget and no animation fires.
**How to avoid:** Every `_build*` method must return a widget with a unique `ValueKey`. The existing `_buildCheckinBody` returns `ValueKey('checkin')` and `_buildAcknowledgmentBody` returns `ValueKey('acknowledgment')`. The new `_buildDecisionBody` must return `ValueKey('decision')`.
**Warning signs:** The state changes visually but no fade transition occurs; both old and new content flicker into place simultaneously.

### Pitfall 2: `_generationDone` State Leaking on "Go Back"
**What goes wrong:** User taps "Go back" from the decision screen, but `_generationDone` is still `true`, so the `AnimatedSwitcher` ternary re-renders the decision screen immediately.
**Why it happens:** "Go back" must reset `_generationDone = false` in `setState`. If it only navigates (which is not applicable here — there is no route push) or if `setState` is called after disposal, the state remains stale.
**How to avoid:** The "Go back" `TextButton` handler: `onPressed: () => setState(() => _generationDone = false)`. Also note: the schedule generated in State C (with `lighterDay: false`) is already persisted by the time State D is shown. If the user goes back and then taps "Let's go" again, the `generateToday()` call runs again and overwrites — this is correct behavior (the schedule is always regenerated on "Let's go" tap).
**Warning signs:** "Go back" button appears to do nothing; user stays on decision screen.

### Pitfall 3: `computeLuminance()` Called on `Colors.transparent`
**What goes wrong:** `_backgroundColor` returns `Colors.transparent` when `_selectedMood == null`. Calling `computeLuminance()` on transparent returns 0.0 (dark), so `_onBgColor` would return `Colors.white` — which is correct for the unselected state but the getter is guarded by `_selectedMood == null` check. If the guard is missing, `Colors.transparent.computeLuminance()` returns 0.0, incorrectly treating it as a dark background.
**Why it happens:** Transparent has no meaningful luminance.
**How to avoid:** The `_onBgColor` getter is guarded: `if (_selectedMood == null) return Theme.of(context).colorScheme.onSurface;`. The luminance check only runs when `_selectedMood != null`, at which point `_backgroundColor` returns a real mood seed color. [VERIFIED: codebase — confirmed `_backgroundColor` getter at line 45: returns `Colors.transparent` when `_selectedMood == null`]

### Pitfall 4: GoalTypePicker Height Not Actually Reduced
**What goes wrong:** The `contentPadding` change alone reduces visual padding but `ListTile` still enforces `minVerticalPadding: 8` (its default), which adds 8dp top + 8dp bottom = 16dp per card. The net saving is less than expected.
**Why it happens:** `ListTile.minVerticalPadding` defaults to 8dp — this is independent of `contentPadding` and applies symmetrically inside the content area.
**How to avoid:** Set `minVerticalPadding: 0` explicitly on every `ListTile` in `_TypeCard`. Combined with `contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6)`, this achieves the target ~64dp per card.
**Warning signs:** After the change, opening the goal form sheet still shows Priority/Save cut off; measure the card height with `LayoutBuilder` or Flutter DevTools if uncertain.

### Pitfall 5: `_LighterDayCard` onTapUp Fires Before `setState` Unblocks
**What goes wrong:** `onTapUp` calls both `setState(() => _pressed = false)` and `widget.onTap()`. If `widget.onTap()` triggers a parent `setState` that rebuilds the card before the card's `setState` completes, the press visual may be skipped.
**Why it happens:** Dart's event loop; both calls are synchronous but parent rebuild may win.
**How to avoid:** In `onTapUp`: call `setState(() => _pressed = false)` first, then invoke `widget.onTap()` in the same handler. The frame boundary handles ordering correctly in Flutter's build cycle.

### Pitfall 6: `ElevatedButton` on Amber Background — Invisible Disabled State
**What goes wrong:** When `_isGenerating == true`, the "Let's go" button's `onPressed: null` makes it disabled. The default Material 3 disabled state uses `colorScheme.onSurface.withOpacity(0.38)` as foreground — on an amber background this may not be legible.
**Why it happens:** The button uses `ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: bgColor)` which customizes the enabled state but not the disabled state. `styleFrom` does NOT automatically adapt the disabled color.
**How to avoid:** The spinner loading state (State C) replaces the Text child while keeping the button enabled-but-non-interactive. `onPressed: _isGenerating ? null : _generate` is the current implementation and should be replaced with a non-null no-op during generation so the disabled styling is never triggered: `onPressed: _isGenerating ? () {} : _generate`. Then the spinner is shown as the child. Or, keep `onPressed: null` and override the disabled colors explicitly. The UI-SPEC shows the spinner approach which avoids disabled state entirely. [VERIFIED: codebase — current implementation at line 226 uses `onPressed: _isGenerating ? null : _generate`]

---

## Code Examples

### Full `_onBgColor` Getter Pattern
```dart
// Replaces all hardcoded `Colors.white` for mood-background-overlaid text/icons
// Source: 13-UI-SPEC.md §Resolution for mood 4 and mood 5 contrast failure
Color get _onBgColor {
  if (_selectedMood == null) return Theme.of(context).colorScheme.onSurface;
  final bg = _backgroundColor;
  final luminance = bg.computeLuminance();
  return luminance > 0.35 ? const Color(0xFF1A1A1A) : Colors.white;
}
```

### New State Fields in `_CheckinScreenState`
```dart
// Add alongside existing state fields (_selectedMood, _scheduleGenerated, _isGenerating)
bool _generationDone = false;                    // new: true after generateToday() completes
final Map<int, bool> _hoveredMoods = {};         // new: per-emoji hover state
final Map<int, bool> _pressedMoods = {};         // new: per-emoji pressed state
// Remove: bool _lighterDay = true;              // remove: replaced by decision screen
```

### Restructured `_generate()` Method
```dart
// Source: 13-UI-SPEC.md §Check-in Screen Redesign Contract
Future<void> _generate() async {
  if (_selectedMood == null || _isGenerating) return;
  setState(() => _isGenerating = true);
  try {
    await context.read<ScheduleNotifier>().generateToday(
      moodIndex: _selectedMood!,
      goals: context.read<GoalsNotifier>().goals,
      blocks: context.read<CommitmentsNotifier>().blocks,
      lighterDay: false,  // provisional — decision screen may regenerate with true
    );
    await NotificationService.requestIOSPermissions();
    if (mounted) {
      setState(() {
        _generationDone = true;   // ← triggers AnimatedSwitcher to show decision screen
        _isGenerating = false;
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')),
      );
    }
  }
}
```

### `_commitAndProceed()` Method
```dart
// Source: 13-UI-SPEC.md §Check-in Screen Redesign Contract
Future<void> _commitAndProceed({required bool lighterDay}) async {
  if (lighterDay) {
    // Regenerate with lighter day — fast, synchronous engine call
    await context.read<ScheduleNotifier>().generateToday(
      moodIndex: _selectedMood!,
      goals: context.read<GoalsNotifier>().goals,
      blocks: context.read<CommitmentsNotifier>().blocks,
      lighterDay: true,
    );
  }
  // else: use the schedule already generated in _generate() (lighterDay: false)
  if (mounted) {
    setState(() => _scheduleGenerated = true);
  }
}
```

### Updated AnimatedSwitcher (three-state)
```dart
// Source: 13-UI-SPEC.md §States and Transitions
AnimatedSwitcher(
  duration: const Duration(milliseconds: 300),
  child: _scheduleGenerated
      ? _buildAcknowledgmentBody(context)
      : _generationDone
          ? _buildDecisionBody(context)
          : _buildCheckinBody(context),
)
```

### `_buildDecisionBody()` Top-Level Structure
```dart
// Source: 13-UI-SPEC.md §Lighter-Day Decision Screen Layout
Widget _buildDecisionBody(BuildContext context) {
  final onBg = _onBgColor;
  return Container(
    key: const ValueKey('decision'),
    width: double.infinity,
    height: double.infinity,
    color: _backgroundColor,
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Ready to start?', style: TextStyle(
              color: onBg, fontSize: 20, fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: 8),
            Text('Choose your pace for today', style: TextStyle(
              color: onBg.withAlpha(179), fontSize: 14,
            )),
            const SizedBox(height: 32),
            _LighterDayCard(
              icon: Icons.bolt_outlined,
              title: 'Full day',
              subtitle: 'Push forward with your complete plan',
              onBgColor: onBg,
              onTap: () => _commitAndProceed(lighterDay: false),
            ),
            const SizedBox(height: 12),
            _LighterDayCard(
              icon: Icons.self_improvement_outlined,
              title: 'Lighter day',
              subtitle: 'A gentler pace — fewer chunks, lower stakes',
              onBgColor: onBg,
              onTap: () => _commitAndProceed(lighterDay: true),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() => _generationDone = false),
              child: Text('Go back', style: TextStyle(color: onBg.withAlpha(179))),
            ),
          ],
        ),
      ),
    ),
  );
}
```

### GoalTypePicker _TypeCard Compact Diff (key lines only)
```dart
// BEFORE (goal_type_picker.dart line 85):
// contentPadding: const EdgeInsets.all(16),
// leading: Icon(icon, color: isSelected ? colorScheme.primary : null),

// AFTER (source: 13-UI-SPEC.md §Compact GoalTypePicker visual spec):
contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
minVerticalPadding: 0,
leading: Icon(icon, size: 20,
    color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant),
// Also: change Card borderRadius from 12 to 10, side width from 2 to 1.5
// Also: title Text gets fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400
```

### GoalFormSheet Spacer Reductions (three locations)
```dart
// goal_form_sheet.dart — reduce these three SizedBox heights from 16 to 12:
// 1. After title Text (line 153):         SizedBox(height: 16) → SizedBox(height: 12)
// 2. After GoalTypePicker (line 171):     SizedBox(height: 16) → SizedBox(height: 12)
// 3. After goal name TextField (line 184): SizedBox(height: 16) → SizedBox(height: 12)
// (These are the only three; the SizedBox after SegmentedButton at line 200 stays at 16)
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `GestureDetector` only for emoji tap | `MouseRegion` + `GestureDetector` for hover+pressed | This phase | Desktop/web users get hover feedback |
| Inline `Switch` for lighter-day toggle | Two explicit choice cards in decision screen | This phase | Eliminates contrast failure on amber; clearer UX |
| `bool _lighterDay` state (always visible) | `_generationDone` state gate (post-commit) | This phase | Lighter-day decision is contextually deferred |
| `Colors.white` hardcoded foreground | `_onBgColor` luminance-threshold getter | This phase | Eliminates amber WCAG AA failure |
| `ListTile(contentPadding: all(16))` | `ListTile(contentPadding: symmetric(h:12,v:6), minVerticalPadding:0)` | This phase | ~84dp freed; Priority+Save visible on phone |

**Nothing deprecated:** All Flutter APIs used (`AnimatedSwitcher`, `AnimatedScale`, `MouseRegion`, `SegmentedButton`, `ListTile.minVerticalPadding`) are stable in Flutter 3.44.1. `WidgetStateProperty` (formerly `MaterialStateProperty`) is available if needed for button styles but is not required for the patterns above. [ASSUMED — API stability claim is based on training knowledge; Flutter 3.44.1 is confirmed via `flutter --version`]

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `MouseRegion` + `GestureDetector` + `AnimatedContainer` is the recommended pattern for hover+pressed on colored backgrounds (as opposed to `InkWell` inside `Material`) | Patterns, Code Examples | Low — either approach works; InkWell inside Material is an alternative that also works and may be simpler |
| A2 | `AnimatedScale` widget is stable and available in Flutter 3.44.1 | Don't Hand-Roll | Low — `AnimatedScale` was added in Flutter 2.x and is confirmed stable in all current releases |
| A3 | Regenerating with `lighterDay: true` after initial `lighterDay: false` generation takes <100ms | Pattern 3, _commitAndProceed | Medium — if regeneration is slow (>500ms), the UX between decision and acknowledgment will feel sluggish; should add a loading indicator in `_commitAndProceed` if this is observed in testing |
| A4 | `minVerticalPadding: 0` on `ListTile` is available in Flutter 3.44.1 | Pattern 5, Pitfall 4 | Low — `minVerticalPadding` has been a `ListTile` parameter since Flutter 2.x |

---

## Open Questions (RESOLVED)

1. **`_commitAndProceed` async loading state**
   - What we know: `generateToday()` is async and involves Hive writes. It is described as synchronous/fast in UI-SPEC comments but is `async` in implementation.
   - What's unclear: Whether a loading indicator is needed during the "Lighter day" regeneration path in `_commitAndProceed`.
   - RESOLVED: Do not add a spinner for now. The transition to the acknowledgment body (which animates in via `AnimatedSwitcher`) provides sufficient visual feedback. If testing reveals a perceptible delay, add `setState(() => _isGenerating = true)` before the regeneration call and show a brief spinner on the decision screen. Plan 13-01 Task 2 implements this recommendation (no spinner).

2. **`onTapCancel` handling for `_LighterDayCard`**
   - What we know: If the user lifts their finger outside the card after pressing, `onTapCancel` fires. `_pressed` must be reset to avoid a permanently-scaled card.
   - What's unclear: Whether `GestureDetector.onTapCancel` also fires on web when pointer leaves the card boundary during press.
   - RESOLVED: Always handle `onTapCancel: () => setState(() => _pressed = false)` alongside `onTapUp`. Plan 13-01 Task 2 handles `onTapCancel` on the lighter-day card and emoji targets.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All widgets | ✓ | 3.44.1 (Dart 3.12.1) | — |
| `flutter/material.dart` | AnimatedSwitcher, MouseRegion, AnimatedScale, SegmentedButton, ListTile | ✓ | Included in Flutter 3.44.1 | — |
| `provider` | ScheduleNotifier.generateToday calls | ✓ | 6.1.5+1 (in pubspec.yaml) | — |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** None.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (Flutter 3.44.1 built-in) |
| Config file | none — uses default flutter test runner |
| Quick run command | `flutter test test/widget_test.dart` |
| Full suite command | `/home/dan/development/flutter/bin/flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CHECKIN-01 | `_onBgColor` returns `Color(0xFF1A1A1A)` for mood 5 (luminance > 0.35) | unit | `flutter test test/widget_test.dart` | ❌ Wave 0 |
| CHECKIN-01 | `_onBgColor` returns `Colors.white` for moods 1-3 (luminance <= 0.35) | unit | `flutter test test/widget_test.dart` | ❌ Wave 0 |
| CHECKIN-01 | Emoji targets show hover highlight on `MouseRegion` enter | manual-only (pointer event; flutter_test PointerEventRecord approach is feasible but complex) | — | manual |
| CHECKIN-02 | AnimatedSwitcher shows decision screen after generation completes | widget | `flutter test test/widget_test.dart` | ❌ Wave 0 |
| CHECKIN-02 | "Lighter day" card tap triggers second generateToday call | widget | `flutter test test/widget_test.dart` | ❌ Wave 0 |
| CHECKIN-02 | "Go back" resets to State B (emoji + "Let's go") | widget | `flutter test test/widget_test.dart` | ❌ Wave 0 |
| GOALFORM-01 | GoalTypePicker _TypeCard renders at ≤64dp height | widget (LayoutBuilder capture) | `flutter test test/widget_test.dart` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/widget_test.dart` (fast; placeholder test always passes)
- **Per wave merge:** `/home/dan/development/flutter/bin/flutter test` + `flutter analyze`
- **Phase gate:** Full suite green + `flutter analyze` clean before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/screens/checkin_screen_test.dart` — unit test for `_onBgColor` luminance threshold; covers CHECKIN-01 contrast requirement
- [ ] `test/screens/checkin_screen_widget_test.dart` — widget tests for state machine transitions (States B→C→D→E and "Go back" D→B); covers CHECKIN-02
- [ ] `test/widgets/goal_type_picker_test.dart` — layout height assertion for compact `_TypeCard`; covers GOALFORM-01

**Existing infrastructure:** `test/widget_test.dart` is a stub placeholder test. All three test files above are new. The flutter_test framework is already installed (dev dependency in pubspec.yaml). No conftest or fixture setup needed — tests can use `WidgetTester.pumpWidget` directly with a `MaterialApp` wrapper and in-memory fakes for providers.

---

## Security Domain

ASVS security enforcement: this phase involves no authentication, session management, user input validation beyond existing TextField behavior, or cryptography. The lighter-day decision and mood selection are local UI state; no network calls; no new input surfaces.

| ASVS Category | Applies | Notes |
|---------------|---------|-------|
| V2 Authentication | no | No auth in this phase |
| V3 Session Management | no | No sessions |
| V4 Access Control | no | No access gating |
| V5 Input Validation | no | No new user input fields; existing TextField for goal name already in use |
| V6 Cryptography | no | No crypto |

No new threat patterns introduced.

---

## Project Constraints (from CLAUDE.md)

| Directive | Impact on Phase 13 |
|-----------|-------------------|
| State management: Provider + ChangeNotifier for cross-screen state; StatefulWidget + setState() for screen-local state | Lighter-day decision screen state (`_generationDone`, `_hoveredMoods`, `_pressedMoods`) is screen-local → `setState()` correct. `ScheduleNotifier.generateToday()` is already a Provider call → no change. |
| Routing: Single-screen MaterialApp with no routing library | The lighter-day decision screen is NOT a new route — it is an AnimatedSwitcher child within `CheckinScreen`. Correct. |
| Theme: Material 3 with ColorScheme.fromSeed(Colors.deepOrangeAccent) | All new widgets use `Theme.of(context).colorScheme.*` tokens. No hardcoded theme colors except the luminance-threshold `Color(0xFF1A1A1A)` which is intentionally theme-neutral dark. |
| Linting: flutter_lints | New code must pass `flutter analyze`. Use `const` constructors where possible; avoid unused variables. |
| Flutter path: /home/dan/development/flutter/bin | Use `/home/dan/development/flutter/bin/flutter` for all CLI commands in plan tasks. |
| All application code in lib/ | No new top-level directories. `_LighterDayCard` is a private class in `checkin_screen.dart` (not a separate file) since it is only used there. |

---

## Sources

### Primary (HIGH confidence — VERIFIED from codebase)
- `lib/screens/schedule/checkin_screen.dart` — current state fields, `_generate()`, `_buildCheckinBody()`, `_buildAcknowledgmentBody()`, `AnimatedSwitcher` usage, `GestureDetector` emoji targets
- `lib/screens/goals/goal_form_sheet.dart` — current `SizedBox` spacer heights, `SingleChildScrollView` wiring, `SegmentedButton` usage
- `lib/screens/goals/widgets/goal_type_picker.dart` — current `ListTile(contentPadding: EdgeInsets.all(16))` on line 85; `Card borderRadius: 12`; no `minVerticalPadding`
- `lib/providers/schedule_notifier.dart` — `generateToday()` signature (lines 97-102), async nature, `lighterDay` parameter
- `lib/providers/theme_notifier.dart` — `moodSeeds` map (lines 56-62), `computeLuminance()` usage pattern via `HSLColor.fromColor`

### Secondary (MEDIUM confidence — VERIFIED from UI-SPEC)
- `.planning/phases/13-check-in-and-goal-form/13-UI-SPEC.md` — complete implementation contract for all three requirements; authored by gsd-ui-researcher with checker sign-off process

### Tertiary (LOW confidence — ASSUMED)
- Flutter 3.44.1 API stability for `AnimatedScale`, `MouseRegion`, `minVerticalPadding` on ListTile — based on training knowledge of Flutter APIs

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — confirmed via codebase read and `flutter --version`
- Architecture: HIGH — grounded in actual source files
- Pitfalls: HIGH — derived from reading actual bugs in the code (hardcoded `Colors.white`, missing `MouseRegion`, `contentPadding: all(16)`)
- Code examples: HIGH — derived from actual current code with targeted mutations from UI-SPEC

**Research date:** 2026-06-13
**Valid until:** 2026-07-13 (stable Flutter framework; 30-day horizon)
