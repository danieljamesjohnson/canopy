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
