import 'package:device_calendar_plus/device_calendar_plus.dart' as plugin;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

import 'calendar_event.dart';
import 'calendar_source.dart';

// ── Pure mapping functions ──────────────────────────────────────────────
//
// Deliberately top-level, taking plain plugin-shaped values rather than
// reaching into `plugin.DeviceCalendar.instance` — this is the seam that
// lets the mapping be unit-tested on a machine with no Android SDK and no
// Xcode (danserver). `DeviceCalendarSource` itself is a thin adapter that
// calls the plugin singleton and delegates every conversion here; nothing
// below this comment can run on this machine, nothing above it needs a
// device to prove correct.

/// Maps the plugin's permission status onto this app's own enum.
///
/// This app only ever requests [plugin.CalendarAccessLevel.full] — the only
/// tier that includes read access, since the plugin has no separate
/// read-only tier — and never [plugin.CalendarAccessLevel.writeOnly]. A
/// [plugin.CalendarPermissionStatus.writeOnly] result should therefore not
/// occur in practice, but if the OS ever returns it anyway, it maps to the
/// same state as [CalendarPermissionState.denied]: this app never needs
/// write access and must never treat a write-capable grant as success
/// (CAL-03, Security V4).
CalendarPermissionState mapDeviceCalendarPermissionStatus(
  plugin.CalendarPermissionStatus status,
) {
  switch (status) {
    case plugin.CalendarPermissionStatus.granted:
      return CalendarPermissionState.granted;
    case plugin.CalendarPermissionStatus.writeOnly:
      return CalendarPermissionState.denied;
    case plugin.CalendarPermissionStatus.denied:
      return CalendarPermissionState.denied;
    case plugin.CalendarPermissionStatus.restricted:
      return CalendarPermissionState.restricted;
    case plugin.CalendarPermissionStatus.notDetermined:
      return CalendarPermissionState.notDetermined;
  }
}

/// Maps the plugin's `Calendar` onto this app's uniform [CalendarInfo].
///
/// [plugin.Calendar.accountName]/[plugin.Calendar.accountType] are carried
/// through faithfully — this is what the settings picker groups by, and
/// grouping by account is how the screen SHOWS the user whether their
/// Google account is attached, rather than asking (D-35-04).
CalendarInfo mapDeviceCalendar(plugin.Calendar calendar) {
  return CalendarInfo(
    id: calendar.id,
    name: calendar.name,
    accountName: calendar.accountName,
    accountType: calendar.accountType,
    colorHex: calendar.colorHex,
    // Always true regardless of the plugin's own `readOnly` field — CAL-03
    // means Canopy never writes to a calendar, so every CalendarSource
    // implementation reports every calendar as read-only regardless of
    // what the OS itself would allow (see CalendarInfo.isReadOnly's own
    // doc comment).
    isReadOnly: true,
    // D-36-03: this string is deliberately byte-identical to the
    // account-less fallback `_groupedCalendarList` already renders at
    // `calendar_settings_screen.dart:459`, so the picker gains no second
    // vocabulary for the same idea.
    sourceLabel: 'This device',
  );
}

/// Maps the plugin's `Event` onto this app's uniform [CalendarEvent].
///
/// The OS (EventKit) has already resolved recurrence and any exceptions
/// before this event ever reaches Dart — this function does not attempt to
/// expand, re-expand, or correct recurrence itself, it only relabels the
/// fields (Pattern 3, RESEARCH.md).
CalendarEvent mapDeviceEvent(plugin.Event event) {
  return CalendarEvent(
    uid: event.eventId,
    // Per the plugin's own doc comment, instanceId equals eventId for a
    // non-recurring event — only carry it through as recurrenceId when it
    // actually distinguishes this occurrence from its siblings, so
    // externalEventId stays unique per occurrence without being
    // needlessly qualified for a one-off event.
    recurrenceId: event.instanceId == event.eventId ? null : event.instanceId,
    title: event.title,
    start: event.startDate,
    end: event.endDate,
    isAllDay: event.isAllDay,
    status: mapDeviceEventStatus(event.status),
    calendarId: event.calendarId,
  );
}

/// Maps the plugin's `EventStatus` onto this app's [CalendarEventStatus].
///
/// Mirrors `IcsCalendarSource._mapStatus`'s own default: anything that
/// isn't explicitly cancelled or tentative reads as confirmed, including
/// the plugin's `none` (no status set at all).
CalendarEventStatus mapDeviceEventStatus(plugin.EventStatus status) {
  switch (status) {
    case plugin.EventStatus.canceled:
      return CalendarEventStatus.cancelled;
    case plugin.EventStatus.tentative:
      return CalendarEventStatus.tentative;
    case plugin.EventStatus.confirmed:
    case plugin.EventStatus.none:
      return CalendarEventStatus.confirmed;
  }
}

// ── The adapter ──────────────────────────────────────────────────────────

/// Produces the raw plugin events for one `listEvents` call. The production
/// default forwards straight to `plugin.DeviceCalendar.instance.listEvents`;
/// tests inject a recorder here instead, so the exact `calendarIds` list that
/// would reach `device_calendar_plus` is observable on a host machine with no
/// Android SDK and no Xcode — mirroring `IcsCalendarSource`'s `fetch:` seam
/// and `GoogleCalendarSource`'s `apiClientFactory:` seam.
typedef DeviceEventsFetcher =
    Future<List<plugin.Event>> Function({
      required DateTime start,
      required DateTime end,
      required List<String> calendarIds,
    });

