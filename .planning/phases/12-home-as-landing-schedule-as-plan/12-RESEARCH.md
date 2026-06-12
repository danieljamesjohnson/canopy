# Phase 12: Home as Landing, Schedule as Plan — Research

**Researched:** 2026-06-12
**Domain:** Flutter UI — navigation routing, Hive CE schema migration, Material 3 widget composition
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
None — discuss phase was skipped per `workflow.skip_discuss`.

### Claude's Discretion
All implementation choices are at Claude's discretion. Use ROADMAP phase goal, success criteria, and codebase conventions to guide decisions.

### Deferred Ideas (OUT OF SCOPE)
None.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| NAV-01 | After onboarding completes — and on any normal launch with onboarding done — the app lands on Home, not the Goals screen. | Single-line change in `router.dart` redirect: `return '/goals'` → `return '/home'`. Existing test in `router_redirect_test.dart` must be updated (one assertion) and a new test added for the post-onboarding → /home case. |
| NAV-02 | Home leads with the live day (current chunk + what's next); Home↔Schedule relationship is resolved. | HomeScreen refactor to show Now/Next sections + "See full schedule" TextButton. New `ActiveChunkCard` widget in `lib/screens/home/widgets/`. |
| SCHED-01 | Every chunk — discretionary and commitment — displays a real clock time instead of frequency metadata. | Requires `syntheticStartMinutes` persisted as `@HiveField(10)` + `displayStartMinutes` getter + `_formatTimeRange` helper in ChunkCard. Schema bump to version 7 with additive no-op migration. |
| SCHED-02 | Schedule surfaces a clear "now / next" framing anchored to the current time. | New inline `NowMarker` widget inserted in `ScheduleScreen ListView.builder` before first unresolved work chunk. |
| SCHED-03 | Complete and skip actions are clear, labeled affordances discoverable without hover. | Replace `_HoverableChunkContent` `AnimatedOpacity` hover overlay with always-visible `FilledButton.icon` + `OutlinedButton.icon` row. Existing hover test (`chunk_card_hover_test.dart`) must be updated to reflect the new always-visible pattern. |
</phase_requirements>

---

## Summary

Phase 12 is a focused UI rework with one data-layer change. The five requirements decompose cleanly into five independent implementation areas that can be parallelized across waves.

The only blocking dependency is the Hive schema change (SCHED-01): `syntheticStartMinutes` must become a persisted `@HiveField(10)` so clock times survive app restarts. Everything else — the router redirect (NAV-01), the schedule card actions (SCHED-03), the NowMarker (SCHED-02), and the HomeScreen active-day view (NAV-02) — can proceed independently once the schema is in place.

The current `schemaVersion` is 6 (confirmed from `lib/data/database/migrations.dart`). The UI-SPEC says to add `@HiveField(10)` and bump to schemaVersion 6, but the code is already at version 6 — the bump must target **schemaVersion 7** with a `_migration6to7` no-op entry appended to `_migrations`. The migration framework enforces `_migrations.length == currentSchemaVersion` at startup via an `assert`, so getting the count right is critical.

No new pub.dev packages are needed. All widgets use Material 3 primitives already in `pubspec.yaml`.

**Primary recommendation:** Work in the five-wave sequence defined in the UI-SPEC: schema → router → schedule cards → NowMarker → HomeScreen active-day view. Each wave is independently committable and testable.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Router redirect (NAV-01) | Frontend (go_router) | — | Pure routing logic; single redirect guard in `router.dart` |
| Home active-day view (NAV-02) | Frontend (widget) | ScheduleNotifier (Provider) | HomeScreen reads `ScheduleNotifier.todaySchedule`; new `ActiveChunkCard` widget owns layout |
| Clock time display (SCHED-01) | Data layer (Hive schema) + Frontend (widget) | ScheduleGeneratorService | Schema change persists `syntheticStartMinutes`; `ChunkCard` reads `displayStartMinutes` getter |
| Now/Next marker (SCHED-02) | Frontend (widget) | — | Pure UI widget inserted in `ScheduleScreen` ListView; no new provider state |
| Always-visible chunk actions (SCHED-03) | Frontend (widget) | ScheduleNotifier | `ChunkCard` wires to existing `markComplete`/`markSkipped` notifier methods |

---

## Standard Stack

No new packages. All dependencies already in `pubspec.yaml`.

### Relevant Existing Dependencies

| Library | Version in pubspec | Role in this Phase |
|---------|-------------------|--------------------|
| `hive_ce` | ^2.19.3 | Add `@HiveField(10)` to `ScheduledChunk`; bump schema |
| `hive_ce_generator` | ^1.11.1 | Regenerate `scheduled_chunk.g.dart` after field addition |
| `build_runner` | ^2.4.13 | Runs code generation |
| `go_router` | ^17.1.0 | One-line redirect fix |
| `provider` | ^6.1.5+1 | `context.read<ScheduleNotifier>()` for action wiring |
| `flutter_test` | sdk | Existing test framework |

**Installation:** No new packages — run `flutter pub get` if needed, then `flutter pub run build_runner build --delete-conflicting-outputs` after schema change.

---

## Package Legitimacy Audit

No packages added this phase. All dependencies are existing, verified packages already in use.

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| (no new packages) | — | — | — | — | — | — |

**Packages removed due to SLOP verdict:** none
**Packages flagged as suspicious:** none

---

## Architecture Patterns

### System Architecture Diagram

```
Cold launch / Onboarding done
         │
         ▼
  router.dart redirect
  onboardingDone && onOnboarding
         │
         └─ return '/home'   ← NAV-01 fix (was '/goals')
                │
                ▼
         HomeScreen
         │         │
     has schedule  no schedule
         │              │
         ▼              ▼
   ActiveChunkCard  Empty state
   (NOW section)   (unchanged)
   NextChunkRow
   (NEXT section)
   "See full schedule" → /schedule ← NAV-02
         │
         ▼
   ScheduleScreen
   ListView.builder
         │
   ┌─────┴─────┐
   │           │
NowMarker   ChunkCard (SCHED-01, SCHED-02, SCHED-03)
(inline)    │
            ├── displayStartMinutes getter
            │   ├── anchoredStartMinutes  (commitment chunks)
            │   └── syntheticStartMinutes  (@HiveField(10) — new)
            ├── _formatTimeRange(start, end) → "9:25 AM – 9:50 AM"
            └── always-visible FilledButton.icon + OutlinedButton.icon
                    │
                    ▼
           ScheduleNotifier.markComplete / markSkipped
```

### Recommended File Structure Changes

```
lib/
├── data/
│   ├── database/
│   │   └── migrations.dart          # add _migration6to7 (no-op), bump to 7
│   └── models/
│       ├── scheduled_chunk.dart     # add @HiveField(10) syntheticStartMinutes
│       └── scheduled_chunk.g.dart   # regenerated by build_runner
├── router.dart                       # change '/goals' to '/home' in redirect
├── screens/
│   ├── home/
│   │   ├── home_screen.dart          # refactor to Now/Next sections
│   │   └── widgets/
│   │       ├── active_chunk_card.dart  # NEW
│   │       ├── end_of_day_card.dart    # unchanged
│   │       └── review_banner.dart      # unchanged
│   └── schedule/
│       └── widgets/
│           └── chunk_card.dart         # replace hover overlay, add clock time
└── services/
    └── schedule_generator.dart         # persist syntheticStartMinutes before return
test/
├── screens/
│   ├── router_redirect_test.dart       # update /onboarding→/home assertion
│   ├── chunk_card_hover_test.dart      # update to always-visible pattern
│   ├── active_chunk_card_test.dart     # NEW
│   └── now_marker_test.dart            # NEW (optional but helpful)
```

### Pattern 1: Hive Additive Field + Migration

**What:** Add a new nullable `@HiveField` to an existing Hive model, regenerate the adapter, and add a no-op migration entry.

**When to use:** Any time a new persisted field is added to an existing Hive type. The Hive CE binary reader returns null for missing fields in pre-existing records — no data transformation needed.

**Critical invariant (WR-06):** `_migrations.length` must equal `currentSchemaVersion`. The `runMigrations` assert fires at startup in debug/CI if the count is wrong. Current state: version 6, six migrations. Adding `@HiveField(10)` requires bumping to version 7 and adding a seventh migration entry.

```dart
// Source: existing pattern in lib/data/database/migrations.dart

// In scheduled_chunk.dart — add after @HiveField(9):
/// Synthetic start time assigned by ScheduleGeneratorService.
/// Persisted so clock times survive app restart.
@HiveField(10)
int? syntheticStartMinutes;

// In migrations.dart — bump constant and append entry:
const int currentSchemaVersion = 7;  // was 6

final List<MigrationFn> _migrations = [
  _migration0to1,
  _migration1to2,
  _migration2to3,
  _migration3to4,
  _migration4to5,
  _migration5to6,
  _migration6to7,  // NEW
];

Future<void> _migration6to7() async {
  // ScheduledChunk gains syntheticStartMinutes (HiveField 10, int?, null).
  // Additive nullable field — Hive CE binary reader returns null for missing
  // HiveField(10) in existing records. No data transformation needed.
}
```

**After adding the field, run:**
```bash
/home/dan/development/flutter/bin/dart run build_runner build --delete-conflicting-outputs
```

The generated `scheduled_chunk.g.dart` will gain a `writeByte(10)` / `write(obj.syntheticStartMinutes)` line and the `read` will pull `fields[10] as int?`. The `writeByte(10)` count at the top increments from 10 to 11 (writes 11 fields).

### Pattern 2: displayStartMinutes Unified Getter

**What:** A single getter on `ScheduledChunk` that returns the appropriate start time regardless of chunk origin.

**When to use:** Every UI element that needs to display a clock time. Never access `anchoredStartMinutes` or `syntheticStartMinutes` directly in UI code.

```dart
// Source: UI-SPEC §Clock Time Contract
// Add to ScheduledChunk class body (after the syntheticStartMinutes field):
int? get displayStartMinutes => anchoredStartMinutes ?? syntheticStartMinutes;
```

### Pattern 3: _formatTimeRange Helper

**What:** Extends the existing `_formatMinutes` private helper in `chunk_card.dart` to produce a "START – END" range string.

**When to use:** Secondary text on all work chunk cards (replacing duration-only display).

```dart
// Source: existing _formatMinutes in lib/screens/schedule/widgets/chunk_card.dart
String _formatTimeRange(int startMin, int endMin) {
  return '${_formatMinutes(startMin)} – ${_formatMinutes(endMin)}';
}
// Usage: _formatTimeRange(chunk.displayStartMinutes!, chunk.displayStartMinutes! + chunk.durationMinutes)
// Fallback (displayStartMinutes == null): '${chunk.durationMinutes} min'
```

### Pattern 4: Always-Visible Action Buttons (replacing hover overlay)

**What:** Replace the `MouseRegion` + `AnimatedOpacity` hover-gated icon row in `_HoverableChunkContent` with always-visible `FilledButton.icon` + `OutlinedButton.icon`.

**When to use:** All unresolved work chunks in `ChunkCard` (both ScheduleScreen and the new `ActiveChunkCard`).

The `_HoverableChunkContent` class needs restructuring:
- Remove `_hovered` state variable and `AnimatedOpacity` overlay `Positioned` widget
- Keep `MouseRegion` but only for cursor change (`SystemMouseCursors.click`) — not for content reveal
- Add action row below the main content row (inside the `Opacity` wrapper so resolved chunks dim the buttons too — or outside if resolved chunks should show no buttons at all per UI-SPEC)
- Per UI-SPEC: resolved chunks show **no buttons**, only the status icon. So the action row is conditionally rendered only when `!isResolved`.

```dart
// Source: UI-SPEC §Chunk Action Contract
// In _HoverableChunkContent.build, after the main content Column:
if (!isResolved) ...[
  const SizedBox(height: 12),
  Row(
    children: [
      FilledButton.icon(
        icon: const Icon(Icons.check_circle_outline),
        label: const Text('Complete'),
        onPressed: () => context.read<ScheduleNotifier>().markComplete(chunk.id),
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
        ),
      ),
      const SizedBox(width: 8),
      OutlinedButton.icon(
        icon: const Icon(Icons.skip_next_outlined),
        label: const Text('Skip'),
        onPressed: () => context.read<ScheduleNotifier>().markSkipped(chunk.id),
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          foregroundColor: Theme.of(context).colorScheme.error,
          side: BorderSide(color: Theme.of(context).colorScheme.error),
        ),
      ),
    ],
  ),
],
```

### Pattern 5: NowMarker Inline Widget

**What:** A thin horizontal divider with a "Now" label inserted in `ScheduleScreen`'s ListView before the first unresolved work chunk at or after the current wall time.

**Insertion logic** (in `ScheduleScreen.build`, replacing the simple for-loop):

```dart
// Source: UI-SPEC §NowMarker widget
// Compute the "now marker" insertion index once before the ListView build:
final nowMinutes = DateTime.now().hour * 60 + DateTime.now().minute;
int? nowMarkerIndex;
for (int i = 0; i < activeChunks.length; i++) {
  final c = activeChunks[i];
  if (c.chunkType == ChunkType.work && !c.isCompleted && !c.isSkipped) {
    // Insert before the first unresolved work chunk whose start >= now,
    // or before the first unresolved work chunk overall if none qualify.
    if (nowMarkerIndex == null) nowMarkerIndex = i; // fallback: first unresolved
    if ((c.displayStartMinutes ?? 9999) >= nowMinutes) {
      nowMarkerIndex = i;
      break;
    }
  }
}

// In ListView children:
for (int i = 0; i < activeChunks.length; i++) {
  if (i == nowMarkerIndex) children.add(const NowMarker());
  children.add(_buildSwipeableCard(context, activeChunks[i]));
}
```

### Pattern 6: HomeScreen Now/Next Refactor

**What:** Replace the existing "Up next" single-chunk display with a two-section layout: a "Now" section with `ActiveChunkCard` and a "Next" section with a compact next-chunk row.

**Key difference from existing code:** The existing `home_screen.dart` uses `nextChunk` as both the current and next chunk (there is no distinction). Phase 12 splits this into:
- `currentChunk` = first unresolved work chunk (the one in progress or up immediately)
- `nextChunk` = second unresolved work chunk

```dart
// Source: derived from existing home_screen.dart pattern
final unresolvedWork = schedule.chunks
    .where((c) => c.chunkType == ChunkType.work && !c.isCompleted && !c.isSkipped)
    .toList();
final currentChunk = unresolvedWork.isNotEmpty ? unresolvedWork.first : null;
final nextChunk = unresolvedWork.length > 1 ? unresolvedWork[1] : null;
```

### Anti-Patterns to Avoid

- **Accessing syntheticStartMinutes directly in UI:** Always use `displayStartMinutes` getter. Direct field access bypasses the unified fallback and makes commitment chunks show null.
- **Recomputing NowMarker position on every ListView build without memoization:** The marker index should be computed once per build, not inside a closure that runs per item.
- **Retaining the MouseRegion AnimatedOpacity overlay:** The old hover-only overlay must be removed entirely, not just hidden at opacity 0. Leaving opacity 0 elements in the tree wastes layout and confuses the existing `chunk_card_hover_test.dart` assertions.
- **Wrong schemaVersion bump:** The UI-SPEC says "bump to schemaVersion 6" but the codebase is already at 6. The correct target is 7. Using 6 triggers the WR-06 assert at startup (`_migrations.length` would be 7 but `currentSchemaVersion` would still read 6).
- **Mutating syntheticStartMinutes after persist:** `ScheduleGeneratorService` sets `syntheticStartMinutes` on the in-memory chunk object before `ScheduleNotifier.generateToday` calls `_repo.save(schedule)`. The field is set during generation and read back from Hive on subsequent loads. Never set it after save.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Clock time formatting | Custom AM/PM formatter | Extend existing `_formatMinutes` in `chunk_card.dart` | Already handles midnight (h==0→12), PM hours, zero-padding. |
| Goal color lookup | New color resolution logic | `_lookupGoalColor` / `_lookupGoalName` (already in `ScheduleScreen` and `HomeScreen`) | Identical pattern in both screens — copy to `ActiveChunkCard` or extract to a shared helper |
| Provider wiring for actions | New state mechanism | `context.read<ScheduleNotifier>().markComplete/markSkipped` (existing) | Already used by the hover overlay and Dismissible swipe; same idempotent call site |
| Schema migration framework | Custom Hive migration | Existing `migrations.dart` pattern | WR-06 assert protects against version drift; just add a new entry |

**Key insight:** This phase is almost entirely a UI reorganization over an existing data layer. The generator already computes `syntheticStartMinutes` — persisting it requires adding one `@HiveField` declaration, running build_runner, and adding a no-op migration. All other work is widget rearrangement.

---

## Common Pitfalls

### Pitfall 1: Wrong schemaVersion Target

**What goes wrong:** The UI-SPEC documents target version as 6, but the codebase is already at `currentSchemaVersion = 6`. Using 6 leaves `_migrations.length` (7 after adding the entry) not equal to `currentSchemaVersion` (6), triggering the WR-06 startup assert in debug mode.

**Why it happens:** The UI-SPEC was written before researching the live migrations.dart.

**How to avoid:** Use `currentSchemaVersion = 7` and append `_migration6to7` as the 7th entry.

**Warning signs:** `assert(_migrations.length == currentSchemaVersion)` fires at app startup in debug mode.

### Pitfall 2: Existing chunk_card_hover_test.dart will fail

**What goes wrong:** `chunk_card_hover_test.dart` asserts that `AnimatedOpacity` for `Icons.check_circle_outline` is at `opacity: 0.0` before hover and `1.0` after. After Phase 12, those icons are always visible buttons (no `AnimatedOpacity` wrapper) and the test will fail to find the `AnimatedOpacity` ancestor.

**Why it happens:** The test was written for the hover-gated pattern that Phase 12 deliberately removes.

**How to avoid:** Update the test in Wave 3. The new assertions should verify:
- `FilledButton.icon` with `Icons.check_circle_outline` and label "Complete" is `findsOneWidget` on unresolved chunks without any hover gesture.
- `OutlinedButton.icon` with `Icons.skip_next_outlined` and label "Skip" is `findsOneWidget` on unresolved chunks.
- Resolved chunks show no `FilledButton` or `OutlinedButton`.

### Pitfall 3: router_redirect_test.dart assertion needs update

**What goes wrong:** Line 170 in `router_redirect_test.dart` asserts `expect(_currentPath(router), '/goals')` for the `onOnboarding → already-done` redirect. After NAV-01, the redirect returns `/home` and this assertion fails.

**Why it happens:** The test was written before NAV-01 was in scope.

**How to avoid:** Update line ~170 to `expect(_currentPath(router), '/home')`. Also add a new test: `'onboardingComplete=true → /onboarding redirects to /home'`.

### Pitfall 4: syntheticStartMinutes null for existing persisted schedules

**What goes wrong:** Today's schedule was generated before `@HiveField(10)` existed. On app restart, `syntheticStartMinutes` is read back as `null` from Hive (field didn't exist). Discretionary chunk clock times show the fallback "25 min" duration-only string instead of a clock time.

