# Phase 26: The Day Has a Shape - Research

**Researched:** 2026-08-10
**Domain:** Flutter layout architecture — row-list-to-absolute-positioning migration in a single-tier client app
**Confidence:** HIGH (implementation-risk findings are grounded in direct source reads and a live test run, not speculation)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01 — Replace the list, do not add a mode.** The proportional surface *becomes* TodayScreen's
timeline. There is no list/calendar toggle and no persisted view preference. One surface, one
now-line, one renderer to keep truthful. This is the aggressive reading and it is deliberate:
maintaining two renderers of the same day was judged worse than losing the list fallback.

*Consequence:* `NowMarkerRow`'s between-rows insertion contract in `timeline.dart` is **reworked, not
extended**. Phase 24's `Active`-state marker suppression rule is **superseded** by CAL-02, not
coexisted with — a proportional layout can place the line truthfully mid-chunk, which is the exact
reason the suppression existed.

**D-02 — Fully proportional. No gap compression.** An empty 4-hour stretch renders as a real
4-hour-tall stretch and the user scrolls through it. Rejected: collapsing long gaps to a fixed band,
and clamping rows to a min/max height.

*Consequence — flagged for planning, not a blocker:* a sparse day is now several screens tall, so
the auto-scroll-to-now behaviour carries more weight than it did in Phase 24 and must be correct on
open, not best-effort.

**D-03 — Now-line uses `colorScheme.primary`.** Rejected: hardcoded red, `colorScheme.error`.

### Claude's Discretion

Everything not fixed above — the pixels-per-minute scale factor and whether it is fixed or
responsive, how a 5-minute break stays legible at that scale, whether the time gutter keeps its
Phase 23 `kGutterWidth`/16dp-inset treatment or is re-derived, widget decomposition, and the
scroll-restoration mechanics. **This discretion has already been exercised by `26-UI-SPEC.md`**
(checker-passed 6/6 dimensions) — this research treats the UI-SPEC as the locked design contract
and focuses on implementation risk, not re-litigating the design.

### Deferred Ideas (OUT OF SCOPE)

- A list/calendar view toggle — explicitly rejected in D-01, not deferred.
- Gap compression / min-max row clamping — explicitly rejected in D-02.
- `23-VALIDATION.md` nyquist-draft tech debt — unrelated carried item, not this phase's work.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CAL-01 | The day reads as a time-proportional surface — a row's height corresponds to its duration | Architecture Patterns §1-2 (Stack/Positioned layout mechanics), Common Pitfalls #4-5 (density-tier and dashed-painter code changes) |
| CAL-02 | A continuously-positioned now-line sits at the true current moment, including inside an activity's span; supersedes Phase 24's `Active`-suppression | Architecture Patterns §1 (sealed-class removal), §4 (tick granularity), Common Pitfalls #1, #8 |
| CAL-03 | Elapsed time recedes — reaching the past is a deliberate scroll, not the default view | Architecture Patterns §3 (scroll-on-open arithmetic), Common Pitfalls #2-3 |
</phase_requirements>

## Summary

Phase 26's *design* is already fully specified and checker-approved in `26-UI-SPEC.md`. What remains
is genuine implementation risk in migrating `lib/screens/today/` from a **row-list model**
(`TimelineRow` sealed hierarchy → `ListView`-style `Column` of variable-content widgets) to an
**absolute-positioning model** (`Stack` + `Positioned`, offsets computed from `durationMinutes` and
`nowMinutes` arithmetic). This is not a routine feature addition — it removes a sealed-class
subtype (`NowMarkerRow`), deletes the dual centre-on-open flag/`GlobalKey`/`Scrollable.ensureVisible`
mechanism Phase 24 shipped, and reworks four widget files (`chunk_card.dart`, `free_time_row.dart`,
`now_marker.dart`, `timeline_row_tile.dart`) around a duration-driven density model that doesn't
exist in the codebase today.

Three findings materially change what the planner should scope:

