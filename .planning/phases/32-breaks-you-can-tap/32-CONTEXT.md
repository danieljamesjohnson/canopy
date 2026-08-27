# Phase 32: Breaks You Can Tap - Context

**Gathered:** 2026-08-27
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped via workflow.skip_discuss)

<domain>
## Phase Boundary

A break is skipped by tapping a button you can see, on a row big enough to read as a real section of
the day — with the timeline still telling the exact truth about how long everything takes.

Raised by the owner on 2026-08-27 while judging Phase 31's round-two UAT on a real device: *"I think
the icon you're using makes it look like you can drag and drop the short break, not hold and slide.
Let's just make the thing 50% bigger, have a skip button on the side, and make it look like a small
section similar to work."*

**In scope:**

1. `kPixelsPerMinute` 4.0 → 6.0, with every derived constant **re-derived rather than restated**.
   `kSubCompactBreakMinHeight` (32.0), `kMinBreakDragTarget` (48.0), `kCompactLiveMinHeight` (88.0)
   and the density-tier thresholds were all tuned against 4.0 and all shift meaning at 6.0. A 5-min
   break at 30dp is still under the 32dp sub-compact threshold, so it would *still* render as a
   hairline unless the thresholds move too.
2. Break rows styled as *a small section similar to work* — a real card with background and border,
   not a hairline between two `Divider`s. Retires Phase 29's `_SubCompactRow` treatment for breaks at
   the 5-minute tier.
3. A visible, labelled **Skip** button on the break card.
4. Remove the swipe path for breaks and retire the machinery it leaves dead — `kBreakHitSlop`,
   `kMinBreakDragTarget`, the Layer 1b `Stack` pass, and the `Icons.drag_indicator` grip glyph, plus
   their tests.