**Why it happens:** Additive Hive field migration returns null for pre-existing records.

**How to avoid:** The `displayStartMinutes` fallback ("25 min" text) is the correct behavior for this edge case. The user will see a "25 min" string for legacy chunks until the next re-check-in regenerates the schedule with `syntheticStartMinutes` properly set and persisted. This is acceptable and intentional — document it in the plan task for the wave 1 schema change.

### Pitfall 5: ScheduleGeneratorService sets syntheticStartMinutes on in-memory chunk but doesn't save it

**What goes wrong:** After the schema change, `@HiveField(10)` is present but `ScheduleGeneratorService.generate()` assigns `syntheticStartMinutes` to the in-memory `ScheduledChunk` objects. `ScheduleNotifier.generateToday` then calls `_repo.save(schedule)`. Since `DailySchedule.chunks` is the persisted list, and `ScheduledChunk` objects within it have `syntheticStartMinutes` set at this point, Hive will serialize the value **only if** the write path includes the new field.

**Why it happens:** The `.g.dart` generated adapter's `write` method must include `writeByte(10)` and `write(obj.syntheticStartMinutes)` for the field to be persisted. This happens automatically after `build_runner` regenerates the adapter — but only if `@HiveField(10) int? syntheticStartMinutes` is declared as an instance field (not a transient one like the current `int? syntheticStartMinutes` without the annotation).

