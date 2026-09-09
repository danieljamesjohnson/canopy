---
id: SEED-007
status: unharvested
planted: 2026-09-09
planted_during: Phase 34 "Adding a Goal Feels Like Onboarding" (agent UAT round)
trigger_when: next time onboarding is opened for any reason, or if the owner ever reports a goal committing him to hours he did not choose
scope: small
---

# SEED-007: Onboarding still hides the 3.0 hrs/week it assigns

Phase 34 closed the silent-defaults hole on the **Goals screen** and left the identical hole open in
**onboarding**. Found by driving the built app during Phase 34's agent UAT round, then confirmed in
code — not inferred from a test.

## The fact

`GoalsNotifier._newDefaultGoal` (`lib/providers/goals_notifier.dart`) assigns every quick-created
goal:

```dart
goalTypeIndex: GoalType.timeTarget.index,
weeklyHourBudget: 3.0,
```

**Both** onboarding paths route through it — the preset chip via `addPresetGoal`
(`onboarding_screen.dart:188`) and the typed field via `quickAddGoals` (`:193`). And
`onboarding_screen.dart` **renders a budget nowhere**: grep it for `hrs/week` and the only hit is a
doc comment referencing `GoalCard`.

So a user who completes onboarding walks away with a set of goals each carrying a three-hour weekly
commitment that was never shown at the moment it was made.

## Why this is the "help" defect again, one screen over

On 2026-09-08 the bare quick-add field was deleted from the Goals screen because a goal typed as
"help" silently became a 3.0 hrs/week commitment. Phase 34's whole safety argument for ruling (a)
was that the default may exist as long as it is **visible** — which is why the created row shows
`3.0 hrs/week` and opens the form on tap.

Onboarding got the chips and the emoji from Phase 34. It did not get the visibility.

**The amended GOALADD-03 reads: "no add path creates a goal with attributes that are hidden from the
user."** Onboarding is an add path.

## Why it survived a 12/12 verification

Not an oversight by the verifier — a scoping artifact worth remembering, because it will recur:

- GOALADD-03 was **amended mid-phase** (2026-09-08), from "attributes the user did not choose" to
  "attributes that are hidden from the user", because ruling (a) made the original unsatisfiable.
- The plans' `must_haves` were written **before** that amendment and were scoped to the Goals screen.
- So verification checked the pre-amendment scope faithfully and passed. **A requirement amended
  after its must_haves are written does not retroactively widen them.** Next time a requirement
  changes mid-phase, re-read the must_haves against the new wording.

## Mitigating — read before treating this as urgent

1. **The value is not hidden permanently.** The Goals screen shows `3.0 hrs/week` on every row the
   moment onboarding ends, so it is discoverable within one screen.
2. **Onboarding is a one-time deliberate act** — the user is laying out a slate on purpose, not
   hitting a control absent-mindedly months later. That situational difference is a real part of
   what made the deleted quick-add field dangerous and does not apply here in the same way.

## Not accepted, not urgent — just unruled

The owner accepted Phase 34 with *"i'm satisfied with teh flow"* after running the **Goals screen**
flow he was asked to judge. He was never walked through this onboarding case, so his acceptance is
not a ruling on it. Surface it, do not assume it either way.

## The fix, if it is wanted

Small. Onboarding's added-chip display (`_AddedChipRow`) shows name + emoji only; it could carry the
budget the same way `GoalCard._secondaryLine` already does, or onboarding could route through
`GoalCard`. Either is cheap. The judgement call — whether onboarding *should* show budgets at all,
or whether that clutters a first-run screen whose job is momentum — is a taste question for the
owner, not a bug to fix unilaterally.

## Related

- Phase 34 (`34-UAT.md`, the agent round's Finding B; `34-VERIFICATION.md`)
- Phase 33's one-add-path fix, commit `1587fff` — the original "help" report
