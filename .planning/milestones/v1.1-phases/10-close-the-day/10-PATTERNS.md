# Phase 10: Close the Day — Pattern Map

**Mapped:** 2026-06-11
**Files analyzed:** 7 new/modified files
**Analogs found:** 7 / 7

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/data/models/scheduled_chunk.dart` | model | CRUD | self (HiveField 8 `isDeferred` is the additive-field pattern) | exact |
| `lib/data/database/migrations.dart` | config | batch | self (`_migration3to4` / `currentSchemaVersion`) | exact |
| `lib/data/models/app_settings.dart` | model | CRUD | self (HiveField 2–6 are the analog for adding HiveField 7) | exact |
| `lib/providers/settings_notifier.dart` | provider | request-response | self (`setMidDayNudgeEnabled` / `setMidDayNudgeMinutes`) | exact |
| `lib/services/notification_service.dart` | service | event-driven | self (`scheduleMidDayNudge` / id 1 is the exact template for id 2) | exact |
| `lib/providers/schedule_notifier.dart` | provider | CRUD | self (`markDeferred`, `generateToday`) | exact |
| `lib/services/schedule_generator.dart` | service | batch | self (Step 1 commitment loop, `computeStreak`) | exact |
| `lib/screens/home/home_screen.dart` | component | request-response | `lib/screens/home/widgets/review_banner.dart` | exact |
| `lib/screens/settings/settings_screen.dart` | component | request-response | self (mid-day nudge `ListTile` block lines 123–163) | exact |

---

## Pattern Assignments

### `lib/data/models/scheduled_chunk.dart` — add `commitmentId` HiveField 9

**Analog:** HiveField 8 `isDeferred` in the same file (lines 50–51).

**Additive field pattern** (lines 50–51 — the immediately-preceding field):
```dart
@HiveField(8)
bool isDeferred = false;
```

**New field follows the same shape** — nullable String with no initializer (reads as null for old records):
```dart
/// CommitmentBlock.id for commitment-anchored chunks; null for discretionary chunks.
/// Populated by ScheduleGeneratorService.generate() (Step 1).
/// Logged by markComplete / markSkipped / markDeferred via commitmentId ?? '' guard.
@HiveField(9)
String? commitmentId;
```

Also add `commitmentId` as a named parameter in the constructor, mirroring the existing optional params like `anchoredStartMinutes`.

After editing the source file, regenerate `scheduled_chunk.g.dart`:
```bash
dart run build_runner build --delete-conflicting-outputs
```

---

### `lib/data/database/migrations.dart` — bump schemaVersion 4 → 5

**Analog:** `_migration3to4` pattern (lines 37–42) and `currentSchemaVersion` constant (line 3).

**Exact pattern to copy** (lines 3, 37–42):
```dart
const int currentSchemaVersion = 4;   // bump to 5

// ...existing migrations unchanged...

Future<void> _migration3to4() async {
  // Phase 8: ScheduledChunk expanded with isDeferred (HiveField 8, bool, default false).
  // Additive bool field — Hive CE binary reader returns false for missing
  // HiveField(8) in existing ScheduledChunk records.
  // No data transformation needed.
}
```

**New entry to append** (append to `_migrations` list and add function):
```dart
const int currentSchemaVersion = 5;

// Add to _migrations list:
_migration4to5,

// Add function:
Future<void> _migration4to5() async {
  // Phase 10: ScheduledChunk gains commitmentId (HiveField 9, String?, default null)
  // and AppSettings gains eveningReminderEnabled (HiveField 7, bool, default false)
  // and eveningReminderMinutes (HiveField 8, int, default 1200).
  // All additive nullable/defaulted fields — Hive CE binary reader returns
  // null/false/0 for missing fields in existing records.
  // No data transformation needed.
}
```

The `assert(_migrations.length == currentSchemaVersion, ...)` at line 52 enforces that the list length matches the version — adding the new entry satisfies it.

---

### `lib/data/models/app_settings.dart` — add evening-reminder fields HiveField 7 & 8

**Analog:** HiveField 2–3 mid-day nudge pair (lines 21–26) in the same file.

**Existing pair pattern** (lines 21–26):
```dart
/// Mid-day nudge opt-in (default false per ROADMAP.md).
@HiveField(2)
bool midDayNudgeEnabled = false;

/// Mid-day nudge time in minutes from midnight (default 720 = 12:00pm).
@HiveField(3)
int midDayNudgeMinutes = 720;
```

**New fields to add** — append after HiveField 6 (`lastMoodSetYmdInt`):
```dart
/// Evening reminder opt-in (default false — opt-in per CLOSE-01).
@HiveField(7)
bool eveningReminderEnabled = false;

