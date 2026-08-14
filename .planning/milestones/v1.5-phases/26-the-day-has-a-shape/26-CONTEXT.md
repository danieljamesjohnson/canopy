# Phase 26: The Day Has a Shape - Context

**Gathered:** 2026-08-10
**Status:** Ready for planning
**Mode:** Autonomous (`workflow.skip_discuss=true`), with the three ROADMAP-flagged open questions
put to Dan directly — they fork the work too hard to answer by default.

<domain>
## Phase Boundary

The day renders as a time-proportional surface with a continuously-moving now-line, so "where am I"
is answered by *position* rather than by a marker slotted between rows.

**Requirements:** CAL-01, CAL-02, CAL-03

**In scope:** the timeline rendering model in `lib/screens/today/` — `timeline.dart`'s row model and
whatever `today_screen.dart` does to lay it out; the now-line's position, colour, and motion; scroll
behaviour on open.

**Out of scope:** the schedule generator (untouched), `resolveNowState` as the *authority on which
activity is current* (it stays the single detector — this phase adds a position, never a second
opinion), and any new product surface. No LLM, per PROJECT.md.

</domain>

<decisions>
## Implementation Decisions

### Decided by Dan, 2026-08-10 (the three questions the ROADMAP reserved for discuss)

**D-01 — Replace the list, do not add a mode.** The proportional surface *becomes* TodayScreen's
timeline. There is no list/calendar toggle and no persisted view preference. One surface, one
now-line, one renderer to keep truthful. This is the aggressive reading and it is deliberate:
maintaining two renderers of the same day was judged worse than losing the list fallback.

*Consequence:* `NowMarkerRow`'s between-rows insertion contract in `timeline.dart` is **reworked, not
extended** (ROADMAP: "Expect ... to be reworked"). Phase 24's `Active`-state marker suppression rule
is **superseded** by CAL-02, not coexisted with — a proportional layout can place the line truthfully
mid-chunk, which is the exact reason the suppression existed.

**D-02 — Fully proportional. No gap compression.** An empty 4-hour stretch renders as a real
4-hour-tall stretch and the user scrolls through it. Rejected: collapsing long gaps to a fixed band,
and clamping rows to a min/max height. The emptiness of an empty afternoon is information, and
compressing it would reintroduce exactly the "position is a bit of a lie" problem this phase exists
to remove.

*Consequence — flagged for planning, not a blocker:* a sparse day is now several screens tall, so
**the auto-scroll-to-now behaviour carries more weight than it did in Phase 24** and must be
correct on open, not best-effort. Phase 24-04 already shipped a centre-on-open fallback
(`_didCentreMarker`) for `PreStart`/`GapBeforeNext`/`DayComplete`; under D-02 that path is the
primary way the user ever finds "now" on a sparse day. Plan accordingly.

**D-03 — Now-line uses `colorScheme.primary`.** Dan's original words were "a red line", but the
literal reading loses to two things: the palette is mood-seeded, and Phase 24's `colorScheme.primary`
marker is the one Dan already confirmed reads well at a glance. Rejected: a hardcoded red (would
reintroduce a raw `Colors.*` literal into a codebase that spent Phase 22/23 removing them, and can
clash with a warm mood seed) and `colorScheme.error` (semantically wrong for "now", and Phase 19's
UI-SPEC already excluded `error` from the palette for that reason).

### Claude's Discretion

Everything not fixed above — the pixels-per-minute scale factor and whether it is fixed or
responsive, how a 5-minute break stays legible at that scale, whether the time gutter keeps its
Phase 23 `kGutterWidth`/16dp-inset treatment or is re-derived, widget decomposition, and the
scroll-restoration mechanics — is at Claude's discretion, guided by the codebase conventions below
and the phase's success criteria.

</decisions>

<code_context>
## Existing Code Insights

Carried forward from STATE.md's verified post-Phase-25 notes. These paths were checked against the
current tree, not inherited from pre-Phase-22 notes (the old `home_screen.dart` /
`schedule_screen.dart` paths are dead — do not chase them).

- **`lib/screens/today/timeline.dart`** — pure `buildTimeline` + the sealed `TimelineRow` hierarchy.
  `isLive` is derived *only* from the injected `NowState`, never re-scanned. `NowMarkerRow` (added
  24-01) and its `nowMinutes` threading (24-02) live here. This is the file D-01 reworks.
  Dart's sealed-class switch exhaustiveness is a **compile error, not a lint** — adding or removing a
  `TimelineRow` subtype breaks the build at `today_screen.dart`'s switch immediately (learned in
  24-01).

