# Phase 17 — UI Review

**Audited:** 2026-06-14
**Baseline:** 17-UI-SPEC.md (approved design contract)
**Screenshots:** Not captured — Flutter mobile app, no accessible web dev server

---

## Pillar Scores

| Pillar | Score | Key Finding |
|--------|-------|-------------|
| 1. Copywriting | 4/4 | All spec-mandated strings match exactly; GapBeforeNext copy is calm and on-tone |
| 2. Visuals | 4/4 | Exhaustive five-state switch; correct visual hierarchy in all states; no accent leak |
| 3. Color | 4/4 | Accent (primary) absent from all new inline states; onSurfaceVariant used correctly throughout |
| 4. Typography | 4/4 | All spec roles applied correctly; no new roles introduced |
| 5. Spacing | 3/4 | Heading-to-body gap is 4px (xs) in all three inline states; spec calls for 24px (lg) |
| 6. Experience Design | 4/4 | Five states covered; timer lifecycle complete with mounted guard and pause/resume |

**Overall: 23/24**

---

## Top 3 Priority Fixes

1. **Inline state heading-to-body gap is xs (4px) not lg (24px)** — The spec's Spacing Scale table lists `lg = 24px` as the value for "between state heading and body" on pre-start and day-complete states. All three inline builders (`_buildPreStartContent`, `_buildGapBeforeNextContent`, `_buildDayCompleteContent`) use `SizedBox(height: 4)`. Replace with `SizedBox(height: 24)` in all three. File: `lib/screens/home/home_screen.dart` lines 552, 586, 617.

2. **GapBeforeNext heading/body phrasing is mildly redundant** — Heading reads "Up next"; body reads "Next up at [TIME]". The echo of "next/up" across heading and body is a minor copy rhythm issue. Consider "Up next" / "Starts at [TIME]" for cleaner differentiation that matches the pre-start pattern ("Your day starts at…"). Not a contract violation — the fifth state has no spec copy — but worth aligning to the spec's plain-statement style. File: `lib/screens/home/home_screen.dart` lines 581, 589.

3. **`SizedBox(height: 2)` in the Next row subtitle gap is off the declared spacing scale** — The spec's spacing scale has no 2px token; the smallest defined value is xs = 4px. The `SizedBox(height: 2)` at line 426 (between Next row goal name and subtitle) is not a new addition in Phase 17, but it is visible in the "Next" row this phase gates. Change to `SizedBox(height: 4)` to stay on scale. File: `lib/screens/home/home_screen.dart` line 426.

---

## Detailed Findings

### Pillar 1: Copywriting (4/4)

All spec-required strings are present verbatim:

| Spec String | File:Line | Match |
|-------------|-----------|-------|
| "Your day starts at [TIME]" | home_screen.dart:547 | PASS |
| "That's a wrap" | home_screen.dart:612 | PASS |
| "You've reached the end of today's schedule." | home_screen.dart:619 | PASS |
| "No schedule yet" | home_screen.dart:648 | PASS |
| "Start your day" | home_screen.dart:665 | PASS |
| "See full schedule" | home_screen.dart:483 | PASS |
| "Now" section label | home_screen.dart:373 | PASS |
| "Next" section label | home_screen.dart:386 | PASS |

Locked copy from previous phases is unchanged.

**GapBeforeNext (fifth state, not in UI-SPEC — audited for tone consistency):**
- Heading: "Up next" — calm, no emoji, no exclamation. Consistent with spec tone.
- Body (with time): "Next up at [TIME]" — factual, matches formatMinutes() convention.
- Body (null fallback): "Coming up next" — acceptable fallback when displayStartMinutes is null.

Minor polish only (see Priority Fix 2): heading and body echo "next/up" redundantly. No blocker.

No generic labels ("OK", "Submit", "Cancel") detected in the modified code.

### Pillar 2: Visuals (4/4)

Visual hierarchy in all five states is consistent:

- Section label (`labelMedium`, `onSurfaceVariant`, `letterSpacing: 0.8`) — always "Now"
- State heading (`titleMedium w600`) — weight differentiation from body is clear
- State body (`bodyMedium`, `onSurfaceVariant`) — recedes correctly below heading

The `_buildNowContent` switch at line 512 is exhaustive across all five variants. The `GapBeforeNext` state mirrors the pre-start/day-complete Padding/Column/Text structure identically, with no accent color or card widget — consistent visual treatment.

`ActiveChunkCard` is passed unchanged for Active and Overdue states, as specified.

The "Next" section is correctly hidden for PreStart, GapBeforeNext, and DayComplete states (line 382 gates on `nextChunk != null`, which is null for those states).

No icon-only buttons in the Now zone. The `refresh` AppBar icon at line 350 has a `tooltip: 'Re-check-in'` — accessibility handled.

The `BreathingPulseCta` in the empty state provides a focal point. Existing, not modified.

### Pillar 3: Color (4/4)

`colorScheme.primary` appears in this file only in `BreathingPulseCta.build()` (line 773) — a pre-existing decorative glow, not a new addition from this phase. The glow uses `primary.withValues(alpha: 0.25)`, not full-opacity accent.

All three new inline states use:
- Headings: no explicit color override (inherits `onSurface` via `titleMedium` default) — correct
- Bodies: `theme.colorScheme.onSurfaceVariant` — matches spec exactly