**How to avoid:** Verify the generated `scheduled_chunk.g.dart` includes the field 10 write after running `build_runner`. The count at the top of `write` should change from `writeByte(10)` (10 fields) to `writeByte(11)` (11 fields).

### Pitfall 6: ActiveChunkCard needs ThemeNotifier for color, not hardcoded colors

**What goes wrong:** The new `ActiveChunkCard` hardcodes colors instead of using `Theme.of(context).colorScheme.*`.

**How to avoid:** Follow existing `ChunkCard` and `HomeScreen` patterns — all colors come from `Theme.of(context).colorScheme`. Goal color comes from `_lookupGoalColor` (same as `ScheduleScreen`).

---

## Code Examples

### Existing _formatMinutes (chunk_card.dart — verified in codebase)

```dart
// Source: lib/screens/schedule/widgets/chunk_card.dart lines 12-17 [VERIFIED: codebase]
String _formatMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  final suffix = h < 12 ? 'AM' : 'PM';
  final hour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '$hour:${m.toString().padLeft(2, '0')} $suffix';
}
```

### Existing hover overlay (to be removed in SCHED-03)

```dart
// Source: lib/screens/schedule/widgets/chunk_card.dart lines 300-326 [VERIFIED: codebase]
// The Positioned + AnimatedOpacity block is removed entirely in Wave 3.
// The _hovered bool state, MouseRegion.onEnter, and MouseRegion.onExit
// are also removed (or MouseRegion kept only for cursor change).
```