1. **The single biggest unresolved gap in the UI-SPEC is the live row's real height.** `LiveRowCard`
   is a documented, locked exception to CAL-01 (content-driven ~200-220px, not
   `durationMinutes * kPixelsPerMinute`). The UI-SPEC says rows *after* the live row must be
   positioned using the live row's "real measured height (available post-layout)" — but never says
   *how* that measurement reaches the offset-calculation code. This requires either (a) a fixed
   estimated-height constant, accepting a few pixels of drift, or (b) a two-pass
   measure-then-position flow via `GlobalKey`/`RenderBox`. The planner must pick one explicitly (see
   Common Pitfalls #3).
2. **A factual correction to the UI-SPEC's stated rationale for break rows losing their tap target:**
   verified by reading `chunk_card.dart` and `swipeable_chunk_card.dart` directly — breaks have **no
   tap handler today**. `SwipeableChunkCard.build()` returns a bare `ChunkCard` for non-work chunks
   with no `onTap` forwarded, and `ChunkCard._buildBreak()` wraps nothing in a `GestureDetector`. The
   UI-SPEC's framing ("a deliberate behavior change from the current implicit onTap") describes
   behavior that does not exist in the shipped code — no task is needed to "remove" a break tap
   target, because there isn't one to remove.
3. **Test blast radius is real but bounded and precisely countable.** A live `flutter test` run
   (515/515 passing, confirming the 515-test baseline) plus per-file isolation shows the row-model
   rework touches roughly 30 of 515 tests directly (the `NowMarkerRow`/`NowMarker`-widget/dual-flag
   centre-on-open assertions), concentrated in exactly three files. `resolveNowState` and
   `LiveRowCard`'s countdown/timer tests (50 tests in `today_screen_now_state_test.dart`) are
   untouched by this phase's scope and should stay green with zero changes.

**Primary recommendation:** Delete `NowMarkerRow` outright (sealed variants can't be "kept but
ignored" without still requiring a switch arm, so partial retention buys nothing); implement the
now-line and hour-axis as `Positioned` overlays inside a `Stack` wrapped by the existing
`SingleChildScrollView`, not `ListView.builder` (this codebase already made and documented this
exact "eager layout, bounded row count" tradeoff for the pre-proportional list — nothing about
duration-driven heights changes that calculus); replace `Scrollable.ensureVisible` +
dual-`GlobalKey`/dual-flag with a single one-shot post-frame `animateTo`, computing
`maxScrollExtent`-based clamping **inside** the post-frame callback (not in `build()`, where
`maxScrollExtent` isn't valid yet); and do not touch the existing 1-minute `Timer.periodic` cadence
— CAL-02's "continuously-positioned" describes the arithmetic function, not an animation frame rate,
and Phase 23 already fought and won the battery-cost argument against a faster ticker.

## Architectural Responsibility Map

Canopy is a single-tier Flutter client (no separate frontend-server/API split — this is a local-first
app with a Hive persistence layer, not a web app with backend tiers). The standard Browser/SSR/API/CDN
tier table doesn't apply; the table below maps capabilities to this app's actual layers instead
(Render, State, Persistence), which is the equivalent sanity-check the planner needs.

| Capability | Primary Layer | Secondary Layer | Rationale |
|------------|-------------|----------------|-----------|
| Row height (`durationMinutes → px`) | Render (`Stack`/`Positioned` children in `today_screen.dart`) | — | Pure layout arithmetic; no persistence or state-holder involvement |
| Now-line position | Render (`Positioned` overlay) | State (`build()`'s single `nowDt` sample) | Position is arithmetic derived from the existing single-clock-sample seam; ownership stays entirely client-side (CLAUDE.md: no LLM/backend surface for this) |
| Scroll-on-open offset | Render (`ScrollController.animateTo`) | — | Pure post-layout arithmetic, one-shot, no backend involvement |
| "Now" classification (which chunk is current) | State (`resolveNowState`, `now_state.dart`) | — | **Unchanged, out of scope** — this phase adds a position, never a second opinion (explicit CONTEXT.md boundary) |
| Schedule data (chunks, durations, resolution) | Persistence (Hive, `ScheduleNotifier`) | State | **Untouched** — schedule generator and Hive models are out of scope this phase |

## Package Legitimacy Audit

Not applicable — this phase introduces **no new external packages**. Every widget used (`Stack`,
`Positioned`, `IgnorePointer`, `CustomPaint`, `SingleChildScrollView`, `ScrollController`) is a
Flutter/Material 3 SDK built-in already imported elsewhere in this codebase (`chunk_card.dart` already
uses `CustomPaint` for its dashed-border painter; `today_screen.dart` already uses
`SingleChildScrollView` + `ScrollController`). `pubspec.yaml` [VERIFIED: `pubspec.yaml` read] shows no
scroll-position or calendar/timetable package already installed, and none should be added — see
Don't Hand-Roll below.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Flutter SDK | 3.44.1 (stable) [VERIFIED: `flutter --version`] | `Stack`, `Positioned`, `IgnorePointer`, `ScrollController` | Already the app's only UI framework; no alternative considered |
| Dart SDK | 3.12.1 [VERIFIED: `flutter --version`] | Sealed classes / exhaustive `switch` (`TimelineRow`) | Already governs the row model being reworked |

### Supporting

No new supporting libraries. `hive_ce` (2.19.3), `provider` (6.1.5+1), `go_router` (17.1.0) are
present in `pubspec.yaml` [VERIFIED: `pubspec.yaml` read] and untouched by this phase's scope.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `SingleChildScrollView` + `Stack` + `Positioned` (UI-SPEC's choice) | `ListView.builder` with `SizedBox`-wrapped variable-height children | `ListView.builder`'s lazy culling buys nothing at this app's bounded row count (~20-60 rows/day) and cannot natively express "a line positioned at an arbitrary offset over arbitrary content" without extra machinery (e.g. a custom `Sliver` or a second overlay `Stack` anyway) — see Architecture Patterns §2 |
| Hand-rolled `Positioned` offset math | A calendar/day-view timetable package (e.g. `flutter_calendar_carousel`-style widgets) | Rejected outright — CLAUDE.md's product position ("Canopy is a dumb app on purpose... rule-based and deterministic") argues against opaque, over-featured scheduling-UI dependencies for what is ~40 lines of arithmetic the team fully owns and can audit |

**Installation:** None — no `pubspec.yaml` changes required for this phase.

**Version verification:** Flutter 3.44.1 / Dart 3.12.1 confirmed live via `flutter --version`
[VERIFIED: command output, 2026-08-10]. `environment: sdk: ^3.10.3` in `pubspec.yaml` is satisfied.

## Architecture Patterns

### System Architecture Diagram

```
                    build() — ONE clock sample (D-01 single-sample rule, unchanged)
                        │
                        ▼
              nowDt = _nowFn()  ──────────────────────────────┐
                        │                                      │
                        ▼                                      ▼
             resolveNowState(chunks, nowDt)          nowMinutes = minutesOfDay(nowDt)
                        │                                      │
                        │                                      ▼
                        │                       rangeStart = floorHour(min(nowMinutes, firstStart))
                        │                       rangeEnd   = ceilHour(max(nowMinutes, lastEnd))
                        │                                      │
                        ▼                                      │
             buildTimeline(chunks, nowState)        ┌──────────┴───────────┐
             — NO LONGER emits NowMarkerRow          │                      │
             — still emits LeadingFreeRow/           ▼                      ▼
               GapFreeRow/ChunkRow (NOW-02      Layer 1: rows          Layer 2: hour axis
               suppression logic UNCHANGED)     Column of duration-    Positioned labels +
                        │                       sized boxes,           hairlines at
                        ▼                       top-aligned in         (hourMinutes-rangeStart)
             SingleChildScrollView               clock order           *kPixelsPerMinute,
             (_dayScrollController)               │                    IgnorePointer
                        │                          ▼
                        │                    Stack (fixed height =
                        │                    (rangeEnd-rangeStart)*kPixelsPerMinute)
                        └─────────────────────────►│
                                                    ▼
                                          Layer 3: now-line overlay
                                          Positioned top: (nowMinutes-rangeStart)*kPixelsPerMinute
                                          IgnorePointer, topmost z-order
                                                    │
                                                    ▼
                                    postFrameCallback (one-shot, D-02 load-bearing):
                                    targetOffset = ((nowMinutes-rangeStart)*kPixelsPerMinute)
                                                   - viewportHeight/2
                                    clamp(0, _dayScrollController.position.maxScrollExtent)
                                          ← maxScrollExtent only valid HERE, post-layout
                                    _dayScrollController.animateTo(targetOffset, 250ms, easeOut)
```

### Recommended Project Structure

No new top-level folders. File-level changes within `lib/screens/today/`:

```
lib/screens/today/
├── timeline.dart              # DELETE NowMarkerRow class + its buildTimeline emission logic;
│                               # KEEP nowMinutes param (still needed for NOW-02 leading-row
│                               # suppression, which this phase does NOT touch)
├── today_screen.dart          # DELETE _nowMarkerKey, _didCentreMarker, the NowMarkerRow switch
│                               # arm, both ensureVisible blocks; ADD rangeStart/rangeEnd/
│                               # nowMinutes-offset arithmetic, ADD Stack/Positioned layers,
│                               # ADD single-flag animateTo post-frame callback
├── widgets/
│   ├── now_marker.dart        # RENAME/REWRITE — becomes an overlay widget (full-width rule +
│   │                           # time chip), not a TimelineRowTile-wrapped row
│   ├── timeline_row_tile.dart # DECISION NEEDED — its time-text SizedBox role is obsoleted by
│   │                           # the new hour axis; kGutterWidth constant is reused verbatim for
│   │                           # the axis column width only
│   ├── free_time_row.dart     # SMALL EDIT — vertical-centering within a duration-tall parent
│   │                           # instead of intrinsic Padding(vertical: 8)
│   └── live_row_card.dart     # UNCHANGED — the one deliberate CAL-01 exception, carried forward
└── (new, small) hour_axis.dart or inline in today_screen.dart — Positioned hour labels + hairlines
```

`lib/screens/schedule/widgets/chunk_card.dart` and `swipeable_chunk_card.dart` also change (density
tiers, `showStartTime` default flip, `_DashedBorderPainter` parameterization) — see Common Pitfalls
#4-5.

### Pattern 1: Removing a sealed-class subtype is a scoped, one-site compile break

**What:** `TimelineRow` is `sealed class TimelineRow {}` in `timeline.dart:13` with exactly four
subtypes today (`ChunkRow`, `LeadingFreeRow`, `GapFreeRow`, `NowMarkerRow`). Dart enforces exhaustive
`switch` over sealed hierarchies at compile time — this is documented in the codebase's own comments
(`timeline.dart:11-12`, `today_screen.dart:88` "Dart's sealed-class switch-statement exhaustiveness
is a compile error, not a lint").

**Verification (not assumed):** `grep -rn "case ChunkRow\|case LeadingFreeRow\|case GapFreeRow\|case
NowMarkerRow" lib/ test/` returns exactly one switch site — `today_screen.dart:632-715`'s
`_buildTimelineRow` method [VERIFIED: grep against live tree, 2026-08-10]. No other file
pattern-matches on the sealed hierarchy. A second, non-switch call site does an `is` type-check on
the variant: `today_screen.dart:1130`, `timelineRows.any((row) => row is NowMarkerRow)` — used only
by the marker-fallback centre-on-open block being deleted anyway.

**Removing a subtype (not adding one) requires NO switch-arm edit for exhaustiveness** — going from
4 arms to 3 is always legal; only *adding* a subtype forces every switch to gain a case (this is what
happened in reverse during Phase 24-01, "Added a minimal `NowMarkerRow` case ... outside this plan's
declared file scope" per STATE.md). The one edit required is deleting the now-dead
`case NowMarkerRow(:final minutes):` arm (`today_screen.dart:643-673`) so it doesn't reference a type
that no longer exists.

**Verdict — delete outright, don't keep-and-ignore:** a sealed variant cannot be "kept but ignored"
while the hierarchy stays exhaustive-checked — if `NowMarkerRow` remained in the sealed set, every
switch over `TimelineRow` (today just one, but the whole point of `sealed` is guaranteeing future
switches can't forget it either) would still be compile-forced to handle it, meaning "ignore" would
mean writing a live, reachable, dead-looking branch — worse than deleting it, and directly against
this codebase's own repeatedly-stated aversion to parallel/dead code paths (STATE.md's
single-now-detector discipline, "a code review caught and fixed a third" detector). Delete the class
and its two emission blocks in `buildTimeline` (`timeline.dart:78-84`, `115-122`, `129-131`).

**One thing that must NOT be deleted alongside it:** `buildTimeline`'s `nowMinutes` parameter itself.
It is also load-bearing for **NOW-02** (`timeline.dart:103`, the `LeadingFreeRow` suppression once
its window has closed) — a requirement this phase's CONTEXT.md/UI-SPEC never revisits or retires.
Deleting `nowMinutes` wholesale from `buildTimeline`'s signature would silently regress NOW-02.

### Pattern 2: `SingleChildScrollView` + `Stack` + `Positioned`, not `ListView.builder`

**The UI-SPEC's architecture section already prescribes this** (`26-UI-SPEC.md` "Architecture: from
a row list to a positioned overlay"). The implementation-risk question is whether eager `Stack`
rendering (all children laid out regardless of scroll position) matters at this app's scale, versus
`ListView.builder`'s lazy viewport culling.

**Real answer, not a hedge: it doesn't matter, and the codebase has already made and shipped this
exact tradeoff once.** `today_screen.dart:1171-1176` currently uses `SingleChildScrollView` + `Column`
(not `ListView`) for the non-proportional list, with an explicit code comment:

> "SingleChildScrollView + Column, deliberately NOT a ListView: the centre-on-open above needs the
> live row already laid out, and a lazy ListView may not have built a row far down the day. A day is
> bounded at a few dozen rows, so eager layout is the cheap correct answer and avoids a
> scroll-positioning package." [VERIFIED: `today_screen.dart:1171-1176`, 2026-08-10]

A time-proportional day at `kPixelsPerMinute = 4.0` is bounded the same way: `26-UI-SPEC.md`'s own
worked example puts a realistic 10-12 hour day at 2400-2880px total — but the *row count* driving
layout cost is unchanged from today (still one widget per chunk/gap, still "a few dozen"). Flutter's
layout/paint cost scales with widget count and paint-surface complexity, not raw pixel height; 2880px
of mostly solid-fill `Card`/dashed-outline content with ~20-60 total widgets is trivially cheap on
both web (CanvasKit) and mobile — orders of magnitude below a single scrolled image. `ListView.builder`
exists to solve *thousands*-of-items culling; this app will never have that many chunks in a day.
Additionally, `ListView.builder` cannot natively express "paint an overlay at an arbitrary absolute
pixel offset across the whole scrollable content" — the now-line and hour-axis need a `Stack` region
regardless, so using `ListView.builder` for Layer 1 would still require a *second* overlaying
mechanism for Layers 2-3, adding complexity for no benefit. **Verdict: `SingleChildScrollView` wrapping
a fixed-height `Stack` (children: rows Column, hour-axis Positioned labels, now-line Positioned
overlay) is correct and should not be second-guessed for performance during planning.**
[MEDIUM confidence — corroborated by in-repo precedent (HIGH) plus general Flutter layout-cost
reasoning that was not independently re-verified via an authoritative doc this session (a live
WebSearch for the specific Stack/Positioned/SingleChildScrollView performance claim failed to return
results and fell back to trained knowledge — see Assumptions Log A1).]

### Pattern 3: Scroll-on-open — arithmetic `animateTo`, not `ensureVisible`, and the `maxScrollExtent` ordering hazard is real

`Scrollable.ensureVisible` needs a rendered widget's `BuildContext` (via `GlobalKey`) — that's how
Phase 24-04 centred on the live row or the marker row. Under absolute positioning there is no "the
marker's row widget" to find a context for; the target offset is pure arithmetic, exactly as
`26-UI-SPEC.md`'s "Scroll-on-open" section already specifies:

```
targetOffset = ((nowMinutes - rangeStart) * kPixelsPerMinute) - (viewportHeight / 2)
             , clamped to [0, maxScrollExtent]
```

**The hazard, confirmed via a live web search of Flutter's own issue tracker:** passing an
out-of-bounds offset to `ScrollController(initialScrollOffset: ...)` is a documented crash vector —
`flutter/flutter#96924` reports a **hard crash on iOS** from `ScrollController(initialScrollOffset:
double.maxFinite)` [CITED: github.com/flutter/flutter/issues/96924, found via WebSearch 2026-08-10].
This is exactly why `initialScrollOffset` must **not** be used here — a `DayComplete` day where `now`
is at the very bottom will, for at least one frame, produce a computed offset that could exceed
`maxScrollExtent` before the constant-based `Stack` height and the real live-row height (see Common
Pitfalls #3) are both known.

The UI-SPEC's chosen mechanism — a one-shot `WidgetsBinding.instance.addPostFrameCallback` that reads
`_dayScrollController.position.maxScrollExtent` and calls `animateTo` — is the **safe** pattern
already used by both of Phase 24's `ensureVisible` blocks (`today_screen.dart:1100-1113`,
`1133-1143`), and it avoids the `initialScrollOffset` crash class entirely because `animateTo` is
called on an already-laid-out, already-attached `ScrollController`.

**The ordering hazard to flag explicitly for the planner:** `rangeStart`/`rangeEnd`/`nowMinutes` can
all be computed synchronously in `build()` (pure arithmetic on already-known data), but
`maxScrollExtent` **cannot** — it is only valid after the `Stack`'s fixed-height content and the
`SingleChildScrollView`'s viewport have both been laid out. The `.clamp(0, maxScrollExtent)` call
must happen **inside** the post-frame callback, reading `_dayScrollController.position.maxScrollExtent`
there — not precomputed in `build()` alongside the rest of the offset math, where it is not yet a
valid value (attempting to read `.position.maxScrollExtent` on a freshly-attached, not-yet-laid-out
`ScrollController` in the same synchronous frame is undefined and generally throws in debug builds).
This mirrors exactly the ordering discipline the existing `_didCentreLiveRow`/`_didCentreMarker` code
already follows (flag set synchronously in `build()`, actual scroll math and target resolution
deferred to the post-frame callback) — the pattern is not new to this phase, only the arithmetic
computed inside it is.

### Pattern 4: Tick cadence — the existing 1-minute ticker is sufficient; the UI-SPEC is silent on this by design

`26-UI-SPEC.md` does not mention `Timer`, tick cadence, or animation frame rate anywhere in its text
[VERIFIED: full read of `26-UI-SPEC.md`, 2026-08-10] — this is a genuine gap the planner must resolve,
not an oversight in this research.

At `kPixelsPerMinute = 4.0`, one minute of elapsed time moves the now-line 4px on the next
`Timer.periodic(Duration(minutes: 1))` tick (`today_screen.dart:165`, unchanged). That is a visible
"step," not a frame-by-frame glide — but CAL-02's actual wording is "**a continuously-positioned**
now-line sits at the true current moment" (REQUIREMENTS.md), which describes the *position formula*
being valid at every instant (arithmetic on `nowMinutes`, never stale), not a requirement that the
pixel itself animates smoothly between minutes. The origin quote in ROADMAP.md ("a red line that
scrolls down the page ... relative to the time") is about the line's position changing *over the
course of the day*, which a 1-minute step-cadence already delivers.

**Do not add a faster tick without re-litigating Phase 23's battery contract.** `today_screen.dart`'s
own doc comments are explicit and adversarial about this: the 1-second `_fastTimer`
(`today_screen.dart:76-93`) exists **only** inside the final 60 seconds of the current activity,
specifically because "D-01 forbids a blanket 1-second ticker on a screen the user leaves open all
day" (`today_screen.dart:79`). Making the now-line animate smoothly at, say, 60fps or even a blanket
1-second cadence would reopen exactly the tradeoff Phase 23-02/23-05 fought to avoid, for a cosmetic
gain (a 4px/min step vs. a glide) that no locked decision or requirement asks for. **Recommendation:
keep the 1-minute `Timer.periodic` unchanged; CAL-02 is satisfied by the position being correct on
every rebuild, not by the rebuild rate itself.**

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Scroll-to-offset animation | A custom `Tween`/`AnimationController`-driven scroll | `ScrollController.animateTo(duration, curve)` | SDK built-in, already the exact API Phase 22/24's `ensureVisible` calls used for `duration`/`curve` — same felt motion, zero new machinery |
| Dashed/hairline painting | A `dotted_border`-style pub package dependency | Extend the existing file-private `_DashedBorderPainter` (`chunk_card.dart:160-199`) with two new constructor params (dash length, dash gap) alongside its existing `strokeWidth` param, and a new corner-radius param | The codebase already ships a working, tested, zero-dependency dashed painter; the UI-SPEC's Compact-tier break needs a tighter 2dp/2dp pitch and 6dp radius vs. the current hardcoded `_dashWidth`/`_dashGap`/`_radius` constants (4/4/12) — this is a parameterization, not a new capability |
| Time-of-day → pixel offset math | A calendar/day-view timetable package | Plain arithmetic (`durationMinutes * kPixelsPerMinute`, `Positioned(top:)`) — exactly what `26-UI-SPEC.md` already specifies | CLAUDE.md: "Canopy is a dumb app on purpose... rule-based and deterministic" — a scheduling-UI package is precisely the kind of opaque dependency the product's own stated philosophy rejects, for what is roughly 40 lines of arithmetic |

**Key insight:** this phase's entire risk surface is in *removing* existing, working machinery
(sealed variant, `GlobalKey`s, `ensureVisible`, dual flags) and *replacing* it with simpler
arithmetic — not in adding new capability. Nothing in this phase justifies a new dependency.

## Runtime State Inventory

Not a rename/refactor/migration phase in the sense this section exists for (no persisted
identifiers, data keys, or external service configuration are renamed). Explicitly checked against
all five categories:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — Hive models (`ScheduledChunk`, etc.) are untouched; `NowMarkerRow`/`TimelineRow` are plain in-memory Dart classes, never persisted | None |
| Live service config | None — no external services involved (local-first app, no backend) | None |
| OS-registered state | None — no OS-level registration (notifications, task scheduling) touched by this phase | None |
| Secrets/env vars | None | None |
| Build artifacts | None — no package/dependency changes | None |

## Common Pitfalls

### Pitfall 1: Deleting `NowMarkerRow` breaks exactly two call sites, both known and small
**What goes wrong:** Forgetting the second, non-switch reference (`today_screen.dart:1130`,
`timelineRows.any((row) => row is NowMarkerRow)`), which is a plain type-check, not caught by the
compiler the way the switch arm is — deleting the class without deleting this line is a silent
runtime no-op (the `.any` always returns false), not a compile error, so it could ship unnoticed if
the surrounding marker-fallback block isn't also deleted as a unit.
**Why it happens:** Sealed-class exhaustiveness catches the `switch` but not general `is`/type-check
usage elsewhere.
**How to avoid:** Grep `NowMarkerRow` after the edit — it should return zero results in `lib/`.
**Warning signs:** `flutter analyze` stays clean (this specific bug doesn't trigger a lint) — this is
exactly the class of bug that needs a grep-based verify step in the plan, not just `flutter analyze`.

### Pitfall 2: `initialScrollOffset` is a crash vector — never use it for this
**What goes wrong:** An out-of-bounds `ScrollController(initialScrollOffset: ...)` value has a
documented hard-crash report on iOS (`flutter/flutter#96924`) [CITED: GitHub issue, found via
WebSearch].
**Why it happens:** `initialScrollOffset` is applied before the scrollable's content is laid out, so
`maxScrollExtent` isn't known yet — there's no way to safely clamp it at construction time for a
day whose total height depends on runtime data (chunk count/durations).
**How to avoid:** Use the existing post-frame-callback + `animateTo` pattern (Architecture Patterns
§3); never pass a computed offset to the `ScrollController` constructor.
**Warning signs:** Any code that tries to pre-scroll via the constructor rather than a post-frame
callback.

### Pitfall 3: The live row's real height is the one place "pure arithmetic" breaks down — this needs an explicit planner decision
**What goes wrong:** `26-UI-SPEC.md`'s "The live row exception" section says rows after the live row
must use its "real measured height (available post-layout)" for their cumulative offset — but a
`Positioned` widget's `top:` value must be known *before* that layout pass completes, creating a
circular dependency (you need the live row's rendered size to place the next `Positioned` widget, but
`Positioned` widgets in a `Stack` don't participate in a size-negotiation protocol the way `Column`
children do).
**Why it happens:** `LiveRowCard` is intentionally content-driven (~200-220px, "let now break the
grid" — carried forward, not reopened, per the UI-SPEC), which is precisely why it can't be computed
from `durationMinutes * kPixelsPerMinute` like every other row.
**How to avoid — two options, planner must pick one and document the choice:**
  - **(a) Fixed estimated-height constant** (e.g. `kLiveRowEstimatedHeight = 210.0`, matching the
    UI-SPEC's own "200-220px" range): simplest, zero extra layout passes, small (~±10px) positional
    drift for rows immediately after the live row — likely invisible given the now-line and hour-axis
    are the only elements whose *exact* position matters, and both are computed independent of row
    stacking (they use `nowMinutes`/`hourMinutes` directly against `rangeStart`, not cumulative row
    heights).
  - **(b) Two-pass measure-then-position**: build once with an estimate, read the live row's actual
    `RenderBox.size` via a `GlobalKey` in a post-frame callback (the same `_liveRowKey` pattern already
    in the codebase, repurposed from "find it to scroll to" to "measure it"), then `setState` to
    correct subsequent rows' offsets. More faithful to the UI-SPEC's literal wording, but adds a
    second layout pass and a possible one-frame visual snap for anything below the live row.
  **Recommendation: (a).** The UI-SPEC's own CAL-01 exception language ("it is *supposed* to swell
  larger than its neighbors") already accepts imprecision for this one row; a fixed estimate is
  consistent with that spirit and avoids a whole class of correction-frame bugs for a cosmetic
  few-pixel gain.

### Pitfall 4: `TimelineRowTile`'s time-text responsibility is obsoleted, not extended — needs a planner decision, not a silent edit
**What goes wrong:** `TimelineRowTile` (`timeline_row_tile.dart`) currently reserves a `kGutterWidth`
(52dp) `SizedBox` per row and renders that row's own compact start time inside it. The UI-SPEC moves
time display to (a) a persistent hour-axis overlay (round-hour labels, not per-chunk) and (b) back
into the card itself for Full-tier chunks (`showStartTime` flips `false → true`). This means
`TimelineRowTile`'s current per-row time-rendering branch (`timeline_row_tile.dart:77-82`) has no
remaining caller that needs it to show anything — every row either shows no time in its 52dp column
(hour axis now owns that column visually) or shows its time inside the card body instead.
**Why it happens:** The gutter's *column width* (`kGutterWidth = 52.0`) is reused verbatim for the
axis, but its *content* (per-row text) is not — the UI-SPEC is explicit about this ("the 52dp gutter
width... stops being a per-`TimelineRowTile` static time label").
**How to avoid:** The planner must decide explicitly whether to (a) keep `TimelineRowTile` as a pure
16dp-inset + 52dp-reserved-blank-column wrapper (deleting its time-text branch), or (b) delete
`TimelineRowTile` entirely and inline the padding/inset directly wherever Layer 1 rows are built,
since the hour axis is a separate `Positioned` overlay that doesn't route through this widget at all.
Either is workable; leaving `TimelineRowTile` unchanged (still trying to render per-row compact time)
would visually collide with the new hour axis's round-hour labels in the same 52dp column.
**Warning signs:** Two different time strings rendering in the same 52dp column at different
vertical offsets.

### Pitfall 5: The dashed-border painter needs new constructor parameters, not just reuse
**What goes wrong:** `_DashedBorderPainter` (`chunk_card.dart:160-199`) only parameterizes
`strokeWidth` today; `_dashWidth`, `_dashGap`, and `_radius` are hardcoded `static const` fields (4.0,
4.0, 12.0). The UI-SPEC's Compact-tier break needs a **different** dash pitch (2dp/2dp, tightened from
4dp/4dp) and corner radius (6dp, down from 12dp) — this requires extending the painter's constructor,
not just calling it with a different `strokeWidth`.
**Why it happens:** The painter was written for a single visual treatment (D-06/G-02's two break
weights, which only ever varied `strokeWidth`); this phase introduces a third dimension of variation
(compact-vs-full geometry) the original design didn't anticipate.
**How to avoid:** Add `dashWidth`, `dashGap`, `radius` as optional constructor params (defaulting to
the current 4/4/12 values) so the existing Full-tier break call site is unaffected.
**Warning signs:** A second, duplicated painter class instead of parameterizing the existing one.

### Pitfall 6: The UI-SPEC's stated "breaks lose their tap target" rationale describes behavior that doesn't currently exist — verify before scoping a task for it
**What goes wrong:** `26-UI-SPEC.md`'s "Row content density" section frames the Compact-tier break's
lack of a tap target as "a deliberate behavior change from the current implicit `onTap` (every
unresolved chunk, including breaks, currently opens `ChunkDetailSheet`)." Reading the live code
directly contradicts this: `SwipeableChunkCard.build()` (`swipeable_chunk_card.dart:67-74`) returns a
bare `ChunkCard(chunk: chunk, goalColor: goalColor, showStartTime: showStartTime)` for any
non-`ChunkType.work` chunk — **no `onTap` parameter is forwarded at all** — and `ChunkCard._buildBreak`
(`chunk_card.dart:96-152`) wraps its content in a plain `Container`/`CustomPaint`/`Padding`/`Row`, with
no `GestureDetector` anywhere in that method. Breaks are **not tappable today**.
**Why it happens:** The UI-SPEC's author reasoned from the *general* rule ("every unresolved chunk...
opens ChunkDetailSheet") without checking whether that rule actually reached the break code path —
it doesn't; only `_WorkChunkContent` wires a `GestureDetector`.
**How to avoid:** Do not add a task to "remove" break tap targets — there is nothing to remove. If the
planner wants to double-check, grep `_buildBreak` and `SwipeableChunkCard.build()`'s early-return
branch for `GestureDetector`/`onTap` — both come back empty.
**Warning signs:** A plan task titled something like "strip onTap from break rows" — that task has no
code to act on and will produce a confusing no-op diff.

### Pitfall 7: Widget-test font-metrics harness lies about *whether text fits*, not about *box geometry*
**What goes wrong:** `flutter test`'s placeholder font renders every glyph as a fixed
`fontSize`-wide box (no real Roboto metrics) — this already produced one wrong, shipped constant
(`kGutterWidth` bumped 46→75 on a test measurement, corrected to 52 after a real-browser check,
documented in `timeline_row_tile.dart:8-24` and STATE.md).
**Why it happens:** The harness has no font assets loaded; any assertion that measures *text width or
whether text overflows a box* is measuring the harness's placeholder box model, not real typography.
**How to avoid — the actual distinction that matters for this phase's assertions:**
  - **SAFE to automate in `flutter test`:** any assertion on a `Container`/`SizedBox`/`Positioned`'s
    explicit `height`/`top` value — these are Dart-code constants (`durationMinutes * kPixelsPerMinute`),
    not derived from font metrics. e.g. "a 25-minute chunk's row box has height 100.0" is 100% reliable
    regardless of font.
  - **HARNESS-BOUND, needs real-browser verification (per CLAUDE.md's `tools/serve-uat.py` protocol):**
    anything asserting whether real text (title, "Now · 2:47 PM" chip, hour-axis label) visually fits
    or overflows/ellipsizes inside a small box — specifically the Compact-tier break's 20px slot and
    the now-line chip's `8dp`/`4dp` padding around `labelSmall` text. `TextOverflow.ellipsis` correctness
    at real Roboto metrics cannot be trusted from a widget-test pass/fail; it needs Dan's eyes on the
    served debug build.
**Warning signs:** A new constant derived from a `flutter test` text-measurement, unverified in a real
browser — this is the exact mistake the existing `kGutterWidth` doc comment warns against repeating.

### Pitfall 8: Multi-clock widget tests must force a full unmount between pumps
**What goes wrong:** `_TodayScreenState._nowFn` is `late final` (`today_screen.dart:67`) — set once
in `initState()`. A widget test that pumps `TodayScreen(now: () => timeA)`, then re-pumps
`TodayScreen(now: () => timeB)` on the *same* mounted widget tree silently keeps using `timeA`'s
closure.
**Why it happens:** `late final` fields are computed once at first access and never re-evaluated on
rebuild with new constructor params, if the `State` object itself isn't recreated.
**How to avoid:** Between pumps of different simulated clocks, `pumpWidget(const SizedBox.shrink())`
first to force a full unmount, then pump the new `TodayScreen(now: ...)` — this is already documented
codebase practice (STATE.md, "Phase 23-03" entry) and directly relevant here since testing the
now-line's position at multiple times of day in one test is a natural way to verify CAL-02.
**Warning signs:** A new now-line-position test that pumps two different clocks in the same test
without an intervening unmount, and silently asserts against the first clock's position twice.

## Code Examples

### Stack layer skeleton (illustrative — matches `26-UI-SPEC.md`'s architecture section)
```dart
// Source: 26-UI-SPEC.md "Architecture" section, translated to Flutter widget shape.
// This is a sketch of the shape, not a drop-in — the planner's tasks own the real code.
SingleChildScrollView(
  controller: _dayScrollController,
  child: SizedBox(
    height: (rangeEnd - rangeStart) * kPixelsPerMinute,
    child: Stack(
      children: [
        // Layer 1 — rows (owns total height via the parent SizedBox above)
        for (final row in timelineRows) _buildPositionedRow(row, rangeStart),
        // Layer 2 — hour axis, behind row content, IgnorePointer
        for (final hourMinutes in hourBoundariesIn(rangeStart, rangeEnd))
          Positioned(
            top: (hourMinutes - rangeStart) * kPixelsPerMinute,
            left: 0,
            right: 0,
            child: const IgnorePointer(child: HourAxisLabel(/* ... */)),
          ),
        // Layer 3 — the now-line, topmost, IgnorePointer
        Positioned(
          top: (nowMinutes - rangeStart) * kPixelsPerMinute,
          left: 0,
          right: 0,
          child: const IgnorePointer(child: NowLineOverlay(/* ... */)),
        ),
      ],
    ),
  ),
)
```

### Scroll-on-open — clamp inside the post-frame callback, not in `build()`
```dart
// Source: adapted from the existing centre-on-open pattern at today_screen.dart:1098-1114,
// which already uses this synchronous-flag / deferred-callback split — only the arithmetic
// inside the callback is new.
if (!_didCentreOnOpen) {
  _didCentreOnOpen = true; // set BEFORE scheduling, so a same-tick rebuild can't double-fire
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    final viewportHeight = _dayScrollController.position.viewportDimension;
    final raw = (nowMinutes - rangeStart) * kPixelsPerMinute - viewportHeight / 2;
    // maxScrollExtent is ONLY valid here, post-layout — never precompute this in build().
    final target = raw.clamp(0.0, _dayScrollController.position.maxScrollExtent);
    _dayScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  });
}
```

### `IgnorePointer` for decorative overlays — new to this codebase, standard Flutter pattern
```dart
// Source: Flutter SDK — IgnorePointer is a built-in that prevents a subtree from receiving
// hit-test events while still painting it. Not used anywhere in lib/screens/today/ today
// [VERIFIED: grep, 2026-08-10] — this phase introduces the pattern, correctly, for both the
// hour axis and the now-line (26-UI-SPEC.md requires both to never intercept a Complete/Skip
// tap on the card beneath them).
IgnorePointer(
  child: Semantics(
    label: 'Now — ${formatMinutes(nowMinutes)}',
    excludeSemantics: true,
    child: const NowLineOverlay(),
  ),
)
```

## State of the Art

| Old Approach (Phase 24) | New Approach (Phase 26) | When Changed | Impact |
|--------------------------|--------------------------|---------------|--------|
| `NowMarkerRow` inserted as a list item between `ChunkRow`s | `Positioned` overlay at an arithmetic pixel offset, independent of row boundaries | This phase | Can render truthfully mid-chunk; `Active`-suppression is no longer needed and is deleted |
| `Scrollable.ensureVisible` + `GlobalKey` (two of them) + two one-shot flags | One arithmetic `targetOffset` + `ScrollController.animateTo` + one flag | This phase | No dependency on a rendered row's `BuildContext`; works identically for every `NowState` (no live-row-vs-marker branch) |
| Per-row `TimelineRowTile` gutter shows that row's own compact time | Persistent hour-axis overlay shows round-hour labels; per-chunk exact time moves into the card (`showStartTime: true`) | This phase | A 20px Compact-tier row can't hold a time label; a 1000px+ gap row isn't left with one stranded label at its top |
| Row container height is intrinsic/content-driven | Row container height is `durationMinutes * kPixelsPerMinute` (except the named `LiveRowCard` exception) | This phase | This is CAL-01's entire point — the day's shape becomes legible without reading times |

**Deprecated/outdated:** `NowMarker` widget (`now_marker.dart`) in its current 24dp-leading-rule/
"Now"-label/fading-trailing-rule form is fully superseded — its replacement is a full-content-width
2dp stroke plus a `"Now · <time>"` chip, a different enough visual contract that this is a rewrite,
not an edit.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `Stack`+`Positioned` inside `SingleChildScrollView` at ~2880px/~20-60 widgets has no meaningful eager-layout performance cost on web/mobile | Architecture Patterns §2 | If wrong, a very dense/long day could show jank on low-end devices; mitigated by the fact this app's row count ceiling is already small and the codebase's own precedent (eager `Column` layout for the current list) has shipped without a reported performance issue |
| A2 | `ScrollController.animateTo()` with an already-clamped target never itself throws or visually overshoots regardless of `ScrollPhysics` | Architecture Patterns §3, Pitfall 2 | Low risk — the UI-SPEC's own formula already clamps explicitly before calling `animateTo`, and this is the same API already used safely by Phase 24's `ensureVisible`-adjacent code (though `ensureVisible` is a different call than `animateTo`, both route through the same `ScrollPosition` machinery) |

**Note:** A1 and A2 are general Flutter-framework behavior claims, not package-legitimacy claims —
the Package Legitimacy Gate protocol does not apply to them (no packages involved), but per this
research's provenance discipline they are logged here because a live WebSearch for A1's specific
claim returned no usable results this session and fell back to trained knowledge (see the tool-error
note in Architecture Patterns §2). Both should be re-confirmed empirically once the plan's Wave 0
tests exist, rather than trusted blindly.

## Open Questions

1. **Live row's real height — fixed estimate vs. two-pass measurement (Common Pitfalls #3)**
   - What we know: the UI-SPEC names this as a real requirement but doesn't resolve the mechanism.
   - What's unclear: whether a ~10px positional drift for rows immediately following the live row is
     acceptable, or whether the planner wants pixel-exact positioning badly enough to justify a
     two-pass layout.
   - Recommendation: use the fixed-estimate approach (Pitfall 3, option a) unless a plan-check or
     Dan's UAT specifically flags visible misalignment.

2. **Fate of `TimelineRowTile` (Common Pitfalls #4)**
   - What we know: its time-text branch has no remaining caller under the new model.
   - What's unclear: whether to keep it as a pure inset wrapper or delete it and inline the padding.
   - Recommendation: keep it as a pure 16dp/52dp inset wrapper (minimal diff, single call site to
     update at each row-content site) rather than deleting it outright — this preserves the one place
     that currently documents and owns the "16dp horizontal inset + 52dp reserved column" contract
     (`timeline_row_tile.dart:36-44`), which the hour axis and Layer 1 rows both still need to agree on.

3. **Hour-axis boundary generation — is there an existing helper, or does this phase write the first one?**
   - What we know: nothing in `lib/utils/time_format.dart` currently generates "every hour boundary
     between X and Y" — `formatMinutes`/`formatMinutesCompact`/`minutesOfDay` are all single-value
     formatters, not range generators [VERIFIED: `time_format.dart` full read, 2026-08-10].
   - What's unclear: nothing architecturally — this is confirmation that a small new pure function
     (e.g. `List<int> hourBoundariesIn(int rangeStart, int rangeEnd)`) is new code, not a gap in
     research.
   - Recommendation: plan it as its own small, directly-unit-testable pure function alongside
     `floorToHour`/`ceilToHour` (also new — not present in `time_format.dart` today).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | Entire phase | ✓ | 3.44.1 (stable) | — |
| Dart SDK | Sealed-class switch exhaustiveness | ✓ | 3.12.1 | — |
| `flutter test` | Unit/widget test verification | ✓ | Bundled with SDK; 515/515 baseline confirmed passing live [VERIFIED: full suite run, 2026-08-10] | — |
| `tools/serve-uat.py` + a real browser | Real-browser verification of harness-bound assertions (Pitfall 7) | ✓ (script present in repo, per CLAUDE.md) | — | — |

**Missing dependencies with no fallback:** none.

**Missing dependencies with fallback:** none — this phase needs nothing beyond what's already
installed and working.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` (bundled with Flutter SDK 3.44.1) |
| Config file | none dedicated — tests are auto-discovered under `test/`; `analysis_options.yaml` governs lint only |
| Quick run command | `flutter test test/screens/today_timeline_model_test.dart test/screens/today_row_widgets_test.dart test/screens/today_screen_test.dart` (the three files with direct blast radius — ~1-2s combined) |
| Full suite command | `flutter test` (515 tests baseline, confirmed green 2026-08-10, ~13s wall time) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CAL-01 | A chunk/gap row's rendered `Positioned`/`Container` height equals `durationMinutes * kPixelsPerMinute` | widget (geometric assertion — SAFE per Pitfall 7) | `flutter test test/screens/today_timeline_model_test.dart` (rewritten) | ❌ new assertions needed in existing file — Wave 0 |
| CAL-01 | Compact-tier (<20min) vs Full-tier (≥20min) content density switches correctly at the threshold | widget | `flutter test test/screens/today_row_widgets_test.dart` (rewritten `ChunkCard` group) | ❌ new density-tier group needed — Wave 0 |
| CAL-02 | Now-line's `Positioned(top:)` value equals `(nowMinutes - rangeStart) * kPixelsPerMinute` at several `NowState`s, including mid-chunk `Active` | widget (geometric — SAFE) | `flutter test test/screens/today_screen_test.dart` (rewritten marker group) | ❌ replaces the deleted `Active`-suppression tests — Wave 0 |
| CAL-02 | Now-line renders in every `NowState` (no suppression) | widget | same file | ❌ Wave 0 |
| CAL-03 | Post-open `_dayScrollController.offset` equals the clamped centred-on-now target | widget (matches the existing pattern at `today_screen.dart` Task 3 tests, e.g. "centres the live row on open (offset moves off zero)") | `flutter test test/screens/today_screen_test.dart` | ❌ rewritten single-flag version — Wave 0 |
| CAL-03 | A tick (1-minute) after open does NOT re-trigger the centre-on-open scroll | widget | same file | ❌ carries forward the existing "centres once" test pattern — Wave 0 |
| CAL-02/03 | Text actually fits/ellipsizes correctly inside the Compact-tier (20px) row and the now-line time chip at real Roboto metrics | manual-only (harness-bound per Pitfall 7) | N/A — real browser via `tools/serve-uat.py` | N/A |

### Sampling Rate
- **Per task commit:** `flutter test test/screens/today_timeline_model_test.dart
  test/screens/today_row_widgets_test.dart test/screens/today_screen_test.dart`
- **Per wave merge:** `flutter test` (full suite — confirms `today_screen_now_state_test.dart`'s 50
  `resolveNowState`/`LiveRowCard` tests, which this phase should not touch, stay green)
- **Phase gate:** Full suite green before `/gsd-verify-work`, plus a served debug build
  (`flutter build web --debug --source-maps --pwa-strategy=none` + `tools/serve-uat.py`) for the
  harness-bound checks in Pitfall 7.

### Wave 0 Gaps
- [ ] No new test *file* is needed — the three existing files (`today_timeline_model_test.dart`,
      `today_row_widgets_test.dart`, `today_screen_test.dart`) are the correct location for rewritten
      assertions; their harness/fixture helpers (`pumpDay`/`buildDayFixture`, per STATE.md's Phase
      24-02 note) are reusable.
- [ ] New pure functions need direct unit tests as they're written: `floorToHour`/`ceilToHour`,
      `hourBoundariesIn`, and the rendered-range formula (`rangeStart`/`rangeEnd` from
      `nowMinutes`/`firstStart`/`lastEnd`) — none of these exist in `lib/utils/time_format.dart` today
      [VERIFIED: file read].
- [ ] Framework install: none — `flutter_test` is already a dev dependency and in active use.

## Security Domain

`security_enforcement` is absent from `.planning/config.json` [VERIFIED: file read, 2026-08-10] →
treated as enabled per protocol. This phase is pure client-side layout/rendering arithmetic on
already-loaded, already-trusted local data (Hive-persisted schedule chunks) — it introduces no new
I/O, no new user input, no new authentication/authorization surface, and no new network calls
(consistent with CLAUDE.md's "rule-based and deterministic... do not propose or add LLM calls" product
position).

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | No auth surface in this app at all; unaffected |
| V3 Session Management | No | N/A — no sessions |
| V4 Access Control | No | N/A — single-user local app |
| V5 Input Validation | No new surface | The only "input" this phase touches is `durationMinutes`/`displayStartMinutes` already validated at write time by the schedule generator (out of scope); the new arithmetic (`floorToHour`, offset clamping) operates on already-trusted `int`s, no external/user-supplied strings parsed |
| V6 Cryptography | No | N/A — no new secrets, tokens, or crypto operations |

### Known Threat Patterns for {stack}

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Negative/degenerate `durationMinutes` producing a negative-height `Positioned`/`SizedBox` (e.g. a data-corruption edge case, not an attacker-controlled input) | Tampering (theoretical — no external attacker in this local-first, single-user app) | Clamp `durationMinutes * kPixelsPerMinute` to a non-negative value defensively when computing row heights, mirroring `timeline.dart`'s existing defensive posture for negative gaps (T-22-03, "out-of-order/overlapping chunks silently emit nothing rather than a negative-duration row") |

## Sources

### Primary (HIGH confidence)
- `lib/screens/today/timeline.dart` — direct read, sealed hierarchy and `buildTimeline` logic
- `lib/screens/today/today_screen.dart` — direct read, all 1299 lines, switch site and centre-on-open mechanism
- `lib/screens/today/now_state.dart` — direct read, `resolveNowState` (confirmed out of scope, unchanged)
- `lib/screens/today/widgets/{timeline_row_tile,free_time_row,now_marker,live_row_card}.dart` — direct reads
- `lib/screens/schedule/widgets/{chunk_card,swipeable_chunk_card}.dart` — direct reads, including the break-tap-target correction (Pitfall 6)
- `lib/dev/dev_clock.dart` — direct read, confirms DevClock's own doc comment names Phase 26 explicitly
- `lib/utils/time_format.dart` — direct read, confirms no existing hour-boundary/range helper
- `flutter test` — full suite run live, 515/515 passing; three per-file isolated runs (24, 38, 46, 50 tests) for exact blast-radius counts
- `flutter --version` — live command, 3.44.1 / Dart 3.12.1
- `.planning/phases/26-the-day-has-a-shape/26-UI-SPEC.md` — the locked design contract, full read
- `.planning/phases/26-the-day-has-a-shape/26-CONTEXT.md` — locked decisions, full read
- `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, `.planning/STATE.md`, `.planning/phases/24-where-am-i/24-UI-SPEC.md`, `CLAUDE.md` — full reads

### Secondary (MEDIUM confidence)
- `github.com/flutter/flutter/issues/96924` — `initialScrollOffset` hard-crash report on iOS, found via WebSearch, cross-checked against the codebase's existing safe pattern

### Tertiary (LOW confidence)
- General Flutter `Stack`/`Positioned`/`SingleChildScrollView` eager-layout performance reasoning (Architecture Patterns §2, Assumptions Log A1) — a live WebSearch for this specific claim returned a tool error and fell back to trained knowledge; corroborated by, but not independently verified beyond, the in-repo precedent comment

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies, versions confirmed live via `flutter --version`
- Architecture: HIGH for the parts grounded in direct source reads and the live test run (sealed-class removal, test blast radius, break-tap-target correction); MEDIUM for the Stack/Positioned performance-at-scale claim (corroborated by strong in-repo precedent but not independently re-verified via an authoritative external source this session)
- Pitfalls: HIGH — all eight are sourced from direct code reads, a live test run, or a cross-checked GitHub issue, not speculation

**Research date:** 2026-08-10
**Valid until:** 30 days (stable Flutter/Dart toolchain, no fast-moving external dependency involved) — but any code cited by exact line number should be re-verified against the tree at plan time if execution is delayed, since this is an active codebase
</content>
