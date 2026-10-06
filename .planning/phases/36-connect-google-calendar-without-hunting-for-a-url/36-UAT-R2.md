# Phase 36 UAT, Round 2 — Device Re-Verification

**Owner:** Dan
**Prepared:** 2026-10-06
**Where this runs:** your iPhone, built from your MacBook. **No URL is involved anywhere in this
document** — this is a native device check, not a browser one, and nothing below should ever ask
you to type one. If a future edit adds a feed-URL step to this file, that is a mistake: see
"Limits of this document" below for why.

---

## Why there is a round two

On 2026-10-06 you ran Phase 36 on your real iPhone and stopped partway through, on your own call,
because two real defects made the rest of the sitting not worth judging:

- **WINDOWS entry 7** — your calendar ticks never reached the device calendar plugin. Every
  calendar on your phone imported, not just the ones you selected.
- **WINDOWS entry 8** — all-day events imported as full 08:00-22:00 blocking commitments. In a
  12-day window you lost six working days to Vacation, a 38th Birthday, Fall break, Payday,
  Indigenous Peoples' Day, and Columbus Day.
- **WINDOWS entry 10** — the disclosure that tells you an event wasn't imported exists and is
  tested, but you didn't notice it on screen.

All three are now fixed in code (danserver-side). **None of the three can be confirmed from
danserver** — two are device-plugin behavior and one is a perceptual "did a human notice this"
question. This document is how you confirm them, and it also carries forward everything the
stopped sitting never got to.

---

## Step 0 — MANDATORY. Do this first. Before judging anything below.

This is not optional and it is not a suggestion — this project's own `CLAUDE.md` states it as a
rule, with a date attached: on **2026-08-21**, a UAT skipped this exact step, judged a
pre-fix day, reported a false failure, and the real defect survived three more days until it was
reported again on 2026-08-24. That is trap #4, and it applies here directly, because
`ScheduleNotifier._loadToday()` reads today's schedule straight out of Hive and
`ScheduleGeneratorService.generate()` only runs at check-in with silent-replace — **an
already-generated day is never regenerated on load.** If you look at Today before completing
step 5 below, you are looking at data the new code never touched.

Five steps, in this exact order:

1. **Build and install from your Mac** with the single command already staged in `STATE.md`'s "Mac
   environment" table — do not re-derive it, it's ready:
   ```bash
   ssh dans-macbook-air
   cd ~/CodeProjects/canopy && export PATH="/opt/homebrew/bin:$HOME/Library/Python/3.9/bin:$PATH"
   tools/build-ios.sh run
   ```
2. Open **Settings → Calendars** and tap **"Allow calendar access"** if asked.
3. **Tick the calendars you actually want to schedule around.**
4. Tap **"Sync now."**
5. Go to **Today** and tap **⟳ Re-check-in.**

**Judge nothing before step 5 is done.** That is the binding rule, and the 2026-08-21 round trip
above is exactly what it prevents.

### What you will see first, and it is not a bug

The upgrade includes a one-time cleanup that discards **every previously-imported calendar
commitment**, once, on purpose. The pre-fix set was built from calendars you never ticked and
contains the six all-day blocks that should never have existed. Step 4's sync rebuilds the
correct set from scratch.

**If you look at your schedule between installing and syncing, imported commitments will appear
to be missing. That is the migration working, not a regression.** Be online for this first sync —
if you're offline when you first open the app post-upgrade, there's nothing to fall back to until
a sync succeeds (this is a known, accepted, one-time cost; see R-cost below).

---

## The five items this round must settle

### R1 — WINDOWS entry 7 / CAL-02: do your ticks actually control what imports on your phone?

