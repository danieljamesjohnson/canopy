# Phase 26 — UI Review (retroactive)

**Audited:** 2026-08-11
**Baseline:** `26-UI-SPEC.md`, as amended by the G-01 (2026-08-10), G-02 (2026-08-11), and G-03
(2026-08-11) dated notes — audited against the spec **as amended**, not its original body text.
**Screenshots:** partially captured — 13 pre-existing evidence screenshots
(`evidence-26-08/`, `evidence-26-09/`) were inspected pixel-by-pixel (cropped/zoomed), plus one
fresh onboarding-state screenshot confirming the debug build at `http://danserver:8133/` is live
and renders correctly under headless Chromium with default WebGL (no swiftshader flag needed —
CanvasKit recovered from the transient `CONTEXT_LOST_WEBGL` warning). Reaching a mid-day
`Active`/`Overdue`/`GapBeforeNext`/`DayComplete` state fresh requires onboarding + DevClock
navigation not attempted in this pass; the existing evidence set already covers those states from
real-browser captures taken during 26-08/26-09, and was sufficient to confirm the primary finding
below directly, not just infer it from source.

---

## Pillar Scores

| Pillar | Score | Key Finding |
|--------|-------|-------------|
| 1. Copywriting | 3/4 | Contract strings match exactly (chip, semantics, hour label, free-row copy); `formatMinutesCompact`'s AM/PM asymmetry is now on the app's most prominent element |
| 2. Visuals | 1/4 | **Confirmed in 3 independent screenshots:** the topmost (and, by the same code path, bottommost) hour-axis label is sheared in half by the Stack's default clip on every single render |
| 3. Color | 4/4 | Zero raw `Colors.*`/hex literals in touched files; `primary` reserved exactly for "now," per D-03 |
| 4. Typography | 3/4 | Type roles/weights match the declared table; docked once, cross-referenced from the Visuals defect (the clipped label is a `bodySmall` role) |
| 5. Spacing | 4/4 | 8-pt scale and the closed micro-spacing tier followed exactly; G-01's `8dp→4dp` chip-padding amendment correctly shipped |
| 6. Experience Design | 3/4 | All 5 `NowState`s render through one unconditional overlay mechanism; G-01/G-03 collisions verifiably closed; the same clip defect is a latent risk to the now-line itself, untested |

**Overall: 18/24**

---

## Top 3 Priority Fixes

1. **Every rendered day's first and last hour-axis label is sheared in half.** `HourAxisLine` is
   `Positioned(top: geometry.yFor(hourMinutes) - kHourAxisHeight / 2, height: kHourAxisHeight)`
   (`today_screen.dart:1305-1319`). `hourBoundariesIn` (`time_format.dart:74-81`) always includes
   `rangeStart` itself as the first boundary, and `rangeEnd` as the last — both are exact
   multiples of `kHourAxisHeight/2` off the Stack's own `[0, totalHeight]` bounds. `Stack`'s
   default `clipBehavior` is `Clip.hardEdge` (confirmed against
   `flutter/packages/flutter/lib/src/widgets/basic.dart`), and the Stack in question is sized by
   an outer `SizedBox(height: geometry.totalHeight)` (`today_screen.dart:1288-1291`) with no
   `clipBehavior` override — so the top boundary's box paints from `y=-10` to `y=+10` and the
   Stack clips off everything above `y=0`; the bottom boundary is clipped symmetrically at
   `totalHeight`. **User impact:** this is not a rare edge case — it is unconditional, on every
   single day render, in every `NowState`. It is the exact defect Dan flagged and asked this audit
   to confirm ("a possibly-sheared '11 AM' label at the top of the range"); it was never caught
   because the one existing test (`test/screens/today_screen_test.dart` "hour axis coverage")
   asserts widget count and `hourMinutes`/label text presence only — never a painted rect against
   the Stack's own bounds. **Concrete fix:** either give the outer Stack `clipBehavior: Clip.none`
   (verify this doesn't change the deliberate live-row-overflow-paints-over-neighbour behavior,
   which relies on the *sibling* paint order, not on being unclipped) or reserve
   `kHourAxisHeight / 2` of padding at both ends of the Stack's total height and shift every
   `yFor` offset down by that amount so no `Positioned` box can ever start above `0` or end below
   `totalHeight`. Add the regression test the existing one doesn't have:
   `tester.getTopLeft(...).dy >= 0` and `getBottomLeft(...).dy <= stackHeight` for the first/last
   `HourAxisLine`.

