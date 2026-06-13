# Phase 3: Schedule Generation and Morning Check-In - Research

**Researched:** 2026-03-23
**Domain:** Flutter UI routing, deterministic scheduling algorithm, gesture-driven navigation, Provider state management
**Confidence:** HIGH

## Summary

Phase 3 delivers the core product loop for the first time. The scheduling engine is pure Dart — no external library needed beyond what is already installed. The UI work breaks into three distinct layers: (1) the check-in screen with mood-adaptive tinting, (2) the acknowledgment screen with a swipe-up gesture transition, and (3) the schedule list screen. All three screens plus the Home summary widget must read from `ScheduleNotifier`, which is currently a stub.

The existing codebase is well-prepared. `DailySchedule`, `ScheduledChunk`, and all repository layers are scaffolded and functional. `GoalsNotifier.goals` and `CommitmentsNotifier.blocks` expose exactly the inputs the algorithm needs. The `hexToColor()` helper in `goal_card.dart` handles all color conversion. The primary unknowns are the gesture animation for the swipe-up reveal and the routing strategy for the check-in sub-flow within the Schedule branch.

**Primary recommendation:** Build the algorithm as a pure Dart service class (`ScheduleGeneratorService`) that takes goals, blocks, and mood as plain inputs and returns a `List<ScheduledChunk>`. Wire it through `ScheduleNotifier.generateToday()`. Build the three screens as separate files in `lib/screens/schedule/`. Use a pushed `go_router` route for check-in (`/schedule/checkin`) within the Schedule branch so the bottom nav remains mounted but is hidden via `Scaffold` body-only rendering.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Morning entry flow**
- Schedule tab shows an empty state with a "Start your day" button when no schedule exists for today — check-in launches from there as a full-screen pushed route (bottom nav remains accessible but hidden during check-in)
- Check-in is a full-screen route pushed from the Schedule tab; after generation it pops back to the schedule
- Regenerating (tap check-in again on a day with an existing schedule): silent replace — no confirmation dialog
- Home tab shows today's summary after schedule is generated: progress bar, today's mood emoji, and the next upcoming chunk name + duration

**Mood check-in screen**
- Weather/nature metaphor emojis for the 5 moods: 🌧️ (1, stormy) · 🌥️ (2, overcast) · ⛅ (3, partly cloudy) · 🌤️ (4, clearing) · ☀️ (5, sunny)
- Visual tone: playful and colorful, mood-adaptive — tapping an emoji immediately shifts the screen's background tint to that mood's palette color
- Color palette (also used for progress bar / AppBar accent on the schedule screen):
  - Mood 1: #4A6275 (steel blue-grey)
  - Mood 2: #5C7A8A (slate)
  - Mood 3: #4A8C7A (muted teal)
  - Mood 4: #7AAF6A (soft green)
  - Mood 5: #E8C547 (warm amber)
- Mood color kicks in on tap (not hover/browse); no animation needed in Phase 3

**Post-check-in acknowledgment**
- Acknowledgment screen uses weather-themed copy matching the emoji set:
  - Mood 1: "Stormy day — keeping it light. X chunks."
  - Mood 2: "Overcast — gentle pace. X chunks."
  - Mood 3: "Partly cloudy — steady. X chunks."
  - Mood 4: "Clearing up — good flow. X chunks."
  - Mood 5: "Clear skies — let's go. X chunks."
- Acknowledgment shows chunk count + name of the first work chunk (e.g. "…starting with Writing")
- Mood 1–2 follow-up toggle "Want a lighter day?" (default Yes) shows before the acknowledgment — as spec'd in ROADMAP
- Dismiss: user swipes up to reveal the schedule (acknowledgment slides up, schedule peeks from below)

**Chunk card visual states**
- Done state: color bar desaturates to grey, text fades to ~50% opacity, checkmark icon replaces the status icon; card stays in position
- Short break card: compact strip (~48dp), no color bar, soft background tint, pause icon ⏸, no rationale text
- Long break card: full work-card height, neutral/white surface, no color bar, coffee icon ☕, no rationale text
- Mood color on schedule screen: subtle accent only — progress bar and AppBar tint use today's mood color; chunk cards themselves stay neutral (white/surface) to avoid clashing with goal color bars