/// Evening reminder time in minutes from midnight (default 1200 = 8:00pm).
@HiveField(8)
int eveningReminderMinutes = 1200;
```

Regenerate `app_settings.g.dart` after editing:
```bash
dart run build_runner build --delete-conflicting-outputs
```

---

### `lib/providers/settings_notifier.dart` — add evening-reminder getters + setters

**Analog:** `_midDayNudgeEnabled` / `_midDayNudgeMinutes` block (lines 18–75) in the same file.

**Field + getter pattern** (lines 18–22):
```dart
bool _midDayNudgeEnabled = false;
int get midDayNudgeEnabled => _midDayNudgeEnabled;

int _midDayNudgeMinutes = 720;
int get midDayNudgeMinutes => _midDayNudgeMinutes;
```

**init() hydration pattern** (lines 31–32):
```dart
_midDayNudgeEnabled = settings?.midDayNudgeEnabled ?? false;
_midDayNudgeMinutes = settings?.midDayNudgeMinutes ?? 720;
```

**Setter pattern** (lines 61–75):
```dart
Future<void> setMidDayNudgeEnabled(bool value) async {
  _midDayNudgeEnabled = value;
  final settings = await _repository.getSettings() ?? AppSettings();
  settings.midDayNudgeEnabled = value;
  await _repository.saveSettings(settings);
  notifyListeners();
}

Future<void> setMidDayNudgeMinutes(int value) async {
  _midDayNudgeMinutes = value;
  final settings = await _repository.getSettings() ?? AppSettings();
  settings.midDayNudgeMinutes = value;
  await _repository.saveSettings(settings);
  notifyListeners();
}
```

**New members to add** — mirror exactly with evening names and defaults:
```dart
bool _eveningReminderEnabled = false;
bool get eveningReminderEnabled => _eveningReminderEnabled;

int _eveningReminderMinutes = 1200;
int get eveningReminderMinutes => _eveningReminderMinutes;

// In init():
_eveningReminderEnabled = settings?.eveningReminderEnabled ?? false;
_eveningReminderMinutes = settings?.eveningReminderMinutes ?? 1200;

