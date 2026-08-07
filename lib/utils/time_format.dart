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