### Claude's Discretion
- Exact wording/punctuation of the empty-state copy on the Schedule tab ("Start your day" button label, subtitle)
- Home screen summary layout details (spacing, secondary stats shown)
- Exact opacity value for faded "done" text (aim for ~50% but adjust for legibility)
- Short break background tint color (can derive from mood color at low opacity, or use a neutral surface variant)
- Animation curve for the swipe-up reveal from acknowledgment to schedule

### Deferred Ideas (OUT OF SCOPE)
- Full app mood theming throughout the day — user wants the entire app's color scheme to reflect the morning mood and evolve as the day progresses. Explicitly deferred to Phase 6 polish. The mood palette defined here (#4A6275 → #E8C547) is the foundation.
</user_constraints>

---

## Standard Stack

### Core (all already installed — no new packages needed)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `provider` | ^6.1.5+1 | `ScheduleNotifier` state | Already in use for Goals/Commitments |
| `go_router` | ^17.1.0 | `/schedule/checkin` pushed route | Already wiring all navigation |
| `hive_ce` / `hive_ce_flutter` | ^2.19.3 / ^2.3.4 | `DailySchedule` persistence | Already the project database |
| `intl` | ^0.20.2 | `DateFormat` for `dateYmd` formatting | Already installed |
| Flutter `material` | (SDK) | `AnimatedContainer`, `GestureDetector`, `LinearProgressIndicator` | Core toolkit |

No new dependencies are required for Phase 3. All needed functionality is covered by the existing stack.

### Supporting Patterns Already In Codebase
| Pattern | Location | Reuse In Phase 3 |
|---------|----------|------------------|
| `hexToColor()` | `lib/screens/goals/widgets/goal_card.dart` | Mood palette colors, chunk card goal color bars |
| Colored left bar via `Stack` + `Positioned` | `GoalCard` | `ChunkCard` follows the same structure |
| `DraggableScrollableSheet` | Goal/commitment forms | NOT used — check-in is a pushed route, not a sheet |
| Provider `ChangeNotifier` pattern | `GoalsNotifier`, `CommitmentsNotifier` | `ScheduleNotifier` mirrors exactly |
| `context.push()` / `context.pop()` | `router.dart` + commitments | Check-in route lifecycle |

---

## Architecture Patterns

### Recommended Project Structure (additions only)
```
lib/
├── providers/
│   └── schedule_notifier.dart        # Expand from stub — owns generation + state
├── screens/
│   ├── home/
│   │   └── home_screen.dart          # Replace stub with today's summary widget
│   └── schedule/
│       ├── schedule_screen.dart      # Replace stub — empty state + card list
│       ├── checkin_screen.dart       # NEW — mood tap + follow-up toggle
│       ├── acknowledgment_screen.dart # NEW — weather copy + swipe-up gesture
│       └── widgets/
│           ├── chunk_card.dart       # NEW — work/break card variants
│           └── schedule_progress_bar.dart # NEW — "X of Y Chunks"
└── services/
    └── schedule_generator.dart       # NEW — pure Dart algorithm, zero Flutter deps
```

### Pattern 1: Algorithm as Pure Service Class

**What:** A top-level `ScheduleGeneratorService` class (or standalone function) that takes `List<Goal>`, `List<CommitmentBlock>`, `int moodIndex`, and `DateTime date` as parameters and returns `List<ScheduledChunk>`. No Flutter imports, no async, no side effects.

**When to use:** Any time the algorithm must run — morning generation, regeneration (silent replace), and unit testing.

**Why pure:** Enables unit testing without `flutter_test`, `BuildContext`, or Hive. The algorithm is the most logic-heavy code in the project; testability is critical.

```dart
// lib/services/schedule_generator.dart
class ScheduleGeneratorService {
  List<ScheduledChunk> generate({
    required List<Goal> goals,
    required List<CommitmentBlock> blocks,
    required int moodIndex,         // 1–5
    required DateTime date,         // used to filter CommitmentBlock.daysOfWeek
  }) {
    // Pure logic — returns ordered list of ScheduledChunks.
    // No async, no Hive, no BuildContext.
  }
}
```

### Pattern 2: Algorithm Allocation Sequence (FIXED ORDER)

The algorithm produces a deterministic list given identical inputs. The allocation sequence is:

1. **Commitment blocks** — anchor all CommitmentBlock windows for today's weekday into 25-min `ScheduledChunk`s with `anchoredStartMinutes` set. A 90-min block yields 3 × 25-min chunks + leftover (truncate if <25 min remaining).
2. **Habits** — always included regardless of mood. One chunk per active habit goal (not exceeding `frequencyPerWeek` budget for the week — Phase 3 can treat each day as independent; streak tracking is Phase 4).
3. **Outcome goals** (mood 3–5 only, or mood 1–2 if `deadline == today`) — sorted by urgency score: `priorityWeight × chunksRemaining / daysRemaining`. `priorityWeight` defaults to 0.5 if null. `daysRemaining` floored at 1 to avoid division by zero.
4. **Time-target goals** (mood 3–5 only) — sorted by most behind weekly budget first. Budget tracking across the week is not available in Phase 3 (no CompletionLog yet); treat each scheduled chunk as reducing the remaining budget proportionally.
5. **Leave 20% of discretionary capacity unscheduled** — stop allocating discretionary chunks when 80% of capacity is filled.

**Capacity table:**
| Mood | Chunk Range | Use |
|------|-------------|-----|
| 1 | 5–6 | Hard max 6; min 3 |
| 2 | 7–8 | Hard max 8 |
| 3 | 9–10 | Hard max 10 |
| 4 | 11–12 | Hard max 12 |
| 5 | 13–14 | Hard max 14 (hard cap 16) |

The 80% rule: at mood 5 (14 discretionary slots), schedule at most 11 discretionary chunks — leave 3 open.

**"Just survive" mode (mood 1–2):** Skip outcome and time-target goals entirely unless a goal has `deadline == today`. Habits always survive.

### Pattern 3: Break Insertion

Insert breaks AFTER allocation sequence, not during:

1. Walk the ordered work-chunk list.
2. After every work chunk, insert a `shortBreak` (5 min, `goalId: null`, `chunkTypeIndex: ChunkType.shortBreak.index`).
3. After every 3rd work chunk (mood 1–2) or 4th work chunk (mood 3–5), replace the next short break with a `longBreak` (25 min) instead.

`ScheduledChunk` fields for breaks:
- `chunkTypeIndex`: `ChunkType.shortBreak.index` or `ChunkType.longBreak.index`
- `goalId`: null
- `rationale`: empty string (breaks show no rationale text per CONTEXT.md)
- `durationMinutes`: 5 or 25

### Pattern 4: ScheduleNotifier Expansion

`ScheduleNotifier` is the single source of truth for the schedule. It owns:
- `DailySchedule? _todaySchedule` — null until generated
- `int? get moodIndex` — from today's schedule, used by HomeScreen and ScheduleScreen for accent color
- `Future<void> generateToday(int moodIndex)` — calls the generator, persists via `HiveDailyScheduleRepository`, calls `notifyListeners()`
- `Future<void> loadToday()` — called at app start (from `initState` of `ScheduleScreen` or `HomeScreen`) to restore persisted schedule
- `bool get hasScheduleToday` — drives empty state vs. schedule list

```dart
// lib/providers/schedule_notifier.dart  (expanded)
class ScheduleNotifier extends ChangeNotifier {
  final DailyScheduleRepository _repo = HiveDailyScheduleRepository();
  final ScheduleGeneratorService _generator = ScheduleGeneratorService();

  DailySchedule? _todaySchedule;
  DailySchedule? get todaySchedule => _todaySchedule;
  bool get hasScheduleToday => _todaySchedule != null;
  int? get moodIndex => _todaySchedule?.moodIndex;

  Future<void> loadToday() async {
    _todaySchedule = await _repo.getTodaysSchedule();
    notifyListeners();
  }

  Future<void> generateToday({
    required int moodIndex,
    required List<Goal> goals,
    required List<CommitmentBlock> blocks,
  }) async {
    final chunks = _generator.generate(
      goals: goals, blocks: blocks, moodIndex: moodIndex,
      date: DateTime.now(),
    );
    final today = _formatDateYmd(DateTime.now().toUtc());
    // Replace existing schedule if any (silent).
    final existing = await _repo.getByDate(today);
    if (existing != null) await _repo.delete(existing.id);

    final schedule = DailySchedule(
      dateYmd: today, moodIndex: moodIndex, chunks: chunks,
    );
    await _repo.save(schedule);
    _todaySchedule = schedule;
    notifyListeners();
  }
}
```

### Pattern 5: Check-in Route Within Schedule Branch

The check-in screen is a **child route** of `/schedule` within the `StatefulShellBranch`. This keeps the `StatefulNavigationShell` mounted (preserves branch state) while pushing a full-screen route over the Schedule tab.