2. **The now-line overlay shares the identical root cause and was never checked against it.**
   `NowLineOverlay` is positioned the same way (`Positioned(top: geometry.yFor(nowMinutes) -
   kNowLineHeight / 2, height: kNowLineHeight)`, `today_screen.dart:1360-1364`). It clips whenever
   `nowMinutes` falls within `kNowLineHeight / 2 / kPixelsPerMinute ≈ 2.5` minutes of `rangeStart`
   or `rangeEnd` — plausible in `PreStart` (now close to a whole hour, before the day starts) and
   `DayComplete` (now close to a whole hour, after the day ends), since those are exactly the
   states where `rangeStart`/`rangeEnd` are derived directly from `nowMinutes` itself. **User
   impact:** the spec calls this overlay "the screen's primary visual anchor" — if it ships clipped
   at exactly the two states (`PreStart`, `DayComplete`) where nothing else on screen tells the
   user "where now is," the one thing CAL-02 exists to guarantee fails at the edges. **Concrete
   fix:** same mechanism as #1 covers both widgets in one change; add a dedicated regression test
   at `nowMinutes == rangeStart` and `nowMinutes == rangeEnd` exactly (not just "near" — the exact
   boundary is the reproducible case) asserting the chip's full rect stays within
   `[0, totalHeight]`. This is precisely the generalized lesson `26-UAT.md`'s G-03 postmortem
   already named ("enumerate every widget type that can be Y before writing the assertion") —
   apply it here before a third gate finds this by hand.

3. **`formatMinutesCompact`'s AM/PM asymmetry is now materially more visible than when it was
   written.** `time_format.dart:47-54` returns no meridiem letter for AM times and `p` for PM
   (`"8:10"` vs `"1:00p"`) — a convention inherited from the old per-row time gutter (D-04), not
   introduced this phase. But this phase (per the G-01 amendment) promotes that exact formatter
   onto the now-line chip — the single most prominent, always-on-screen, `colorScheme.primary`-filled
   element in the app. A chip reading bare `"8:10"` with no AM/PM cue is a small but real
   legibility regression relative to its old, lower-stakes role, especially for a schedule that can
   run into the evening. **Concrete fix:** add a matching `'a'` suffix for AM in
   `formatMinutesCompact` (mirroring the existing `'p'` for PM) — a one-line change, and the chip's
   fixed-width gutter column already has budget for it (confirmed by the G-01 fix's own math: a
   6-character worst case like `"12:45p"` already fits `kGutterWidth`).

---

## Detailed Findings

### Pillar 1: Copywriting (3/4)

- Now-line chip copy: `formatMinutesCompact(nowMinutes)` — matches the G-01 amendment exactly
  (`now_line.dart:101`).
- Now-line semantics label: `'Now — ${formatMinutes(nowMinutes)}'` — matches the Copywriting
  Contract table verbatim (`today_screen.dart:1366`).
- Hour-axis label: `formatHourLabel` produces `"9 AM"` / `"12 PM"`, no minutes — matches
  (`time_format.dart:91-95`, `hour_axis.dart:36`).
- `FreeTimeRow.until`/`FreeTimeRow.gap` — locked copy reused verbatim, unchanged
  (`free_time_row.dart:20-35`).
