# Phase 24: Where Am I - Research

**Researched:** 2026-08-08
**Domain:** Flutter row-model / pure-function state threading (internal codebase change, no external libraries)
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **The marker is a position, not a second detector.** Its clock position must come from the same
  `nowDt` sample `build()` already takes and passes to `resolveNowState`. It must never re-derive
  *which activity is current*. This is the single-detector rule that Phase 17 established, Phase 22
  spent a whole plan enforcing (two competing detectors deleted), and a Phase 22 code review
  extended (a third killed in the "Start focus" button). `timeline.dart` carries INVARIANT 1 —
  "this function NEVER reads the clock" — and it must survive: pass the marker's position in as a
  parameter, do not read a clock inside `buildTimeline`.
- **Show the marker when it adds information.** When a row is live, the swelled full-bleed card
  already answers "where am I", so a marker adjacent to it is redundant. The states that need it are
  `PreStart`, `GapBeforeNext`, `Overdue` and `DayComplete`. Planning should decide and justify
  whether to suppress it in the `Active` case or always render it.

### Claude's Discretion

Visual treatment of the marker (rule, label, colour), and where exactly it inserts when "now" falls
*inside* a resolved chunk's window rather than between rows.

### Deferred Ideas (OUT OF SCOPE)

- Dimming *unresolved* chunks whose window has passed. Not observed as a problem in Dan's session
  (his past chunks were all resolved), and it risks making an overdue chunk look inactionable. Revisit
  only if it surfaces in real use.
- Sketch variants B and D from `served/nowsketch/` (quieting non-live rows). Dan chose C in Phase 23
  and B/D remain available if the marker alone proves insufficient.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| NOW-01 | The timeline carries a visible now-marker at the current clock position; position derives from the same clock sample `resolveNowState` uses — never a second opinion about which activity is current. | §Architecture Patterns "Row-model mechanics" + "Insertion semantics" gives the exact signature change and insertion algorithm. §Common Pitfalls documents the ID collision with the *other* NOW-01/NOW-02 (Phase 17) so grep-based verification isn't fooled. |
| NOW-02 | A leading "Free until <time>" row never describes a window that has already closed. | §Architecture Patterns "NOW-02 mechanics" gives the exact guard condition and shows it falls out of the same `nowMinutes` parameter NOW-01 needs. §Common Pitfalls flags the one existing test (`today_screen_test.dart:364-370`) that currently pins the buggy behavior and must be corrected, not just extended. |

**Note on requirement-ID collision:** `NOW-01`/`NOW-02` were already used once before, for a *different*
pair of requirements, in v1.3 Phase 17 ("Time-Anchored Home") — see `.planning/milestones/v1.3-phases/17-time-anchored-home/`.
`test/screens/today_screen_now_state_test.dart:1-8,181` still carries a `group('resolveNowState unit
tests (NOW-01/NOW-02)', ...)` label referring to *that* pair (the first-unresolved-chunk bug fix), not
this phase's. Both are real, both are satisfied, but they are not the same requirements. See §Common
Pitfalls, Pitfall 1.
</phase_requirements>

<claude_md_constraints>
## Project Constraints (from CLAUDE.md)

- **No LLM calls, no "smart" suggestions, no in-app AI surface** — irrelevant risk for this phase (it's
  pure deterministic row-model math), but confirms nothing here should ever become a heuristic guess;
  the marker's position is arithmetic on a supplied clock sample, nothing else.
- **Host the DEBUG build for UAT, single-bundle (`flutter build web --debug --source-maps
  --pwa-strategy=none`), never `flutter run -d web-server`.** Applies to however this phase's UAT
  sign-off is served — no new hosting concern introduced by this phase.
- **Never swap build types on one origin/port** (service-worker collision) and **headless Chromium GPU
  exhaustion gives a false "blank page"** — both apply if `go-look-at` or a served debug build is used
  to visually verify the marker; neither is new to this phase.
- **Dart SDK `^3.10.3` / Flutter `>=3.18.0-18.0.pre.54`, `flutter_lints`, Provider + `ChangeNotifier`,
  Hive persistence** — all unaffected; this phase touches no persistence layer, no provider, no routing.
- **Test with `flutter test`**, format with `dart format lib/`, lint with `flutter analyze` — the
  existing project commands, unchanged by this phase.
</claude_md_constraints>

## Summary

This is a small, fully self-contained Flutter internal change: one new `TimelineRow` subtype, one new
quiet row widget, a two-line guard in an existing pure function, and one new parameter threaded from
`build()` through `buildTimeline` to `_buildTimelineRow`. There are no new packages, no new
architectural layers, and no external documentation to consult — every fact in this document was
verified by reading the live code in this checkout on 2026-08-08.

The central design decision is the shape of the new parameter. `buildTimeline` currently has no way to
know "now" as a *position* — `resolveNowState` computes `currentMinutes` internally and discards it.
The correct fix threads a `nowMinutes` value into `buildTimeline` alongside the existing `nowState`
value, computed with the exact same `nowDt.hour * 60 + nowDt.minute` formula `now_state.dart:125`
already uses, from the exact same `nowDt` sample `build()` already takes once per frame (P1 /
22-PATTERNS.md §5) — satisfying "position, never a second opinion" by construction, not convention.
Making this parameter **optional** (`int? nowMinutes`, default `null` = no marker, no NOW-02
suppression) rather than required is the single highest-leverage recommendation in this document: it
keeps the blast radius of this phase to the *feature's own* tests, instead of forcing an edit to all 15
existing `buildTimeline()` call sites in `today_timeline_model_test.dart` (10 of which assert an exact
`rows.length` that a naive required-parameter change would silently break by inserting an unplanned
trailing `NowMarkerRow` under `DayComplete`).