Future<List<plugin.Event>> _defaultFetchEvents({
  required DateTime start,
  required DateTime end,
  required List<String> calendarIds,
}) => plugin.DeviceCalendar.instance.listEvents(
  start,
  end,
  calendarIds: calendarIds,
);

/// The iOS device-calendar source (D-35-15): reads every calendar the user
/// has added at the OS level — iCloud, Google, Exchange, subscribed feeds —
/// via `device_calendar_plus`'s EventKit binding. No OAuth, no API key, no
/// vendor-specific integration (CAL-02).
///
/// **CAL-02 enforcement point (WINDOWS entry 7).** This class is constructed
/// with the exact set of calendar ids the user has ticked
/// ([configuredCalendarIds]) and substitutes that list whenever `listEvents`
/// is called with an empty `calendarIds` argument — the same convention
/// `GoogleCalendarSource` already follows, since `CalendarSyncService.sync()`
/// always passes `calendarIds: const []` as its own "every calendar this
/// source is configured for" convention. Previously this class forwarded
/// that empty list straight to `device_calendar_plus`, which resolves an
/// empty id list to "every calendar on the device" — the defect this
/// constructor-time list exists to close.
///
/// **Android does not use this class**, even though `device_calendar_plus`
/// itself supports Android. `device_calendar_plus`'s own Android
/// permission-declaration guard (`PermissionService.kt`) requires BOTH
/// `READ_CALENDAR` and `WRITE_CALENDAR` to be *declared* in the manifest for
/// any permission call to succeed — even a bare status check — because the
/// plugin has no separate read-only [plugin.CalendarAccessLevel] on either
/// platform, only `full` (read+write) and `writeOnly` (write alone). Worse,
/// per the plugin's own `doc/permissions.md`, `READ_CALENDAR` and
/// `WRITE_CALENDAR` share one Android permission group, so granting access
/// auto-grants write with no second dialog. Shipping this class on Android
/// would therefore mean Canopy genuinely holds OS-level write capability,
/// degrading CAL-03 from "the operating system prevents it" to "our code
/// promises not to" — the owner ruled against that (D-35-15,
/// `35-DECISIONS.md`). `calendar_source_factory.dart` routes Android to
/// `IcsCalendarSource` instead, exactly like desktop and web. iOS has no
/// equivalent problem: its `full`-level guard only requires
/// `NSCalendarsUsageDescription` declared (verified in
/// `device_calendar_plus_ios`'s `PermissionService.swift`).
///
/// Read-only by construction, same as every [CalendarSource]: this class
/// calls only the plugin's read APIs — `requestPermissions`, `listCalendars`,
/// `listEvents` — and never `createEvent`, `updateEvent`, `deleteEvent`,
/// `createCalendar`, `updateCalendar`, or `deleteCalendar` (CAL-03).
class DeviceCalendarSource implements CalendarSource {
  DeviceCalendarSource({
    List<String> calendarIds = const [],
    DeviceEventsFetcher? fetchEvents,
  }) : _calendarIds = calendarIds,
       _fetchEvents = fetchEvents ?? _defaultFetchEvents;

  final List<String> _calendarIds;
  final DeviceEventsFetcher _fetchEvents;

  /// The calendar ids this source was constructed with — for tests and
  /// introspection only. Mirrors `CompositeCalendarSource.children`'s own
  /// contract: this class never reorders or filters what the constructor
  /// was given. As of WINDOWS entry 7, this list is also the CAL-02
  /// enforcement point on the device path — see this class's own doc
  /// comment.
  List<String> get configuredCalendarIds => List.unmodifiable(_calendarIds);

  @override
  Future<bool> isAvailable() async {
    if (kIsWeb) return false; // Web: no EventKit binding exists.
    if (Platform.isIOS) return true;
    // Android and desktop: this class is iOS-only by design (D-35-15). The
    // factory never constructs it for these platforms, but this getter
    // stays honest regardless of who calls it, matching
    // notification_service.dart's "no silent fallthrough" idiom.
    return false;
  }

  @override
  Future<CalendarPermissionState> requestPermission() async {
    // `level` defaults to `CalendarAccessLevel.full` — the only tier that
    // includes read access, since the plugin has no separate read-only
    // tier. This app never passes `CalendarAccessLevel.writeOnly` (the
    // add-only, write-oriented tier) — it has no use for it and must never
    // request it (CAL-03, Security V4).
    final status = await plugin.DeviceCalendar.instance.requestPermissions();
    return mapDeviceCalendarPermissionStatus(status);
  }

  @override
  Future<List<CalendarInfo>> listCalendars() async {
    final calendars = await plugin.DeviceCalendar.instance.listCalendars();
    return calendars.map(mapDeviceCalendar).toList();
  }

  @override
  Future<List<CalendarEvent>> listEvents({
    required DateTime start,
    required DateTime end,
    required List<String> calendarIds,
  }) async {
    // Empty means "every calendar this source is configured for" — the same
    // convention GoogleCalendarSource.listEvents follows, and exactly what
    // CalendarSyncService.sync() passes.
    final targetIds = calendarIds.isEmpty ? _calendarIds : calendarIds;
    if (targetIds.isEmpty) {
      // The plugin resolves an empty id list to "every calendar on the
      // device" — forwarding one would be precisely the CAL-02 violation
      // WINDOWS entry 7 recorded. A user who has ticked nothing must import
      // nothing, so the seam is never called at all here — the same outcome
      // GoogleCalendarSource already gets for free from its own empty-list
      // for-loop.
      return const [];
    }
    final events = await _fetchEvents(
      start: start,
      end: end,
      calendarIds: targetIds,
    );
    return events.map(mapDeviceEvent).toList();
  }
}