```dart
// In router.dart — expand the Schedule branch:
StatefulShellBranch(
  routes: [
    GoRoute(
      path: '/schedule',
      builder: (context, state) => const ScheduleScreen(),
      routes: [
        GoRoute(
          path: 'checkin',
          builder: (context, state) => const CheckinScreen(),
        ),
      ],
    ),
  ],
),
```

After generation, `CheckinScreen` navigates to `AcknowledgmentScreen` (can be a second nested route or shown inline with an `AnimatedSwitcher`), then pops back to `/schedule`.

**Bottom nav hiding during check-in:** Since check-in is within the shell, the `NavigationBar` will be visible unless hidden. The simplest approach: `CheckinScreen` uses a full-screen `Scaffold` that draws over the nav bar using `extendBody: true` and a solid background, or use `context.push` to the route and wrap the `_ScaffoldWithNavBar` so that it detects child routes and hides the nav bar. The most pragmatic approach in go_router: push `/schedule/checkin` — the bottom nav IS still rendered in the shell but the check-in Scaffold's opaque background covers it entirely. This is acceptable per CONTEXT.md ("bottom nav remains accessible but hidden during check-in").

### Pattern 6: Swipe-Up Gesture (Acknowledgment → Schedule)

The acknowledgment dismissal is a **swipe-up to pop** gesture. Implementation approach:

```dart
// AcknowledgmentScreen body wrapper:
GestureDetector(
  onVerticalDragEnd: (details) {
    if (details.primaryVelocity != null && details.primaryVelocity! < -300) {
      context.pop(); // pops checkin route → lands on ScheduleScreen
    }
  },
  child: /* acknowledgment content */,
)
```

For the "schedule peeks from below" effect: a `PageRouteBuilder` with a `SlideTransition` (translate from below, offset 0→1 on dismiss) or a `Stack` with an `AnimatedPositioned`. The simplest correct pattern in Phase 3 is to use the velocity threshold approach above with a standard `context.pop()` — the curve for the pop animation is Claude's discretion (locked decision says no animation required, only "acknowledgment slides up, schedule peeks from below" feel).

### Anti-Patterns to Avoid

- **Running algorithm in `build()`:** Never call `generateToday()` inside a `build` method. Trigger only on user action (mood tap) or `initState` (load only, not generate).
- **Passing `BuildContext` into the algorithm:** `ScheduleGeneratorService` must be pure Dart — no `Provider.of`, no `context.read`. The notifier fetches from context before calling the service.
- **Storing mood color in algorithm output:** Mood colors are a UI concern. The algorithm stores `moodIndex` in `DailySchedule`; the screen maps moodIndex → Color. Never store color hex in the model.
- **Hardcoding `DateTime.now()` inside the algorithm:** Pass `date` as a parameter so the algorithm is testable with any date.
- **Using `setState` in schedule screens:** All schedule state lives in `ScheduleNotifier`. Screens use `context.watch<ScheduleNotifier>()` or `Consumer<ScheduleNotifier>`. No `StatefulWidget` state for schedule data.
- **Showing clock times on discretionary chunks:** Only commitment-anchored chunks (`anchoredStartMinutes != null`) display a time label. Discretionary chunks show no time.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Color hex → Flutter `Color` | Custom parser | `hexToColor()` already in `goal_card.dart` | Already handles the `FF` prefix, handles `#` stripping |
| Date string formatting | String interpolation | `intl` `DateFormat('yyyy-MM-dd').format(date)` | Already installed; handles month/day zero-padding correctly |
| Today's weekday integer | Manual `DateTime.weekday` mapping | `DateTime.weekday` already returns 1=Monday…7=Sunday (ISO 8601) — matches `CommitmentBlock.daysOfWeek` directly | No mapping needed |
| Swipe gesture velocity detection | Custom `GestureRecognizer` | `GestureDetector.onVerticalDragEnd` with `primaryVelocity` threshold | Flutter built-in; well-tested |
| Schedule list scrolling | Custom scroll view | `ListView.builder` | Standard pattern; handles dynamic chunk count |
| State persistence across restarts | Manual serialization | `HiveDailyScheduleRepository.getTodaysSchedule()` — already scaffolded | Hive box already registered |

**Key insight:** The algorithm produces a `List<ScheduledChunk>` — a plain Dart list. All persistence, rendering, and routing complexity is handled by existing infrastructure. The algorithm itself is the only net-new logic.

---

