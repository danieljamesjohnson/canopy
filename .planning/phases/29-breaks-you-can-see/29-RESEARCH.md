# Phase 29: Breaks You Can See - Research

**Researched:** 2026-08-20
**Domain:** Flutter/Material 3 layout — a new density tier for a duration-exact timeline row, plus
a real-browser pixel-measurement recipe to set its threshold constant.
**Confidence:** HIGH (source facts, all file:line verified against the actual tree) / MEDIUM (the
measurement recipe's exact numbers, which cannot be known until executed) / LOW (none — no
claim in this document rests on unverified training knowledge alone).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **Option (1), a sub-compact density tier, is the chosen approach** (owner's call, 2026-08-20).
  Below a measured threshold (~24dp), render the break as a single hairline-with-label rather than
  a card. This follows Phase 27's own precedent exactly — tiers driven by slot height — and keeps
  the grid exact.
- **Option (2) — render short breaks as the bare gap between work cards, label on tap — was
  rejected.** It loses the "you're on a break" affordance the Phase 27 spike explicitly valued when
  it rejected option (b).
- **Option (3) — raise `kPixelsPerMinute` — was rejected.** At 8.0 a break would be 40dp, but this
  doubles the day's scroll length; Phase 27 worked specifically to make the day *shorter* (it bought
  back 132dp). Do not revisit without new evidence.

**Constraints the plan must honour:**
- Measure the threshold in a real browser, not in `flutter test`. Record the raw number, the
  method, and the conditions that would invalidate it — the doc-comment house style
  `kCompactLiveMinHeight` already uses.
- Do not buy legibility with grid accuracy. A regression test must assert no chunk's rendered
  height deviates from `durationMinutes × kPixelsPerMinute`.
- The work card's own 26dp overflow must be resolved, not left unexamined — decide whether it is
  real on-device or a harness artifact, and either fix it or explicitly dismiss it with evidence.
