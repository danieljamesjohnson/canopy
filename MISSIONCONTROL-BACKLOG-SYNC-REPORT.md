# Mission Control — Backlog Sync Drift Report

**For:** the agent working on the backlog / mission-control board tooling
**From:** a session debugging Canopy's planning state (2026-06-12)
**TL;DR:** The Backlog.md board drifted out of sync with reality — two completed phases showed `To Do`. Fixing it surfaced three tooling problems worth your attention: (1) a **one-way, lossy projection** with no reconciler, (2) **hand-edits get silently re-synced away**, and (3) **the board is mostly untracked in git**. Details + repro below.

---

## What happened (the symptom)

In `backlog/tasks/`, every phase task was `status: Done` **except**:

- `task-2 - Phase-2-—-Goals-and-Commitments.md` → `To Do`
- `task-3 - Phase-3-—-Schedule-Generation-and-Morning-Check-In.md` → `To Do`

This was **false**. Phases 2 and 3 are unambiguously complete:

- Phase 2 has 6 plan summaries (`.planning/phases/02-goals-and-commitments/02-0{1..6}-SUMMARY.md`).
- Phase 3 has 5 summaries + `03-VERIFICATION.md`.
- The deliverables exist and are wired in code (`lib/screens/goals/goal_form_sheet.dart`, `lib/screens/commitments/commitments_screen.dart`, `lib/screens/schedule/checkin_screen.dart`, `lib/services/schedule_generator.dart`).
- **Logical proof:** the entire v1.1 milestone (phases 7–11, all marked `Done`) is built *on top of* phases 2 and 3. Phase 9 modifies the very `schedule_generator.dart` that phase 3 created; phase 7 fixes the check-in→generation loop from phase 3. Phases 7–11 being `Done` is impossible unless 2 and 3 were done first.

**Source of the bad state (hypothesis):** phases 2 and 3 predate the board being wired up, so their "Done" status was never projected from the phase artifacts onto the board. They've sat at the `default_status: "To Do"` (per `backlog/config.yml`) ever since.

## What we changed (so you're not confused by the diffs)

- `task-2` → `Done` (committed `70f6315`, then state held)
- `task-3` → `Done` via the `backlog` CLI (committed `c86d296`)

Both verified `Done` via `backlog task list --plain`. **All 11 phases now read Done.** No phase artifacts were touched — only the board was corrected to match them.

---

## Three tooling problems this exposed

### 1. The projection is one-way and lossy, with no reconciler
The real "is this phase done?" signal lives in the phase artifacts on disk (`SUMMARY.md` / `VERIFICATION.md` under `.planning/phases/NN-*/`). The board is a *projection* of that. But:
- The projection only seems to run forward at certain lifecycle moments, so phases completed **before** the board existed never got their status projected.
- There is **no reverse reconcile** — nothing ever asks "does the board disagree with the phase artifacts?" and corrects it. So drift, once introduced, is permanent and silent.

**Suggested fix:** a reconciliation pass (e.g. in `gsd-health` or the `gsd-roadmap-board` sync) that treats phase artifacts as the single source of truth and derives board status from them, **failing loudly on disagreement** rather than letting projections drift independently.

### 2. Hand-edits to task files get silently re-synced away
`backlog/.mc-managed` marks this as managed content. When we edited `task-3`'s `status:` field directly in the markdown, **a background sync reverted it** (the `updated_date` changed to a timestamp we didn't write, and `status` flipped back to `To Do`). Only editing via the `backlog` CLI (`backlog task edit 3 -s "Done"`) stuck.

**Why this matters:** a human (or agent) eyeballing the markdown will reasonably edit the file directly, see it "work," and then watch it silently revert — with no error or explanation. At minimum the managed layer should (a) warn on detecting a manual edit it's about to overwrite, or (b) treat a manual `status` change as an intent signal rather than discarding it.

### 3. The board is mostly untracked in git
`git status` showed **9 of 11 task files untracked** (`??`), along with `backlog/config.yml` and `backlog/.mc-managed`. Only the two files we explicitly committed are tracked. So:
- Board state isn't durable or reviewable in diffs.
- It can diverge from the committed `.planning/` artifacts with no trace.
- `config.yml` has `auto_commit: false`, which is consistent with this — but it means the board is effectively a local-only cache, not a versioned artifact.

**Open question for the human/owner:** should `backlog/` be tracked in git (so the board is a reviewable, durable projection), or is it intentionally local-only? If local-only, the GSD docs should say so, because the partial-tracking state (2 files in, 9 out) is the worst of both worlds.

---

## Repro (minimal)

```bash
# From a project where a phase completed BEFORE the backlog board was initialized:
backlog task list --plain          # observe early phase(s) stuck at "To Do"
# Confirm the phase is actually done:
ls .planning/phases/0N-*/          # SUMMARY.md / VERIFICATION.md present
# Note: editing the task .md's `status:` field directly gets reverted by the .mc-managed sync.
# Correct fix:
backlog task edit N -s "Done"
```

---

## Cross-reference

This is the GSD-level instance of a pattern also seen at the Canopy project level — see `.planning/seeds/SEED-001-engine-product-critique.md` finding #7 ("the tracking system isn't a reliable mirror of reality"). In this same session we also found v1.1's `REQUIREMENTS.md` checkboxes were stale (LOOP-01…05 marked Pending despite verified completion). **Three different trackers, same root cause: multiple unreconciled sources of truth for "done."**
