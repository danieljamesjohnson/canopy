# Phase 35 UAT — Your Real Commitments, Read From Your Calendar

**Owner:** Dan
**Prepared:** 2026-09-17 · **Re-served and re-verified:** 2026-09-29
**Path tested:** the ICS feed-URL path (web build). Per D-35-15 this is what
Android uses too, so it is the majority path, not a fallback. The iOS device
path (checkbox list of the phone's own calendars) is verified separately on
your MacBook via `35-05` Task 3 and is not part of this UAT.

---

## Step 0 — ⟳ Re-check-in FIRST. Mandatory. Not optional. Read this before step 1.

**This UAT judges scheduling-engine output — imported commitments on the
Today timeline.** `ScheduleNotifier._loadToday()` reads today's schedule
straight from Hive, and the generator only runs at check-in with
silent-replace. **An already-generated day is never regenerated on load.**

If you import a calendar feed and then look at Today without re-checking-in,
you will be judging a day that was built *before* the calendar was ever read
— and it will look exactly like a failure, when the real defect (if any) is
somewhere else entirely. `curl | grep` on the bundle confirming the new code
shipped (see Pre-flight below) proves nothing about this — the code can be
completely correct and the screen can still be wrong, because the *data*
on screen was produced by an earlier check-in.

**On 2026-08-21 this exact omission cost a round trip:** a UAT skipped
re-check-in, judged a pre-fix day, reported a false failure, and the real
defect survived three more days until it was reported again on 2026-08-24.

**The rule for this UAT:** after step 2 (adding the feed), and again any
time you're about to judge the Today timeline, tap **⟳ Re-check-in** first.
Step 4 below repeats this instruction — record explicitly, at both step 0
and step 4, whether you did it. Do not assume; write "yes" or "no."

---

## Pre-flight (performed by the executor before handing this over)

| Item | Value |
|---|---|
| Build command | `flutter build web --debug --source-maps --pwa-strategy=none` |
| Build mode | **Debug** (assertions on, DEBUG banner, unminified source-mapped traces) — not release |
| Serve command | `python3 tools/serve-uat.py 8161 --dir build/web`, fronted by `sudo tailscale serve --bg --https=8447 http://127.0.0.1:8161` so the origin is **HTTPS** with a real tailnet certificate (required — see step 2) |
| **Re-served** | **2026-09-29** — rebuilt and re-served from scratch. The previous serve was a **2026-09-17** build whose fixture had rotted (see "Fixture freshness" below); it would have shown you an empty timeline |
| Port | **8161** — 8161 has only ever served **debug** builds of Canopy, never a release build, so no release-era service worker can be squatting it (trap #1). It is no longer a *fresh* origin, but same-build-type reuse is the safe case |
| Bind check | `ss -ltn \| grep 8161` → `LISTEN 0 5 0.0.0.0:8161 0.0.0.0:*` — confirmed on all interfaces, not just loopback |
| Reachability check | `curl` against the **tailnet IP** `100.108.146.112` (not localhost): `/` → `200`, `/main.dart.js` → `200`, `/sample.ics` → `200` |
| Cache-Control | `curl -sI .../main.dart.js \| grep -i cache-control` → `Cache-Control: no-store, max-age=0` (confirms `serve-uat.py`, not a bare `http.server`) |
| **Byte identity** | `sha256` of the built `main.dart.js` and the **served** one both begin `477cf162df0bf747` — you are looking at exactly the bytes that were built, not a cached older bundle |
| Served-bytes check | Phase 35's `'Imported from your calendar'` → **3**. Phase 36's `'googleReconnectNeeded'` → **7**, `'google:'` → **1**. Non-zero on both phases, so this build post-dates Phase 36 (the previous serve did not) |
| Visual check | Headless-Chromium screenshot of `https://danserver.tailc2efd2.ts.net:8447/` at 430×900 — app renders the onboarding screen, DEBUG banner visible, preset goal chips and "Add your own" present. No JS errors; only expected Hive-box-open logs, a `CONTEXT_LOST_WEBGL` warning and GPU-stall messages, which are trap #2 headless artifacts (it drew correctly regardless) |
| Fixture feed | `https://danserver.tailc2efd2.ts.net:8447/sample.ics` — **generated fresh by `python3 tools/gen-uat-calendar.py > build/web/sample.ics`**, served from the **app's own origin** (so the browser's cross-origin rules for a third-party feed never enter into your first test — see step 2) |
| **Fixture freshness** | ⚠ `gen-uat-calendar.py` dates every event **relative to the day it is run**. It prevents a fixture being *authored* stale; it does **not** self-update. The fixture served here was generated **2026-09-29**. **If you are reading this on a later date, regenerate before looking** — otherwise every event is in the past and Today renders empty, which is a false failure manufactured by the test data. Two commands: `python3 tools/gen-uat-calendar.py > build/web/sample.ics` then restart `tools/serve-uat.py 8161 --dir build/web` |

**A note before you start:** the origin you will use — `https://danserver.tailc2efd2.ts.net:8447` — has never served Canopy before (it was created on 2026-09-29 to satisfy the HTTPS requirement in step 2), so your browser has no existing onboarding or data for it. You'll land on the "What are your goals?" onboarding screen first. That's expected, not a bug; the router gates everything behind onboarding until it's complete (unrelated to this phase). Click or tap through it (pick anything, or "Skip" if offered) to reach the main app. Confirmed by a headless screenshot at that exact origin — see the Visual check row above.

---

## The fixture feed, so you know what you're looking at

`sample.ics` as regenerated on **2026-09-29 (Tuesday)** contains — all clock times **local**:

| Event | When | Why it's in here |
|---|---|---|
| "Weekly Sync: Product + Eng" | Recurring weekly, **Tuesdays** 2:00–3:00pm, anchored **2026-08-18** | The base recurring series (step 4, step 7b) |
| "Weekly Sync: Product + Eng (moved)" | **Today**, 4:00–5:00pm (a `RECURRENCE-ID` override moving today's 2:00pm occurrence) | Step 7b's "moved occurrence" case |
| *(today's original 2:00pm occurrence is also present — the base series has no `EXDATE` for today, only for next week — see below)* | | This is the bug step 7b asks about: verified against the real stack, today's sync produces **both** the 2pm slot and the 4pm "(moved)" slot — the original was never suppressed |
| **Next Tuesday (Oct 6)**'s occurrence | Marked `EXDATE` (deleted) in the feed | Step 7b's "deleted occurrence" case — verified against the real stack, it **still imports** as a commitment dated **Oct 6** despite the `EXDATE` |
| "1:1 with Manager" | Today, 11:00–11:30am | Plausible weekday meeting (UTC `Z` form) |
| "Product Review (zoned TZID)" | Today, 3:00–3:45pm | The `TZID`+`VTIMEZONE` `DTSTART` form — the one a real Google feed sends (WINDOWS.md entry 2) |
| "Design Review (floating time)" | Today, 5:00–5:30pm | The **floating** `DTSTART` form (no `Z`, no `TZID`) — the third RFC 5545 shape |
| "Team Off-site (all day)" | Today, all-day | Step 7a's all-day entry (D-35-06: spans the 08:00–22:00 working day) |
| "Quick Check-in" | Today, 9:00–9:10am (10 minutes) | Step 7's "too short to schedule" entry |
| "Cancelled Thing" | Today, 7:00–8:00pm, `STATUS:CANCELLED` | Should **not** appear on your timeline at all — a cancelled event must be skipped |

> **These dates move every time the fixture is regenerated.** They are correct for a fixture
> generated on 2026-09-29. If you regenerate on another day, the weekly series lands on that day's
> weekday and the `EXDATE` occurrence is one week out — re-read the generated file rather than
> trusting this table's literal dates.

This was verified by running the actual `CalendarSyncService`/`IcsCalendarSource` code
against this exact file before handing it to you — not assumed from reading the
`.ics` text. The real output:

**Re-verified 2026-09-29 against the regenerated fixture, over the real HTTPS URL above, using the
real network fetcher — no `fetch` seam.** That matters: driving it through the seam is exactly what
hid the HTTPS defect above, so this run deliberately used the URL you will type.

```
--- imported (7) ---
Team Off-site (all day)            | date=2026-09-29 | 08:00-22:00
1:1 with Manager                   | date=2026-09-29 | 11:00-11:30
Weekly Sync: Product + Eng         | date=2026-09-29 | 14:00-15:00
Product Review (zoned TZID)        | date=2026-09-29 | 15:00-15:45
Weekly Sync: Product + Eng (moved) | date=2026-09-29 | 16:00-17:00
Design Review (floating time)      | date=2026-09-29 | 17:00-17:30
Weekly Sync: Product + Eng         | date=2026-10-06 | 14:00-15:00   ← EXDATE'd, still here
--- skipped (2) ---
Quick Check-in  | tooShort
Cancelled Thing | cancelled
failed=false
```

> **On the clock times.** The harness process has no device timezone, so the `timezone` package's
> `tz.local` defaults to **UTC** there and it printed these as 16:00, 19:00, 20:00, 21:00. The times
> above are those values converted to **America/Chicago (UTC-5)**, which is what your browser will
> set `tz.local` to and therefore what you will actually see. Two do not shift and that is correct:
> "Team Off-site" reads 08:00–22:00 because an all-day entry is spanned across
> `ScheduleGeneratorService.dayStartMinutes`/`dayEndMinutes` (D-35-06) rather than derived from a
> timezone, and "Design Review" is a **floating** time, which means "whatever local is" by
> definition.

---

## How to verify

**0. ⟳ Re-check-in first — see above. Do this after step 2, before step 4, and any time you're about to judge Today.**

1. Open **`https://danserver.tailc2efd2.ts.net:8447/`**. Complete onboarding if it appears (see Pre-flight note). Go to **Settings → Calendars**. Does the row's subtitle say something true about the current state (should read "Not connected")?

2. Tap **Add calendar URL** and enter **`https://danserver.tailc2efd2.ts.net:8447/sample.ics`**. Does it accept it? (If you'd rather try a real Google or Outlook feed first, go ahead — but if it fails, that's most likely the browser's cross-origin rule kicking in for a third-party feed, not a Canopy bug. It's expected to work fine on a phone, and the fixture feed above is specifically served same-origin so this test doesn't depend on that at all.)

   > **⚠ Both URLs changed on 2026-09-29, and the old ones could not have worked.**
   > This document previously said `http://danserver:8161/` and
   > `http://danserver:8161/sample.ics`. **`IcsCalendarSource._requireHttps()` rejects any
   > non-HTTPS feed URL outright** — Security V6, no localhost or loopback exemption — so step 2
   > would have failed with *"feed URL must use HTTPS"* and every step after it depends on step 2.
   > The browser UAT was un-runnable as written from the day it was handed over.
   >
   > It survived because `35-06`'s verification drove the sync through the `fetch` seam with an
   > `https://example.com/...` URL while this document told you to type an `http://` one — the
   > harness and the instructions never met, so nothing connected them. Fixed by exposing the same
   > build over HTTPS with a real tailnet certificate (`tailscale serve --https=8447`), which is why
   > the port moved. The plain `http://danserver:8161/` origin is still up and still fine for
   > *looking* at the app — it just cannot accept a feed.

3. Enter a URL that is not a calendar (e.g. `https://danserver/`). Does it refuse it inline, with a message that makes sense, and leave nothing saved?

4. **⟳ Re-check-in.** (Record: did you do this? yes/no.) Now look at **Today**. Are the feed's meetings on the timeline, at the right times? You should see: "1:1 with Manager" ~11am, "Product Review" ~3pm, "Weekly Sync: Product + Eng" ~2pm, "Weekly Sync: Product + Eng (moved)" ~4pm, and "Team Off-site (all day)" spanning the whole working day.

5. Do those timeline rows carry the small calendar glyph? Go to **Commitments** — are the imported ones marked, and do any commitments you type yourself look exactly as they did before this phase?

6. Tap an imported commitment. Does the read-only explanation make sense, or does it feel like the app is refusing you something? **This is the one item here with no right answer on file** — D-35-14 says imported commitments are read-only, and this is where that ruling is either confirmed by use or rejected.

7. Does the status line tell you when it last synced, and does the "{n} events not imported" line show you the 10-minute "Quick Check-in" entry with a reason that reads sensibly ("Too short to schedule")? (**The all-day entry is NOT in this list** — D-35-06 was ruled `import-as-blocking`, so it's imported, not skipped — you'll find it on the Today timeline instead, per step 4.)

7a. **The all-day span — answer this as its own item, separate from step 7.** Look at "Team Off-site (all day)" on Today. **What exact hours does it block?**

    **Verified: it ships as `08:00–22:00` — a 14-hour block.** (Checked against `ScheduleGeneratorService.dayStartMinutes`/`dayEndMinutes` in the actual source, and confirmed in the sync output above — this is the app's only existing "working day" constant.)

    **But the option you actually ruled on showed you `08:00–18:00`.** So there are two separate problems, and you should judge them separately:

    - **The orchestrator worded the question badly.** Its label said "full-day block" while its description said "the whole working day" and its preview rendered `08:00–18:00`. Label and description pointed at different behaviours.
    - **And then the build didn't match even the preview.** It reuses the 08:00–22:00 constant, four hours longer than the `08:00–18:00` you were shown.

    You have three real options and none of them is expensive right now: **08:00–22:00** (what ships, matches the rest of the app), **08:00–18:00** (what the preview promised you), or **00:00–23:59** (the literal reading of "full-day block"). The third would hand the generator a 24-hour commitment window that no fixture covers, so if you want it, say so and it gets its own test. **Any of the three is a small change today and an irritating one after you've lived with it.** `SEED-007` survived a 12/12 verification for precisely this reason: a requirement's wording moved after its tests were written.

7b. **A known limitation you should meet here rather than discover in use — this is a decision, not a bug report.** `RECURRENCE-ID` and `EXDATE` are **not supported**, and that was established by running a test against the real `enough_icalendar` + `rrule` stack, not by reading docs. Concretely, **you can see it yourself in this fixture, right now**:

    - The "moved" occurrence: today's timeline shows the Weekly Sync **twice** — once at 2:00pm (its original, un-suppressed slot) and once at 4:00pm labeled "(moved)" (the override). The original was supposed to disappear when it moved; it didn't.
    - The "deleted" occurrence: go to **Commitments** and look for a "Weekly Sync: Product + Eng" dated **Oct 6** (next Tuesday) — the feed marks that occurrence deleted (`EXDATE`), and Canopy imported it anyway.

    This is `WINDOWS.md` entry 1, open. Do you want to (a) accept it for v1, (b) have it built as a follow-up phase, or (c) treat it as blocking this phase? If you move or cancel a real recurring meeting often, this will bite you regularly — if you never do, it costs nothing. Only you know which.

8. Remove the feed. Does the confirmation dialog say what will happen? After removing, are the imported commitments gone and your hand-entered ones still there?

9. With no feed configured at all, is the app completely usable — add a commitment by hand, run a check-in, get a day (CAL-04)? **Answer this one as pass/fail in a single line** — it's the requirement most likely to be assumed true because on the development machine it always is.

---

## Your answers

*(Fill in below — a failure should record what was on screen, not a diagnosis. A blank page is most likely a stale service worker or a cached bundle (traps 1 and 3), not a broken build — rule those out before concluding anything about the code. A feed that fails to load in the browser but not on a phone is the cross-origin rule, a browser policy, not a defect in this app.)*

**Step 0 (re-check-in performed before judging Today):**

**Step 1 (Calendars row subtitle, accurate?):**

**Step 2 (feed URL accepted?):**

**Step 3 (bad URL rejected inline, nothing saved?):**

**Step 4 (re-check-in performed — again, explicitly — and are the feed's meetings on the timeline at the right times?):**

**Step 5 (imported rows marked; hand-entered rows unchanged?):**

**Step 6 (does the read-only refusal feel right, or does it feel like the app is refusing you something?):**

**Step 7 (sync status + skipped-events disclosure showing the 10-minute entry with a sensible reason?):**

**Step 7a (all-day span — which of the three options do you want: 08:00–22:00 / 08:00–18:00 / 00:00–23:59?):**

**Step 7b (RECURRENCE-ID/EXDATE gap — accept for v1 / follow-up phase / blocking?):**

**Step 8 (remove-feed confirmation + cleanup correct?):**

**Step 9 (app fully usable with no feed configured — pass/fail):**

**Overall verdict:** *(type "approved" only if every step passed)*