### Existing router redirect (NAV-01 fix is one word)

```dart
// Source: lib/router.dart line 33 [VERIFIED: codebase]
// CURRENT:
if (onboardingDone && onOnboarding) return '/goals';
// CHANGE TO:
if (onboardingDone && onOnboarding) return '/home';
```

### Existing ScheduledChunk field 9 (to understand field numbering)

```dart
// Source: lib/data/models/scheduled_chunk.dart line 57 [VERIFIED: codebase]
@HiveField(9)
String? commitmentId;
// Therefore the new field is:
@HiveField(10)
int? syntheticStartMinutes;
```

### Migration count enforcement

```dart
// Source: lib/data/database/migrations.dart line 72 [VERIFIED: codebase]
assert(
  _migrations.length == currentSchemaVersion,
  '_migrations.length (${_migrations.length}) must equal '
  'currentSchemaVersion ($currentSchemaVersion) ...',
);
// Current state: _migrations has 6 entries, currentSchemaVersion = 6.
// After Phase 12 Wave 1: _migrations must have 7 entries, currentSchemaVersion = 7.
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hover-only desktop action icons | Always-visible labeled buttons | Phase 12 (SCHED-03) | Touch platforms finally have labeled action affordances |
| Frequency label as rationale ("5x/week") | Clock time range ("9:25 AM – 9:50 AM") | Phase 12 (SCHED-01) | Schedule reads as a real time plan |
| App lands on /goals after onboarding | App lands on /home | Phase 12 (NAV-01) | Consistent launch destination |
| "Up next" single chunk on Home | Now/Next active-day view with actions | Phase 12 (NAV-02) | Home answers "what am I doing right now" |

**Deprecated/outdated:**
- `_HoverableChunkContent` `_hovered` bool state + `AnimatedOpacity` overlay: replaced by always-visible buttons
- `anchoredStartMinutes`-only time display in ChunkCard: replaced by `displayStartMinutes` getter covering both chunk origins

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `syntheticStartMinutes` is not currently set back on the ScheduledChunk before `_repo.save(schedule)` in `ScheduleNotifier.generateToday` — the save happens to chunks that already have the field set in memory. | Common Pitfalls §5 | If the save happens BEFORE syntheticStartMinutes is set (unlikely given generator returns the list), the field would persist as null. Low risk — generator sets it, then notifier saves. |

All other claims in this research were verified directly in the codebase.

---

## Open Questions

1. **NowMarker position when all work chunks are resolved**
   - What we know: The UI-SPEC says insert before "the first unresolved work chunk at or after current time, or before the first unresolved work chunk overall."
   - What's unclear: When all work chunks are resolved (all done today), should NowMarker appear at all?
   - Recommendation: When `nextChunk == null` (all resolved), omit the NowMarker entirely. The "All done today!" text makes the NowMarker redundant.

2. **ScheduleScreen vs. HomeScreen action button scope for SCHED-03**
   - What we know: The UI-SPEC requires always-visible buttons on both `ChunkCard` (ScheduleScreen) and `ActiveChunkCard` (HomeScreen).
   - What's unclear: Should the existing `SwipeableChunkCard` in ScheduleScreen retain swipe gestures alongside the always-visible buttons?
   - Recommendation: Yes — per UI-SPEC §Chunk Action Contract: "always-visible buttons and swipe gestures are orthogonal and coexist." Swipe wrapping is in `SwipeableChunkCard`/`Dismissible` which is independent of `ChunkCard`'s internals.

---

## Environment Availability

| Dependency | Required By | Available | Notes |
|------------|------------|-----------|-------|
| Flutter toolchain | All tasks | ✓ | At `/home/dan/development/flutter/bin` |
| `build_runner` | Wave 1 (schema) | ✓ | In `dev_dependencies` |
| `hive_ce_generator` | Wave 1 (schema) | ✓ | In `dev_dependencies` |
| `flutter test` | Verification | ✓ | Standard Flutter test framework |

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in Flutter SDK) |
| Config file | none — standard `flutter test` discovery |
| Quick run command | `/home/dan/development/flutter/bin/flutter test test/screens/router_redirect_test.dart test/screens/chunk_card_hover_test.dart` |
| Full suite command | `/home/dan/development/flutter/bin/flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| NAV-01 | Onboarding done → /onboarding redirects to /home | widget | `flutter test test/screens/router_redirect_test.dart` | ✅ (needs update) |
| NAV-01 | Cold launch onboarding done → initial location /home | widget | `flutter test test/screens/router_redirect_test.dart` | ✅ (needs new test case) |
| NAV-02 | HomeScreen shows Now section with ActiveChunkCard when schedule exists | widget | `flutter test test/screens/active_chunk_card_test.dart` | ❌ Wave 0 |
| NAV-02 | "See full schedule" TextButton navigates to /schedule | widget | `flutter test test/screens/active_chunk_card_test.dart` | ❌ Wave 0 |
| SCHED-01 | ChunkCard shows "9:25 AM – 9:50 AM" for displayStartMinutes-set chunk | widget | `flutter test test/screens/chunk_card_goal_name_test.dart` (extend) | ✅ (needs clock time assertions) |
| SCHED-01 | ChunkCard fallback shows duration when displayStartMinutes null | widget | same | ✅ (needs fallback test) |
| SCHED-02 | NowMarker renders in ScheduleScreen ListView | widget | `flutter test test/screens/now_marker_test.dart` | ❌ Wave 0 (optional) |
| SCHED-03 | FilledButton "Complete" + OutlinedButton "Skip" visible without hover | widget | `flutter test test/screens/chunk_card_hover_test.dart` (update) | ✅ (needs update) |
| SCHED-03 | Resolved chunk shows no action buttons | widget | same | ✅ (needs update) |