Future<void> setEveningReminderEnabled(bool value) async {
  _eveningReminderEnabled = value;
  final settings = await _repository.getSettings() ?? AppSettings();
  settings.eveningReminderEnabled = value;
  await _repository.saveSettings(settings);
  notifyListeners();
}
```

Note: no `setEveningReminderMinutes` needed this phase (time is fixed at 1200, no picker UI per CONTEXT.md).

---

### `lib/services/notification_service.dart` — add `scheduleEveningReminder` / `cancelEveningReminder`

**Analog:** `scheduleMidDayNudge` (lines 132–173) + `cancelMidDayNudge` (lines 183–185) in the same file. The only differences are id, channel strings, and notification copy.

**Full method to copy and adapt** (lines 132–173):
```dart
static Future<void> scheduleMidDayNudge(int minutesFromMidnight) async {
  if (kIsWeb) return;
  // LOOP-04: zonedSchedule is not supported on Linux or Windows desktop —
  // degrade gracefully so the app does not crash when running on those
  // platforms. iOS and Android are the real targets.
  if (Platform.isLinux || Platform.isWindows) return;
  await _plugin.cancel(id: 1);
  final hour = minutesFromMidnight ~/ 60;
  final minute = minutesFromMidnight % 60;

  final now = tz.TZDateTime.now(tz.local);
  var scheduled = tz.TZDateTime(
    tz.local,
    now.year,
    now.month,
    now.day,
    hour,
    minute,
  );
  if (scheduled.isBefore(now)) {
    scheduled = scheduled.add(const Duration(days: 1));
  }

  await _plugin.zonedSchedule(
    id: 1,
    title: "How's your day going?",
    body: 'Check in on your schedule.',
    scheduledDate: scheduled,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'midday_nudge',
        'Mid-day nudge',
        channelDescription: 'Optional mid-day schedule reminder',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
    ),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    matchDateTimeComponents: DateTimeComponents.time,
  );
}
```

**New method substitutions** (copy above, change these values):
- `id: 1` → `id: 2`
- `'midday_nudge'` → `'evening_reminder'`
- `'Mid-day nudge'` → `'Evening reminder'`
- `'Optional mid-day schedule reminder'` → `'Opt-in evening schedule reminder'`
- title: `'Canopy'` (matches morning notification pattern per UI-SPEC copywriting)
- body: `'Time to close the day. See how your chunks went.'`

**Cancel method** (lines 183–185):
```dart
static Future<void> cancelMidDayNudge() async {
  if (kIsWeb) return;
  await _plugin.cancel(id: 1);
}
```
Mirror with `cancelEveningReminder` / `id: 2`.

---

### `lib/providers/schedule_notifier.dart` — wire CLOSE-02 and CLOSE-03

**Three change sites; all analogs are within the same file.**

#### Change site 1: `markDeferred` — switch event to `CompletionEvent.deferred` + write `commitmentId`

**Existing log call in `markDeferred`** (lines 296–301):
```dart
await _logRepo.append(
  CompletionLog(
    chunkId: chunkId,
    goalId: chunk.goalId ?? '',
    dateYmd: dateYmd,
    eventIndex: CompletionEvent.skipped.index, // Phase 8: log as skipped
  ),
);
```

**Change to** (Phase 10):
```dart
await _logRepo.append(
  CompletionLog(
    chunkId: chunkId,
    goalId: chunk.commitmentId ?? chunk.goalId ?? '',
    dateYmd: dateYmd,
    eventIndex: CompletionEvent.deferred.index, // CLOSE-02: real deferred event
  ),
);
```

#### Change site 2: `markComplete` and `markSkipped` — write `commitmentId` for commitment chunks

**Existing log call in `markComplete`** (lines 156–163):
```dart
await _logRepo.append(
  CompletionLog(
    chunkId: chunkId,
    goalId: chunk.goalId ?? '',
    dateYmd: dateYmd,
    eventIndex: CompletionEvent.completed.index,
  ),
);
```

**Change to** (CLOSE-03 fix — use `commitmentId` when present, fall back to `goalId`):
```dart
await _logRepo.append(
  CompletionLog(
    chunkId: chunkId,
    goalId: chunk.commitmentId ?? chunk.goalId ?? '',
    dateYmd: dateYmd,
    eventIndex: CompletionEvent.completed.index,
  ),
);
```
Apply the same `chunk.commitmentId ?? chunk.goalId ?? ''` pattern to the log call in `markSkipped`.

#### Change site 3: `generateToday` — thread carried-over deferred chunks

**Existing `generate()` call** (lines 116–123):
```dart
final chunks = _generator.generate(
  goals: goals,
  blocks: blocks,
  moodIndex: moodIndex,
  date: date,
  completionLogs: allLogs,
  lighterDay: lighterDay,
);
```

**Carry-in lookup to add before the generate call** (CLOSE-02, single-hop):
```dart
// CLOSE-02: single-hop deferred carry-in from the immediately preceding day.
// Only discretionary (non-commitment) deferred chunks re-enter as fresh demand
// for their goal. Commitment chunks are anchored to their day and do not carry.
final yesterday = date.subtract(const Duration(days: 1));
final yesterdayYmd = DateFormat('yyyy-MM-dd').format(yesterday);
final priorSchedule = await _repo.getByDate(yesterdayYmd);
final deferredGoalIds = priorSchedule?.chunks
    .where((c) => c.isDeferred && !c.isCompleted && c.goalId != null)
    .map((c) => c.goalId!)
    .toSet() ?? {};

