// Pure-mapping tests for device_calendar_source.dart's top-level mapping
// functions — the one part of DeviceCalendarSource that can run on a
// machine with no Android SDK and no Xcode (danserver). These functions
// take plain plugin-shaped values and never reach `plugin.DeviceCalendar
// .instance`, so nothing here exercises the actual device path; Task 3 of
// 35-05-PLAN.md (the owner's MacBook) is what proves the device path
// itself.
import 'package:device_calendar_plus/device_calendar_plus.dart' as plugin;
import 'package:flutter_test/flutter_test.dart';

import 'package:canopy/data/calendar/calendar_event.dart';
import 'package:canopy/data/calendar/device_calendar_source.dart';

void main() {
  group(
    'mapDeviceCalendarPermissionStatus — every plugin status maps to the '
    "app's own enum",
    () {
      test('granted maps to granted', () {
        expect(
          mapDeviceCalendarPermissionStatus(
            plugin.CalendarPermissionStatus.granted,
          ),
          CalendarPermissionState.granted,
        );
      });

      test(
        'writeOnly maps to denied — this app never requests write access '
        'and must never treat a write-capable grant as success (CAL-03, '
        'Security V4)',
        () {
          expect(
            mapDeviceCalendarPermissionStatus(
              plugin.CalendarPermissionStatus.writeOnly,
            ),
            CalendarPermissionState.denied,
          );
        },
      );

      test('denied maps to denied', () {
        expect(
          mapDeviceCalendarPermissionStatus(
            plugin.CalendarPermissionStatus.denied,
          ),
          CalendarPermissionState.denied,
        );
      });

      test('restricted maps to restricted', () {
        expect(
          mapDeviceCalendarPermissionStatus(
            plugin.CalendarPermissionStatus.restricted,
          ),
          CalendarPermissionState.restricted,
        );
      });

      test('notDetermined maps to notDetermined', () {
        expect(
          mapDeviceCalendarPermissionStatus(
            plugin.CalendarPermissionStatus.notDetermined,
          ),
          CalendarPermissionState.notDetermined,
        );
      });
    },
  );

  group('mapDeviceCalendar — plugin Calendar to CalendarInfo (CAL-02)', () {
    test('carries id, name, accountName, accountType, colorHex through', () {
      const calendar = plugin.Calendar(
        id: 'cal-1',
        name: 'Work',
        colorHex: '#FF0000',
        readOnly: false,
        accountName: 'dan@gmail.com',
        accountType: 'com.google',
        isPrimary: true,
        hidden: false,
      );

      final info = mapDeviceCalendar(calendar);

      expect(info.id, 'cal-1');
      expect(info.name, 'Work');
      expect(info.accountName, 'dan@gmail.com');
      expect(info.accountType, 'com.google');
      expect(info.colorHex, '#FF0000');
    });

    test(
      'always reports isReadOnly true, regardless of the plugin\'s own '
      'readOnly field — CAL-03 means every CalendarSource implementation '
      'reports every calendar read-only no matter what the OS would allow',
      () {
        const writableCalendar = plugin.Calendar(
          id: 'cal-2',
          name: 'Personal',
          readOnly: false,
        );

        expect(mapDeviceCalendar(writableCalendar).isReadOnly, isTrue);
      },
    );

    test('a null accountName/accountType/colorHex stays null', () {
      const calendar = plugin.Calendar(
        id: 'cal-3',
        name: 'Local',
        readOnly: false,
      );

      final info = mapDeviceCalendar(calendar);

      expect(info.accountName, isNull);
      expect(info.accountType, isNull);
      expect(info.colorHex, isNull);
    });
  });

  group('mapDeviceEvent — plugin Event to CalendarEvent (CAL-01)', () {
    test('carries uid, title, start, end, isAllDay, calendarId through', () {
      final event = plugin.Event(
        eventId: 'evt-1',
        instanceId: 'evt-1',
        calendarId: 'cal-1',
        title: 'Standup',
        startDate: DateTime.utc(2026, 3, 2, 14),
        endDate: DateTime.utc(2026, 3, 2, 14, 15),
        isAllDay: false,
        availability: plugin.EventAvailability.busy,
        status: plugin.EventStatus.confirmed,
        isRecurring: false,
      );

      final mapped = mapDeviceEvent(event);

      expect(mapped.uid, 'evt-1');
      expect(mapped.title, 'Standup');
      expect(mapped.start, DateTime.utc(2026, 3, 2, 14));
      expect(mapped.end, DateTime.utc(2026, 3, 2, 14, 15));
      expect(mapped.isAllDay, isFalse);
      expect(mapped.calendarId, 'cal-1');
    });

    test(
      'a non-recurring event (instanceId == eventId) maps recurrenceId to '
      'null',
      () {
        final event = plugin.Event(
          eventId: 'evt-1',
          instanceId: 'evt-1',
          calendarId: 'cal-1',
          title: 'One-off',
          startDate: DateTime.utc(2026, 3, 2, 14),
          endDate: DateTime.utc(2026, 3, 2, 15),
          isAllDay: false,
          availability: plugin.EventAvailability.busy,
          status: plugin.EventStatus.confirmed,
          isRecurring: false,
        );

        expect(mapDeviceEvent(event).recurrenceId, isNull);
      },
    );

    test(
      'a recurring occurrence (instanceId != eventId) carries instanceId '
      'through as recurrenceId, so externalEventId stays unique per '
      'occurrence',
      () {
        final event = plugin.Event(
          eventId: 'evt-2',
          instanceId: 'evt-2@1772722800',
          calendarId: 'cal-1',
          title: 'Weekly sync',
          startDate: DateTime.utc(2026, 3, 2, 14),
          endDate: DateTime.utc(2026, 3, 2, 15),
          isAllDay: false,
          availability: plugin.EventAvailability.busy,
          status: plugin.EventStatus.confirmed,
          isRecurring: true,
        );

        expect(mapDeviceEvent(event).recurrenceId, 'evt-2@1772722800');
      },
    );
  });

  group(
    'mapDeviceEventStatus — every plugin status maps to the app\'s own '
    'enum, mirroring IcsCalendarSource\'s default-to-confirmed rule',
    () {
      test('canceled maps to cancelled', () {
        expect(
          mapDeviceEventStatus(plugin.EventStatus.canceled),
          CalendarEventStatus.cancelled,
        );
      });

      test('tentative maps to tentative', () {
        expect(
          mapDeviceEventStatus(plugin.EventStatus.tentative),
          CalendarEventStatus.tentative,
        );
      });

      test('confirmed maps to confirmed', () {
        expect(
          mapDeviceEventStatus(plugin.EventStatus.confirmed),
          CalendarEventStatus.confirmed,
        );
      });

      test('none (no status set at all) maps to confirmed', () {
        expect(
          mapDeviceEventStatus(plugin.EventStatus.none),
          CalendarEventStatus.confirmed,
        );
      });
    },
  );
}
