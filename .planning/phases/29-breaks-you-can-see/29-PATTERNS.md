# Phase 29: Breaks You Can See - Pattern Map

**Mapped:** 2026-08-20
**Files analyzed:** 6 source files (3 modified, 0 new source), 2 test files (modified), 1 tooling
script (new), 1 measurement-artifact directory (new, not code)
**Analogs found:** 6 / 6 — every file has a direct, high-quality in-repo analog. This phase touches
established files, not new architecture, so match quality is uniformly "exact" (same file, prior
tier) or "role-match" (sibling density-tier component, Phase 27).

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/screens/schedule/widgets/chunk_card.dart` (`ChunkCardDensity` enum + `_buildBreak` + `_WorkChunkContent` switches) | component | request-response (pure render, no I/O) | itself — the existing `compact` tier is the direct sibling to copy from | exact (self, prior tier) |
| `lib/screens/today/timeline_geometry.dart` (`kSubCompactBreakMinHeight` constant) | config/utility (pure geometry constants) | transform (arithmetic only) | `kCompactLiveMinHeight` (same file, lines 108-150) | exact — same file, same "measured threshold constant" pattern |
| `lib/screens/today/today_screen.dart` (density-selection ternary, lines 789-792) | controller (screen-level dispatch) | request-response | itself — existing `isBreak` ternary, one line up | exact (self, extend from 2-way to 3-way) |
| `test/screens/today_screen_test.dart` (new `subCompact` widget tests + tier-boundary test) | test | request-response | `LiveRowCard` tier-boundary test, `live_row_card_test.dart`-style boundary assertion (per RESEARCH.md, lines 759-772 in that file) + existing break-density tests (lines 601-629, same file) | exact — same file, established per-density test shape |
| `test/screens/today_timeline_model_test.dart` (SEEBREAK-02 ground-truth test) | test | transform | `'GRID-01: every hour boundary is equidistant...'` test, same file, lines 440-477 | exact — same file, same ground-truth-literal pattern |
| `.planning/phases/29-breaks-you-can-see/tools/measure_break_compact.py` (new) | utility (measurement script) | file-I/O (PNG in → stdout report) | `.planning/spikes/001-live-row-in-a-true-grid/tools/measure_hours.py` (band-detection method) and `.planning/phases/27-true-grid/tools/measure_card_fill.py` (fill-region method) | role-match — adapt `measure_hours.py`'s derive-background approach per RESEARCH.md Open Question 2, not `measure_card_fill.py`'s saturated-fill approach |

No files in this phase lack an analog — everything is an extension of an existing, already-patterned
component. There is no "No Analog Found" section as a result.

## Pattern Assignments

### `lib/screens/schedule/widgets/chunk_card.dart` — `ChunkCardDensity` enum (component, request-response)

**Analog:** itself — the existing three-value enum, lines 12-33.

**Enum doc-comment pattern to copy** (lines 12-33, exact text in tree):
```dart
enum ChunkCardDensity {
  /// Today's card, byte-for-byte unchanged. Renders every field: title,
  /// clock-time range, rationale, priority chip, valence chip, action row.
  /// This is the default — ...
  detailed,

  /// The UI-SPEC's "Full" tier (`26-UI-SPEC.md` § "Row content density"): ...
  full,

  /// The UI-SPEC's "Compact" tier: title only (single line, ellipsis). ...
  compact,
}
```
Add `subCompact` as a fourth value, doc-commented in the same style: cite `29-UI-SPEC.md`, state the
trigger (`slot < kSubCompactBreakMinHeight`) and scope (break rows only; work-chunk arm is a
documented dead path — see UI-SPEC "Scope boundary").

---

### `lib/screens/schedule/widgets/chunk_card.dart` — `_buildBreak` (component, request-response)

**Analog:** itself — the existing `compact` branch, lines 129-160.

**Core pattern to copy (the `if (density == ...)` early-return shape, checked BEFORE `compact`)**
(lines 129-160):
```dart
Widget _buildBreak(BuildContext context) {
  final theme = Theme.of(context);
  final isLong = chunk.chunkType == ChunkType.longBreak;
  final title = isLong ? 'Long break' : 'Short break';

  // Compact tier (density-driven, CAL-01): label only, no leading icon,
  // no duration text, no completed check icon — D-02 forbids inflating the
  // box, so at a 5-minute break's 27.5px slot the only lever is content.
  if (density == ChunkCardDensity.compact) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: CustomPaint(
        painter: _DashedBorderPainter(...),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          child: Center(child: Text(title, style: ...)),
        ),
      ),
    );
  }
  // detailed / full fallthrough unchanged below...
