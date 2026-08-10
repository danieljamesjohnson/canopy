# Phase 26: The Day Has a Shape - Pattern Map

**Mapped:** 2026-08-10
**Files analyzed:** 9 (5 reworked, 3 new/near-new, 1 new-test-target set of 3 existing test files)
**Analogs found:** 9 / 9 (all self-analogs — this phase reworks existing files in place; the "closest
analog" for nearly every file is itself, pre-rework, plus one cross-file precedent per new mechanism)

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/screens/today/timeline.dart` | model / pure transform | transform (list → list) | itself (pre-rework) | exact — delete one variant, keep shape |
| `lib/utils/time_format.dart` | utility | transform | itself (pre-rework) — new pure functions alongside existing ones | exact |
| `lib/screens/today/today_screen.dart` | screen / controller | request-response (build) + event-driven (timers, scroll) | itself (pre-rework), `_liveRowKey`/`ensureVisible` block as analog for the new `animateTo` block | exact |
| `lib/screens/today/widgets/now_marker.dart` | component (overlay) | render-only | itself (rewrite, not edit) — closest surviving precedent is its own `Container(height: 2, color: ...)` rule | role-match (becomes an absolutely-positioned overlay, not a row) |
| `lib/screens/today/widgets/timeline_row_tile.dart` | component (layout wrapper) | render-only | itself (pre-rework) — decision needed, see Pitfall 4 | exact (kept as pure inset wrapper per RESEARCH recommendation) |
| `lib/screens/today/widgets/free_time_row.dart` | component | render-only | itself (pre-rework) — `_DottedRulePainter` already tiles to arbitrary height, no change needed there | exact |
| `lib/screens/today/widgets/hour_axis.dart` (new file) | component (overlay) | render-only | `free_time_row.dart`'s `_DottedRulePainter` (CustomPainter-over-arbitrary-size precedent) + `chunk_card.dart`'s `_DashedBorderPainter` (stroke/color-from-ColorScheme precedent) | role-match — no existing hour-boundary axis exists; nearest precedent is "a CustomPainter drawing a themed line across a widget's `size`" |
| `lib/screens/schedule/widgets/chunk_card.dart` | component | render-only | itself (pre-rework) — `_DashedBorderPainter` extended with new ctor params, `_buildBreak` gains density-tier branch | exact |
| `lib/screens/schedule/widgets/swipeable_chunk_card.dart` | component | event-driven (Dismissible) | itself (unchanged except `showStartTime` default flip verification) | exact |

**Test files** (role: test, data flow: transform/render assertions — rewritten in place, not new files):

| File | Analog |
|---|---|
| `test/screens/today_timeline_model_test.dart` | itself — pure `test()` blocks, no widget pump (see excerpt below) |
| `test/screens/today_row_widgets_test.dart` | itself — widget-pump geometry assertions |
| `test/screens/today_screen_test.dart` | itself — full-screen widget-pump + scroll-offset assertions |

---

## Pattern Assignments

### `lib/screens/today/timeline.dart` (model, transform)

**Analog:** itself, pre-rework (this is the file being reworked, not replaced by a different file's
pattern).

**Sealed hierarchy shape to preserve** (lines 13-45):
```dart
sealed class TimelineRow {}

class ChunkRow extends TimelineRow {
  final ScheduledChunk chunk;
  final bool isLive;
  ChunkRow(this.chunk, {this.isLive = false});
}

class LeadingFreeRow extends TimelineRow {
  final int untilMinutes;
  LeadingFreeRow(this.untilMinutes);
}

class GapFreeRow extends TimelineRow {
  final int startMinutes;
  final int durationMinutes;
  GapFreeRow(this.startMinutes, this.durationMinutes);
}

// DELETE — NowMarkerRow's between-rows contract, per D-01:
class NowMarkerRow extends TimelineRow {
  final int minutes;
  NowMarkerRow(this.minutes);
}
```
Keep `ChunkRow`/`LeadingFreeRow`/`GapFreeRow` verbatim (still list-shaped rows Layer 1 iterates).
Delete `NowMarkerRow` outright (Pattern 1, RESEARCH.md) — do not keep-and-ignore a sealed variant.

**`buildTimeline`'s marker-emission blocks to delete** (lines 78-84 doc comment context, 115-122,
129-131) — the `showMarker`/`markerInserted` local state and both `rows.add(NowMarkerRow(...))`
call sites. **Do NOT delete the `nowMinutes` parameter itself** — it is still load-bearing for NOW-02
(`LeadingFreeRow` suppression, line 103: `if (start > 0 && (nowMinutes == null || nowMinutes < start))`).
This line and its surrounding `if (prevEnd == null) { ... }` block (lines 93-105) are unchanged.

**INVARIANT 1 comment discipline to carry forward** (lines 50-58): this file must never read the
clock (`DateTime.now()`); the doc-comment convention of naming the invariant explicitly at the
function-level doc comment should be preserved for any new pure function added here or in
`time_format.dart` (`floorToHour`/`ceilToHour`/`hourBoundariesIn`/range formula) — none of these take
a live clock read either, only injected `int` minute values, so the same "never reads the clock"
framing applies.

---

### `lib/utils/time_format.dart` (utility, transform)

**Analog:** itself — existing formatters are the pattern for the new pure functions
(`floorToHour`, `ceilToHour`, `hourBoundariesIn`, and the `rangeStart`/`rangeEnd` formula from
`26-UI-SPEC.md`'s "Scroll-on-open" section, per RESEARCH Open Question 3).

**Existing formatter shape to copy** (lines 8-16, 22, 47-54):
```dart
/// Formats minutes-from-midnight as a 12-hour time string.
/// Example: 565 → "9:25 AM"
String formatMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  final suffix = h < 12 ? 'AM' : 'PM';
  final hour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '$hour:${m.toString().padLeft(2, '0')} $suffix';
}

