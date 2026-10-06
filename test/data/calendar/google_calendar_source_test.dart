// The tracer's proof: drive the WHOLE Google path in one test — a fake
// consent launcher returns a token, the token lands in a fake
// GoogleTokenStore, and a fake http.Client returns Google's own
// `events.list` JSON shape, all the way through the EXISTING
// CalendarSyncService into one CommitmentBlock. No native sheet, no
// network, no device.
//
// Throwaway doubles live in this file, not lib/ — the house pattern stated
// in calendar_settings_screen_test.dart's own header.

import 'dart:convert';
import 'dart:io';

import 'package:canopy/data/calendar/calendar_event.dart';
import 'package:canopy/data/calendar/calendar_source.dart';
import 'package:canopy/data/calendar/google_auth_client.dart';
import 'package:canopy/data/calendar/google_calendar_source.dart';
import 'package:canopy/data/models/commitment_block.dart';
import 'package:canopy/data/repositories/commitment_block_repository.dart';
import 'package:canopy/services/calendar_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/calendar/v3.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as gauth;
import 'package:http/http.dart' as http;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// In-memory GoogleTokenStore double — mirrors SettingsNotifier's shape
/// without touching Hive.
class _FakeGoogleTokenStore implements GoogleTokenStore {
  GoogleTokens? _tokens;
  bool _reconnectNeeded = false;

  @override
  Future<GoogleTokens?> read() async => _tokens;

  @override
  Future<void> write(GoogleTokens tokens) async {
    _tokens = tokens;
  }

  @override
  Future<void> clear() async {
    _tokens = null;
  }

  @override
  Future<void> setReconnectNeeded(bool value) async {
    _reconnectNeeded = value;
  }

  @override
  bool get reconnectNeeded => _reconnectNeeded;
}

/// In-memory CommitmentBlockRepository double — mirrors
/// test/services/calendar_sync_service_test.dart's own shape exactly.
class InMemoryCommitmentBlockRepository implements CommitmentBlockRepository {
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

/// An http.Client double returning a fixed JSON body for every request —
/// enough to fake Google's `events.list` response with no network at all.
class _FixtureHttpClient extends http.BaseClient {
  _FixtureHttpClient(this._body);

