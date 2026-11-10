---
phase: 37-three-meals-one-tap
status: human_needed
verified: 2026-11-10
gaps: []
tests: 1094 passing (baseline 1055), flutter analyze clean
---

# Phase 37 Verification — Three Meals, One Tap

**Verdict:** the code delivers what the phase promised. Every requirement is backed by a test that
was mutation-proven, and by the emulator. What remains is the owner's own UAT on his iPhone
(`37-UAT.md`). That UAT is the gate: this phase is **not** marked complete on his behalf.

## Requirements

| Req | Truth | Evidence |
|---|---|---|
| MEAL-01 | Onboarding has a meals beat, and one tap saves the three defaults | `onboarding_flow_test.dart` "one tap on Looks good saves exactly the three default meals…" (M10); emulator `media/07b`, `07c`, `07d` |
| MEAL-02 | Each meal can be edited or switched off before saving | "editing lunch to 12:30-1:15…" (M14), "switching dinner off saves two" (M13), "under 10 minutes blocks…" (M11) |
| MEAL-03 | A meal is one solid block every day, with no breaks inside, in its own fixed colour | `schedule_generator_meals_test.dart` "a meal is one solid block" (M1); `chunk_card_meal_test.dart` (M20, M21); emulator `04`, `05a`, `06` |
| MEAL-04 | Work yields to a meal the way it yields to a meeting | "Work 9-5 with lunch 12-1…" (M3), plus the sync path in `schedule_notifier_apply_calendar_sync_test.dart`; emulator `05a` (Work ends 12:00) and `05b` (Work resumes 1:00) |
| MEAL-05 | Existing users get Settings → Meals | `meals_screen_test.dart` (M18); emulator `01`–`03`, driven on the owner's own pre-37 data snapshot |

## Owner rulings (D-37-01..07): how each is honoured

- **The meeting wins.** A meal is carved by `subtractWindows`; pieces under 10 minutes are dropped;
  a fully covered meal is absent. This holds at check-in and on a calendar sync after check-in.
- **Same times every day.** Meal blocks are always saved with `daysOfWeek` 1–7.
- **Meals are not tracked.** This is structural rather than a flag:
  - `ChunkType.meal` is excluded from every count that filters on `ChunkType.work`.
  - Check-in said "14 chunks" with three meals on the day, and Today read "0 of 14 Chunks".
  - A meal has no swipe and no Complete/Skip, including as the live row.
  - A past meal is never Overdue (the fix in `47d40ae`).
- **The 10-minute minimum** is enforced in the editor and in the engine.
- **Existing users get Settings → Meals only.** There is no prompt card.
- **Snacks are not built.**

## The riskiest assumption: 7:00 breakfast vs the 08:00 day start

- **Test:** the breakfast chunk is first, at 7:00, and the first goal chunk is still at 8:00.
- **Emulator:** `media/04-today-breakfast-before-8.png` shows the timeline starting at 7 AM with
  the green Breakfast card, before 8 AM.

## Found on device, not by the suite

At 8:25, a 7:00–7:30 breakfast showed as **RIGHT NOW**. The cause was in `resolveNowState`, and it
is fixed and regression-tested in `47d40ae` (details in 37-02-SUMMARY). This is the sixth time on
this project that a screen contradicted a green suite. This time it was caught by the agent's own
emulator pass rather than by the owner.

## Upgrade path (old data still loads)

The new APK was installed **over** the emulator's existing pre-37 Hive data, which is a snapshot
of the owner's phone. It launched cleanly, Settings → Meals saved, and check-in produced the
expected day. The unit-level equivalent is `commitment_block_kind_test.dart` (M6).

## Device status

- **Emulator (canopy_api35):** all checked, 12 screenshots in `media/`, each one opened and read.
  The emulator's original app data was backed up and then restored afterwards.
- **iPhone:** the build is **not installed yet**. `dans-macbook-air` went offline on the tailnet a
  few minutes before the build was due (tailscale: "offline, last seen 9m ago"), most likely asleep.
  This is a physical state and was not retried in a loop. See STATE.md for the one command to run
  once the Mac is awake.

## Possible owner preferences (not defects, not built)

- The **live row** for a meal uses the ordinary live-row styling, not the green meal fill.
- A meal's **live-row kicker** reads "RIGHT NOW · 12:00 PM", not something meal-specific.
- **Settings → Meals does not rebuild today on save.** It says to ⟳ Re-check-in, per trap #4. An
  automatic apply, like the calendar sync's entry 16, would be a new behaviour for the owner to
  ask for.
