# Open questions for Dan

## 2026-08-24 — Two UAT verdicts needed; Phase 31 is blocked on the first

**Autonomous run stopped here.** Phases 29 and 30 are both code-complete and verified; Phase 31
cannot start until you judge Phase 29.

### What you need to do

Open **`http://danserver:8143/`** and **tap ⟳ Re-check-in first.** Nothing below means anything
until you do — the app only runs the scheduling engine at check-in, so an already-generated day is
never rebuilt on load. That is exactly what wasted a round trip on 2026-08-21. It is now trap #4 in
CLAUDE.md.

Then make sure today has a committed `Work` block spanning a couple of hours (add one on the
Commitments screen and re-check-in if not) — both phases are about what happens inside one.

One build serves both UATs. Record verdicts in:

- `.planning/phases/30-breaks-in-committed-time/30-UAT.md` — **are the breaks there?** Phase 30 put
  breaks inside committed blocks for the first time. This is the symptom you reported twice.
- `.planning/phases/29-breaks-you-can-see/29-UAT.md` — **does a 5-minute break read as a break?**
  Or does it read as a divider / a separator / the edge of the card above it? A near-miss is a fail
  here — that reading is the exact complaint that opened Phase 29.

### Why Phase 31 is blocked and not just pending

Phase 31 ("Breaks You Can Skip") attaches a swipe gesture to the 20dp sub-compact hairline. Its
ROADMAP entry says outright: *"Do not start until Phase 29's UAT verdict is recorded — if that
verdict changes the sub-compact layout, it changes what this phase attaches a gesture to."*

If your answer to Phase 29 item 1 is "that reads as a divider," the layout changes and any Phase 31
planning done first is thrown away. So the gate is honoured rather than worked around.

### After you record the verdicts

- Both pass → `/gsd-verify-work 29`, `/gsd-verify-work 30`, then `/gsd-autonomous --from 31`
- Something reads wrong → say so plainly; it routes to a gap-closure plan, not an inline patch