- **`lib/screens/today/now_state.dart:97`** — `resolveNowState`, the **single** now-detector.
  `grep -rn "resolveNowState" lib/` must keep showing one definition and one call site. Phase 22
  spent real effort eliminating parallel detectors and a code review caught a third; reintroducing
  one is the specific regression this milestone is guarding against.

- **`lib/screens/today/today_screen.dart`** — ~900+ lines. Uses an injectable clock (`_nowFn`,
  `late final`, set once in `initState`) throughout; **never call `DateTime.now()` directly** — a
  code review already corrected one drift (`1035339`). `build()` takes **one** clock sample
  (`nowDt`) and derives both `resolveNowState` and `nowMinutes` from it; CAL-02's line must come off
  that same sample.

- **Tick model (Phase 23-02/23-05):** an all-day 1-minute `Timer.periodic` plus a 1-second timer that
  exists *only* inside the final minute of the current activity. `paused` no longer kills the minute
  tick, the fast tick is guarded by `_isBackgrounded`, and `build()` self-heals a dead timer.
  **A continuously-moving line at 1-minute granularity is the default** — anything faster must
  justify itself against that battery contract rather than silently replacing it.

- **`lib/dev/` DevClock (Phase 25)** — debug-only `Duration` **offset** (never a frozen instant),
  wired into every clock-gated seam. This exists precisely so Phase 26's moving now-line can be
  UAT'd without waiting; time still *flows* under override. Use it for UAT rather than asking Dan to
  sit at the screen at 9pm.

- **Layout precedent:** `Align(topCenter)` + `ConstrainedBox(maxWidth: 720)` on body content
  (POLISH-01). Zero raw `Colors.*` literals remain in `chunk_card.dart` /
  `swipeable_chunk_card.dart` — keep it that way.

- **Test seam:** multi-state widget tests must force a full unmount
  (`pumpWidget(SizedBox.shrink())`) between pumps of different clocks, or the second state's `now`
  closure is silently ignored (`_nowFn` is `late final`). Learned the hard way in 23-03.

- **Test-harness caveat:** `flutter test`'s placeholder font has no real Roboto metrics, so measured
  glyph widths inflate to a fontSize-wide box per character. `kGutterWidth` was bumped 46→75 on a
  test measurement and then corrected to 52 after a real-browser check. **Any height/width
  measurement asserted in a widget test is a harness bound, not a device requirement** — verify
  proportional layout in a real browser.

</code_context>

<specifics>
## Specific Ideas

**Success criteria (from ROADMAP), restated as what must be TRUE:**

1. A row's height corresponds to its duration, so the shape of the day is legible without reading
   any times.
2. The now-line sits at the true current moment **including inside an activity's span**, not only at
   chunk boundaries.
3. Elapsed time recedes — the past is a deliberate scroll away rather than the default view.
4. The single-clock-sample rule still holds: the line is a *position* derived from `build()`'s one
   `nowDt`, never a second opinion about which activity is current.

**Origin (Dan, Phase 24 UAT 2026-08-08), verbatim:**

> "could maek it like a calendar view as well where as time goes on theres a red line that scrolls
> downt he page to tell you where you are relatively to the time"

alongside

> "i think things int het past should have to be scrolle dto"

**Scope boundary inherited from Phase 24:** D-03's prohibition on a sticky bar, floating pill, or
jump button was about the *marker*. Whether it binds a proportional layout is an open question for
this phase, not a settled constraint — but note Dan has *not* asked for one, so adding one needs a
reason.

</specifics>

<deferred>
## Deferred Ideas

- **A list/calendar view toggle** — explicitly rejected in D-01, not deferred. If the proportional
  surface turns out to read badly for a dense day, that is a new phase, not a fallback to restore.
- **Gap compression / min-max row clamping** — explicitly rejected in D-02 for the same reason.
- `23-VALIDATION.md` remains at `status: draft` / `nyquist_compliant: false` — carried tech debt from
  Phase 23, tracked in STATE.md alongside the identical 15/16/17 drafts. Not this phase's work.

</deferred>