**Explicitly out of scope (from the ROADMAP's "must NOT do"):**

- **Do not make any row lie about its duration.** SKIPBREAK-02's spirit survives D-32-01 intact and
  is the reason that option was chosen: rows get bigger, the mapping stays exact.
- **Do not remove the swipe from work chunks.** Only breaks become button-only.
- **Do not remove `LiveRowCard`'s compact-tier Skip button** (D-31-07). It is closer to what the
  owner asked for than the swipe ever was, and it survives.
- **Do not re-litigate** skipped-break legibility at `Opacity(0.5)` or D-31-03's "skipping a break
  does not hand the minutes back." Both PASSED human UAT and are settled.

</domain>

<decisions>
## Implementation Decisions

### Owner-ruled — do NOT re-ask, do NOT re-litigate

These three were ruled by the owner on 2026-08-27 and are recorded in the ROADMAP phase entry.
Planning must treat them as fixed inputs.

- **D-32-01 — `kPixelsPerMinute` 4.0 → 6.0.** This **reverses Phase 29 D-03**, which rejected
  raising it. That rejection was made on *legibility* evidence and is not wrong on its own terms; it
  is overturned by evidence that did not exist then — two rounds of a real thumb failing on a 20dp
  row. Chosen over three alternatives specifically **because it keeps the grid honest**: every row
  still renders at exactly `durationMinutes × kPixelsPerMinute`. A 5-min break becomes 30dp, a
  25-min work chunk 150dp. **Known cost, accepted by the owner: the day is 50% taller to scroll**
  (an 8-hour day 1920dp → 2880dp). The rejected alternatives all bought a bigger break by making
  some row lie about its duration.

- **D-32-02 — breaks become button-only; the swipe is removed from break rows.** Chosen over
  keeping both. **Reverses D-31-01's one-directional `Dismissible` for breaks and makes D-31-06 dead
  — both halves of it.** Retire the dead machinery deliberately; do not leave an unused
  invisible-band mechanism in the tree. Accepted inconsistency: work chunks stay swipeable, so
  breaks and work no longer share a gesture vocabulary. The owner was shown that trade-off and took
  it.

- **D-32-03 — the Skip button is ~64dp wide × the full 30dp row height.** At 6.0 px/min a 5-min row
  is 30dp, under Material's 48dp minimum, so the button earns its target area from **width** instead
  of height: ~64 × 30 = 1920dp² against the 48 × 48 = 2304dp² guideline. Slightly under on raw area,
  and **deliberately so** — every pixel of it is *visible*, and a wider-than-tall target suits a
  thumb's contact patch better than a square one. Three alternatives were offered and declined: a
  vertically-overhanging hit area would hit 48dp *on paper* by extending into invisible space (the
  exact pattern that failed the owner twice) and would steal target area from neighbouring work
  chunks again; a 48dp floor on short breaks was declined because it makes the row lie about its
  duration.

### Claude's discretion

Everything not fixed above — file layout, widget decomposition, how the density-tier thresholds are
re-derived from `kPixelsPerMinute`, test structure — is at Claude's discretion, guided by the
ROADMAP success criteria and existing codebase conventions. Discuss was skipped per
`workflow.skip_discuss=true`.

</decisions>

<code_context>
## Existing Code Insights

**Verification note — measured, not assumed.** `kPixelsPerMinute` is load-bearing for the suite's
pixel assertions, so the migration was surveyed before planning rather than guessed at. **The blast
radius is small:** 38 symbolic references to `kPixelsPerMinute` across 4 test files (these follow
the constant automatically and need no edit), and only **4 hardcoded pixel literals** in the entire
`test/` tree. Files touched: `today_screen_test.dart`, `today_timeline_model_test.dart`,
`today_screen_now_state_test.dart`, `today_row_widgets_test.dart`.

An earlier draft of the ROADMAP entry warned that "a large number" of tests hardcode 4.0-derived
geometry and that a mass update would be dangerous. **That was wrong and is corrected:** the survey
found 4 literals. The discipline still applies to those four (re-derive from the constant; justify
any literal that must stay), but **this is not a hazardous migration and must not be planned as
one.** Over-engineering a migration strategy against a risk that isn't there costs real work.

Further codebase context will be gathered during plan-phase research.

</code_context>

<specifics>
## Specific Ideas

**Requirements:**

- **TAPBREAK-01** — a break is skipped by a visible, labelled button; no swipe, no invisible target.
- **TAPBREAK-02** — the grid still tells the exact truth: every row renders at
  `durationMinutes × kPixelsPerMinute`, at the new 6.0.
- **TAPBREAK-03** — a 5-minute break reads as a section of the day, not a hairline.

**This phase MUST end in a human UAT checkpoint**, for the fourth time and with the strongest
precedent yet: Phase 27 failed 2 of 3 human items after 16/17 automated; Phase 29 went 587-green
while the owner saw no breaks at all; Phase 31 went 625-green then 639-green and was contradicted by
a thumb **twice** — the second time finding a defect (an icon that means the wrong verb) that no
assertion in the suite could ever have caught.

**UAT mechanics (from the ROADMAP):** reuse port 8143, kill whatever is squatting it first. Per
`CLAUDE.md` trap #4, any UAT judging scheduling-engine or timeline output **must ⟳ Re-check-in
first, and that step must appear first and marked mandatory in the UAT's own instructions.**

**Two open questions this phase inherits rather than closes** — surface both in the UAT:

- **D-31-07 was never judged by a human.** The owner did not reach Item 3 of the round-two UAT.
  `LiveRowCard`'s compact-tier Skip button is code-complete and test-proven (639/639) but has never
  been confirmed on a device, and this phase changes the surface underneath it. Re-ask it.
- **The "Up next" transition still needs a ruling.** When a live break is skipped,
  `resolveNowState`'s pre-existing advance-past-resolved loop (`now_state.dart:176`) delists it from
  "current," so the header switches from the break to the next chunk. The now-line itself does not
  move. Flagged in advance in the round-two UAT; still unanswered.

</specifics>

<deferred>
## Deferred Ideas

None — discuss phase skipped.

</deferred>
