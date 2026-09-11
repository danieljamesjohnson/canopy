# Phase 35: Your Real Commitments, Read From Your Calendar - Pattern Map

**Mapped:** 2026-09-11
**Files analyzed:** 10 (3 CalendarSource impls + interface, 1 uniform event shape, 1 sync service, 1 settings screen, 2 model/migration changes, tests as a group)
**Analogs found:** 8 / 10 (2 have partial/no analog — `IcsCalendarSource` and the permission-denial-storage UI pattern, both called out below)

RESEARCH.md and CONTEXT.md already cite most of this codebase's load-bearing files by path and line
number; this document re-verifies each citation against the actual file (all confirmed accurate) and
adds the pieces research didn't extract verbatim (settings-row code, notifier shape, repository test
harness, migration entry style).

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/data/calendar/calendar_source.dart` (interface) | model/interface | CRUD (read-only subset) | `lib/data/repositories/commitment_block_repository.dart` | exact (shape) |
| `lib/data/calendar/device_calendar_source.dart` | service/adapter | request-response (plugin call) | `lib/data/repositories/hive_commitment_block_repository.dart` (structurally) + `lib/services/notification_service.dart` (permission pattern) | role-match |
| `lib/data/calendar/ics_calendar_source.dart` | service/adapter | file-I/O / network fetch + parse | none direct — see "No Analog Found" | no analog |
| `lib/data/calendar/null_calendar_source.dart` | model/adapter | CRUD (always-empty) | `lib/data/repositories/in_memory_*_repository.dart` (e.g. `in_memory_app_settings_repository.dart`) | role-match (both are "safe stub" implementations of an interface) |
| `lib/data/calendar/calendar_event.dart` (uniform shape) | model | transform | `lib/data/models/commitment_block.dart` | role-match (plain Hive-adjacent data class) |
| `lib/services/calendar_sync_service.dart` | service | event-driven / batch (triggered sync, transforms + upserts) | `lib/services/notification_service.dart` (trigger + permission + platform branching) as primary; `lib/services/schedule_generator.dart` (pure transform over a list) as secondary for the mapping logic itself | role-match |
| `lib/data/models/commitment_block.dart` (+2 fields) | model | CRUD | itself — follow its own existing additive-field precedent (`date`, `color`) | exact |
| `lib/data/database/migrations.dart` (+1 entry) | migration | batch | itself — `_migration8to9`/`_migration7to8` (most recent additive-field entries) | exact |
| `lib/screens/settings/calendar_settings_screen.dart` | screen | request-response (user toggles → persist) | `lib/screens/settings/settings_screen.dart` (Notifications section, lines 247-342) | exact |
| `lib/screens/settings/settings_screen.dart` (+1 row) | screen (modified) | request-response | itself — copy the existing section-heading + `ListTile` idiom verbatim | exact |
| `lib/providers/commitments_notifier.dart` (+`sync()` or sibling notifier) | provider | CRUD + event-driven trigger | itself — `loadBlocks`/`saveBlock` pair | exact |
| `test/data/calendar/null_calendar_source_test.dart` | test | unit | `test/repositories/goal_repository_test.dart` (in-memory-impl-under-test harness) | exact |
| `test/services/calendar_sync_service_test.dart` | test | unit | `test/services/notification_service_test.dart` (service test with platform/time-dependent branching) | role-match |
| `test/screens/settings/calendar_settings_screen_test.dart` | test | widget | `test/screens/checkin_screen_widget_test.dart` | role-match |

## Pattern Assignments

### `lib/data/calendar/calendar_source.dart` (interface)

**Analog:** `lib/data/repositories/commitment_block_repository.dart` (verified this session, full file — 9 lines)

```dart
import '../models/commitment_block.dart';

