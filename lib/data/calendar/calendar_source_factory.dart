import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

import 'calendar_source.dart';
import 'device_calendar_source.dart';
import 'ics_calendar_source.dart';
import 'null_calendar_source.dart';

/// Selects the right [CalendarSource] for the current platform (D-35-12: one
/// active source type per platform, never a combined multi-source picker).
///
/// Follows `notification_service.dart`'s platform-branching idiom: an
/// explicit branch per platform with a trailing comment for every one that's
/// a no-op — never a silent fallthrough.
CalendarSource defaultCalendarSource({List<String> icsUrls = const []}) {
  if (kIsWeb) {
    // Web: no device calendar API exists — ICS is the only path.
    return icsUrls.isEmpty
        ? NullCalendarSource()
        : IcsCalendarSource(urls: icsUrls);
  }
  if (Platform.isIOS) {
    // iOS: the native device calendar (D-35-15) — every calendar the user
    // has added at the OS level (iCloud, Google, Exchange, subscribed
    // feeds), no OAuth, no vendor-specific integration.
    return DeviceCalendarSource();
  }
  // Android, macOS, Windows, Linux: ICS is the path. Android was originally
  // meant to get its own DeviceCalendarSource too (D-35-12), but D-35-15
  // (35-DECISIONS.md) reversed that: device_calendar_plus's Android
  // implementation cannot be scoped to read-only — its own
  // permission-declaration guard requires WRITE_CALENDAR declared in the
  // manifest for ANY permission call to succeed, even a bare status check,
  // and READ_CALENDAR/WRITE_CALENDAR share one Android permission group, so
  // granting access would auto-grant write with no second dialog. Shipping
  // it would degrade CAL-03 from "the OS prevents it" to "our code
  // promises not to" — the owner ruled against that. Android reads
  // calendars via a subscribed .ics feed URL instead, exactly like desktop
  // and web; the accepted cost is a pasted URL instead of a ticked list.
  return icsUrls.isEmpty
      ? NullCalendarSource()
      : IcsCalendarSource(urls: icsUrls);
}
