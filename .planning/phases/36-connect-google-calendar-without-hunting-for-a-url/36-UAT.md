# Phase 36 UAT — Connect Google Calendar Without Hunting For a URL

**+ Phase 35's still-open device gate (35-05 Task 3), carried here as Section A**

**Owner:** Dan
**Prepared:** 2026-09-25
**Where this runs:** your MacBook, building for a real iPhone (simulator or device). This is the
only place any of Phase 36 — and Phase 35's device path — can be observed. danserver has no Xcode
and never will; every claim below that mentions a device has been proven only as far as
`flutter analyze` and an injected-seam test can prove it. Nothing about this phase has ever run.

---

## Build instructions — nothing below can happen without this working first

1. `git pull` (or otherwise get this worktree's commits onto your Mac).
2. Confirm `.google-client-id` exists at the repo root, mode 600, containing your real iOS OAuth
   client id (ends in `.apps.googleusercontent.com`). Per `STATE.md` this file already exists on
   your machine — it is gitignored by design and never enters any worktree checkout, so if you're
   building from a fresh clone rather than your existing working copy, see
   `36-GOOGLE-CLOUD-SETUP.md` to recreate it.
3. Build with **`tools/build-ios.sh`** — this is the only supported way to build the iOS target.
   Do not use `flutter build ios` directly; it will not inject the client id into either place that
   needs it.
   ```bash
   tools/build-ios.sh run              # build and run on a connected device or simulator
   tools/build-ios.sh build --simulator --no-codesign   # build only
   ```
4. **What the failure looks like if `.google-client-id` is missing**, so you recognize it instead
   of treating it as a broken build: the script exits immediately, before Xcode or `flutter` ever
   runs, with:
   ```
   ERROR: /path/to/canopy/.google-client-id not found.

   Get your iOS OAuth client id from Google Cloud Console (APIs & Services ->
   Credentials -> your iOS client, ends in .apps.googleusercontent.com) and:

     echo '<your-client-id>.apps.googleusercontent.com' > .google-client-id
     chmod 600 .google-client-id

   See .planning/phases/36-connect-google-calendar-without-hunting-for-a-url/36-GOOGLE-CLOUD-SETUP.md
   for the full walkthrough.
   ```
   That is not a code defect — it is the script doing exactly what it is for. The same wrapper also
   prints `Building for bundle identifier: com.danjjohnson.canopy` before invoking Xcode. **Compare
   that line to what Cloud Console shows for your iOS OAuth client before diagnosing anything else
   as a code bug** — a bundle-identifier mismatch (Pitfall 4, D-36-02) fails in a way that reads
   exactly like a broken consent flow.

**Why the client id has to reach two places and agree in both:** the compiled Dart code needs it
as a `--dart-define` (so the app can start the consent flow), and Xcode needs it baked into
`Info.plist`'s `CFBundleURLTypes` (so iOS knows to route Google's redirect back into Canopy rather
than Safari). `tools/build-ios.sh` derives both from the one gitignored file so they can never
drift apart — that is the entire reason this script exists rather than a plain `flutter build ios`.

---

## Step 0 — ⟳ Re-check-in FIRST. Mandatory. Not optional. Read this before anything else below.

**Several items below judge what appears on the Today timeline or in Commitments — imported
calendar events.** `ScheduleNotifier._loadToday()` reads today's schedule straight from Hive, and
`ScheduleGeneratorService.generate()` only runs at check-in, with silent-replace. **An
already-generated day is never regenerated on load.** If you connect a calendar or tick a new
selection and then look at Today without tapping **⟳ Re-check-in**, you will be judging a day that
was built *before* the calendar was ever read — and a working feature will look exactly like a
failure.