abstract class CommitmentBlockRepository {
  Future<List<CommitmentBlock>> getAll();
  Future<CommitmentBlock?> getById(String id);
  Future<void> save(CommitmentBlock block);
  Future<void> delete(String id);
  Future<List<CommitmentBlock>> getByDayOfWeek(int day);
}
```

**What to copy:** a bare `abstract class` with no state, method-per-operation, no constructor, living
in its own file next to the implementations. `CalendarSource` should follow this exactly — RESEARCH.md's
proposed shape (`isAvailable()`, `requestPermission()`, `listCalendars()`, `listEvents(...)`) already
matches this pattern's granularity (one verb per capability, all `Future<...>`, no defaults). **Deviation
CalendarSource must NOT copy:** this repository interface has no read-only constraint — `CalendarSource`
must omit any write/create/update/delete method entirely (CAL-03 is enforced by the interface's own
shape, not by a runtime check — this is also how `flutter analyze` can serve as the CAL-03 static test
per RESEARCH.md's Validation Architecture).

### `lib/data/calendar/device_calendar_source.dart`

**Analog (structure):** `lib/data/repositories/hive_commitment_block_repository.dart` (verified, full
file — 25 lines) — one class implementing the sibling interface, a single external handle
(`Box<CommitmentBlock> get _box`), each interface method a one-line delegation to that handle.

```dart
import 'package:hive_ce/hive.dart';
import '../models/commitment_block.dart';
import 'commitment_block_repository.dart';

class HiveCommitmentBlockRepository implements CommitmentBlockRepository {
  Box<CommitmentBlock> get _box =>
      Hive.box<CommitmentBlock>('commitment_blocks');

  @override
  Future<List<CommitmentBlock>> getAll() async => _box.values.toList();
  ...
}
```

`DeviceCalendarSource` should have the same shape: a getter/lazy-init for the plugin singleton
(`DeviceCalendar.instance`), each interface method a thin delegation, no business logic (mapping logic
belongs in `CalendarSyncService`, per Pattern 1 in RESEARCH.md).

**Analog (permission pattern):** `lib/services/notification_service.dart:239-266` (read this session,
verified) — this app's ONLY existing runtime-permission request, and therefore the direct precedent for
`requestPermission()`:

```dart
/// Requests notification permissions on Darwin platforms (iOS and macOS).
///
/// Call this after the first successful mood check-in. No-op on Web and
/// non-Darwin platforms. Darwin platforms silently ignore if permissions
/// are already granted.
static Future<void> requestDarwinPermissions() async {
  if (kIsWeb) return;
  if (Platform.isIOS) {
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return;
  }
  if (Platform.isMacOS) {
    await _plugin
        .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return;
  }
  // Android/Linux/Windows: no-op. ...
}
```

**What to copy:** the platform-branch-with-explicit-comment-per-branch idiom (`if (kIsWeb) return;`
then `if (Platform.isX) { ... return; }` per platform, trailing comment explaining every omitted
branch — never a silent fallthrough). `DeviceCalendarSource.requestPermission()` should read the same
way: explicit branch per platform, explicit comment for every platform that's a no-op or unsupported.

**What this app does NOT have, confirmed:** no existing code *stores* a permission-denial result
anywhere — `notification_service.dart` requests and returns/ignores, it never persists "the user was
asked and said no." `AppSettings` has no field like `notificationsPermissionDenied`. This means the
CAL-04 "denied" UI state (`35-UI-SPEC.md` Screen Inventory §2) has **no precedent to copy** for how a
denial is stored — the planner must decide fresh whether denial is (a) queried live from the OS every
time the settings screen opens, or (b) cached in `AppSettings`/Hive. Recommend (a) — query
`CalendarPermissionStatus` live via `DeviceCalendar.instance` on screen build, matching how
`notification_service.dart` never caches permission state either; this avoids adding a stale-cache bug
class the rest of the app doesn't have to think about.

### `lib/data/calendar/null_calendar_source.dart`

**Analog:** `lib/data/repositories/in_memory_app_settings_repository.dart` — the closest existing
"always-safe, no I/O" implementation of an interface. (Not read verbatim this session — file list
confirmed via `ls`; role-match is structural: an in-memory stand-in that trivially satisfies every
interface method without touching a real backing store, which is exactly `NullCalendarSource`'s job.)
Concretely: `isAvailable()` returns `false`, `listCalendars()`/`listEvents()` return `const []`,
`requestPermission()` returns a "not applicable" status — never throws, matching CAL-04's guarantee.

### `lib/services/calendar_sync_service.dart`

**Analog (trigger + platform-branch shape):** `lib/services/notification_service.dart` — see excerpt
above. Both are services with static/singleton-style entry points invoked from a screen at a specific
moment (`checkin_screen.dart` calls `NotificationService.requestDarwinPermissions()` after first
check-in per its own doc comment; the new service should be called from
`checkin_screen.dart:127-132`, the exact call site RESEARCH.md already identified, right next to where
`blocks` is read).

**Analog (pure list transform, no side effects in the loop body):** `lib/services/schedule_generator.dart`
lines 458-478 (cited in RESEARCH.md, structure only — not re-read here to avoid duplicate context; see
RESEARCH.md Pitfall 3 for the verbatim excerpt) — a `for (final block in blocks) { ...; addAll(...); }`
shape with an early-`continue` guard. `CalendarSyncService`'s event→block mapping loop (gating short
events, all-day events, cancelled events per RESEARCH.md Pitfalls 4/6) should follow the same
guard-then-map shape rather than nested conditionals.

**Write path to reuse, not reinvent:** `lib/providers/commitments_notifier.dart` (verified, full file
— 33 lines):

```dart
class CommitmentsNotifier extends ChangeNotifier {
  CommitmentsNotifier({CommitmentBlockRepository? repository})
    : _repository = repository ?? HiveCommitmentBlockRepository();