## Common Pitfalls

### Pitfall 1: CommitmentBlock Day Filtering
**What goes wrong:** Generating commitment chunks for blocks that don't apply today (e.g., a "Work" block set to Mon–Fri being scheduled on Saturday).
**Why it happens:** `CommitmentBlock.daysOfWeek` is a `List<int>` (ISO weekday 1–7). Forgetting to filter by today's weekday before chunking.
**How to avoid:** `final todayWeekday = date.weekday;` then `blocks.where((b) => b.daysOfWeek.contains(todayWeekday))`.
**Warning signs:** Acceptance criterion 2 fails — commitment chunks appear on wrong days.

### Pitfall 2: Division by Zero in Urgency Score
**What goes wrong:** Outcome goal with `deadline == today` → `daysRemaining = 0` → urgency score = infinity or exception.
**Why it happens:** `urgency = priorityWeight * chunksRemaining / daysRemaining` — deadline today means 0 days remaining.
**How to avoid:** `final days = max(1, daysRemaining)`. Also handle null deadline (treat as very low urgency or exclude from outcome sorting entirely).
**Warning signs:** App crashes on mood tap when any goal has today's deadline.

### Pitfall 3: ScheduleNotifier Not Loaded at App Start
**What goes wrong:** `HomeScreen` and `ScheduleScreen` show stale state (null) even when a schedule was generated earlier today and persisted in Hive.
**Why it happens:** `ScheduleNotifier.loadToday()` must be called at startup, but `ScheduleNotifier` is constructed as an empty stub.
**How to avoid:** Call `loadToday()` from the `ScheduleNotifier` constructor or from `CanopyApp`'s `initState`. The pattern used by `SettingsNotifier.init()` in `main()` is the reference — apply the same init pattern.
**Warning signs:** Acceptance criterion 5 fails — schedule disappears on app restart.

### Pitfall 4: `DailySchedule.generatedAt` Field Default
**What goes wrong:** `generatedAt` uses a field declaration default `DateTime.now().toUtc()` — this runs at class definition time in Dart, not at construction time.
**Why it happens:** In Hive entities, `@HiveField` with a field-level default is evaluated once at app start, not per-instance.
**How to avoid:** Set `generatedAt` in the constructor body: `DailySchedule({...}) : id = id ?? _uuid.v4() { generatedAt = DateTime.now().toUtc(); }` or pass it as a named parameter. Verify the existing model sets this correctly at construction.
**Warning signs:** All `DailySchedule` records show the same `generatedAt` timestamp (app launch time).

### Pitfall 5: Bottom Nav Visible Under Check-in
**What goes wrong:** The check-in screen pushed within the shell branch shows the `NavigationBar` at the bottom, making the check-in feel like a sub-tab rather than a focused full-screen experience.
**Why it happens:** `StatefulShellRoute` keeps the shell (including `NavigationBar`) mounted behind child routes.
**How to avoid:** Check-in `Scaffold` must have `resizeToAvoidBottomInset: true` and a fully opaque background color. Since CONTEXT.md specifies the background tint shifts to mood color on tap, the initial background should be `Theme.of(context).colorScheme.surface` (opaque) until a mood is tapped. This completely obscures the nav bar underneath.
**Warning signs:** Can see bottom nav bar through check-in screen, or nav bar is partially visible.

### Pitfall 6: `DailySchedule` Embedded Chunks Not Updating in Hive
**What goes wrong:** Calling `schedule.chunks[i].isCompleted = true` (Phase 4 concern, but layout state in Phase 3) and saving doesn't persist the embedded list change.
**Why it happens:** Hive embedded objects — `List<ScheduledChunk>` inside `DailySchedule` — must have the entire parent object re-saved when child fields change. `schedule.save()` on the `HiveObject` triggers the write, but only if the box key matches.
**How to avoid (Phase 3):** Phase 3 only reads `isCompleted` / `isSkipped` to render done state. No mutation in Phase 3. Establish the pattern now: always call `_repo.save(schedule)` after any mutation, never mutate the embedded list and assume it auto-persists.
**Warning signs:** Done state disappears on hot reload or restart.

---

## Code Examples

Verified patterns from the existing codebase:

### Mood Color Lookup
```dart
// lib/screens/schedule/checkin_screen.dart
static const Map<int, Color> _moodColors = {
  1: Color(0xFF4A6275),
  2: Color(0xFF5C7A8A),
  3: Color(0xFF4A8C7A),
  4: Color(0xFF7AAF6A),
  5: Color(0xFFE8C547),
};

// hexToColor() from goal_card.dart can also be used:
// Color hexToColor(String hex) =>
//   Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
```

