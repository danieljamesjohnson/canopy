# Phase 24: Where Am I - Context

**Gathered:** 2026-08-08
**Status:** Ready for planning
**Mode:** Captured live from UAT (Dan's feedback drop), not from discuss-phase

<domain>
## Phase Boundary

The timeline itself shows where "now" falls, so the user can locate themselves in the day even
when no activity is currently running.

**Requirements:** NOW-01 (now-marker in the list), NOW-02 (no stale leading free row)

**In scope:** the row model (`lib/screens/today/timeline.dart`), its render dispatch
(`_buildTimelineRow` in `lib/screens/today/today_screen.dart`), and one small row widget.

**Out of scope:** the live row's own styling (settled in Phase 23 — Dan picked "let now break the
grid" and signed it off), the mood chip, the progress bar, the edge-state header lines, and any
change to `resolveNowState`'s classification logic.

</domain>

<decisions>
## Implementation Decisions

### Locked

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

</decisions>

<code_context>
## Existing Code Insights

- `buildTimeline` (`lib/screens/today/timeline.dart:52`) emits a `List<TimelineRow>` from a sealed
  hierarchy of exactly three subtypes — `ChunkRow`, `LeadingFreeRow`, `GapFreeRow` — with a
  doc-comment promise that the render layer can switch exhaustively "with no default branch". A
  fourth subtype is the natural home for the marker; adding one means updating the exhaustive switch
  in `_buildTimelineRow` (`today_screen.dart` ~line 556).
- The leading free row is emitted unconditionally whenever the first clock-positioned chunk starts
  after minute 0 (`timeline.dart` ~line 75, `if (start > 0) rows.add(LeadingFreeRow(start))`). It has
  no notion of whether that window has already passed — which is NOW-02.
- `resolveNowState` lives at `lib/screens/today/now_state.dart:97` and is the single now-detector.
  `build()` samples the clock once into `nowDt` and threads it to both `resolveNowState` and
  `_liveSecondsRemaining` (commit `48af6bf`, WR-01) — the marker must join that same threading, not
  add a fourth read.
- `FreeTimeRow` (`lib/screens/today/widgets/free_time_row.dart`) is the closest analog for a quiet,
  non-card row and is the pattern a marker row should follow.
- Post-G-04, `TimelineRowTile` owns the 16dp horizontal inset and the `kGutterWidth` (52) time
  gutter; child widgets carry no horizontal inset of their own.

### The regression this closes

`lib/screens/schedule/widgets/now_marker.dart` existed before the merge and was deleted in commit
`ea97862` (22-04) along with `schedule_screen.dart`. Deleting it was half right: the *old placement
logic* (`_buildActiveChunkItems`, a crude first-unresolved-chunk scan) genuinely had to die, and
22-PATTERNS.md §2 said so — but the same document also said, verbatim, "`NowMarker` the *widget*
(visual divider) is still useful as a component". Nothing took over the job. The widget went with
the scan.

</code_context>

<specifics>
## Specific Ideas

Dan's report, verbatim:

> i clicked the link and right now i can't tell what we're 'on'

> just can't tell where now is

Evidence is preserved alongside this file as `24-evidence-dan-drop.png` (originally
`~/feedback-drop/canopy/inbox/2026-08-08_17-34-09/`). What it shows, at ~12:34 on a sunny 8-chunk day:

- Header reads "Up next / Short break / Starts at 12:40 PM" — **correct**, this is `GapBeforeNext`.
- The list below shows: `Free until 11:45 AM` · Exercise (completed, struck through) · Short break
  **29 min** · Family time (skipped) · Short break 5 min · Exercise (pending, with Complete/Skip) · …
- Nothing anywhere in the list marks the current moment. The header text that answers "what's now" sits
  at the very top of the screen; the position it refers to is five rows down.
- `Free until 11:45 AM` is being rendered at 12:34 — describing a window that closed ~50 minutes ago.

Two incidental confirmations from the same screenshot, both working as designed: the 29-minute short
break is Phase 23's G-05 break-absorption in real use, and completed/skipped rows do dim and strike
through correctly (so "past looks like future" is NOT a defect for *resolved* chunks — only the
missing marker and the stale leading row are real).

</specifics>

<deferred>
## Deferred Ideas

- Dimming *unresolved* chunks whose window has passed. Not observed as a problem in Dan's session
  (his past chunks were all resolved), and it risks making an overdue chunk look inactionable. Revisit
  only if it surfaces in real use.
- Sketch variants B and D from `served/nowsketch/` (quieting non-live rows). Dan chose C in Phase 23
  and B/D remain available if the marker alone proves insufficient.

</deferred>