```
The UI-SPEC's `_buildSubCompactBreak` (already fully specified, `29-UI-SPEC.md` lines 178-211) must
be inserted as an `if (density == ChunkCardDensity.subCompact) return _buildSubCompactBreak(...)`
**above** this `compact` check — this is an `if`-chain, not a `switch`, so Dart gives no
exhaustiveness error if the branch is omitted (RESEARCH.md Pitfall 1's "silent failure mode").

**Widget-tree pattern to copy for `_buildSubCompactBreak` itself:** `LiveRowCard._buildSingleLine`
(`lib/screens/today/widgets/live_row_card.dart`, lines 262-300) — the closest sibling "smallest
tier, zero-margin, one-line, `Semantics`-wrapped" pattern in the codebase:
```dart
/// The single-line tier — one row of text, nothing else. Fits a 5-minute
/// break's 20dp slot, and anything else below [kCompactLiveMinHeight].
///
/// Margin is zero VERTICALLY ONLY (PD-27-01) — the smallest guaranteed
/// slot cannot spend any of its height on margin and still leave room for
/// one legible text line, but zeroing the HORIZONTAL margin would bleed
/// this card to the raw viewport edge, since it is positioned
/// `left: 0, right: 0` with no [TimelineRowTile] ...
Widget _buildSingleLine(BuildContext context, ThemeData theme, ColorScheme colorScheme) {
  final style = theme.textTheme.labelMedium?.copyWith(...);
  final row = Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [ Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)), ... ],
    ),
  );
  return Semantics(
    label: 'Right now: $title, $remainingLabel',
    excludeSemantics: true,
    button: onTap != null,
    onTap: onTap,
    ...
```
Note one structural difference the UI-SPEC's own widget already resolves: `_buildSingleLine` zeroes
margin *vertically only* because it renders with no `TimelineRowTile` wrapper (bleeds to the raw
edge otherwise); `_buildSubCompactBreak` zeroes margin on *all four sides* because it DOES render
through `TimelineRowTile` and would double-inset otherwise (UI-SPEC "Horizontal insets" note,
`29-UI-SPEC.md` lines 240-245). Copy the zero-margin discipline and the `Semantics`
`excludeSemantics: true` + restated-duration-label idiom; do not copy the vertical-only exception.

**Semantics restated-duration idiom** (the exact precedent the UI-SPEC's own `_buildSubCompactBreak`
cites) is `LiveRowCard`'s: visible text drops information a screen reader still needs, so
`Semantics(label: ..., excludeSemantics: true)` restates it. Copy this shape verbatim.

---

### `lib/screens/schedule/widgets/chunk_card.dart` — `_WorkChunkContent` density switches (component, request-response)

**Analog:** itself — the two existing exhaustive `switch (density)` expressions, lines 346-359 and
397-413.

**Pattern to copy (both switches, both need a `subCompact` arm — this is a compile error until both
are updated):**
```dart
final contentPadding = switch (density) {
  ChunkCardDensity.compact => const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
  ChunkCardDensity.full => const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  ChunkCardDensity.detailed => const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  // ChunkCardDensity.subCompact => ... (new arm required)
};
...
child: switch (density) {
  ChunkCardDensity.compact => _buildCompactContent(context, theme, isResolved),
  ChunkCardDensity.full => _buildFullContent(context, theme, isResolved),
  ChunkCardDensity.detailed => _buildDetailedContent(context, theme, isResolved),
  // ChunkCardDensity.subCompact => ... (new arm required, dead path — see UI-SPEC scope boundary)
},
```
Per UI-SPEC ("Scope boundary" point 3): the new arm is a **documented, unreachable defensive
fallback** — route it to content visually identical to the break sub-compact treatment, using
`_titleText` in place of the break's `title`. Do not build a measured `kSubCompactWorkMinHeight`
constant for it.

---

### `lib/screens/today/timeline_geometry.dart` — `kSubCompactBreakMinHeight` (config/utility, transform)

**Analog:** `kCompactLiveMinHeight`, same file, lines 108-150 — the house doc-comment style to match
exactly (per RESEARCH.md's own instruction).

**Doc-comment template to copy** (structure, not literal text — this constant's own numbers will
differ):
```dart
/// **MEASURED (2026-08-18, plan 27-04).** The slot height at or above which
/// `LiveRowCard`'s compact tier fits; below it the single-line tier is used
/// (there is no third tier).
///
/// **Method:** headless Chromium (`--use-gl=swiftshader
/// --enable-unsafe-swiftshader`), viewport `430`×930 at DPR 1 (screenshot px
/// = logical px), debug build (`flutter build web --debug --source-maps
/// --pwa-strategy=none`) served through `tools/serve-uat.py` on port `8137`,
/// simulated clock parked 10 minutes (40%) into a live 25-minute Exercise
/// chunk (8:00–8:25 AM). A freshly onboarded profile generates its own day, so
/// ... [full raw measured number + explicit safety margin + relationship to
/// numerically-close sibling constants + "what would invalidate this" ]
const double kCompactLiveMinHeight = 88.0;
```
Required sections per RESEARCH.md: date, viewport, method, raw measured number + explicit safety
margin, relationship to any numerically-close sibling constant (Pitfall 3 — check distance from
`kFullTierMinHeight`/`kFullBreakMinHeight`/`kCompactLiveMinHeight` (all `88.0`) and
`kNowLineHeight`/`kHourAxisHeight` (`28.0`/`20.0`)), and a "what would invalidate this value"
paragraph. Colocate immediately after `kFullBreakMinHeight` (line ~79), per the file's "one file
owns every Today-timeline density threshold" convention.

**Sibling constant for the "what this measures" framing:** `kFullBreakMinHeight`'s own short-form
comment (lines 74-79) is the template for stating *what* a threshold constant means precisely
(here: the point at which the *existing, unchanged* `compact` tier's own natural height stops
fitting — not a measurement of the new tier itself).

---

### `lib/screens/today/today_screen.dart` — density-selection ternary (controller, request-response)

**Analog:** itself, lines 786-795 — extend the existing 2-way break ternary to 3-way; the work
ternary is explicitly untouched.

**Current pattern (verified in tree, lines 786-795):**
```dart
final isBreak =
    chunk.chunkType == ChunkType.shortBreak ||
    chunk.chunkType == ChunkType.longBreak;
final density = isBreak
    ? (slot >= kFullBreakMinHeight
          ? ChunkCardDensity.full
          : ChunkCardDensity.compact)
    : (slot >= kFullTierMinHeight
          ? ChunkCardDensity.full
          : ChunkCardDensity.compact);
```
**Target pattern** (from `29-UI-SPEC.md`, already fully specified — copy verbatim):
```dart
final density = isBreak
    ? (slot >= kFullBreakMinHeight
          ? ChunkCardDensity.full
          : slot >= kSubCompactBreakMinHeight
              ? ChunkCardDensity.compact
              : ChunkCardDensity.subCompact)
    : (slot >= kFullTierMinHeight
          ? ChunkCardDensity.full
          : ChunkCardDensity.compact);   // work branch UNCHANGED
```
**Unchanged safety-net wrapper immediately below** (lines 802-817, `Positioned` → `ClipRect` →
`OverflowBox` → `TimelineRowTile`) — nothing here changes; PD-10's comment already states the
invariant this phase relies on ("the slot is always exactly `durationMinutes * kPixelsPerMinute`").
Do not touch this block.

---

### `test/screens/today_screen_test.dart` — new `subCompact` tests (test, request-response)

**Analog 1 (per-density widget test shape):** existing break-density tests, same file, lines
601-629:
```dart
testWidgets(
  'compact short break renders the label but not its duration text',
  (tester) async { ... pump ChunkCard(chunk: _breakChunk(type: ChunkType.shortBreak), density: ChunkCardDensity.compact) ... },
);
testWidgets(
  'full short break renders both the label and its duration text',
  (tester) async { ... },
);
```
Mirror this shape for `subCompact`: pump `ChunkCard(..., density: ChunkCardDensity.subCompact)`,
assert label present, no `CustomPaint`, no `Card`, exactly one `Divider` pair (per RESEARCH.md's
Test Map entry).

**Analog 2 (tier-boundary test shape):** the `LiveRowCard` tier-boundary test (per RESEARCH.md,
"`'tier boundary: kCompactLiveMinHeight is compact, one dp below is single-line'`") — pump at the
boundary value, then boundary−1, assert the density flips. Reuse this exact shape for
`kSubCompactBreakMinHeight`: pump `today_screen.dart`'s full render path (not `ChunkCard` in
isolation, since RESEARCH.md notes this is a genuine coverage gap — no existing test drives
`today_screen.dart`'s selection ternary against a break at a specific slot height) at the threshold,
then threshold−1dp, assert `compact` flips to `subCompact`.

**Analog 3 (forwarding-regression symmetry):** `'SwipeableChunkCard forwards density on the break
early-return path ...)'`, same file, lines 632-651 — same pattern (pump `SwipeableChunkCard` with an
explicit `density:`, assert the break content) extended to `density: ChunkCardDensity.subCompact`
for symmetry; no source change expected in `swipeable_chunk_card.dart` itself (grep-confirmed no
`ChunkCardDensity`-specific branching at its two forwarding call sites, lines 80 and 132).

