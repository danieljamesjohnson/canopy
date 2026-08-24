# Phase 30 Plan 05 — Human UAT

**Served at:** `http://danserver:8143/`
**Debug build** (`flutter build web --debug --source-maps --pwa-strategy=none`), served via
`python3 tools/serve-uat.py 8143 --dir build/web` (never `python3 -m http.server` — CLAUDE.md trap
#3). Port 8143 has served debug builds only, across this phase and Phase 29 — never a release
build, so trap #1 (service-worker collision) cannot apply here.

The prior listener on 8143 (a stale server left running from Phase 29's UAT session, PID 704702)
was killed before this build was served, so the owner is not being handed a three-day-old bundle.

## Pre-flight — served bytes match built bytes, and contain this phase's change

```
$ sha256sum build/web/main.dart.js
84ef9419281e1f5dc2161e1ab0277b242a10fc2a294a376f7a3356d1be3794b0  build/web/main.dart.js
$ curl -s http://localhost:8143/main.dart.js | sha256sum
84ef9419281e1f5dc2161e1ab0277b242a10fc2a294a376f7a3356d1be3794b0  -
$ curl -s http://localhost:8143/main.dart.js | grep -c buildCommitmentChunks
3
```

**Identical hashes, non-zero grep.** The build you are about to judge is the build that was just
compiled, and it contains this phase's change.

---

## STEP 0 — MANDATORY, DO THIS FIRST: tap ⟳ Re-check-in

Nothing below is meaningful until you do this. The app reads today's schedule from Hive
(`ScheduleNotifier._loadToday()`) and only runs the scheduling engine at check-in
(`ScheduleGeneratorService.generate()`), so a day that was already generated is never rebuilt on
load — you would be judging a pre-fix day. **This is exactly what happened on 2026-08-21:** a false
failure, a wasted round trip, and the real bug survived another three days until you reported the
identical symptom a second time on 2026-08-24. This is now trap #4 in CLAUDE.md's UAT trap list, for
exactly this reason. Re-check-in first. Every time.

## STEP 1 — make sure today has a committed block

If your day has no `Work` block (or similar) spanning at least a couple of hours, add one on the
Commitments screen and re-check-in again. This whole phase is about what happens *inside* a
committed block, so a day without one proves nothing.

---

## What automation already proved, and why you're still being asked

597/597 tests pass, `flutter analyze` is clean, and the arithmetic is proven to the minute in both
`30-GREEN-wave2.txt` (generator path) and `30-GREEN-final.txt` (notifier path — the second entry
point, adding an event mid-day). This is integer minute math, the same trustworthy category as
Phase 28, which needed no human gate at all.

The reason for this checkpoint is not that the math is in doubt — it's that **you have reported
this exact symptom twice** (2026-08-21 and 2026-08-24), and only a screenshot of a real generated
day, seen by you, closes that credibly.

---

## Item 1 — Breaks inside the block

Between the work chunks inside your committed block, is there a break? There should be a short
break after every 25 minutes of work — the same rhythm the rest of your day already has.

**Verdict:**

## Item 2 — Your appointment did not move

Does the block still start and end at exactly the times you entered? Not a minute earlier, not a
minute later, not rounded to the half hour. This is the one thing that must not have changed.

**Verdict:**

## Item 3 — A long break, if the block is long enough

On a block of roughly four hours or more, is there also one full 30-minute break partway through
(two of them on a six-hour block, at a normal mood)? If your block is short, skip this one and say
so.

**Verdict:**

## Item 4 — The 5-minute breaks read as breaks

Can you tell at a glance that a 5-minute break is a break — not a divider, not a sliver, not a
mystery line?

This is Phase 29's outstanding question, which has been waiting for a day that actually has breaks
in it to look at (see `29-UAT.md`'s correction note). Answer it here, against a day that now has
breaks inside its committed block — but the verdict itself gets recorded against Phase 29
separately, via `/gsd-verify-work 29`, not in this file.

**Verdict:**

---

## Confirmation

**Did you tap ⟳ Re-check-in before judging any of the above (Step 0)?**

**Verdict:**

---

If anything reads wrong, say what you saw rather than what you think caused it — that gets routed
to a gap-closure plan, not patched inline. A NO on any item is not a failure of this UAT process;
it's exactly what this checkpoint exists to catch.

Reply with a yes/no for each of the four items (item 3 may be "skipped — block too short"), plus
confirmation that you tapped ⟳ Re-check-in first. Say **"approved"** to close Phase 30, or describe
what you saw for anything that reads wrong.
