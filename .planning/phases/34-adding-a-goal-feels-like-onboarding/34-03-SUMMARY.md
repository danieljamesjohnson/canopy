# Phase 34-03 — UAT Build & Script — SUMMARY

**Completed:** 2026-09-08
**Plan:** `34-03-PLAN.md` (Wave 3)
**Status:** Complete — awaiting the owner's verdict on `34-UAT.md`

---

## Deviation from the plan, stated up front

**This plan was executed by the orchestrator directly, not by a dispatched `gsd-executor`.**

The project's dispatch isolation resolves to `harness-worktree`, and the isolation guard refuses a
`gsd-executor` dispatch without `isolation="worktree"`. That is correct for the two code waves and
they both ran that way. It is *wrong* for this plan: 34-03's whole job is to build the app and leave
a server running on port 8143 for the owner to open. A build produced inside a throwaway worktree
serves bytes from a directory that is deleted at merge, so the URL would have died the moment the
wave was cleaned up.

So the build, the port handling, and the live verification were performed on the primary checkout by
the orchestrator, and this SUMMARY was written by the party that actually did them. Dispatching a
subagent to author a SUMMARY about work it had not performed would have produced a less truthful
artifact, which is the opposite of the point.

---

## What was done

### Suite re-verified on the exact tree that was built
- `flutter analyze` — **clean**
- `flutter test` — **740 passing** (706 at phase start; +13 from 34-01, +12 from 34-02, +9 from the
  post-review race fixes)

### Port 8143 cleared, and its death verified rather than assumed
A stale server **was** listening (`python3 tools/serve-uat.py 8143`, pid 1229272) — the plan
predicted this and it was true. Killed, then confirmed gone with `ss -ltn | grep 8143` returning
empty *before* starting the new one. This port has been squatted twice before; the check is the
point, not the kill.

### Build
`flutter build web --debug --source-maps --pwa-strategy=none` → `build/web/main.dart.js`, 13.7 MB,
single bundle. Debug on purpose (readable stack traces over load speed, per CLAUDE.md).

### One thing the plan did not predict, checked rather than assumed
`flutter_service_worker.js` **was present in `build/web/` despite `--pwa-strategy=none`**, with a
timestamp from this build — which looks exactly like trap #1 (a service worker poisoning the origin)
waiting to happen.

It is inert. Verified two ways rather than reasoned about: `index.html` contains **zero** references
to `serviceWorker`, and a headless Chromium boot of the served page reported
`navigator.serviceWorker.getRegistrations()` → **0**. The file is emitted but never registered, so
it cannot cache anything and cannot collide. No action taken; recorded so the next agent who sees
that file does not re-investigate it or "fix" it.

### Served, and proven reachable the way the owner will reach it
`python3 tools/serve-uat.py 8143 --dir build/web`, started with the sandbox disabled so the socket
actually binds all interfaces.

| Check | Result |
|---|---|
| `ss -ltn \| grep 8143` | `0.0.0.0:8143` ✓ (not `127.0.0.1`) |
| `curl http://100.108.146.112:8143/` (tailscale IP) | **200** ✓ |
| `curl http://127.0.0.1:8143/` | 200 — *proves nothing on its own, recorded for contrast* |
| `curl … /main.dart.js \| grep -c 'Just added'` | **1** ✓ |
| bundle sha256, disk vs wire | `b479e2c449f0b0bf…` — identical ✓ |

`'Just added'` is the probe string because it is new to `lib/` in this phase. `'Add your own'` and
`'Add a goal'` already existed and would have false-positived — a grep that cannot fail proves
nothing, which is the same discipline this phase applied to its test assertions.

---

## The feature was driven and looked at before being handed over

CLAUDE.md's rule is to look at the running app rather than claim it works. Playwright's text finders
are useless against Flutter's canvas rendering, so this used the project's own driver
(`.planning/spikes/001-live-row-in-a-true-grid/tools/drive.cjs`), which onboards a persistent profile
and taps through the semantics tree.

Path driven: onboarding → Today → Goals → `+ Add goal` → "Something to make time for" → tap
`Reading`. Screenshots committed to `shots/`.

**What that confirmed live, not just in tests:**

1. **The emoji reaches the model.** The Today timeline renders the chunk as `🏃 Exercise` — it is on
   the `Goal`, not decoration on a chip.
2. **The picker filters what you already have.** `Exercise` was absent from the grid because it
   already existed as a goal.
3. **"Add your own" is a button, not a text field** — the deleted quick-add control was not
   reintroduced.
4. **One tap creates, with nothing in between** (ruling (a)): the chip vanished, a `Just added` card
   appeared, and the goal was already at rank 2 in the list behind the sheet.
5. **The GOALADD-03 mitigation is real on screen**: both the `Just added` card and the Goals list row
   read `3.0 hrs/week` on their face.

---

## What is NOT settled, and is the owner's to judge

The five points above are structural — "is the control there", "did the value land" — and a browser
can answer those, so it did. **None of them answer whether the flow feels right, and no number of
green tests will.** That is what `34-UAT.md` asks for, and it is deliberately short:

- whether it feels like onboarding (item 1)
- the thumb count on five chips, **as a digit** (item 2) — this question has produced five
  non-answers across two phases by being phrased as "does it work"
- whether the budget on the card is *noticed*, not merely present (item 3)
- whether "add your own" as a button instead of a field is an acceptable trade (item 4)
- accept/reject on the two visible changes the owner did not ask for: onboarding's chip family and
  emoji, and `Walk` → `Walk outside` (items 5 and 6)

---

## Files

- `.planning/phases/34-adding-a-goal-feels-like-onboarding/34-UAT.md` — the script
- `.planning/phases/34-adding-a-goal-feels-like-onboarding/shots/` — four driven screenshots
- No `lib/` or `test/` changes in this plan.