int minutesOfDay(DateTime dt) => dt.hour * 60 + dt.minute;
```
Every function is: a doc comment with a worked numeric example, a plain `int`-in/`int`-or-`String`-out
signature, no side effects, no `DateTime.now()`. New functions (`floorToHour(int minutes) => (minutes
~/ 60) * 60`, `ceilToHour(int minutes) => ((minutes + 59) ~/ 60) * 60`, `hourBoundariesIn(int
rangeStart, int rangeEnd) => [for (var m = rangeStart; m <= rangeEnd; m += 60) m]`) should match this
exact shape: pure, doc-commented with an example, unit-testable in isolation (see test pairing below).

---

### `lib/screens/today/today_screen.dart` (screen/controller)

**Analog:** itself, pre-rework. Two sub-patterns to copy and one to delete.

**Single-clock-sample + injectable-clock discipline (KEEP, unchanged)** (lines 61-93):
```dart
late final DateTime Function() _nowFn = widget.now ?? DevClock.now;
Timer? _nowTimer;   // 1-minute periodic, unchanged this phase (Pattern 4)
Timer? _fastTimer;  // 1-second, final-60s-only, unchanged this phase
bool _isBackgrounded = false;
```
Do not touch the timer cadence — CAL-02 is satisfied by position correctness on every rebuild, not
rebuild rate (RESEARCH Pattern 4). `build()` still takes exactly one `_nowFn()` sample and derives
both `resolveNowState` and `nowMinutes` from it.

**Switch site to rework** (lines 626-716, `_buildTimelineRow`) — VERIFIED the one and only switch
site via grep, confirming RESEARCH.md's claim:
```
grep -n "case ChunkRow\|case LeadingFreeRow\|case GapFreeRow\|case NowMarkerRow" lib/ test/
→ lib/screens/today/today_screen.dart:632-715 (this switch) — the only hit in lib/
```
Delete the `case NowMarkerRow(:final minutes):` arm (lines 643-673) as a unit — its `KeyedSubtree`,
`Semantics`, and `TimelineRowTile`-wrapping pattern is what `now_marker.dart`'s replacement overlay
widget should study for its `Semantics` wrapping convention (see now_marker.dart section below), even
though the arm itself is deleted, not moved.

**The `is` type-check call site to delete** (line 1130, VERIFIED via grep — exactly one hit outside
the switch):
```dart
final hasMarkerRow = timelineRows.any((row) => row is NowMarkerRow);
```
This is Pitfall 1's silent-no-op risk: a plain `is` check, not caught by sealed-exhaustiveness. Grep
`NowMarkerRow` after the edit — must return zero results in `lib/`.

**Centre-on-open mechanism — the exact analog to read before replacing** (lines 141-145 field decls,
1086-1144 body):
```dart
final GlobalKey _liveRowKey = GlobalKey();
final GlobalKey _nowMarkerKey = GlobalKey();          // DELETE
final ScrollController _dayScrollController = ScrollController();
bool _didCentreLiveRow = false;
bool _didCentreMarker = false;                         // DELETE, replaced by one flag

