// Widget tests for CalendarSettingsScreen — the CAL-02 (device's own list,
// not asked-about) and CAL-04 (fully usable app when access is off)
// guarantees.
//
// Drives a throwaway fake CalendarSource defined inside this file (the house
// pattern from test/repositories/goal_repository_test.dart — a double in the
// test, not a production stub reused). Forces the mobile branch via
// debugDefaultTargetPlatformOverride (test/screens/goal_card_drag_handle_test.dart's
// established pattern) since flutter test's host platform is never
// iOS/Android on its own.
//
// Two CLAUDE.md-documented traps checked against every assertion below:
//   1. find.byType(X) compares runtimeType exactly and does not match
//      subclasses — used here only where we mean "exactly this widget",
//      never "any widget playing this role" (which uses
//      find.byWidgetPredicate instead, e.g. the denied card's color).
//   2. Copy is asserted as rendered text (find.text('...')) against the
//      locked UI-SPEC string, never against a constant the screen itself
//      derives the string from.

import 'dart:async';

import 'package:canopy/data/calendar/calendar_event.dart';
import 'package:canopy/data/calendar/calendar_source.dart';
import 'package:canopy/data/calendar/google_auth_client.dart' show GoogleTokens;
import 'package:canopy/data/models/commitment_block.dart';
import 'package:canopy/data/repositories/commitment_block_repository.dart';
import 'package:canopy/data/repositories/in_memory_app_settings_repository.dart';
import 'package:canopy/providers/commitments_notifier.dart';
import 'package:canopy/providers/schedule_notifier.dart';
import 'package:canopy/providers/settings_notifier.dart';
import 'package:canopy/screens/commitments/commitments_screen.dart';
import 'package:canopy/screens/settings/calendar_settings_screen.dart';
import 'package:canopy/services/calendar_sync_service.dart' show calendarIdHash;
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// WR-05 copy, approved by the owner 2026-11-03.
const _wr05Copy = "Connected, but couldn't load your calendars. Try again.";

// ---------------------------------------------------------------------------
// Fake CalendarSource — a throwaway double, not a production stub reused.
// ---------------------------------------------------------------------------
class _FakeCalendarSource implements CalendarSource {
  _FakeCalendarSource({
    this.permission = CalendarPermissionState.granted,
    this.calendars = const [],
    this.events = const [],
    Completer<CalendarPermissionState>? permissionGate,
  }) : _permissionGate = permissionGate;

  final CalendarPermissionState permission;

  /// Mutable (36-15): a test can change what the fake serves between syncs —
  /// e.g. point it at one remaining feed after another is removed, as the
  /// real source rebuilt from the remaining URLs would be.
  List<CalendarInfo> calendars;
  List<CalendarEvent> events;

  /// When non-null, requestPermission() never resolves until the test
  /// completes it — lets a test observe the in-flight spinner deliberately.
  final Completer<CalendarPermissionState>? _permissionGate;

  /// WINDOWS entry 6 (36-10, Task 2) — the load-bearing counter. A "fix"
  /// that restored the connected view by re-running the consent flow would
  /// satisfy every other assertion in that plan's tests except this one.
  int requestPermissionCount = 0;

  /// WINDOWS entries 12/13 (36-14): `listCalendars()` / `listEvents()` call
  /// counts, so a test can prove opening the screen does not sync and that
  /// "Sync now" does not re-list the calendars.
  int listCalendarsCount = 0;
  int listEventsCount = 0;

  /// WINDOWS entry 14 (36-16): when non-null, listCalendars() never resolves
  /// until the test completes it — holds a network-shaped list open.
  Completer<void>? listCalendarsGate;

  /// When non-null, listEvents() never resolves until the test completes it —
  /// lets a test observe the in-flight "Sync now" state deliberately.
  Completer<void>? listEventsGate;

  /// When non-null, listEvents() throws this (a failed sync).
  Object? listEventsError;

  /// When non-null, requestPermission() throws this — a genuine sign-in
  /// failure, the way GoogleCalendarSource.requestPermission() surfaces one
  /// (WINDOWS entry 4).
  Object? requestPermissionError;

  /// When non-null, listCalendars() throws this.
  Object? listCalendarsError;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<CalendarPermissionState> requestPermission() async {
    requestPermissionCount++;
    if (requestPermissionError != null) throw requestPermissionError!;
    if (_permissionGate != null) return _permissionGate.future;
    return permission;
  }

  @override
  Future<List<CalendarInfo>> listCalendars() async {
    listCalendarsCount++;
    if (listCalendarsGate != null) await listCalendarsGate!.future;
    if (listCalendarsError != null) throw listCalendarsError!;
    return calendars;
  }

  @override
  Future<List<CalendarEvent>> listEvents({
    required DateTime start,
    required DateTime end,
    required List<String> calendarIds,
  }) async {
    listEventsCount++;
    if (listEventsGate != null) await listEventsGate!.future;
    if (listEventsError != null) throw listEventsError!;
    return events;
  }
}

/// A fake that, like the production [DeviceCalendarSource], can read its
/// permission status without prompting (WINDOWS entry 12, 36-14).
class _RestorableFakeCalendarSource extends _FakeCalendarSource
    implements CalendarPermissionReader {
  _RestorableFakeCalendarSource({
    this.status = CalendarPermissionState.granted,
    super.calendars,
    super.events,
    super.permission,
    this.currentPermissionError,
    this.calendarOrders,
  });

  /// WINDOWS entry 14 (36-16): successive `listCalendars()` calls return
  /// successive entries (the last repeats), standing in for EventKit giving
  /// back the same calendars in a different order on each fetch.
  final List<List<CalendarInfo>>? calendarOrders;

  @override
  Future<List<CalendarInfo>> listCalendars() async {
    final orders = calendarOrders;
    if (orders == null) return super.listCalendars();
    final call = listCalendarsCount++;
    return orders[call < orders.length ? call : orders.length - 1];
  }

  CalendarPermissionState status;
  Object? currentPermissionError;
  int currentPermissionCount = 0;

  @override
  Future<CalendarPermissionState> currentPermission() async {
    currentPermissionCount++;
    if (currentPermissionError != null) throw currentPermissionError!;
    return status;
  }
}

// ---------------------------------------------------------------------------
// In-memory CommitmentBlockRepository — mirrors
// test/services/calendar_sync_service_test.dart's InMemoryCommitmentBlockRepository.
// ---------------------------------------------------------------------------
class _InMemoryCommitmentBlockRepository implements CommitmentBlockRepository {
  final Map<String, CommitmentBlock> _store = {};

  @override
  Future<List<CommitmentBlock>> getAll() async => _store.values.toList();

  @override
  Future<CommitmentBlock?> getById(String id) async => _store[id];

  @override
  Future<void> save(CommitmentBlock block) async => _store[block.id] = block;

  @override
  Future<void> delete(String id) async => _store.remove(id);

  @override
  Future<List<CommitmentBlock>> getByDayOfWeek(int day) async =>
      _store.values.where((b) => b.daysOfWeek.contains(day)).toList();
}

/// Test double — CommitmentsScreen reads ScheduleNotifier only to re-anchor
/// today's schedule after an add/edit; init() is no-op'd to avoid Hive I/O.
/// Nothing in the CAL-04 test below tags a commitment, so addEventToday is
/// never actually invoked.
class _FakeScheduleNotifier extends ScheduleNotifier {
  @override
  Future<void> init() async {}

  /// WINDOWS entry 16: what each Calendars-screen sync handed to today's
  /// schedule — the blocks, and the ids the sync removed.
  final applied = <(List<CommitmentBlock>, Set<String>)>[];

  @override
  Future<void> applyCalendarSync(
    List<CommitmentBlock> blocks, {
    Set<String> removedCalendarBlockIds = const {},
  }) async {
    applied.add((List.of(blocks), removedCalendarBlockIds));
  }
}

// ---------------------------------------------------------------------------
// Pump helper
// ---------------------------------------------------------------------------
Future<void> _pumpCalendarScreen(
  WidgetTester tester, {
  required CalendarSource source,
  CalendarSource? googleSource,
  SettingsNotifier? settingsNotifier,
  CommitmentsNotifier? commitmentsNotifier,
  ScheduleNotifier? scheduleNotifier,
  bool insideAppShell = false,
}) async {
  final settings =
      settingsNotifier ??
      SettingsNotifier(repository: InMemoryAppSettingsRepository());
  final commitments =
      commitmentsNotifier ??
      CommitmentsNotifier(repository: _InMemoryCommitmentBlockRepository());

  // Plan 36-06: the Calendars screen now renders TWO always-present
  // sections (Google + device) stacked in one scrolling body, so the
  // device CTA/list this file's existing tests tap can sit below the
  // default 600dp test viewport. Enlarge the viewport rather than adding a
  // scroll-into-view step to every tap call site — this changes nothing
  // about what any test asserts, only how much of the (now taller) page a
  // single frame can show at once.
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsNotifier>.value(value: settings),
        ChangeNotifierProvider<CommitmentsNotifier>.value(value: commitments),
        if (scheduleNotifier != null)
          ChangeNotifierProvider<ScheduleNotifier>.value(
            value: scheduleNotifier,
          ),
      ],
      child: MaterialApp(
        home: insideAppShell
            // The production frame (lib/widgets/responsive_shell.dart, below
            // 720dp): an OUTER Scaffold with the Today/Goals/Settings
            // NavigationBar, the Calendars screen inside its body. A popup
            // test pumped without this frame passed while the owner watched
            // the popup cover "Sync now" on hardware (2026-11-04): the app's
            // one ScaffoldMessenger shows SnackBars on the OUTERMOST
            // Scaffold, so the inner pinned footer was never in play.
            ? Scaffold(
                body: CalendarSettingsScreen(
                  source: source,
                  googleSource: googleSource,
                ),
                bottomNavigationBar: NavigationBar(
                  selectedIndex: 2,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.today),
                      label: 'Today',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.flag),
                      label: 'Goals',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.settings),
                      label: 'Settings',
                    ),
                  ],
                ),
              )
            : CalendarSettingsScreen(
                source: source,
                googleSource: googleSource,
              ),
      ),
    ),
  );
  await tester.pump();
}