### Sampling Rate

- **Per task commit:** `flutter test test/screens/router_redirect_test.dart test/screens/chunk_card_hover_test.dart`
- **Per wave merge:** `/home/dan/development/flutter/bin/flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/screens/active_chunk_card_test.dart` — covers NAV-02 (Now section, See full schedule link)
- [ ] `test/screens/chunk_card_hover_test.dart` — update existing to always-visible pattern (covers SCHED-03)
- [ ] `test/screens/router_redirect_test.dart` — update existing `/goals` → `/home` assertion + add new test (covers NAV-01)
- [ ] `test/screens/chunk_card_goal_name_test.dart` — add clock time range assertions (covers SCHED-01)

Note: `test/screens/now_marker_test.dart` for SCHED-02 is optional — the NowMarker is a pure visual widget with no logic; manual visual verification may be sufficient.

---

## Security Domain

SCHED-03 chunk actions (`markComplete`, `markSkipped`) call `context.read<ScheduleNotifier>()` directly. The existing notifier methods are already idempotent and validated (chunk.isCompleted/isSkipped guard). No new security surface introduced.

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V5 Input Validation | yes (chunk ID) | Existing notifier guards: `if (chunk == null \|\| chunk.isCompleted) return` |
| V4 Access Control | no | Local app; no authentication surface in this phase |
| V3 Session Management | no | No session state changed |