**On 2026-08-21 this exact omission cost a round trip:** a UAT skipped re-check-in, judged a
pre-fix day, reported a false failure, and the real defect survived three more days until it was
reported again on 2026-08-24 (`CLAUDE.md`'s trap #4).

**The rule for this UAT:** any time an item below asks you to look at Today or Commitments and
judge what's on it, tap **⟳ Re-check-in first** — even if you just did it for a different item.
Record explicitly, each time, whether you did it. Do not assume; write "yes" or "no."

---

## Section A — Phase 35's still-open device items (35-05 Task 3)

**These come first because Section B's item 6 (the double-tick) has nothing to stand on if the
device calendar list doesn't work at all.** This is the load-bearing claim of Phase 35 that has
never been checked on a device: whether `device_calendar_plus.listEvents()` returns
already-expanded occurrences with exceptions applied. If it doesn't, `36-DECISIONS.md`'s
"Correction on the record" (that Google sign-in adds no recurrence benefit on the device path) is
wrong, and the Google path is worth more than currently stated.

**A1. Grant the permission when iOS asks.** Read the dialog text — this is the `Info.plist` string
you're seeing. Does it say something true and unalarming about what Canopy does with your
calendar?

**A2. Open Settings → Calendars.** Are your real calendars listed, grouped by account? **Is your
Google account there?** (If it's not, that's an OS Settings matter — the account isn't added at OS
level — not a Canopy bug; the screen is showing you the truth either way.)

**A3. In your own Calendar app — not in Canopy — create a recurring event**, e.g. weekly at 10:00
for four weeks. **Move ONE occurrence** to a different time ("this event only"), and **delete a
different single occurrence**. Then **⟳ Re-check-in in Canopy** (mandatory — see Step 0) before
looking at anything.

**A4. Now look, on three different days:**
- On the day of the **moved** occurrence — does it appear at its **new** time, not its original one?
- On the day of the **deleted** occurrence — is it **absent**?
- On an ordinary week — does it appear at the **base** time?

Answer these three separately. "It seems to work" is not an answer to three questions.

**A5. Turn the calendar permission OFF** in OS Settings, reopen Canopy, and confirm it's still
fully usable: Commitments works, you can add one by hand, a check-in still produces a day (CAL-04).

**A6. Confirm Canopy changed nothing** in your calendar app — the events you created are exactly
as you left them (CAL-03).

---

## Section B — Phase 36's items

Each item states what you're judging before you judge it. Answer each one on its own — a
multi-part item needs a multi-part answer.

**1. The button.** Settings → Calendars. Is there a "Connect Google Calendar" button? Tap it. Does
Google's own account picker appear? This is CALAUTH-01, and it's the whole reason this phase
exists — your words were *"when I login to google on an app, how does that work? I just want
that."*

**2. The consent screen's own words.** Before approving, read exactly what Google says Canopy is
asking for. **Does it say read-only / view?** Record the exact wording — that sentence IS
CALAUTH-02's evidence, stated by Google rather than by us, and it's a stronger guarantee than the
device path has.

**3. Cancel first, on purpose.** Back out of the consent sheet without approving — **try both the
Cancel button and a swipe-dismiss, and record them separately.** Does the app return cleanly to the
Connect button both times, with no error message and nothing implying something went wrong?
Whether both paths behave the same is genuinely unconfirmed (Assumption A7) — the code only proves
one specific exception type is caught; a real device is what tells us whether every cancellation
path throws it.

**4. Then connect for real.** Do your Google calendars appear, under a **Google** heading, separate
from the device list? Tick one. **Close the app completely and reopen it — is it still connected?**
That last question is Assumption A6: whether Google actually issued a durable refresh token to an
iOS client with no secret, which is the premise the whole native-flow decision (D-36-01) rests on.

**5. The expiry, forced rather than waited for.** Go to `myaccount.google.com/permissions`, find
Canopy, and remove its access. Come back to the app and sync (Sync now, or a re-check-in — see Step
0). **Does it say the sign-in expired, in plain words, with a button to reconnect? Does the
Settings row say it too?** Tap Reconnect and confirm it actually works. This is CALAUTH-03, and
revoking access is the same wire failure as the 7-day expiry you already accepted — it just doesn't
take a week to arrive.

   **Also, separately: turn wifi off and sync again.** Does it say something about the sync
   *failing*, rather than telling you your login *expired*? **Those are supposed to be two
   different sentences — if they read the same, CALAUTH-03 is not met, regardless of what the test
   suite says.** That is the entire requirement.

**6. The double-tick — the one that needs your judgement, not a test.** Tick the SAME calendar
under **Google** and under **This device**, deliberately. **Does a warning appear under the row,
and does it read clearly enough that it would stop you doing this by accident?** Then **⟳
Re-check-in** (Step 0) and look at a day with a meeting on it: **does the meeting genuinely appear
twice?** It should — nothing de-duplicates it on purpose, because both sources are allowed to
coexist and Canopy must not quietly undo a configuration you chose (D-36-03). Untick one side and
re-check-in to confirm it goes back to appearing once.

   This item also settles something the code cannot: whether your real iPhone's calendar app
   reports the SAME account identifier for a Google-added device calendar as Google's own API
   reports for that account. If the warning does NOT appear when you tick the same calendar both
   ways, that assumption is wrong on your device — which is useful to know either way, and is not
   itself a failure of this item.

**7. Everything still works without any of it.** Disconnect Google, deny or ignore the device
permission, and confirm the app is fully usable: add a commitment by hand, run a check-in, get a
day. That's CAL-04 — the guarantee that makes everything above optional rather than load-bearing.

**8. Canopy changed nothing.** Open Google Calendar (the real one, in a browser or its own app).
Are your events exactly as you left them? That's CAL-03, now additionally enforced by the
read-only OAuth scope rather than only by our code.

---

## Pre-verified on the iOS Simulator, 2026-09-30 — read this first, it shortens your sitting

The orchestrator built and ran Canopy on an **iPhone 17 Pro simulator (iOS 26.2)** on the owner's
MacBook, driving it with `idb`. **This is the first time Canopy has ever run on iOS.** Screenshots of
every step are in the session scratchpad. What follows is settled — you do not need to re-test it,
though you may want to glance at it on the real device.

### Settled by the simulator run

| Claim | Result | How |
|---|---|---|
| The app builds and launches on iOS at all | ✅ | `tools/build-ios.sh` → `Runner.app` 21.4MB → launched, onboarding rendered |
| `com.danjjohnson.canopy` (D-36-02) is the real bundle id | ✅ | build banner + `simctl listapps` both report it |
| `tools/build-ios.sh` injects the client id and generates `GoogleOAuth.xcconfig` (36-04) | ✅ | xcconfig written with the correct reversed id; **the real value never appeared in a tracked file** |
| Onboarding completes and Hive persists across an app restart on iOS | ✅ | terminated and relaunched; still past onboarding |
| **Item 1** — Settings → Calendars subtitle is truthful when disconnected | ✅ **PASS** | reads exactly **"Not connected"** |
| The Calendars screen renders both sources as separate sections (D-36-03) | ✅ | "Connect your Google Calendar" + "See your calendars here", each with its own CTA |
| Read-only is stated to the user in plain language (CALAUTH-02) | ✅ | *"Canopy asks Google for read-only access, so it can never change anything in your calendar"* and *"commitments are only ever read"* |
| **CALAUTH-01** — one tap reaches Google's consent screen | ✅ | one tap on Connect → iOS `ASWebAuthenticationSession` prompt → **Google's live sign-in page** |
| The OAuth client id is valid, registered, and bound to this bundle | ✅ | `accounts.google.com` rendered **"Sign in — to continue to canopy"**. A wrong or unregistered id returns an error page, not a sign-in form. Google resolved our app name |
| The read-only scope is accepted by Google | ✅ | no scope error on the live consent request |
| **Item 3, first half** — tapping **Cancel** on the consent prompt | ✅ **PASS** | returned cleanly to the CTA. **No error banner, no red text, nothing alarming** — 36-02's "cancellation is a state, not an error", confirmed through the real native flow rather than the test seam |

### NOT settled — and why, precisely

- **Item 3, second half (dismissing the Google web sheet by swipe or by its ✕).** Synthetic gestures
  reach the app's own views and the iOS system alert, but **not** the `ASWebAuthenticationSession`
  web sheet, which is a separate process. Needs a real finger. Answer this one yourself.
- **Everything past the sign-in form.** Completing sign-in needs the owner's Google credentials,
  which the orchestrator will not type. So items 4, 5, 7, 8 — refresh-token persistence across
  restart, the revoked-token message, the reconnect card — are all still open.
- **All of Section A, and item 6.** A fresh simulator has **no calendar accounts and no Google
  account added at OS level**, so the device calendar list is necessarily empty and the same
  calendar cannot be ticked under both sources. Section A and the double-tick are *structurally*
  unanswerable here, not merely untested.
- **Phase 35 Assumption A1** (does `device_calendar_plus` return expanded occurrences with
  exceptions applied) — needs real recurring calendar data on a real device.

### One thing worth your eye that no test can catch

The two sections on the Calendars screen are visually near-identical: same calendar glyph, same
heading weight, same button treatment, separated only by a divider. They read as two instances of one
thing rather than two *different sources*. That matters specifically because of D-36-03: the
double-tick footgun is likelier if the sections don't register as distinct. Not a defect, and not
something a widget test can judge — flagging it because it is exactly the class of perceptual call
D-36-03 reserves for you.

---

## Orchestrator observations — read these before you judge, so you don't meet a known quirk cold

- **Re-opening the Calendars screen always shows the "Connect Google Calendar" button, even right
  after you've connected and even if your token is still perfectly valid.** Tapping it re-launches
  a real Google consent screen and issues a fresh token — it does not fail, and it does not mean
  the previous connection broke. This is deliberate UX friction, not a bug: the screen only checks
  for a genuinely *dead* token (a "reconnect needed" state), not "already connected and fine." If
  you see this and wonder whether something reset, it didn't. (`WINDOWS.md` entry 6.)
- **The button does not exist, and never will, in the browser build at `danserver:8161`.** That's
  D-36-01's accepted cost, not a bug — the browser keeps Phase 35's `.ics` feed-URL path.
- **On iOS, the device calendar path already reads your Google calendars with no sign-in at all**,
  if your Google account is added at the OS level. Signing in via this phase's new button adds a
  read-only guarantee enforced by Google itself, and it works even without adding the account at OS
  level — but it does **not** add a recurrence advantage over the device path (Section A above is
  what settles whether the device path already handles moved/deleted occurrences correctly). The
  recurrence fix built in this phase is a real advantage only over the `.ics` feed-URL path — what
  the browser and Android use.
- **The 7-day token expiry itself cannot be tested in this one sitting — that's expected, not a
  gap.** You already accepted this knowingly. Whether Google's real token endpoint emits the exact
  error-body shape the code classifies on (`400` + `invalid_grant`) is only observable about a week
  from now, when a token dies of natural causes rather than being revoked by hand. **Come back to
  this in about a week** and re-run just item 5's first half (without the manual revoke) to close
  it out — it is not something to judge today, and nothing will have "failed" if it doesn't come up
  today.

---

## Cross-check — every "unverified" statement from every 36-0N SUMMARY, and where it lands here

| SUMMARY's own statement | Where it's settled in this document |
|---|---|
| 36-01: whether `ASWebAuthenticationSession` + the registered redirect scheme actually round-trips a real consent flow | Items 1, 3, 4 |
| 36-01/36-02: whether Google truly issues a refresh token with no `client_secret` to a real iOS-registered client (Assumption A6) | Item 4 (app-restart check) |
| 36-02: whether Google's real token endpoint emits the exact `invalid_grant` body shape after a real 7-day expiry (Assumption A3's remaining half) | Item 5 (revoke half is testable now; natural 7-day expiry is the come-back-in-a-week note above) |
| 36-02: whether every native cancellation path (Cancel button, swipe-dismiss) throws the one exception type the code catches (Assumption A7) | Item 3 |
| 36-03: whether Google's live API genuinely returns a moved recurring occurrence at its moved time (WINDOWS.md entry 1, Google-path half) | Item 4 is the connect step; the recurrence claim itself is Section A4 (device path) plus the general Google sync behavior observed across items 4-6 |
| 36-04: whether Xcode actually substitutes `$(GOOGLE_REVERSED_CLIENT_ID)` into the built `Info.plist`, and whether iOS routes Google's redirect back into the app | Items 1, 3, 4 (a working consent round-trip proves both) |
| 36-04: bundle identifier printed by the wrapper vs. Cloud Console's value | Build instructions, step 4 — check before diagnosing anything else |
| 36-04: Known Discrepancy (CALAUTH-04 gate 2b returns 2, not 0) | Not a device question — recorded here as background only: both matches are the bare `.apps.googleusercontent.com` suffix used to implement the reversal rule, not a real client id; no action needed from you on this one |
| 36-05: whether a real iPhone's `EventKit` `accountName` for a Google-added device calendar matches Google's own account id closely enough for the overlap rule to fire | Item 6 |
| 36-05/36-06: whether `Platform.isIOS`/the whole Google+device composition path behaves as coded on a real signed-in device, and whether Google calendars actually arrive at check-in | Items 4-6 (a synced, ticked Google calendar showing on Today is the proof) |
| 36-06: whether the whole restructured Calendars screen reads as ONE coherent screen | Items 1, 4, 6 (look at the screen as a whole while working through them) |
| 36-06: whether the overlap warning's wording reads clearly enough to stop you double-ticking by accident | Item 6 |
| 36-06 (Known Stubs / WINDOWS.md entry 6): the CTA always reappearing on screen re-open | Orchestrator observations, above |

