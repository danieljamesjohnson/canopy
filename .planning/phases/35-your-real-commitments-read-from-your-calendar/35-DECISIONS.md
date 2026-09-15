# Phase 35 — Owner rulings on the two planned checkpoints

**Ruled:** 2026-09-14, by the owner, before execution started.
Both plans deliberately stopped for these. Neither was inferable from the code.

---

## D-35-05 — ICS stack: `enough_icalendar` + `rrule`

**Ruling: `enough_icalendar` (parse) + `rrule` (expand). NOT `firstfloor_calendar`.**

The plan's own recommendation was "look at both pub.dev pages first, so this is an observation rather
than a judgment on metadata." That was done, and it turned up a **third option the research and the
plan had both missed**: `getInstances()` — the expansion API the architecture needs — belongs to
`rrule` (JonasWanke), a dedicated RRULE library, not to `enough_icalendar` itself. So the real choice
was never "one SUS package vs. one parser that cannot expand."

What the pages actually said:

| | `firstfloor_calendar` | `enough_icalendar` | `rrule` |
|---|---|---|---|
| Weekly downloads | **52** | 7.55k | **128k** |
| Likes / stars | 5 / **2 stars, 0 forks** | 9 | 94 / 58 stars |
| Pub points | 160 | 140 | 150 |
| Last release | 58 days | 12 months | 8 months |
| Publisher | firstfloorsoftware.com | enough.de | wanke.dev |
| Publisher vs repo owner | **MISMATCH — GitHub owner is `kozw`** | matches | matches |
| Web support | yes | yes | yes |

**The mismatch research flagged is real and still present** — it was worth re-checking rather than
inheriting, and it survived the re-check. On a repo that is public as a work sample, putting a
load-bearing path behind a 52-download package whose GitHub owner does not match its pub.dev
publisher is not defensible when a 128k-download alternative exists.

**What this ruling costs, recorded so it is not discovered mid-execution:**

1. **Two dependencies instead of one, and we own the seam between them.** `enough_icalendar` parses
   the `.ics` into a VEVENT model; `rrule` expands the RRULE. Nothing joins them for us.
2. **`rrule` requires `isUtc: true` on every supplied `DateTime`** — its README is explicit:
   *"rrule doesn't care about any time-zone-related stuff. All supplied `DateTime`s must have `isUtc`
   set to `true`."* This collides directly with `CommitmentBlock` storing **local wall-clock**
   minutes-from-midnight (confirmed twice — see the doc-comment defect below). **This is the SEED-006
   trap's exact shape**, and it is now a known, named boundary rather than a latent one. The
   local↔UTC conversion at that seam needs a test that actually fails when the conversion is wrong —
   and per D-35-08 that test must set `tz.local` explicitly, because a fixture that passes only
   because danserver's system zone is UTC proves nothing.
3. **Neither package handles `EXDATE` / `RDATE` / `RECURRENCE-ID`.** Neither did
   `firstfloor_calendar` in any documented way, so this is not a regression against the alternative —
   but it is unhandled by the chosen stack and must be either implemented or explicitly scoped out
   with the consequence stated. A moved or cancelled single occurrence is exactly the case a user
   notices.

**`rrule`'s stated limitations**, so no one rediscovers them: custom week starts (`WKST`) are not
supported — Monday only; no leap seconds; years outside 0–9999.

---

## D-35-06 — All-day events: imported as a blocking commitment

**Ruling: import an all-day event as a commitment that blocks the day.** The owner chose the literal
reading over the recommended skip-and-disclose.

**The recommendation was NOT taken, and the reasoning that was offered against this option still
stands as a known cost:** one all-day `Vacation` entry blanks that day's schedule. That is the
accepted trade, not an oversight — it was on screen when the ruling was made.

### ⚠ An ambiguity in how this was asked, recorded rather than silently resolved

**The question was built badly and the fault is the orchestrator's, not the owner's.** The chosen
option's *label* read "Import as a full-day block", but its *description* said "covering the whole
working day" and its *preview* rendered `08:00–18:00`. A true all-day block (`00:00–23:59`) and a
working-window block are different behaviours, and the label pointed at one while the description and
preview pointed at the other.

**Resolution taken: the description and the preview agree with each other, so they win.** An all-day
event becomes a commitment spanning **the user's configured waking/working window**, not `00:00–23:59`.
Two reasons beyond majority-of-wording:

- It is what the owner actually had in front of him. The preview showing `08:00–18:00` is the concrete
  artifact he judged; the label is the part he could not see the consequences of.
- A literal `00:00–23:59` commitment window would hand `schedule_generator.dart` a 24-hour window,
  which is not a shape any existing test or fixture covers — and the generator is explicitly out of
  scope for this phase.

**This must be confirmed by the owner in the UAT, not treated as settled.** The relevant history is
in `STATE.md`: `SEED-007` survived a 12/12 verification because `GOALADD-03` was amended mid-phase
while its `must_haves` had already been written against the old wording. *A requirement amended after
its must_haves are written does not retroactively widen them.* The same shape of error is available
here, so the UAT must show the owner a real all-day event on a real timeline and ask whether the span
is what he meant — as a distinct item, not folded into a general "does it look right".

### What the plans must now change

`35-02`'s current `must_haves` and Task 1 are written for the **opposite** ruling — they assert an
all-day entry does *not* become a blocking commitment and appears in the skipped list with the reason
"All-day — not imported automatically". Those are now wrong and must be rewritten against this
ruling before execution, not patched afterwards. The UI-SPEC's locked copy for the skipped-events
disclosure remains correct for its other uses (short events, zero-duration, no-end-time) and is not
deleted — only the all-day row leaves it.

