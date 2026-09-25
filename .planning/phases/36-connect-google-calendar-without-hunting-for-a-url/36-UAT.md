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

**Step 0 discipline — was ⟳ Re-check-in performed every time this document asked for it? (yes/no,
and note any time you skipped it):**

### Section A — Phase 35's device path

**A1 (permission dialog wording — true and unalarming?):**

**A2 (calendars grouped by account; Google account present?):**

**A3 (recurring event created, one occurrence moved, a different one deleted — confirm done):**

**A4 (moved occurrence at its NEW time / deleted occurrence ABSENT / ordinary week at base time — three separate answers):**

**A5 (permission off — app still fully usable, CAL-04):**

**A6 (Canopy changed nothing in your real calendar):**

### Section B — Phase 36

**Item 1 (Connect button present; Google's account picker appears — CALAUTH-01):**

**Item 2 (consent screen's exact wording on access level — CALAUTH-02):**

**Item 3 (Cancel button AND swipe-dismiss, recorded separately — Assumption A7):**

**Item 4 (Google calendars appear under their own heading; survives full app restart — Assumption A6):**

**Item 5 (revoked-token message AND offline message, recorded separately — were they different? — CALAUTH-03):**

**Item 6 (double-tick warning appears and reads clearly / meeting appears twice / goes back to once after unticking — your own words):**

**Item 7 (fully usable with everything disconnected/denied — CAL-04):**

**Item 8 (Google Calendar itself unchanged — CAL-03):**

**Anything that read like a fifth trap** (something that faked a broken build or a missing feature the way `CLAUDE.md`'s existing four traps do) — describe it here with what was on screen and when:

**Overall verdict:** *(type "approved" only if every item above passed; otherwise list which failed and which requirement each leaves unmet)*