Every "unverified" line from every 36-0N SUMMARY appears in this table. Nothing was invented that
no plan flagged, and nothing a plan flagged was dropped.

**Q-01, for while you're in Cloud Console anyway (not a UAT item, just efficient to do now):** the
real client ID is already committed, in the clear, in `36-RESEARCH.md` (five places), and that
commit is already pushed to a public repo. This is **not** a CALAUTH-04 violation — an iOS native
client has no secret to leak — but it does contradict this project's own stated posture of keeping
the ID out of the repo. See `QUESTIONS.md` Q-01 for the three options (rotate / scrub the doc /
accept and move on). Rotating costs minutes in the same Cloud Console tab you already have open for
this session.

---

## How to answer

Each item gets its own answer, in your own words, recorded below. "It seems to work" is not an
answer to a multi-part question — three separate times in this project's history a non-answer stood
in for a measurement and the item had to be re-asked a round later. Where an item asks for two
things (e.g. item 3's Cancel-button vs. swipe-dismiss, item 5's revoked-message vs.
offline-message), answer both, separately, even if they turned out the same — especially if they
turned out the same.

---

## Your answers

*(Fill in below. A failure should record what was on screen, not a diagnosis — the routing table in
the plan's Task 2 says which kind of conversation each failure opens.)*

---

### ⚠ HOW THIS SECTION WAS FILLED IN — read before trusting any answer below

**Recorded 2026-10-06 by the orchestrator, NOT typed by the owner.** The owner ran Phase 36 on his
real iPhone on 2026-10-06 and **stopped the sitting partway through**, by his own call, once two
real defects made the rest not worth judging. His findings were logged to `WINDOWS.md` (entries
7–10) and `STATE.md` at the time but were **never transferred into this document** — so
`36-07` Task 3 stayed undone, and this section sat blank.

This transcription exists because `/gsd-plan-phase --gaps` reads **this file and
`36-VERIFICATION.md`** as its only inputs. It does **not** read `WINDOWS.md`. With this section
blank and `36-VERIFICATION.md` carrying `gaps: []`, gap-closure planning would have seen **zero**
evidence of the three open defects and planned nothing.

**The discipline applied, because this is second-hand recording and that is a known way to
manufacture a pass:**

- Every answer is traceable to `WINDOWS.md` entries 7–10 or the `STATE.md` 2026-10-06 section. No
  answer is inferred from "it probably worked."
- An item the owner did not reach is marked **UNANSWERED**, not guessed. Several are.
- **The strongest answers below came from reading the device's own Hive, not from the owner
  describing a screen** — `xcrun devicectl` pulled the app container and a throwaway test dumped the
  box through the project's own adapters. That method settled both real defects *and* overturned a
  false alarm the orchestrator had already filed as a bug. Where an answer rests on Hive data rather
  than the owner's eyes, it says so.
- **One name collision, called out so it cannot silently become an answer:** `STATE.md` and commit
  `b69ef12` say *"Assumption A1 VERIFIED"*. That is **Phase 35 Assumption A1** (does
  `device_calendar_plus` return expanded occurrences with exceptions applied) — it is **NOT** this
  document's item **A1** (the permission dialog wording). Phase 35's A1 is verified. Item A1 is
  unanswered. Do not let the shared label collapse them.

---

**Step 0 discipline — was ⟳ Re-check-in performed every time this document asked for it? (yes/no,
and note any time you skipped it):**
**NOT RECORDED.** Nothing in `WINDOWS.md` or `STATE.md` states whether re-check-in was tapped before
each judgement. **Treat this as a gap in the sitting's provenance, not as a "yes."** It matters: the
all-day blocks and the imported-wrong-calendars findings are both judgements about imported data, and
trap #4 is exactly the failure where a stale day is judged instead of a fresh one. The findings
themselves survive this doubt — they were confirmed from Hive contents rather than from the timeline —
but any **re-run** of this UAT must record it explicitly.

### Section A — Phase 35's device path

**A1 (permission dialog wording — true and unalarming?):**
**UNANSWERED.** Permission was evidently *granted* (device events imported at all), but no judgement
of the dialog's wording was recorded. See the name-collision note above — Phase 35's Assumption A1 is
a different claim and its verification does not answer this. Still open.

**A2 (calendars grouped by account; Google account present?):**
**PARTIALLY ANSWERED — and it surfaced defect entry 7.** The picker demonstrably worked and the owner
ticked a calendar: `AppSettings.selectedCalendarIds` held exactly one id (`CF8A6881-…`), read from the
device's own Hive. Whether the list was *grouped by account* on screen was not recorded.
**The Google account was NOT present at OS level — by the owner's deliberate choice**, which is
configuration, not a defect (and it is what makes item 6 structurally untestable for him, below).
**What this item actually exposed:** imported commitments carried **at least four different calendar
ids**, including a holidays calendar and a birthdays calendar, while only one calendar was ticked.
That is `WINDOWS.md` **entry 7** — CAL-02 violated; the ticks are persisted and rendered but never
reach the device source.

**A3 (recurring event created, one occurrence moved, a different one deleted — confirm done):**
**DONE.** A recurring event named `Canopy test` was created in the owner's own Calendar app, with one
occurrence moved. Confirmed from imported Hive records.

**A4 (moved occurrence at its NEW time / deleted occurrence ABSENT / ordinary week at base time — three separate answers):**
Three separate answers, as the item demands:

1. **Moved occurrence at its NEW time — ✅ PASS, and this is the sitting's most valuable result.**
   `Canopy test` imported **twice**: `2026-10-06 09:00` (base) and **`2026-10-13 09:10` — the moved
   occurrence, at its new time.** Read directly from the device's Hive. **This VERIFIES Phase 35
   Assumption A1** — the single most load-bearing claim of Phase 35 — and therefore **CONFIRMS**
   `36-DECISIONS.md`'s "Correction on the record": Google sign-in adds **no** recurrence advantage on
   the device path.
   **Worth recording how close this came to the opposite conclusion:** the owner first reported the
   moved occurrence as *missing entirely*, and the orchestrator filed it as a bug (`WINDOWS.md` entry
   9) that would have *reversed* that Correction and made the Google path worth materially more. It
   was **withdrawn** after the Hive read showed the event was present all along — absent from *Today*
   only because the moved instance falls next week. Entry 9 is **waived with its evidence, not
   deleted.** A false alarm nearly rewrote a decision; the data settled it.
2. **Deleted occurrence ABSENT — ❓ UNANSWERED, and genuinely ambiguous.** Both in-window dates were
   **present**, so either the occurrence was deleted *outside* the ~14-day sync window
   (`kCalendarSyncWindowDays`) or the deletion never took. **This cannot be scored either way from the
   data captured.** It needs a re-run that deletes an occurrence provably *inside* the window and
   records the date deleted. **This is the one Section A item that a re-visit must actually redo.**
3. **Ordinary week at base time — ✅ PASS (partial).** The base occurrence imported at
   `2026-10-06 09:00`, its expected base time.

**A5 (permission off — app still fully usable, CAL-04):**
**UNANSWERED.** Not reached — the owner stopped the sitting before this item.

**A6 (Canopy changed nothing in your real calendar):**
**UNANSWERED.** Not reached. *(Note: CAL-03 is separately supported by the device path being
read-only in code and, on the Google path, by the read-only OAuth scope — but neither is an
observation, and this item asks for an observation.)*

### Section B — Phase 36

**Item 1 (Connect button present; Google's account picker appears — CALAUTH-01):**
**✅ PASS — settled on the iOS Simulator 2026-09-30, not on the real device.** One tap on Connect →
iOS `ASWebAuthenticationSession` → **Google's live sign-in page** rendering *"Sign in — to continue to
canopy"*. That Google resolved the app name proves the client id is valid, registered and bound to
`com.danjjohnson.canopy`. The disconnected-state subtitle read exactly **"Not connected."** See the
"Pre-verified on the iOS Simulator" table above for the full evidence.

**Item 2 (consent screen's exact wording on access level — CALAUTH-02):**
**UNANSWERED.** Reaching the consent screen's scope wording requires completing sign-in with the
owner's Google credentials. The simulator run confirmed Google raised **no scope error** on the live
consent request, but **the exact sentence Google shows was never captured** — and that sentence *is*
CALAUTH-02's evidence. Still open.

**Item 3 (Cancel button AND swipe-dismiss, recorded separately — Assumption A7):**
Two answers, as the item demands:

1. **Cancel button — ✅ PASS.** Returned cleanly to the CTA with **no error banner, no red text,
   nothing alarming** — "cancellation is a state, not an error," confirmed through the real native
   flow rather than the test seam. (Simulator, 2026-09-30.)
2. **Swipe-dismiss — ❓ UNANSWERED.** Synthetic gestures cannot reach the
   `ASWebAuthenticationSession` web sheet; it is a separate process. **Needs a real finger.**
   Assumption A7 is therefore only half-closed: the code proves one exception type is caught, and only
   one of two cancellation paths has been observed throwing it.

**Item 4 (Google calendars appear under their own heading; survives full app restart — Assumption A6):**
**UNANSWERED.** Requires completed Google sign-in. **Assumption A6 — whether Google issues a durable
refresh token to a secret-less iOS client — remains unverified, and it is the premise D-36-01 rests
on.** Note before any re-judgement: `WINDOWS.md` entry 6 plus review finding WR-05 mean a reconnect
CTA reappearing does **not** indicate the connection broke.

**Item 5 (revoked-token message AND offline message, recorded separately — were they different? — CALAUTH-03):**
**UNANSWERED, both halves.** Neither the revoked-access message nor the wifi-off message was
observed, so **whether they read as two different sentences — the entire requirement — is untested on
device.** The natural 7-day expiry half remains a come-back-in-a-week item by design, not a gap.

**Item 6 (double-tick warning appears and reads clearly / meeting appears twice / goes back to once after unticking — your own words):**
**STRUCTURALLY UNTESTABLE FOR THIS OWNER — not a failure, and it should stop being asked of him.**
The item needs the *same* calendar ticked under both **Google** and **This device**, which requires the
Google account added at OS level. **The owner deliberately does not do that.** So the same calendar
can never appear under both sources on his phone, and D-36-03's double-tick warning can never fire
there. The underlying question it was also meant to settle — whether a real iPhone's EventKit
`accountName` matches Google's own account id — is therefore **unanswerable on this device** and needs
either a different device or a different method.

**Item 7 (fully usable with everything disconnected/denied — CAL-04):**
**UNANSWERED.** Not reached.

**Item 8 (Google Calendar itself unchanged — CAL-03):**
**UNANSWERED.** Not reached.

**Anything that read like a fifth trap** (something that faked a broken build or a missing feature the way `CLAUDE.md`'s existing four traps do) — describe it here with what was on screen and when:
**YES — one, and it is worth adding to `CLAUDE.md` as a genuine fifth trap.**
**"Today shows today" faked a dropped recurring occurrence.** The owner moved a recurring occurrence
and it was **not on the Today timeline**, which read exactly like the event having been dropped
entirely. The orchestrator filed it as a bug (entry 9) and drew the serious conclusion that Phase 35
Assumption A1 was **disproven**. In fact the import was perfect — the moved instance landed on
**2026-10-13**, a week out, and Today only ever renders today. **The absence was correct behaviour
rendered by a screen that is scoped to a single day.**
Shape it shares with the existing four traps: *the data was right, the screen was right, and the
inference drawn from looking at the screen was wrong.* The thing that broke the loop was **not** more
looking — it was reading the device's Hive directly. **Any future judgement about whether a calendar
occurrence imported must name the date it should land on and look at THAT day, or read the box.**

**Overall verdict:** **NOT APPROVED — the sitting was stopped partway by the owner's own call, and
two real defects stand.**

**What failed, and what each leaves unmet:**

| Finding | Requirement left unmet |
|---|---|
| **Entry 7** — `sync()` passes `calendarIds: const []` and `iosCalendarSource()` builds `DeviceCalendarSource()` with no ids, so the plugin resolves empty to *every calendar*. Ticks are persisted and rendered but never reach the device source. Proven from device Hive: one id ticked, ≥4 calendar ids imported. | **CAL-02 VIOLATED.** Google's half was wired (entry 5); the device half never was. |
| **Entry 8** — all-day events import as blocking `08:00–22:00`. **Six working days erased** in a 12-day window: Vacation, a 38th Birthday, Fall break, **Payday**, Indigenous Peoples' Day, Columbus Day. | The schedule is unusable in normal use. **Now RULED — `D-36-05` (2026-10-06) supersedes `D-35-06`: all-day events are skipped and disclosed, never imported.** Not a duplicate of entry 7 and not fixed by fixing it — `Payday` lands on a calendar nobody would untick. |
| **Entry 10** — the skipped-events disclosure exists and is tested, but the owner did not notice it and asked for "a reminder at the top." | Not missing — **not discoverable.** Raised from real use. **Fixing entry 8 without entry 10 trades six visible fake blocks for one invisible omission**, because the disclosure becomes the only way a dropped Vacation is ever communicated. |

**What PASSED and should not be re-litigated:** Phase 35 **Assumption A1 is verified on real
hardware** (A4.1) — the highest-value result of the sitting, and it **confirms** rather than reverses
`36-DECISIONS.md`'s Correction on the record. Item 1 / CALAUTH-01 passed on the simulator. Item 3's
Cancel half passed.

**What a re-visit must cover, in priority order:** (1) re-verify entries 7, 8 and 10 are fixed;
(2) **A4.2 — delete an occurrence provably inside the 14-day window and record the date**, the one
Section A item whose data was inconclusive rather than merely uncollected; (3) A1, A5, A6; (4) Section
B items 2, 4, 5, 7, 8 — all of which need a completed Google sign-in; (5) item 3's swipe-dismiss half,
which needs a real finger. **Item 6 should be dropped for this owner** unless the OS-level account
situation changes.

**One open question no device data answers yet**, flagged by `D-36-05` and repeated here because it
directly threatens the validity of the next sitting: the six all-day blocks are **already persisted
`CommitmentBlock` records**. A sync that stops *importing* all-day events is not the same as one that
*prunes* what an earlier sync already wrote. **If they are not pruned, the next UAT must not judge a
day that still holds them** (`CLAUDE.md` trap #4), and the owner needs either a migration or an
explicit instruction.
