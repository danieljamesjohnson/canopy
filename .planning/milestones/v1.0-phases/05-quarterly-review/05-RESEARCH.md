# Phase 5: Quarterly Review - Research

**Researched:** 2026-04-03
**Domain:** Flutter data aggregation, fl_chart (PieChart/BarChart), paged review flow, GoalsNotifier priority update
**Confidence:** HIGH

## Summary

Phase 5 introduces the project's first charting library (fl_chart 1.2.0) and builds a full quarterly review flow on top of the already-solid CompletionLog and QuarterlySnapshot infrastructure from earlier phases. All the hard persistence work is done: HiveCompletionLogRepository can return all logs by date or goalId, HiveQuarterlySnapshotRepository has append/getLatest, and QuarterlySnapshot already has the right Hive fields (goalChunkTotals, reflectionAnswers) marked as stub-until-Phase-5. The implementation work is therefore primarily UI and aggregation logic — no new data models or repositories are needed.

The two charting widgets (donut + bar) are data-display-only per decisions D-01/D-04; no touch interaction is required. The reflection section follows the same PageView/PageController pattern already proven in OnboardingScreen. The goal-adjustment section extends the ReorderableListView.builder pattern from GoalsScreen. The home screen review banner, settings "Past Reviews" list, and GoalsNotifier priority update are targeted surgical additions to existing files.

The most important risk is the QuarterlySnapshot Hive model: it currently stores only `Map<String, int> goalChunkTotals` and `List<String> reflectionAnswers`. These stubs must be extended with new HiveFields to hold periodStartYmd, periodEndYmd (already present), and any new fields for priority adjustments captured during the review. Changes to Hive model field definitions require a `build_runner` codegen run.

