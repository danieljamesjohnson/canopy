---
created: 2026-06-14T19:30:38Z
title: Check-in emoji hover + pressed feedback not visible on desktop/web
area: ui/checkin
surfaced_during: v1.2 Phase 13 UAT (scenarios 3 & 4, CHECKIN-01)
severity: minor
files:
  - lib/screens/schedule/checkin_screen.dart
---

## Problem

On the morning check-in, hovering or press-and-holding the mood emoji circles
shows no perceptible feedback on desktop/web (confirmed in UAT — "don't see a
hover on desktop", and pressed shows nothing).

Both are wired but ineffective, in `_resolveEmojiBackground` (~L79):

```dart
final luminance = _selectedMood != null
    ? _backgroundColor.computeLuminance()
    : 0.0;                       // <-- defaults to 0.0 BEFORE a mood is picked
final base = luminance > 0.35 ? const Color(0xFF1A1A1A) : Colors.white;
if (isSelected) {
  return base.withAlpha(isPressed ? 77 : (isHovered ? 64 : 51));
} else {
  return base.withAlpha(isHovered ? 26 : 0);   // <-- ignores isPressed
}
```

1. **Hover invisible.** Unselected highlight is `base.withAlpha(26)` (~10%).
   Before any mood is selected, `luminance` is hard-coded to `0.0`, so `base` is
   forced to **white** → white at ~10% on the light pre-selection background is
   invisible. (After a mood is picked it's slightly better but still faint.)
2. **Pressed does nothing.** The unselected branch ignores `isPressed`, and the
   mood is only selected on `onTap` (release) — so during press-and-hold the
   emoji is always unselected and shows no pressed fill.

## Solution

- Derive `base` from the *actual* current screen/background luminance even when
  `_selectedMood == null` (the pre-checkin background), so the hover wash
  contrasts with whatever is behind it.
- Raise the hover alpha to a perceptible level on a light background.
- Honor `isPressed` in the unselected branch (e.g. a stronger alpha than hover),
  so press-and-hold gives feedback before release.

## Acceptance

On desktop/web: hovering an unselected emoji shows a clearly visible highlight
that clears on exit; press-and-hold shows a stronger fill before release — both
visible regardless of whether a mood has been selected yet.