The insertion position for the marker does not need per-`NowState`-variant special-casing. A single
position-based rule — insert the marker row immediately before the first `ChunkRow` whose
`displayStartMinutes > nowMinutes`, or append it at the end if no such chunk exists — is provably
correct for all four "needs it" states (`PreStart`, `GapBeforeNext`, `Overdue`, `DayComplete`) because
of how `resolveNowState`'s own state boundaries are defined (see §Architecture Patterns). The only
extra rule needed is a `nowState is! Active` guard to implement the CONTEXT.md-recommended suppression.
NOW-02's fix reuses the exact same `nowMinutes` value already threaded in for NOW-01 — implementing
NOW-01's plumbing first makes NOW-02 nearly free.

**Primary recommendation:** Add `NowMarkerRow(int minutes)` to the `TimelineRow` sealed hierarchy; add
one optional `int? nowMinutes` parameter to `buildTimeline` (default `null`); insert the marker with a
single position-based rule inside the existing forward loop (no second pass, no re-scan); suppress
insertion only when `nowState is Active`; reuse the same `nowMinutes` to guard `LeadingFreeRow`'s
emission for NOW-02; render the marker with a new `NowMarker` widget (resurrecting the old file's name
and its `colorScheme.primary` convention, dropped strings/scan logic) wrapped in the existing
`TimelineRowTile` so it inherits the 16dp inset and shows the current time in the gutter for free.

## Architectural Responsibility Map

Canopy is a client-only Flutter app with no backend/SSR tier (per CLAUDE.md's Architecture section) —
the generic Browser/SSR/API/CDN/Database tiers in the standard template don't apply. Mapped instead to
this project's own layers (`lib/data`, `lib/providers`, `lib/screens/*` controller, `lib/screens/*/widgets`
render):

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| "Now" classification (which chunk is current) | `now_state.dart` (pure model) | — | Already the single detector (Phase 17/22); untouched by this phase. |
| Row ordering / gap arithmetic / marker position | `timeline.dart` (pure model) | — | `buildTimeline` already owns row-list construction; the marker's insertion point is more row-list geometry, so it belongs here, not in the widget layer. |
| Clock sampling (single read per frame) | `today_screen.dart` `build()` (screen controller) | — | Already the sole call site of `_nowFn()` for both `resolveNowState` and `_liveSecondsRemaining` (WR-01); the marker's `nowMinutes` must be a third consumer of that *same* sample, not a new read. |
| Row rendering / exhaustive switch dispatch | `today_screen.dart` `_buildTimelineRow` (screen controller) | — | The one and only exhaustive switch over `TimelineRow` in the codebase (confirmed by grep, see §Architecture Patterns). |
| Marker visual presentation | new `widgets/now_marker.dart` (dumb widget) | `widgets/timeline_row_tile.dart` (layout) | Mirrors `FreeTimeRow`'s split: a quiet, non-card row widget wrapped by the existing gutter/inset layout primitive. No new layout primitive needed. |

## Standard Stack

No new packages. This phase is a pure extension of existing first-party Dart/Flutter code — one new
sealed-class variant, one new `StatelessWidget`, and a parameter added to an existing pure function.
`pubspec.yaml` confirms `sdk: ^3.10.3` and no relevant dependency needs bumping
`[VERIFIED: pubspec.yaml:22]`.

### Core

No additions.

### Supporting

No additions.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| A new `NowMarkerRow` `TimelineRow` subtype + widget | Overlay/Stack-positioned marker painted on top of the list at a computed pixel offset | Rejected: requires knowing each row's rendered height/offset (the list is a `SingleChildScrollView` + `Column`, not a `CustomScrollView` with `Sliver` geometry), which the pure `buildTimeline` model has no way to express. A row-model entry is the only approach consistent with INVARIANT 1/2 and the existing row-list architecture. |
| Optional `int? nowMinutes` parameter | Required `int nowMinutes` parameter | Rejected as the default recommendation — see Summary and §Common Pitfalls Pitfall 2 for the ~15-test-call-site cost this avoids. A required parameter is defensible if the planner wants "impossible to forget to pass it" at the type level, but budget the test rewrite explicitly if chosen. |

### Package Legitimacy Audit

Not applicable — no new packages are installed by this phase.

## Architecture Patterns

### System Architecture Diagram

```
 today_screen.dart build()
 ────────────────────────
   nowDt = _nowFn()                      ← the ONE clock read per frame (WR-01)
        │
        ├──► resolveNowState(chunks, now: () => nowDt)  ──► nowState (PreStart|Active|Overdue|GapBeforeNext|DayComplete)
        │
        ├──► nowMinutes = nowDt.hour*60 + nowDt.minute   ← NEW: same formula as now_state.dart:125
        │         (recommend extracting a shared `minutesOfDay(DateTime)` helper — see Pitfall 5)
        │
        └──► buildTimeline(chunks, nowState, nowMinutes) ──► List<TimelineRow>
                  │  (pure function — timeline.dart)             │
                  │  INVARIANT 1: never reads the clock            │
                  │  INVARIANT 2: never re-sorts chunks             ▼
                  │                                    [LeadingFreeRow?, NowMarkerRow?,
                  │                                     ChunkRow, GapFreeRow?, ChunkRow, ...]
                  ▼
        for (row in timelineRows) _buildTimelineRow(context, row, nowState, secondsRemaining)
                  │  (the ONE exhaustive switch over TimelineRow in the codebase)
                  ├─ LeadingFreeRow  → TimelineRowTile(child: FreeTimeRow.until(...))
                  ├─ GapFreeRow      → TimelineRowTile(child: FreeTimeRow.gap(...))
                  ├─ NowMarkerRow    → TimelineRowTile(child: NowMarker())      ← NEW case
                  └─ ChunkRow(isLive)→ isLive ? LiveRowCard (full-bleed, outside TimelineRowTile)
                                              : TimelineRowTile(child: SwipeableChunkCard)
```

