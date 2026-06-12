---
id: SEED-001
status: dormant
planted: 2026-06-12
planted_during: v1.1 "Actually Daily" (post-milestone audit)
trigger_when: planning the next milestone (v1.2) — especially after the developer has dogfooded Canopy for several real mornings
scope: medium
---

# SEED-001: Adversarial engine + product critique (validate by dogfooding, then fix)

Adversarial read of the v1.1 codebase against PROJECT.md's stated goal — *"a usable daily schedule every morning that reflects your real goals and how you actually feel."* These are design/behavior concerns found by reading the engine, not bugs that fail tests. **The developer will dogfood first to confirm which are real friction vs. acceptable.** Treat the dogfood log as the deciding evidence; this seed is the hypothesis list.

## Why This Matters

v1.1 closed at 21/21 requirements but PROJECT.md "Validated" is still **None**. Every checkmark verifies code-conformance to spec, not whether the spec produces a day a human wants to live. The same "complete on paper and in code" state preceded v1.0 being found broken. The engine defaults and ordering below encode product decisions nobody has *felt* yet — they're the most likely sources of lived friction once dogfooding starts.

## When to Surface

**Trigger:** When planning v1.2 / the next milestone, or immediately if dogfooding surfaces any of these as real friction. Cross-reference against the dogfood log before committing engine changes — confirmed items become requirements, unconfirmed ones may be working as intended.

## Scope Estimate

**Medium** — a focused "engine honesty + legibility" phase or two. Mostly logic changes in `schedule_generator.dart` plus some UI surfacing; no re-architecture.

## The Findings

### 1. Default day is a diminished day
`lighterDay` defaults to **true** (`checkin_screen.dart:41` → `schedule_notifier.dart:101` → `schedule_generator.dart:197`). The reduced-capacity "lighter day" is the out-of-box state, so every morning is scheduled one mood-tier below real capacity unless the user actively flips the toggle off. ENGINE-05 sells the toggle as "measurably reduces," but the reduced tier is the resting state.
**Question:** Should the default be `false` (full capacity) with the toggle opting *into* a lighter day?

### 2. Low-mood days zero out time-target goals
Time-target goals (explicitly "relationships, wellness" per PROJECT.md) are scheduled **mood 3–5 only** (`schedule_generator.dart:307`). On a low day (mood 1–2), family/wellness time gets zero chunks — the app strips the restorative goals exactly when the user most needs them.
**Consider:** a minimal time-target floor that survives low-mood days.

### 3. Habits monopolize the scarce cap
Step 2 (habits) runs before outcomes and time-targets and consumes the cap first (`schedule_generator.dart:234-255`). At mood 1 the cap is 4; a handful of habits can eat the entire low-mood budget, leaving nothing for higher-stakes goals. First-come ordering is acting as de-facto prioritization.
**Consider:** interleaving across types, or per-type reservation of the cap.

### 4. Priority is nearly inert
Despite ENGINE-06 / REVIEW-02 selling priority as something that "demonstrably changes" generation, `priorityWeight` is only a **tiebreaker** for time-target ordering (`schedule_generator.dart:316`) and one term in outcome `urgencyScore` (`schedule_generator.dart:268`). It never changes how many chunks a goal gets, never promotes a high-priority time-target ahead of habits. High vs. normal priority produce identical schedules unless competing for the literal last slot — so the quarterly-review payoff is mechanically marginal.
**Consider:** letting priority influence chunk *counts* / cross-type ordering, not just within-type ties.

### 5. Synthetic times + silent overflow drop
Discretionary chunks get fabricated start times in a hardcoded 8am–10pm window (`schedule_generator.dart:456`); chunks that don't fit are `removeWhere`'d silently (`schedule_generator.dart:536`). The "leave unscheduled for a calmer day" policy is implemented as **silent deletion** — a busy commitment day can swallow goals with no UI signal, and the user can't distinguish "light day" from "engine dropped 3 things."
**Consider:** surfacing dropped/unscheduled goals in the UI.

### 6. Streaks built for a usage history that doesn't exist yet
`computeStreak` breaks the streak on any due day with no log entry (`schedule_generator.dart:93`). Until consistent daily usage is established, streaks will read 0 or 1 indefinitely — the feature is ahead of the behavior that feeds it. Revisit after dogfooding produces real history.

### 7. Process / validation gap (meta)
PROJECT.md "Validated: None yet." The v1.1 audit labels the milestone "complete on paper and in code" — the same epistemic state that preceded v1.0 being found broken. All daily-loop behaviors are deferred to on-device UAT that hasn't happened. The audit also found its own requirement checkboxes were stale, i.e. the tracking system isn't a reliable mirror of reality.
**Highest-value next step:** dogfood 5 consecutive real mornings on iOS, log lived friction, and let *that* drive the next REQUIREMENTS.md — not another paper audit.

## Breadcrumbs

- `lib/services/schedule_generator.dart` — generate() defaults (:197), habit step (:234-255), outcome urgency (:268), time-target mood gate (:307), priority tiebreaker (:316), synthetic times (:456), silent drop (:536), streak (:64-100)
- `lib/screens/schedule/checkin_screen.dart:41` — `_lighterDay = true` default
- `lib/providers/schedule_notifier.dart:101` — `lighterDay` param default
- `.planning/PROJECT.md` — Core Value, "Validated: None yet"
- `.planning/v1.1-MILESTONE-AUDIT.md` — "complete on paper and in code", stale-checkbox note
- `.planning/REQUIREMENTS.md` — ENGINE-05/06, REVIEW-02 claims

## Notes

Captured via /gsd-capture after an adversarial review. The findings are hypotheses ranked by likelihood of being felt; the dogfood log is the arbiter.
