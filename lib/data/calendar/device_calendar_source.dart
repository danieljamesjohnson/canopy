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

/// The iOS device-calendar source (D-35-15): reads every calendar the user
/// has added at the OS level — iCloud, Google, Exchange, subscribed feeds —
/// via `device_calendar_plus`'s EventKit binding. No OAuth, no API key, no
/// vendor-specific integration (CAL-02).
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
    final events = await plugin.DeviceCalendar.instance.listEvents(
      start,
      end,
      calendarIds: calendarIds,
    );
    return events.map(mapDeviceEvent).toList();
  }
}
