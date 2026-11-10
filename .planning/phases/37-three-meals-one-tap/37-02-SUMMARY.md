---
phase: 37-three-meals-one-tap
plan: 02
status: complete
commits: [ff91750, 47d40ae]
requirements: [MEAL-01, MEAL-02, MEAL-03, MEAL-05]
---

# 37-02 Summary — the meals UI

**Shipped in `ff91750`, plus the device-found fix `47d40ae`.**

- **`lib/widgets/meals_editor.dart`:** the three rows. Each has an emoji and label, a switch, and
  Start/End time buttons, with an inline error under 10 minutes. The time picker is injectable
  (`MealTimePicker`) so tests can set a time without driving the dial. Onboarding and Settings
  share this widget, so they cannot drift apart.
- **Onboarding** has five beats now:
  - The Job beat's actions are **"Add & continue"** (renamed from "Add & finish") and "I don't
    have a fixed commitment". Both move on to the meals beat.
  - The new beat is **"When do you eat?"**. "Looks good" saves the job (if any) and the meals, then
    finishes onboarding.
  - Both saves are upserts, so a retry after a failed finish does not duplicate anything (asserted).
- **Settings → Meals** (`/settings/meals`, `lib/screens/settings/meals_screen.dart`):
  - It opens with the saved meals, or with the three defaults switched on when none are saved.
  - "Looks good" saves, returns to Settings, and says *"Meals saved. Tap ⟳ Re-check-in to see them
    on today."* (trap #4).
  - The Settings row's subtitle lists the saved meals, or says "Set breakfast, lunch and dinner".
- **Today:**
  - A meal is a fixed green card (`mealFill`: light `#A5D6A7`, dark `#2E5E35`) with
    `Icons.restaurant`, its name and its time.
  - It has no tap, no swipe and no Complete/Skip. That is enforced structurally: `SwipeableChunkCard`
    already routes any non-work chunk around `Dismissible`.
  - As the live row it shows no actions (`showActions: false`).
- **Commitments screen:** meals are filtered out. They are edited in Settings → Meals, where the
  floor is 10 minutes, not in the commitment form, where it is 25.
- **The existing settings test harness** (`settings_screen_calendar_row_test.dart`) now also
  provides `CommitmentsNotifier`. `SettingsScreen.build` watches it for the Meals row, and the
  test's comment saying SettingsNotifier alone was enough has been corrected.

## Defect found on the emulator, fixed in `47d40ae`

At 8:25, Today showed the 7:00–7:30 breakfast as **"RIGHT NOW"**.
- **Cause:** `resolveNowState` keeps an unresolved chunk current (Overdue) until the next chunk
  opens, and a meal can never be resolved (D-37-03).
- **Fix:** a meal whose window has ended now counts as settled.
- **Test:** `test/screens/now_state_meal_test.dart`. I watched it go RED against the unfixed code
  first. Its third case pins that an unresolved **work** chunk is still Overdue, so the fix did
  not widen.
- **Confirmed** on the emulator afterwards: Today shows "Up next: Exercise · Starts at 8:30 AM".

## Mutation log

| # | Mutant | Killed by |
|---|---|---|
| M10 | onboarding never calls `saveMeals` | 4 meals-beat tests |
| M11 | "Looks good" ignores validity | "a meal under 10 minutes blocks Looks good" |
| M12 | job id not reused across Back/forward | **survived.** The job is only saved at finish, so the id reuse was dead code. I deleted the code and replaced the test with one that discriminates |
| M12b | `_jobChosen` keeps the old job when "no fixed commitment" is chosen | "Back from meals, then no fixed commitment, saves no job" |
| M13 | the switch does not change `enabled` | "switching dinner off saves two" |
| M14 | a picked time is not applied | "editing lunch to 12:30-1:15…", "under 10 minutes…" |
| M15 | live meal row shows actions | "as the live row, lunch offers no actions at all" |
| M16 | a meal goes through `Dismissible` (break-only early return) | "before the day starts, a 7:00 breakfast…" |
| M17 | a meal is rendered as a work card | same |
| M18 | Settings → Meals ignores saved meals | 2 tests |
| M19 | Commitments screen shows meals | "meals do not appear on the Commitments screen" |
| M20 | light meal fill = the meeting orange | "meal fill is visibly apart from every other card" |
| M21 | dark meal fill ≈ the dark meeting fill (`#8D5A20`) | same, with reason `Brightness.dark: meal vs meeting`. The first attempt at M21 only failed to compile, which is a weak red, so I redid it with a real near-collision |

The test "tapping a meal opens nothing" is a regression guard. M16 and M17 carry the
discrimination for that behaviour.

## Not done, deliberately

- **The live row for a meal uses LiveRowCard's ordinary styling, not the green fill.** Restyling
  the live row was not asked for. It is noted in VERIFICATION as a possible owner preference.
- **`addEventToday` does not make a newly hand-added event yield to meals or meetings.** That is
  pre-existing behaviour for meetings too, and it is not this phase's scope.
