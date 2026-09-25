import 'calendar_event.dart';

/// A pair of currently-selected calendars, one from each source, that
/// plausibly refer to the SAME underlying calendar (D-36-03's REQUIRED
/// mitigation for both iOS calendar sources coexisting). Reported so the
/// picker (plan 36-06) can warn about it — never merged, never dropped.
class CalendarOverlap {
  CalendarOverlap({required this.google, required this.device});

  /// The Google-sourced [CalendarInfo] half of the pair.
  final CalendarInfo google;

  /// The device-sourced [CalendarInfo] half of the pair.
  final CalendarInfo device;
}

/// A coarse fallback for when the narrow, per-row rule below cannot be
/// trusted to fire correctly — D-36-03's own instruction: "if reliable
/// matching turns out to be impossible, say so rather than shipping a
/// detector that misses... a detector that cries wolf is worse than none."
///
/// True when at least one currently-selected Google calendar and at least
/// one currently-selected device calendar exist at all — regardless of
/// whether any pair plausibly refers to the same underlying calendar. This
/// costs three lines and is what plan 36-06 needs to fall back to a single
/// general note on the picker instead of a per-row flag, if
/// [detectSelectedCalendarOverlaps]'s narrower rule is judged unreliable
/// against a real device (see this file's own findings, recorded in
/// 36-05-SUMMARY.md).
bool hasCrossSourceSelection({
  required List<CalendarInfo> calendars,
  required Set<String> selectedIds,
}) {
  final selected = calendars.where((c) => selectedIds.contains(c.id));
  final hasGoogle = selected.any((c) => c.sourceLabel == 'Google');
  final hasDevice = selected.any((c) => c.sourceLabel == 'This device');
  return hasGoogle && hasDevice;
}

/// Detects when a calendar ticked under the Google source plausibly refers
/// to the SAME underlying calendar as one ticked under the device source
/// (D-36-03's REQUIRED mitigation). Only [CalendarInfo]s identified by
/// [CalendarInfo.sourceLabel] as `'Google'` or `'This device'` — the exact
/// strings `google_calendar_source.dart` and `device_calendar_source.dart`
/// stamp on every calendar they return — participate; anything else is
/// ignored (overlap is a cross-source concept, T-36-21).
///
/// **The matching rule is deliberately narrow, and the narrowness is the
/// design:** a pair is reported only when ALL of the following hold —
/// - [CalendarInfo.accountName] is non-null on both sides and matches
///   exactly.
/// - [CalendarInfo.name] matches case-insensitively once trimmed of
///   surrounding whitespace.
/// - Both calendars are present in [selectedIds].
///
/// D-36-03 is explicit that a detector that cries wolf is worse than none:
/// an account-only match would flag every one of a Google account's
/// calendars against every other one, which would train the owner to
/// ignore the warning within a day (this exact widening is this file's
/// mandatory first mutation proof, recorded in 36-05-SUMMARY.md).
///
/// **This function only reports. It never de-duplicates, filters, or
/// reorders [calendars] or [selectedIds].** D-36-03: quietly dropping one
/// side of a double-tick would contradict the ruling and hide a state the
/// user deliberately created. There is no variant of this function that
/// returns a filtered selection — a later plan wanting one is a
/// conversation with the owner, not a refactor.
List<CalendarOverlap> detectSelectedCalendarOverlaps({
  required List<CalendarInfo> calendars,
  required Set<String> selectedIds,
}) {
  final selected = calendars.where((c) => selectedIds.contains(c.id));
  final googleCalendars = selected.where((c) => c.sourceLabel == 'Google');
  final deviceCalendars = selected.where(
    (c) => c.sourceLabel == 'This device',
  );

  final overlaps = <CalendarOverlap>[];
  for (final google in googleCalendars) {
    final googleAccount = google.accountName;
    if (googleAccount == null) continue;
    for (final device in deviceCalendars) {
      final deviceAccount = device.accountName;
      // A local, account-less device calendar (accountName == null) can
      // never overlap with anything — never throws, per this function's
      // own behavior contract.
      if (deviceAccount == null) continue;
      if (googleAccount != deviceAccount) continue;
      if (google.name.trim().toLowerCase() !=
          device.name.trim().toLowerCase()) {
        continue;
      }
      overlaps.add(CalendarOverlap(google: google, device: device));
    }
  }
  return overlaps;
}
