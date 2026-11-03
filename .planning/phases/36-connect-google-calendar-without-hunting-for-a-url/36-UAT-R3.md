# Phase 36 UAT, Round 3 — Device Re-Verification of the 2026-11-02 Findings

**Owner:** Dan
**Prepared:** 2026-11-02 (plan 36-17)
**Where this runs:** your iPhone, with the build installed for you. **There is no web address anywhere in
this document**, and nothing below should ever ask you to type one. See "Limits" at the end for why that
rule exists.

---

## Why there is a round three

On 2026-11-02 you ran round two on your real iPhone. It closed one defect on hardware and found four more:

- **WINDOWS entry 7** (ticks never reaching the device) **closed** — only the calendar you ticked, `spunkl`,
  imported.
- **Entry 10** (the "events were not imported" notice) **reopened** — your screenshot of Settings → Calendars
  showed no notice at all, because it was only held in memory and vanished whenever you left the screen.
- **Entry 11** (stale imported commitments are never removed) was **seen on real data** — a "Bi-Weekly One on
  One" from your Home calendar, on 2026-11-12, was still on your schedule after you switched to `spunkl`.
- **Entries 12, 13, 14** were found during the sitting: the Calendars screen showed "Allow calendar access" on
  every re-open (you took it for a sync button), "Sync now" gave no feedback at all, and one tick appeared to
  land on Family instead of `spunkl`.

All five now have a code fix that is proven on danserver. **None of them is closed.** Each is a claim about
what your phone does, and the register's own history says what that is worth: entry 10 was marked fixed on a
test that was true and irrelevant, and your screenshot reopened it. So every one of these stays open until you
have seen it work. This document is how you do that.

### What you will notice first on the Calendars screen

- Your calendar list is simply **there** when you open Settings → Calendars. You should no longer see
  "Allow calendar access" once access has been granted.
- The **"This device" list now sits ABOVE the Google section**, where it used to be below. The reason: when
  Google is connected, its list loads over the network a moment after the device list is already on screen,
  and the device rows used to jump down under your finger when it arrived. With the device list first, rows
  that are already showing cannot move. If you dislike the new order, say so and it goes back — it is a
  two-line change.
- **The build is a profile build, installed on your phone by the agent.** There is no Xcode step and no
  Terminal step for you. All you need to do is have the phone **unlocked and connected** (cable or the
  paired wireless connection) when the agent installs it.

---

## Step 0 — MANDATORY. Do this first. Judge nothing until it is finished.

This is not optional. This project's `CLAUDE.md` calls it trap number four, with a date attached: on
**2026-08-21** a UAT skipped this step, judged a schedule that had been generated before the fix, reported a
false failure, and the real defect survived three more days until it was reported again on 2026-08-24. The
mechanism: Today's schedule is read straight from storage when the app opens, and the generator only runs at
check-in. **An already-generated day is never regenerated on load.** If you look at Today before step 5, you
are looking at data the new code never touched.

Five steps, in this order:

1. **Install.** The agent builds and installs for you. For the record, as `CLAUDE.md` states it today: an
   agent can drive a real device build only through `tools/ios-build-agent.sh` (a plain ssh build fails
   signing), by starting the installed launch agent on the Mac; the script builds in **profile** mode
   (because on iOS 14 and later a debug Flutter app refuses to start unless a debugger is attached) and then
   installs to the phone. **The phone must be unlocked and connected for the install step**; if it is only
   "paired", the build succeeds and the install fails with "Connection reset by peer" — a physical state, not
   a code problem. You do nothing here except keep the phone awake and unlocked until you are told it is on.
2. Open **Settings → Calendars** and **look at the screen BEFORE you tap anything.** Note what is there
   (the list, or an "Allow calendar access" card, or something else). This is item S1's first observation.
3. **Tick exactly the calendars you want scheduled around.** For this sitting that means `spunkl`. Leave
   Home and Family **unticked** unless you actually want them scheduled around.
4. Tap **"Sync now"**.
5. Go to **Today** and tap **⟳ Re-check-in**.

**Judge nothing about your schedule before step 5 is done.** That is the binding rule, and the 2026-08-21
round trip above is exactly what it prevents.

### What you will see after the first sync, and it is not a bug

The first sync on this build may **remove** imported commitments that came from calendars you no longer have
ticked. That is entry 11's fix working, not data loss. Concretely, if Home is unticked, the stale Home
commitment "Bi-Weekly One on One" on 2026-11-12 should be gone — that is item S4(a).

---

## The five items this round must settle

### S1 — WINDOWS entry 12: is your calendar list simply there?

With your ticks in place, do each of these and watch for the same thing every time:

1. Go back out of Settings → Calendars, then open it again.
2. Switch to Today and back to Settings → Calendars.
3. **Force-quit the app** (swipe it away in the app switcher), reopen it, and go to Settings → Calendars.

