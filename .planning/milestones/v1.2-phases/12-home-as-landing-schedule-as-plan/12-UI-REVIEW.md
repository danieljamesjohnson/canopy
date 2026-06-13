---
phase: 12-home-as-landing-schedule-as-plan
reviewed: 2026-06-12
audit_type: code-only (no Playwright in session)
overall_score: 18/24
pillars:
  copywriting: 3
  visuals: 3
  color: 3
  typography: 2
  spacing: 3
  experience_design: 4
status: reviewed
---

# Phase 12: Home as Landing, Schedule as Plan — UI Audit

**Overall Score:** 18/24 (code-only audit, no screenshots)

## Pillar Scores

| Pillar | Score | Key Finding |
|--------|-------|-------------|
| 1. Copywriting | 3/4 | All contract strings present; Next chunk row omits clock-time range per spec |
| 2. Visuals | 3/4 | Clear hierarchy; ScheduleScreen AppBar uses hardcoded mood color palette (pre-existing) |
| 3. Color | 3/4 | New widgets fully token-compliant; pre-existing hardcoded colors in schedule_screen not cleaned up |
| 4. Typography | 2/4 | Raw TextStyle with hardcoded fontSize/fontWeight bypassing Material 3 roles; Next title uses w700 vs spec w600 |
| 5. Spacing | 3/4 | ChunkCard work-variant uses vertical: 12dp (off 8pt scale); SizedBox(height: 2) gaps below xs=4dp |
| 6. Experience Design | 4/4 | All states handled; tooltips on action buttons; ExcludeSemantics on NowMarker; animation guard retained |

## Top Priority Fixes

1. **WARNING — Next chunk compact row shows duration only ("25 min"), not the clock-time range the spec requires.** The "Next" section fails its job of telling the user when the next chunk starts, undercutting the "schedule as plan" goal. Fix in `home_screen.dart`: when `nextChunk.displayStartMinutes != null`, render `formatTimeRange(...)` like ActiveChunkCard does.

2. **WARNING — "All done today!" and Next chunk title use raw TextStyle with hardcoded sizes/weights instead of Material 3 TextTheme roles.** Next title uses `FontWeight.bold` (w700) where spec mandates w600, appearing heavier than the ActiveChunkCard goal name on the same screen. Fix in `home_screen.dart`: use `textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)`.

3. **WARNING — Schedule empty-state heading uses `titleMedium` (16sp) instead of spec-mandated `titleLarge` (22sp).** Fix in `schedule_screen.dart`: change `textTheme.titleMedium` to `textTheme.titleLarge`.

## Notes

- New widgets (ActiveChunkCard, NowMarker, time_format) are fully token-compliant — zero hardcoded `Colors.*`.
- Hover overlay fully removed; always-visible Complete/Skip with tooltips confirmed.
- Pre-existing hardcoded mood colors / `Colors.amber` / `Colors.white` in `schedule_screen.dart` predate this phase; flagged but out of phase scope.
- Registry audit: not applicable (Flutter, no third-party component registries).

*Audit is advisory (non-blocking). Top-3 warnings addressed in a follow-up polish commit (see 12-REVIEW-FIX.md / git log).*