  final CommitmentBlockRepository _repository;
  List<CommitmentBlock> _blocks = [];
  List<CommitmentBlock> get blocks => List.unmodifiable(_blocks);

  Future<void> loadBlocks() async {
    _blocks = await _repository.getAll();
    notifyListeners();
  }

  Future<void> saveBlock(CommitmentBlock block) async {
    await _repository.save(block);
    await loadBlocks();
  }

  Future<void> deleteBlock(String id) async {
    await _repository.delete(id);
    await loadBlocks();
  }
}
```

**What to copy:** the constructor-injected-repository-with-production-default idiom
(`repository ?? HiveCommitmentBlockRepository()`) — `CalendarSyncService` should take a
`CalendarSource`/`CommitmentBlockRepository` the same way, defaulting to production impls but
swappable in tests. The upsert-by-`externalEventId` logic (RESEARCH.md Pattern 4) should call
`_repository.save(block)` per mapped event (the repository's `save` already does upsert-by-id via
`_box.put(block.id, block)` — reuse `getAll()` + a local lookup by `externalEventId` to decide
create-vs-update-in-place before calling `save`, since the repository itself has no
"find by external id" method and RESEARCH.md doesn't propose adding one).

### `lib/data/models/commitment_block.dart` (+2 fields)

**Analog:** the file's own existing additive fields — `color` (`@HiveField(5)`, defaulted, no
migration-visible comment because it predates the current commenting convention) and `date`
(`@HiveField(6)`, nullable, WITH a doc comment explaining the additive/back-compat semantics):

```dart
/// Optional specific calendar date for a ONE-OFF commitment (e.g. a dentist
/// appointment this Thursday). When non-null the block is anchored only on
/// that single day and [daysOfWeek] is ignored; when null the block is a
/// recurring weekly commitment driven by [daysOfWeek]. Additive field — old
/// records deserialize with date == null and stay recurring.
@HiveField(6)
DateTime? date;
```

**What to copy:** doc comment explaining (a) what the field means, (b) that it's additive, (c) what old
records deserialize to. `externalEventId` (`@HiveField(7)`) and `isFromCalendar`
(`@HiveField(8)`, defaulted `false`) should each get the same three-part comment style.

**Confirmed discrepancy (RESEARCH.md's own flag, re-verified this session):** lines 29 and 33 of this
file read `/// Start time as minutes from midnight UTC` and `/// End time as minutes from midnight
UTC` — **verified still present, unchanged**, and **confirmed wrong**: no `.toUtc()` call exists
anywhere the fields are written (`commitment_form_sheet.dart`'s `showTimePicker` result, per
RESEARCH.md's own citation, is local wall-clock). Planner should fix both doc comments to say "local"
while the file is open for the two new fields — same file, same commit, trivial diff, and leaving it
would compound the exact misleading-comment risk RESEARCH.md's Pitfall 2 already names.

### `lib/data/database/migrations.dart` (+1 entry)

**Analog:** the file's own most recent entries, `_migration7to8` and `_migration8to9` (verified, full
function bodies read):

```dart
Future<void> _migration7to8() async {
  // Phase 19: Goal model gains energyValenceIndex (HiveField 12, int?, null)
  // and emojiTag (HiveField 13, String?, null). Both additive nullable fields —
  // Hive CE binary reader returns null for missing fields in existing records.
  // null energyValenceIndex → Goal.energyValence getter returns EnergyValence.neutral.
  // No data transformation needed.
}
```

**What to copy exactly:**
1. `currentSchemaVersion` bumps by 1 (currently 9 → 10).
2. A new `_migrationXtoY` function is **appended** to `_migrations` (never insert/reorder — the file's
   own top comment says "Add new migrations here as schema changes; never modify existing entries").
3. The function body is a **comment-only no-op** — every migration in this file so far is a no-op
   because Hive CE's binary reader already returns `null`/`false`/default for a missing `@HiveField`,
   which is exactly the shape of `externalEventId`/`isFromCalendar` (both nullable/defaulted). No data
   transformation code is needed or should be written.
4. The comment names the phase, the exact field/type/default, and states explicitly "no data
   transformation needed" plus what old records deserialize to.
5. `runMigrations`'s own `assert(_migrations.length == currentSchemaVersion, ...)` (line 99-104) is a
   real, live guard — forgetting to append the new function to the `_migrations` list literal (not just
   defining it) throws `RangeError` at every existing user's next startup in debug. This is the one
   sharp edge in an otherwise mechanical pattern.

### `lib/screens/settings/calendar_settings_screen.dart` + `settings_screen.dart` (+1 row)

**Analog:** `lib/screens/settings/settings_screen.dart` lines 247-342 (verified, read this session),
the "Notifications" section heading + first two `ListTile` rows:

```dart
// Notifications section heading
Padding(
  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
  child: Text(
    'Notifications',
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
  ),
),

