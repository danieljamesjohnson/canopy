# Phase 37 UAT — Three Meals, One Tap (owner, iPhone)

**Status:** awaiting the owner. **Who:** Dan, as an existing user, on his iPhone. **Build:** master
at or after `47d40ae`.

> ⚠️ **The iPhone build had not been installed when this was written.** The MacBook was asleep. If
> Settings has no **Meals** row, the build is not on the phone yet. Wake the Mac, then from
> danserver run:
> `ssh dans-macbook-air 'cd ~/CodeProjects/canopy && git pull -q --ff-only && rm -f ~/Library/Logs/canopy-ios-build.log; launchctl kickstart -p gui/501/com.canopy.iosbuild'`
> (the phone must be unlocked and connected).

## Steps

1. **Settings → Meals.** You should see three rows, all switched on:
   - 🍳 Breakfast 7:00–7:30 AM
   - 🥪 Lunch 12:00–1:00 PM
   - 🍝 Dinner 6:00–7:00 PM

   Change anything you like, or switch off a meal you skip, then tap **Looks good**.

   *Expect:* you are back on Settings, and the Meals row lists your meals.

2. **⟳ Re-check-in — MANDATORY, and do it before judging Today.** Today's schedule was built before
   the meals existed and is not rebuilt on its own (CLAUDE.md trap #4). Skipping this step will
   show a day with no meals and look like a failure.

3. **Today.** Check that:
   - [ ] Each meal is a **green** card with a fork-and-knife glyph. It is a different colour from
     Work (lavender) and from meetings (orange).
   - [ ] Breakfast appears at **7:00** even though the rest of the day starts at 8:00.
   - [ ] **Work stops at 12:00 and picks up again at 1:00.** There are no Work chunks or Work breaks
     under lunch.
   - [ ] A meal has **no Complete/Skip** and does nothing when tapped or swiped.
   - [ ] The "N of M Chunks" count does not include meals.
   - [ ] After a meal ends, it does not stay "RIGHT NOW". Today moves on to "Up next".
   - [ ] If one of your meetings overlaps a meal, **the meeting wins**. Lunch shrinks to the time
     that is left, or disappears if the meeting covers it all.

4. **Optional.** Settings → Meals again: the times you saved are what it shows. Switch a meal off,
   tap Looks good, and ⟳ Re-check-in. The meal should be gone from Today.

## Verdict

- [ ] Pass
- [ ] Fail. What you saw:
