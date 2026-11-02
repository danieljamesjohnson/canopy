---
phase: 36-connect-google-calendar-without-hunting-for-a-url
plan: 17
subsystem: uat-and-register
tags: [uat, windows-ledger, gap-closure, docs-only, CAL-02, CAL-04]
requires: [36-12, 36-13, 36-14, 36-15, 36-16]
provides:
  - "36-UAT-R3.md: round-3 device script (Step 0 + S1-S5 for WINDOWS entries 12, 13, 10, 11, 14)"
  - "WINDOWS.md: entries 10-14 open with what shipped and the R3 item that closes each; entry 15 added"
affects: []
key-files:
  created:
    - .planning/phases/36-connect-google-calendar-without-hunting-for-a-url/36-UAT-R3.md
  modified:
    - .planning/WINDOWS.md
key-decisions:
  - "Round-3 register policy: entries 10-14 all stay open until observed on the owner's iPhone (entry 10's reopening and entry 7's precedent), stated once in entry 10."
  - "Post-Disconnect Google residual recorded as its own entry 15 rather than absorbed into entry 11."
requirements-completed: [CAL-02, CAL-04]
completed: 2026-11-02
status: complete
commits: 2
plan_head_before: 6b670340264af7dfc37adffe086168ba9675a831
plan_head_after: dc8e68b117ef02bc5fc980ad03a2159c0b1db28a
actuals:
  tokens: 8400
  tasks: 2
  commits: 2
---

# Phase 36 Plan 17: Round-3 device script and register reconciliation Summary

A mandatory-Step-0 device script (`36-UAT-R3.md`, no URL of any kind) for the owner's next iPhone sitting, and a hand-edited `WINDOWS.md` that keeps entries 10-14 open against the R3 item that closes each and adds entry 15 for the post-Disconnect Google residual. Documentation only; no file under `lib/`, `test/` or `tools/` touched.

## Tasks

| # | Task | Commit |
|---|------|--------|
| 1 | `36-UAT-R3.md` | ec588cb |
| 2 | `WINDOWS.md` reconciliation | dc8e68b |

## What UAT-R3 asks

- **Step 0 (MANDATORY, first):** install (agent-driven profile build; phone unlocked and connected) -> look at Settings -> Calendars before tapping (S1's first observation) -> tick `spunkl` only -> Sync now -> Today -> **Re-check-in**. Binding sentence plus the 2026-08-21 trap-#4 precedent follow. Notes that the first sync may remove commitments of unticked calendars (entry 11 working).
- **S1 (entry 12):** list shows on re-enter, tab-switch and force-quit; never "Allow calendar access"; no iOS prompt.
- **S2 (entry 13):** Sync now -> greyed button with spinner -> "Synced just now - N commitments imported"; owner describes it in his own words.
- **S3 (entry 10):** asked cold; then persistence across leave/re-enter and force-quit; tap names the all-day entries. Fallback if nothing was skipped: add a throwaway all-day event on a ticked calendar.
- **S4 (entry 11):** (a) Goals -> top-right menu -> "Commitment blocks" (NOT Today, per R2's fifth trap): "Bi-Weekly One on One", Nov 12, Home, gone after the first sync (conditional on Home being unticked); (b) untick -> sync -> rows leave -> re-check-in -> re-tick returns them; (c) throwaway timed event tomorrow..~10 days out, created then deleted -> sync -> row gone. Today-limit stated.
- **S5 (entry 14):** untick/tick straight after opening, leave and re-enter, optionally with Google loading; stop and report if any tick lands wrong.
- Carried-forward R2 slots by label (R4, R5, A4.2, A5, A6, B2, B4, B5, B7, B8, B3 swipe half); B6 double-tick listed as untestable.
- Also tells the owner the device section is now ABOVE Google (reasoned, reversible) and that the build is agent-installed with no Xcode step.
- Blank "Your answers" section: Step 0, S1, S2, S3, S4 (a/b/c), S5, sixth trap, verdict.

## WINDOWS before / after (table, JSON and frontmatter agree; checked by script)

| | open | fixed | waived | total |
|---|---|---|---|---|
| before | 8 (1, 3, 4, 10-14) | 5 (2, 5, 6, 7, 8) | 1 (9) | 14 |
| after | 9 (1, 3, 4, 10-15) | 5 | 1 | 15 |

Checker (the plan's, run from a scratchpad file because the inline form is shell-escaped) printed `WINDOWS OK`: 15 table rows, 15 JSON objects, counts 9/5/1/15, entries 1-9 equal their `df106fe` objects, 10-15 open with null `resolved_at`, no pipe inside any table cell. `git diff -U0` was read hunk by hunk: frontmatter (3 lines), table rows 10-14 changed and 15 added, JSON descriptions 10-14 changed and object 15 added. Nothing else changed.

## Deviations from Plan

None in what was produced. Observations:

1. **No `gsd-tools` writer was run.** WINDOWS.md was backed up to the scratchpad and hand-edited with Edit; table and JSON were worded separately per row.
2. **Stale line in `CLAUDE.md` (not edited; out of this plan's file list).** The iOS section says the agent build "builds `--debug`, then `devicectl` installs". `tools/ios-build-agent.sh` now builds `--${CANOPY_BUILD_MODE:-profile}` (profile, because a debug Flutter app refuses to start on iOS 14+ without a debugger). R3 quotes the script's current mode, as the plan required. `CLAUDE.md` should be corrected by whoever next touches it.
3. **Two judgement calls inside S3/S4**, both flagged in the document: S3 gives a fallback if no all-day event exists to be skipped; S4(c) has the owner create a throwaway event and then delete it rather than delete a real one. S4(a) is conditional on Home being unticked, since a deliberately ticked Home should keep the block.
4. Task 2's plan-embedded checker uses `\$` escapes meant for a shell-quoted string; the same logic was run as a file with plain `$`, plus an added 12-cell-per-row check.

## Known Stubs

None.

## Threat Flags

None. T-36-59 (Step 0 first, mandatory, grep-gated), T-36-60 (all round-3 entries stay open, checker-asserted) and T-36-61 (hand edit, backup, diff read, checker) mitigated as planned.

## Self-Check: PASSED

- 36-UAT-R3.md exists; "Re-check-in" appears 7 times; zero matches for a URL scheme; all required strings present.
- ec588cb and dc8e68b are ancestors of HEAD; `git rev-list --count 6b67034..HEAD` was 2 before this summary commit.
- `git diff --name-only 6b67034..HEAD` listed only the two plan files before this summary.
- STATE.md and ROADMAP.md untouched.