Each time: you should see **your calendar list with your ticks** — never the "Allow calendar access" card,
and **no iOS permission pop-up at any point**. Record anything that differs.

### S2 — WINDOWS entry 13: does "Sync now" tell you it did something?

Tap **"Sync now"** and watch the button and the bottom of the screen. What should happen: the button greys
out with a small spinner while it works, then a message appears at the bottom of the screen that reads
**"Synced just now — N commitments imported"** (N is a number; "1 commitment" for one).

Do not rely on this description. **Say what you saw, in your own words** — including if it was too quick to
see, or you saw nothing.

### S3 — WINDOWS entry 10: did the "not imported" notice show up without being pointed out?

This is a perceptual question, so it is asked before pointing you at anything. After Step 0's sync, **leave
Settings → Calendars and come back**, and open it as if you had not been told anything. **Before you hunt:**
does anything on the screen tell you that some events were not imported? Write down what you noticed first.

Then:

- **Leave and re-enter again**, and **force-quit and reopen** the app. Is whatever you saw **still there**
  each time? (The original defect was that it vanished on every re-open.)
- **Tap it.** Does it name the all-day entries and say they are not imported automatically?

If there is nothing to see because none of your ticked calendars has an all-day event in the next two
weeks, this item cannot be judged yet: in the Calendar app, add a throwaway all-day event on a ticked
calendar for a date in the next two weeks, come back, tap **Sync now**, and then do the above. Say that you
had to.

### S4 — WINDOWS entry 11: does a sync remove what should be gone?

**(a) The stale one-on-one.** Open the **Commitments** screen — from **Goals**, tap the **⋮ menu at the top
right** and choose **"Commitment blocks"**. Confirm that **"Bi-Weekly One on One" on Nov 12, from your Home
calendar, is no longer in the list** after Step 0's sync (assuming Home is unticked). **Look at the
Commitments list, NOT Today.** This is round two's fifth trap: Today only ever shows today, and 2026-11-12 is
not today, so an absence on Today proves nothing either way. If Home is ticked on purpose, the block is
*supposed* to remain — say so and skip (a).

**(b) Unticking removes that calendar's commitments.** Pick a ticked calendar that has timed events in the
next two weeks. In Settings → Calendars, **untick it**, tap **Sync now**, and open the Commitments list: that
calendar's rows should be gone. Then **⟳ Re-check-in** on Today: the schedule should no longer work around
them. Now **re-tick it, Sync now**, and confirm its rows come back.

**(c) A deleted event disappears.** In the Calendar app, on a ticked calendar, create a throwaway timed
event dated **tomorrow or later, within roughly the next ten days** (not today, and not at the far end of
the two-week window). Back in Canopy, **Sync now** and confirm the row is on the Commitments list. Then go to
the Calendar app and **delete that event**, return to Canopy, **Sync now**, and confirm the row is gone.

**Accepted limit, stated so you are not surprised:** an event deleted **today** keeps its block for the rest
of today. The same goes for the very last day of the two-week window. Neither is a failure of this item.

### S5 — WINDOWS entry 14: does every tick land where you tapped?

Untick one calendar and tick another — and do it **straight after opening the screen**, the way it went
wrong before. Leave the screen and re-enter. **The ticks should be exactly the ones you tapped**, no more and
no fewer. If you connect Google in this same sitting (round two's R4), repeat this with the Google list
loading above or below; the device list should not move while Google arrives.

**If any tick lands wrong:** write down exactly what you tapped and which row ended up ticked, and **stop** —
the phone's own data will be read before anything else is concluded.

---

## Carried forward from round two

These are still blank in `36-UAT-R2.md`. They are listed, not restated — each points at its label there, so
you are answering the same question rather than a paraphrase. **R4 and the Google items can be answered in
this same sitting**, since connecting Google also exercises S5.

- **R4** — does the Google section stay connected on screen re-open (`36-UAT-R2.md`, item R4)
- **R5** — is the accepted all-day cost fine, or do you want the day-marker built (`36-UAT-R2.md`, item R5)
- **A4.2** — delete one occurrence of a recurring event provably inside the 14-day window, and record the
  date you deleted it (`36-UAT-R2.md`, carried-forward list)
- **A5** — permission off, app still fully usable
- **A6** — Canopy changed nothing in your real calendar
- **Section B item 2** — the exact wording of Google's consent screen
- **Section B item 4** — Google calendars under their own heading; survives a full close and reopen
- **Section B item 5** — the revoked-token message and the offline message, answered separately
- **Section B item 7** — fully usable with everything disconnected or denied
- **Section B item 8** — Google Calendar itself unchanged
- **Section B item 3, swipe-dismiss half** — dismissing Google's consent sheet with a real finger

**Listed separately as untestable for you, not unanswered:** **Section B item 6's double-tick** (the same
calendar ticked under both Google and "This device"). It needs your Google account added at the phone's
operating-system level, which you deliberately do not do. Drop it.