---

### `test/screens/today_timeline_model_test.dart` — SEEBREAK-02 ground-truth test (test, transform)

**Analog:** `'GRID-01: every hour boundary is equidistant, even with a live chunk present'`, same
file, lines 440-477.

**Pattern to copy (ground-truth-literal, never self-referential) — full text in tree:**
```dart
test(
    'GRID-01: every hour boundary is equidistant, even with a live '
    'chunk present', () {
  // ... Ground truth is 60 * kPixelsPerMinute and nothing else: this must
  // NOT re-derive any implementation-internal quantity ...
  final geometry = TimelineGeometry.forDay(
    nowMinutes: 550, firstStartMinutes: 480, lastEndMinutes: 1020,
    liveStartMinutes: 540, liveEndMinutes: 565,
  );
  final boundaries = geometry.hourBoundaries;
  expect(boundaries.length, greaterThan(2), reason: '...');
  for (var i = 0; i < boundaries.length - 1; i++) {
    expect(
      geometry.yFor(boundaries[i + 1]) - geometry.yFor(boundaries[i]),
      60 * kPixelsPerMinute,
      reason: '...',
    );
  }
});
```
Copy the literal-ground-truth discipline exactly: `expect(geometry.heightFor(540, 5), 20.0)` — a
bare `double` literal, not `5 * kPixelsPerMinute` re-derived, and never a call into
`_buildSubCompactBreak`'s own rendered output compared against `heightFor()`'s own return value
(RESEARCH.md Pitfall 4 — this is the exact self-referential-blindness trap the file's own comment
already names).

---

### `.planning/phases/29-breaks-you-can-see/tools/measure_break_compact.py` (new) — measurement script (utility, file-I/O)

**Analog:** `.planning/spikes/001-live-row-in-a-true-grid/tools/measure_hours.py` (derive-background
band-detection method — the one to crib from per RESEARCH.md's Open Question 2, NOT
`measure_card_fill.py`'s saturated-fill method, since the break's `compact` tier has no solid fill
region, only a dashed outline).

**Header/docstring pattern to copy** (`measure_hours.py`, lines 1-20):
```python
#!/usr/bin/env python3
"""Pixel-measure the vertical distance between hour labels on the Today timeline.

This is the only measurement that can see Phase 27's defect. `flutter test`
cannot: 240dp and 372dp both satisfy every existing assertion, because no test
asserts that consecutive hour boundaries are equidistant ...

Method: the hour-axis labels ("8 AM", "9 AM", ...) are the only ink in the
timeline's left gutter (x < kGutterWidth = 40). Scan that column strip for rows
containing non-background pixels, group contiguous rows into label bands, and
report the centre-to-centre distance between consecutive bands. ...

Usage: measure_hours.py <png> [--gutter=40] [--top=200]
"""
import sys
from collections import Counter
from PIL import Image
```
Adapt: derive-background-then-flag-differing-pixels method stays; target region changes from the
left gutter's hour labels to the break card's dashed-outline bounding box; empirically verify the
gap-bridging tolerance (`<=3` rows in `measure_hours.py`) against the first real screenshot, since a
dashed (non-continuous) outline may need a larger bridge tolerance (RESEARCH.md's own open
question — do not assume the existing tolerance transfers unmodified).

Do not modify `drive.cjs` — reuse it unmodified (per RESEARCH.md's Don't-Hand-Roll table), driving
it at a fresh dedicated port (**8143** — confirmed unused via repo-wide grep, per RESEARCH.md
Pitfall 6) rather than any of the already-claimed ports (`8080`, `8095-8097`, `8101`, `8123`,
`8131-8134`, `8137`, `8142`, `8788`, `8840`).