### Commitment Block Chunking
```dart
// In ScheduleGeneratorService.generate()
List<ScheduledChunk> _chunkCommitmentBlock(CommitmentBlock block) {
  final chunks = <ScheduledChunk>[];
  var cursor = block.startMinutes;
  var position = 0;
  while (cursor + 25 <= block.endMinutes) {
    chunks.add(ScheduledChunk(
      chunkTypeIndex: ChunkType.work.index,
      goalId: null, // commitment blocks have no Goal entity; use block.id or block.name in rationale
      durationMinutes: 25,
      anchoredStartMinutes: cursor,
      rationale: block.name,
    ));
    cursor += 25;
    position++;
  }
  return chunks;
}
```

### GoalCard Left Bar Pattern (reference — adapt for ChunkCard)
```dart
// Source: lib/screens/goals/widgets/goal_card.dart
Stack(
  children: [
    Positioned(
      left: 0, top: 0, bottom: 0, width: 5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: goalColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            bottomLeft: Radius.circular(12),
          ),
        ),
      ),
    ),
    Padding(padding: const EdgeInsets.only(left: 5), child: /* content */),
  ],
)
```

### Schedule Progress Bar
```dart
// lib/screens/schedule/widgets/schedule_progress_bar.dart
class ScheduleProgressBar extends StatelessWidget {
  const ScheduleProgressBar({super.key, required this.schedule});
  final DailySchedule schedule;

  @override
  Widget build(BuildContext context) {
    final workChunks = schedule.chunks
        .where((c) => c.chunkType == ChunkType.work).toList();
    final completed = workChunks.where((c) => c.isCompleted).length;
    final total = workChunks.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$completed of $total Chunks',
              style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: total == 0 ? 0 : completed / total,
            // color: moodColor — passed in from ScheduleScreen
          ),
        ],
      ),
    );
  }
}
```

### Weekday Filter for Commitment Blocks
```dart
// In generate():
final todayWeekday = date.weekday; // 1=Monday, 7=Sunday — matches ISO 8601
final todayBlocks = blocks.where(
  (b) => b.daysOfWeek.contains(todayWeekday)
).toList();
```

### Acknowledgment Weather Copy
```dart
// lib/screens/schedule/acknowledgment_screen.dart
static const Map<int, String> _moodPrefix = {
  1: 'Stormy day — keeping it light.',
  2: 'Overcast — gentle pace.',
  3: 'Partly cloudy — steady.',
  4: 'Clearing up — good flow.',
  5: 'Clear skies — let\'s go.',
};

String buildAckText(int moodIndex, int workChunkCount, String? firstChunkName) {
  final prefix = _moodPrefix[moodIndex] ?? '';
  final countText = '$workChunkCount chunk${workChunkCount == 1 ? '' : 's'}.';
  final startText = firstChunkName != null ? ' Starting with $firstChunkName.' : '';
  return '$prefix $countText$startText';
}
```

### Urgency Score (Outcome Goals)
```dart
// In generate() — avoid division by zero
double _urgencyScore(Goal g) {
  final weight = g.priorityWeight ?? 0.5;
  final deadline = g.deadline;
  if (deadline == null) return weight * 0.1; // low urgency, no deadline
  final daysRemaining = deadline.difference(date).inDays;
  final days = math.max(1, daysRemaining).toDouble();
  // chunksRemaining: no CompletionLog in Phase 3 — estimate as 2 (placeholder)
  const chunksRemaining = 2.0;
  return weight * chunksRemaining / days;
}
```

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| `MaterialApp` with named routes | `go_router` `StatefulShellRoute` with branches | Shell branches preserve scroll/state per tab; child routes within a branch don't disrupt shell |
| `setState` for all state | `ChangeNotifier` + `Provider` | `ScheduleNotifier` pattern already established in Phase 2 |
| Hive 2 (original) | `hive_ce` (community edition) | Same API, actively maintained; no migration required |

**No deprecated approaches to avoid:** The stack is current as of Phase 1.

---

## Integration Points Summary