---

## Unchanged by either ruling

- **CAL-03 stands absolutely.** Nothing writes to the user's calendar under either decision.
- **`schedule_generator.dart` is still out of scope.** An all-day event that blocks the day does so by
  producing an ordinary `CommitmentBlock` the existing generator already understands. If honouring
  this ruling appears to require touching the generator, that is the signal the mapping is wrong, not
  the generator.
- **The doc-comment defect is still to be fixed** in the same commit as the two new fields:
  `lib/data/models/commitment_block.dart:29,33` claim UTC; no `.toUtc()` exists anywhere and the only
  writer uses local wall-clock via `showTimePicker`. Confirmed independently by both the researcher
  and the pattern mapper. D-35-05's UTC boundary above makes fixing this comment more load-bearing,
  not less — `rrule` genuinely does want UTC, so a stale comment claiming the field already is UTC is
  now actively dangerous.

---

## Folded in — WINDOWS.md entry 2 (TZID / floating time) → plan 35-02

**Owner instruction, 2026-09-15: "fold the TZID gap into 35-02 and keep going."**

The tracer (`35-01`) proved exactly one of RFC 5545's three `DTSTART` forms — and it proved the wrong
one to be confident about. A real Google Calendar feed emits
`DTSTART;TZID=America/Chicago:20260302T140000` with a `VTIMEZONE` block; the tracer's only fixture is
`Z`-suffixed UTC, which a Google feed will rarely produce.

| Form | Meaning | After 35-01 | After 35-02 |
|---|---|---|---|
| `...T140000Z` | absolute instant | ✅ proven | proven |
| `;TZID=America/Chicago:...T140000` | instant in a named zone | ❌ **the Google form** | must be proven |
| `...T140000` (bare) | floating — "2pm wherever you are" | ❌ falls through to system-local | must be proven |

**The defect:** for a non-`Z` value, `enough_icalendar` returns a `DateTime` with `isUtc == false`
constructed against **the machine's real system timezone**, not the app's injected `tz.local`. Every
other date path in this app goes through `tz.local`; this is the one that silently disagrees.

**Why this specific gap is dangerous to test, and the reason it earns a third mutation proof:**
danserver's system timezone is **UTC**, so for the floating case `tz.local`-correct and
system-local-correct produce **identical numbers here**. A test written without explicitly setting a
non-UTC `tz.local` passes on this machine whether or not the bug exists, and fails on the owner's
phone. That is `SEED-006` exactly — 3248 green lines that only ever exercised the one input where the
bug could not fire. The plan now requires that the floating-case mutation be *observed to fail*, and
says out loud that a mutation producing no failure on danserver means the test is not discriminating
and must be rewritten — not recorded as "no change observed".

**Closing rule, so this cannot be closed by having been looked at:** `gsd-tools windows fixed 2` runs
only if both new truths are green AND both were mutation-proven. Otherwise entry 2 stays open and the
SUMMARY names which forms remain unproven.

**WINDOWS.md entry 1 (`EXDATE` / `RDATE` / `RECURRENCE-ID`) is NOT folded in and stays open.** It is a
genuine capability gap — neither chosen package provides it, so it is ours to write — and it was
scoped honestly rather than hidden. A moved or cancelled single occurrence of a recurring event still
appears at its original time. `35-02`'s existing `must_have` asserting MOVED/EXDATE behaviour is
therefore still at risk of passing vacuously, which the plan already flags as the phase's most
important honesty requirement.

---

## ⚠ CORRECTION — danserver's system timezone is `America/Chicago`, NOT UTC

**Recorded 2026-09-15. The wrong claim is the orchestrator's, and it is in committed artifacts.**

`35-01-PLAN.md`, `35-02-PLAN.md`, this file's earlier sections, and both wave-2 executor prompts all
assert — as a load-bearing fact — that *"danserver's system zone is UTC, so a fixture that passes only
because of that proves nothing."* **The reasoning was right. The fact was wrong.**

```
$ timedatectl
Time zone: America/Chicago (CDT, -0500)
```

**How it was caught, which is the part worth keeping.** `35-02`'s floating-time mutation proof
*refused to pass on its first attempt*. The plan predicted that mutation might produce no failure
(because UTC would make the correct and buggy paths agree) and instructed the executor to treat a
no-change result as a non-discriminating test. Instead it failed properly — which was only possible
because the machine is **not** UTC. The instruction that would have caught a fake proof is what
surfaced the bad premise behind it.

**What this changes, and what it does not:**

- **It does not invalidate any test.** Every timezone test in this phase sets `tz.local` explicitly
  rather than relying on ambient system zone — which is what the plans demanded for the *wrong*
  reason but the right outcome. `35-02`'s proofs stand.
- **It does change the standing advice.** Do NOT write "danserver is UTC so this can't discriminate"
  into a future plan. The opposite is true: an America/Chicago host will *expose* naive local-time
  bugs rather than mask them, which makes this box a better place to catch them than previously
  assumed — but also means a test that accidentally relies on ambient zone will pass here and fail in
  CI or on a UTC host. **Set `tz.local` explicitly either way.**
- **It is worth checking beyond this project.** Other lanes on danserver may carry the same stale
  assumption. Not fixed here — `~/.claude/CLAUDE.md` is outside this repo and is not this phase's to
  edit.

**The general lesson, which is the reusable part:** the UTC claim was never verified — it was asserted
confidently by the orchestrator, repeated across four artifacts, and inherited by two subagents as
given. `timedatectl` takes one second and was never run until a test disagreed with the premise. This
repo's documented failure mode is assertions that cannot fail; this is its sibling — **premises that
were never checked**, propagated by confident repetition.