  final String _body;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = utf8.encode(_body);
    return http.StreamedResponse(
      Stream.value(bytes),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

/// An http.Client double that records every request URL and returns a
/// canned JSON body selected by which Calendar API endpoint the URL path
/// names — enough to fake both `calendarList.list` and `events.list` in one
/// test with no network at all.
class _RecordingHttpClient extends http.BaseClient {
  _RecordingHttpClient(this._responses);

  /// Maps a substring of the request path (e.g. `calendarList`, `events`)
  /// to the canned JSON body to return for a request whose path contains it.
  final Map<String, String> _responses;

  final List<Uri> requestedUrls = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestedUrls.add(request.url);
    final entry = _responses.entries.firstWhere(
      (e) => request.url.path.contains(e.key),
    );
    final bytes = utf8.encode(entry.value);
    return http.StreamedResponse(
      Stream.value(bytes),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

Future<String> _fixture(String name) =>
    File('test/fixtures/calendar/$name').readAsString();

Future<Events> _loadEvents(String fixtureName) async {
  final text = await _fixture(fixtureName);
  return Events.fromJson(jsonDecode(text) as Map<String, dynamic>);
}

void main() {
  tzdata.initializeTimeZones();

  tearDown(() {
    // Never leak a non-UTC tz.local override into later tests in the suite.
    tz.setLocalLocation(tz.UTC);
  });

  test('a canned Google token persists to the store, and a canned events.list '
      'response becomes one CommitmentBlock through the unchanged '
      'CalendarSyncService (tracer, CALAUTH-01/02)', () async {
    tz.setLocalLocation(tz.UTC);

    final store = _FakeGoogleTokenStore();
    final authClient = GoogleAuthClient(
      store: store,
      // Synthetic — matches Google's real client-id shape only so
      // reverseGoogleClientId() (called internally by connect()) doesn't
      // throw. Never a real client id (see CLAUDE.md / plan 36-04's
      // CALAUTH-04 gate).
      clientId: '000000000000-synthtestidvalue.apps.googleusercontent.com',
      launcher:
          ({
            required String clientId,
            required String redirectUri,
            required List<String> scopes,
          }) async => GoogleTokens(
            accessToken: 'fake-access-token',
            refreshToken: 'fake-refresh-token',
            expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
          ),
    );

    // 1. The consent round trip, faked end to end.
    final cancelled = await authClient.connect();
    expect(cancelled, isFalse);

    // 2. The token landed in the store (survives-restart proxy — the
    // store IS the persistence boundary; SettingsNotifier is the
    // production implementation backed by Hive).
    final storedTokens = await store.read();
    expect(storedTokens, isNotNull);
    expect(storedTokens!.accessToken, equals('fake-access-token'));
    expect(storedTokens.refreshToken, equals('fake-refresh-token'));

    // 3. A canned Google events.list response, in Google's real shape.
    final fixtureJson = await _fixture('google_events_list_basic.json');
    final source = GoogleCalendarSource(
      authClient: authClient,
      calendarIds: const ['google:dan@example.com'],
      apiClientFactory: () async => _FixtureHttpClient(fixtureJson),
    );

    final repo = InMemoryCommitmentBlockRepository();
    final syncedAt = DateTime.utc(2026, 3, 1);
    final service = CalendarSyncService(
      source: source,
      repository: repo,
      now: () => syncedAt,
    );

    // 4. The whole path, through the EXISTING (unmodified) sync service.
    final result = await service.sync();

    expect(result.failed, isFalse);
    expect(result.imported, hasLength(1));
    final block = result.imported.single;
    expect(block.name, equals('Team standup'));
    expect(block.isFromCalendar, isTrue);
    expect(block.externalEventId, isNotEmpty);
    // Fixture event is 14:00-14:25 UTC; tz.local is UTC in this test, so
    // local wall-clock minutes equal the UTC clock reading.
    expect(block.startMinutes, equals(14 * 60));
    expect(block.endMinutes, equals(14 * 60 + 25));
  });

  test('authenticatedClient() refreshes an expired access token via the '
      'injected refresher and persists the result (Assumption A6)', () async {
    final store = _FakeGoogleTokenStore();
    await store.write(
      GoogleTokens(
        accessToken: 'stale-access-token',
        refreshToken: 'still-good-refresh-token',
        expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
      ),
    );

    var refresherCalled = false;
    final authClient = GoogleAuthClient(
      store: store,
      clientId: '000000000000-synthtestidvalue.apps.googleusercontent.com',
      refresher: (clientId, credentials, client) async {
        refresherCalled = true;
        // A null secret must reach here unchanged (Assumption A6 — Google
        // never requires one for an installed/iOS client).
        expect(clientId.secret, isNull);
        expect(credentials.refreshToken, equals('still-good-refresh-token'));
        return gauth.AccessCredentials(
          gauth.AccessToken(
            'Bearer',
            'refreshed-access-token',
            DateTime.now().toUtc().add(const Duration(hours: 1)),
          ),
          'still-good-refresh-token',
          const [],
        );
      },
    );

    final client = await authClient.authenticatedClient();
    client.close();

    expect(refresherCalled, isTrue);
    final persisted = await store.read();
    expect(persisted!.accessToken, equals('refreshed-access-token'));
    expect(persisted.refreshToken, equals('still-good-refresh-token'));
  });

  group('mapGoogleEvent — Google event shapes the real API actually returns '
      '(Task 1). Every claim here is proven against fixtures built from '
      "googleapis 17.0.0's own field names, NOT against a live Google "
      'response — nobody on this machine can capture one. These fixtures '
      'prove our mapper honours a moved instance; that Google actually emits '
      "one is plan 36-07's item 4, on the owner's MacBook.", () {
    test('a moved recurring instance maps to its own (moved) start, not to '
        'originalStartTime, and its siblings map at the base time — the '
        'defect WINDOWS.md entry 1 records as unfixable on the .ics path '
        '(NOT a claim about the device path — Phase 35 Assumption A1 '
        'covers that, and A1 is itself still unverified)', () async {
      tz.setLocalLocation(tz.UTC);
      final events = await _loadEvents(
        'google_events_list_recurring_moved.json',
      );
      final mapped = events.items!
          .map((e) => mapGoogleEvent(e, calendarId: 'google:dan@example.com'))
          .toList();

      expect(mapped, hasLength(4));
      // Bare literal times — not re-derived from the fixture by the
      // same code path under test (the mandatory acceptance criterion).
      expect(mapped[0]!.start, DateTime.utc(2026, 3, 2, 14));
      expect(mapped[1]!.start, DateTime.utc(2026, 3, 9, 15)); // MOVED
      expect(mapped[2]!.start, DateTime.utc(2026, 3, 16, 14));
      expect(mapped[3]!.start, DateTime.utc(2026, 3, 23, 14));
    });

    test(
      'every instance of one series shares its uid (the series id), and '
      'each carries its own occurrence identity as recurrenceId (the '
      "instance id) — matching CalendarSource's documented contract",
      () async {
        final events = await _loadEvents(
          'google_events_list_recurring_moved.json',
        );
        final mapped = events.items!
            .map((e) => mapGoogleEvent(e, calendarId: 'google:dan@example.com'))
            .toList();

        expect(mapped.map((e) => e!.uid).toSet(), {'series1'});
        expect(
          mapped[1]!.recurrenceId,
          'series1_20260309T140000Z', // the moved instance's own id
        );
        expect(mapped[0]!.recurrenceId, 'series1_20260302T140000Z');
      },
    );

    test('a cancelled instance returned only because showDeleted is true '
        'maps to CalendarEventStatus.cancelled and is NOT dropped by the '
        'mapper — CalendarSyncService skips it downstream with the '
        'existing cancelled reason', () async {
      final events = await _loadEvents('google_events_list_edge_cases.json');
      final cancelled = events.items!.firstWhere(
        (e) => e.id == 'cancelled_with_fallback_20260304T090000Z',
      );

      final mapped = mapGoogleEvent(
        cancelled,
        calendarId: 'google:dan@example.com',
      );

      expect(mapped, isNotNull);
      expect(mapped!.status, CalendarEventStatus.cancelled);
    });

    test('that same cancelled stub carries no start of its own and falls '
        'back to originalStartTime rather than being dropped', () async {
      final events = await _loadEvents('google_events_list_edge_cases.json');
      final cancelled = events.items!.firstWhere(
        (e) => e.id == 'cancelled_with_fallback_20260304T090000Z',
      );

      final mapped = mapGoogleEvent(
        cancelled,
        calendarId: 'google:dan@example.com',
      );

      expect(mapped!.start, DateTime.utc(2026, 3, 4, 9));
    });

    test('a cancelled stub carrying no start AND no originalStartTime at '
        'all — the minimal shape Google returns for a deleted instance — '
        'is dropped cleanly without throwing (the shape most likely to '
        'crash a naive mapper)', () async {
      final events = await _loadEvents('google_events_list_edge_cases.json');
      final timeless = events.items!.firstWhere(
        (e) => e.id == 'cancelled_no_usable_time',
      );

      expect(
        () => mapGoogleEvent(timeless, calendarId: 'google:dan@example.com'),
        returnsNormally,
      );
      expect(
        mapGoogleEvent(timeless, calendarId: 'google:dan@example.com'),
        isNull,
      );
    });

    test('an all-day event (start carries date, not dateTime) maps with '
        'isAllDay true and a start on that local calendar day', () async {
      tz.setLocalLocation(tz.getLocation('America/Chicago'));
      final events = await _loadEvents('google_events_list_edge_cases.json');
      final allDay = events.items!.firstWhere(
        (e) => e.id == 'all_day_conference',
      );

      final mapped = mapGoogleEvent(
        allDay,
        calendarId: 'google:dan@example.com',
      );

      expect(mapped!.isAllDay, isTrue);
      expect(
        mapped.start.isAtSameMomentAs(tz.TZDateTime(tz.local, 2026, 3, 6)),
        isTrue,
      );
    });

    test('a timed event whose dateTime carries a non-local UTC offset maps '
        "to the correct absolute instant, NOT re-anchored to this "
        "machine's system timezone", () async {
      tz.setLocalLocation(tz.getLocation('America/Chicago'));
      final events = await _loadEvents('google_events_list_edge_cases.json');
      final foreignOffset = events.items!.firstWhere(
        (e) => e.id == 'foreign_offset_dinner',
      );

      final mapped = mapGoogleEvent(
        foreignOffset,
        calendarId: 'google:dan@example.com',
      );

      // 19:00 US Eastern (-05:00) is 00:00 UTC the next day, regardless
      // of this test's tz.local override.
      expect(mapped!.start, DateTime.utc(2026, 3, 6));
      expect(mapped.start.isUtc, isTrue);
    });

    test('an event with no summary (which cancelled stubs routinely lack) '
        'maps to a non-null title rather than throwing', () async {
      final events = await _loadEvents('google_events_list_edge_cases.json');
      final noSummary = events.items!.firstWhere(
        (e) => e.id == 'no_summary_event',
      );

      final mapped = mapGoogleEvent(
        noSummary,
        calendarId: 'google:dan@example.com',
      );

      expect(mapped, isNotNull);
      expect(mapped!.title, isNotNull);
      expect(mapped.title, '');
    });

    test("a tentative event maps to tentative and still imports — matching "
        "the ICS path's existing behaviour exactly", () async {
      final events = await _loadEvents('google_events_list_edge_cases.json');
      final tentative = events.items!.firstWhere(
        (e) => e.id == 'tentative_hold',
      );

      final mapped = mapGoogleEvent(
        tentative,
        calendarId: 'google:dan@example.com',
      );

      expect(mapped, isNotNull);
      expect(mapped!.status, CalendarEventStatus.tentative);
    });
  });

  group('filterGoogleCalendarIds (WR-02 code review) — the shared filter '
      "calendar_settings_screen.dart's _googleSelectedIds and "
      "checkin_screen.dart's _generate() both call, so their behavior can "
      'never silently desync from each other or from the prefix this file '
      'stamps on every id it hands out', () {
    test('keeps only ids carrying the googleCalendarIdPrefix, in order, '
        'dropping every device id', () {
      final result = filterGoogleCalendarIds([
        'device-1',
        '${googleCalendarIdPrefix}dan@example.com',
        'device-2',
        '${googleCalendarIdPrefix}work@example.com',
      ]);

      expect(result, [
        '${googleCalendarIdPrefix}dan@example.com',
        '${googleCalendarIdPrefix}work@example.com',
      ]);
    });

    test('an empty input yields an empty result', () {
      expect(filterGoogleCalendarIds(const []), isEmpty);
    });
  });

  group('filterGoogleCalendarIds / filterDeviceCalendarIds (WINDOWS entry 7) — '
      'the two filters are the exact complement of each other, so every id '
      'in a mixed selection lands on exactly one side and none is dropped', () {
    test('concatenating both filters\' outputs over a mixed list contains '
        'every input id exactly once, and no id appears in both', () {
      const mixedIds = [
        'cal-device-1',
        '${googleCalendarIdPrefix}dan@example.com',
        'cal-device-2',
        '${googleCalendarIdPrefix}work@example.com',
        'cal-device-3',
      ];

      final googleIds = filterGoogleCalendarIds(mixedIds);
      final deviceIds = filterDeviceCalendarIds(mixedIds);

      expect(googleIds, [
        '${googleCalendarIdPrefix}dan@example.com',
        '${googleCalendarIdPrefix}work@example.com',
      ]);
      expect(deviceIds, ['cal-device-1', 'cal-device-2', 'cal-device-3']);
      expect({...googleIds, ...deviceIds}, Set<String>.from(mixedIds));
      expect(googleIds.toSet().intersection(deviceIds.toSet()), isEmpty);
    });
  });

  group('GoogleCalendarSource.listCalendars() — CalendarInfo mapping and '
      'sourceLabel (Task 2, D-36-03)', () {
    test('maps summary/backgroundColor/isReadOnly/sourceLabel and uses the '
        "PRIMARY entry's id as accountName for every calendar — a "
        "secondary or subscribed calendar's own id is not an account "
        'identifier', () async {
      final fixtureJson = await _fixture('google_calendar_list.json');
      final authClient = GoogleAuthClient(store: _FakeGoogleTokenStore());
      final source = GoogleCalendarSource(
        authClient: authClient,
        calendarIds: const [],
        apiClientFactory: () async => _FixtureHttpClient(fixtureJson),
      );

      final calendars = await source.listCalendars();

      expect(calendars, hasLength(3));

      final primary = calendars.firstWhere(
        (c) => c.id == 'google:dan@example.com',
      );
      expect(primary.name, 'dan@example.com');
      expect(primary.accountName, 'dan@example.com');
      expect(primary.accountType, 'Google');
      expect(primary.colorHex, '#0088aa');
      expect(primary.isReadOnly, isTrue);
      expect(primary.sourceLabel, 'Google');

      final secondary = calendars.firstWhere(
        (c) => c.id == 'google:abcdef1234567890@group.calendar.google.com',
      );
      expect(secondary.name, 'Family');
      // The grouping fact this task exists to establish: a secondary
      // calendar's OWN id must never be used as its accountName.
      expect(secondary.accountName, 'dan@example.com');
      expect(secondary.sourceLabel, 'Google');

      final holiday = calendars.firstWhere(
        (c) => c.id == 'google:en.usa#holiday@group.v.calendar.google.com',
      );
      expect(holiday.accountName, 'dan@example.com');
    });

    test('WR-03: when calendarList.list() has no primary entry, every '
        'calendar still gets a non-null accountName rather than null — '
        'a null accountName would group under the empty-string bucket, '
        "which _calendarRows renders as the literal header 'This device' "
        '(a real mislabeling for a Google calendar), and would also make '
        'the calendar permanently ineligible for '
        'detectSelectedCalendarOverlaps, which requires a non-null '
        'accountName on both sides', () async {
      final noPrimaryJson = jsonEncode({
        'kind': 'calendar#calendarList',
        'items': [
          {
            'kind': 'calendar#calendarListEntry',
            'id': 'abcdef1234567890@group.calendar.google.com',
            'summary': 'Family',
            'backgroundColor': '#ff8800',
          },
        ],
      });
      final authClient = GoogleAuthClient(store: _FakeGoogleTokenStore());
      final source = GoogleCalendarSource(
        authClient: authClient,
        calendarIds: const [],
        apiClientFactory: () async => _FixtureHttpClient(noPrimaryJson),
      );

      final calendars = await source.listCalendars();

      expect(calendars, hasLength(1));
      expect(calendars.single.accountName, isNotNull);
    });

    test('a Google calendar id round-trips: prefixed on the way out of '
        "listCalendars(), stripped from the outbound events.list() "
        'request (plan 36-05 depends on this being unambiguous)', () async {
      final calendarListJson = await _fixture('google_calendar_list.json');
      final eventsJson = await _fixture('google_events_list_basic.json');
      final client = _RecordingHttpClient({
        'calendarList': calendarListJson,
        'events': eventsJson,
      });

      final authClient = GoogleAuthClient(store: _FakeGoogleTokenStore());
      final source = GoogleCalendarSource(
        authClient: authClient,
        calendarIds: const [],
        apiClientFactory: () async => client,
      );

      final calendars = await source.listCalendars();
      final prefixedId = calendars.first.id;
      // WR-02: asserted against the shared public constant, not a
      // second hardcoded 'google:' literal — a future rename of the
      // prefix must fail this assertion rather than silently agreeing
      // with a copy that no longer matches production.
      expect(prefixedId, '${googleCalendarIdPrefix}dan@example.com');

      await source.listEvents(
        start: DateTime.utc(2026, 3, 1),
        end: DateTime.utc(2026, 3, 2),
        calendarIds: [prefixedId],
      );

      final eventsRequest = client.requestedUrls.firstWhere(
        (u) => u.path.contains('events'),
      );
      // The outbound request's OWN observed value carries the bare
      // Google id — the `google:` prefix this app added for its own
      // persisted-selection disambiguation never reaches Google.
      expect(eventsRequest.pathSegments, contains('dan@example.com'));
      expect(
        eventsRequest.pathSegments.any(
          (segment) => segment.contains(googleCalendarIdPrefix),
        ),
        isFalse,
      );
    });
  });

  group('GoogleCalendarSource — CALAUTH-02: one read-only scope, proven by a '
      'command rather than asserted in prose (Task 3)', () {
    test('requestPermission() hands the auth client exactly one scope, and '
        'it is the read-only calendar scope — asserted against a bare '
        'literal, never re-derived from kGoogleCalendarReadonlyScope (an '
        'assertion derived from the constant it checks moves with that '
        'constant and cannot fail)', () async {
      List<String>? capturedScopes;
      final authClient = GoogleAuthClient(
        store: _FakeGoogleTokenStore(),
        clientId: '000000000000-synthtestidvalue.apps.googleusercontent.com',
        launcher:
            ({
              required String clientId,
              required String redirectUri,
              required List<String> scopes,
            }) async {
              capturedScopes = scopes;
              return GoogleTokens(
                accessToken: 'fake-access-token',
                refreshToken: 'fake-refresh-token',
                expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
              );
            },
      );
      final source = GoogleCalendarSource(
        authClient: authClient,
        calendarIds: const [],
      );

      await source.requestPermission();

      expect(capturedScopes, hasLength(1));
      expect(
        capturedScopes!.single,
        'https://www.googleapis.com/auth/calendar.readonly',
      );
    });

    test('GoogleCalendarSource satisfies CalendarSource and exposes no '
        'public method beyond the four interface verbs plus its '
        'constructor — the structural half of the guarantee', () async {
      final authClient = GoogleAuthClient(store: _FakeGoogleTokenStore());
      final source = GoogleCalendarSource(
        authClient: authClient,
        calendarIds: const [],
      );
      expect(source, isA<CalendarSource>());

      final sourceText = await File(
        'lib/data/calendar/google_calendar_source.dart',
      ).readAsString();
      final classStart = sourceText.indexOf(
        'class GoogleCalendarSource implements CalendarSource {',
      );
      expect(classStart, greaterThan(-1));
      final classBody = sourceText.substring(classStart);
      // This class's own style: every method it declares is exactly
      // 2-space-indented and returns `Future<...>` — the private
      // `_stripPrefix` helper returns `String` and is deliberately NOT
      // matched here, and neither is the constructor.
      final methodNames = RegExp(
        r'^  Future<[\w<>,\s\?]+>\s+([a-zA-Z]\w*)\s*\(',
        multiLine: true,
      ).allMatches(classBody).map((m) => m.group(1)!).toSet();

      expect(
        methodNames,
        {'isAvailable', 'requestPermission', 'listCalendars', 'listEvents'},
        reason:
            'GoogleCalendarSource must expose exactly the four '
            'CalendarSource verbs and nothing else — a public method '
            "beyond these would be new surface CALAUTH-02's guarantee "
            'has not accounted for.',
      );
    });
  });
}
