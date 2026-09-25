import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

import 'calendar_source.dart';
import 'composite_calendar_source.dart';
import 'device_calendar_source.dart';
import 'google_auth_client.dart';
import 'google_calendar_source.dart';
import 'ics_calendar_source.dart';
import 'null_calendar_source.dart';

/// Selects the right [CalendarSource] for the current platform.
///
/// D-35-12 established "one active source type per platform, never a
/// combined multi-source picker" — **D-36-03 overrides that rule for iOS
/// specifically, and only iOS**: when a Google auth client is supplied, iOS
/// returns both the Google and device sources together (see
/// [iosCalendarSource]), because the owner chose to keep device-only
/// calendars (iCloud Personal, a local calendar, a subscribed OS-level
/// feed) reachable while signed in to Google. This is a narrow, deliberate
/// carve-out, not a quiet violation of the rule it overrides — every other
/// platform keeps D-35-12's original rule untouched.
///
/// Follows `notification_service.dart`'s platform-branching idiom: an
/// explicit branch per platform with a trailing comment for every one that's
/// a no-op — never a silent fallthrough.
CalendarSource defaultCalendarSource({
  List<String> icsUrls = const [],
  GoogleAuthClient? googleAuth,
  List<String> googleCalendarIds = const [],
}) {
  if (kIsWeb) {
    // Web: no device calendar API exists — ICS is the only path. D-36-01's
    // accepted cost: the Google sign-in button does not exist here.
    return icsUrls.isEmpty
        ? NullCalendarSource()
        : IcsCalendarSource(urls: icsUrls);
  }
  if (Platform.isIOS) {
    return iosCalendarSource(
      googleAuth: googleAuth,
      googleCalendarIds: googleCalendarIds,
    );
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

/// The iOS composition decision (D-36-03), factored out from the real
/// `Platform.isIOS` check above purely for testability — deliberately a
/// plain top-level function taking `googleAuth` directly, mirroring this
/// codebase's existing pure-function/adapter split (`mapGoogleEvent`,
/// `mapDeviceEvent`): this is the seam a test can call directly, exercising
/// exactly the same code [defaultCalendarSource] runs when `Platform.isIOS`
/// is true. `dart:io`'s `Platform.isIOS` itself cannot be forced inside
/// `flutter test` the way Flutter's own `defaultTargetPlatform` can via
/// `debugDefaultTargetPlatformOverride` — this file (like
/// `device_calendar_source.dart`'s own `Platform.isIOS` check) deliberately
/// keeps `dart:io.Platform` rather than switching to `defaultTargetPlatform`,
/// so the real OS read above is, like that existing check, unverifiable on
/// danserver and left to CI/the owner's device rather than a host test.
///
/// The Google child must be harmless when nobody has signed in:
/// [GoogleCalendarSource.listCalendars]/[GoogleCalendarSource.listEvents] on
/// a client with no stored token already return empty rather than throwing
/// (36-01), so composing it unconditionally on iOS is safe — there is no
/// need for a separate connected-or-not flag here, one less piece of state
/// that could disagree with Hive. Google is ordered first, device second,
/// so the picker (plan 36-06) renders the signed-in account above the
/// device's own list.
///
/// **`googleCalendarIds`, closing WINDOWS.md entry 5 (plan 36-06).** Unlike
/// `DeviceCalendarSource` (whose plugin resolves an empty list to "every
/// calendar" internally) or `IcsCalendarSource` (whose feed list IS its
/// configuration), `GoogleCalendarSource` has no way to enumerate "every
/// calendar" on its own — it must be told which calendar ids to query, AND
/// it must be told at CONSTRUCTION time specifically: `CalendarSyncService
/// .sync()` always calls `listEvents` with an EMPTY `calendarIds` argument
/// (its own "empty means every configured calendar" convention), so a
/// constructor-time list is the only place this can ever take effect. The
/// caller (36-06's `CalendarSettingsScreen`) is expected to pass
/// `AppSettings.selectedCalendarIds` filtered to the `google:` prefix.
/// Defaults to `const []` so every existing caller (every test, and any
/// caller that hasn't opted in) is unaffected — same backward-compatible
/// shape as `googleAuth` itself.
CalendarSource iosCalendarSource({
  GoogleAuthClient? googleAuth,
  List<String> googleCalendarIds = const [],
}) {
  final device = DeviceCalendarSource();
  if (googleAuth == null) return device;
  return CompositeCalendarSource([
    GoogleCalendarSource(authClient: googleAuth, calendarIds: googleCalendarIds),
    device,
  ]);
}
