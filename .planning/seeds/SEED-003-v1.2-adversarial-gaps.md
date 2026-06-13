---
id: SEED-003
status: dormant
planted: 2026-06-13
planted_during: v1.2 "Make It Usable" (post-milestone adversarial audit)
trigger_when: planning the next milestone — review before defining requirements
scope: small-medium
---

# SEED-003: v1.2 adversarial-audit gaps (3 requirements landed superficially)

After v1.2 shipped (11/11 requirements "met", 209 tests green, tagged), an adversarial agent re-read the actual `lib/` code (not the SUMMARY/VERIFICATION claims) and found **3 of the 11 requirements were only superficially met**, plus one verification-integrity problem. v1.2 is genuinely more usable than the pre-v1.2 app — but "Make It Usable" oversold these three. Capture them as candidate requirements for the next milestone.

## Why This Matters

These are the same failure shape SEED-001 warned about: a checkmark verifies code-conformance to a must-have, not whether the behavior delivers the requirement's intent. Two of the three gaps are in the *headline* promises of v1.2 (Home as the "what am I doing now" place; the goal sheet fitting the viewport). The GOALFORM test issue means a requirement passed CI without testing the real claim — a process smell worth fixing, not just a feature gap.

## When to Surface

**Trigger:** When planning the next milestone / running `/gsd-new-milestone`. Confirm against a dogfood session first (especially #1 and #2 — both are "open the app and look" checks). Confirmed items become requirements.

## Scope Estimate

**Small-medium** — mostly localized logic + one real test, no re-architecture. Likely one "engine + landing honesty" phase.

## The Findings

### 1. Home "Now" is not time-anchored (NAV-02 — superficial)
`home_screen.dart` has **zero `DateTime.now()`**. "Now" = `unresolvedWork.first` and "Next" = `unresolvedWork[1]` (`home_screen.dart:110-111`). At 6pm with nothing checked off, the 8am chunk still shows as "Now." The real wall-clock anchor (`NowMarker`) lives only on the **Schedule** screen (`schedule_screen.dart:115-145`), not on the new landing screen. So the headline NAV-02 promise — one obvious "what am I doing now" place — is delivered by a label, not by logic.
**Candidate requirement:** Home's "Now" reflects the chunk whose clock-time window contains the current time (reuse the Schedule NowMarker logic), with a distinct "Next." Falls back gracefully when the day hasn't started / is over.

### 2. Goal sheet "fits the viewport" is unproven and likely false (GOALFORM-01 — superficial + test cheats)
The add/edit sheet opens at `initialChildSize: 0.6` (`goals_screen.dart:34,52`) as a `SingleChildScrollView` (`goal_form_sheet.dart:141`) — it *can* scroll. The only "fits without scrolling" test (`goal_form_priority_test.dart:122`) **resizes the surface to 800×1200 and pumps the form outside the 60%-height modal** — it doesn't test the real presentation. Outcome goals (3-line description + date ListTile + archive button) almost certainly push Save below the 60% fold.
**Candidate requirement:** A test that asserts Priority + Save are visible at the actual opened modal height on a standard phone, for every goal type — and raise `initialChildSize` / restructure if outcome goals overflow.

### 3. Priority count-effect is time-target-only (PRIORITY-01 — superficial)
Raising priority yields more/earlier chunks **only for time-target goals** (Step 4 composite score, `schedule_generator.dart:315-338`). **Habits (Step 2) and outcomes (Step 3) always get exactly 1 chunk** regardless of priority — priority only reorders them. The requirement says "a goal's priority" (any goal); the count effect covers 1 of 3 goal types.
**Plus — two divergent priority models:** drag-reorder writes a *continuous* 0.75→0.25 spread (`goals_notifier.dart:105`) while the form writes discrete 0.25/0.5/0.75 buckets. A mid-list dragged goal lands at ~0.5 → shows **no priority chip**, so GOALS-02's visual distinctness silently disappears for anything not top/bottom of the list.
**Candidate requirements:** (a) priority influences chunk count (or an equivalent observable allocation) for habits and outcomes, not just ordering; (b) reconcile the drag-continuous vs form-discrete priority models so the visual chip language stays meaningful after a drag.

## Minor / watch items (not requirements yet)
- Mood 4 (#7AAF6A) luminance is 0.358 vs the 0.35 dark-text cutoff — correct side, 0.008 margin. Confirm AA ratio by eye during dogfood (CHECKIN-01).
- `schedule_screen.dart:21-27` re-hardcodes the mood palette instead of reading `ThemeNotifier.moodSeeds` — values match today, future drift risk.

## Evidence
Full adversarial audit was run 2026-06-13 against the tagged v1.2 code; suite was 209/209 green and `flutter analyze` clean at the time, which is exactly why these semantic/test-integrity gaps matter — they passed automated verification.