---

## Sources

### Primary (HIGH confidence — verified in codebase)

- `lib/data/database/migrations.dart` — confirmed current schemaVersion=6, migration list has exactly 6 entries, WR-06 assert pattern [VERIFIED: codebase]
- `lib/data/models/scheduled_chunk.dart` — confirmed field layout: HiveField 0-9, `syntheticStartMinutes` is currently transient (no annotation) [VERIFIED: codebase]
- `lib/data/models/scheduled_chunk.g.dart` — confirmed generated adapter writes 10 fields (bytes), field 9 is `commitmentId` [VERIFIED: codebase]
- `lib/router.dart` — confirmed redirect: `if (onboardingDone && onOnboarding) return '/goals'` is the exact string to change [VERIFIED: codebase]
- `lib/screens/schedule/widgets/chunk_card.dart` — confirmed `_HoverableChunkContent` structure, `_hovered` state, `AnimatedOpacity` overlay at lines 300-326 [VERIFIED: codebase]
- `lib/screens/home/home_screen.dart` — confirmed current "Up next" single-chunk layout, `_lookupGoalName` pattern [VERIFIED: codebase]
- `lib/services/schedule_generator.dart` — confirmed `syntheticStartMinutes` is set on chunks during `_assignSyntheticStartTimes`, before `_repo.save` in `ScheduleNotifier` [VERIFIED: codebase]
- `test/screens/router_redirect_test.dart` — confirmed line ~170 asserts `/goals` (must change to `/home` for NAV-01) [VERIFIED: codebase]
- `test/screens/chunk_card_hover_test.dart` — confirmed tests assert `AnimatedOpacity` pattern (must be updated for SCHED-03) [VERIFIED: codebase]

### Secondary (from UI-SPEC)

- `12-UI-SPEC.md` — Implementation sequencing, component specs, clock time contract, chunk action contract [CITED: .planning/phases/12-home-as-landing-schedule-as-plan/12-UI-SPEC.md]

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new packages; all deps verified in pubspec.yaml
- Architecture: HIGH — all patterns derived from live codebase inspection
- Schema migration: HIGH — exact field numbers and migration count verified in source
- Pitfalls: HIGH — identified by tracing actual code paths and test assertions

**Research date:** 2026-06-12
**Valid until:** 2026-07-12 (stable Flutter/Hive codebase — changes only if schema is modified by other work)