/// Forces the mobile (device permission) branch for the duration of [body] —
/// flutter test's host platform is never iOS/Android on its own (D-35-12
/// branch decision). Mirrors test/screens/goal_card_drag_handle_test.dart's
/// _withPlatform helper: set/reset must bracket the test body itself via
/// try/finally, not setUp/tearDown — debugAssertAllFoundationVarsUnset is
/// checked before tearDown callbacks run.
Future<void> _withMobilePlatform(Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();

  tearDown(() {
    // Never leak a non-UTC tz.local override into later tests in the suite.
    tz.setLocalLocation(tz.UTC);
  });

  group('CalendarSettingsScreen — mobile permission states', () {
    testWidgets(
      'granted with several calendars across two accounts renders the '
      "fake's exact list, grouped by account (CAL-02)",
      (tester) => _withMobilePlatform(() async {
        tz.setLocalLocation(tz.UTC);
        final calendars = [
          CalendarInfo(
            id: 'cal-1',
            name: 'Work',
            accountName: 'dan@gmail.com',
            isReadOnly: true,
          ),
          CalendarInfo(
            id: 'cal-2',
            name: 'Family',
            accountName: 'dan@gmail.com',
            isReadOnly: true,
          ),
          CalendarInfo(
            id: 'cal-3',
            name: 'Personal',
            accountName: 'dan@icloud.com',
            isReadOnly: true,
          ),
        ];
        final source = _FakeCalendarSource(
          permission: CalendarPermissionState.granted,
          calendars: calendars,
        );
        await _pumpCalendarScreen(tester, source: source);

        await tester.tap(find.text('Allow calendar access'));
        await tester.pumpAndSettle();

        // The load-bearing CAL-02 assertion: exactly the fake's own data —
        // same count, same names, grouped under the same account headers.
        expect(
          find.byType(CheckboxListTile),
          findsNWidgets(3),
          reason: 'one row per calendar the fake reported',
        );
        expect(find.text('Work'), findsOneWidget);
        expect(find.text('Family'), findsOneWidget);
        expect(find.text('Personal'), findsOneWidget);
        expect(find.text('dan@gmail.com'), findsOneWidget);
        expect(find.text('dan@icloud.com'), findsOneWidget);
      }),
    );

    testWidgets(
      'granted with zero calendars renders the empty state, no checkbox',
      (tester) => _withMobilePlatform(() async {
        tz.setLocalLocation(tz.UTC);
        final source = _FakeCalendarSource(
          permission: CalendarPermissionState.granted,
          calendars: const [],
        );
        await _pumpCalendarScreen(tester, source: source);

        await tester.tap(find.text('Allow calendar access'));
        await tester.pumpAndSettle();

        expect(find.text('No calendars found on this device.'), findsOneWidget);
        expect(find.byType(CheckboxListTile), findsNothing);
      }),
    );

    testWidgets(
      'denied renders the neutral card and Open Settings — never the '
      'error role (CAL-04)',
      (tester) => _withMobilePlatform(() async {
        tz.setLocalLocation(tz.UTC);
        final source = _FakeCalendarSource(
          permission: CalendarPermissionState.denied,
        );
        await _pumpCalendarScreen(tester, source: source);

        await tester.tap(find.text('Allow calendar access'));
        await tester.pumpAndSettle();

        expect(find.text('Calendar access is off'), findsOneWidget);
        expect(find.text('Open Settings'), findsOneWidget);

        // Role assertion (any Card playing the denied-card role), per the
        // find.byType-does-not-match-subclasses trap — read the ACTUAL
        // rendered color against the theme's roles rather than merely
        // counting widgets, so a mutation to errorContainer is caught.
        final cardFinder = find.byWidgetPredicate((w) => w is Card);
        expect(cardFinder, findsOneWidget);
        final card = tester.widget<Card>(cardFinder);
        final theme = Theme.of(tester.element(cardFinder));
        expect(
          card.color,
          isNot(equals(theme.colorScheme.error)),
          reason: 'a denied permission is not an error (CAL-04)',
        );
        expect(
          card.color,
          isNot(equals(theme.colorScheme.errorContainer)),
          reason: 'a denied permission is not an error (CAL-04)',
        );
      }),
    );

    testWidgets(
      'a pending permission future shows exactly one spinner, no list',
      (tester) => _withMobilePlatform(() async {
        tz.setLocalLocation(tz.UTC);
        final gate = Completer<CalendarPermissionState>();
        final source = _FakeCalendarSource(
          permission: CalendarPermissionState.granted,
          permissionGate: gate,
        );
        await _pumpCalendarScreen(tester, source: source);

        await tester.tap(find.text('Allow calendar access'));
        await tester.pump(); // kick off the async chain — future now pending

        // Exact-class assertions — CircularProgressIndicator/CheckboxListTile
        // are Material leaf widgets with no in-app subtype to worry about,
        // unlike the denied card's color role above.
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(CheckboxListTile), findsNothing);
        // Plan 36-06 deliberately re-points this assertion: the combined
        // body is now ALWAYS a ListView (both sections are always present,
        // Task 1), so `find.byType(ListView), findsNothing` would fail
        // regardless of whether a calendar LIST is showing — it stopped
        // testing this state's actual invariant (no calendar rows) the
        // moment the screen gained a structural outer ListView unrelated
        // to this state. The CheckboxListTile check above is what actually
        // proves "no list of calendars is shown yet."

        // Resolve so the pending future doesn't dangle past the test.
        gate.complete(CalendarPermissionState.granted);
        await tester.pumpAndSettle();
      }),
    );

    testWidgets(
      'a 120-character calendar name renders on one line with no overflow',
      (tester) => _withMobilePlatform(() async {
        tz.setLocalLocation(tz.UTC);
        final longName = 'A' * 120;
        final calendars = [
          CalendarInfo(
            id: 'cal-1',
            name: longName,
            accountName: 'dan@gmail.com',
            isReadOnly: true,
          ),
        ];
        final source = _FakeCalendarSource(
          permission: CalendarPermissionState.granted,
          calendars: calendars,
        );
        await _pumpCalendarScreen(tester, source: source);

        await tester.tap(find.text('Allow calendar access'));
        await tester.pumpAndSettle();

        expect(find.text(longName), findsOneWidget);
        expect(
          tester.takeException(),
          isNull,
          reason: 'a device-reported name must never overflow',
        );
      }),
    );

    testWidgets(
      'tapping a checkbox persists the calendar id in the notifier '
      'selection',
      (tester) => _withMobilePlatform(() async {
        tz.setLocalLocation(tz.UTC);
        final calendars = [
          CalendarInfo(
            id: 'cal-1',
            name: 'Work',
            accountName: 'dan@gmail.com',
            isReadOnly: true,
          ),
        ];
        final source = _FakeCalendarSource(
          permission: CalendarPermissionState.granted,
          calendars: calendars,
        );
        final settings = SettingsNotifier(
          repository: InMemoryAppSettingsRepository(),
        );
        await _pumpCalendarScreen(
          tester,
          source: source,
          settingsNotifier: settings,
        );
        await tester.tap(find.text('Allow calendar access'));
        await tester.pumpAndSettle();

        expect(settings.selectedCalendarIds, isEmpty);

        await tester.tap(find.byType(CheckboxListTile));
        await tester.pumpAndSettle();

        expect(settings.selectedCalendarIds, contains('cal-1'));
      }),
    );

    testWidgets(
      'unticking a calendar removes the id from the notifier selection',
      (tester) => _withMobilePlatform(() async {
        tz.setLocalLocation(tz.UTC);
        final calendars = [
          CalendarInfo(
            id: 'cal-1',
            name: 'Work',
            accountName: 'dan@gmail.com',
            isReadOnly: true,
          ),
        ];
        final source = _FakeCalendarSource(
          permission: CalendarPermissionState.granted,
          calendars: calendars,
        );
        final settings = SettingsNotifier(
          repository: InMemoryAppSettingsRepository(),
        );
        await settings.setSelectedCalendarIds(['cal-1']);
        await _pumpCalendarScreen(
          tester,
          source: source,
          settingsNotifier: settings,
        );
        await tester.tap(find.text('Allow calendar access'));
        await tester.pumpAndSettle();

        expect(settings.selectedCalendarIds, contains('cal-1'));

        await tester.tap(find.byType(CheckboxListTile));
        await tester.pumpAndSettle();

        expect(settings.selectedCalendarIds, isEmpty);
      }),
    );

    testWidgets(
      'a sync result with 2 skipped events renders the disclosure and the '
      'sheet lists both, with their reasons',
      (tester) => _withMobilePlatform(() async {
        tz.setLocalLocation(tz.UTC);
        final now = DateTime.now();
        final calendars = [
          CalendarInfo(
            id: 'cal-1',
            name: 'Work',
            accountName: 'dan@gmail.com',
            isReadOnly: true,
          ),
        ];
        final events = [
          CalendarEvent(
            uid: 'evt-cancelled',
            title: 'Cancelled Meeting',
            start: now.add(const Duration(days: 1, hours: 1)),
            end: now.add(const Duration(days: 1, hours: 2)),
            isAllDay: false,
            status: CalendarEventStatus.cancelled,
            calendarId: 'cal-1',
          ),
          CalendarEvent(
            uid: 'evt-short',
            title: 'Quick Sync',
            start: now.add(const Duration(days: 1, hours: 3)),
            end: now.add(const Duration(days: 1, hours: 3, minutes: 10)),
            isAllDay: false,
            status: CalendarEventStatus.confirmed,
            calendarId: 'cal-1',
          ),
        ];
        final source = _FakeCalendarSource(
          permission: CalendarPermissionState.granted,
          calendars: calendars,
          events: events,
        );
        await _pumpCalendarScreen(tester, source: source);

        await tester.tap(find.text('Allow calendar access'));
        await tester.pumpAndSettle();

        expect(
          find.text('2 events not imported — tap for details'),
          findsOneWidget,
        );

        await tester.tap(find.text('2 events not imported — tap for details'));
        await tester.pumpAndSettle();

        expect(find.text('Cancelled Meeting'), findsOneWidget);
        expect(find.text('Cancelled'), findsOneWidget);
        expect(find.text('Quick Sync'), findsOneWidget);
        expect(find.text('Too short to schedule'), findsOneWidget);
      }),
    );
  });

  group('Plan 36-09 — the skipped-events disclosure moves to the top '
      '(WINDOWS entry 10)', () {
    testWidgets(
      'the disclosure renders ABOVE the Google section\'s "Connect '
      'Google Calendar" button on the mobile branch, proven by '
      'comparing rendered y-offsets, not widget order in source',
      (tester) => _withMobilePlatform(() async {
        tz.setLocalLocation(tz.UTC);
        final now = DateTime.now();
        final calendars = [
          CalendarInfo(
            id: 'cal-1',
            name: 'Work',
            accountName: 'dan@gmail.com',
            isReadOnly: true,
          ),
        ];
        final events = [
          CalendarEvent(
            uid: 'evt-cancelled',
            title: 'Cancelled Meeting',
            start: now.add(const Duration(days: 1, hours: 1)),
            end: now.add(const Duration(days: 1, hours: 2)),
            isAllDay: false,
            status: CalendarEventStatus.cancelled,
            calendarId: 'cal-1',
          ),
          CalendarEvent(
            uid: 'evt-short',
            title: 'Quick Sync',
            start: now.add(const Duration(days: 1, hours: 3)),
            end: now.add(const Duration(days: 1, hours: 3, minutes: 10)),
            isAllDay: false,
            status: CalendarEventStatus.confirmed,
            calendarId: 'cal-1',
          ),
        ];
        final source = _FakeCalendarSource(
          permission: CalendarPermissionState.granted,
          calendars: calendars,
          events: events,
        );
        // Google is deliberately left unconnected (no tap on "Connect
        // Google Calendar") — its CTA card, with the button this test
        // anchors on, stays on screen throughout.
        await _pumpCalendarScreen(tester, source: source);

        await tester.tap(find.text('Allow calendar access'));
        await tester.pumpAndSettle();

        expect(
          find.text('2 events not imported — tap for details'),
          findsOneWidget,
        );
        expect(find.text('Connect Google Calendar'), findsOneWidget);

        final bannerY = tester
            .getTopLeft(find.text('2 events not imported — tap for details'))
            .dy;
        // Anchor on the Connect button's own LABEL, never the bare word
        // "Google" — that word also appears in the CTA headline above
        // the button (CLAUDE.md "assertions that cannot fail": an
        // ambiguous anchor could pass for the wrong reason).
        final googleButtonY = tester
            .getTopLeft(find.text('Connect Google Calendar'))
            .dy;

        expect(
          bannerY,
          lessThan(googleButtonY),
          reason:
              'the disclosure must render above the Google section — '
              'banner dy=$bannerY, Google CTA dy=$googleButtonY',
        );
      }),
    );

    testWidgets(
      'the disclosure appears exactly once on screen — moved, not '
      'duplicated',
      (tester) => _withMobilePlatform(() async {
        tz.setLocalLocation(tz.UTC);
        final now = DateTime.now();
        final calendars = [
          CalendarInfo(
            id: 'cal-1',
            name: 'Work',
            accountName: 'dan@gmail.com',
            isReadOnly: true,
          ),
        ];
        final events = [
          CalendarEvent(
            uid: 'evt-cancelled',
            title: 'Cancelled Meeting',
            start: now.add(const Duration(days: 1, hours: 1)),
            end: now.add(const Duration(days: 1, hours: 2)),
            isAllDay: false,
            status: CalendarEventStatus.cancelled,
            calendarId: 'cal-1',
          ),
        ];
        final source = _FakeCalendarSource(
          permission: CalendarPermissionState.granted,
          calendars: calendars,
          events: events,
        );
        await _pumpCalendarScreen(tester, source: source);

        await tester.tap(find.text('Allow calendar access'));
        await tester.pumpAndSettle();

        expect(
          find.text('1 events not imported — tap for details'),
          findsOneWidget,
        );
      }),
    );
  });

  group('CAL-04 — a denied calendar permission leaves hand-entered '
      'commitments fully usable', () {
    testWidgets(
      'CommitmentsScreen renders and stays fully interactive independent '
      'of any calendar permission state',
      (tester) => _withMobilePlatform(() async {
        final blockRepo = _InMemoryCommitmentBlockRepository();
        final existing = CommitmentBlock(
          name: 'Gym',
          daysOfWeek: const [1, 3, 5],
          startMinutes: 420,
          endMinutes: 480,
        );
        await blockRepo.save(existing);
        final commitments = CommitmentsNotifier(repository: blockRepo);
        await commitments.loadBlocks();

        final scheduleNotifier = _FakeScheduleNotifier();
        await scheduleNotifier.init();
        addTearDown(scheduleNotifier.dispose);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<CommitmentsNotifier>.value(
                value: commitments,
              ),
              ChangeNotifierProvider<ScheduleNotifier>.value(
                value: scheduleNotifier,
              ),
            ],
            child: const MaterialApp(home: CommitmentsScreen()),
          ),
        );
        await tester.pump();

        // Nothing about this screen reads calendar permission at all — the
        // hand-entered row, its delete affordance, and the "Add commitment"
        // FAB are all present and enabled, proving CAL-04's guarantee holds
        // structurally rather than by inspecting a flag.
        expect(find.text('Gym'), findsOneWidget);
        expect(find.text('Add commitment'), findsOneWidget);
        // Exact-class assertion — FloatingActionButton.extended is the one
        // and only FAB this screen renders.
        final fab = tester.widget<FloatingActionButton>(
          find.byType(FloatingActionButton),
        );
        expect(fab.onPressed, isNotNull);
        final deleteButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.delete_outline),
        );
        expect(deleteButton.onPressed, isNotNull);
      }),
    );
  });

  group('Plan 36-06 — Google connect flow (D-36-03, CALAUTH-01)', () {
    testWidgets(
      'the connect button renders with its locked copy on iOS',
      (tester) => _withMobilePlatform(() async {
        final deviceSource = _FakeCalendarSource(
          permission: CalendarPermissionState.denied,
        );
        await _pumpCalendarScreen(tester, source: deviceSource);

        expect(find.text('Connect your Google Calendar'), findsOneWidget);
        expect(
          find.text(
            'Sign in once and Canopy reads your Google calendars directly '
            '— no links to find, nothing to paste. Canopy asks Google for '
            'read-only access, so it can never change anything in your '
            'calendar.',
          ),
          findsOneWidget,
        );
        expect(find.text('Connect Google Calendar'), findsOneWidget);
        // The device CTA's locked copy still renders alongside the Google
        // section in every Google state (Task 1).
        expect(find.text('Allow calendar access'), findsOneWidget);
      }),
    );

    testWidgets(
      'tapping it with a fake that returns connected shows the Google '
      'calendars grouped',
      (tester) => _withMobilePlatform(() async {
        final deviceSource = _FakeCalendarSource(
          permission: CalendarPermissionState.denied,
        );
        final googleCalendars = [
          CalendarInfo(
            id: 'google:primary',
            name: 'Work',
            accountName: 'dan@gmail.com',
            isReadOnly: true,
            sourceLabel: 'Google',
          ),
        ];
        final googleSource = _FakeCalendarSource(
          permission: CalendarPermissionState.granted,
          calendars: googleCalendars,
        );
        await _pumpCalendarScreen(
          tester,
          source: deviceSource,
          googleSource: googleSource,
        );

        await tester.tap(find.text('Connect Google Calendar'));
        await tester.pumpAndSettle();

        expect(find.text('Google'), findsOneWidget);
        expect(find.text('Work'), findsOneWidget);
        expect(find.text('dan@gmail.com'), findsOneWidget);
        expect(find.text('Disconnect'), findsOneWidget);
        expect(find.byType(CheckboxListTile), findsOneWidget);
        // The device CTA's locked copy still renders alongside.
        expect(find.text('Allow calendar access'), findsOneWidget);
      }),
    );

    testWidgets(
      'tapping it with a fake that cancels returns to the button with '
      'nothing error-shaped on screen',
      (tester) => _withMobilePlatform(() async {
        final deviceSource = _FakeCalendarSource(
          permission: CalendarPermissionState.denied,
        );
        final googleSource = _FakeCalendarSource(
          permission: CalendarPermissionState.notDetermined,
        );
        await _pumpCalendarScreen(
          tester,
          source: deviceSource,
          googleSource: googleSource,
        );

        await tester.tap(find.text('Connect Google Calendar'));
        await tester.pumpAndSettle();

        expect(find.text('Connect your Google Calendar'), findsOneWidget);
        expect(find.text('Connect Google Calendar'), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
        // No error-shaped card anywhere — the device section was never
        // touched in this test, so a Card here could only be a stray
        // error/denied render from the Google flow itself.
        expect(find.byWidgetPredicate((w) => w is Card), findsNothing);
        // The device CTA's locked copy still renders alongside.
        expect(find.text('Allow calendar access'), findsOneWidget);
      }),
    );

    testWidgets(
      'Disconnect shows its dialog and, on confirm, returns the Google '
      'section to its connect card',
      (tester) => _withMobilePlatform(() async {
        final deviceSource = _FakeCalendarSource(
          permission: CalendarPermissionState.denied,
        );
        final googleCalendars = [
          CalendarInfo(
            id: 'google:primary',
            name: 'Work',
            accountName: 'dan@gmail.com',
            isReadOnly: true,
            sourceLabel: 'Google',
          ),
        ];
        final googleSource = _FakeCalendarSource(
          permission: CalendarPermissionState.granted,
          calendars: googleCalendars,
        );
        final settings = SettingsNotifier(
          repository: InMemoryAppSettingsRepository(),
        );
        await _pumpCalendarScreen(
          tester,
          source: deviceSource,
          googleSource: googleSource,
          settingsNotifier: settings,
        );

        await tester.tap(find.text('Connect Google Calendar'));
        await tester.pumpAndSettle();
        expect(find.text('Work'), findsOneWidget);

        await tester.tap(find.text('Disconnect'));
        await tester.pumpAndSettle();

        expect(find.text('Disconnect Google Calendar?'), findsOneWidget);
        expect(
          find.text(
            'Canopy will stop reading your Google calendars. Commitments '
            'already imported stay on your schedule until you remove '
            'them.',
          ),
          findsOneWidget,
        );

        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Disconnect'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Connect Google Calendar'), findsOneWidget);
        expect(find.text('Work'), findsNothing);
      }),
    );
  });

  group('WINDOWS entry 4 — a failed Google sign-in is not a cancellation', () {
    // GoogleCalendarSource.requestPermission() already keeps the three
    // outcomes apart: granted (connected), notDetermined (cancelled — a
    // state, not an error), and a THROW (a genuine failure). These tests
    // pin that the SCREEN keeps them apart too: before this fix its
    // catch-all folded a failure into the same silent "back to the button"
    // render as a cancellation. Copy proposed, not locked (no UI-SPEC
    // string exists for a failed Google sign-in).
    const failureCopy = "Couldn't connect to Google. Please try again.";

    testWidgets(
      'a sign-in that throws returns to the connect button AND says the '
      'connection failed',
      (tester) => _withMobilePlatform(() async {
        final deviceSource = _FakeCalendarSource(
          permission: CalendarPermissionState.denied,
        );
        final googleSource = _FakeCalendarSource()
          ..requestPermissionError = Exception('Google sign-in failed');
        await _pumpCalendarScreen(
          tester,
          source: deviceSource,
          googleSource: googleSource,
        );

        await tester.tap(find.text('Connect Google Calendar'));
        await tester.pumpAndSettle();

        expect(googleSource.requestPermissionCount, 1);
        expect(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.text(failureCopy),
          ),
          findsOneWidget,
        );
        // Still the plain CTA: a failed sign-in leaves nothing connected.
        expect(find.text('Connect Google Calendar'), findsOneWidget);
        expect(find.text('Disconnect'), findsNothing);
        // Never the sync-failure line — no sync ran.
        expect(
          find.text(
            'Calendar sync failed — showing your last-known calendars.',
          ),
          findsNothing,
        );
        expect(googleSource.listEventsCount, 0);
      }),
    );

    testWidgets(
      'a cancelled sign-in shows NO failure copy — the same tap, the only '
      "difference being the fake's answer",
      (tester) => _withMobilePlatform(() async {
        final deviceSource = _FakeCalendarSource(
          permission: CalendarPermissionState.denied,
        );
        final googleSource = _FakeCalendarSource(
          permission: CalendarPermissionState.notDetermined,
        );
        await _pumpCalendarScreen(
          tester,
          source: deviceSource,
          googleSource: googleSource,
        );

        await tester.tap(find.text('Connect Google Calendar'));
        await tester.pumpAndSettle();

        expect(googleSource.requestPermissionCount, 1);
        expect(find.text(failureCopy), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
        expect(find.text('Connect Google Calendar'), findsOneWidget);
      }),
    );

    testWidgets(
      'a sign-in that SUCCEEDS but whose calendar list then fails is not '
      'reported as a failed sign-in (WR-05 territory, unchanged)',
      (tester) => _withMobilePlatform(() async {
        final deviceSource = _FakeCalendarSource(
          permission: CalendarPermissionState.denied,
        );
        final googleSource = _FakeCalendarSource()
          ..listCalendarsError = Exception('network');
        await _pumpCalendarScreen(
          tester,
          source: deviceSource,
          googleSource: googleSource,
        );

        await tester.tap(find.text('Connect Google Calendar'));
        await tester.pumpAndSettle();

        expect(googleSource.requestPermissionCount, 1);
        expect(googleSource.listCalendarsCount, 1);
        expect(find.text(failureCopy), findsNothing);
        // WR-05: connected-but-unloaded, not the Connect CTA.
        expect(find.text(_wr05Copy), findsOneWidget);
        expect(find.text('Connect Google Calendar'), findsNothing);
      }),
    );

    testWidgets(
      'WR-05: Try again lists the calendars again WITHOUT re-running '
      'consent, and shows them once the list succeeds',
      (tester) => _withMobilePlatform(() async {
        final deviceSource = _FakeCalendarSource(
          permission: CalendarPermissionState.denied,
        );
        final googleSource = _FakeCalendarSource(
          calendars: [
            CalendarInfo(
              id: 'google:primary',
              name: 'Work',
              accountName: 'dan@gmail.com',
              isReadOnly: true,
              sourceLabel: 'Google',
            ),
          ],
        )..listCalendarsError = Exception('network');
        await _pumpCalendarScreen(
          tester,
          source: deviceSource,
          googleSource: googleSource,
        );

        await tester.tap(find.text('Connect Google Calendar'));
        await tester.pumpAndSettle();
        expect(find.text(_wr05Copy), findsOneWidget);

        googleSource.listCalendarsError = null;
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();

        // Load-bearing: the retry never re-launches Google's consent sheet.
        expect(googleSource.requestPermissionCount, 1);
        expect(googleSource.listCalendarsCount, 2);
        expect(find.text(_wr05Copy), findsNothing);
        expect(find.text('Work'), findsOneWidget);
      }),
    );

    testWidgets(
      'WR-05: re-opening with a stored token whose calendar list fails shows '
      'the load-failed card, not the Connect CTA',
      (tester) => _withMobilePlatform(() async {
        final deviceSource = _FakeCalendarSource(
          permission: CalendarPermissionState.denied,
        );
        final googleSource = _FakeCalendarSource()
          ..listCalendarsError = Exception('network');
        final settings = SettingsNotifier(
          repository: InMemoryAppSettingsRepository(),
        );
        await settings.write(
          GoogleTokens(
            accessToken: 'access-1',
            refreshToken: 'refresh-1',
            expiresAt: DateTime(2026, 3, 1, 9, 30),
          ),
        );
        await _pumpCalendarScreen(
          tester,
          source: deviceSource,
          googleSource: googleSource,
          settingsNotifier: settings,
        );
        await tester.pumpAndSettle();

        expect(find.text(_wr05Copy), findsOneWidget);
        expect(find.text('Try again'), findsOneWidget);
        expect(find.text('Disconnect'), findsOneWidget);
        expect(find.text('Connect Google Calendar'), findsNothing);
        expect(googleSource.requestPermissionCount, 0);
      }),
    );
  });

  group('Plan 36-06 — Google reconnect (CALAUTH-03, Task 2)', () {
    testWidgets(
      'reconnectNeeded renders the reconnect card with its locked strings, '
      'not the calendar list — and is distinguishable from the denied '
      'card even when both are on screen',
      (tester) => _withMobilePlatform(() async {
        final deviceSource = _FakeCalendarSource(
          permission: CalendarPermissionState.denied,
        );
        final settings = SettingsNotifier(
          repository: InMemoryAppSettingsRepository(),
        );
        await settings.setReconnectNeeded(true);
        await _pumpCalendarScreen(
          tester,
          source: deviceSource,
          settingsNotifier: settings,
        );

        expect(find.text('Google sign-in expired'), findsOneWidget);
        expect(
          find.text(
            "Canopy can't read your Google calendar until you sign in "
            'again, so what it shows you may be out of date. Everything '
            'else still works — your other calendars and anything you '
            'added by hand are unaffected.',
          ),
          findsOneWidget,
        );
        expect(find.text('Reconnect Google Calendar'), findsOneWidget);
        // The denied card is absent — device permission has not been
        // requested yet, so only the reconnect card's Card exists.
        expect(find.text('Calendar access is off'), findsNothing);
        final reconnectIcon = tester.widget<Icon>(
          find.descendant(of: find.byType(Card), matching: find.byType(Icon)),
        );
        final theme = Theme.of(tester.element(find.byType(Card)));
        expect(reconnectIcon.color, equals(theme.colorScheme.error));
        // The device section renders identically regardless of
        // reconnectNeeded — a dead Google token has nothing to do with the
        // device calendars.
        expect(find.text('Allow calendar access'), findsOneWidget);

        // Now bring up the device's OWN denied card too, so both cards
        // coexist — they share Card+Icon by construction (this file's own
        // trap 1), so the discrimination must survive both being present.
        await tester.tap(find.text('Allow calendar access'));
        await tester.pumpAndSettle();
        expect(find.text('Calendar access is off'), findsOneWidget);
        final icons = tester
            .widgetList<Icon>(
              find.descendant(
                of: find.byType(Card),
                matching: find.byType(Icon),
              ),
            )
            .toList();
        expect(icons, hasLength(2));
        expect(
          icons.where((i) => i.color == theme.colorScheme.error),
          hasLength(1),
          reason: 'exactly the reconnect card is error-tinted',
        );
        expect(
          icons.where((i) => i.color != theme.colorScheme.error),
          hasLength(1),
          reason: 'exactly the denied card stays neutral (CAL-04)',
        );
      }),
    );

    testWidgets(
      'reconnectNeeded clear renders the list, not the reconnect card',
      (tester) => _withMobilePlatform(() async {
        final deviceSource = _FakeCalendarSource(
          permission: CalendarPermissionState.denied,
        );
        final googleCalendars = [
          CalendarInfo(
            id: 'google:primary',
            name: 'Work',
            accountName: 'dan@gmail.com',
            isReadOnly: true,
            sourceLabel: 'Google',
          ),
        ];
        final googleSource = _FakeCalendarSource(
          permission: CalendarPermissionState.granted,
          calendars: googleCalendars,
        );
        await _pumpCalendarScreen(
          tester,
          source: deviceSource,
          googleSource: googleSource,
        );

        await tester.tap(find.text('Connect Google Calendar'));
        await tester.pumpAndSettle();

        expect(find.text('Google sign-in expired'), findsNothing);
        expect(find.text('Work'), findsOneWidget);
        expect(find.text('Allow calendar access'), findsOneWidget);
      }),
    );
  });

  group('Plan 36-10 — Google section restores itself (WINDOWS entry 6)', () {
    testWidgets(
      'a valid stored token renders the connected section on first build, '
      'with the Connect CTA absent and requestPermission never called',
      (tester) => _withMobilePlatform(() async {
        final deviceSource = _FakeCalendarSource(
          permission: CalendarPermissionState.denied,
        );
        final googleCalendars = [
          CalendarInfo(
            id: 'google:primary',
            name: 'Work',
            accountName: 'dan@gmail.com',
            isReadOnly: true,
            sourceLabel: 'Google',
          ),
        ];
        final googleSource = _FakeCalendarSource(
          permission: CalendarPermissionState.granted,
          calendars: googleCalendars,
        );
        final settings = SettingsNotifier(
          repository: InMemoryAppSettingsRepository(),
        );
        await settings.write(
          GoogleTokens(
            accessToken: 'access-1',
            refreshToken: 'refresh-1',
            expiresAt: DateTime(2026, 3, 1, 9, 30),
          ),
        );
        await _pumpCalendarScreen(
          tester,
          source: deviceSource,
          googleSource: googleSource,
          settingsNotifier: settings,
        );
        await tester.pumpAndSettle();

        expect(find.text('Connect Google Calendar'), findsNothing);
        expect(find.text('Work'), findsOneWidget);
        expect(find.text('Disconnect'), findsOneWidget);
        // The load-bearing assertion: the restore path lists calendars and
        // nothing else. A "fix" that re-ran consent would satisfy every
        // other assertion in this test.
        expect(googleSource.requestPermissionCount, 0);
      }),
    );

    testWidgets(
      'a dead token still wins — the reconnect card renders, not the '
      'connected section, even though a token is stored',
      (tester) => _withMobilePlatform(() async {
        final deviceSource = _FakeCalendarSource(
          permission: CalendarPermissionState.denied,
        );
        final googleSource = _FakeCalendarSource(
          permission: CalendarPermissionState.granted,
          calendars: const [],
        );
        final settings = SettingsNotifier(
          repository: InMemoryAppSettingsRepository(),
        );
        await settings.write(
          GoogleTokens(
            accessToken: 'access-1',
            refreshToken: 'refresh-1',
            expiresAt: DateTime(2026, 3, 1, 9, 30),
          ),
        );
        await settings.setReconnectNeeded(true);
        await _pumpCalendarScreen(
          tester,
          source: deviceSource,
          googleSource: googleSource,
          settingsNotifier: settings,
        );
        await tester.pumpAndSettle();

        expect(find.text('Google sign-in expired'), findsOneWidget);
        expect(find.text('Reconnect Google Calendar'), findsOneWidget);
        expect(find.text('Connect Google Calendar'), findsNothing);
        expect(find.text('Disconnect'), findsNothing);
        expect(googleSource.requestPermissionCount, 0);
      }),
    );

    testWidgets(
      'no stored token renders the Connect CTA exactly as it does today',
      (tester) => _withMobilePlatform(() async {
        final deviceSource = _FakeCalendarSource(
          permission: CalendarPermissionState.denied,
        );
        final settings = SettingsNotifier(
          repository: InMemoryAppSettingsRepository(),
        );
        await _pumpCalendarScreen(
          tester,
          source: deviceSource,
          settingsNotifier: settings,
        );
        await tester.pumpAndSettle();

        expect(find.text('Connect Google Calendar'), findsOneWidget);
        expect(find.text('Connect your Google Calendar'), findsOneWidget);
      }),
    );

    testWidgets(
      'confirming Disconnect leaves the Connect CTA on screen and does not '
      're-enter the connected section on the next build',
      (tester) => _withMobilePlatform(() async {
        final deviceSource = _FakeCalendarSource(
          permission: CalendarPermissionState.denied,
        );
        final googleCalendars = [
          CalendarInfo(
            id: 'google:primary',
            name: 'Work',
            accountName: 'dan@gmail.com',
            isReadOnly: true,
            sourceLabel: 'Google',
          ),
        ];
        final googleSource = _FakeCalendarSource(
          permission: CalendarPermissionState.granted,
          calendars: googleCalendars,
        );
        final settings = SettingsNotifier(
          repository: InMemoryAppSettingsRepository(),
        );
        await settings.write(
          GoogleTokens(
            accessToken: 'access-1',
            refreshToken: 'refresh-1',
            expiresAt: DateTime(2026, 3, 1, 9, 30),
          ),
        );
        await _pumpCalendarScreen(
          tester,
          source: deviceSource,
          googleSource: googleSource,
          settingsNotifier: settings,
        );
        await tester.pumpAndSettle();
        expect(find.text('Work'), findsOneWidget);

        await tester.tap(find.text('Disconnect'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Disconnect'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Connect Google Calendar'), findsOneWidget);
        expect(find.text('Work'), findsNothing);

        // Rebuild the widget tree (a fresh "next build") over the SAME
        // settings notifier — googleConnected is now false (clear() ran),
        // so the ??= restore must not resurrect the connected view.
        await tester.pumpWidget(const SizedBox.shrink());
        await _pumpCalendarScreen(
          tester,
          source: deviceSource,
          googleSource: googleSource,
          settingsNotifier: settings,
        );
        await tester.pumpAndSettle();

        expect(find.text('Connect Google Calendar'), findsOneWidget);
        expect(find.text('Work'), findsNothing);
      }),
    );
  });

  group('Plan 36-06 — overlap disclosure (D-36-03, Task 3)', () {
    CalendarInfo deviceWork() => CalendarInfo(
      id: 'device-1',
      name: 'Work',
      accountName: 'dan@gmail.com',
      isReadOnly: true,
      sourceLabel: 'This device',
    );
    CalendarInfo googleWork() => CalendarInfo(
      id: 'google:work',
      name: 'Work',
      accountName: 'dan@gmail.com',
      isReadOnly: true,
      sourceLabel: 'Google',
    );
    const overlapNote =
        'These may be the same calendar — events could appear twice.';

    testWidgets(
      'two selected calendars the detector flags: both rows show the note',
      (tester) => _withMobilePlatform(() async {
        final deviceSource = _FakeCalendarSource(
          permission: CalendarPermissionState.granted,
          calendars: [deviceWork()],
        );
        final googleSource = _FakeCalendarSource(
          permission: CalendarPermissionState.granted,
          calendars: [googleWork()],
        );
        final settings = SettingsNotifier(
          repository: InMemoryAppSettingsRepository(),
        );
        await settings.setSelectedCalendarIds(['device-1', 'google:work']);
        await _pumpCalendarScreen(
          tester,
          source: deviceSource,
          googleSource: googleSource,
          settingsNotifier: settings,
        );

        await tester.tap(find.text('Connect Google Calendar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Allow calendar access'));
        await tester.pumpAndSettle();

        expect(find.text(overlapNote), findsNWidgets(2));
      }),
    );

    testWidgets(
      'only one of a plausible pair ticked: no note anywhere',
      (tester) => _withMobilePlatform(() async {
        final deviceSource = _FakeCalendarSource(
          permission: CalendarPermissionState.granted,
          calendars: [deviceWork()],
        );
        final googleSource = _FakeCalendarSource(
          permission: CalendarPermissionState.granted,
          calendars: [googleWork()],
        );
        final settings = SettingsNotifier(
          repository: InMemoryAppSettingsRepository(),
        );
        await settings.setSelectedCalendarIds(['device-1']);
        await _pumpCalendarScreen(
          tester,
          source: deviceSource,
          googleSource: googleSource,
          settingsNotifier: settings,
        );

        await tester.tap(find.text('Connect Google Calendar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Allow calendar access'));
        await tester.pumpAndSettle();

        expect(find.text(overlapNote), findsNothing);
      }),
    );

    testWidgets(
      'two selected calendars from the SAME source: no note',
      (tester) => _withMobilePlatform(() async {
        final deviceCalendars = [
          deviceWork(),
          CalendarInfo(
            id: 'device-2',
            name: 'Family',
            accountName: 'dan@gmail.com',
            isReadOnly: true,
            sourceLabel: 'This device',
          ),
        ];
        final deviceSource = _FakeCalendarSource(
          permission: CalendarPermissionState.granted,
          calendars: deviceCalendars,
        );
        final settings = SettingsNotifier(
          repository: InMemoryAppSettingsRepository(),
        );
        await settings.setSelectedCalendarIds(['device-1', 'device-2']);
        await _pumpCalendarScreen(
          tester,
          source: deviceSource,
          settingsNotifier: settings,
        );

        await tester.tap(find.text('Allow calendar access'));
        await tester.pumpAndSettle();

        expect(find.text(overlapNote), findsNothing);
      }),
    );

    testWidgets(
      'a flagged row checkbox still toggles and the selection still '
      'persists — the warning is advisory, not a block (D-36-03)',
      (tester) => _withMobilePlatform(() async {
        final deviceSource = _FakeCalendarSource(
          permission: CalendarPermissionState.granted,
          calendars: [deviceWork()],
        );
        final googleSource = _FakeCalendarSource(
          permission: CalendarPermissionState.granted,
          calendars: [googleWork()],
        );
        final settings = SettingsNotifier(
          repository: InMemoryAppSettingsRepository(),
        );
        await settings.setSelectedCalendarIds(['device-1', 'google:work']);
        await _pumpCalendarScreen(
          tester,
          source: deviceSource,
          googleSource: googleSource,
          settingsNotifier: settings,
        );

        await tester.tap(find.text('Connect Google Calendar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Allow calendar access'));
        await tester.pumpAndSettle();

        expect(find.text(overlapNote), findsNWidgets(2));
        expect(
          settings.selectedCalendarIds,
          containsAll(['device-1', 'google:work']),
        );

        // The Google section renders BELOW the device section (36-16, WINDOWS
        // entry 14), so its CheckboxListTile is the last of the two on
        // screen — untick it. (Both calendars are named "Work", so the label
        // cannot tell them apart.)
        await tester.tap(find.byType(CheckboxListTile).last);
        await tester.pumpAndSettle();

        expect(settings.selectedCalendarIds, isNot(contains('google:work')));
        expect(settings.selectedCalendarIds, contains('device-1'));
      }),
    );

    testWidgets(
      'nothing is de-duplicated in the selection — ticking both sides of '
      'an overlap keeps BOTH ids, proving the duplicate is disclosed, not '
      'silently prevented',
      (tester) => _withMobilePlatform(() async {
        final deviceSource = _FakeCalendarSource(
          permission: CalendarPermissionState.granted,
          calendars: [deviceWork()],
        );
        final googleSource = _FakeCalendarSource(
          permission: CalendarPermissionState.granted,
          calendars: [googleWork()],
        );
        final settings = SettingsNotifier(
          repository: InMemoryAppSettingsRepository(),
        );
        await _pumpCalendarScreen(
          tester,
          source: deviceSource,
          googleSource: googleSource,
          settingsNotifier: settings,
        );

        await tester.tap(find.text('Connect Google Calendar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Allow calendar access'));
        await tester.pumpAndSettle();

        // Tick both — the Google row first, then the device row.
        await tester.tap(find.byType(CheckboxListTile).first);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(CheckboxListTile).last);
        await tester.pumpAndSettle();

        expect(settings.selectedCalendarIds, hasLength(2));
        expect(
          settings.selectedCalendarIds,
          containsAll(['device-1', 'google:work']),
        );
        expect(find.text(overlapNote), findsNWidgets(2));
      }),
    );

    testWidgets(
      'the note is not error-tinted',
      (tester) => _withMobilePlatform(() async {
        final deviceSource = _FakeCalendarSource(
          permission: CalendarPermissionState.granted,
          calendars: [deviceWork()],
        );
        final googleSource = _FakeCalendarSource(
          permission: CalendarPermissionState.granted,
          calendars: [googleWork()],
        );
        final settings = SettingsNotifier(
          repository: InMemoryAppSettingsRepository(),
        );
        await settings.setSelectedCalendarIds(['device-1', 'google:work']);
        await _pumpCalendarScreen(
          tester,
          source: deviceSource,
          googleSource: googleSource,
          settingsNotifier: settings,
        );

        await tester.tap(find.text('Connect Google Calendar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Allow calendar access'));
        await tester.pumpAndSettle();

        final theme = Theme.of(tester.element(find.text(overlapNote).first));
        final noteText = tester.widget<Text>(find.text(overlapNote).first);
        expect(noteText.style?.color, isNot(equals(theme.colorScheme.error)));
      }),
    );
  });

  group('D-35-15 — Android takes the desktop/ICS branch, not the device '
      'permission branch (35-DECISIONS.md)', () {
    testWidgets('on Android, the screen shows the feed-URL CTA and never the '
        'device permission CTA, even though a device-capable source is '
        'passed in', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        // A source that WOULD grant device permission if asked — if the
        // screen still routed Android through the mobile branch, this
        // fake would drive it there. It must not be reached at all: on
        // Android the desktop branch renders before source.
        // requestPermission() is ever called.
        final source = _FakeCalendarSource(
          permission: CalendarPermissionState.granted,
          calendars: [
            CalendarInfo(id: 'cal-1', name: 'Work', isReadOnly: true),
          ],
        );
        await _pumpCalendarScreen(tester, source: source);

        expect(find.text('Subscribe to a calendar'), findsOneWidget);
        expect(find.text('Add calendar URL'), findsOneWidget);
        expect(find.text('Allow calendar access'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('Plan 36-14 — device section restores itself (WINDOWS entry 12)', () {
    final threeCalendars = [
      CalendarInfo(
        id: 'home',
        name: 'Home',
        accountName: 'iCloud',
        isReadOnly: true,
      ),
      CalendarInfo(
        id: 'family',
        name: 'Family',
        accountName: 'iCloud',
        isReadOnly: true,
      ),
      CalendarInfo(
        id: 'spunkl',
        name: 'spunkl',
        accountName: 'dan@gmail.com',
        isReadOnly: true,
      ),
    ];

    Finder tickedRow(String name) => find.byWidgetPredicate(
      (w) =>
          w is CheckboxListTile &&
          w.value == true &&
          w.title is Text &&
          (w.title as Text).data == name,
    );

    Future<SettingsNotifier> settingsWithSpunklTicked() async {
      final settings = SettingsNotifier(
        repository: InMemoryAppSettingsRepository(),
      );
      await settings.setSelectedCalendarIds(['spunkl']);
      return settings;
    }

    testWidgets(
      'granted status renders the three rows on first build with spunkl '
      'ticked, no CTA, ZERO permission requests, and no sync',
      (tester) => _withMobilePlatform(() async {
        final source = _RestorableFakeCalendarSource(calendars: threeCalendars);
        await _pumpCalendarScreen(
          tester,
          source: source,
          settingsNotifier: await settingsWithSpunklTicked(),
        );
        await tester.pumpAndSettle();

        expect(find.text('Home'), findsOneWidget);
        expect(find.text('Family'), findsOneWidget);
        expect(find.text('spunkl'), findsOneWidget);
        expect(tickedRow('spunkl'), findsOneWidget);
        expect(tickedRow('Home'), findsNothing);
        expect(find.text('Allow calendar access'), findsNothing);
        // The load-bearing assertion: a "fix" that silently re-requested
        // permission (iOS answers an already-granted request instantly, with
        // no visible prompt) would satisfy every other check here.
        expect(source.requestPermissionCount, 0);
        expect(source.currentPermissionCount, 1);
        // Opening the screen must not rewrite the schedule.
        expect(source.listEventsCount, 0);
      }),
    );

    testWidgets(
      're-opening the screen (a brand new State, same source and notifiers) '
      'renders the rows again and still never requests permission',
      (tester) => _withMobilePlatform(() async {
        final source = _RestorableFakeCalendarSource(calendars: threeCalendars);
        final settings = await settingsWithSpunklTicked();
        final commitments = CommitmentsNotifier(
          repository: _InMemoryCommitmentBlockRepository(),
        );
        await _pumpCalendarScreen(
          tester,
          source: source,
          settingsNotifier: settings,
          commitmentsNotifier: commitments,
        );
        await tester.pumpAndSettle();
        expect(find.text('spunkl'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await _pumpCalendarScreen(
          tester,
          source: source,
          settingsNotifier: settings,
          commitmentsNotifier: commitments,
        );
        await tester.pumpAndSettle();

        expect(find.text('Home'), findsOneWidget);
        expect(find.text('spunkl'), findsOneWidget);
        expect(tickedRow('spunkl'), findsOneWidget);
        expect(find.text('Allow calendar access'), findsNothing);
        expect(source.requestPermissionCount, 0);
        expect(source.currentPermissionCount, 2);
      }),
    );

    testWidgets(
      'restored but never synced: the footer reads "Not synced yet" and a '
      '"Sync now" button is offered',
      (tester) => _withMobilePlatform(() async {
        final source = _RestorableFakeCalendarSource(calendars: threeCalendars);
        await _pumpCalendarScreen(tester, source: source);
        await tester.pumpAndSettle();

        expect(find.text('Not synced yet'), findsOneWidget);
        expect(find.text('Sync now'), findsOneWidget);
      }),
    );

    testWidgets(
      'status notDetermined shows the CTA and requests nothing until it is '
      'tapped; tapping requests exactly once and then lists',
      (tester) => _withMobilePlatform(() async {
        final source = _RestorableFakeCalendarSource(
          status: CalendarPermissionState.notDetermined,
          permission: CalendarPermissionState.granted,
          calendars: threeCalendars,
        );
        await _pumpCalendarScreen(tester, source: source);
        await tester.pumpAndSettle();

        expect(find.text('Allow calendar access'), findsOneWidget);
        expect(find.text('Home'), findsNothing);
        expect(source.requestPermissionCount, 0);

        await tester.tap(find.text('Allow calendar access'));
        await tester.pumpAndSettle();

        expect(source.requestPermissionCount, 1);
        expect(find.text('Home'), findsOneWidget);
      }),
    );

    testWidgets(
      'status denied renders "Calendar access is off" directly, with no '
      'permission request',
      (tester) => _withMobilePlatform(() async {
        final source = _RestorableFakeCalendarSource(
          status: CalendarPermissionState.denied,
          calendars: threeCalendars,
        );
        await _pumpCalendarScreen(tester, source: source);
        await tester.pumpAndSettle();

        expect(find.text('Calendar access is off'), findsOneWidget);
        expect(find.text('Allow calendar access'), findsNothing);
        expect(source.requestPermissionCount, 0);
      }),
    );

    testWidgets(
      'currentPermission() throwing folds to the CTA — nothing crashes',
      (tester) => _withMobilePlatform(() async {
        final source = _RestorableFakeCalendarSource(
          calendars: threeCalendars,
          currentPermissionError: StateError('missing usage description'),
        );
        await _pumpCalendarScreen(tester, source: source);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Allow calendar access'), findsOneWidget);
        expect(source.requestPermissionCount, 0);
      }),
    );
  });

  group('Plan 36-14 — "Sync now" syncs in place and answers back '
      '(WINDOWS entry 13)', () {
    final calendars = [
      CalendarInfo(
        id: 'spunkl',
        name: 'spunkl',
        accountName: 'dan@gmail.com',
        isReadOnly: true,
      ),
    ];

    List<CalendarEvent> oneTimedEvent() {
      final now = DateTime.now();
      return [
        CalendarEvent(
          uid: 'evt-1',
          title: 'Dentist',
          start: now.add(const Duration(days: 1, hours: 1)),
          end: now.add(const Duration(days: 1, hours: 2)),
          isAllDay: false,
          status: CalendarEventStatus.confirmed,
          calendarId: 'spunkl',
        ),
      ];
    }

    // `TextButton.icon` builds a private SUBCLASS of TextButton, so an exact
    // type lookup would miss the in-flight button (CLAUDE.md trap #1) —
    // locate it as the ButtonStyleButton ancestor of its label.
    Finder syncNowButton() => find.ancestor(
      of: find.text('Sync now'),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );

    VoidCallback? syncNowOnPressed(WidgetTester tester) =>
        tester.widget<ButtonStyleButton>(syncNowButton()).onPressed;

    Finder inSnackBar(String text) =>
        find.descendant(of: find.byType(SnackBar), matching: find.text(text));

    testWidgets(
      'while the sync runs the button is disabled and carries a spinner, the '
      'rows stay on screen, and nothing re-requests or re-lists',
      (tester) => _withMobilePlatform(() async {
        final source = _RestorableFakeCalendarSource(
          calendars: calendars,
          events: oneTimedEvent(),
        )..listEventsGate = Completer<void>();
        await _pumpCalendarScreen(tester, source: source);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Sync now'));
        await tester.pump();

        expect(syncNowOnPressed(tester), isNull);
        expect(
          find.descendant(
            of: syncNowButton(),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );

        source.listEventsGate!.complete();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 7));
      }),
    );

    testWidgets(
      'while the sync runs the calendar rows stay on screen and nothing '
      're-requests permission or re-lists calendars',
      (tester) => _withMobilePlatform(() async {
        final source = _RestorableFakeCalendarSource(
          calendars: calendars,
          events: oneTimedEvent(),
        )..listEventsGate = Completer<void>();
        await _pumpCalendarScreen(tester, source: source);
        await tester.pumpAndSettle();
        final listedBefore = source.listCalendarsCount;
        expect(find.text('spunkl'), findsOneWidget);

        await tester.tap(find.text('Sync now'));
        await tester.pump();

        expect(find.text('spunkl'), findsOneWidget);
        expect(source.requestPermissionCount, 0);
        expect(source.listCalendarsCount, listedBefore);

        source.listEventsGate!.complete();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 7));
      }),
    );

    testWidgets(
      'tapping "Sync now" again while a sync is in flight does not start a '
      'second one',
      (tester) => _withMobilePlatform(() async {
        final source = _RestorableFakeCalendarSource(
          calendars: calendars,
          events: oneTimedEvent(),
        )..listEventsGate = Completer<void>();
        await _pumpCalendarScreen(tester, source: source);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Sync now'));
        await tester.pump();
        await tester.tap(find.text('Sync now'), warnIfMissed: false);
        await tester.pump();

        expect(source.listEventsCount, 1);

        source.listEventsGate!.complete();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 7));
      }),
    );

    testWidgets(
      'a finished sync shows the "Synced just now" popup sliding up from the '
      'bottom WITHOUT covering Sync now, which is pinned below it; the '
      'spinner is gone and the button is enabled again (WINDOWS entry 17)',
      (tester) => _withMobilePlatform(() async {
        final source = _RestorableFakeCalendarSource(
          calendars: calendars,
          events: oneTimedEvent(),
        )..listEventsGate = Completer<void>();
        await _pumpCalendarScreen(tester, source: source, insideAppShell: true);
        // A phone-sized screen, where the 2026-11-03 overlap was seen.
        tester.view.physicalSize = const Size(390, 844);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Sync now'));
        await tester.pump();
        source.listEventsGate!.complete();
        await tester.pumpAndSettle();

        expect(
          inSnackBar('Synced just now — 1 commitment imported'),
          findsOneWidget,
        );
        final snack = tester.getRect(find.byType(SnackBar));
        final button = tester.getRect(syncNowButton());
        // Load-bearing: the popup sits entirely ABOVE the button.
        expect(snack.bottom, lessThanOrEqualTo(button.top));
        // And the button is pinned to the bottom of the screen, not wherever
        // the list happens to end.
        expect(button.bottom, greaterThan(844 - 80 - 80));
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(syncNowOnPressed(tester), isNotNull);

        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
      }),
    );

    testWidgets(
      'the footer line disappears when Sync now is pressed and comes back, '
      'highlighted, only once the popup has gone (owner 2026-11-04: it '
      '"says the exact same thing as the popup")',
      (tester) => _withMobilePlatform(() async {
        final source = _RestorableFakeCalendarSource(
          calendars: calendars,
          events: oneTimedEvent(),
        )..listEventsGate = Completer<void>();
        await _pumpCalendarScreen(tester, source: source, insideAppShell: true);
        await tester.pumpAndSettle();
        Finder footerLine() => find.byKey(const ValueKey('sync-status-line'));
        expect(footerLine(), findsOneWidget);

        await tester.tap(find.text('Sync now'));
        await tester.pump();
        // The spinner never settles, so step the fade-out by hand.
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pump();
        // Gone while the sync runs...
        expect(footerLine(), findsNothing);

        source.listEventsGate!.complete();
        await tester.pumpAndSettle();
        // ...and while the popup says it.
        expect(
          inSnackBar('Synced just now — 1 commitment imported'),
          findsOneWidget,
        );
        expect(footerLine(), findsNothing);

        await tester.pump(const Duration(seconds: 3)); // popup's duration
        await tester.pump(const Duration(milliseconds: 400)); // its exit
        await tester.pump(); // `closed` fires -> line rebuilt
        await tester.pump(const Duration(milliseconds: 300));
        // Popup gone: the line is back, mid-entrance, still highlighted.
        expect(find.byType(SnackBar), findsNothing);
        expect(footerLine(), findsOneWidget);
        final highlight =
            (tester.widget<Container>(footerLine()).decoration!
                    as BoxDecoration)
                .color!;
        expect(highlight.a, greaterThan(0.3));
        expect(
          find.descendant(
            of: footerLine(),
            matching: find.text('Synced just now — 1 commitment imported'),
          ),
          findsOneWidget,
        );

        // The highlight fades back to plain text.
        await tester.pumpAndSettle();
        final settled =
            (tester.widget<Container>(footerLine()).decoration!
                    as BoxDecoration)
                .color!;
        expect(settled.a, lessThan(0.05));
      }),
    );

    testWidgets(
      'an older sync shows a clock time, not "just now" (WINDOWS entry 17)',
      (tester) => _withMobilePlatform(() async {
        final settings = SettingsNotifier(
          repository: InMemoryAppSettingsRepository(),
        );
        await settings.recordCalendarSyncSuccess(
          syncedAt: DateTime.now().subtract(const Duration(minutes: 5)),
          skipped: const [],
        );
        await _pumpCalendarScreen(
          tester,
          source: _RestorableFakeCalendarSource(calendars: calendars),
          settingsNotifier: settings,
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            RegExp(
              r'^Synced at \d{1,2}:\d{2}\s?[AP]M — 0 commitments imported$',
            ),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('just now'), findsNothing);
      }),
    );

    testWidgets(
      'Sync now hands the synced blocks to TODAY\'s schedule, so a new event '
      'reaches the timeline without a Re-check-in (WINDOWS entry 16)',
      (tester) => _withMobilePlatform(() async {
        final source = _RestorableFakeCalendarSource(
          calendars: calendars,
          events: oneTimedEvent(),
        );
        final schedule = _FakeScheduleNotifier();
        await _pumpCalendarScreen(
          tester,
          source: source,
          scheduleNotifier: schedule,
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Sync now'));
        await tester.pumpAndSettle();

        expect(schedule.applied, hasLength(1));
        expect(
          schedule.applied.single.$1.where((b) => b.isFromCalendar),
          hasLength(1),
        );
        await tester.pump(const Duration(seconds: 2));
      }),
    );

    testWidgets(
      'a sync whose listEvents throws shows the locked failure SnackBar, no '
      'success SnackBar, and the footer still reads "Not synced yet"',
      (tester) => _withMobilePlatform(() async {
        final source = _RestorableFakeCalendarSource(
          calendars: calendars,
          events: oneTimedEvent(),
        )..listEventsError = StateError('network down');
        await _pumpCalendarScreen(tester, source: source);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Sync now'));
        await tester.pumpAndSettle();

        expect(
          inSnackBar(
            'Calendar sync failed — showing your last-known calendars.',
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.textContaining('Synced'),
          ),
          findsNothing,
        );
        // The failed attempt is not shown as a fresh sync.
        expect(find.text('Not synced yet'), findsOneWidget);
        expect(syncNowOnPressed(tester), isNotNull);

        await tester.pump(const Duration(seconds: 7));
      }),
    );
  });

  group('Plan 36-15 — the skipped-events banner is persisted state, and '
      'removing a feed really removes its commitments '
      '(WINDOWS entries 10 and 11)', () {
    final calendars = [
      CalendarInfo(
        id: 'spunkl',
        name: 'spunkl',
        accountName: 'dan@gmail.com',
        isReadOnly: true,
      ),
    ];

    // `tz.local` is a `late` field nothing initialises in a widget test; the
    // sync maps events through it.
    setUp(() => tz.setLocalLocation(tz.UTC));

    DateTime inThreeDays(int hour) {
      final n = DateTime.now();
      return DateTime(n.year, n.month, n.day + 3, hour);
    }

    // One timed event (imports) and one all-day event (skipped, disclosed).
    List<CalendarEvent> timedAndAllDay() => [
      CalendarEvent(
        uid: 'evt-dentist',
        title: 'Dentist',
        start: inThreeDays(10),
        end: inThreeDays(11),
        isAllDay: false,
        status: CalendarEventStatus.confirmed,
        calendarId: 'spunkl',
      ),
      CalendarEvent(
        uid: 'evt-vacation',
        title: 'Vacation',
        start: inThreeDays(0),
        end: inThreeDays(0).add(const Duration(days: 1)),
        isAllDay: true,
        status: CalendarEventStatus.confirmed,
        calendarId: 'spunkl',
      ),
    ];

    Finder syncNowText() => find.text('Sync now');
    Finder banner(int n) =>
        find.text('$n events not imported — tap for details');
    Finder inSnackBar(String text) =>
        find.descendant(of: find.byType(SnackBar), matching: find.text(text));
    const failureCopy =
        'Calendar sync failed — showing your last-known calendars.';

    Future<void> openAndSync(
      WidgetTester tester, {
      required _FakeCalendarSource source,
      required SettingsNotifier settings,
      required CommitmentsNotifier commitments,
    }) async {
      await _pumpCalendarScreen(
        tester,
        source: source,
        settingsNotifier: settings,
        commitmentsNotifier: commitments,
      );
      await tester.pumpAndSettle();
      await tester.tap(syncNowText());
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 7));
    }

    testWidgets(
      'leave and re-enter Settings -> Calendars: the banner is still there '
      'and still lists the all-day event (the unmount between the two '
      'assertions is what makes this the owner\'s R3 case)',
      (tester) => _withMobilePlatform(() async {
        final source = _RestorableFakeCalendarSource(
          calendars: calendars,
          events: timedAndAllDay(),
        );
        final settings = SettingsNotifier(
          repository: InMemoryAppSettingsRepository(),
        );
        final commitments = CommitmentsNotifier(
          repository: _InMemoryCommitmentBlockRepository(),
        );
        await openAndSync(
          tester,
          source: source,
          settings: settings,
          commitments: commitments,
        );
        expect(banner(1), findsOneWidget);

        // Leave the screen entirely, then come back with the same notifiers.
        await tester.pumpWidget(const SizedBox());
        expect(banner(1), findsNothing);
        await _pumpCalendarScreen(
          tester,
          source: source,
          settingsNotifier: settings,
          commitmentsNotifier: commitments,
        );
        await tester.pumpAndSettle();

        expect(banner(1), findsOneWidget);
        await tester.tap(banner(1));
        await tester.pumpAndSettle();
        expect(find.text('Vacation'), findsOneWidget);
        expect(
          find.text('All-day — not imported automatically'),
          findsOneWidget,
        );
      }),
    );

    testWidgets(
      'relaunch: a NEW SettingsNotifier over the same repository, after '
      'init(), shows the banner before any sync has run',
      (tester) => _withMobilePlatform(() async {
        final source = _RestorableFakeCalendarSource(
          calendars: calendars,
          events: timedAndAllDay(),
        );
        final settingsRepo = InMemoryAppSettingsRepository();
        final settings = SettingsNotifier(repository: settingsRepo);
        final commitments = CommitmentsNotifier(
          repository: _InMemoryCommitmentBlockRepository(),
        );
        await openAndSync(
          tester,
          source: source,
          settings: settings,
          commitments: commitments,
        );
        expect(banner(1), findsOneWidget);
        final listedAfterFirstSync = source.listEventsCount;

        await tester.pumpWidget(const SizedBox());
        final relaunched = SettingsNotifier(repository: settingsRepo);
        await relaunched.init();
        await _pumpCalendarScreen(
          tester,
          source: source,
          settingsNotifier: relaunched,
          commitmentsNotifier: CommitmentsNotifier(
            repository: _InMemoryCommitmentBlockRepository(),
          ),
        );
        await tester.pumpAndSettle();

        expect(banner(1), findsOneWidget);
        // Nothing was synced to get it there.
        expect(source.listEventsCount, listedAfterFirstSync);
      }),
    );

    testWidgets(
      'a later sync whose source throws leaves the banner showing the last '
      'successful sync\'s count',
      (tester) => _withMobilePlatform(() async {
        final source = _RestorableFakeCalendarSource(
          calendars: calendars,
          events: timedAndAllDay(),
        );
        final settings = SettingsNotifier(
          repository: InMemoryAppSettingsRepository(),
        );
        final commitments = CommitmentsNotifier(
          repository: _InMemoryCommitmentBlockRepository(),
        );
        await openAndSync(
          tester,
          source: source,
          settings: settings,
          commitments: commitments,
        );
        expect(banner(1), findsOneWidget);

        source.listEventsError = StateError('network down');
        await tester.tap(syncNowText());
        await tester.pumpAndSettle();

        expect(inSnackBar(failureCopy), findsOneWidget);
        expect(banner(1), findsOneWidget);
        await tester.pump(const Duration(seconds: 7));
      }),
    );

    testWidgets(
      'a later successful sync with nothing skipped removes the banner',
      (tester) => _withMobilePlatform(() async {
        final source = _RestorableFakeCalendarSource(
          calendars: calendars,
          events: timedAndAllDay(),
        );
        final settings = SettingsNotifier(
          repository: InMemoryAppSettingsRepository(),
        );
        final commitments = CommitmentsNotifier(
          repository: _InMemoryCommitmentBlockRepository(),
        );
        await openAndSync(
          tester,
          source: source,
          settings: settings,
          commitments: commitments,
        );
        expect(banner(1), findsOneWidget);

        source.events = [source.events.first];
        await tester.tap(syncNowText());
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 7));

        expect(find.textContaining('events not imported'), findsNothing);
      }),
    );

    testWidgets(
      'desktop branch, the very first load fails (nothing ever synced): the '
      'locked failure SnackBar appears AND the footer still reads "Not '
      'synced yet" with a "Sync now" button',
      (tester) async {
        const feed = 'https://example.com/work.ics';
        final source = _FakeCalendarSource(
          calendars: [
            CalendarInfo(id: feed, name: 'Work feed', isReadOnly: true),
          ],
        )..listEventsError = StateError('network down');
        final settings = SettingsNotifier(
          repository: InMemoryAppSettingsRepository(),
        );
        await settings.addIcsUrl(feed);

        await _pumpCalendarScreen(
          tester,
          source: source,
          settingsNotifier: settings,
        );
        await tester.pumpAndSettle();

        expect(inSnackBar(failureCopy), findsOneWidget);
        expect(find.text('Not synced yet'), findsOneWidget);
        expect(syncNowText(), findsOneWidget);
        await tester.pump(const Duration(seconds: 7));
      },
    );

    testWidgets(
      'mobile branch, granted on tap, the first sync throws: after "Allow '
      'calendar access" the footer still reads "Not synced yet" with '
      '"Sync now"',
      (tester) => _withMobilePlatform(() async {
        final source = _FakeCalendarSource(
          permission: CalendarPermissionState.granted,
          calendars: calendars,
        )..listEventsError = StateError('network down');
        await _pumpCalendarScreen(tester, source: source);

        await tester.tap(find.text('Allow calendar access'));
        await tester.pumpAndSettle();

        expect(inSnackBar(failureCopy), findsOneWidget);
        expect(find.text('Not synced yet'), findsOneWidget);
        expect(syncNowText(), findsOneWidget);
        await tester.pump(const Duration(seconds: 7));
      }),
    );

    testWidgets(
      'desktop branch, two feeds: removing feed a through the "Remove this '
      'calendar?" dialog deletes a\'s commitments at the next sync and '
      'keeps b\'s — the locked dialog\'s promise, kept',
      (tester) async {
        const feedA = 'https://example.com/a.ics';
        const feedB = 'https://example.com/b.ics';
        CalendarEvent eventOn(String feed, String uid, int hour) =>
            CalendarEvent(
              uid: uid,
              title: 'Event $uid',
              start: inThreeDays(hour),
              end: inThreeDays(hour + 1),
              isAllDay: false,
              status: CalendarEventStatus.confirmed,
              calendarId: feed,
            );
        final infoA = CalendarInfo(id: feedA, name: 'Feed A', isReadOnly: true);
        final infoB = CalendarInfo(id: feedB, name: 'Feed B', isReadOnly: true);
        final source = _FakeCalendarSource(
          calendars: [infoA, infoB],
          events: [eventOn(feedA, 'evt-a', 9), eventOn(feedB, 'evt-b', 13)],
        );
        final settings = SettingsNotifier(
          repository: InMemoryAppSettingsRepository(),
        );
        await settings.addIcsUrl(feedA);
        await settings.addIcsUrl(feedB);
        final commitments = CommitmentsNotifier(
          repository: _InMemoryCommitmentBlockRepository(),
        );

        await _pumpCalendarScreen(
          tester,
          source: source,
          settingsNotifier: settings,
          commitmentsNotifier: commitments,
        );
        await tester.pumpAndSettle();

        String idOf(String feed, String uid) => commitments.blocks
            .singleWhere(
              (b) =>
                  b.externalEventId?.startsWith(
                    'ics:${calendarIdHash(feed)}:$uid:',
                  ) ??
                  false,
            )
            .id;
        final aId = idOf(feedA, 'evt-a');
        final bId = idOf(feedB, 'evt-b');
        expect(commitments.blocks.map((b) => b.id), containsAll([aId, bId]));

        // As the real source rebuilt from the one remaining URL would be.
        source.calendars = [infoB];
        source.events = [eventOn(feedB, 'evt-b', 13)];

        await tester.tap(find.byTooltip('Remove calendar').first);
        await tester.pumpAndSettle();
        expect(find.text('Remove this calendar?'), findsOneWidget);
        expect(
          find.textContaining('will disappear the next time you sync'),
          findsOneWidget,
        );
        await tester.tap(find.text('Remove'));
        await tester.pumpAndSettle();

        final survivors = commitments.blocks.map((b) => b.id).toSet();
        expect(survivors, isNot(contains(aId)));
        expect(survivors, contains(bId));
        await tester.pump(const Duration(seconds: 7));
      },
    );
  });

  group('Plan 36-16 — a tick lands on the row the user aimed at '
      '(WINDOWS entry 14)', () {
    CalendarInfo cal(String id, String name, [String? account = 'iCloud']) =>
        CalendarInfo(
          id: id,
          name: name,
          accountName: account,
          isReadOnly: true,
        );

    double rowY(WidgetTester tester, String name) =>
        tester.getTopLeft(find.text(name)).dy;

    testWidgets(
      'the device rows come out Family, Home, spunkl on the first open AND '
      'on a re-open where the source returned a different order',
      (tester) => _withMobilePlatform(() async {
        final family = cal('3935F311-family', 'Family');
        final home = cal('home-id', 'Home');
        final spunkl = cal('spunkl-id', 'spunkl');
        final source = _RestorableFakeCalendarSource(
          calendarOrders: [
            [spunkl, home, family],
            [family, spunkl, home],
          ],
        );
        final settings = SettingsNotifier(
          repository: InMemoryAppSettingsRepository(),
        );
        final commitments = CommitmentsNotifier(
          repository: _InMemoryCommitmentBlockRepository(),
        );

        Future<void> open() async {
          await _pumpCalendarScreen(
            tester,
            source: source,
            settingsNotifier: settings,
            commitmentsNotifier: commitments,
          );
          await tester.pumpAndSettle();
        }

        await open();
        expect(source.listCalendarsCount, 1);
        final f1 = rowY(tester, 'Family');
        final h1 = rowY(tester, 'Home');
        final s1 = rowY(tester, 'spunkl');
        expect(f1, lessThan(h1), reason: 'first open: Family above Home');
        expect(h1, lessThan(s1), reason: 'first open: Home above spunkl');

        await tester.pumpWidget(const SizedBox());
        await open();
        expect(source.listCalendarsCount, 2);
        expect(rowY(tester, 'Family'), f1);
        expect(rowY(tester, 'Home'), h1);
        expect(rowY(tester, 'spunkl'), s1);
      }),
    );

    testWidgets(
      'on the re-open where the source reordered, tapping the row labelled '
      "spunkl stores spunkl's id and neither Family's nor Home's",
      (tester) => _withMobilePlatform(() async {
        final family = cal('3935F311-family', 'Family');
        final home = cal('home-id', 'Home');
        final spunkl = cal('spunkl-id', 'spunkl');
        final source = _RestorableFakeCalendarSource(
          calendarOrders: [
            [spunkl, home, family],
            [family, spunkl, home],
          ],
        );
        final settings = SettingsNotifier(
          repository: InMemoryAppSettingsRepository(),
        );
        final commitments = CommitmentsNotifier(
          repository: _InMemoryCommitmentBlockRepository(),
        );
        Future<void> open() async {
          await _pumpCalendarScreen(
            tester,
            source: source,
            settingsNotifier: settings,
            commitmentsNotifier: commitments,
          );
          await tester.pumpAndSettle();
        }

        await open();
        await tester.pumpWidget(const SizedBox());
        await open();
        expect(source.listCalendarsCount, 2);

        await tester.tap(find.text('spunkl'));
        await tester.pumpAndSettle();

        expect(settings.selectedCalendarIds, ['spunkl-id']);
        expect(
          settings.selectedCalendarIds,
          isNot(contains('3935F311-family')),
        );
        expect(settings.selectedCalendarIds, isNot(contains('home-id')));
      }),
    );

    group('section order: the device rows never move when Google loads', () {
      final deviceCalendars = [
        cal('home-id', 'Home'),
        cal('family-id', 'Family'),
        cal('spunkl-id', 'spunkl'),
      ];

      Future<SettingsNotifier> connectedSettings() async {
        final settings = SettingsNotifier(
          repository: InMemoryAppSettingsRepository(),
        );
        await settings.write(
          GoogleTokens(
            accessToken: 'access-1',
            refreshToken: 'refresh-1',
            expiresAt: DateTime(2026, 3, 1, 9, 30),
          ),
        );
        return settings;
      }

      testWidgets(
        'Google connected, its list held open: the device rows are visible '
        'first; releasing Google moves none of them, and every Google row '
        'sits below them',
        (tester) => _withMobilePlatform(() async {
          final device = _RestorableFakeCalendarSource(
            calendars: deviceCalendars,
          );
          final googleSource = _FakeCalendarSource(
            calendars: [
              cal('google:primary', 'GWork', 'dan@gmail.com'),
              cal('google:second', 'GHome', 'dan@gmail.com'),
            ],
          )..listCalendarsGate = Completer<void>();

          await _pumpCalendarScreen(
            tester,
            source: device,
            googleSource: googleSource,
            settingsNotifier: await connectedSettings(),
          );
          // Several frames; the Google list is still held on its gate.
          await tester.pump();
          await tester.pump();
          await tester.pump();

          expect(find.text('GWork'), findsNothing, reason: 'still loading');
          expect(find.text('spunkl'), findsOneWidget);
          final before = {
            for (final n in ['Family', 'Home', 'spunkl']) n: rowY(tester, n),
          };

          googleSource.listCalendarsGate!.complete();
          await tester.pumpAndSettle();

          expect(find.text('GWork'), findsOneWidget);
          expect(find.text('GHome'), findsOneWidget);
          for (final n in ['Family', 'Home', 'spunkl']) {
            expect(rowY(tester, n), before[n], reason: '$n moved');
          }
          final lowestDevice = before.values.reduce((a, b) => a > b ? a : b);
          expect(rowY(tester, 'GWork'), greaterThan(lowestDevice));
          expect(rowY(tester, 'GHome'), greaterThan(lowestDevice));
        }),
      );

      testWidgets(
        'Google not connected: the device rows render above the '
        '"Connect Google Calendar" button',
        (tester) => _withMobilePlatform(() async {
          final device = _RestorableFakeCalendarSource(
            calendars: deviceCalendars,
          );
          await _pumpCalendarScreen(tester, source: device);
          await tester.pumpAndSettle();

          expect(find.text('Connect Google Calendar'), findsOneWidget);
          final button = tester.getTopLeft(
            find.text('Connect Google Calendar'),
          );
          for (final n in ['Family', 'Home', 'spunkl']) {
            expect(rowY(tester, n), lessThan(button.dy), reason: n);
          }
        }),
      );
    });

    test('sortCalendarsForPicker: no-account group first, then accounts, '
        'then names, all case-insensitive, ids break ties, input untouched', () {
      final input = [
        cal('1', 'banana', 'iCloud'),
        cal('9', 'x', 'Zed'),
        cal('2', 'Alpha', 'dan@gmail.com'),
        cal('3', 'beta', null),
        cal('4', 'Cherry', 'iCloud'),
        cal('8', 'Dup', 'iCloud'),
        cal('5', 'apple', 'iCloud'),
        cal('6', 'Dup', 'iCloud'),
        cal('7', 'Local', null),
      ];
      final before = [for (final c in input) c.id];

      final sorted = sortCalendarsForPicker(input);

      expect(
        [for (final c in sorted) c.id],
        [
          '3', // no account: beta
          '7', // no account: Local
          '2', // dan@gmail.com
          '5', // iCloud: apple
          '1', //         banana
          '4', //         Cherry (a case-sensitive sort would put it before apple)
          '6', //         Dup, lower id first
          '8', //         Dup
          '9', // Zed (a case-sensitive sort would put it before dan@gmail.com)
        ],
      );
      expect([for (final c in input) c.id], before);
    });
  });
}