Untick one calendar that you know has events on it right now. Tap **Sync now**, then **⟳
Re-check-in** (Step 0's rule applies every time). Look at today and the next few days: that
calendar's events must be gone, and your still-ticked calendars' events must still be there.
Re-tick it, sync, re-check-in again, and confirm its events come back.

**This is the only real confirmation of this fix that exists.** On danserver, the fix is proven
only as far as the exact calendar-id list that reaches the point where `device_calendar_plus` is
called — the production `sync()` path, mutation-tested, with the right ids verified to arrive.
**Whether the plugin itself actually honors a non-empty id list and restricts EventKit's query to
it, on real iOS hardware, has never been observed by anyone until you do this.** There is no Xcode
or device on danserver to check this any other way.

### R2 — WINDOWS entry 8 / D-36-05: are the six fake all-day blocks gone?

Look across the same window you saw them in before. Confirm specifically that none of these still
occupies a working day:

- Vacation
- a 38th Birthday
- Fall break
- Payday
- Indigenous Peoples' Day
- Columbus Day

**Call out 2026-10-13 by name** — it carried two of these (Columbus Day and Indigenous Peoples'
Day land on the same date in most US calendars) and is the single best day to check first.
Confirm it's a normal, schedulable working day now.

### R3 — WINDOWS entry 10 / discoverability: did you actually notice it this time?

This is a perceptual question, and it's deliberately asked without pointing you at the answer
first — this project's green test suites have been wrong about what a human notices six separate
times (Phases 27, 29, 31, and 32 twice), and a passing geometry test is not the same thing as a
human seeing the banner.

**Open Settings → Calendars cold, without being told where to look.** Before you go hunting,
does anything on the screen tell you that some events were not imported? Then deliberately tap or
look at it, and confirm it names the all-day entries specifically as the reason they're missing.

This is the item that decides whether the move-to-the-top-and-add-weight fix actually worked. A
widget test already proved the banner's new screen position geometrically; it cannot prove you
will notice it. Only you can answer that.

### R4 — WINDOWS entry 6: does the Google connection survive leaving the screen?

Leave Settings → Calendars (go back), then go back in. Does the Google section still show your
connected account and calendar list directly, or does it ask you to connect again?

The **old** behavior — always re-showing "Connect Google Calendar" even with a perfectly valid
token — was expected and called out explicitly in round one as a known limitation, not a bug. It
should be **gone now.** If tapping Connect ever does re-launch Google's consent screen when you
weren't expecting it, that's the thing to report; simply seeing the connected view persist on
re-open is the pass condition.

### R5 — D-36-05's accepted cost, now that it's in front of you rather than in a decision doc

A genuine all-day entry — a real Vacation, say — no longer blanks the whole day the way it used
to. That was a deliberate decision (D-36-05), made because the old behavior was actively worse
(it ate Payday). The cost: if you have a real all-day commitment, the schedule will act as if your
day is free unless you add a one-off commitment by hand, or you simply skip checking in that day.

**Now that you're living with it rather than reading about it:** is that fine in practice, or do
you want the better end state — a non-blocking day marker that shows the title without consuming
the whole day — built as a real follow-up? That option was **not rejected on merit. It was
deferred on size** — `CommitmentBlock` has no concept of "non-blocking," and building one needs a
new Hive field, generator changes, and a new timeline affordance. That's a phase, not a gap
closure, and **no follow-up phase has been committed to.** This question exists so you're choosing
with the real tradeoff in front of you, not a hypothetical one.

---

## Carried forward — what the stopped 2026-10-06 sitting never reached

These are listed, not restated — each points at its exact wording in `36-UAT.md` so you're
answering the same question, not a paraphrase of it.

- **A4.2** (`36-UAT.md`, Section A, item A4, part 2) — delete a single occurrence of a recurring
  event that you can **prove is inside the ~14-day sync window** (`kCalendarSyncWindowDays`), and
  **record the date you deleted it.** Last time both in-window dates were present, so the result
  was genuinely inconclusive — either the deletion happened outside the window or it didn't take.
  This is the one Section A item that must be actually redone, not just re-asked.
- **A5** (`36-UAT.md`, Section A, item A5) — permission off, app still fully usable (CAL-04).
- **A6** (`36-UAT.md`, Section A, item A6) — confirm Canopy changed nothing in your real calendar.
  Note: this document's item **A1** is the permission-dialog-wording question and is unrelated to
  **Phase 35 Assumption A1** (whether `device_calendar_plus` returns expanded recurring occurrences
  with exceptions applied) — that one is already verified on your device and does not need
  re-asking. Don't let the shared label collapse the two.
- **Section B item 2** (`36-UAT.md`, item 2) — the exact wording of Google's own consent screen on
  what it's asking for.
- **Section B item 4** (`36-UAT.md`, item 4) — Google calendars appear under their own heading;
  survives a full app close/reopen (Assumption A6, the refresh-token-persistence claim).
- **Section B item 5** (`36-UAT.md`, item 5) — the revoked-token message and the offline message,
  answered **separately**, confirming they read as two different sentences (CALAUTH-03).
- **Section B item 7** (`36-UAT.md`, item 7) — fully usable with everything disconnected or denied
  (CAL-04).
- **Section B item 8** (`36-UAT.md`, item 8) — Google Calendar itself is unchanged (CAL-03).
- **Section B item 3's swipe-dismiss half** (`36-UAT.md`, item 3, second half) — dismissing
  Google's consent sheet by swipe rather than the Cancel button. This needs a real finger;
  synthetic gestures cannot reach the `ASWebAuthenticationSession` web sheet, which is a separate
  process from the app.

**Listed separately, as untestable rather than unanswered:**

- **Section B item 6's double-tick** (`36-UAT.md`, item 6) — ticking the same calendar under both
  Google and "This device." This is **structurally untestable for you specifically**, not merely
  unreached: it requires the same calendar to appear under both sources, which requires your
  Google account to be added at the OS level, and you deliberately do not do that. The same
  calendar can never appear under both sources on your phone. Drop this item; it isn't coming back
  unless that OS-level configuration changes.

**Not re-asked, and should not be:** anything `D-36-05` already settled by ruling (the old
10-vs-14-hour all-day span question — removed by D-36-05 deciding to skip all-day events
entirely, not by picking a span), and anything this document's own R1-R5 already cover.

---

## Limits of this document

- **Nothing in this document was or could be executed on danserver.** Every item above needs
  either your own eyes on a real screen or your own finger on a real gesture. danserver has no
  Xcode and no device; what it could prove (the code paths, the id lists, the mutation tests) is
  already proven and is not what's being asked here.
- **No URL is involved in this sitting at all.** This is a native device check — Settings,
  taps, your own Calendar app. The plain-`http://`-versus-HTTPS-required trap that made Phase
  35's browser UAT impossible to complete for twelve days (it told you to paste an insecure feed
  URL that the app's own HTTPS enforcement rejects outright) **does not apply here and never
  will**, because there is no feed URL step in this document. If a future edit to this file ever
  adds one, that is itself a bug in the edit — this is a device-only sitting by design.
- **If any answer above is ambiguous, you don't have to guess — the device's own data can be read
  directly.** The method that settled both real defects and overturned a false alarm last time
  (entry 9, withdrawn) outperformed describing what was on screen. It's documented in `STATE.md`
  and repeated here because it's the single most useful tool in this sitting:
  ```bash
  xcrun devicectl device copy from --device 66110258-0097-5E64-9C90-B9815966D67E \
    --domain-type appDataContainer --domain-identifier com.danjjohnson.canopy \
    --source / --destination <dir>
  ```
  followed by a throwaway test that `Hive.init(dir)`s and dumps the box through the project's own
  adapters. Reach for this whenever the screen leaves you unsure, rather than guessing.

### A fifth trap, found last time, worth knowing about before you look at anything

**"Today shows today" can fake a dropped recurring occurrence.** Last time, a moved recurring
event appeared to be missing entirely — it wasn't on the Today timeline — and that read exactly
like the import having dropped it. In fact the import was correct: the moved occurrence landed a
week out, and Today only ever renders today. The data was right, the screen was right, and the
conclusion drawn from looking at the screen was wrong. **Whenever you're checking whether a
specific calendar occurrence imported, name the date it should land on and look at that day** —
or read the Hive directly, which is what actually caught this the first time.

---

## Your answers

*(Fill in below, in your own words. A failure should record what was on screen, not a diagnosis.
Leave nothing pre-filled — the slots below are genuinely blank.)*

**Step 0 — did you complete all five steps, in order, before judging anything? (yes/no):**


**R1 — unticked calendar's events gone, ticked calendars' events still present, re-tick restores them:**


**R2 — are all six all-day entries confirmed gone, specifically on 2026-10-13:**


**R3 — did you notice the disclosure cold, before being told where to look, and does it name the all-day entries:**


**R4 — does the Google section stay connected on screen re-open, without re-launching consent:**


**R5 — is the accepted cost (a real all-day entry no longer blanks the day) fine in practice, or do you want the non-blocking day marker built as a real follow-up:**


**A4.2 — deleted occurrence provably inside the 14-day window, date deleted, and was it absent:**


**A5 — permission off, app still fully usable:**


**A6 — Canopy changed nothing in your real calendar:**


**Section B item 2 — Google's exact consent wording:**


**Section B item 4 — Google calendars under their own heading, survives full app restart:**


**Section B item 5 — revoked-token message and offline message, recorded separately:**


**Section B item 7 — fully usable with everything disconnected/denied:**


**Section B item 8 — Google Calendar itself unchanged:**


**Section B item 3, swipe-dismiss half:**


**Anything that read like a sixth trap (the screen implied one thing, the data said another):**


**Overall verdict:**