- **Finding (Top Fix #3):** `formatMinutesCompact` drops the AM suffix entirely
  (`time_format.dart:52`, `final suffix = isPm ? 'p' : ''`) — asymmetric, and now exposed on the
  app's highest-visibility element. See Top 3 above.
- Generic-label grep (`Submit`/`OK`/`Cancel`/generic error strings) turned up nothing in the
  touched files — no findings.

### Pillar 2: Visuals (1/4)

- **BLOCKER, confirmed by direct visual inspection of provided evidence, not inference:**
  cropped/zoomed regions of `evidence-26-09/g03-non-live-chip-renders.png` (PreStart, "7 AM"),
  `evidence-26-09/g03-work-live-full.png` (Active, "8 AM"), and
  `evidence-26-08/g02-work-full-after.png` (Active, a different day/time, same defect) all show
  the topmost hour-axis label with its upper half sheared off — glyphs read as bottom-half-only
  strokes (e.g. "AM" renders as a flat baseline stub, "7"/"8" loses its top hook). Same root cause
  and same fix as Top Fix #1.
- Z-order is otherwise correct and matches the contract: hour axis painted first (behind rows,
  `today_screen.dart:1304-1319`), non-live rows next, the live row last among Layer 1 (PD-10,
  `:1323-1340`), the now-line topmost (`:1360-1393`) — verified by reading the `Stack.children`
  list order, which Flutter paints back-to-front.
- G-01/G-03 chip-vs-card collisions: confirmed closed by re-reading the current
  `now_line.dart`/`today_screen.dart` source (gutter confinement + live-row `showChip` suppression)
  against the evidence screenshots — `g03-work-live-full.png` and `g03-work-title-after.png` both
  show the live row's title fully clear of any chip, with the 2dp rule crossing but not occluding.
- No icon-only-button-without-label issues: Complete/Skip both carry an icon *and* a text label
  *and* a `Tooltip`, everywhere they appear (`chunk_card.dart:619-650`, `live_row_card.dart:112-146`).

### Pillar 3: Color (4/4)

- `grep -rn "Colors\.\|#[0-9a-fA-F]\{3,8\}\|Color(0x"` across `lib/screens/today/` and the two
  named `chunk_card`/`swipeable_chunk_card` files returns only comments referencing the rule, zero
  actual literals.
- `colorScheme.primary` usage in the new surface is confined to exactly what the contract
  specifies: the now-line rule + chip fill (`now_line.dart:72,90`) and the pre-existing Complete
  button / progress-bar / left-bar uses. No new `primary` usage snuck in elsewhere in this phase's
  diff.
- Hour-axis hairline correctly uses `colorScheme.outlineVariant`, not `primary`
  (`hour_axis.dart:46`) — matches the deliberate "quiet infrastructure" framing.
- M3's `ColorScheme.fromSeed` algorithmically guarantees tonal separation between `primary` and
  `primaryContainer`/`surfaceContainer` at every seed (`theme_notifier.dart:56-82` confirms the
  app seeds per-mood, always through `fromSeed`, never a hand-picked pair) — so the now-line's
  contrast against card fills is structurally protected across all mood seeds, not something this
  phase could regress. **Not independently re-verified per-mood in a real browser this pass** —
  flagged `needs_human_review: true` if a specific mood ever looks wrong, but no evidence of a
  problem was found.
- The app has **no dark theme** at all (`grep -rn "darkTheme\|ThemeMode" lib/main.dart
  lib/providers/theme_notifier.dart` returns nothing) — the "check contrast in light and dark
  theme" ask in scope for this audit does not apply; this is a pre-existing project condition, not
  a Phase 26 gap.

### Pillar 4: Typography (3/4)

- Role usage in the new widgets matches the declared table exactly: `bodySmall` (hour-axis label,
  Full-tier time range, Compact break label), `bodyMedium` (Compact work title, free-row label),
  `labelSmall` + `w600` override (now-line chip, `now_line.dart:104-107`), `titleMedium`
  (Full-tier work title, long-break title) — no undeclared role introduced.
- Docked one point purely as a cross-reference to the Pillar 2 finding: the specific text instance
  that ships broken (the topmost/bottommost hour-axis label) is a `bodySmall` role render — the
  typography choice itself is correct, but the shipped result is illegible at that position. Not
  double-counted at full severity; the root cause and fix are the same single change described
  under Pillar 2 / Top Fix #1.

### Pillar 5: Spacing (4/4)

- `now_line.dart:85-88` — chip padding is `horizontal: 4, vertical: 4`, exactly the G-01 amendment
  (`8dp → 4dp` horizontal, vertical unchanged) — correctly shipped, not left at the pre-amendment
  value.
- `hour_axis.dart:29` / `timeline_row_tile.dart:58` — both use the `16dp` outer inset consistently,
  so the hour-axis column lines up with row content as specified.
- Micro-spacing tier (stroke/hairline/dash only) correctly scoped: `now_line.dart:72` uses `height:
  2` for the rule; `hour_axis.dart:45` uses `height: 1` for the hairline; `chunk_card.dart:141-146`
  uses `dashWidth: 2, dashGap: 2` for the Compact-tier break (tightened from `4/4`, matching the
  spec's stated pitch change) with `radius: 6` (down from the default `12`) — all match the spec's
  named exceptions exactly, nothing new added to the set.
- Compact-tier break vertical padding is `0` (`chunk_card.dart:149`, `vertical: 0`), centered via
  `Center` rather than pushed by padding — matches the spec's stated rationale precisely.
- No arbitrary (`[...px]`-style) spacing values found in the touched files.

### Pillar 6: Experience Design (3/4)

- All 5 `NowState`s (`PreStart`, `Active`, `Overdue`, `GapBeforeNext`, `DayComplete`) route through
  the same unconditional overlay — confirmed by reading `resolveNowState`
  (`now_state.dart:117-209`) against `today_screen.dart`'s single call site and the unconditional
  `Positioned` now-line block (no `if`/ternary gating it on state, `:1360-1393`, exactly as the
  code comment claims).
- Breaks correctly lose their tap target at every density: `ChunkCard.build`
  (`chunk_card.dart:96-116`) routes break chunks to `_buildBreak(context)`, which takes no `onTap`
  parameter at all — not merely `null`-ed, structurally absent. `SwipeableChunkCard` early-returns
  a plain (non-`Dismissible`) `ChunkCard` for any non-work chunk (`swipeable_chunk_card.dart:75-82`)
  — no swipe gesture either. Matches the contract's explicit behavior change.
- G-01 (chip-vs-`ChunkCard`) and G-03 (chip-vs-`LiveRowCard`) both carry dedicated, differently-
  named regression tests (`test/screens/today_screen_test.dart:943`, `:981`) — the postmortem's own
  "name the actual widget type" lesson was applied at least for this pair.
- **Docked:** the same clip defect that hits the hour axis (Pillar 2) is an untested latent risk
  against the now-line itself (Top Fix #2) — no regression test exercises `nowMinutes` at exactly
  `rangeStart`/`rangeEnd`, the one condition that reproduces it.
- **Also docked, minor:** the live row's documented "content-driven swell can exceed
  `kLiveRowReservedHeight` on a second-line title wrap" residual risk
  (`timeline_geometry.dart:66-68`) has an interaction-hazard corollary the code comments don't
  name: because the live row's `Positioned` is appended last within Layer 1 (painted on top) and
  carries no explicit `height` (natural size, `today_screen.dart:738-743`), an overflow beyond the
  reservation would let the live `Card` visually and hit-test-wise cover part of the row
  immediately below it — a real `Card` is an opaque hit target, unlike the `IgnorePointer`-wrapped
  overlays. This is the same accepted risk already carried forward from Phase 22/23 (not new to
  this phase, and the "known and accepted" list already covers the live-row swell generally) — but
  its interaction-hazard framing specifically was not what earlier rounds evaluated, so it is
  called out here for completeness rather than filed as a fresh defect.
- Confirmed no other widget in the new `Stack` can steal a tap meant for a card: both the hour
  axis and now-line layers are `IgnorePointer`-wrapped at their `Positioned` call sites
  (`today_screen.dart:1312`, `:1368`), and the zero-size placeholder `Positioned` for
  untimed chunks (`:721-727`) has `width: 0, height: 0` and is therefore never hit-testable.

---

## Files Audited

- `.planning/phases/26-the-day-has-a-shape/26-UI-SPEC.md` (including all four dated amendments)
- `.planning/phases/26-the-day-has-a-shape/26-CONTEXT.md`
- `.planning/phases/26-the-day-has-a-shape/26-UAT.md`
- `.planning/phases/26-the-day-has-a-shape/evidence-26-08/*.png` (8 images, cropped/zoomed for
  inspection)
- `.planning/phases/26-the-day-has-a-shape/evidence-26-09/*.png` (5 images, cropped/zoomed for
  inspection)
- `lib/screens/today/today_screen.dart`
- `lib/screens/today/timeline.dart`
- `lib/screens/today/now_state.dart`
- `lib/screens/today/timeline_geometry.dart`
- `lib/screens/today/widgets/now_line.dart`
- `lib/screens/today/widgets/hour_axis.dart`
- `lib/screens/today/widgets/timeline_row_tile.dart`
- `lib/screens/today/widgets/free_time_row.dart`
- `lib/screens/today/widgets/live_row_card.dart`
- `lib/screens/schedule/widgets/chunk_card.dart`
- `lib/screens/schedule/widgets/swipeable_chunk_card.dart`
- `lib/utils/time_format.dart`
- `lib/providers/theme_notifier.dart`
- `test/screens/today_screen_test.dart` (spot-checked for existing coverage of the two clip
  findings — confirmed absent)
- `flutter/packages/flutter/lib/src/widgets/basic.dart` (confirmed `Stack`'s default
  `clipBehavior: Clip.hardEdge`)