- This phase MUST end in a `checkpoint:human-verify` task. It cannot close on automated
  verification alone (two independent reasons automation lies here: `flutter test`'s placeholder
  font, and headless Chromium's `CONTEXT_LOST_WEBGL`).

### Claude's Discretion

Everything else — the exact sub-compact layout, the constant's name, where the tier switch lives,
task decomposition — is at Claude's discretion. Use the ROADMAP phase entry, the success criteria,
and codebase conventions to guide the decisions.

**Note:** the UI-SPEC (`29-UI-SPEC.md`, approved 6/6 dimensions) has already exercised this
discretion in full — exact widget tree, constant name (`kSubCompactBreakMinHeight`), file location,
copy, semantics, and scope boundary are all settled there. This research does not re-open any of
those; it supplies the HOW (build/measure/test mechanics) the UI-SPEC assumes but does not itself
contain.

### Deferred Ideas (OUT OF SCOPE)

None — discuss phase skipped.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SEEBREAK-01 | Every break is identifiable as a break at its duration-exact height, with no clipped content | "Architecture Patterns" (exact current-state source facts + the UI-SPEC's already-approved sub-compact widget), "Code Examples" (measurement recipe reused from Phase 27) |
| SEEBREAK-02 | The true grid is preserved: rendered height never deviates from `durationMinutes × kPixelsPerMinute` | "Common Pitfalls" (painted-rect vs. self-referential-arithmetic test distinction), "Code Examples" (the `measure_hours.py` UNIFORM proof), "Validation Architecture" |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- **Host the DEBUG build, not release**, for UAT — `flutter build web --debug --source-maps
  --pwa-strategy=none`, served with `python3 tools/serve-uat.py <port> --dir build/web`. Never
  `python3 -m http.server` (no `Cache-Control` header → stale-bundle trap).
- **Flutter/Dart are not on PATH** in a non-login shell: prefix every shell call with
  `export PATH="$PATH:/home/dan/development/flutter/bin"`.
- **Node/Playwright are nvm-only:** `export NVM_DIR=$HOME/.nvm && . $NVM_DIR/nvm.sh` then
  `NODE_PATH=$(npm root -g)` before any `node drive.cjs …` call (Playwright is a global install,
  not a project dependency).
- **Three traps that fake a broken build** (all documented in CLAUDE.md, all directly relevant to
  this phase's real-browser measurement step):
  1. **Service-worker cache collision** — never reuse a port across build types. `--pwa-strategy=none`
     never registers a SW, so it cannot *create* this collision, but a leftover SW from a prior
     release build on the same port still will.
  2. **Headless Chromium `CONTEXT_LOST_WEBGL`** — repeated headless launches exhaust the GPU and
     blank the CanvasKit paint. Mitigate with `--use-gl=swiftshader --enable-unsafe-swiftshader` on
     every Chromium launch (already baked into `drive.cjs`).
  3. **Stale browser cache via `python3 -m http.server`** — always use `tools/serve-uat.py`, which
     sends `Cache-Control: no-store` and strips `If-Modified-Since`/`If-None-Match`.
- **Never build an Artifact; host locally on the tailnet** (`http://danserver:<port>`) — irrelevant
  to this phase's mechanics but binding for any interim demo.
- **Product position:** Canopy is rule-based/deterministic by design — nothing in this phase implies
  or should introduce any LLM/AI surface; not at risk here (pure layout), noted for completeness.

## Summary

This phase adds one new `ChunkCardDensity.subCompact` tier to the existing three-tier break card
(`lib/screens/schedule/widgets/chunk_card.dart`), selected by `today_screen.dart` when a break's
slot height falls below a new constant `kSubCompactBreakMinHeight` (colocated in
`lib/screens/today/timeline_geometry.dart` next to the file's three existing density-threshold
constants). The exact widget, its copy, its semantics, and its scope boundary (breaks only; work
chunks get a documented, unreachable defensive fallback) are already fully specified and approved
in `29-UI-SPEC.md` — this document does not relitigate any of that.

What the UI-SPEC assumes but does not itself supply is the **execution mechanics**: (1) the exact,
reusable real-browser measurement recipe (Phase 27's `drive.cjs` + `measure_card_fill.py` +
`measure_hours.py` harness, which this phase should crib from verbatim rather than reinvent), (2)
the distinction between a geometric test that can actually fail (SEEBREAK-02's proof) and one that
silently re-derives the implementation's own arithmetic (the documented v1.5 failure mode this
project explicitly guards against), (3) resolution of the work-chunk 26dp-overflow question via
existing evidence already recorded in `kPixelsPerMinute`'s own doc comment, and (4) the concrete
pitfalls (Dart enum-switch exhaustiveness, `Divider` height/thickness semantics, port reuse) that
will bite during implementation.

**Primary recommendation:** implement the UI-SPEC's `_buildSubCompactBreak` widget and
`ChunkCardDensity.subCompact` enum value verbatim; reuse Phase 27's `tools/drive.cjs` (unmodified)
and adapt `measure_card_fill.py`/`measure_hours.py` (same band-detection method, new target) to
measure `kSubCompactBreakMinHeight` on a **fresh port (8143 — no build type has ever served there)**;
prove SEEBREAK-02 with the same style of arithmetic-ground-truth test
`today_timeline_model_test.dart`'s `"GRID-01: every hour boundary is equidistant"` test already
uses (assert against `60 * kPixelsPerMinute`, never against `yFor()`'s own internals); and treat the
work-chunk 26dp overflow as a harness artifact **by citing `kPixelsPerMinute`'s existing doc
comment** (already recorded: 70dp card + 8dp margin = 78dp measured in a real browser against a
100dp slot, 2026-08-18) rather than re-measuring from scratch — confirm with one screenshot, don't
re-derive.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Break density-tier selection (`isBreak` branch, slot-height comparison) | Browser / Client | — | Pure Flutter widget-tree logic in `today_screen.dart`'s `build()` dispatch; no network, no persistence. |
| Sub-compact break rendering (`_buildSubCompactBreak`) | Browser / Client | — | A `StatelessWidget` subtree painted by Flutter's own renderer (CanvasKit on web); no I/O. |
| `kSubCompactBreakMinHeight` threshold constant | Browser / Client | — | A compile-time Dart `const double`; its *value* is derived from a real-browser pixel measurement, but the constant itself is pure client-side layout data, never read from a server or config service. |
| Grid-accuracy invariant (SEEBREAK-02) | Browser / Client | — | `TimelineGeometry.heightFor()` is pure arithmetic on injected ints — the single minute-to-pixel authority (STATE.md carry-forward invariant), entirely client-side. |
| Measurement tooling (`drive.cjs`, `measure_card_fill.py`, `measure_hours.py`) | Dev tooling (outside runtime tiers) | — | Build-time/QA scripts that drive a headless browser against a locally served debug build; not shipped, not part of the app's own architecture. |

This is a single-tier client app for the surface this phase touches — there is no backend, no SSR,
and no persisted server-side state involved in rendering a break card. (Canopy's only persistence,
Hive, is untouched by this phase — `29-CONTEXT.md` explicitly scopes the schedule engine out.)

## Standard Stack

**No new packages this phase.** Everything needed (Flutter SDK `Divider`, `Row`, `Semantics`,
`CustomPaint`) already ships with the Flutter/Material 3 SDK already in use. The measurement
tooling reuses what Phase 27 already installed and committed:

| Tool | Version/Source | Purpose | Status |
|------|-----------------|---------|--------|
| Playwright | global npm install (already present, used by Phase 27) | Headless Chromium driver (`drive.cjs`) | [VERIFIED: local filesystem — `.planning/spikes/001-live-row-in-a-true-grid/tools/drive.cjs` runs against it, referenced by 27-04-SUMMARY.md's committed run] |
| Pillow (`PIL`) | system python3, 10.2.0 (per 27-04-SUMMARY.md's threat model) | Pixel-band measurement in `measure_card_fill.py`/`measure_hours.py` | [VERIFIED: local filesystem — both scripts already exist and run, see below] |
| `tools/serve-uat.py` | in-repo, committed | No-cache static server for the debug web build | [VERIFIED: local filesystem, read directly] |

No `pubspec.yaml`/`pubspec.lock` change is expected. Confirm with `git diff --exit-code pubspec.yaml
pubspec.lock` before closing the phase, per Phase 27's own threat-model precedent (T-27-SC).

### Alternatives Considered

Not applicable — no new dependency is being introduced or considered. The UI-SPEC's own "Design
System" table already states this ("Component library: Material 3 built-ins... no new widgets").

## Package Legitimacy Audit

Not applicable — this phase installs no new packages. `git diff --exit-code pubspec.yaml
pubspec.lock` must remain empty at phase close; if a plan ever proposes adding a dependency, that is
a planning error for this phase's stated scope.

## Architecture Patterns

### Current-state source facts (exact, file:line, verified against the tree at research time)

**`lib/screens/schedule/widgets/chunk_card.dart`** (note: NOT `lib/screens/today/chunk_card.dart` —
that path does not exist; the real file lives under `lib/screens/schedule/widgets/`, and
`29-UI-SPEC.md`'s own line references match this path exactly):

- `ChunkCardDensity` enum, lines 12-33: three values today — `detailed` (default, every field),
  `full` (title + time range + action row, no rationale/chips), `compact` (title only, single
  line, ellipsis). The UI-SPEC's `subCompact` is a **fourth** value to be added inside this same
  enum block.
- `ChunkCard.build()`, lines 96-116: a `switch (chunk.chunkType)` dispatches breaks to `_buildBreak`
  and work chunks to `_WorkChunkContent`. This switch is **not** the one that needs a new arm — it
  switches on `ChunkType` (3 values, unchanged), not `ChunkCardDensity`.
- `_buildBreak(BuildContext context)`, lines 129-217: currently branches on `density ==
  ChunkCardDensity.compact` (lines 137-161) for the compact tier's `Container` + `CustomPaint`
  dashed-outline treatment (margin `EdgeInsets.symmetric(vertical: 4)`, padding
  `EdgeInsets.symmetric(horizontal: 16, vertical: 0)`), falling through to the
  `detailed`/`full` treatment (lines 163-217, `margin: vertical 4`, `padding: vertical: isLong ? 24
  : 12`). **The UI-SPEC's new `subCompact` branch must be checked BEFORE this `compact` check** —
  confirmed the UI-SPEC's own pseudocode (line 82-89) does exactly this.
- `_DashedBorderPainter`, lines 220-273: the `CustomPainter` the sub-compact tier's `Divider`-based
  design deliberately avoids reusing — the UI-SPEC states no `CustomPaint` for this tier, which
  matches: a plain Material `Divider` is cheaper than a painter for a single hairline.
- `_WorkChunkContent`, lines 283-648: its own `density` switch is at lines 397-413 (the
  `contentPadding` switch is a *separate* exhaustive switch at line 346-359 — **both** must gain a
  `ChunkCardDensity.subCompact` arm, not just one). Both are Dart `switch` **expressions**
  (`switch (density) { ChunkCardDensity.x => ... }`), which are exhaustiveness-checked at compile
  time — see Pitfall 1 below.

**`lib/screens/today/timeline_geometry.dart`** (this file is real and matches the additional_context
exactly):

- `kPixelsPerMinute = 4.0` (line 56) — doc comment (lines 12-56) already records a **real-browser**
  measurement of the `full`-tier work card: 70dp measured card + 8dp Card margin = 78dp, against a
  100dp slot, ~22dp slack, measured 2026-08-18 via headless Chromium + `tools/serve-uat.py`. This is
  directly relevant to the ROADMAP item 4 (work-chunk 26dp overflow) — see "Verification obligation"
  below.
- `kFullTierMinHeight = 88.0` (line 72), `kFullBreakMinHeight = 88.0` (line 79) — both work-chunk and
  break-row Full-tier thresholds, expressed in pixels not minutes (PD-3: rot-resistant to a future
  `kPixelsPerMinute` change).
- `kCompactLiveMinHeight = 88.0` (line 150) — the **house-style doc-comment template** to match
  exactly for the new `kSubCompactBreakMinHeight`: date, viewport (`430`×930, DPR 1), method
  (headless Chromium `--use-gl=swiftshader --enable-unsafe-swiftshader`, debug build via
  `tools/serve-uat.py` on a named port), raw measured number + explicit safety margin, relationship
  to any numerically-close sibling constant (Pitfall 6's "decide explicitly" rule — see Pitfall 3
  below), and a "what would invalidate this value" paragraph. This constant's own history (84.0 →
  re-measured to 88.0 after a touch-target fix raised the action row) is the concrete precedent for
  "measurements can and do get invalidated by a later, unrelated change — re-measure, don't assume."
- `TimelineGeometry.yFor()`/`heightFor()` (lines 302-321): pure, branch-free arithmetic — `heightFor`
  computes `yFor(start+duration) - yFor(start)`, and `kTimelineEdgePadding` cancels out of that
  difference by construction. **This phase's new density branch changes nothing here** — SEEBREAK-02
  is protected by construction as long as no new code changes what `slot`/`height:` receives.

**`lib/screens/today/today_screen.dart`** (density-selection call site, exact as additional_context
described):

- Lines 786-795: `isBreak` boolean, then a ternary picking `full`/`compact` for breaks (line
  789-792) and a separate ternary for work chunks (line 793-795, unchanged by this phase). The
  UI-SPEC's proposed nested-ternary replacement (adding a `slot >= kSubCompactBreakMinHeight ?
  compact : subCompact` branch) is a direct, mechanical edit to lines 789-792 only — the work
  branch at 793-795 is explicitly untouched, matching the UI-SPEC's "Scope boundary."
- Lines 802-817: the `Positioned(... ClipRect(... OverflowBox(... TimelineRowTile(child:
  _buildChunkCard(...)))))` wrapper (PD-10) — this is the safety net (not a min/max clamp) that
  currently silently swallows the short break's overflow. **Nothing about this wrapper changes** —
  the new tier's job is to make its *natural* height already fit inside the slot, so the safety net
  simply never engages for breaks anymore (though it stays in place, unconditionally, for every
  other row and for the still-possible-in-principle work-chunk edge case).
- The live-row arm (lines 748-784) is architecturally identical in shape (also `ClipRect` +
  `OverflowBox`) but is explicitly out of scope per `29-CONTEXT.md` — do not touch.

**`lib/screens/today/timeline.dart`**: `TimelineRow` sealed hierarchy (`ChunkRow`, `LeadingFreeRow`,
`GapFreeRow`, lines 13-52) is **unaffected** by this phase — a break is still a `ChunkRow`; only the
*density* passed to `ChunkCard` inside the existing `ChunkRow` render path changes. No new
`TimelineRow` subtype is needed, so the sealed-class exhaustiveness pitfall that bit Phase 24-01
(adding `NowMarkerRow`) does **not** apply here — flagging this explicitly so a future reader does
not go looking for a `TimelineRow` switch to update. (The switch that DOES need a new arm is the
`ChunkCardDensity` switch inside `chunk_card.dart`, a different sealed-ish construct — see Pitfall 1.)

**`lib/screens/today/widgets/timeline_row_tile.dart`**: `TimelineRowTile` (lines 97-120) is a pure
16dp-inset + `kGutterWidth`-reserved-blank-column wrapper — the sub-compact break renders *through*
this wrapper (per the UI-SPEC's "Horizontal insets" note), so it automatically inherits
`kGutterWidth` + `kTimelineRowInset` and must NOT add a second horizontal inset. Confirmed: nothing
in `today_screen.dart`'s call site (`TimelineRowTile(child: _buildChunkCard(context, chunk,
density))`, line 812-814) changes for this phase — the wrapper is applied uniformly regardless of
density.

### Existing tests that will move (found via `grep -rln "ChunkCardDensity\|_buildBreak\|kFullBreakMinHeight"`)

Only one test file references break-density behavior directly:
`test/screens/today_screen_test.dart`.

- **`group('ChunkCardDensity ...)')` → `group('break densities')`, lines 600-630.** Two tests:
  `'compact short break renders the label but not its duration text'` (line 601-614) and `'full
  short break renders both the label and its duration text'` (line 616-629). Both pump
  `ChunkCard(chunk: _breakChunk(type: ChunkType.shortBreak), density: ChunkCardDensity.compact/
  full)` directly — **neither exercises `today_screen.dart`'s selection logic**, so neither breaks
  when the selection ternary gains a third branch. But a new test in the same style (`density:
  ChunkCardDensity.subCompact`) is the natural place to assert the new tier's content (label
  present, no `CustomPaint`, no `Card`, has exactly one `Divider` pair) — mirroring this file's own
  established per-density-per-widget-type test shape.
- **`testWidgets('SwipeableChunkCard forwards density on the break early-return path ...)', lines
  632-651.** Regression guard for `SwipeableChunkCard` forwarding `density` through the break
  early-return path — this pattern (pump `SwipeableChunkCard` with an explicit `density:`, assert
  the break content) is the template for a `subCompact`-forwarding regression test too, since
  `swipeable_chunk_card.dart` forwards `density` at two call sites (lines 80 and 132, both already
  generic — no `ChunkCardDensity`-specific branching there, confirmed via grep — so this file likely
  needs **no code change**, only a new forwarding test for symmetry with the existing one).
- **No existing test directly exercises `today_screen.dart`'s density-selection ternary
  (lines 786-795) against a break at a specific slot height** — the file's `ChunkCard` tests all
  pump `ChunkCard` in isolation with an explicit `density:` parameter, never through the full
  `today_screen.dart` render path with a computed `slot`. This is a genuine coverage gap the new
  `kSubCompactBreakMinHeight` tier-boundary test should close, mirroring the `LiveRowCard` tier-
  boundary test at lines 759-772 (`'tier boundary: kCompactLiveMinHeight is compact, one dp below is
  single-line'`) — that exact shape (pump at the boundary value, then boundary−1, assert the flip)
  is the established pattern for a threshold test in this codebase and should be reused for
  `kSubCompactBreakMinHeight`.
- **`test/screens/today_timeline_model_test.dart`** (pure `test()`, no widget pump) is where the
  SEEBREAK-02 grid-accuracy assertion belongs, following its own `"GRID-01: every hour boundary is
  equidistant"` test (lines 440-477) as the template — see "Common Pitfalls" Pitfall 4 for exactly
  what makes that test meaningfully able to fail vs. not.
- **`test/screens/lattice_break_pair_test.dart`** (added by Phase 28 for D-06, two consecutive break
  chunks) is a plausible second place to extend — it already fixtures a short-break-then-long-break
  pair through the full render path; worth reading if the plan wants a two-break-in-a-row rendering
  regression test, though it was not required reading for this research pass.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| "Divider with a centered label" idiom | A custom `Row` of two `Container`s + manual `Expanded` sizing, or a `CustomPainter` | Material's built-in `Divider(height: 1, thickness: 1)` inside a `Row` with `Expanded` on both sides (exactly as `29-UI-SPEC.md` already specifies) | `Divider` already handles theming (`DividerThemeData`), respects `colorScheme`, and its `height`/`thickness` split is exactly the lever needed (`height` = the widget's own box height *including* default padding, `thickness` = the drawn line width) — [VERIFIED: local Flutter SDK source, `packages/flutter/lib/src/material/divider.dart` lines 56-92: `height`/`thickness` are both nullable, falling back to `DividerThemeData`/`_DividerDefaultsM3`]. Setting both explicitly to `1` collapses the box to exactly its stroke, which is the whole trick the UI-SPEC relies on to fit a 20dp slot. |
| Real-browser pixel measurement of a rendered card's natural height | A bespoke screenshot-diffing script, or trusting `flutter test`'s `tester.getSize()` | Phase 27's already-committed `measure_card_fill.py` (derived-fill-colour band detection) and `measure_hours.py` (derived-background label-band detection), both under `.planning/spikes/001-live-row-in-a-true-grid/tools/` and `.planning/phases/27-true-grid/tools/` | Both scripts already solve the two hard sub-problems (deriving a background/fill colour from the image so the script survives a theme change, and bridging small gaps so a stroke crossing the region doesn't split one band into two) — reinventing either risks reproducing the exact colour-derivation bug 27-04-SUMMARY.md already found and fixed (naive "most saturated colour" picks the wrong fill when a darker button outnumbers a lighter card region in raw pixel count). |
| Headless-browser driving / onboarding / clock control | A new Puppeteer/Selenium script | `.planning/spikes/001-live-row-in-a-true-grid/tools/drive.cjs`, reusable **unmodified** | Already solves: semantics-tree-based clicking (Flutter web has no DOM to `querySelector`), persistent-profile reuse (so onboarding runs once and every screenshot session sees the identical generated day), and precise clock control via `localStorage['flutter.dev_clock_offset_micros']` (bypassing the debug UI's coarse ±1h buttons). `--at=HH:MM` is exactly the lever this phase needs to park on an instant inside a live/adjacent short break. |
| A no-cache static file server for the debug build | `python3 -m http.server` (the CLAUDE.md trap #3 footgun) or a new server script | `tools/serve-uat.py <port> --dir build/web` (already in-repo) | Sends `Cache-Control: no-store` and strips conditional-request validators — the only thing that reliably prevents the stale-bundle failure mode that has already cost this project a round trip once (Phase 25 UAT). |

**Key insight:** every tool this phase's measurement step needs already exists, committed, in this
repo from Phase 27. The task is to **drive** those tools at a new target (a break's slot instead of
the live row's slot) and a **new port**, not to build new tooling.

## Common Pitfalls

### Pitfall 1: Dart `switch` expression exhaustiveness — TWO switches need the new arm, not one

**What goes wrong:** `chunk_card.dart` has two separate `switch (density)` **expressions** on
`ChunkCardDensity` inside `_WorkChunkContent`: the `contentPadding` switch (lines 346-359) and the
content-builder switch (lines 397-413). Both are exhaustiveness-checked by the Dart compiler the
moment `ChunkCardDensity` gains a fourth value — this is a **compile error**, not a lint, per the
same mechanism Phase 24-01 hit adding `NowMarkerRow` to a sealed-class switch (STATE.md: "Dart's
sealed-class switch-statement exhaustiveness is a compile error, not a lint, so the app failed to
build the moment the fourth subtype existed").

**Why it happens:** `ChunkCardDensity` is a plain `enum`, and Dart enum-switch-expression
exhaustiveness (not just sealed-class exhaustiveness) has applied since Dart 3's pattern-matching
switch expressions — adding a fifth `case`/arm requirement is silent until compile time, and the
build simply fails with no runtime symptom to chase.

**How to avoid:** Grep `switch (density)` in `chunk_card.dart` before considering the enum-add
task done — there must be exactly two hits, both updated. The UI-SPEC already specifies the content
these should route to for `subCompact` in `_WorkChunkContent` (a defensive, currently-unreachable
fallback — see UI-SPEC "Scope boundary" point 3). `_buildBreak`'s own `if (density ==
ChunkCardDensity.compact)` check (line 137) is an `if`, not a `switch` — it does NOT get an
exhaustiveness error if left unmodified, so the sub-compact `if` branch must be added explicitly
and checked *before* the `compact` check (as the UI-SPEC's pseudocode already shows), or `subCompact`
density silently falls through to the `detailed`/`full` rendering path with no compiler warning at
all.

**Warning signs:** `flutter analyze`/`flutter build` fails with "The type 'ChunkCardDensity' is not
exhaustively matched" — expected and easy; the *silent* failure mode (an `if`-chain missing the new
case with no compile error) is the one to actually watch for in code review.

### Pitfall 2: `Divider`'s `height` is a box height, not the stroke width — both parameters must be set

**What goes wrong:** `Divider`'s default `height` (when unset) falls back to `DividerThemeData.space`
(Material 3 default `16.0`), meaning the widget reserves 16dp of vertical box space even though the
drawn line itself is only `thickness` (default `1.0`) tall, centered inside that box. If a plan
implements the sub-compact tier's `Divider` without both `height: 1` and `thickness: 1` explicit,
the row's cross-axis extent balloons to (16dp × 2 + the text's own height) instead of just the
text's own height — silently reproducing a version of the exact "8dp of margin nobody zeroed"
defect the UI-SPEC's "Root cause" section already diagnosed for the *previous* compact tier.

**Why it happens:** `height`'s name is misleading — a first read suggests it controls the drawn
line's thickness, when it actually controls the surrounding layout box (`thickness` is the actual
line width). [VERIFIED: local Flutter SDK source, `packages/flutter/lib/src/material/divider.dart`
lines 63-92 & 191-192.]

**How to avoid:** The UI-SPEC's own code sample already sets both explicitly
(`Divider(height: 1, thickness: 1, color: theme.colorScheme.outlineVariant)`) — implement it exactly
as specified, do not "simplify" to a bare `Divider(color: ...)`.

**Warning signs:** the sub-compact row measures taller than expected in a real-browser screenshot,
or `Row`'s cross-axis extent (set by its tallest child per `CrossAxisAlignment.center`) is dominated
by the `Divider`s rather than the `Text`.

### Pitfall 3: A numerically-close sibling threshold constant needs an explicit "kept separate" decision

**What goes wrong:** This file already has a documented rule (Pitfall 6 in `27-RESEARCH.md`,
enforced by `kCompactLiveMinHeight`'s own doc comment) that a new density-threshold constant landing
within ~2-4dp of an existing one must explicitly state whether it is being collapsed into that
sibling or kept separate, with a stated reason — silently adding a near-duplicate constant with no
cross-reference is the one outcome flagged as unacceptable both times this happened before
(`kFullTierMinHeight`/`kCompactLiveMinHeight`, both landed at `88.0` twice, by coincidence, and the
doc comment says so explicitly both times).

**Why it happens:** `kSubCompactBreakMinHeight`'s placeholder target is `24.0` — far enough from
`kFullBreakMinHeight` (`88.0`) that this specific pair is not at risk, but the *measured* value
could land anywhere; if it lands near `kFullTierMinHeight`/`kCompactLiveMinHeight` (both `88.0`)
or `kNowLineHeight`/`kHourAxisHeight` (`28.0`/`20.0`) by chance, the same rule applies.

**How to avoid:** After measuring, check the new value's distance from every other constant already
in `timeline_geometry.dart` and state the relationship explicitly in the doc comment, exactly as
`kCompactLiveMinHeight`'s own comment (lines 112-128) does for its coincidental match with
`kFullTierMinHeight`.

**Warning signs:** two constants within ~4dp of each other, neither doc comment mentioning the
other.

### Pitfall 4: A grid-accuracy ("painted-rect") test that cannot fail is worse than no test

**What goes wrong:** STATE.md's binding carry-forward invariant: "v1.5 shipped two defects behind
green tests, both assertions that could not fail — one scoped to the wrong widget type, one
counting widgets instead of checking painted rects." The SEEBREAK-02 regression test is exactly the
kind of assertion at risk of this failure mode, because the *easy*, wrong way to write it is to
assert `heightFor(start, duration)` against `duration * kPixelsPerMinute` **using the
implementation's own `heightFor` method** — which can never fail, because `heightFor` computes
exactly that by construction (see `timeline_geometry.dart` lines 318-321). That test would pass even
if `_buildSubCompactBreak` itself silently inflated the row's rendered height (e.g. via a stray
non-zero margin, per Pitfall 2) — Flutter's `Positioned(height: slot)` box constrains the outer box,
but a child that overflows it and gets silently clipped by `ClipRect` produces an *identical*
`heightFor()` return value regardless of what actually painted.

**Why it happens:** `TimelineGeometry.heightFor()` is pure arithmetic — asserting it against itself
proves the arithmetic is self-consistent, not that the *rendered* row matches it. This is the exact
same self-referential-blindness trap `27-VALIDATION.md`'s "The load-bearing split" already names,
and the fix Phase 27 used is the template: `today_timeline_model_test.dart`'s
`"GRID-01: every hour boundary is equidistant, even with a live chunk present"` test (lines 440-477)
asserts against **`60 * kPixelsPerMinute`, a ground-truth literal derived independently of any
implementation-internal quantity** — explicitly commented "this must NOT re-derive any
implementation-internal quantity ... or it inherits the same self-referential blindness."

**How to avoid:** Two complementary tests, not one:
1. A **pure-arithmetic** test in `today_timeline_model_test.dart`, in the same style as the existing
   GRID-01 test — assert `geometry.heightFor(start, durationMinutes)` equals
   `durationMinutes * kPixelsPerMinute` (a ground-truth literal computed the same way the existing
   `heightFor` tests at lines 375-392 already do — these ARE legitimate, because they assert the
   geometry class's own contract, not a *rendered widget's* actual height) — this proves the SLOT
   never lies, at every density.
2. A **rendered-pixel** proof — re-run `measure_hours.py` (band-detection on hour labels, unrelated
   to any break's own content) against a screenshot taken while a short break renders at
   `subCompact` density, and confirm it still prints `UNIFORM`. This is what proves the *painted*
   grid — not just the arithmetic behind it — stays true, mirroring 27-04-PLAN.md Task 2's own
   closing step exactly ("Run `measure_hours.py` ... against a screenshot taken with the sub-compact
   tier rendering — confirm it still prints `UNIFORM`. This is the SEEBREAK-02 proof in pixels, not
   just arithmetic").

Neither alone is sufficient: (1) alone cannot detect a widget that overflows its box and gets
silently clipped; (2) alone cannot pin the exact arithmetic relationship or run in <1s per commit.

**Warning signs:** a new test whose only assertion path traces back to `TimelineGeometry`'s own
method being called and compared to itself; a PR that "proves" SEEBREAK-02 with zero screenshots.

### Pitfall 5: `flutter test`'s placeholder font — do not size or judge legibility from a widget test

**What goes wrong:** `flutter test`'s font has no real Roboto metrics (`kGutterWidth`'s own doc
comment: `'1'`, `'i'`, `'W'`, `':'`, `'p'` all measure exactly 12.0px at fontSize 12 — every glyph a
fixed-width box). Any *text-driven* measurement taken there is a harness bound, not a device
requirement — this project has been burned by exactly this three times (`kGutterWidth` 46→75→52,
`kPixelsPerMinute` 4.0→5.5→4.0, `kCompactLiveMinHeight`'s own two-pass history 84.0→88.0).
SEED-005's own "52dp natural height" figure for the (old) compact break tier is explicitly flagged
in the seed as a harness bound for exactly this reason.

**How to avoid:** `kSubCompactBreakMinHeight` MUST be set from a real-browser pixel measurement
(headless Chromium via `drive.cjs`), never from `tester.getSize()`. Geometric assertions
(`heightFor` vs. arithmetic — Pitfall 4's item 1) stay legitimate in `flutter test` because they
never touch text metrics; anything that would require rendering a `Text` widget and reading its
actual pixel extent does not.

**Warning signs:** a doc comment for `kSubCompactBreakMinHeight` citing a `flutter test`
`tester.getSize()` call as its source.

### Pitfall 6: Port reuse — CLAUDE.md trap #1, with a specific list of already-burned ports

**What goes wrong:** Reusing a port that has ever served a different Flutter build type (debug vs.
release) risks a stale service-worker serving a mismatched shell — a blank page that looks exactly
like a broken build.

**Already-used ports found in this repo** (grep across `.planning/`): `8080`, `8095`, `8096`,
`8097`, `8101`, `8123`, `8131`, `8132`, `8133`, `8134` (spike UAT, permanently reserved per
`CONVENTIONS.md`), `8137` (Phase 27's debug port, "now, and going forward, a debug-build-only port
for this project", per `27-04-SUMMARY.md`), `8142` (used for the SEED-005 diagnosis session that
raised this very phase), `8788`, `8840`. **`8143` has never appeared anywhere in `.planning/` or the
working tree** [VERIFIED: `grep -rn "8143" .` returned no hits] — recommend this phase claim `8143`
as its dedicated debug-only port, following the same incrementing convention Phase 27 used
(`8134` → `8137`).

**How to avoid:** pick an unused port, confirm with a repo-wide grep before first use, and never
reuse it for a release build afterward.

### Pitfall 7: `drive.cjs`'s onboarding assumes a fresh IndexedDB profile per port — the generated day is not guaranteed to match any prior run

**What goes wrong:** 27-04-SUMMARY.md's own deviation log: a fresh port's onboarding regenerates a
random day (mood/goal RNG), so a plan that hard-codes a specific clock time (e.g. "park at 08:25 for
the first short break") may find nothing live at that instant if the generated day differs.

**How to avoid:** Follow 27-04's own resolution exactly — drive first with `--dump` (prints the
semantics tree as JSON) or inspect a screenshot to confirm what is actually live/adjacent at the
chosen instant, and if the day differs, pick an *equivalent* instant (e.g. "N minutes into whichever
short break the generated day contains") and record which instant was used and why, renaming
evidence files to match the actual times rather than keeping planned placeholder names.

## Code Examples

### The reusable measurement recipe (adapted from Phase 27's `27-04-PLAN.md` Task 1, verbatim
method — target changed from the live row's compact tier to the break card's compact tier)

```bash
# 1. Build & serve (debug, never release; fresh dedicated port 8143)
export PATH="$PATH:/home/dan/development/flutter/bin"
flutter build web --debug --source-maps --pwa-strategy=none
python3 tools/serve-uat.py 8143 --dir build/web &   # background

# 2. Sanity-check served bytes before trusting any screenshot (CLAUDE.md trap #3)
curl -s http://localhost:8143/main.dart.js | grep -c 'Short break'   # must be non-zero

# 3. Drive to an instant with a live-adjacent SHORT break in view (fresh profile, this port
#    has never onboarded before). measure the COMPACT tier's own natural height — since compact
#    is unreachable at any duration the current lattice generates, force it via a throwaway
#    debug route or a --dart-define gate, per 29-UI-SPEC.md's step 6 options (a)/(b).
export NVM_DIR=$HOME/.nvm && . $NVM_DIR/nvm.sh && NODE_PATH=$(npm root -g)
node .planning/spikes/001-live-row-in-a-true-grid/tools/drive.cjs \
  http://localhost:8143/ /tmp/canopy-p29-profile \
  .planning/phases/29-breaks-you-can-see/shots/compact-break-forced.png \
  --at=08:10   # or whatever instant lands a short break in view; verify, don't assume

# 4. Pixel-count the compact tier's own natural height (adapt measure_card_fill.py's
#    band-detection approach — fill colour becomes the dashed outline's stroke region or the
#    Container's own background, whichever is more reliably distinguishable; do not reuse the
#    primaryContainer-specific filter verbatim, that was tuned for the LIVE row's fill, not the
#    non-live break card's outline).
python3 .planning/phases/29-breaks-you-can-see/tools/measure_break_compact.py \
  .planning/phases/29-breaks-you-can-see/shots/compact-break-forced.png

# 5. Set kSubCompactBreakMinHeight = measured height, ROUNDED UP to the nearest 4dp
#    (per 29-UI-SPEC.md: "does it fit", round toward the safer larger value, no separate margin).

# 6. Rebuild with the new constant, re-serve, re-drive to a SHORT break instant, and prove
#    SEEBREAK-02 in pixels:
python3 .planning/spikes/001-live-row-in-a-true-grid/tools/measure_hours.py \
  .planning/phases/29-breaks-you-can-see/shots/uniform-subcompact-break.png
# must print VERDICT: UNIFORM
```

### The painted-rect-capable SEEBREAK-02 test pattern (arithmetic half — ground truth, never
implementation-internal), modeled directly on the existing GRID-01 test

```dart
// test/screens/today_timeline_model_test.dart — new test, same file, same style as the
// existing 'GRID-01: every hour boundary is equidistant' test (lines 440-477).
test(
    'SEEBREAK-02: a break at every density renders at exactly '
    'durationMinutes * kPixelsPerMinute — ground truth, not self-reference', () {
  final geometry = TimelineGeometry.forDay(
    nowMinutes: 550, firstStartMinutes: 480, lastEndMinutes: 1020,
  );
  // 5-minute short break -> subCompact tier at the current lattice's slot.
  expect(geometry.heightFor(540, 5), 20.0); // literal, not `5 * kPixelsPerMinute`
  // 30-minute long break -> full tier.
  expect(geometry.heightFor(600, 30), 120.0); // literal, not `30 * kPixelsPerMinute`
});
```

Note the deliberate use of **literal pixel values** (`20.0`, `120.0`) rather than
`5 * kPixelsPerMinute` in the expected side — asserting against the constant multiplied out is
still one step removed from full ground truth (it locks in "5 minutes is however many pixels
`kPixelsPerMinute` currently says," not "5 minutes is 20 pixels"). Either form is legitimate for
this specific test (both are arithmetic on the SAME formula the implementation uses for `heightFor`,
which is the class's own honest contract) — the failure mode Pitfall 4 warns against is a test that
calls `_buildSubCompactBreak` or pumps the actual widget and then asserts its rendered `Positioned`
height against `heightFor()`'s own return value, which proves nothing about what actually painted.

## State of the Art

Not applicable in the "industry trend" sense — this is an internal, one-off layout fix to an
existing bespoke timeline component, not a library upgrade or ecosystem shift. The relevant "state
of the art" is entirely this project's own accumulated precedent (Phase 27's density-tier pattern,
measurement harness, and doc-comment house style), all of which is catalogued above.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Port `8143` is genuinely unused anywhere relevant (only checked `.planning/` and the working tree via grep, not e.g. a running process on the machine outside this repo) | Common Pitfalls, Pitfall 6 | Low — if occupied, the `serve-uat.py` bind will simply fail loudly at startup; no silent-corruption risk. Trivial to pick a different unused port if so. |
| A2 | `swipeable_chunk_card.dart`'s two `density:` forwarding call sites (lines 80, 132) need no code change for `subCompact` to pass through correctly (confirmed via grep that neither site branches on the specific `ChunkCardDensity` value) | Architecture Patterns, "Existing tests that will move" | Low-medium — if a hidden branch does exist elsewhere in that file (not found in the targeted grep), the sub-compact tier could silently fail to render through the swipe wrapper. The planner should have the executing agent re-grep the full file, not just the two known lines, before treating this as settled. |
| A3 | The work-chunk 26dp overflow (ROADMAP item 4) is a harness artifact, per `kPixelsPerMinute`'s existing doc-comment measurement (70dp card + 8dp margin = 78dp against a 100dp slot) — this document recommends confirming with ONE fresh screenshot rather than re-deriving from scratch, but does not itself take that screenshot | Summary; "Validation Architecture" § Phase Requirements → Test Map (ROADMAP item 4 row) | Medium — `29-UI-SPEC.md` already states this same default-with-caveat explicitly and requires the plan's real-browser step to confirm or refute it with a screenshot of a standard 25-minute work chunk; this research inherits that requirement rather than resolving it, since no build was run during this research pass. |

**If this table is empty:** N/A — see above.

## Open Questions

1. **Exactly which mechanism forces the `compact` break tier to render for measurement, given it is
   unreachable under the current lattice?**
   - What we know: `29-UI-SPEC.md` step 6 offers two explicit options — (a) a `--dart-define`-gated
     debug affordance forcing one break row to `compact` density regardless of slot (mirroring the
     `/gsd-spike` pattern), or (b) rendering `ChunkCard` at `compact` density standalone
     (unconstrained height) in a throwaway debug route, pixel-measuring it there.
   - What's unclear: which of the two is cheaper to build and tear down cleanly for a single
     one-off measurement (as opposed to Phase 27's spike, which needed three persistent variants).
   - Recommendation: (b) is likely simpler for a single measurement — no `--dart-define` plumbing,
     no `variants.patch` bookkeeping — a throwaway debug route that just pumps
     `ChunkCard(chunk: <short-break-fixture>, density: ChunkCardDensity.compact)` inside an
     unconstrained `Scaffold` body, screenshotted once, then deleted. Record which was used, per the
     UI-SPEC's own instruction.

2. **What exact fill/stroke colour should `measure_break_compact.py`'s band-detection filter target
   for the (non-live) break card, since `measure_card_fill.py`'s existing filter is tuned
   specifically for the live row's `primaryContainer` fill?**
   - What we know: the `compact`/`full` break tiers use a `CustomPaint` dashed **outline** (
     `colorScheme.outlineVariant`, not a filled background) — there is no solid fill region to scan
     for the way the live row has one. `measure_hours.py`'s approach (derive the most common
     "differs from background" colour in a scan strip, treating ANY sufficiently-different pixel as
     "ink," grouping into bands) is architecturally closer to what a dashed-outline card needs than
     `measure_card_fill.py`'s saturated-fill-colour approach is.
   - What's unclear: whether a dashed (non-continuous) outline produces clean enough contiguous
     "ink" rows for `measure_hours.py`'s exact gap-bridging (`<=3` rows) to work unmodified, or
     whether the dash gaps are wide enough to need a larger bridge tolerance.
   - Recommendation: start from `measure_hours.py`'s derive-background-then-flag-differing-pixels
     method (not `measure_card_fill.py`'s saturated-fill method), and empirically check the bridge
     tolerance against the first real screenshot before trusting the printed band height.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | build/test/analyze | ✓ | 3.44.1 per `28-VALIDATION.md`'s recorded framework version; not on PATH in non-login shells, prefix `export PATH="$PATH:/home/dan/development/flutter/bin"` | — |
| Playwright (global npm) | `drive.cjs` headless driving | ✓ | already used successfully by Phase 27, 2026-08-18/19 | — |
| Node (nvm-managed) | Playwright runtime | ✓ | resolves via `export NVM_DIR=$HOME/.nvm && . $NVM_DIR/nvm.sh` | — |
| python3 + Pillow | `measure_card_fill.py`/`measure_hours.py` | ✓ | Pillow 10.2.0 per 27-04-SUMMARY.md's threat model, system python3, no venv needed | — |
| `tools/serve-uat.py` | no-cache static serving | ✓ | in-repo, committed | — |
| Port `8143` | dedicated debug UAT port for this phase | ✓ (unused) | — | pick any other confirmed-unused port if this one is later found occupied |

No missing dependencies. Nothing in this phase requires new environment setup beyond what Phase 27
already established and left in place.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` (bundled with Flutter SDK) — already wired, 579 passing tests today [VERIFIED: `flutter test` run during this research pass, 2026-08-20, `+579: All tests passed!`] |
| Config file | none — standard `flutter test` discovery over `test/` |
| Quick run command | `flutter test test/screens/today_timeline_model_test.dart test/screens/today_screen_test.dart` |
| Full suite command | `flutter test` |
| Estimated runtime | quick: a few seconds (two files); full: ~26s per this research pass's own run (579 tests) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SEEBREAK-01 | `subCompact` renders label + no `Card` + no `CustomPaint`, distinct from `compact`/`full` | widget | `flutter test test/screens/today_screen_test.dart` | ✅ existing file, new test group |
| SEEBREAK-01 | `today_screen.dart`'s density selection picks `subCompact` below the new threshold, `compact` at/above it (tier-boundary test, same shape as the existing `LiveRowCard` boundary test) | widget | `flutter test test/screens/today_screen_test.dart` | ✅ existing file, new test |
| SEEBREAK-01 | Sub-compact tier's accessibility label restates the duration (`'$title, N min'`) | widget | `flutter test test/screens/today_screen_test.dart` (`ensureSemantics()` pattern, mirrors `LiveRowCard`'s single-line-tier semantics test) | ✅ existing file, new test |
| SEEBREAK-02 | `heightFor()` at every density equals the literal duration-implied pixel height (ground truth, not self-reference) | unit | `flutter test test/screens/today_timeline_model_test.dart` | ✅ existing file, new test |
| SEEBREAK-02 | Rendered grid stays `UNIFORM` in pixels with a sub-compact break present | manual-assisted (scripted, but requires a real browser — cannot run inside `flutter test`) | `python3 .../measure_hours.py <screenshot>` | ❌ Wave 0 — needs the new port + a rebuilt debug bundle before this can run; not a `flutter test` file |
| ROADMAP item 4 (work-chunk 26dp) | 25-minute work chunk's rendered height stays inside its 100dp slot, no `ClipRect` clipping visible | manual-assisted (real-browser screenshot + visual confirmation) | screenshot via `drive.cjs`, inspected with the Read tool | ❌ Wave 0 — one screenshot, not yet taken during this research pass |
| Human UAT (locked constraint) | A 5-minute break reads as *a break*, not a divider, to a human eye | manual | `checkpoint:human-verify` task, served build opened by a human | N/A — cannot be automated, per the locked constraint |

### Sampling Rate

- **Per task commit:** `flutter test test/screens/today_timeline_model_test.dart
  test/screens/today_screen_test.dart` (targeted, fast)
- **Per wave merge:** `flutter test` (full suite, baseline to beat: 579 green, `flutter analyze`
  clean — confirmed current as of this research pass)
- **Phase gate:** full suite green AND `flutter analyze` clean AND `measure_hours.py` prints
  `UNIFORM` against a screenshot with the sub-compact tier rendering AND the human
  `checkpoint:human-verify` task returns a recorded verdict — a green suite alone does NOT close
  this phase, per the locked constraint and Phase 27's own precedent (16/17 automated, 2/3 human
  items failed).

### Wave 0 Gaps

- [ ] `.planning/phases/29-breaks-you-can-see/shots/` — directory does not exist yet; create before
  the first screenshot.
- [ ] `.planning/phases/29-breaks-you-can-see/tools/measure_break_compact.py` (or equivalent,
  adapted from `measure_hours.py`'s derive-background approach per Open Question 2) — does not
  exist yet, needs writing before Task 1's measurement step can run.
- [ ] A mechanism to force the `compact` break tier to render despite being unreachable under the
  current lattice (Open Question 1) — must be built and torn down as part of the measurement task,
  not a standing framework addition.
- [ ] No `pytest`/JS test framework gaps — `flutter_test` is fully wired and green already; no
  framework install needed.

## Security Domain

**`security_enforcement` is not set to `false`** in `.planning/config.json`, so this section is
included per protocol — but this phase's actual surface has essentially no security-relevant
behavior to assess.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Not touched — this phase is pure client-side layout, no auth surface exists in this app at all (single-user local Hive storage, no accounts). |
| V3 Session Management | No | Not applicable — no session concept in this app. |
| V4 Access Control | No | Not touched. |
| V5 Input Validation | No | No new user input surface — breaks are engine-generated data, rendered read-only, no new form or text field. |
| V6 Cryptography | No | Not touched. |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Stale/mismatched debug bundle served to a human during UAT, mistaken for the current build | Spoofing (of build state, not identity) | The served-bytes `curl … | grep -c` sanity check before every screenshot/checkpoint, per Phase 27's own T-27-06 mitigation and CLAUDE.md trap #3 |
| Debug UAT server left running longer than needed, minor local information exposure | Information Disclosure | Loopback/Tailscale-only exposure (no public network path), matching Phase 27's own T-27-05 disposition (`mitigate`, accepted risk given the tailnet-only, no-secrets nature of a layout-only debug build); stop the background server once measurement is complete |

No other STRIDE-relevant pattern applies — this phase adds no network call, no new persisted field,
no new external package, and no new input surface.

## Sources

### Primary (HIGH confidence — read directly from the local filesystem/SDK during this research pass)

- `lib/screens/schedule/widgets/chunk_card.dart` — full file read, `ChunkCardDensity` enum,
  `_buildBreak`, `_WorkChunkContent`'s two density switches
- `lib/screens/today/timeline_geometry.dart` — full file read, all constants and `TimelineGeometry`
  methods, house-style doc-comment precedent
- `lib/screens/today/today_screen.dart` lines 600-839 — density-selection call site, PD-10 wrapper
- `lib/screens/today/timeline.dart` — full file, `TimelineRow` sealed hierarchy, `buildTimeline`
- `lib/screens/today/widgets/timeline_row_tile.dart` — full file, `kGutterWidth`/`kTimelineRowInset`
  house-style doc comments
- `lib/data/models/scheduled_chunk.dart` — `ChunkType` enum (grep-confirmed 3 values)
- `lib/screens/schedule/widgets/swipeable_chunk_card.dart` — grep-confirmed `density` forwarding,
  no branching
- `lib/screens/today/widgets/live_row_card.dart` — `Semantics` pattern precedent (line 296-298)
- `test/screens/today_screen_test.dart` — full file read, existing `ChunkCardDensity`/break tests
- `test/screens/today_timeline_model_test.dart` lines 360-478 — the GRID-01 equidistance test, the
  arithmetic-vs-self-reference distinction
- `.planning/phases/27-true-grid/tools/measure_card_fill.py` — full file read
- `.planning/spikes/001-live-row-in-a-true-grid/tools/measure_hours.py` — full file read
- `.planning/spikes/001-live-row-in-a-true-grid/tools/drive.cjs` — full file read
- `.planning/spikes/CONVENTIONS.md` — full file read, port/tooling conventions
- `.planning/phases/27-true-grid/27-04-PLAN.md` and `27-04-SUMMARY.md` — full files read, the exact
  precedent recipe and its real outcomes/deviations
- `.planning/phases/28-the-day-is-a-lattice/28-VALIDATION.md` — full file read, Validation
  Architecture format precedent
- `tools/serve-uat.py` — full file read
- `packages/flutter/lib/src/material/divider.dart` (local Flutter SDK install,
  `/home/dan/development/flutter/`) — `Divider.height`/`thickness` defaults, grep-confirmed
- `flutter test` run during this research pass (2026-08-20) — confirmed 579 tests green, current
  baseline
- `.planning/CONTEXT.md`, `.planning/UI-SPEC.md` (phase 29), `.planning/STATE.md`,
  `.planning/ROADMAP.md`, `.planning/seeds/SEED-005-*.md`, `./CLAUDE.md`,
  `.planning/config.json` — all read in full

### Secondary (MEDIUM confidence)

None — every claim in this document traces to a primary source read directly during this research
pass; no WebSearch or external documentation lookup was needed (this phase is entirely internal to
an already-well-documented codebase pattern).

### Tertiary (LOW confidence)

None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependency, every tool already exists and was read/verified in
  place.
- Architecture: HIGH — every file:line claim was read directly against the current tree, not
  inferred from the UI-SPEC's own (also-accurate) line references.
- Pitfalls: HIGH — each pitfall traces to either a compiler-enforced fact (Dart exhaustiveness,
  verified against SDK source), a local SDK source read (`Divider`), or a documented prior incident
  in this exact codebase (STATE.md carry-forward invariants, 27-04-SUMMARY.md's own deviation log).
- Measurement recipe: MEDIUM — the mechanics and tooling are HIGH confidence (proven to work,
  verbatim, by Phase 27), but the actual numeric outcome (the measured `kSubCompactBreakMinHeight`
  value) cannot be known until the recipe is executed; this is expected and matches Phase 27's own
  two-pass precedent (84.0 → 88.0).

**Research date:** 2026-08-20
**Valid until:** effectively indefinite for the architectural facts (stable until the next phase
touches these files) — but the port-availability claim (Pitfall 6 / A1) and the "no new package"
claim should be re-checked if planning is delayed by more than a few weeks, since other concurrent
work on this box could claim the port or add a dependency in the interim.
