---
schema_version: 1
open_count: 5
waived_count: 1
fixed_count: 5
total_count: 11
last_updated: 2026-10-06T00:00:00.000Z
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
| 6 | 36 | deviation | lib/screens/settings/calendar_settings_screen.dart |  | Re-opening the Calendars screen always shows the "Connect Google Calendar" CTA even when a valid token is stored -- only reconnectNeeded (a dead token) is read from persisted state, never a valid-but-unconfirmed connection. Tapping re-launches real consent and re-issues a token rather than failing, so this is UX friction, not wrong data. Mirrors the device flow's identical pre-existing limitation (_mobileFuture also resets on re-open). Fixing it needs a new SettingsNotifier.googleConnected getter, outside 36-06's declared scope. LOGGED BY THE ORCHESTRATOR, not 36-06, which reasoned it was carried-by-design and left it in its SUMMARY's Known Stubs only: it is recorded here because 36-07's UAT script must tell the owner this is expected, or a reasonable person will report it as a bug at the device gate. FIXED by plan 36-10: SettingsNotifier.googleConnected getter added; _loadGoogleCalendars restores the connected view from a valid stored token without ever calling requestPermission() (call-count-proven, not just inspected). CALAUTH-03's dead-token-wins ordering is unchanged. Device confirmation is 36-UAT-R2.md item R4. | fixed |  | 2026-09-25T16:20:00.000Z | 2026-10-06T00:00:00.000Z |
| 7 | 36 | bug | lib/services/calendar_sync_service.dart |  | CAL-02 VIOLATED on the device path: sync() always calls listEvents(calendarIds: const []), and iosCalendarSource() builds DeviceCalendarSource() with no ids, so device_calendar_plus resolves empty to "every calendar". The user's ticks are persisted and rendered but NEVER reach the device source. Google's half WAS wired (entry 5); the device half never was. PROVEN on the owner's iPhone 2026-10-06: selectedCalendarIds held exactly one id (CF8A6881-...) while imported commitments carried at least four different calendar ids incl. a holidays and a birthdays calendar. Undetectable before now because the device path is iOS-only and 35-05's gate was open. STAYS OPEN DESPITE A CODE FIX (plan 36-08): the app-side wiring is now mutation-proven correct up to the plugin boundary -- the exact ticked id list reaches the exact point device_calendar_plus is called, through the real sync() path. What remains unproven, and cannot be proven on danserver (no Xcode, no device), is whether device_calendar_plus itself honours a non-empty calendarIds argument on real iOS hardware rather than ignoring it. Marking this fixed on a host test alone would be exactly the overclaim this project's CLAUDE.md exists to prevent. Closes only when 36-UAT-R2.md item R1 is observed on the owner's real iPhone. | open |  | 2026-10-06T00:00:00.000Z |  |
| 8 | 36 | bug | lib/services/calendar_sync_service.dart |  | All-day events import as blocking 08:00-22:00. Observed on device: Columbus Day, Indigenous Peoples' Day, a 38th Birthday, Vacation, Fall break, Payday -- SIX working days erased in a 12-day window. NOT a duplicate of entry 7 and NOT fixed by fixing it: a legitimately-ticked calendar still contains birthdays, and Payday lands regardless. **THE TARGET BEHAVIOUR IS SETTLED — D-36-05 (ruled 2026-10-06) REVISES D-35-06: all-day events are SKIPPED and disclosed, never imported.** Read 36-DECISIONS.md D-36-05 before planning; it names the required code changes, the now-wrong SkipReason doc comment, the new UI-SPEC copy string, that schedule_generator must NOT be touched, and the open question of whether already-persisted all-day blocks on the owner's device get pruned by a sync that no longer imports them. Do NOT re-ask the owner and do NOT plan work on D-35-06's 10-vs-14-hour span question, which D-36-05 closes by removing the behaviour. FIXED by plan 36-09: SkipReason.allDay added, the all-day branch returns (blocks: const [], skip: SkipReason.allDay) instead of a blocking window, and a one-time schema 12->13 migration purges every already-persisted isFromCalendar==true block so the six fake blocks don't survive the upgrade. schedule_generator.dart confirmed byte-identical (empty git diff). Device confirmation is 36-UAT-R2.md item R2. | fixed |  | 2026-10-06T00:00:00.000Z | 2026-10-06T00:00:00.000Z |
| 9 | 36 | bug | lib/data/calendar/device_calendar_source.dart |  | WITHDRAWN 2026-10-06 — FALSE ALARM, see reason. Original report: A moved single occurrence of a recurring event ("this event only") does NOT appear at all on the device path -- not at its new time, not at its original. Reported by the owner on device 2026-10-06. If confirmed (pending: was it still inside 08:00-22:00 and on the same day), this DISPROVES Phase 35 Assumption A1 and REVERSES 36-DECISIONS.md's "Correction on the record": the Google path would then be worth materially MORE than stated, not neutral. Worse than the known .ics defect, which duplicates rather than drops. | waived | FALSE ALARM. Read the device Hive directly: "Canopy test" imported TWICE — 2026-10-06 09:00-10:00 (base) and 2026-10-13 09:10-10:10 (the MOVED occurrence, at its NEW time). It was absent from Today only because Today shows today; the moved one is next week. This VERIFIES Phase 35 Assumption A1 on real hardware and CONFIRMS 36-DECISIONS.md\'s Correction on the record rather than reversing it. | 2026-10-06T00:00:00.000Z |  |
| 10 | 36 | todo | lib/screens/settings/calendar_settings_screen.dart |  | The skipped-events disclosure ("N events were not imported") exists and is tested, but the owner did not notice it on device and asked for "a reminder at the top". Not missing -- not discoverable. Prominence/placement issue raised from real use. FIXED (code) by plan 36-09: _skippedBanner extracted and promoted to the first child of both the mobile and desktop screen bodies, rendered above both calendar sections, geometrically proven (not widget order). Marked fixed here on the strength of that geometric proof; the underlying question is perceptual ("did the owner actually notice it this time"), which no widget test can answer by itself -- 36-UAT-R2.md item R3 is where that judgment lands, consistent with this project's own precedent for perceptual claims (D-36-03's overlap warning). | fixed |  | 2026-10-06T00:00:00.000Z | 2026-10-06T00:00:00.000Z |
| 11 | 36 | bug | lib/services/calendar_sync_service.dart |  | sync() only ever upserts -- it never deletes a CommitmentBlock whose source event has gone, so unticking a calendar or deleting an event in the calendar app leaves the already-imported block on the schedule permanently. Found while reading calendar_sync_service.dart during plan 36-09, deliberately NOT fixed in this gap closure. Three pieces of evidence: (1) sync() (lines ~149-176) calls _repository.getAll() and only ever _repository.save(block) -- no delete call anywhere in the method or in _mapEvent; (2) grep -rn '.delete(' lib/ returns exactly four call sites outside migrations.dart's own one-time purge -- restoratives_notifier, schedule_notifier (x2, re-anchoring), and the user-initiated commitments_notifier.removeBlock -- none in the calendar path; (3) calendar_settings_screen.dart's _disconnectGoogle doc comment already says so in so many words ("that sentence is not true today; sync() only ever upserts"). 35-UI-SPEC.md's LOCKED "Remove this calendar?" dialog body (line ~165) tells the user the opposite -- "Commitments already imported from it will disappear the next time you sync" -- so the shipped copy is currently false. Plan 36-09's one-time schema 12->13 cleanup does NOT fix this and was never meant to: it discards the pre-fix imported set once; this defect is about every sync afterward. Not fixed here because a general window-scoped prune is unsafe while CompositeCalendarSource swallows a per-child failure and returns a partial event list with no error signal -- pruning against that partial list would delete a healthy source's blocks on a transient network blip, a worse defect than the one being fixed. That design problem is a phase, not gap closure. | open |  | 2026-10-06T00:00:00.000Z |  |