**Primary recommendation:** Add fl_chart to pubspec, run `flutter pub get`, implement a pure-Dart `QuarterlyAggregationService` for data crunching, build three PageView sections in `quarterly_review_screen.dart`, add a `ReviewNotifier` (or inline state in StatefulWidget) to hold in-progress answers, and persist a fully populated `QuarterlySnapshot` on completion.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Both donut chart (time by goal proportions) and bar chart (completed chunks per week over the quarter) — as spec'd in ROADMAP
- **D-02:** Skipped chunks shown transparently as their own slice/category ("Time not spent") — honest, no hiding
- **D-03:** Hero stat at top: total chunks completed as a big number ("247 chunks completed this quarter")
- **D-04:** fl_chart used for both donut and bar chart (introduced this phase per ROADMAP)
- **D-05:** One question per screen, swipe to advance — focused, no overwhelm
- **D-06:** Tap-to-pick answers: 2-3 suggested answers per question (e.g. goal names from user's data) plus an "Other" option for free text
- **D-07:** Celebratory/warm tone — "Which goal gave you the most energy?" not "What did you miss?"
- **D-08:** Fixed question set in v1 (per ROADMAP) — configurable questions deferred to v2
- **D-09:** Priority reordering via drag — goals shown in priority order, drag to reorder for next quarter
- **D-10:** Suggest archiving underused goals with a gentle one-tap "Archive this?" prompt for goals with very low completion rates
- **D-11:** Updated priorities persist to GoalsNotifier and affect next morning's schedule generation (per ROADMAP acceptance criteria)
- **D-12:** Home screen banner ("Your quarterly review is ready") when within 7 days of the 90-day review window
- **D-13:** Always dismissable — review is optional, accessible from Settings > Past Reviews anytime
- **D-14:** Review launches as full-screen route at `/review` (already wired in router, outside shell — no bottom nav)
- **D-15:** Past reviews accessible from Settings screen (per ROADMAP: "visible in a 'Past reviews' list accessible from settings")

### Claude's Discretion
- Exact wording of the 3-5 reflection questions (within celebratory/warm tone constraint)
- Chart color scheme and styling details (goal colors from GoalsNotifier used where possible)
- Animation between reflection question screens
- Layout spacing, typography, and card styling for the data section
- Archive suggestion threshold (what completion rate counts as "very low")

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| fl_chart | ^1.2.0 | PieChart (donut) and BarChart | The locked library for this phase per D-04; verified as latest on pub.dev 2026-03-10 |
| hive_ce / hive_ce_flutter | already in pubspec | Persistence for QuarterlySnapshot | Already present from Phase 1 |
| provider | already in pubspec | GoalsNotifier, new ReviewNotifier | Already present |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| intl | already in pubspec | Date formatting for week labels in bar chart | Already present; use `DateFormat` for "Jan 6" style week labels |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| fl_chart | syncfusion_flutter_charts | fl_chart is locked; syncfusion requires a license |
| fl_chart | charts_flutter | fl_chart is locked; charts_flutter is archived/unmaintained |

**Installation:**
```bash
# Add to pubspec.yaml dependencies section:
#   fl_chart: ^1.2.0
flutter pub get
```

**Version verification:** Confirmed via pub.dev API on 2026-04-03: `fl_chart` latest = 1.2.0, published 2026-03-10.

---

## Architecture Patterns

### Recommended Project Structure
```
lib/
├── screens/quarterly_review/
│   ├── quarterly_review_screen.dart   # Replace stub — three-section PageView
│   ├── sections/
│   │   ├── data_section.dart          # Hero stat, donut, bar chart, top-3 goals
│   │   ├── reflection_section.dart    # PageView of question cards
│   │   └── adjustments_section.dart   # ReorderableListView + archive prompts
│   └── widgets/
│       ├── donut_chart.dart           # PieChart wrapper
│       ├── bar_chart_weekly.dart      # BarChart wrapper
│       └── reflection_question_card.dart  # Single question + tap-to-pick answers
├── services/
│   └── quarterly_aggregation_service.dart  # Pure-Dart; no Flutter imports
└── providers/
    └── review_notifier.dart           # Holds in-progress review state (OR inline StatefulWidget)
```

### Pattern 1: Aggregation Service (pure Dart)
**What:** A standalone service class that takes a list of `CompletionLog` entries and a date range, and returns structured totals — no Flutter dependency, easily testable.

**When to use:** All CompletionLog-to-chart-data transformations. Never do this inside a widget build method.

**Example:**
```dart
// lib/services/quarterly_aggregation_service.dart
class QuarterlyAggregationService {
  /// Returns chunks-per-goal totals over [startYmd..endYmd] inclusive.
  /// Skipped/deferred events count as NOT completed.
  Map<String, int> completedByGoal(
    List<CompletionLog> logs,
    String startYmd,
    String endYmd,
  ) {
    final result = <String, int>{};
    for (final log in logs) {
      if (log.dateYmd.compareTo(startYmd) < 0) continue;
      if (log.dateYmd.compareTo(endYmd) > 0) continue;
      if (log.event == CompletionEvent.completed) {
        result[log.goalId] = (result[log.goalId] ?? 0) + 1;
      }
    }
    return result;
  }

  /// Returns completed chunk count per ISO week (Monday-start) for bar chart.
  Map<String, int> completedByWeek(
    List<CompletionLog> logs,
    String startYmd,
    String endYmd,
  ) {
    final result = <String, int>{};
    for (final log in logs) {
      if (log.dateYmd.compareTo(startYmd) < 0) continue;
      if (log.dateYmd.compareTo(endYmd) > 0) continue;
      if (log.event != CompletionEvent.completed) continue;
      final date = DateTime.parse(log.dateYmd);
      // ISO week Monday: subtract weekday-1 days
      final monday = date.subtract(Duration(days: date.weekday - 1));
      final weekKey = monday.toIso8601String().substring(0, 10);
      result[weekKey] = (result[weekKey] ?? 0) + 1;
    }
    return result;
  }

  /// Count of skipped+deferred events — shown as "Time not spent" slice (D-02).
  int notSpentCount(List<CompletionLog> logs, String startYmd, String endYmd) {
    return logs.where((l) {
      if (l.dateYmd.compareTo(startYmd) < 0) return false;
      if (l.dateYmd.compareTo(endYmd) > 0) return false;
      return l.event == CompletionEvent.skipped ||
          l.event == CompletionEvent.deferred;
    }).length;
  }
}
```

### Pattern 2: fl_chart PieChart — Donut
**What:** `PieChart` with `centerSpaceRadius` set to a non-zero value creates the donut hole.

**When to use:** Section 1 data display. No touch interaction (no `pieTouchData` listener needed — set `touchCallback: null` or leave default).

**Example:**
```dart
// Source: https://github.com/imaNNeoFighT/fl_chart/blob/main/repo_files/documentations/pie_chart.md
PieChart(
  PieChartData(
    centerSpaceRadius: 60,
    centerSpaceColor: Theme.of(context).colorScheme.surface,
    sections: [
      // One per goal, plus one "Time not spent" slice
      PieChartSectionData(
        value: completedCount.toDouble(),
        color: goalColor,
        title: '${goalName}\n${pct.toStringAsFixed(0)}%',
        radius: 50,
        showTitle: false, // use legend below chart instead
      ),
      PieChartSectionData(
        value: notSpentCount.toDouble(),
        color: Colors.grey.shade300,
        title: 'Not spent',
        showTitle: false,
      ),
    ],
    sectionsSpace: 2,
  ),
)
```

### Pattern 3: fl_chart BarChart — Weekly Chunks
**What:** `BarChart` with one `BarChartGroupData` per week, x positions derived from week index.

**When to use:** Section 1, bar chart of completed chunks per week.

**Example:**
```dart
// Source: https://github.com/imaNNeoFighT/fl_chart/blob/main/repo_files/documentations/bar_chart.md
BarChart(
  BarChartData(
    barGroups: weeklyData.entries.toList().asMap().entries.map((e) {
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: e.value.value.toDouble(),
            color: Theme.of(context).colorScheme.primary,
            width: 14,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList(),
    titlesData: FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) {
            // Show "Jan 6" style label from the week key
            return Text(weekLabels[value.toInt()],
                style: const TextStyle(fontSize: 10));
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(showTitles: true, reservedSize: 28),
      ),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    ),
    gridData: const FlGridData(show: false),
    borderData: FlBorderData(show: false),
  ),
)
```

### Pattern 4: PageView for Reflection Section
**What:** Reuse the proven `PageController` + `PageView` from `OnboardingScreen`. `NeverScrollableScrollPhysics` on the PageView; swipe handled by `GestureDetector` on each question card (or programmatic `nextPage` on answer tap).

**When to use:** Section 2 — one question per screen (D-05).

**Example:**
```dart
// Pattern from lib/screens/onboarding/onboarding_screen.dart
final _controller = PageController();

PageView(
  controller: _controller,
  physics: const NeverScrollableScrollPhysics(),
  children: _questions.map((q) => ReflectionQuestionCard(
    question: q,
    suggestedAnswers: q.buildSuggestions(goals),
    onAnswered: (answer) {
      _recordAnswer(answer);
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    },
  )).toList(),
)
```

### Pattern 5: Drag-to-Reorder for Goal Adjustments
**What:** `ReorderableListView.builder` with `ReorderableDelayedDragStartListener` — identical to GoalsScreen. After drag, call `GoalsNotifier.reorder()` per goal type group, or a new `reorderAll(List<Goal>)` method if cross-type reordering is needed.

**When to use:** Section 3 — priority drag to set next-quarter priorities (D-09).

**Note:** `GoalsNotifier.reorder()` currently reorders within a single `GoalType` group. For the review's flat list (all goals together), a new `reorderAll(List<String> orderedIds)` method may be needed — examine whether goals should be reordered across types or only within types during the review.

### Pattern 6: Review Window Detection
**What:** Compare `DateTime.now()` against `latestSnapshot.completedAt.add(Duration(days: 90))`. If within 7 days of that date, show banner. If no snapshot exists, fall back to app install date or first CompletionLog entry date + 90 days.

**When to use:** HomeScreen banner logic and Settings "Past Reviews" display.

```dart
// In HomeScreen or a ReviewWindowService
bool isInReviewWindow(QuarterlySnapshot? latest, List<CompletionLog> allLogs) {
  final DateTime windowStart;
  if (latest != null) {
    windowStart = latest.completedAt.add(const Duration(days: 90));
  } else if (allLogs.isNotEmpty) {
    final firstDate = allLogs
        .map((l) => DateTime.parse(l.dateYmd))
        .reduce((a, b) => a.isBefore(b) ? a : b);
    windowStart = firstDate.add(const Duration(days: 90));
  } else {
    return false;
  }
  final now = DateTime.now();
  return now.isAfter(windowStart.subtract(const Duration(days: 7))) &&
      now.isBefore(windowStart.add(const Duration(days: 30)));
}
```

### Anti-Patterns to Avoid
- **Aggregating inside `build()`:** CompletionLog queries are async and O(n). Always aggregate in a service or notifier `init()` call, store results in state.
- **Calling `GoalsNotifier.loadGoals()` from within the review screen build:** Use `context.read` in callbacks; `context.watch` in `build()` for live data.
- **Blocking PieChart with `pieTouchData` callbacks:** D-01 specifies no user interaction on charts; leave touch disabled.
- **Overwriting past QuarterlySnapshots:** The repository is append-only. Never call `_box.put(existingId, ...)` on an existing snapshot; always create a new one with a new UUID.
- **Storing raw goal objects in QuarterlySnapshot:** `goalChunkTotals` stores `Map<String, int>` (goalId -> count). This is the correct approach — goal names can change; IDs are stable.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Donut chart rendering | Custom `CustomPainter` pie/arc math | `fl_chart PieChart` with `centerSpaceRadius` | Arc math with touch hit-testing is subtle; fl_chart handles geometry, clipping, and spacing |
| Bar chart rendering | Custom canvas bar drawing | `fl_chart BarChart` | Axis label layout, scale calculation, and responsive sizing are non-trivial |
| Date arithmetic for weekly buckets | Home-rolled week-boundary logic | `DateTime.weekday` + `Duration` arithmetic (see Pattern 1) | Flutter/Dart stdlib is sufficient; no external package needed |
| Reorderable list | Manual drag gestures | `ReorderableListView.builder` (Flutter SDK) | Already proven in GoalsScreen |

**Key insight:** fl_chart handles all chart geometry. The project's responsibility is only: (1) aggregate CompletionLog data into the right shape, and (2) map goalId colors from GoalsNotifier._colorPalette.

---

## Common Pitfalls

### Pitfall 1: QuarterlySnapshot Missing HiveFields
**What goes wrong:** The `QuarterlySnapshot` model stub has `goalChunkTotals` and `reflectionAnswers` but no field for `priorityAdjustments` or `archiveRecommendations`. If these are needed in the snapshot record, new `@HiveField` entries are required.

**Why it happens:** The stub was created in Phase 1 with minimal fields; Phase 5 is the first time the full schema is needed.

**How to avoid:** Before implementing, define the complete `QuarterlySnapshot` Hive schema including any new fields (e.g., `Map<String, int> goalPriorityOrder`, `List<String> archivedGoalIds`). Add `@HiveField` entries with the next available index (currently last is `@HiveField(5)`). Run `dart run build_runner build --delete-conflicting-outputs` to regenerate `quarterly_snapshot.g.dart`.

**Warning signs:** App crashes at snapshot read/write with Hive type adapter errors; `MissingAdapterException`.

### Pitfall 2: CompletionLogRepository Has No Date-Range Query
**What goes wrong:** `CompletionLogRepository.getByDate(String dateYmd)` returns entries for a single date only. A quarterly review spans ~90 days. Calling `getByDate` 90 times is feasible but ugly; `getAll()` and filtering in Dart is simpler and correct for local data.

**Why it happens:** The repository interface was designed for day-granularity (Phase 4). No `getByDateRange` exists.

**How to avoid:** Use `getAll()` and filter in `QuarterlyAggregationService`. Performance is acceptable for local Hive storage where record counts are in the low thousands.

**Warning signs:** Accidental use of a single-date query for a quarter-wide chart; chart shows only one day's data.

### Pitfall 3: fl_chart PieChart Section Colors Must Be Non-Null
**What goes wrong:** `PieChartSectionData.color` defaults to `Colors.red` if not set. If goal `color` is null (auto-assign not yet run), the chart shows red slices.

**Why it happens:** Goals created early in onboarding may have `color == null` (the palette auto-assigns on save, but the field is nullable on the model).

**How to avoid:** In chart data preparation, resolve goal colors via `GoalsNotifier.autoColor()` fallback logic or maintain a local `colorForGoalId()` helper that falls back to the palette index:
```dart
Color colorForGoal(Goal goal, int index) {
  if (goal.color != null) return hexToColor(goal.color!);
  final palette = GoalsNotifier._colorPalette; // or duplicate the list
  return Color(int.parse(palette[index % palette.length].replaceFirst('#', '0xFF')));
}
```

**Warning signs:** All donut slices appear red; chart looks broken.

### Pitfall 4: Review Window Logic When No Snapshot Exists (First-Time User)
**What goes wrong:** `QuarterlySnapshotRepository.getLatest()` returns null for first-time users. Code that blindly calls `.completedAt` on the result will throw a null dereference.

**Why it happens:** The banner logic assumes at least one past review exists.

**How to avoid:** Always null-check `getLatest()`. For first-time users, derive the review window from the earliest `CompletionLog` date. If no logs exist, show no banner.

### Pitfall 5: GoalsNotifier.reorder() Is Type-Scoped
**What goes wrong:** The existing `reorder(GoalType type, int oldIndex, int newIndex)` method only reorders within one type group. The review's adjustments section (D-09) shows all goals together for priority drag — cross-type reorder may be intended.

**Why it happens:** GoalsScreen uses type-sectioned reordering; the review may need flat ordering across all types.

**How to avoid:** Clarify in planning whether cross-type reordering is required. If yes, add a `reorderAll(List<String> orderedIds)` method to GoalsNotifier that sets `sortOrder` globally across types. If reordering is within-type only, use separate sections in the adjustments list.

### Pitfall 6: build_runner Must Be Re-Run After Hive Model Changes
**What goes wrong:** Modifying `quarterly_snapshot.dart` (new `@HiveField`) without regenerating `quarterly_snapshot.g.dart` causes a build-time error.

**How to avoid:** Any Wave that modifies a Hive model must include as a first task: `dart run build_runner build --delete-conflicting-outputs && flutter analyze`.

---

## Code Examples

Verified patterns from official sources and existing codebase:

### Donut Chart — Minimal Working Example
```dart
// Source: pub.dev/packages/fl_chart v1.2.0 + pie_chart.md GitHub docs
SizedBox(
  height: 200,
  child: PieChart(
    PieChartData(
      centerSpaceRadius: 60,
      centerSpaceColor: Theme.of(context).colorScheme.surface,
      sectionsSpace: 2,
      sections: goalSlices + [notSpentSlice],
    ),
  ),
)
```

### Bar Chart — Weekly Counts
```dart
// Source: bar_chart.md GitHub docs
SizedBox(
  height: 180,
  child: BarChart(
    BarChartData(
      barGroups: weeklyGroups,
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, m) => Text(weekLabels[v.toInt()],
                style: const TextStyle(fontSize: 9)),
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: true, reservedSize: 28),
        ),
      ),
      borderData: FlBorderData(show: false),
      gridData: const FlGridData(show: false),
    ),
  ),
)
```

### QuarterlySnapshot — Full Population on Save
```dart
// Pattern: create fully populated snapshot at review completion
final snapshot = QuarterlySnapshot(
  periodStartYmd: startYmd,
  periodEndYmd: endYmd,
)
  ..goalChunkTotals = aggregatedTotals        // Map<String, int>
  ..reflectionAnswers = collectedAnswers;      // List<String>
  // add new HiveFields for priority order if needed

await HiveQuarterlySnapshotRepository().append(snapshot);
```

### hexToColor Helper (already exists in chunk_card.dart)
```dart
// Re-use or import from lib/screens/schedule/widgets/chunk_card.dart
Color hexToColor(String hex) =>
    Color(int.parse(hex.replaceFirst('#', '0xFF')));
```

### GoalsNotifier.reorder — Existing Signature
```dart
// lib/providers/goals_notifier.dart — existing method
Future<void> reorder(GoalType type, int oldIndex, int newIndex) async { ... }
// Note: if cross-type reorder is needed, add:
Future<void> reorderAll(List<String> orderedGoalIds) async { ... }
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| charts_flutter (Google) | fl_chart | charts_flutter archived ~2022 | fl_chart is the community standard for Flutter charts |
| fl_chart positional API | fl_chart named-parameter API | fl_chart v0.40+ | All constructors use named params; old positional examples in blog posts are stale |

**Deprecated/outdated:**
- `PieChartSectionData(color: Colors.red)` positional: Use named parameters. `PieChartSectionData(color: ..., value: ..., radius: ...)`.
- `BarChartData` `gridData: FlGridData(show: true)` with deprecated constructors: Use `const FlGridData(show: false)` for no-grid charts.

---

## Open Questions

1. **Cross-type goal reordering in Section 3**
   - What we know: GoalsNotifier.reorder() is type-scoped; D-09 says "goals shown in priority order, drag to reorder"
   - What's unclear: Are all goals shown in a single flat list (requiring cross-type sort), or are they grouped by type?
   - Recommendation: Planner should decide — if flat list, add `reorderAll(List<String> orderedIds)` to GoalsNotifier.

2. **QuarterlySnapshot — persist priority adjustments?**
   - What we know: The snapshot has `goalChunkTotals` and `reflectionAnswers`; D-11 says updated priorities persist to GoalsNotifier
   - What's unclear: Should the snapshot also record what priority changes were made (for "Past Reviews" display), or is GoalsNotifier the sole source of priority truth?
   - Recommendation: Store `Map<String, int> goalPrioritySnapshot` (goalId -> sortOrder at review time) as a new HiveField. This makes past reviews meaningful without adding architectural complexity.

3. **Archive suggestion threshold (D-10)**
   - What we know: "very low completion rates" — discretion granted to Claude
   - Recommendation: Use <= 20% completion rate over the quarter as the threshold (1-in-5 scheduled chunks completed). Flag goals with zero completions as high-priority archive candidates.

4. **Review window start for first-time user (no prior snapshot)**
   - What we know: `getLatest()` returns null if no reviews done; first review window should be ~90 days after first use
   - Recommendation: Fall back to `min(CompletionLog.dateYmd)` + 90 days. If no logs exist, show no banner.

---

## Environment Availability

Step 2.6: SKIPPED (no new external CLI tools or services needed — fl_chart is a pub.dev package installed via `flutter pub get`, which is already confirmed working in the project).

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in Flutter SDK) |
| Config file | none (uses flutter test runner directly) |
| Quick run command | `flutter test` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

No formal requirement IDs were provided for this phase. Key behaviors map to tests as follows:

| Behavior | Test Type | Automated Command | File Exists? |
|----------|-----------|-------------------|-------------|
| `QuarterlyAggregationService.completedByGoal` returns correct totals | unit | `flutter test test/services/quarterly_aggregation_service_test.dart` | Wave 0 |
| `completedByWeek` buckets entries into correct ISO weeks | unit | `flutter test test/services/quarterly_aggregation_service_test.dart` | Wave 0 |
| `notSpentCount` counts skipped+deferred correctly | unit | `flutter test test/services/quarterly_aggregation_service_test.dart` | Wave 0 |
| Review window detection (within 7 days of 90-day mark) | unit | `flutter test test/services/quarterly_aggregation_service_test.dart` | Wave 0 |
| QuarterlySnapshot persists with all fields populated | unit | `flutter test test/repositories/quarterly_snapshot_repository_test.dart` | Wave 0 |
| DonutChartWidget renders without errors | widget | `flutter test test/widgets/donut_chart_test.dart` | Wave 0 |
| ReflectionQuestionCard tap-to-pick invokes callback | widget | `flutter test test/widgets/reflection_question_card_test.dart` | Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test`
- **Per wave merge:** `flutter test && flutter analyze`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/services/quarterly_aggregation_service_test.dart` — covers aggregation logic
- [ ] `test/widgets/donut_chart_test.dart` — covers PieChart widget rendering
- [ ] `test/widgets/reflection_question_card_test.dart` — covers tap-to-pick interaction
- [ ] `test/repositories/quarterly_snapshot_repository_test.dart` — covers append-only persistence

---

## Project Constraints (from CLAUDE.md)

| Directive | Implication for Phase 5 |
|-----------|------------------------|
| State management: `StatefulWidget` + `setState()` — no external state management library | In-progress review state (current answers, current section index) lives in a `StatefulWidget`. Do NOT introduce Riverpod, BLoC, etc. GoalsNotifier (ChangeNotifier/Provider) is the established pattern and is fine to continue using. |
| Routing: Single-screen `MaterialApp` with no routing library | FALSE as of Phase 1 — go_router is installed and the project uses it. Router is already wired. `/review` route exists. |
| Theme: Material 3 with `ColorScheme.fromSeed(Colors.deepOrangeAccent)` | All review screen widgets must use `Theme.of(context).colorScheme.*` for colors. Chart colors should pull from `GoalsNotifier._colorPalette` where possible. |
| Linting: `package:flutter_lints` | Run `flutter analyze` after every file change. No lint warnings in committed code. |
| Dart SDK: `^3.10.3` | fl_chart 1.2.0 is compatible. |

---

## Sources

### Primary (HIGH confidence)
- pub.dev/packages/fl_chart — version 1.2.0 confirmed via pub.dev API on 2026-04-03
- github.com/imaNNeoFighT/fl_chart/blob/main/repo_files/documentations/pie_chart.md — PieChartData, centerSpaceRadius, PieChartSectionData parameters
- github.com/imaNNeoFighT/fl_chart/blob/main/repo_files/documentations/bar_chart.md — BarChartData, BarChartGroupData, BarChartRodData, FlTitlesData
- Canopy codebase (all files read above): CompletionLog, QuarterlySnapshot, repositories, GoalsNotifier, OnboardingScreen, GoalsScreen, router.dart

### Secondary (MEDIUM confidence)
- pub.dev/packages/fl_chart landing page — confirmed dependency list (equatable, vector_math), MIT license, platform support

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — fl_chart version verified directly from pub.dev API; all other libraries already in pubspec
- Architecture: HIGH — patterns derived directly from existing codebase files; fl_chart API verified from official GitHub docs
- Pitfalls: HIGH — derived from direct inspection of existing Hive models, repository interfaces, and GoalsNotifier code

**Research date:** 2026-04-03
**Valid until:** 2026-05-03 (fl_chart 1.2.0 is recent; stable for 30 days)
