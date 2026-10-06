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
import 'package:canopy/data/models/commitment_block.dart';
import 'package:canopy/data/repositories/commitment_block_repository.dart';
import 'package:canopy/data/repositories/in_memory_app_settings_repository.dart';
import 'package:canopy/providers/commitments_notifier.dart';
import 'package:canopy/providers/schedule_notifier.dart';
import 'package:canopy/providers/settings_notifier.dart';
import 'package:canopy/screens/commitments/commitments_screen.dart';
import 'package:canopy/screens/settings/calendar_settings_screen.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

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
  final List<CalendarInfo> calendars;
  final List<CalendarEvent> events;

  /// When non-null, requestPermission() never resolves until the test
  /// completes it — lets a test observe the in-flight spinner deliberately.
  final Completer<CalendarPermissionState>? _permissionGate;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<CalendarPermissionState> requestPermission() async {
    if (_permissionGate != null) return _permissionGate.future;
    return permission;
  }

  @override
  Future<List<CalendarInfo>> listCalendars() async => calendars;

  @override
  Future<List<CalendarEvent>> listEvents({
    required DateTime start,
    required DateTime end,
    required List<String> calendarIds,
  }) async => events;
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
}) async {
  final settings =
      settingsNotifier ?? SettingsNotifier(repository: InMemoryAppSettingsRepository());
  final commitments = commitmentsNotifier ??
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
      ],
      child: MaterialApp(
        home: CalendarSettingsScreen(source: source, googleSource: googleSource),
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

        expect(
          find.text('No calendars found on this device.'),
          findsOneWidget,
        );
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

        await tester.tap(
          find.text('2 events not imported — tap for details'),
        );
        await tester.pumpAndSettle();

        expect(find.text('Cancelled Meeting'), findsOneWidget);
        expect(find.text('Cancelled'), findsOneWidget);
        expect(find.text('Quick Sync'), findsOneWidget);
        expect(find.text('Too short to schedule'), findsOneWidget);
      }),
    );
  });

  group(
    'Plan 36-09 — the skipped-events disclosure moves to the top '
    '(WINDOWS entry 10)',
    () {
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
              .getTopLeft(
                find.text('2 events not imported — tap for details'),
              )
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
    },
  );

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

        // The Google section renders first, so its CheckboxListTile is the
        // first of the two on screen — untick it.
        await tester.tap(find.byType(CheckboxListTile).first);
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

  group(
    'D-35-15 — Android takes the desktop/ICS branch, not the device '
    'permission branch (35-DECISIONS.md)',
    () {
      testWidgets(
        'on Android, the screen shows the feed-URL CTA and never the '
        'device permission CTA, even though a device-capable source is '
        'passed in',
        (tester) async {
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
        },
      );
    },
  );
}