### Recommended Project Structure

No new folders. One new file:

```
lib/screens/today/
├── timeline.dart                 # add NowMarkerRow, thread nowMinutes through buildTimeline
├── today_screen.dart             # compute nowMinutes, add one switch case, pass through
└── widgets/
    ├── free_time_row.dart        # existing — closest analog, unmodified
    ├── timeline_row_tile.dart    # existing — reused as-is (no change needed)
    └── now_marker.dart           # NEW — resurrects the pre-merge file's name & primary-color convention
```

### Pattern 1: Row-model mechanics — exactly how `buildTimeline` works today

**What:** `buildTimeline` (`lib/screens/today/timeline.dart:53-92`) is a single forward pass over the
already-clock-ordered `chunks` list. Per iteration it: (1) checks whether a `LeadingFreeRow` or
`GapFreeRow` is needed by comparing the chunk's `displayStartMinutes` against `prevEnd`, (2) appends the
`ChunkRow` itself with `isLive` derived from a `liveId` computed once up front from `nowState`
(`Active(:current)`/`Overdue(:overdue)` → that chunk's id, else `null`). `[VERIFIED:
lib/screens/today/timeline.dart:53-92]`

**Signature change needed for NOW-01/NOW-02:**
```dart
// Source: lib/screens/today/timeline.dart — recommended diff shape
List<TimelineRow> buildTimeline({
  required List<ScheduledChunk> chunks,
  required NowState nowState,
  int? nowMinutes,                 // NEW — optional, default null (see Pitfall 2)
  int minGapMinutes = kMinGapMinutes,
}) {
```
`nowMinutes` is an `int` value, not a `DateTime` — this keeps `timeline.dart` free of any `DateTime`
symbol, which is exactly what INVARIANT 1's doc comment demands ("`DateTime` must not appear anywhere
in this file outside a doc comment", `timeline.dart:43`). Passing the pre-computed integer, not the
`DateTime`, is what makes this an injected *position*, not a second clock read.

**Exhaustive-switch cost:** `grep -rn "switch (row" lib/ test/` and `grep -rn "TimelineRow" lib/ test/`
confirm there is exactly **one** exhaustive switch over `TimelineRow` in the entire codebase:
`_buildTimelineRow` in `today_screen.dart:556`. No other file pattern-matches on `TimelineRow`'s
subtypes. `[VERIFIED: grep across lib/ and test/, 2026-08-08]` Adding a fourth subtype costs exactly one
new `case` clause at that one site — not the "every exhaustive switch" scope the phase description
worried about; there is only one.

### Pattern 2: Insertion semantics — a single position-based rule handles every locked-in state

**What:** Rather than special-casing each of `PreStart`/`GapBeforeNext`/`Overdue`/`DayComplete`
separately, insert `NowMarkerRow(nowMinutes)` **immediately before the first `ChunkRow` in clock order
whose `displayStartMinutes > nowMinutes`**, or append it after the loop if no such chunk exists. This
single rule is provably correct for all four states because of how `resolveNowState` itself defines its
boundaries — traced against the live algorithm (`now_state.dart:116-208`):

- **`PreStart`** is returned exactly when `currentMinutes < scheduled.first.displayStartMinutes!`
  (`now_state.dart:137`) — i.e. exactly when the rule's condition is true on the very first chunk. The
  marker lands before the day's first row, alongside (or replacing, when `start == 0`) the
  `LeadingFreeRow`.
- **`GapBeforeNext`** is returned when the currently-scanned chunk is resolved and the next unresolved
  chunk's window hasn't opened yet (`now_state.dart:180-188`) — `nowMinutes` is, by construction,
  between the previous chunk's row and the next chunk's `displayStartMinutes`, so the rule places it
  there regardless of whether a `GapFreeRow` also renders in that gap (a gap can be `< kMinGapMinutes`
  and emit no `GapFreeRow` at all — the marker must still render independently of that threshold; it is
  not attached to the `GapFreeRow`, it is its own row).
- **`Overdue`** is only returned when the overdue chunk is *not* `scheduled.last` (the `currentMinutes
  >= scheduled.last`'s-end check at `now_state.dart:155-158` returns `DayComplete` first if it were) —
  so there is always a later chunk with `displayStartMinutes > nowMinutes` for the rule to stop at. The
  marker lands right after the overdue chunk's row (which is *also* rendered as the live row —
  `isLive` is derived from `Overdue(:overdue)` too, `timeline.dart:62` — see Pattern 3 for why this is
  still the right call).
- **`DayComplete`** is returned once `currentMinutes >= scheduled.last`'s window end
  (`now_state.dart:155-158`), i.e. no future chunk exists — the rule's fallback (append at the very
  end) is exactly what's needed. There is no "trailing free row" concept in the current three-subtype
  model and this phase does not need to invent one (out of scope per the phase's own anti-scope note);
  the marker alone, appended last, is sufficient.

**Concrete diff shape** (single forward pass, no second loop, no re-scan):
```dart
// Source: lib/screens/today/timeline.dart — recommended diff shape
final bool showMarker = nowMinutes != null && nowState is! Active;
bool markerInserted = false;

final rows = <TimelineRow>[];
int? prevEnd;

for (final chunk in chunks) {
  final start = chunk.displayStartMinutes;

  if (showMarker && !markerInserted && start != null && nowMinutes! < start) {
    rows.add(NowMarkerRow(nowMinutes));
    markerInserted = true;
  }

  if (start != null) {
    if (prevEnd == null) {
      // NOW-02 fix: only show the leading free row while its window is
      // still open (i.e. before nowMinutes reaches the first chunk's
      // start — equivalent to "we are still in PreStart").
      if (start > 0 && (nowMinutes == null || nowMinutes < start)) {
        rows.add(LeadingFreeRow(start));
      }
    } else if (start - prevEnd >= minGapMinutes) {
      rows.add(GapFreeRow(prevEnd, start - prevEnd));
    }
    prevEnd = start + chunk.durationMinutes;
  }

  rows.add(ChunkRow(chunk, isLive: chunk.id == liveId));
}

if (showMarker && !markerInserted) {
  rows.add(NowMarkerRow(nowMinutes!));
}

return rows;
```
Untimed chunks (`start == null`) never trigger the marker-placement check (guarded by `start != null`),
matching the existing invariant that untimed chunks don't participate in gap/leading-row arithmetic
either (`timeline.dart:72`, INVARIANT 2). `[VERIFIED: lib/screens/today/timeline.dart:69-92, traced
against lib/screens/today/now_state.dart:116-208, 2026-08-08]`

### Pattern 3: The Active-state suppression question — recommendation and reasoning

**Recommendation: suppress when `nowState is Active`; do NOT suppress for `Overdue` even though it also
renders the live row.** Both are explicit, evidence-backed:

1. **Dan's actual reported bug was not an Active-state screen.** The evidence screenshot
   (`24-evidence-dan-drop.png`) shows the header reading "Up next / Short break / Starts at 12:40 PM" —
   that is the `GapBeforeNext` edge-state line (`today_screen.dart:417-449`), not the live row. The
   live row (`LiveRowCard`) was not on screen at all at the moment Dan couldn't tell "where now is."
   This is direct evidence that the four non-Active states are where the marker earns its keep, and
   that Active — where `LiveRowCard` is already rendering — was never the confusing case.
2. **`LiveRowCard` (post-Phase-23) is the single most visually prominent element on the screen** — full
   content width (no horizontal margin, square corners — "let now break the grid",
   `live_row_card.dart:59-69`), `primaryContainer` fill, elevation 6, an uppercase kicker literally
   reading "RIGHT NOW" (or "RIGHT NOW — RESTING" for a break, `today_screen.dart:645-660`), a live
   countdown, and a progress bar. A quiet marker row placed immediately adjacent (per Pattern 2's
   insertion rule, that's exactly where it would land — right after the live row) would be pure visual
   redundancy directly beside the loudest element in the UI.
3. **For `Active`, the marker's insertion point would also be slightly *wrong* about position.** The
   rule places the marker before the first *future* chunk — i.e. after the live chunk's row entirely.
   But "now" is actually mid-way *through* the live chunk's window, not at its boundary. There is no
   way to render a marker literally inside `LiveRowCard`'s own bounds, so rendering it at all in the
   `Active` case would visually claim a slightly false position (implying "now" = the boundary between
   the live activity and what's next). Suppressing avoids asserting a position the row model can't
   actually represent precisely.
4. **`Overdue` is different in a way that matters**, even though its chunk is *also* marked `isLive`
   (`timeline.dart:61-63`, `Overdue(:final overdue) => overdue.id`) and *also* renders through
   `LiveRowCard`. Overdue's card shows the **original scheduled time range with a full (1.0), static
   progress bar** (`today_screen.dart:723-729`, explicit comment: "the old 'now' card's existing plain
   time-range copy... does NOT invent 'behind' wording") — it does **not** show a live countdown or any
   indication of *how* overdue the chunk is. The marker is the only element on the whole screen that
   could show "and 'now' is actually X further along than this card's static full bar suggests" — it is
   not redundant here the way it is for `Active`, it fills a real information gap the Overdue card
   deliberately (per the Copywriting Contract cited in that comment) declines to fill itself. This
   matches CONTEXT.md's locked list, which explicitly separates `Overdue` from `Active` even though both
   render the live row.

`[VERIFIED: lib/screens/today/timeline.dart:60-64, lib/screens/today/today_screen.dart:645-751,
24-CONTEXT.md decisions, 24-evidence-dan-drop.png description in 24-CONTEXT.md, 2026-08-08]`

### Pattern 4: NOW-02 mechanics — minimal correct fix

**What:** `timeline.dart:76-78` currently emits `LeadingFreeRow(start)` unconditionally whenever the
first clock-positioned chunk starts after minute 0:
```dart
if (start > 0) {
  rows.add(LeadingFreeRow(start));
}
```
**Minimal fix:** add the same `nowMinutes` guard already needed for NOW-01 (Pattern 2's diff already
shows it): `if (start > 0 && (nowMinutes == null || nowMinutes < start))`. This is **suppression**, not
relabeling — there is no alternate copy to show once the window has closed; the row simply should not
exist at that point, matching the fact that `nowMinutes < start` is algebraically identical to "we are
in `PreStart`" for the first chunk specifically (see Pattern 2's derivation).

**Does anything else need to take over?** No. `GapFreeRow` only ever represents gaps *between* chunks
(`prevEnd` to next `start`) — there is no code path for a "gap from now back to a past leading window,"
and none is needed: once the leading free window has closed, the `NowMarkerRow` (Pattern 2) is what
communicates "here's where now actually is" in its place. No new row type, no relabeling.

`[VERIFIED: lib/screens/today/timeline.dart:72-78, 2026-08-08]`

### Anti-Patterns to Avoid

- **Re-deriving "now" inside `buildTimeline` from anything but the injected `nowMinutes` parameter** —
  this is the exact single-now-detector regression Phase 22 spent a full plan fixing (two competing
  scans deleted) and a code review caught a third instance of (STATE.md, Phase 23). `nowMinutes` must
  be threaded in, never computed inside `timeline.dart`.
- **A second `DateTime.now()` or `_nowFn()` call anywhere in `today_screen.dart`'s `build()`** — the
  `nowMinutes` computation must reuse the *same* `nowDt` local variable `build()` already holds
  (`today_screen.dart:931`), the same discipline WR-01 already established for `_liveSecondsRemaining`.
- **Attaching the marker's visibility/position to the `GapFreeRow`'s existence** — a gap can be shorter
  than `kMinGapMinutes` and emit no `GapFreeRow` at all; the marker is its own independent row and must
  not assume one exists to "attach" to.
- **Wrapping `NowMarkerRow` in a `Card`** — CONTEXT.md's "position, not a second detector" framing and
  the `FreeTimeRow` analog both point at a quiet, non-elevated row; a `Card` would visually compete with
  `LiveRowCard` for "the important row" attention, which undermines the Active-suppression reasoning in
  Pattern 3 (the marker is deliberately the quieter element).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Minutes-since-midnight arithmetic | A third inline `dt.hour * 60 + dt.minute` in `today_screen.dart`'s `build()` | Extract a tiny shared `minutesOfDay(DateTime dt) => dt.hour * 60 + dt.minute` helper into `lib/utils/time_format.dart` and call it from both `now_state.dart:125` and the new `build()` call site | Currently the formula exists in exactly one place (`now_state.dart:125`); adding a second inline copy for `nowMinutes` creates silent-drift risk (a future edit to one copy without the other). This is a two-line, zero-risk extraction that removes that risk entirely — not a new abstraction, a de-duplication of an existing one-liner. |
| Row-list-to-marker positioning | A `Stack`/`Positioned` overlay computed from measured row heights | `NowMarkerRow` as a `TimelineRow` subtype, positioned in the pure row list | `buildTimeline` already owns "where does this row go" as a pure, testable computation; reproducing that logic in the widget layer against measured pixel offsets would be strictly more code, harder to test, and would violate INVARIANT 1/2's "no re-scanning" contract. |

**Key insight:** this phase's "don't hand-roll" list is short because the phase itself is almost
entirely a "reuse the existing row-model pattern, don't invent a new mechanism" exercise — the risk here
is not missing a library, it's re-adding a parallel now-detector or a parallel clock read.

## Common Pitfalls

### Pitfall 1: Requirement-ID collision (`NOW-01`/`NOW-02` used twice across milestones)
**What goes wrong:** A grep for `NOW-01` or `NOW-02` across `test/` returns matches from
`test/screens/today_screen_now_state_test.dart` (Phase 17, v1.3, the first-unresolved-chunk bug fix)
that have nothing to do with this phase's marker/stale-free-row requirements.
**Why it happens:** `REQUIREMENTS.md`'s "Where Am I" section (added 2026-08-08) reuses the same short
IDs a prior, unrelated milestone already used and left labeled in test group names.
**How to avoid:** When writing or verifying tests for this phase, grep for the *phase number* (`24`) or
the specific new behavior (marker insertion, leading-row suppression), not the bare `NOW-01`/`NOW-02`
string, to avoid false-positive "coverage already exists" conclusions.
**Warning signs:** A plan-checker or verifier reporting "NOW-01 already has test coverage" by finding
the Phase 17 group — that coverage is real but answers a different question.

### Pitfall 2: A `required int nowMinutes` parameter silently breaks ~15 existing unit tests, ~10 of them via an unexpected extra row
**What goes wrong:** `test/screens/today_timeline_model_test.dart` calls `buildTimeline(...)` at 15 call
sites (`[VERIFIED: grep -c "buildTimeline(" test/screens/today_timeline_model_test.dart → 15 call
sites, 2026-08-08]`), none of which currently pass a "now position." Most of the "structural" and "gap
arithmetic" groups use `nowState: DayComplete()`. If the marker is required and *not* suppressed for
`DayComplete` (per the locked decision, it should show for `DayComplete`), every one of those tests
would gain an unplanned trailing `NowMarkerRow`, breaking their `expect(rows, hasLength(N))` assertions.
**Why it happens:** Making the new parameter required forces every existing call site to be touched
just to keep compiling, and choosing an arbitrary `nowMinutes` value doesn't avoid the extra row for
`DayComplete`-based tests specifically, because `DayComplete` is one of the four states that must show
the marker.
**How to avoid:** Make `nowMinutes` an optional `int?` parameter, default `null`. When `null`, both the
marker insertion and the NOW-02 `LeadingFreeRow` guard are no-ops, so all 15 existing call sites
continue to compile and pass unchanged. New tests targeting NOW-01/NOW-02 explicitly pass `nowMinutes`.
**Warning signs:** A plan that says "update `buildTimeline`'s signature" without separately budgeting
"fix N existing `hasLength()` assertions" — that's the tell that the required-parameter path was chosen
without pricing it in.

### Pitfall 3: One specific existing widget test currently pins the exact NOW-02 bug
**What goes wrong:** `test/screens/today_screen_test.dart:364-370` ("`"Free until 8:00 AM" precedes the
first activity`") pumps the day fixture with `now: () => DateTime(2026, 8, 7, 10, 47)`
(`today_screen_test.dart:341`) against a fixture whose first chunk starts at minute 480 (8:00 AM,
`today_screen_test.dart:296`) — i.e. it asserts "Free until 8:00 AM" is present nearly three hours
*after* that window closed. This is the literal bug NOW-02 exists to fix, currently locked in as
expected behavior by a passing test.
**Why it happens:** The test was written under Phase 22, before NOW-02 existed as a requirement; nothing
was wrong with it at the time.
**How to avoid:** This test must be *changed*, not just left green — once the NOW-02 guard ships, this
exact assertion will fail (correctly). The plan must either move this specific assertion to a genuinely
pre-8:00-AM clock time (matching the pattern already used correctly by the `pre-start` test at
`today_screen_test.dart:575-599`, `now: () => DateTime(2026, 8, 7, 6, 0)`), or split it into two cases:
one proving the row shows before the window closes, one proving it's absent after.
**Warning signs:** `flutter test` failing on this exact test after the NOW-02 fix lands is *expected*,
not a regression — treat it as the fix's own proof, not a break to chase down elsewhere. Confirmed no
other test file asserts "Free until" through `TodayScreen`/`buildTimeline` (`grep -rn "Free until"
test/` shows only `today_row_widgets_test.dart`'s two matches, which pump `FreeTimeRow` directly and
never go through `buildTimeline`, so they are unaffected).

### Pitfall 4: `Overdue` also renders the live row — don't assume "isLive" means "suppress the marker"
**What goes wrong:** A naive suppression rule like "suppress the marker whenever the row list has an
`isLive` chunk" would incorrectly also suppress it for `Overdue`, contradicting the locked decision.
**Why it happens:** `timeline.dart:60-64` derives `isLive` from *both* `Active.current` and
`Overdue.overdue` — `Overdue` chunks render through the same `LiveRowCard` widget `Active` chunks do,
so "does a `LiveRowCard` exist on screen right now" and "is `nowState` specifically `Active`" are *not*
the same question.
**How to avoid:** Guard on `nowState is! Active` specifically (a type check on the sealed variant), not
on "does the row list contain an `isLive: true` `ChunkRow`."
**Warning signs:** A test asserting "no marker when a `LiveRowCard` is present" would incorrectly fail
an `Overdue` case that should show the marker — if that happens, the guard was written against the
wrong condition.

### Pitfall 5: Duplicating the minutes-from-midnight formula without a shared helper
**What goes wrong:** `now_state.dart:125` computes `nowDt.hour * 60 + nowDt.minute` internally, but that
value isn't returned to the caller. A second, independent copy of the same formula written directly in
`today_screen.dart`'s `build()` (to compute `nowMinutes` for `buildTimeline`) is correct today but is a
silent-drift risk if either copy is ever "fixed" (e.g. for a timezone edge case) without the other.
**Why it happens:** `resolveNowState`'s signature returns only the classified `NowState`, not the raw
minute value it used internally.
**How to avoid:** Extract the one-line formula into a shared `minutesOfDay(DateTime dt)` helper (e.g. in
`lib/utils/time_format.dart`, alongside `formatMinutes`/`formatMinutesCompact`) and call it from both
`now_state.dart:125` and the new `build()` call site. Two-line change, removes the duplication instead
of adding to it.
**Warning signs:** A future edit changes one copy of the formula (e.g. to account for DST) and not the
other, causing the marker to disagree with `resolveNowState` by exactly one hour on a transition day.

## Code Examples

### Adding the new `TimelineRow` subtype
```dart
// Source: lib/screens/today/timeline.dart — pattern matches existing
// LeadingFreeRow/GapFreeRow subtypes exactly (same file, same conventions)
/// The current-moment position marker, injected as a value (never derived
/// from a clock read inside this file — see INVARIANT 1). Rendered as a
/// quiet row, not a card (NOW-01) — never a second opinion about which
/// chunk is current, only where "now" falls in clock-minutes.
class NowMarkerRow extends TimelineRow {
  final int minutes;
  NowMarkerRow(this.minutes);
}
```

### Rendering it (the one exhaustive switch site)
```dart
// Source: lib/screens/today/today_screen.dart:556 — new case alongside the
// existing LeadingFreeRow/GapFreeRow cases, same TimelineRowTile wrapping
// convention (inherits the 16dp inset and gutter for free; the gutter will
// show the current time next to the marker as a side benefit).
case NowMarkerRow(:final minutes):
  return TimelineRowTile(
    startMinutes: minutes,
    child: const NowMarker(),
  );
```

### The new quiet row widget (mirrors `FreeTimeRow`'s "no Card, quiet label" convention)
```dart
// Source: lib/screens/today/widgets/now_marker.dart — new file, resurrects
// the pre-Phase-22 NowMarker's colorScheme.primary convention (git show
// ea97862^:lib/screens/schedule/widgets/now_marker.dart) but drops its old
// standalone-divider layout in favor of TimelineRowTile wrapping.
class NowMarker extends StatelessWidget {
  const NowMarker({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Container(width: 24, height: 2, color: color),
        const SizedBox(width: 8),
        Text(
          'Now',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 2, color: color.withValues(alpha: 0.4))),
      ],
    );
  }
}
```
(Visual treatment is Claude's Discretion per CONTEXT.md — this is a starting recommendation, not a
locked spec. `withValues(alpha:)` matches the existing Flutter API already used codebase-wide, e.g.
`free_time_row.dart:34`, `[VERIFIED: lib/screens/today/widgets/free_time_row.dart:34]`.)

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| `NowMarker` widget + `_buildActiveChunkItems` crude first-unresolved-chunk scan (`schedule_screen.dart`, pre-merge) | No marker at all; `resolveNowState` is the single now-detector, `buildTimeline` is the single row-list builder | Phase 22-04 (commit `ea97862`) deleted the old widget and screen together | The *scan* needed to die (it was the exact bug Phase 17 fixed elsewhere), but the *widget* — a legitimately reusable visual component — was deleted along with it, and nothing took over its job. This phase resurrects the widget's visual convention (not its file, not its logic) attached to the new, correct position source. |

**Deprecated/outdated:**
- `lib/screens/schedule/widgets/now_marker.dart` (pre-Phase-22): fully deleted, zero remaining
  references (`grep -rn "NowMarker" lib/` returns nothing in the current tree). Its `_buildActiveChunkItems`
  placement logic must **not** be resurrected — only its `colorScheme.primary`/`ExcludeSemantics`
  visual convention is worth reusing, and even that is a starting point, not a requirement.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Recommending `int? nowMinutes` (optional, default `null`) over a required parameter | Architecture Patterns Pattern 1, Common Pitfalls Pitfall 2 | Low — this is an engineering judgment call, not a factual claim; the required-parameter alternative is documented with its cost so the planner can choose either with full information. |
| A2 | Recommending `nowState is! Active` (not `Overdue`) as the sole suppression guard | Architecture Patterns Pattern 3 | Low-medium — CONTEXT.md explicitly leaves the Active-suppression decision to planning ("Planning should decide and justify") and explicitly locks Overdue as a "needs it" state, so this recommendation is well-constrained by the locked decision; the main risk is a planner disagreeing with the *aesthetic* reasoning in point 2/3 of Pattern 3, which is a judgment call, not a fact. |
| A3 | Recommended visual treatment (thin rule + "Now" label + `TimelineRowTile` wrapping) | Code Examples | Low — CONTEXT.md explicitly marks visual treatment as Claude's Discretion; this is offered as a reasoned starting point only, not something requiring user confirmation before planning proceeds. |

**All claims tagged `[VERIFIED: ...]` above were confirmed by directly reading the cited file/line in
this checkout on 2026-08-08** (including the recovered pre-deletion file via `git show
ea97862^:lib/screens/schedule/widgets/now_marker.dart`) — there is no `[ASSUMED]`-tier factual claim in
this document; the three items above are engineering *recommendations*, not unverified facts, and are
logged here per the protocol's instruction to surface anything short of full certainty.

## Open Questions

1. **Exact visual treatment of the marker (rule style, color, whether the gutter's time label is
   redundant with a "Now" text label).**
   - What we know: `FreeTimeRow` is the closest analog (quiet, no `Card`, dotted rule); the old deleted
     `NowMarker` used a solid `colorScheme.primary` rule + dot + "Now" label spanning full width.
   - What's unclear: whether the resurrected widget should keep the old dot-in-the-middle motif, and
     whether showing the compact time in `TimelineRowTile`'s gutter (a free side effect of wrapping it
     there) makes an additional time string in the label itself redundant.
   - Recommendation: keep it simple — "Now" text only in the label (gutter already shows the compact
     time via `TimelineRowTile`), `colorScheme.primary` for the rule. This is Claude's Discretion per
     CONTEXT.md; treat the Code Examples section's widget as a first draft, not a locked spec.

2. **Whether to extract `minutesOfDay(DateTime)` as part of this phase, or leave the formula
   duplicated with a cross-reference comment.**
   - What we know: the duplication is currently zero (formula exists once, in `now_state.dart:125`);
     this phase would be the first to introduce a second copy if the extraction isn't done.
   - What's unclear: whether this is in-scope for a phase whose anti-scope explicitly says "one small
     row widget, one row-model change, one suppression rule" — a shared-helper extraction is arguably a
     fourth, small change.
   - Recommendation: do the extraction — it's two lines, it directly serves the "position, never a
     second opinion" spirit of the locked decisions, and the alternative (a duplicated formula with a
     comment asking future editors to keep two files in sync) is strictly worse engineering for
     equivalent effort.

## Environment Availability

Skipped — this phase has no external dependencies (no new packages, no new tools, no new services). All
work happens inside the existing Flutter/Dart toolchain already verified working by every prior phase in
this milestone.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` (bundled with Flutter SDK, already in `pubspec.yaml` dev_dependencies) |
| Config file | none — standard `flutter test` runner, no custom config |
| Quick run command | `flutter test test/screens/today_timeline_model_test.dart test/screens/today_screen_test.dart test/screens/today_row_widgets_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| NOW-01 | `buildTimeline` inserts `NowMarkerRow` at the correct position for `PreStart`/`GapBeforeNext`/`Overdue`/`DayComplete`, suppressed for `Active` | unit | `flutter test test/screens/today_timeline_model_test.dart -x` | ✅ (extend existing file — mirrors the "isLive derivation" group's structure at `today_timeline_model_test.dart:172-244`) |
| NOW-01 | `NowMarker` widget renders "Now" via `TimelineRowTile`, visible in the rendered `TodayScreen` for the four non-Active states | widget | `flutter test test/screens/today_row_widgets_test.dart test/screens/today_screen_test.dart -x` | ✅ (extend `today_row_widgets_test.dart`'s row-widget groups, and `today_screen_test.dart`'s existing pre-start/gap-before-next/day-complete groups at lines 575, 601, 634) |
| NOW-01 | The marker's clock position is exactly `resolveNowState`'s `nowDt` sample, never a second read | unit + widget | same files as above, asserting via the injected `now:` closure pattern already used throughout `today_screen_now_state_test.dart` | ✅ |
| NOW-02 | `LeadingFreeRow` is suppressed once `nowMinutes >= start` | unit | `flutter test test/screens/today_timeline_model_test.dart -x` | ✅ (extend the "structural cases" group) |
| NOW-02 | The existing `today_screen_test.dart:364-370` test is corrected to a genuinely-open window, per Pitfall 3 | widget | `flutter test test/screens/today_screen_test.dart -x` | ✅ (existing test, must be edited not just left passing) |

### Sampling Rate
- **Per task commit:** `flutter test test/screens/today_timeline_model_test.dart test/screens/today_screen_test.dart test/screens/today_row_widgets_test.dart`
- **Per wave merge:** `flutter test` (full suite)
- **Phase gate:** Full suite green, `flutter analyze` clean, before `/gsd-verify-work`

### Wave 0 Gaps

None — existing test infrastructure (`today_timeline_model_test.dart` for pure `buildTimeline` unit
tests, `today_row_widgets_test.dart` for widget-level row rendering, `today_screen_test.dart` for
full-screen integration, `today_screen_now_state_test.dart` for `resolveNowState`/clock-injection
patterns) covers every test type this phase needs. No new test file, no new fixture helper, no new
framework install required — extend the four existing files using their own established conventions
(`_workChunk`/`_breakChunk` factories, `pumpWithMood`, `_pumpTodayScreen`, injectable `now:` closures).

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-------------------|
| V2 Authentication | no | No auth surface touched — this phase has no user-identity concept at all. |
| V3 Session Management | no | No session state introduced or read. |
| V4 Access Control | no | No new data access; reads the same `ScheduleNotifier`-provided chunks every other row already reads. |
| V5 Input Validation | no | No user input accepted anywhere in this phase — `nowMinutes` is a value computed from the local system clock, not user-supplied. |
| V6 Cryptography | no | Not applicable. |

### Known Threat Patterns for this stack

None applicable. This phase reads no untrusted input, performs no network I/O, writes no persisted
data, and introduces no new attack surface — it is pure integer arithmetic on a locally-sampled
`DateTime` and a `List<TimelineRow>` rendering change. The single-now-detector discipline this phase
must preserve (see Anti-Patterns) is a *correctness* concern (the app disagreeing with itself about
"now"), not a security concern.

## Sources

### Primary (HIGH confidence — all directly read in this checkout, 2026-08-08)
- `lib/screens/today/timeline.dart` (full file, 92 lines)
- `lib/screens/today/now_state.dart` (full file, 208 lines)
- `lib/screens/today/today_screen.dart` (targeted: 1-145, 361-470, 540-780, 890-1020; full file is 1115 lines)
- `lib/screens/today/widgets/free_time_row.dart` (full file, 86 lines)
- `lib/screens/today/widgets/timeline_row_tile.dart` (full file, 88 lines)
- `lib/screens/today/widgets/live_row_card.dart` (full file, 161 lines)
- `git show ea97862^:lib/screens/schedule/widgets/now_marker.dart` (recovered deleted file, 46 lines)
- `test/screens/today_timeline_model_test.dart` (full file, 289 lines)
- `test/screens/today_screen_test.dart` (targeted: 1-450, 560-660, 830-1071; full file is 1071 lines)
- `test/screens/today_row_widgets_test.dart` (targeted: 1-180)
- `test/screens/today_screen_now_state_test.dart` (targeted: 1-40, group headers)
- `.planning/phases/24-where-am-i/24-CONTEXT.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md`, `.planning/ROADMAP.md`
- `.planning/phases/23-live-activity-tracking/23-PATTERNS.md`, `.planning/phases/22-unified-today-screen/22-PATTERNS.md`
- `pubspec.yaml` (SDK/dependency confirmation)
- `.planning/config.json` (workflow flags)

### Secondary (MEDIUM confidence)
None — no external documentation was consulted; this phase has no external-library surface.

### Tertiary (LOW confidence)
None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new packages; confirmed via `pubspec.yaml` read.
- Architecture: HIGH — every mechanism described (row-model loop, exhaustive switch count, `resolveNowState` boundary conditions) was traced directly against the live source, not inferred.
- Pitfalls: HIGH — the ID collision, the required-vs-optional-parameter test-breakage count, and the specific stale test were all confirmed by direct grep/read, not estimated.

**Research date:** 2026-08-08
**Valid until:** Until this phase's plan lands (this research is tied to the exact current state of `lib/screens/today/`; any other phase landing first that touches these files would need a re-check — no fixed calendar expiry is meaningful for an internal-code research doc like this one).