// DevClock offset-jump reset (KEEP the pattern, rename to one flag):
if (DevClock.offset != _lastDevClockOffset) {
  _lastDevClockOffset = DevClock.offset;
  _didCentreLiveRow = false;
  _didCentreMarker = false;
}

// Live-row centring (KEEP the flag-then-postFrameCallback shape, this IS the
// analog for the new arithmetic animateTo):
final hasLiveRow = timelineRows.any((row) => row is ChunkRow && row.isLive);
if (!_didCentreLiveRow && hasLiveRow) {
  _didCentreLiveRow = true;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    final liveRowContext = _liveRowKey.currentContext;
    if (liveRowContext == null) return;
    Scrollable.ensureVisible(
      liveRowContext,
      alignment: 0.5,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  });
}

// Marker-fallback centring (DELETE this whole block — 1116-1144 — replaced
// by the unconditional arithmetic path, since the new overlay always exists
// at a computable offset in every NowState):
final hasMarkerRow = timelineRows.any((row) => row is NowMarkerRow);
if (!hasLiveRow && !_didCentreMarker && hasMarkerRow) { ... }
```
**Replacement shape** (already sketched in RESEARCH.md's Code Examples section, reproduced here as
the concrete target — same one-shot-flag-before-scheduling discipline, same 250ms/easeOut, but a
single flag and arithmetic instead of `ensureVisible`):
```dart
if (!_didCentreOnOpen) {
  _didCentreOnOpen = true;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    final viewportHeight = _dayScrollController.position.viewportDimension;
    final raw = (nowMinutes - rangeStart) * kPixelsPerMinute - viewportHeight / 2;
    final target = raw.clamp(0.0, _dayScrollController.position.maxScrollExtent);
    _dayScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  });
}
```
**Ordering hazard to copy the discipline of, not the code of:** `maxScrollExtent` must be read
*inside* the post-frame callback, never precomputed in `build()` — this mirrors the existing
`_liveRowKey.currentContext` null-check-after-postFrame pattern (context/extent are both only valid
post-layout).

**Layout wrapper to replace** (lines 1171-1198) — the `SingleChildScrollView` + `Column` comment
itself is the analog explaining *why* eager layout (not `ListView.builder`) is correct, and should be
extended (not contradicted) by the new `Stack`:
```dart
// SingleChildScrollView + Column, deliberately NOT a ListView: the
// centre-on-open above needs the live row already laid out, and a lazy
// ListView may not have built a row far down the day. A day is bounded at
// a few dozen rows, so eager layout is the cheap correct answer and avoids
// a scroll-positioning package.
Expanded(
  child: SingleChildScrollView(
    controller: _dayScrollController,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mood <= 2) _buildRestorativeSuggestions(context),
        for (final row in timelineRows)
          _buildTimelineRow(context, row, nowState, liveSecondsLeft),
      ],
    ),
  ),
),
```
becomes `SingleChildScrollView(controller: _dayScrollController, child: SizedBox(height:
(rangeEnd-rangeStart)*kPixelsPerMinute, child: Stack(children: [...])))` per RESEARCH's Code
Examples "Stack layer skeleton" — same controller, same outer `Expanded`, same reasoning for why not
`ListView.builder`.

**No existing `Stack`+`Positioned` or `IgnorePointer` usage in `lib/`** was found — VERIFIED via
grep (`grep -rn "IgnorePointer" lib/` returns zero hits pre-phase). This means Layers 2/3
(`Positioned` + `IgnorePointer`) introduce a genuinely new pattern to this codebase, not a rework —
copy directly from RESEARCH.md's "Code Examples" `IgnorePointer` snippet (Flutter SDK built-in
usage, standard shape, no local precedent to defer to instead).

---

### `lib/screens/today/widgets/now_marker.dart` (component, overlay — rewrite)

**Analog:** its own pre-rework self — the color/stroke-weight convention survives even though the
widget's shape (row → overlay) does not.

**What to keep from the current file** (lines 15-44):
```dart
class NowMarker extends StatelessWidget {
  const NowMarker({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Container(width: 24, height: 2, color: color),   // ← 2dp stroke weight: KEEP (UI-SPEC's now-line stroke)
        ...
      ]),
    );
  }
}
```
Keep: `theme.colorScheme.primary` as the sole color source (D-03, zero raw `Colors.*`), the `height:
2` stroke-weight constant (now the full-content-width rule's thickness, per UI-SPEC's micro-spacing
tier), `theme.textTheme.labelMedium`/`labelSmall` + `FontWeight.w600` styling convention for the
label.

**What changes:** the rule no longer spans a fixed 24px leading segment inside a `Row` — it spans
`double.infinity`/full content width via a `Positioned(left: 0, right: 0, ...)` parent. The trailing
`color.withValues(alpha: 0.35)` fade (line 38) is **dropped per UI-SPEC** ("Fade / trailing opacity:
Dropped"). The bare `'Now'` label becomes a pill/chip (`"Now · <formatMinutes(nowMinutes)>"`) with
`colorScheme.primary` fill + `onPrimary` text, `4dp` radius, `8dp`/`4dp` padding — new content, but
follow the same "read `theme.colorScheme.X` once at the top of `build()`, no hardcoded color"
discipline this file already demonstrates.

**Semantics wrapping convention to copy from the call site being deleted** (`today_screen.dart:663-673`):
```dart
Semantics(
  label: 'Now — ${formatMinutes(minutes)}',
  excludeSemantics: true,
  child: TimelineRowTile(startMinutes: minutes, child: const NowMarker()),
)
```
The learned lesson here (24-REVIEW.md WR-01, cited in the comment) is: **the `Semantics` wrapper must
enclose the whole positioned element, not be passed as an inner `child`** — for the new overlay this
means `Semantics` should wrap the full `Positioned`'s child (rule + chip together), not just the chip,
to avoid a double-announcement regression.

---

### `lib/screens/today/widgets/timeline_row_tile.dart` (component, layout wrapper)

**Analog:** itself, pre-rework. **Decision already made by RESEARCH.md (Open Question 2,
recommendation adopted here):** keep it as a pure 16dp-inset + 52dp-reserved-column wrapper; delete
its time-text branch.

**Current shape** (lines 45-87) — the part to KEEP (the `kGutterWidth` constant, the 16dp
`EdgeInsets.symmetric(horizontal: 16)` inset, the `Row` layout with `SizedBox(width: kGutterWidth)` +
`Expanded(child: child)`):
```dart
const double kGutterWidth = 52.0;  // KEEP — reused verbatim for the new hour-axis column width