---

## Limits of this document

- **Nothing here ran on danserver.** Every item needs your eyes on a real screen or your finger on a real
  gesture. What danserver could prove (the code paths, the id sets, the mutation tests) is proven and is not
  what is being asked.
- **No web address is involved in this sitting, and none may be added.** The history: Phase 35's browser
  check told you to type a calendar feed address that began with the plain, unencrypted form of the protocol,
  and the app deliberately refuses any feed that is not encrypted. The check could not be completed as
  written and sat open for twelve days, because the instructions and the test harness had never been pointed
  at the same address. This round is a native device sitting — Settings, taps, your own Calendar app. If a
  later edit to this file adds an address to type, that edit is the bug.
- **If any answer is ambiguous you do not have to guess.** The phone's own data can be read after the
  sitting with `xcrun devicectl device copy from` (the recipe is recorded in `STATE.md` and in
  `36-UAT-R2.md`), followed by a throwaway test that opens the stored data through the project's own
  adapters. It is the tool that settles S4 and S5 if your description is unclear, and it overturned a false
  alarm last time (entry 9).

---

## Your answers

*(Fill in below, in your own words. A failure should record what was on screen, not a diagnosis. Every slot is
genuinely blank.)*

**Step 0 — did you complete all five steps, in order, before judging anything? (yes/no):**


**S1 — entry 12: list present on every re-open and after force-quit, no "Allow calendar access", no iOS prompt:**
PASS (owner, 2026-11-03, build installed 08:31): the list shows on open, with no Allow calendar access button.


**S2 — entry 13: what you saw when you tapped "Sync now", in your own words:**
PASS (owner): spinner, then the result. But the success SnackBar covered Sync now and lingered, and he wants a clock time rather than 'just now'. Logged as WINDOWS 17 and fixed.


**S3 — entry 10: what you noticed first on opening the screen; still there after leaving and after force-quit; what tapping it said:**
PASS (owner): the notice is at the top and survives leaving and re-entering.


**S4(a) — entry 11: "Bi-Weekly One on One" on Nov 12 gone from the Commitments list:**
PASS AT DATA LEVEL (agent, device Hive 2026-11-03 08:31 and 08:37): the Home block 9fb91958 on 11-12 is gone; only spunkl-hash blocks remain, incl. the 11-05 Biweekly One on One.


**S4(b) — entry 11: unticking removed that calendar's rows; re-ticking brought them back:**
Final state clean: after Family was ticked and then unticked, no Family-hash block remained. Owner: 'doesn't appear to be working' -- he meant the synced events never appeared on Today's check-in timeline (WINDOWS 16, fixed), not the prune.


**S4(c) — entry 11: a deleted throwaway event's row gone after Sync now:**


**S5 — entry 14: ticks landed exactly where you tapped (and, if Google was connected, nothing moved):**


**Anything that read like a sixth trap (the screen implied one thing, the data said another):**


**Overall verdict:**


---

## Addendum (2026-11-03): WINDOWS entry 1 browser check

Run in a **browser**, not on the phone. Problem 1 is about `.ics` feed URLs, and the iPhone build
reads the device calendar instead.

**Pre-flight (verified by the agent 2026-11-03):** debug web build served by
`tools/serve-uat.py 8161`, fronted by `tailscale serve --https=8447`. Fixture regenerated today:
`https://danserver.tailc2efd2.ts.net:8447/sample.ics`. That exact URL was then driven through
`IcsCalendarSource`'s **real default fetcher** (no seam). Result: today the weekly sync appears
once, at 16:00 (moved); an RDATE copy appears 11-04 at 10:00; 11-10 is EXDATE'd and absent; today's
Daily Standup is absent (cancelled override), and it is present from 11-04. A first run also caught
a fixture bug: a UTC series anchored before DST ended no longer lined up with its own overrides. The
series was moved to TZID America/Chicago (commit 8911902). The fixture's dates are relative to the
day it is generated, so regenerate it on a later day before testing.

1. Open `https://danserver.tailc2efd2.ts.net:8447/`, complete onboarding if shown, then go to
   Settings → Calendars → **Add calendar URL** and enter `https://danserver.tailc2efd2.ts.net:8447/sample.ics`.
2. **⟳ Re-check-in (mandatory, trap #4)** so today's schedule is built from the synced blocks.
3. On **Today**: "Weekly Sync: Product + Eng (moved)" appears at **16:00**. There is **no**
   Weekly Sync at 14:00, and **no** "Daily Standup".
4. Goals → ⋮ → **Commitment blocks**: Weekly Sync appears on **Wed 10:00** (RDATE). There is
   **no** Weekly Sync on next Tue (EXDATE). Daily Standup appears from Wed onward.

**E1 — what you saw:**

