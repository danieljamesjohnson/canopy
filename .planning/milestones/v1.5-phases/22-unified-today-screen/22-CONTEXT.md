# Phase 22: Unified Today Screen - Context

**Gathered:** 2026-08-07
**Status:** Ready for planning
**Mode:** Design agreed with Dan via sketch 001 (`.planning/sketches/001-unified-today/`) — the
winning variant and its locked decisions are binding on this phase, not "Claude's discretion".

<domain>
## Phase Boundary

Home and Schedule become one destination. Users see what's happening now and the rest of the day
on one screen, and every existing entry point still lands somewhere real.

Requirements in scope:
- **UNIFY-01**: User sees what's happening now and the rest of the day on one screen, without switching tabs
- **UNIFY-02**: Shell navigation reflects the merge, and every existing entry point (notification tap, in-app links to `/schedule`) lands on the unified screen rather than a dead route

Out of this phase: the live "right now" *behavior* (naming a running break, the countdown, the
edge states) is Phase 23 — LIVE-01/02/03. This phase delivers the surface those land on.

</domain>

<decisions>
## Implementation Decisions

### LOCKED by design review (Dan, 2026-08-07) — do not re-litigate in planning

Winner: **sketch 001, variant A "Pure inline"**. Open
`.planning/sketches/001-unified-today/index.html` — it is the reference, and it is throwaway
HTML, not code to port.

1. **Inline timeline — no separate "now" card, no hero.** The day is ONE scrollable list. The
   current row swells into a live card *in place*; it is not lifted out into its own region
   above the list. This was chosen over a dominant hero block and over a compact top band.
2. **The list auto-scrolls the current row to centre on open.** That is how "now" stays
   findable, instead of a sticky element.
3. **No sticky recall bar.** Sketch variant B added a pill that appeared when the live row
   scrolled off; review found that on a typical day at phone height the live row rarely
   scrolls off, so the bar seldom fired. Rejected as machinery for a rare case.
4. **No time rail / gutter chrome.** Sketch variant C's vertical rail was rejected — on a phone
   its ~68px comes out of the activity names.
5. **Free time is named, never collapsed.** Gaps ≥ ~10 min render as their own quiet rows:
   "Free until 8:00am" before the day's first activity, "Free · 1h 40m" mid-day. Dan
   specifically liked seeing "nothing until 8" and wants that preserved and generalised.
6. **Row vocabulary from the sketch:** completed chunks struck through + ✓ and dimmed; skipped
   chunks dimmed and labelled "skipped"; breaks in a dashed, lighter treatment (they are not
   achievements); commitments in the tertiary container colour (anchored, not discretionary);
   time in a left gutter in mono at ~46px.
7. **Mood theming still applies** — the screen inherits the existing mood-seeded ColorScheme
   (`theme_notifier.dart`); nothing here introduces a new palette.

### Navigation — the risk item

UNIFY-02 exists because removing `/schedule` breaks two live callers:
- `lib/main.dart:86` — `router.go('/schedule')` on notification tap. Chunk reminders are a
  daily-use path; this must land on the working unified screen.
- `lib/screens/home/home_screen.dart:495` — the in-app "see full schedule" affordance, which
  becomes meaningless once the screens are one and should go rather than point at itself.

Keeping `/schedule` as a redirect to the unified route is acceptable and probably safest;
deleting the route outright is not, unless every caller is updated in the same change.

`lib/widgets/responsive_shell.dart` hardcodes four destinations (Home / Goals / Schedule /
Settings) and cites a UI-SPEC "icon library lock" with `NavigationRailLabelType.all`. That lock
is superseded for this phase: the merge reduces it to three. Update the UI-SPEC note rather
than silently violating it.

### Deliberately NOT decided here

- The exact name of the merged destination ("Today" is used in the sketch; the shell label may
  differ). Planning may choose, but it should be one word and it should not be "Home".
- Whether the merged screen keeps a separate check-in entry point or folds it in. The check-in
  flow (`/schedule/checkin`) is not in this phase's requirements — do not restructure it.

</decisions>

<code_context>
## Existing Code Insights

- `lib/screens/home/home_screen.dart` (848 lines) — holds `resolveNowState` + the `NowState`
  sealed class (PreStart / Active / Overdue / GapBeforeNext / DayComplete), a 1-minute
  `Timer.periodic` at :263, and widgets/ (active_chunk_card, end_of_day_card, review_banner).
- `lib/screens/schedule/schedule_screen.dart` (495 lines) — the timed plan view, plus widgets/
  (chunk_card, chunk_detail_sheet, now_marker, schedule_progress_bar, swipeable_chunk_card).
  `now_marker.dart` already solves "where is the current clock time in the list".
- `lib/widgets/responsive_shell.dart` — the four-destination shell (NavigationRail ≥720dp /
  NavigationBar below), `goBranch` semantics.
- `lib/router.dart` — `/home`, `/schedule` (+ `/schedule/checkin`), StatefulShellRoute branches,
  `rootNavigatorKey` for notification-driven navigation.
- `lib/screens/schedule/schedule_screen.dart:404` calls `showAdaptiveFormModal` — the merged
  screen inherits that adaptive dialog/sheet behaviour; don't regress Phase 18's RESP-01/02/03.

Both screens already read the same `ScheduleNotifier` state, so the merge is a view-layer
consolidation, not a data-layer change. No Hive migration is expected in this phase; if planning
concludes otherwise, that is a signal the scope drifted.

</code_context>

<specifics>
## Specific Ideas

Reference render (sketch 001 variant A), mid-morning, mood 3:

    Today                          Tue 4 Aug
    🌤️ Steady day · 9 chunks
    ────────────────────────────────────────
            ┆ Free until 8:00am
     8:00   Exercise            25m  ✓   (struck through, dimmed)
     8:25   Short break          5m  ✓   (dashed, lighter)
     9:00   Side project        25m  skipped
    10:45   ╭──────────────────────────────╮
            │ RIGHT NOW — RESTING          │
            │ Taking a break               │
            │ 3 min left · until 10:50am   │
            │ ▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░ │
            │ Next · Reading at 10:50am    │
            ╰──────────────────────────────╯
    10:50   Reading             25m
    11:20   ┆ Free · 1h 40m
     1:00p  Job — work block     3h       (tertiary container)

</specifics>

<deferred>
## Deferred Ideas

- Sticky recall bar (sketch variant B) — revisit only if long sunny days prove the live row
  scrolls off often in real use.
- Time-rail treatment (sketch variant C) — rejected for phone width; could return for a
  desktop-only layout at ≥720dp, but not in this milestone.
- Any chunk-timer / clock-in behaviour — explicitly out of v1.5 (see REQUIREMENTS.md "Future").

</deferred>