| Consumer | Needs From ScheduleNotifier | How to Read |
|----------|----------------------------|-------------|
| `HomeScreen` | `todaySchedule?.moodIndex`, `todaySchedule?.chunks` (progress + next chunk) | `context.watch<ScheduleNotifier>()` |
| `ScheduleScreen` | `hasScheduleToday`, `todaySchedule`, `moodIndex` (for accent color) | `context.watch<ScheduleNotifier>()` |
| `CheckinScreen` | Calls `generateToday()` on mood confirm | `context.read<ScheduleNotifier>().generateToday(...)` |
| `AcknowledgmentScreen` | `todaySchedule.chunks` (count + first work chunk name) | Read from `ScheduleNotifier` after generate |

`GoalsNotifier.goals` and `CommitmentsNotifier.blocks` are already exposed as getters. `CheckinScreen` reads them before calling `generateToday()`.

---

## Open Questions

1. **`DailySchedule.generatedAt` field declaration bug**
   - What we know: The field uses `DateTime.now().toUtc()` as a field-level default, which Dart evaluates at class parse time, not instance construction time.
   - What's unclear: Whether this behaves correctly in the current Hive entity setup — needs verification at implementation time by logging the value on creation.
   - Recommendation: Set `generatedAt` explicitly in the constructor body to be safe.

2. **Time-target goal scheduling without CompletionLog**
   - What we know: Phase 3 has no `CompletionLog` data (Phase 4). The algorithm must schedule time-target goals without knowing how many hours were already spent this week.
   - What's unclear: Whether to treat each day as starting with full `weeklyHourBudget` remaining or to skip time-target sorting and schedule them by `priorityWeight` only.
   - Recommendation: In Phase 3, sort time-target goals by `priorityWeight ?? 0.5` descending (no budget tracking). The ROADMAP note "most behind weekly budget first" becomes accurate only after Phase 4 adds CompletionLog.

3. **CommitmentBlock goal association**
   - What we know: `CommitmentBlock` has no `goalId` field — it is not linked to a `Goal` entity. `ScheduledChunk.goalId` is null for commitment chunks.
   - What's unclear: How to display commitment chunk cards (no goal color, no goal name). The `rationale` field can hold the block name.
   - Recommendation: For commitment chunks, use `block.color` as the left-bar color and `block.name` as the card title (not goal name). This requires passing `CommitmentBlock` context to the `ChunkCard` widget or embedding the block name in `rationale`.

---

## Sources

### Primary (HIGH confidence)
- Direct codebase reading — all models, notifiers, router, and repository implementations verified from source
- `lib/data/models/daily_schedule.dart` — `DailySchedule` entity structure confirmed
- `lib/data/models/scheduled_chunk.dart` — `ScheduledChunk` + `ChunkType` enum confirmed
- `lib/data/models/goal.dart` — all `Goal` fields confirmed (priorityWeight, deadline, weeklyHourBudget, streakCount, frequencyPerWeek)
- `lib/data/models/commitment_block.dart` — `daysOfWeek` is `List<int>` ISO 8601 weekday confirmed
- `lib/providers/goals_notifier.dart` — `goals` getter confirmed as `List<Goal>`
- `lib/providers/commitments_notifier.dart` — `blocks` getter confirmed as `List<CommitmentBlock>`
- `lib/router.dart` — `StatefulShellRoute` structure confirmed; `/schedule` branch location confirmed
- `lib/screens/goals/widgets/goal_card.dart` — `hexToColor()` and left-bar pattern confirmed
- `.planning/phases/03-schedule-generation-and-morning-check-in/03-CONTEXT.md` — all locked decisions
- `.planning/ROADMAP.md` — Phase 3 algorithm specification (capacity table, break rules, allocation sequence)

### Secondary (MEDIUM confidence)
- go_router v17 child routes within `StatefulShellBranch` — pattern consistent with existing `/goals/archived` child route in the codebase

### Tertiary (LOW confidence)
- `DailySchedule.generatedAt` field declaration timing — flagged as open question; needs runtime verification

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all packages already installed, API shapes confirmed from source
- Architecture: HIGH — patterns derived from existing codebase, not assumptions
- Algorithm specification: HIGH — sourced directly from ROADMAP.md and CONTEXT.md
- Pitfalls: MEDIUM-HIGH — identified from code analysis; one flagged for runtime verification
- Swipe-up gesture: MEDIUM — Flutter GestureDetector is well-established; exact velocity threshold is discretionary

**Research date:** 2026-03-23
**Valid until:** Stable (Flutter/go_router APIs don't change frequently; codebase is the primary source)