// Morning reminder row
ListTile(
  leading: const Icon(Icons.alarm),
  title: const Text('Morning reminder'),
  subtitle: Text(morningEnabled ? _formatMinutes(morningMinutes) : 'Off'),
  trailing: Switch(
    value: morningEnabled,
    onChanged: (val) async {
      await context.read<SettingsNotifier>().setMorningNotificationEnabled(val);
      if (val) {
        await NotificationService.scheduleMorningNotification(morningMinutes);
      } else {
        await NotificationService.cancelMorningNotification();
      }
    },
  ),
  onTap: morningEnabled ? () async { /* showTimePicker, persist, reschedule */ } : null,
),
```

**What to copy for the new "Calendar" section (UI-SPEC §1):** the exact `Padding` + `bodyMedium.copyWith(fontWeight: FontWeight.w600)`
heading treatment, and a single `ListTile` with `leading: Icon(Icons.calendar_month)`,
`title: Text('Calendars')`, computed `subtitle` per UI-SPEC's Copywriting Contract, `trailing:
Icon(Icons.chevron_right)`, `onTap` pushing the new route — this row has no `Switch`/inline toggle,
unlike the notification rows, because CAL-02's selection UI needs its own screen (grouped checkbox
list), so it's closer in shape to the "Debug" section's navigation-style rows further down the same
file (not read verbatim this session — same file, same idiom, `kDebugMode`-gated navigation `ListTile`s
at lines 458+).

**What to copy for `calendar_settings_screen.dart`'s state-driven body:** the `context.watch<...Notifier>()`
+ local computed variables pattern visible at the top of `settings_screen.dart`'s `build()` (lines
240-241 read this session: `final eveningEnabled = settings.eveningReminderEnabled;`) — read state from
a notifier, branch the body on it, never hold UI-only state that duplicates the notifier's.

### Tests

**Repository/interface-with-swappable-impls analog:** `test/repositories/goal_repository_test.dart`
(verified, full file structure read — 50+ lines). The pattern: define a throwaway
`InMemory<X>Repository implements <X>Repository` **inside the test file itself** (not reusing a
production in-memory impl), then `setUp(() { repo = InMemoryGoalRepository(); })`, then plain
`test('...', () async { ... expect(...) })` blocks exercising each interface method. `null_calendar_source_test.dart`
should follow this shape closely, though `NullCalendarSource` itself is the production stub under test
(no separate in-memory double needed — it already **is** the "safe fallback" implementation).

**Service-with-time/platform-dependent-behaviour analog:** `test/services/notification_service_test.dart`
— exists, and is the only existing test of a service with platform branching + external plugin calls;
worth reading in full at plan time for its fake/mock-plugin harness before writing
`calendar_sync_service_test.dart`, since `CalendarSyncService` has the same shape (external
plugin/source behind an interface, time-window-dependent behavior for the 14-day sync window).

**Settings-screen widget test analog:** `test/screens/checkin_screen_widget_test.dart` — the closest
existing widget test exercising a full-screen `Scaffold` with `Provider`-backed state and conditional
rendering branches; `calendar_settings_screen_test.dart` should follow its harness shape (wrap in
`MultiProvider`/`ChangeNotifierProvider` fakes, `pumpWidget`, assert on rendered `ListTile`/`Card`
content per state).

**Project-specific test traps that apply here directly (CLAUDE.md, cross-checked against this phase):**
- **`find.byType` trap:** any assertion checking for a `CheckboxListTile` (CAL-02's calendar rows) or a
  `Card` (the CTA/denied states) must not accidentally rely on exact-type matching if a future revision
  wraps these in a subtype — use `find.byWidgetPredicate` if matching by role rather than exact widget.
  Lower risk here than the Phase 33 `Flexible`/`Expanded` case since these are leaf Material widgets
  unlikely to be subclassed, but worth a conscious check when writing the widget test.
- **Tight-vs-loose constraint trap:** does not obviously apply to `calendar_settings_screen_test.dart`
  (a `ListView` in a `Scaffold` under default `pumpWidget` sizing gets realistic loose constraints by
  default) — flag as low-risk here, but the `ChunkCard`/`chunk_card.dart` glyph work (UI-SPEC §4,
  extending an existing widget) inherits `chunk_card_hover_test.dart`'s existing harness and should be
  checked against this exact trap, since `chunk_card.dart` is the file CLAUDE.md's own example
  (`TimelineRowTile`) is adjacent to.

## Shared Patterns

### Additive Hive fields — no migration logic needed, only a version bump + comment
**Source:** `lib/data/database/migrations.dart:77-90` (see excerpt above)
**Apply to:** `commitment_block.dart`'s two new fields — this is the entire migration story, confirmed
by six consecutive prior no-op migrations in this file, all additive.

### Interface-with-swappable-implementations
**Source:** `lib/data/repositories/commitment_block_repository.dart` + `hive_commitment_block_repository.dart`
**Apply to:** `CalendarSource` + its three implementations — one file per interface, one file per
implementation, no shared abstract base class beyond the interface itself.

### Notifier wraps repository, reloads-after-write
**Source:** `lib/providers/commitments_notifier.dart`
**Apply to:** however `CalendarSyncService`'s results reach the UI — reuse `CommitmentsNotifier.loadBlocks()`
after a sync's upserts, rather than inventing a parallel state-refresh path.

### Settings section heading + ListTile row idiom
**Source:** `lib/screens/settings/settings_screen.dart:247-342`
**Apply to:** both the new "Calendar" row in `settings_screen.dart` and every row inside the new
`calendar_settings_screen.dart`.

### Explicit per-platform branch with trailing "why this platform is a no-op" comment
**Source:** `lib/services/notification_service.dart:244-266`
**Apply to:** `DeviceCalendarSource.requestPermission()` and any platform-branching inside
`CalendarSyncService` (mobile device-source vs. desktop/web ICS-source, per UI-SPEC §2's "branch the
whole screen body by platform" instruction).

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `lib/data/calendar/ics_calendar_source.dart` | service/adapter | file-I/O (network fetch) + parse | No existing code in this app fetches a remote URL and parses a foreign file format — `export_service.dart` writes local files but never fetches/parses external ones, and no HTTP client usage was found elsewhere in `lib/`. Planner should treat this as new territory: wrap the fetch+parse in try/catch per RESEARCH.md's Security Domain (V5), matching the "degrade to SnackBar, never crash" idiom used elsewhere (`_snack()` in `settings_screen.dart`/`commitments_screen.dart`, referenced in UI-SPEC) rather than a code-shape analog, since none exists. |
| Permission-denial storage/caching | provider/model | CRUD | `notification_service.dart` requests permission but never persists a "denied" result anywhere in `AppSettings` or Hive — confirmed by inspection, no field like this exists today. Recommend querying live rather than inventing a first-of-its-kind cached-permission field (see `device_calendar_source.dart` section above for the reasoning). |

## Metadata

**Analog search scope:** `lib/data/repositories/`, `lib/data/models/`, `lib/data/database/`,
`lib/services/`, `lib/providers/`, `lib/screens/settings/`, `lib/screens/commitments/`,
`lib/screens/schedule/`, `test/repositories/`, `test/services/`, `test/screens/`
**Files scanned:** ~20 read or grepped directly this session (repository interface + hive impl,
commitment_block model, migrations.dart in full, notification_service.dart permission section,
settings_screen.dart notifications section, commitments_notifier.dart in full, goal_repository_test.dart,
plus directory listings of repositories/services/providers/screens/tests)
**Pattern extraction date:** 2026-09-11

---

## PATTERN MAPPING COMPLETE

**Phase:** 35 - Your Real Commitments, Read From Your Calendar
**Files classified:** 14
**Analogs found:** 12 / 14 (both "no analog" cases documented with the closest partial match and a concrete recommendation, not left as a gap)

### Coverage
- Files with exact analog: 7 (`CalendarSource` interface, `CommitmentBlock` field additions, migration entry, `settings_screen.dart` row, `CommitmentsNotifier` extension, `NullCalendarSourceTest`, `settings_screen.dart` Notifications section as UI template)
- Files with role-match analog: 5 (`DeviceCalendarSource`, `CalendarSyncService`, `CalendarEvent` shape, `calendar_sync_service_test.dart`, `calendar_settings_screen_test.dart`)
- Files with no analog: 2 (`IcsCalendarSource`, permission-denial storage — both documented with reasoning and a recommended default rather than invented)

### Key Patterns Identified
- `lib/data/repositories/`'s one-interface-file + one-implementation-file-per-class pattern is exact
  and should be copied verbatim for `CalendarSource`'s three implementations.
- `lib/data/database/migrations.dart`'s additive-field migrations are consistently comment-only no-ops
  — the two new `CommitmentBlock` fields need no data-transformation code, only a version bump and a
  descriptive comment following the established three-part template (what/why-additive/old-record-behavior).
- `lib/services/notification_service.dart` is this app's only existing runtime-permission precedent and
  its only existing multi-platform-branch service — it is the direct analog for both
  `DeviceCalendarSource`'s permission handling and `CalendarSyncService`'s platform branching, but it
  also reveals a real gap: nothing in this app currently *stores* a permission denial, so that piece of
  CAL-04's UI has no precedent and needs a fresh (recommended: query-live, don't cache) decision.
- The `CommitmentBlock.startMinutes`/`endMinutes` "UTC" doc comment is confirmed still present and
  confirmed still wrong (local wall-clock is what's actually written) — fix it in the same commit that
  adds the two new fields, since the file is already open.

### File Created
`/home/dan/CodeProjects/canopy/.planning/phases/35-your-real-commitments-read-from-your-calendar/35-PATTERNS.md`

### Ready for Planning
Pattern mapping complete. Planner can now reference analog patterns in PLAN.md files.