## Shared Patterns

### Density-tier selection: slot-height-driven, never chunk-type-driven

**Source:** `26-UI-SPEC.md`'s stated principle, reused verbatim by `LiveRowCard.build()`
(`lib/screens/today/widgets/live_row_card.dart` line 92-95: `slotHeight >= kCompactLiveMinHeight ?
_buildCompact(...) : _buildSingleLine(...)`) and by `today_screen.dart`'s existing ternary.
**Apply to:** `today_screen.dart`'s extended ternary and `chunk_card.dart`'s new `if` branch — the
new tier is selected purely by comparing `slot` (a pixel value) against a named constant, never by
inspecting `chunk.chunkType` or `chunk.durationMinutes` directly. This is what keeps the rule
correct if a future cadence change produces a break duration that lands in the currently-dead
`compact` band.

### Zero-margin smallest-tier discipline (PD-27-01 precedent)

**Source:** `LiveRowCard._buildSingleLine`'s doc comment (`live_row_card.dart` lines 249-257) —
"the smallest guaranteed slot cannot spend any of its height on margin and still leave room for one
legible text line."
**Apply to:** `_buildSubCompactBreak` — zero margin on **all four sides** (not vertical-only, since
this widget DOES render through `TimelineRowTile` and would double-inset horizontally otherwise —
UI-SPEC's explicit, deliberate divergence from the `LiveRowCard` precedent, stated so a reviewer
does not "correct" it back to vertical-only).

### House-style measured-constant doc comment

**Source:** `kCompactLiveMinHeight` (`timeline_geometry.dart` lines 108-150) and `kPixelsPerMinute`
(same file, lines 12-56) — both record: date measured, exact method (viewport, DPR, Chromium flags,
build type, serving tool, port), raw number, explicit safety margin, and (critically) a "what would
invalidate this value" paragraph, plus — when relevant — an explicit statement of the constant's
relationship to any numerically-close sibling (both `kFullTierMinHeight` and `kCompactLiveMinHeight`
independently landed at `88.0`, and both doc comments say so).
**Apply to:** `kSubCompactBreakMinHeight`'s new doc comment — non-negotiable per RESEARCH.md
Pitfall 3 and Pitfall 5; must NOT cite a `flutter test`/`tester.getSize()` source.

### `Semantics` restated-duration idiom for a visually truncated label

**Source:** `LiveRowCard._buildSingleLine` (`live_row_card.dart` lines 289-300) — visible text drops
information (here: the countdown is always shown, but the pattern of "restate what's missing" is
what matters); `NowLineOverlay` uses the same idiom per RESEARCH.md.
**Apply to:** `_buildSubCompactBreak`'s `Semantics(label: '$title, ${chunk.durationMinutes} min',
excludeSemantics: true, ...)` — the visible label drops the duration text (`'Short break'` only,
no `'5 min'`), and semantics restates it, exactly as `29-UI-SPEC.md` already specifies.

### Ground-truth-literal test discipline for anything claiming grid accuracy

**Source:** `today_timeline_model_test.dart`'s `GRID-01` test (lines 440-477) and its own explicit
comment: "this must NOT re-derive any implementation-internal quantity ... or it inherits the same
self-referential blindness."
**Apply to:** every SEEBREAK-02 assertion, in both the pure-arithmetic test
(`today_timeline_model_test.dart`) and the pixel-measurement step (`measure_hours.py` re-run against
a sub-compact screenshot) — two complementary proofs required, neither sufficient alone
(RESEARCH.md Pitfall 4).

## No Analog Found

None — every file this phase touches or creates has a direct, current, well-documented analog
already in the repository (see table above). This is expected: the phase is an extension of an
established density-tier pattern (Phase 27), not new architecture.

## Metadata

**Analog search scope:** `lib/screens/schedule/widgets/`, `lib/screens/today/`,
`lib/screens/today/widgets/`, `test/screens/`, `.planning/spikes/001-live-row-in-a-true-grid/tools/`,
`.planning/phases/27-true-grid/tools/`.
**Files scanned (read in full or targeted ranges):** `chunk_card.dart`, `timeline_geometry.dart`,
`today_screen.dart` (call-site range), `live_row_card.dart`, `today_screen_test.dart` (relevant
ranges), `today_timeline_model_test.dart` (GRID-01 range), `measure_hours.py` (header).
**Pattern extraction date:** 2026-08-20
