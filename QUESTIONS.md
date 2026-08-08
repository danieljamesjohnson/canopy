
## Phase 24 (where-am-i) — waiting on Dan's perceptual verdict

**Asked:** 2026-08-08
**Blocking:** plan 24-03 (autonomous: false), and therefore phase 24 verification/completion.

Plans 24-01 and 24-02 are shipped and committed (500/500 tests, analyze clean). The now-marker
renders end-to-end. The one thing no test can settle is whether it actually answers "where am I"
at a glance — which is the reason this phase exists.

**Look at:** http://danserver:8123/  (your existing Canopy data — debug bundle, same origin as
phases 22/23 UAT). Clean-slate fallback with no data: http://danserver:8840/

**Judge:**
1. Between activities — can you find "now" without reading the header line?
2. Is the stale "Free until <past time>" row gone once its window has closed?
3. During a live activity — no "Now" rule duplicating the live card?
4. Pre-start / after day-complete — marker in the right place?
5. Loud enough to find, quiet enough not to compete with the live card?

**Reply with:** "approved", or what's wrong (too faint / wrong position / shows when it shouldn't /
still doesn't answer the question) and which check failed.
