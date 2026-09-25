---
schema_version: 1
open_count: 3
waived_count: 0
fixed_count: 2
total_count: 5
last_updated: 2026-09-25T16:05:44.417Z
---

# Broken Windows Ledger

> Cross-phase defect register. With `workflow.windows_enforce` enabled, `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 35 | stub | lib/data/calendar/ics_calendar_source.dart |  | EXDATE/RDATE/RECURRENCE-ID overrides not implemented — a moved/cancelled single occurrence of a recurring event still appears at its original time | open |  | 2026-09-14T13:15:25.420Z |  |
| 2 | 35 | stub | lib/data/calendar/ics_calendar_source.dart |  | DTSTART without a Z suffix (floating time, or bare TZID with no VTIMEZONE block) is parsed via Dart's system-local DateTime constructor, not the app's tz.local override — only Z-suffixed UTC timestamps are proven correct by this plan's test | fixed |  | 2026-09-14T13:15:28.640Z | 2026-09-15T13:33:05.131Z |
| 3 | 35 | deviation | lib/data/models/app_settings.dart |  | Pre-existing non-nullable bool/int HiveFields (eveningReminderEnabled/eveningReminderMinutes, fields 7/8) have no defaultValue and generate a straight cast with no null-coalescing -- a genuinely old record missing those fields would throw on read, same defect class fixed in 35-03 for the new List<String> fields. Out of scope for 35-03 (pre-existing, not caused by this task); not fixed. | open |  | 2026-09-15T13:05:57.449Z |  |
| 4 | 36 | deviation | lib/data/calendar/google_calendar_source.dart |  | 36-02 deferred connect()'s three-valued outcome enum (cancelled/connected/failed) to avoid touching 36-03's exclusive file in this wave; bool contract fully covers Task 2 behaviors. 36-06 should introduce the enum when it wires the settings screen. | open |  | 2026-09-25T15:03:20.080Z |  |
| 5 | 36 | stub | lib/data/calendar/calendar_source_factory.dart |  | GoogleCalendarSource is constructed in iosCalendarSource() with calendarIds: const [] -- listCalendars() works (full Google account visible to the picker) but listEvents() returns zero Google events until 36-06 wires AppSettings.selectedCalendarIds (filtered to the google: prefix) into this constructor. | fixed |  | 2026-09-25T15:23:21.055Z | 2026-09-25T16:05:44.417Z |
| 6 | 36 | deviation | lib/screens/settings/calendar_settings_screen.dart |  | Re-opening the Calendars screen always shows the "Connect Google Calendar" CTA even when a valid token is stored -- only reconnectNeeded (a dead token) is read from persisted state, never a valid-but-unconfirmed connection. Tapping re-launches real consent and re-issues a token rather than failing, so this is UX friction, not wrong data. Mirrors the device flow's identical pre-existing limitation (_mobileFuture also resets on re-open). Fixing it needs a new SettingsNotifier.googleConnected getter, outside 36-06's declared scope. LOGGED BY THE ORCHESTRATOR, not 36-06, which reasoned it was carried-by-design and left it in its SUMMARY's Known Stubs only: it is recorded here because 36-07's UAT script must tell the owner this is expected, or a reasonable person will report it as a bug at the device gate. | open |  | 2026-09-25T16:20:00.000Z |  |

````json
[
  {
    "id": 1,
    "kind": "stub",
    "phase": "35",
    "file": "lib/data/calendar/ics_calendar_source.dart",
    "line": null,
    "description": "EXDATE/RDATE/RECURRENCE-ID overrides not implemented — a moved/cancelled single occurrence of a recurring event still appears at its original time",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-14T13:15:25.420Z",
    "resolved_at": null
  },
  {
    "id": 2,
    "kind": "stub",
    "phase": "35",
    "file": "lib/data/calendar/ics_calendar_source.dart",
    "line": null,
    "description": "DTSTART without a Z suffix (floating time, or bare TZID with no VTIMEZONE block) is parsed via Dart's system-local DateTime constructor, not the app's tz.local override — only Z-suffixed UTC timestamps are proven correct by this plan's test",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-09-14T13:15:28.640Z",
    "resolved_at": "2026-09-15T13:33:05.131Z"
  },
  {
    "id": 3,
    "kind": "deviation",
    "phase": "35",
    "file": "lib/data/models/app_settings.dart",
    "line": null,
    "description": "Pre-existing non-nullable bool/int HiveFields (eveningReminderEnabled/eveningReminderMinutes, fields 7/8) have no defaultValue and generate a straight cast with no null-coalescing -- a genuinely old record missing those fields would throw on read, same defect class fixed in 35-03 for the new List<String> fields. Out of scope for 35-03 (pre-existing, not caused by this task); not fixed.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-15T13:05:57.449Z",
    "resolved_at": null
  },
  {
    "id": 4,
    "kind": "deviation",
    "phase": "36",
    "file": "lib/data/calendar/google_calendar_source.dart",
    "line": null,
    "description": "36-02 deferred connect()'s three-valued outcome enum (cancelled/connected/failed) to avoid touching 36-03's exclusive file in this wave; bool contract fully covers Task 2 behaviors. 36-06 should introduce the enum when it wires the settings screen.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-25T15:03:20.080Z",
    "resolved_at": null
  },
  {
    "id": 5,
    "kind": "stub",
    "phase": "36",
    "file": "lib/data/calendar/calendar_source_factory.dart",
    "line": null,
    "description": "GoogleCalendarSource is constructed in iosCalendarSource() with calendarIds: const [] -- listCalendars() works (full Google account visible to the picker) but listEvents() returns zero Google events until 36-06 wires AppSettings.selectedCalendarIds (filtered to the google: prefix) into this constructor.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-09-25T15:23:21.055Z",
    "resolved_at": "2026-09-25T16:05:44.417Z"
  }
]
````