class TimelineRowTile extends StatelessWidget {
  const TimelineRowTile({super.key, required this.startMinutes, required this.child});
  final int? startMinutes;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: kGutterWidth, child: /* DELETE this ternary's Text branch */),
          Expanded(child: child),
        ],
      ),
    );
  }
}
```
Delete the `startMinutes != null ? Text(formatMinutesCompact(startMinutes!), style: gutterStyle) :
const SizedBox.shrink()` ternary and the now-dead `gutterStyle`/`formatMinutesCompact` call — replace
the `SizedBox(width: kGutterWidth, ...)` content with `const SizedBox.shrink()` unconditionally
(still reserves the column width, shows nothing — the hour axis, a separate `Positioned` overlay, now
owns that visual column). Do not change the `startMinutes` constructor param's *presence* if any
call site still needs it for something else — check call sites first; if none remain, it can be
dropped, but the wrapper's core inset/gutter-width contract stays.

**The `kGutterWidth` doc comment's warning is directly relevant to this phase's new geometry
constants** (lines 8-24) — its "do not size from a `flutter test` text measurement" lesson applies
identically to any new width/height assertion this phase adds (Pitfall 7): verify in a real browser
via `tools/serve-uat.py`, not just `flutter test`.

---

### `lib/screens/today/widgets/free_time_row.dart` (component)

**Analog:** itself — **no code change needed for the dotted-rule painter**, per UI-SPEC ("the rule's
painter already tiles to fill an arbitrary `size.height` — no code change needed there").

**Existing tiling painter, confirmed arbitrary-height-safe** (lines 58-85):
```dart
class _DottedRulePainter extends CustomPainter {
  const _DottedRulePainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = size.width..strokeCap = StrokeCap.round;
    const dotSpacing = 4.0;
    var y = 0.0;
    while (y < size.height) {           // ← already loops to size.height, whatever it is
      canvas.drawLine(Offset(size.width / 2, y), Offset(size.width / 2, y + 2), paint);
      y += dotSpacing;
    }
  }
}
```
What changes per UI-SPEC: only the **outer layout** — vertical centering within the full proportional
height instead of the current `Padding(vertical: 8)` intrinsic sizing (lines 36-53). Change the
`Column`/`Row` alignment, not the painter.

---

### `lib/screens/today/widgets/hour_axis.dart` (new file, component)

**No existing hour-axis analog in this codebase** — this is new code. Closest precedents to model it
on, both already-shipped `CustomPainter`-over-arbitrary-`size` patterns:

1. `free_time_row.dart`'s `_DottedRulePainter` (above) for "a `CustomPainter` reading `size.height`
   from its parent and drawing relative to it" — the hairline should be a plain
   `Paint()..color = theme.colorScheme.outlineVariant..strokeWidth = 1` `canvas.drawLine` from `(52,
   0)` to `(size.width, 0)` inside a `SizedBox`/`Positioned` at the computed `top:` offset — simpler
   than a tiling loop since it's one line, not a dotted repeat.
2. `chunk_card.dart`'s `_DashedBorderPainter` (below) for "reading color from `theme.colorScheme.X`
   passed in via constructor, never a raw literal" — the same discipline applies to the new
   `HourAxisLabel`/hairline widget.
3. `timeline_row_tile.dart`'s `kGutterWidth` constant and its `bodySmall`/`onSurfaceVariant`/
   `tabularFigures` label-style convention (lines 66-70) — reuse for the hour label's `TextStyle`,
   since the UI-SPEC specifies the same `bodySmall`/`onSurfaceVariant` family "just repositioned."

---

### `lib/screens/schedule/widgets/chunk_card.dart` (component)

**Analog:** itself, pre-rework. Two distinct edits.

**1. `_DashedBorderPainter` — parameterize, don't duplicate** (lines 160-199):
```dart
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, this.strokeWidth = 1});
  final Color color;
  final double strokeWidth;
  static const double _radius = 12;
  static const double _dashWidth = 4;
  static const double _dashGap = 4;
  // paint() uses _radius/_dashWidth/_dashGap as instance-level constants today
}
```
Add `dashWidth`, `dashGap`, `radius` as optional constructor params defaulting to the current 4/4/12
(Pitfall 5) so the existing Full-tier break call site (`chunk_card.dart:112-115`,
`strokeWidth: isLong ? 1.5 : 1`) is unaffected:
```dart
_DashedBorderPainter(
  color: theme.colorScheme.outlineVariant,
  strokeWidth: isLong ? 1.5 : 1,
  // NEW, Compact-tier only: dashWidth: 2, dashGap: 2, radius: 6,
)
```

**2. `_buildBreak` — add a density-tier branch** (lines 96-152): the existing method already
branches on `isLong` for `titleStyle`/padding/icon; extend the same `if (isLong) { ... } else { ... }`
shape to also branch on `chunk.durationMinutes < 20` (Compact tier) — Full-tier long-break code
(unchanged, "no change needed — it already fits" per UI-SPEC) stays exactly as-is; add a new
Compact-tier branch that drops the duration text, uses `bodySmall` label only, `0dp` vertical padding,
and the new `dashWidth: 2, dashGap: 2, radius: 6` painter params.

**3. `showStartTime` default flip** — `ChunkCard`'s own field doc comment (lines 56-62) already
explains the flag's purpose precisely; only the *call site's* passed value changes (`false` → `true`
for Full-tier work chunks in `today_screen.dart`'s `SwipeableChunkCard(... showStartTime: false,
...)` at line 703), not `ChunkCard`'s own default (which stays `true` — unaffected, since
`schedule_screen.dart`'s plain-list call site is out of scope and already relies on that default).

---

### `lib/screens/schedule/widgets/swipeable_chunk_card.dart` (component — verify only, no functional change needed)

**Analog:** itself. **Factual correction carried from RESEARCH.md Pitfall 6, re-verified here by
direct read:** lines 68-74 confirm breaks have **no `onTap` forwarded today**:
```dart
if (chunk.chunkType != ChunkType.work) {
  return ChunkCard(chunk: chunk, goalColor: goalColor, showStartTime: showStartTime);
  // ← no onTap param passed, and ChunkCard._buildBreak (chunk_card.dart:96-152)
  //   never wraps its content in a GestureDetector.
}
```
**No task should be scoped to "remove break tap targets"** — there is nothing to remove. If a plan
task references this, redirect it to verification only: grep `_buildBreak`/this early-return branch
for `GestureDetector`/`onTap` (both return empty).

---

## Shared Patterns

### Injectable clock / single-sample discipline
**Source:** `today_screen.dart:61-93`, doc comments throughout
**Apply to:** any new code touching `nowMinutes`, `rangeStart`/`rangeEnd`, or the scroll-offset
arithmetic — all must derive from `build()`'s one `_nowFn()`/`nowDt` sample, never a fresh
`DateTime.now()` call.
```dart
late final DateTime Function() _nowFn = widget.now ?? DevClock.now;
```

### Zero raw `Colors.*` literals — semantic `ColorScheme` slots only
**Source:** `now_marker.dart:20-21`, `chunk_card.dart` (`theme.colorScheme.outlineVariant`,
`.primary`, `.onSurfaceVariant` throughout)
**Apply to:** the now-line overlay, hour-axis hairline/labels, Compact-tier break — every new color
reference in this phase.
```dart
final theme = Theme.of(context);
final color = theme.colorScheme.primary; // never Colors.red or a hex literal
```

### One-shot post-frame-callback flag discipline
**Source:** `today_screen.dart:1098-1114` (existing `_didCentreLiveRow` block)
**Apply to:** the new single centre-on-open flag/callback.
```dart
if (!_didCentreOnOpen) {
  _didCentreOnOpen = true; // set BEFORE scheduling — same-tick rebuild can't double-fire
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    // ... read maxScrollExtent HERE, not in build() ...
  });
}
```

### Pure-function + unit-test pairing (no widget pump)
**Source:** `lib/screens/today/timeline.dart` ↔ `test/screens/today_timeline_model_test.dart`
**Apply to:** `floorToHour`, `ceilToHour`, `hourBoundariesIn`, and the rendered-range formula — new
pure functions should each get a `group('functionName — ...')` block of plain `test()` cases, no
`pumpWidget`, matching the existing file's structure:
```dart
// today_timeline_model_test.dart:4 — "Pure test() cases — no widget pump, no providers, no Hive."
group('buildTimeline — structural cases', () {
  test('empty chunks returns an empty list', () { ... });
  ...
});
```

### `IgnorePointer` for decorative overlays (new to this codebase this phase)
**Source:** Flutter SDK built-in — no in-repo precedent exists yet (`grep -rn "IgnorePointer" lib/`
returns zero hits pre-phase); RESEARCH.md's Code Examples section is the concrete target.
**Apply to:** both the hour-axis layer and the now-line overlay — neither must intercept a
Complete/Skip tap on the card beneath it.
```dart
IgnorePointer(
  child: Semantics(
    label: 'Now — ${formatMinutes(nowMinutes)}',
    excludeSemantics: true,
    child: const NowLineOverlay(),
  ),
)
```

### `flutter test` font-metrics harness caveat
**Source:** `timeline_row_tile.dart:8-24` (`kGutterWidth`'s doc comment, the 46→75→52 correction
story)
**Apply to:** every new width/height assertion this phase adds — geometric assertions on explicit
`Container`/`Positioned` values (SAFE), text-fit/ellipsis assertions (HARNESS-BOUND, needs
`tools/serve-uat.py` real-browser verification per CLAUDE.md).

---

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `lib/screens/today/widgets/hour_axis.dart` | component (overlay) | render-only | No existing hour-boundary/range-generating axis exists anywhere in `lib/` — nearest precedents are the two `CustomPainter`s cited above (`_DottedRulePainter`, `_DashedBorderPainter`), which cover the painting mechanics but not the "generate boundary values from a range" logic (`hourBoundariesIn`, new in `time_format.dart`) |
| The `Stack`/`Positioned`/`IgnorePointer` overlay mechanism itself | render architecture | request-response | `grep -rn "Stack\|Positioned\|IgnorePointer" lib/screens/today/ lib/screens/schedule/` confirms no existing `Stack`+`Positioned` overlay composition in this codebase — this phase introduces the pattern for the first time; RESEARCH.md's Code Examples section (not a codebase analog) is the reference to follow |

---

## Metadata

**Analog search scope:** `lib/screens/today/`, `lib/screens/today/widgets/`,
`lib/screens/schedule/widgets/`, `lib/utils/`, `test/screens/`
**Files scanned:** 9 source files read directly (full or targeted sections); 2 additional files
grep-verified for absence of a pattern (`IgnorePointer`, `Stack`/`Positioned` in scope directories)
**Pattern extraction date:** 2026-08-10