final chunks = _generator.generate(
  goals: goals,
  blocks: blocks,
  moodIndex: moodIndex,
  date: date,
  completionLogs: allLogs,
  lighterDay: lighterDay,
  deferredGoalIds: deferredGoalIds, // CLOSE-02 carry-in
);
```

The generator's `generate()` signature gains `Set<String> deferredGoalIds = const {}` — goals in this set get priority in Step 2/3/4 allocation or get a forced slot.

---

### `lib/services/schedule_generator.dart` — CLOSE-02 carry-in + CLOSE-03 commitmentId + deferred streak

**Three change sites.**

#### Change site 1: Step 1 commitment chunk creation — add `commitmentId`

**Existing** (lines 204–212):
```dart
workChunks.add(
  ScheduledChunk(
    chunkTypeIndex: ChunkType.work.index,
    goalId: null,
    durationMinutes: 25,
    anchoredStartMinutes: cursor,
    rationale: block.name,
  ),
);
```

**Change to** (CLOSE-03):
```dart
workChunks.add(
  ScheduledChunk(
    chunkTypeIndex: ChunkType.work.index,
    goalId: null,
    commitmentId: block.id,   // CLOSE-03: real block id for attribution
    durationMinutes: 25,
    anchoredStartMinutes: cursor,
    rationale: block.name,
  ),
);
```

#### Change site 2: `computeStreak` — treat `deferred` as non-breaking

**Existing completed-date index** (lines 76–79):
```dart
final completedDates = <String>{
  for (final l in allLogs)
    if (l.goalId == goalId && l.event == CompletionEvent.completed) l.dateYmd,
};
```

**Add a deferred-dates index** (CLOSE-02 — a deferred day is not a miss):
```dart
final completedDates = <String>{
  for (final l in allLogs)
    if (l.goalId == goalId && l.event == CompletionEvent.completed) l.dateYmd,
};
// CLOSE-02: deferred days do not break the streak — treated as "moved, not missed".
final deferredDates = <String>{
  for (final l in allLogs)
    if (l.goalId == goalId && l.event == CompletionEvent.deferred) l.dateYmd,
};
```

**Existing streak walk** (lines 85–95 — the `else { break; }` is the streak-reset):
```dart
if (completedDates.contains(ymd)) {
  streak++;
} else {
  break; // due day with no completion (missed or skipped) — reset
}
```

**Change to** (non-breaking deferred):
```dart
if (completedDates.contains(ymd)) {
  streak++;
} else if (deferredDates.contains(ymd)) {
  // CLOSE-02: deferred — count as continuing (move, not miss); do not increment.
} else {
  break; // missed or skipped — reset
}
```

#### Change site 3: `generate()` signature — accept `deferredGoalIds`

Add parameter to the public `generate()` method:
```dart
List<ScheduledChunk> generate({
  required List<Goal> goals,
  required List<CommitmentBlock> blocks,
  required int moodIndex,
  required DateTime date,
  required List<CompletionLog> completionLogs,
  bool lighterDay = false,
  Set<String> deferredGoalIds = const {},  // CLOSE-02 carry-in
}) {
```

Goals in `deferredGoalIds` that are not already in the work chunk list after Steps 2–4 (i.e., they were not due today or were below mood cap) get a single additional slot injected — "re-materialized as fresh demand" without duplicating if already scheduled.

---

### `lib/screens/home/home_screen.dart` — insert `EndOfDayCard`

**Analog:** `ReviewBanner` insertion block (lines 103–107) + `_bannerDismissed` state field (line 43).

**Existing banner insertion pattern** (lines 43, 103–107):
```dart
// State field:
bool _bannerDismissed = false;

// In build():
if (_inReviewWindow && !_bannerDismissed)
  ReviewBanner(
    onStart: () => context.push('/review'),
    onDismiss: () => setState(() => _bannerDismissed = true),
  ),
```

**New state field + card insertion** — add immediately after the `ReviewBanner` block:
```dart
// State field (alongside _bannerDismissed):
bool _eodCardDismissed = false;

// Trigger computation helper in build():
bool _shouldShowEodCard(List<ScheduledChunk> chunks) {
  final hour = DateTime.now().hour;
  if (hour >= 18) return true;
  final workChunks = chunks.where((c) => c.chunkType == ChunkType.work).toList();
  if (workChunks.isEmpty) return false;
  final resolved = workChunks.where((c) => c.isCompleted || c.isSkipped || c.isDeferred).length;
  return resolved / workChunks.length >= 0.5;
}

// In build(), after ReviewBanner block:
if (!_eodCardDismissed && _shouldShowEodCard(schedule.chunks))
  EndOfDayCard(
    chunks: schedule.chunks,
    onDismiss: () => setState(() => _eodCardDismissed = true),
    onGoToSummary: () => context.push('/summary'),
  ),
```

**`EndOfDayCard` widget** — extract as a separate file `lib/screens/home/widgets/end_of_day_card.dart`, mirroring `review_banner.dart`'s structure exactly.

---

### `lib/screens/home/widgets/end_of_day_card.dart` — new widget

**Analog:** `lib/screens/home/widgets/review_banner.dart` (full file, 79 lines) — copy structure verbatim, swap content.

**Full `ReviewBanner` structure to copy** (lines 1–78):
```dart
import 'package:flutter/material.dart';

class ReviewBanner extends StatelessWidget {
  const ReviewBanner({super.key, required this.onStart, required this.onDismiss});
  final VoidCallback onStart;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: const Key('review_banner'),
      onDismissed: (_) => onDismiss(),
      direction: DismissDirection.horizontal,
      child: Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Your quarterly review is ready',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: onDismiss,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      Text(
                        "See how far you've come. Takes about 5 minutes.",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16, left: 8),
                child: ElevatedButton(onPressed: onStart, child: const Text('Start review')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

**Substitutions for `EndOfDayCard`:**
- Class name: `EndOfDayCard`
- Constructor params: `required List<ScheduledChunk> chunks`, `required VoidCallback onDismiss`, `required VoidCallback onGoToSummary`
- Dismissible key: `const Key('end_of_day_card')`
- Title text: `'How did today go?'` (same `titleMedium?.copyWith(fontWeight: FontWeight.bold)`)
- IconButton tooltip: `'Dismiss'` (accessibility requirement from UI-SPEC)
- Subtitle text: computed `'$resolved of $total chunks done'` (`bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)`)
- ElevatedButton: `onPressed: onGoToSummary`, label `'Close the day'`

---

### `lib/screens/settings/settings_screen.dart` — add evening reminder `ListTile`

**Analog:** mid-day nudge `ListTile` block (lines 123–163) in the same file.

**Full mid-day block to mirror** (lines 123–163):
```dart
// Mid-day nudge row
ListTile(
  leading: const Icon(Icons.notifications_outlined),
  title: const Text('Mid-day nudge'),
  subtitle: Text(
    midDayEnabled
        ? _formatMinutes(midDayMinutes)
        : 'Opt-in reminder to check your schedule',
  ),
  trailing: Switch(
    value: midDayEnabled,
    onChanged: (val) async {
      await context.read<SettingsNotifier>().setMidDayNudgeEnabled(val);
      if (val) {
        await NotificationService.scheduleMidDayNudge(midDayMinutes);
      } else {
        await NotificationService.cancelMidDayNudge();
      }
    },
  ),
  onTap: midDayEnabled ? () async { /* time picker */ } : null,
),
```

**Insert immediately after this block, before the Android battery note** (line 165):
```dart
// Evening reminder row
ListTile(
  leading: const Icon(Icons.nights_stay_outlined),
  title: const Text('Evening reminder'),
  subtitle: Text(
    eveningEnabled
        ? _formatMinutes(1200)
        : 'Opt-in reminder to close your day',
  ),
  trailing: Switch(
    value: eveningEnabled,
    onChanged: (val) async {
      await context.read<SettingsNotifier>().setEveningReminderEnabled(val);
      if (val) {
        await NotificationService.scheduleEveningReminder(1200);
      } else {
        await NotificationService.cancelEveningReminder();
      }
    },
  ),
  onTap: null, // no time picker this phase — fixed 8:00pm
),
```

Local variable to add alongside `midDayEnabled` / `midDayMinutes` in the `build()` body:
```dart
final eveningEnabled = settings.eveningReminderEnabled;
```

---

## Shared Patterns

### Hive additive field pattern
**Source:** `lib/data/models/scheduled_chunk.dart` lines 50–51 (`isDeferred`) and `lib/data/models/app_settings.dart` lines 21–26 (mid-day pair)
**Apply to:** `scheduled_chunk.dart` (HiveField 9), `app_settings.dart` (HiveFields 7–8)
- Nullable or defaulted field reads as null/false/0 on old records — no data transform required.
- Bump `currentSchemaVersion` by 1 and append one migration entry (even if it's a no-op body).
- Run `dart run build_runner build --delete-conflicting-outputs` after each model edit.

### Log-append pattern with commitmentId fallback
**Source:** `lib/providers/schedule_notifier.dart` lines 155–163 (`markComplete`)
**Apply to:** all three mark* methods
```dart
goalId: chunk.commitmentId ?? chunk.goalId ?? '',
```
This single expression handles both commitment chunks (have `commitmentId`, null `goalId`) and discretionary chunks (null `commitmentId`, non-null `goalId`). Preserves the existing `goalId == ''` guard in the summary screen.

### zonedSchedule guard
**Source:** `lib/services/notification_service.dart` lines 87–91
**Apply to:** `scheduleEveningReminder`
```dart
if (kIsWeb) return;
if (Platform.isLinux || Platform.isWindows) return;
```
Both guards required before any `zonedSchedule` call. Import `dart:io` and `package:flutter/foundation.dart` (already present in the file).

### In-memory-only dismiss state
**Source:** `lib/screens/home/home_screen.dart` line 43 (`_bannerDismissed`)
**Apply to:** `_eodCardDismissed` in `_HomeScreenState`
State is `bool`, initialized `false`, flipped inside `setState()`. No persistence — card reappears on next app launch if trigger is still met.

### Settings read in build()
**Source:** `lib/screens/settings/settings_screen.dart` lines 59–62
**Apply to:** `eveningEnabled` variable
```dart
final settings = context.watch<SettingsNotifier>();
final eveningEnabled = settings.eveningReminderEnabled;
```

---

## No Analog Found

None. All files have exact or role-match analogs within the existing codebase.

---

## Metadata

**Analog search scope:** `lib/data/models/`, `lib/data/database/`, `lib/providers/`, `lib/services/`, `lib/screens/home/`, `lib/screens/settings/`
**Files read:** 11
**Pattern extraction date:** 2026-06-11