No hardcoded hex colors in the Phase 17 code additions. No `colorScheme.error` touched (no skip/destructive actions in this phase). No accent splash on day-complete state — the spec's "calm, honest, no party banner" requirement is met.

"Now" badge accent color remains in `active_chunk_card.dart` (not modified in this phase) — out of scope and unchanged.

### Pillar 4: Typography (4/4)

Typography roles used in Phase 17 additions:

| Role | Token | Applied At |
|------|-------|------------|
| Section label | `labelMedium` + `onSurfaceVariant` + `letterSpacing: 0.8` | Lines 374, 387 |
| State heading | `titleMedium` + `FontWeight.w600` | Lines 548–549, 582–583, 613–614 |
| State body | `bodyMedium` + `onSurfaceVariant` | Lines 555–556, 591–592, 620–621 |
| Next row title | `titleMedium` + `FontWeight.w600` | Lines 420–422 |
| Next row subtitle | `bodySmall` + `onSurfaceVariant` | Lines 429–434 |
| Next row clock-time | `bodySmall` + `onSurfaceVariant` | Lines 450–451 |

All match the spec's Typography table. No new roles introduced. `titleLarge` for "No schedule yet" (line 649) is pre-existing empty-state copy, not part of Phase 17's scope.

`fontSize: 32` at line 465 (mood emoji) is a pre-existing hardcoded value. Not part of this phase's typography contract. Minor, pre-existing.

### Pillar 5: Spacing (3/4)

**WARNING — Heading-to-body gap: xs (4px) vs. spec lg (24px)**

All three inline state builders use `SizedBox(height: 4)` between heading and body:
- `_buildPreStartContent`: line 552
- `_buildGapBeforeNextContent`: line 586
- `_buildDayCompleteContent`: line 617

The spec's Spacing Scale table lists `lg = 24px` under "between state heading and body." A 4px gap compresses the pre-start and day-complete states significantly compared to spec intent. Whether this is a spec literal or a recommendation for breathing room is debatable — but the spec is explicit.

**Padding on inline states** — `EdgeInsets.symmetric(horizontal: 16, vertical: 8)` — matches spec exactly (md horizontal, sm vertical, same as "All done today!" predecessor).

**"Now" label top padding** — `EdgeInsets.fromLTRB(16, 16, 16, 4)` — 16px top, 4px bottom before content. Top is md, bottom is xs. Reasonable; spec does not explicitly mandate the label's own vertical padding value.

**Off-scale values (pre-existing, visible in phase output):**
- `SizedBox(height: 2)` at line 426 (Next row subtitle gap) — below xs minimum
- `SizedBox(width: 12)` at line 466 (mood emoji to text gap) — not on 4/8/16/24 scale

These two are pre-existing; they do not block this phase but are now visible in the audited output.

### Pillar 6: Experience Design (4/4)

**State coverage:** Five states, fully covered with exhaustive switch (compiler-enforced by sealed class). No fall-through or unhandled case possible.

**GapBeforeNext as additive improvement:** The fifth state correctly prevents the false day-complete condition when a user finishes a chunk early with future unresolved work remaining. This is an honest, additive extension to the UI-SPEC's four-state model. It is documented in the sealed class doc comment (lines 55–63) and in the SUMMARY. Not a deviation to penalize.

**Timer lifecycle:**
- `initState`: timer started, observer registered — line 250–251
- `dispose`: timer cancelled, observer removed — lines 276–278
- `didChangeAppLifecycleState`: pause on `paused`, restart on `resumed` — lines 266–271
- Mounted guard in timer callback — line 261
- T-17-01 threat fully mitigated

**Empty state:** Heading, body, and CTA all present with correct locked copy.

**No loading state needed:** Schedule data is synchronous from Provider watch. Correct to omit.

**No error boundary:** Pre-existing pattern; `_checkReviewWindow` has a catch block (line 308) that silently skips the banner on error. Not a Phase 17 regression.

**Test coverage:** 7 pure unit tests + 6 widget tests in `home_screen_now_state_test.dart`, all passed. NAV-02 coverage in `active_chunk_card_test.dart` migrated and green. Full suite: 239 tests passed.

---

## GapBeforeNext — Fifth State Assessment

The GapBeforeNext state was added during code review to address a gap in the spec's four-state model: when a user completes a chunk early and the next chunk's window has not yet opened, the original four states would yield DayComplete (dishonest) or Overdue (inaccurate — the current chunk was resolved, not overdue). GapBeforeNext correctly identifies this as an in-progress day with future work pending.

Visual treatment: identical to pre-start and day-complete — no card, no accent, calm inline text. Consistent with spec tone. The heading/body copy is slightly redundant (see Priority Fix 2) but not a blocker.

This is a documented, sensible extension. No penalty applied.

---

## Registry Safety

No shadcn or third-party component registries. Flutter pub.dev only. No new packages added in this phase (dart:async is stdlib). Registry audit: not applicable.

---

## Files Audited

- `lib/screens/home/home_screen.dart` — primary implementation file (full read)
- `.planning/phases/17-time-anchored-home/17-UI-SPEC.md` — design contract baseline
- `.planning/phases/17-time-anchored-home/17-01-SUMMARY.md` — execution summary
- `.planning/phases/17-time-anchored-home/17-01-PLAN.md` — plan intent
- `.planning/phases/17-time-anchored-home/17-CONTEXT.md` — phase context
