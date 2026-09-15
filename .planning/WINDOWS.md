---
schema_version: 1
open_count: 1
waived_count: 0
fixed_count: 1
total_count: 2
last_updated: 2026-09-15T13:14:18.617Z
---

# Broken Windows Ledger

> Cross-phase defect register. With `workflow.windows_enforce` enabled, `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 35 | stub | lib/data/calendar/ics_calendar_source.dart |  | EXDATE/RDATE/RECURRENCE-ID overrides not implemented — a moved/cancelled single occurrence of a recurring event still appears at its original time | open |  | 2026-09-14T13:15:25.420Z |  |
| 2 | 35 | stub | lib/data/calendar/ics_calendar_source.dart |  | DTSTART without a Z suffix (floating time, or bare TZID with no VTIMEZONE block) is parsed via Dart's system-local DateTime constructor, not the app's tz.local override — only Z-suffixed UTC timestamps are proven correct by this plan's test | fixed |  | 2026-09-14T13:15:28.640Z | 2026-09-15T13:14:18.617Z |

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
    "resolved_at": "2026-09-15T13:14:18.617Z"
  }
]
````
