import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

import 'calendar_source.dart';
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
  if (Platform.isIOS || Platform.isAndroid) {
    // Mobile: the device calendar source lands in plan 35-05
    // (`device_calendar_source.dart`). Until then, mobile has no calendar
    // source of its own — NullCalendarSource degrades honestly rather than
    // pretending ICS is the mobile story.
    return NullCalendarSource();
  }
  // macOS/Windows/Linux desktop: same as web — ICS is the path (D-35-12).
  return icsUrls.isEmpty
      ? NullCalendarSource()
      : IcsCalendarSource(urls: icsUrls);
}
