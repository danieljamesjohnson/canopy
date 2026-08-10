import 'package:flutter/material.dart';

/// Converts a hex color string (e.g. '#4CAF50') to a Flutter [Color].
Color hexToColor(String hex) {
  return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
}

/// Formats minutes-from-midnight as a 12-hour time string.
/// Example: 565 → "9:25 AM"
String formatMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  final suffix = h < 12 ? 'AM' : 'PM';
  final hour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '$hour:${m.toString().padLeft(2, '0')} $suffix';
}

/// Converts a [DateTime] to minutes-from-midnight in its own local
/// wall-clock time (never `.toUtc()`) — the same frame of reference
/// [formatMinutes] and [resolveNowState] already use, so a caller using
/// this helper can never silently disagree with either.
int minutesOfDay(DateTime dt) => dt.hour * 60 + dt.minute;

/// Formats a start–end time range as "START – END" (en-dash per UI-SPEC).
/// Example: formatTimeRange(565, 590) → "9:25 AM – 9:50 AM"
String formatTimeRange(int startMin, int endMin) {
  return '${formatMinutes(startMin)} – ${formatMinutes(endMin)}';
}

/// Formats a duration in minutes as a short "Nh Nm" string (D-05 free-time
/// copy, D-06 break duration). Omits the minute part when it is zero.
/// Examples: 5 → "5m", 60 → "1h", 100 → "1h 40m", 0 → "0m".
String formatDurationShort(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

/// Formats minutes-from-midnight as a compact 12-hour string for the 46dp
/// time gutter (D-04). Mirrors [formatMinutes]'s 12-hour conversion, but
/// drops the space and the AM suffix (PM keeps a single 'p') so the string
/// fits the narrow gutter column.
/// Examples: 480 → "8:00", 645 → "10:45", 780 → "1:00p", 720 → "12:00p",
/// 0 → "12:00", 1350 → "10:30p".
String formatMinutesCompact(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  final isPm = h >= 12;
  final hour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  final suffix = isPm ? 'p' : '';
  return '$hour:${m.toString().padLeft(2, '0')}$suffix';
}

/// Rounds minutes-from-midnight down to the whole hour at or before it.
/// Example: 545 → 480 (9:05 AM → 8:00 AM). Already-aligned values pass
/// through unchanged: 540 → 540, 0 → 0.
int floorToHour(int minutes) => (minutes ~/ 60) * 60;

/// Rounds minutes-from-midnight up to the whole hour at or after it.
/// Example: 545 → 600 (9:05 AM → 10:00 AM). Already-aligned values pass
/// through unchanged: 540 → 540, 0 → 0.
int ceilToHour(int minutes) => ((minutes + 59) ~/ 60) * 60;

/// Every whole-hour minute value in the inclusive range
/// `[rangeStart, rangeEnd]`, ascending.
/// Example: hourBoundariesIn(480, 600) → [480, 540, 600].
///
/// Starts from [floorToHour] of [rangeStart] but skips any boundary that
/// falls below [rangeStart], so a non-hour-aligned [rangeStart] still
/// yields only in-range boundaries: hourBoundariesIn(495, 600) → [540, 600].
/// Returns an empty list when `rangeEnd < rangeStart`.
List<int> hourBoundariesIn(int rangeStart, int rangeEnd) {
  if (rangeEnd < rangeStart) return [];
  final result = <int>[];
  for (var m = floorToHour(rangeStart); m <= rangeEnd; m += 60) {
    if (m >= rangeStart) result.add(m);
  }
  return result;
}

/// Formats minutes-from-midnight as an hour-and-meridiem-only label, no
/// minutes — the hour-axis's LOCKED copy (26-UI-SPEC.md "The time gutter
/// becomes an hour axis").
/// Examples: 540 → "9 AM", 720 → "12 PM", 0 → "12 AM", 1380 → "11 PM".
///
/// Reuses [formatMinutes]'s 12-hour conversion branch
/// (`h == 0 ? 12 : (h > 12 ? h - 12 : h)`) rather than writing a second one,
/// so the two can never disagree about noon/midnight.
String formatHourLabel(int minutes) {
  final h = minutes ~/ 60;
  final suffix = h < 12 ? 'AM' : 'PM';
  final hour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '$hour $suffix';
}