````json
[
  {
    "id": 1,
    "kind": "stub",
    "phase": "35",
    "file": "lib/data/calendar/ics_calendar_source.dart",
    "line": null,
    "description": "EXDATE/RDATE/RECURRENCE-ID overrides not implemented \u2014 a moved/cancelled single occurrence of a recurring event still appears at its original time",
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
    "description": "DTSTART without a Z suffix (floating time, or bare TZID with no VTIMEZONE block) is parsed via Dart's system-local DateTime constructor, not the app's tz.local override \u2014 only Z-suffixed UTC timestamps are proven correct by this plan's test",
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
  },
  {
    "id": 6,
    "kind": "deviation",
    "phase": "36",
    "file": "lib/screens/settings/calendar_settings_screen.dart",
    "line": null,
    "description": "Re-opening the Calendars screen always shows the Connect Google Calendar CTA even when a valid token is stored -- only reconnectNeeded (a dead token) is read from persisted state. Tapping re-launches real consent and re-issues a token rather than failing, so this is UX friction, not wrong data. Fixing it needs a new SettingsNotifier.googleConnected getter, outside 36-06's declared scope. FIXED by plan 36-10: SettingsNotifier.googleConnected getter added; _loadGoogleCalendars restores the connected view from a valid stored token without ever calling requestPermission() (call-count-proven). CALAUTH-03's dead-token-wins ordering is unchanged. Device confirmation is 36-UAT-R2.md item R4.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-09-25T16:20:00.000Z",
    "resolved_at": "2026-10-06T00:00:00.000Z"
  },
  {
    "id": 7,
    "kind": "bug",
    "phase": "36",
    "file": "lib/services/calendar_sync_service.dart",
    "line": null,
    "description": "CAL-02 VIOLATED on the device path: sync() always calls listEvents(calendarIds: const []), and iosCalendarSource() builds DeviceCalendarSource() with no ids, so device_calendar_plus resolves empty to \"every calendar\". The user's ticks are persisted and rendered but NEVER reach the device source. Google's half WAS wired (entry 5); the device half never was. PROVEN on the owner's iPhone 2026-10-06 from its own Hive: selectedCalendarIds held exactly one id while imported commitments carried at least four different calendar ids incl. holidays and birthdays calendars. STAYS OPEN DESPITE A CODE FIX (plan 36-08): the wiring is mutation-proven correct up to the plugin boundary -- the exact ticked id list reaches the exact point device_calendar_plus is called, through the real sync() path. Whether device_calendar_plus itself honours a non-empty calendarIds argument on real iOS hardware is unproven and cannot be proven on danserver (no Xcode, no device). Marking this fixed on a host test alone would be exactly the overclaim this project's CLAUDE.md exists to prevent. Closes only when 36-UAT-R2.md item R1 is observed on the owner's real iPhone.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-10-06T00:00:00.000Z",
    "resolved_at": null
  },
  {
    "id": 8,
    "kind": "bug",
    "phase": "36",
    "file": "lib/services/calendar_sync_service.dart",
    "line": null,
    "description": "All-day events import as blocking 08:00-22:00. Observed on device: Columbus Day, Indigenous Peoples' Day, a 38th Birthday, Vacation, Fall break, Payday -- SIX working days erased in a 12-day window. NOT a duplicate of entry 7 and NOT fixed by fixing it: a legitimately-ticked calendar still contains birthdays, and Payday lands regardless. THE TARGET BEHAVIOUR IS SETTLED -- D-36-05 (ruled 2026-10-06) REVISES D-35-06: all-day events are SKIPPED and disclosed, never imported. Read 36-DECISIONS.md D-36-05 before planning; it names the required code changes, the now-wrong SkipReason doc comment, the new UI-SPEC copy string, that schedule_generator must NOT be touched, and the open question of whether already-persisted all-day blocks on the owner's device get pruned by a sync that no longer imports them. Do NOT re-ask the owner and do NOT plan work on D-35-06's 10-vs-14-hour span question, which D-36-05 closes by removing the behaviour. FIXED by plan 36-09: SkipReason.allDay added, the all-day branch returns (blocks: const [], skip: SkipReason.allDay) instead of a blocking window, and a one-time schema 12->13 migration purges every already-persisted isFromCalendar==true block so the six fake blocks don't survive the upgrade. schedule_generator.dart confirmed byte-identical (empty git diff). Device confirmation is 36-UAT-R2.md item R2.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-10-06T00:00:00.000Z",
    "resolved_at": "2026-10-06T00:00:00.000Z"
  },
  {
    "id": 9,
    "kind": "bug",
    "phase": "36",
    "file": "lib/data/calendar/device_calendar_source.dart",
    "line": null,
    "description": "A moved single occurrence of a recurring event (\"this event only\") does NOT appear at all on the device path -- not at its new time, not at its original. Owner-reported on device 2026-10-06. PENDING one check (was it still inside 08:00-22:00 and on the same day). If confirmed this DISPROVES Phase 35 Assumption A1 and REVERSES 36-DECISIONS.md's Correction on the record: the Google path would be worth materially MORE than stated. Worse than the known .ics defect, which duplicates rather than drops.",
    "status": "waived",
    "reason": "FALSE ALARM, verified 2026-10-06 by reading the device Hive directly: \"Canopy test\" imported twice \u2014 2026-10-06 09:00 (base) and 2026-10-13 09:10 (moved occurrence at its NEW time). Absent from Today only because Today shows today. VERIFIES Assumption A1 and CONFIRMS the Correction on the record.",
    "recorded_at": "2026-10-06T00:00:00.000Z",
    "resolved_at": "2026-10-06T00:00:00.000Z"
  },
  {
    "id": 10,
    "kind": "todo",
    "phase": "36",
    "file": "lib/screens/settings/calendar_settings_screen.dart",
    "line": null,
    "description": "The skipped-events disclosure exists and is tested, but the owner did not notice it on device and asked for a reminder at the top. Not missing -- not discoverable. Prominence issue raised from real use. FIXED (code) by plan 36-09: _skippedBanner promoted to the first child of both the mobile and desktop screen bodies, rendered above both calendar sections, geometrically proven. Marked fixed on that geometric proof; the underlying question is perceptual and lands at 36-UAT-R2.md item R3.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-10-06T00:00:00.000Z",
    "resolved_at": "2026-10-06T00:00:00.000Z"
  },
  {
    "id": 11,
    "kind": "bug",
    "phase": "36",
    "file": "lib/services/calendar_sync_service.dart",
    "line": null,
    "description": "sync() only ever upserts -- it never deletes a CommitmentBlock whose source event has gone, so unticking a calendar or deleting an event in the calendar app leaves the already-imported block on the schedule permanently. Found while reading calendar_sync_service.dart during plan 36-09, deliberately NOT fixed in this gap closure. Three pieces of evidence: (1) sync() calls _repository.getAll() and only ever _repository.save(block) -- no delete call anywhere in the method or in _mapEvent; (2) grep -rn '.delete(' lib/ returns exactly four call sites outside migrations.dart's own one-time purge -- restoratives_notifier, schedule_notifier (x2, re-anchoring), and the user-initiated commitments_notifier.removeBlock -- none in the calendar path; (3) calendar_settings_screen.dart's _disconnectGoogle doc comment already admits it (\"that sentence is not true today; sync() only ever upserts\"). 35-UI-SPEC.md's LOCKED \"Remove this calendar?\" dialog body tells the user the opposite -- commitments will disappear the next time you sync -- so the shipped copy is currently false. Plan 36-09's one-time schema 12->13 cleanup does NOT fix this: it discards the pre-fix imported set once; this defect is about every sync afterward. Not fixed here because a general window-scoped prune is unsafe while CompositeCalendarSource swallows a per-child failure and returns a partial event list with no error signal -- pruning against that would delete a healthy source's blocks on a transient network blip, a worse defect than the one being fixed. That design problem is a phase, not gap closure.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-10-06T00:00:00.000Z",
    "resolved_at": null
  }
]
````
