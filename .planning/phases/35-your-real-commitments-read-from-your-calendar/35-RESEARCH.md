# Phase 35: Your Real Commitments, Read From Your Calendar - Research

**Researched:** 2026-09-11
**Domain:** Flutter cross-platform calendar integration (EventKit/CalendarContract via plugin, ICS parsing, permissions, read-only sync into an existing local-first data model)
**Confidence:** MEDIUM — the architecture and mapping design are grounded in code read this session; the device plugin's runtime recurrence-exception behavior is CITED from its docs, not executed (no Android/iOS build capability on danserver — see Environment Availability).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

1. **The platform-agnostic layer is OURS, not a plugin's.** No plugin covers macOS, Windows, Linux
   or web, and no browser calendar API exists or is coming. The abstraction goes where this codebase
   already puts abstractions — an interface with swappable implementations, exactly as
   `lib/data/repositories/` does with its `hive_*` / `in_memory_*` pair:

   ```
   CalendarSource            interface — the only thing the app talks to
   ├── DeviceCalendarSource  plugin-backed; iOS + Android
   ├── IcsCalendarSource     .ics URL subscription; works EVERYWHERE incl. web + desktop
   └── NullCalendarSource    platforms with neither — the app degrades, never breaks
   ```

2. **Do NOT write our own plugin.** A federated Flutter plugin means maintaining Swift *and* Kotlin
   *and* a platform-interface package indefinitely, and after all that it still would not cover web
   or desktop — so it does not buy the agnosticism that motivated the question.

3. **Plugin choice: `device_calendar_plus`, to be confirmed in research.** `device_calendar` is
   effectively abandoned (23 months, 118 open issues); `eventide` has recurrence **not implemented**,
   which is disqualifying because recurring meetings are the commitments that matter most.
   **CONFIRMED this session — see Package Legitimacy Audit and Common Pitfall 1.**

4. **One device integration covers both vendors.** EventKit and CalendarContract read the *device's
   calendar store*, which already aggregates every account the user has added. Google needs no OAuth
   and no separate integration, **provided the account is added at OS level**.

   **Do not ask the owner whether his Google account is added — show him.** The settings surface
   lists whatever calendars the device actually exposes, with checkboxes. If Google is there he ticks
   it; if not, that is an OS Settings fix, not a code path.

### A scope boundary was deliberately MOVED — do not refuse on it

`PROJECT.md` listed calendar sync as out of scope / v2. The owner promoted it to v1 on 2026-09-11:
*"it needs to be able to read from apple calendar and google calendar. as a v1."* Do not "helpfully"
decline to build this on the strength of a boundary that has been consciously moved. It does **not**
reopen the AI boundary — a calendar is deterministic input to the same rule-based engine.

### Claude's Discretion

Everything not fixed above is an implementation choice, guided by the ROADMAP success criteria and
this codebase's conventions. Discuss was skipped per `workflow.skip_discuss`. This research makes
concrete recommendations for all four originally-open questions (recurrence verification depth,
event→CommitmentBlock mapping, editability, sync trigger) — see the relevant sections below.

### Deferred Ideas (OUT OF SCOPE)

- **Writing to the user's calendar** — permanently out of scope, by product guarantee (CAL-03).
- **Google Calendar API / OAuth as a separate integration** — unnecessary, as long as the account is
  added at OS level.
- **`com.example.canopy` bundle identifier** — noted in the ROADMAP as out of scope for this phase.
- **A federated first-party Flutter plugin** — considered and rejected.
- **Overnight / midnight-crossing commitments** — pre-existing, cross-cutting scope boundary (not
  specific to this phase; see Common Pitfall 4). Do not slip a fix in as part of calendar mapping.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CAL-01 | Commitments can be imported from the device's calendar without retyping | `DeviceCalendarSource` design (Architecture Patterns §1), `device_calendar_plus.listEvents()` verified against docs (Common Pitfall 1), event→`CommitmentBlock` mapping table (§Event Mapping) |
| CAL-02 | The user chooses which calendars feed the schedule, from the list the device actually exposes | `Calendar` class fields confirmed (`id`, `name`, `accountName`, `accountType`, `color`, `readOnly`) — see Code Examples §Listing Calendars; settings persistence pattern (`AppSettings` HiveField 9, next free) |
| CAL-03 | Canopy never writes to the user's calendar | Architecture Patterns §1 (read-only call surface: only `listCalendars`/`listSources`/`listEvents`/`requestPermissions` are ever called — `createCalendar`/`updateCalendar`/`deleteCalendar`/any event-write method is never called); manifest omits `WRITE_CALENDAR` (Permissions §Android) |
| CAL-04 | A platform with no calendar access, or a denied permission, still gives a fully usable app with hand-entered commitments | `NullCalendarSource` design; `CalendarPermissionStatus` enum confirmed (Common Pitfall 1); Environment Availability (Android/iOS cannot even be *built* on danserver, which is itself evidence this path must degrade honestly since it can never be exercised here) |
</phase_requirements>

## Summary

This is an input-layer phase: a new `CalendarSource` abstraction (three implementations) produces
`CommitmentBlock` records that `schedule_generator.dart` already knows how to consume unchanged. The
codebase read this session confirms every locked architectural decision is sound and gives concrete
seams to build against: `CommitmentBlock` (`lib/data/models/commitment_block.dart`) has two free Hive
fields to add provenance/idempotency tracking; `CommitmentsNotifier` and its `saveBlock`/`loadBlocks`
pair is the existing write path a sync service should reuse; and the check-in screen
(`checkin_screen.dart:127-132`) is the one call site that reads `CommitmentsNotifier.blocks` before
generating a day, making it the natural, already-existing sync trigger point.

`device_calendar_plus` is confirmed as the right plugin choice: its published API (pub.dev docs,
version 0.8.0, 50 days old at research time) exposes full RRULE with a typed `RecurrenceRule` model,
three-tier recurrence-edit granularity (series / this-and-following / single occurrence), and —
most importantly for the "load-bearing" recurrence question — a `listEvents(start, end)` call that
returns **already-expanded per-occurrence instances** (each with a unique `instanceId`), which means
the native OS calendar provider (EventKit/CalendarContract), not this app or the plugin, is what
resolves recurrence exceptions. This is a significant simplification: **`CommitmentBlock` should
never be asked to represent a recurring calendar event as a recurring `CommitmentBlock`.** Instead,
every imported calendar event — recurring or not — becomes a one-off `CommitmentBlock` (the existing
`date`-anchored mode), one per occurrence, re-materialized on every sync. `CommitmentBlock`'s own
native weekly recurrence (`daysOfWeek`) stays exactly what it is today: the user's own hand-entered
stable-week commitments, never touched by the importer.

This claim (native instance expansion resolves exceptions) is **CITED from documentation, not
executed** — device builds are impossible on danserver (no Android SDK, no Xcode; see Environment
Availability). It must be the first thing verified on a real device before the rest of the phase is
trusted, and the plan should say so explicitly rather than assume it.

For web/desktop, the equivalent is `IcsCalendarSource` parsing a subscribed `.ics` URL. No Dart ICS
package is both well-adopted and confirmed to expand `RRULE`/`EXDATE`/`RECURRENCE-ID` correctly;
`firstfloor_calendar` is the strongest technical candidate (pure Dart, full RRULE expansion via
`occurrences()`, actively released) but has very low adoption (2 GitHub stars, 52 weekly downloads)
and its GitHub repository silently moved owners between what pub.dev's metadata records and what
`api.github.com` now resolves to — worth a checkpoint before committing to it, not a hard blocker.

**A verified, load-bearing correction to the existing codebase belongs in this phase's scope:**
`CommitmentBlock`'s own doc comments claim `startMinutes`/`endMinutes` are "minutes from midnight
UTC," but the code that actually writes those fields (`commitment_form_sheet.dart`) uses
`showTimePicker`, which returns device-local wall-clock time, with no UTC conversion anywhere. The
comment is wrong; the field is local wall-clock minutes, exactly like every other time-of-day field
in this app. This matters acutely here because calendar events carry real timezone information
(`Event.timeZone`), and converting them to **local**, not UTC, minutes-from-midnight is the one
correctness requirement this phase cannot get wrong — this is the SEED-006 failure shape again
(a time-of-day normalization bug that a UTC-only or midnight-only test fixture would not catch).

**Primary recommendation:** Build `CalendarSource` as the interface, `device_calendar_plus` behind
`DeviceCalendarSource`, a to-be-selected pure-Dart ICS package behind `IcsCalendarSource`, and
`NullCalendarSource` as the always-safe fallback. Sync at check-in (blocking, since `generateToday`
needs fresh blocks) with a best-effort refresh on app resume; surface last-synced staleness visibly.
Import every calendar occurrence as a one-off, read-only-tagged `CommitmentBlock`; never write RRULE
recurrence into `CommitmentBlock`. Verify recurrence-exception behavior on a real device as the very
first task of the device-source wave, before building anything downstream of it.

## Architectural Responsibility Map

This app has no browser/server tiers in the conventional web sense — it is a Flutter client with a
device/OS layer beneath it. The table below adapts the canonical tiers to this codebase's actual
layers (`lib/data`, `lib/providers`, `lib/services`, `lib/screens`) plus the external OS/device layer
the new calendar work introduces.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Reading device calendar events (iOS/Android) | Device/OS native layer (EventKit/CalendarContract, reached via `device_calendar_plus`) | `lib/data` (new `DeviceCalendarSource`) | The OS owns the calendar store and all recurrence-exception resolution; the plugin is a thin bridge, not where logic lives |
| Parsing subscribed `.ics` feeds (web/desktop/macOS/Linux/Windows) | `lib/data` (new `IcsCalendarSource` + ICS parser package) | — | No OS calendar store to read on these platforms; parsing happens entirely in-app |
| `CalendarSource` abstraction itself | `lib/data` (interface + 3 implementations, alongside the existing repository pattern) | — | Matches the existing `lib/data/repositories/` precedent exactly |
| Mapping a calendar `Event` → `CommitmentBlock` | `lib/services` (new `CalendarSyncService`, peer to `schedule_generator.dart`/`export_service.dart`) | — | Pure transformation logic, same tier as the app's other domain services |
| Persisting imported `CommitmentBlock`s | `lib/data` (existing Hive `commitment_blocks` box, unchanged shape + 1-2 additive fields) | — | Reuses the existing repository, no new box |
| Choosing which calendars feed the schedule (CAL-02) | `lib/providers` (new notifier or extension of `SettingsNotifier`) + `lib/screens/settings` (UI) | `lib/data` (persisted selection in `AppSettings`, next free `HiveField(9)`) | Mirrors every other user-facing toggle in this app |
| Triggering a sync | `lib/providers` (`CommitmentsNotifier` or a new sync notifier), called from `lib/screens/schedule/checkin_screen.dart` | `lib/screens/today/today_screen.dart` (resume hook, best-effort) | The check-in screen is the one existing call site that reads `CommitmentsNotifier.blocks` before generating a day |
| Chunking commitments into the day's 25+5 lattice | `lib/services/schedule_generator.dart` — **UNCHANGED** | — | Explicitly out of bounds per ROADMAP/CONTEXT; `CommitmentBlock` is already the correct input shape |
| Permission requests / denial handling | Device/OS native layer (system dialog via plugin) | `lib/screens/settings` (CAL-04 degrade messaging) | The OS owns the dialog; the app owns explaining what a denial means |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `device_calendar_plus` | 0.8.0 (published 2026-07-23, ~50 days old at research time) `[CITED: pub.dev/packages/device_calendar_plus]` | iOS (EventKit) + Android (CalendarContract) read access, permissions, calendar listing | Maintained replacement for the abandoned `device_calendar`; full RRULE typed model; verified publisher `bullet.to`; only viable candidate with implemented recurrence (see Common Pitfall 1 and Package Legitimacy Audit) |

### Supporting — ICS (web/desktop `IcsCalendarSource`), NOT YET LOCKED

No single ICS package is both well-adopted and confirmed on recurrence exceptions. Candidates,
ranked, all `[CITED: pub.dev]` for the metadata and `[ASSUMED]` for exception-handling correctness
(none of the three has an evidenced test/example of `EXDATE`/`RECURRENCE-ID` handling — see Common
Pitfall 2):

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `firstfloor_calendar` | 1.0.14 (2026-07-15, ~58 days old) | RFC 5545 parser, pure Dart, `occurrences()` lazy RRULE+RDATE expansion | Strongest technical fit — full RFC 5545, actively released (15 versions since 2025-10-15) — **but see legitimacy flag below before committing** |
| `enough_icalendar` | 0.17.0 (2025-08-19, ~13 months old) | RFC 5545 **and** RFC 5546 (iTIP) compliant parser, pure Dart | Larger/older, more established (9 likes vs. 5), but staler and recurrence-expansion API is not confirmed to exist (only rule *parsing*, not occurrence generation, was found in docs) |
| `icalendar_parser` | 2.1.0 (published ~24 months ago) | Basic ICS field parser | **Do not use** — stale (2 years unreleased), and RRULE support is "listed" not confirmed to expand |

An ICS package choice does not need to be locked by research; it needs a spike. See Package
Legitimacy Audit for the specific concern with `firstfloor_calendar`.

### Already available — no new dependency

| Library | Version (pubspec.yaml, verified this session) | Relevance |
|---------|---------|-----------|
| `timezone` | ^0.11.0 | Already used in `notification_service.dart` for local-zone-aware scheduling — the precedent for converting a calendar event's timezone into the local minutes-from-midnight `CommitmentBlock` needs (see Common Pitfall 3) |
| `flutter_timezone` | ^5.0.2 | Already used to read the device's IANA timezone identifier at startup — same reuse point |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `device_calendar_plus` | `device_calendar` | Abandoned (23 months, 118 open issues, own successor calls it abandoned) — rejected, not revisited |
| `device_calendar_plus` | `eventide` | Recurrence explicitly marked "not implemented" (🏗) in its own README as of its 2.4.0 release 9 days before this research — confirmed still true this session, disqualifying |
| A first-party ICS package | Writing an RRULE expander in-house | `rrule` (pub.dev) is a credible RFC-5545-only recurrence-math package if a full ICS parser proves unreliable — narrower scope than a full parser, still a "don't hand-roll" win over hand-written date math |

**Installation (once ICS package is spiked and chosen):**
```bash
flutter pub add device_calendar_plus
flutter pub add firstfloor_calendar   # or the spike's winner
```

**Version verification:** confirmed live against the pub.dev API this session (`curl -s
https://pub.dev/api/packages/<name>`), not from training-data recall — see per-package dates above
and the Package Legitimacy Audit table.

## Package Legitimacy Audit

**Tooling gap, disclosed:** `gsd-tools query package-legitimacy check` only supports
`--ecosystem <npm|pypi|crates>`; it errors on `pub` (Dart/Flutter). This audit was therefore done
manually against the pub.dev API (`https://pub.dev/api/packages/<name>`) and the GitHub API
(`https://api.github.com/repos/<owner>/<repo>`), which is the closest equivalent available. No entry
below can carry the tool-conferred `[VERIFIED: npm registry]`-style tag — everything is `[CITED:
pub.dev]` / `[CITED: github.com]` at best.

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| `device_calendar_plus` | pub.dev, verified publisher `bullet.to` | latest release 50 days old; repo pushed 26 days ago | 9.71k total downloads, 20 likes | `github.com/bullet-to/device_calendar_plus`, 21 open issues, 11 stars, not archived | OK (manual) | Approved |
| `device_calendar` | pub.dev | latest release ~23 months old | 80.6k downloads (legacy install base) | `github.com/builttoroam/device_calendar`, 118 open issues per ROADMAP's prior research | SUS (manual) — abandoned | Rejected, not adopted (already decided) |
| `eventide` | pub.dev | latest release 9 days old | — | `github.com/sncf-connect-tech/eventide`, 3 open issues, 16 stars, not archived | OK (manual), but feature-incomplete | Rejected — recurrence "not implemented," disqualifying regardless of package health |
| `firstfloor_calendar` | pub.dev, "verified publisher" claim (`firstfloorsoftware.com`) per score page | latest release 58 days old; 15 releases since 2025-10-15 | **5 likes, 52 weekly downloads** | pub.dev metadata lists `github.com/firstfloorsoftware/firstfloor_calendar`; **that URL 301-redirects to `github.com/kozw/firstfloor_calendar`** (confirmed via `api.github.com/repos/firstfloorsoftware/firstfloor_calendar` → `Moved Permanently` → `api.github.com/repositories/1076056150` → `full_name: kozw/firstfloor_calendar`); 0 open issues, **2 stars**, not archived | **SUS (manual)** | **Flagged — planner must add a `checkpoint:human-verify` task before adopting, or pick `enough_icalendar` instead** |
| `enough_icalendar` | pub.dev | latest release ~13 months old | 7.55k downloads, 9 likes | `github.com/Enough-Software/enough_icalendar` | OK (manual) | Approved as fallback if `firstfloor_calendar`'s spike or legitimacy check fails |
| `icalendar_parser` | pub.dev | latest release ~24 months old | — | `github.com/TesteurManiak/icalendar_parser` | SUS (manual) — stale | Not recommended |

**Packages removed due to [SLOP] verdict:** none — no package here shows the hallmarks of a
hallucinated/slopsquatted package (all resolve on the registry with plausible history).

**Packages flagged as suspicious [SUS]:** `firstfloor_calendar` (very low adoption — 2 stars, 52
weekly downloads — combined with a GitHub-ownership mismatch between what pub.dev's own metadata
records and where the repository now actually lives). This is not proof of anything malicious — solo
open-source authors move personal projects between accounts routinely — but it is exactly the kind of
signal this gate exists to surface, and the low adoption means few other users would have noticed a
problem yet. **Recommendation:** either (a) spike `firstfloor_calendar` against a real `.ics` file
with a `RECURRENCE-ID` exception before committing, with the spike itself gated behind
`checkpoint:human-verify`, or (b) default to `enough_icalendar` and accept that recurrence-instance
expansion may need to be hand-rolled on top of its parsed `RecurrenceRule` (using the `rrule` package
for the math) rather than assumed to exist.

*The device plugin choice (`device_calendar_plus`) is not flagged — it has an order of magnitude more
downloads, a verified publisher building it for their own shipping product, and its GitHub repo
ownership matches pub.dev's metadata exactly.*

## Architecture Patterns

### System Architecture Diagram

```
                     ┌─────────────────────────────────────────┐
                     │   Device / OS layer (per platform)       │
                     │   iOS: EventKit    Android: CalendarContract │
                     │   (aggregates every account the user added:  │
                     │    iCloud, Google, Exchange, subscribed)      │
                     └──────────────┬────────────────────────────┘
                                    │ device_calendar_plus
                                    │ (listCalendars / listSources /
                                    │  listEvents / requestPermissions
                                    │  — READ-ONLY calls only, CAL-03)
                                    ▼
┌───────────────┐         ┌─────────────────────┐         ┌──────────────────┐
│ .ics URL       │         │   CalendarSource      │         │  Neither device   │
│ (web/desktop)   ├────────▶│   interface            │◀────────┤  cal nor .ics     │
│ IcsCalendarSource│  parse │   (lib/data/)          │  no-op  │  NullCalendarSource│
└───────────────┘   +expand└──────────┬─────────────┘         └──────────────────┘
                                       │ List<CalendarEvent> (uniform shape,
                                       │ already-expanded occurrences)
                                       ▼
                            ┌──────────────────────┐
                            │  CalendarSyncService   │  lib/services/
                            │  event → CommitmentBlock│  (new, peer to
                            │  mapping + gating rules  │  schedule_generator)
                            └──────────┬───────────┘
                                       │ upsert by externalEventId
                                       ▼
                            ┌──────────────────────┐
                            │ CommitmentBlockRepository│ lib/data/ — UNCHANGED
                            │ (Hive 'commitment_blocks')│ shape, +1-2 fields
                            └──────────┬───────────┘
                                       │ CommitmentsNotifier.loadBlocks()
                                       ▼
                     checkin_screen.dart:127-132 reads .blocks
                                       │
                                       ▼
                     ScheduleNotifier.generateToday(blocks: ...)
                                       │
                                       ▼
              schedule_generator.dart Step 1 (buildCommitmentChunks)
                          — UNCHANGED, out of scope —
```

### Recommended Project Structure

```
lib/
├── data/
│   ├── calendar/                        # NEW — mirrors repositories/ pattern
│   │   ├── calendar_source.dart         # abstract interface
│   │   ├── calendar_event.dart          # uniform event shape (id, title,
│   │   │                                #   start/end DateTime, isAllDay,
│   │   │                                #   timeZone, status, calendarId)
│   │   ├── device_calendar_source.dart  # device_calendar_plus-backed
│   │   ├── ics_calendar_source.dart     # .ics URL-backed
│   │   └── null_calendar_source.dart    # always-safe fallback
│   └── models/
│       └── commitment_block.dart        # +2 additive HiveFields (7, 8)
├── services/
│   └── calendar_sync_service.dart       # NEW — event → CommitmentBlock mapping,
│                                         #   gating (short/declined/cancelled),
│                                         #   upsert-by-externalEventId
├── providers/
│   └── commitments_notifier.dart        # gains a sync() method, or a thin
│                                         #   sibling notifier calls it
└── screens/
    └── settings/
        └── calendar_settings_screen.dart  # NEW — CAL-02 checkbox list
```

### Pattern 1: `CalendarSource` interface, following the existing repository precedent

**What:** One abstract interface, swappable implementations — identical shape to
`CommitmentBlockRepository` / `HiveCommitmentBlockRepository`.
**When to use:** Every call site that needs calendar data talks only to `CalendarSource`; platform
selection happens once, at construction (e.g. in `main.dart`, mirroring how `CommitmentsNotifier` is
constructed before `runApp`).
**Example, modeled directly on the verified existing pattern:**
```dart
// Source: lib/data/repositories/commitment_block_repository.dart (read this session)
abstract class CommitmentBlockRepository {
  Future<List<CommitmentBlock>> getAll();
  Future<CommitmentBlock?> getById(String id);
  Future<void> save(CommitmentBlock block);
  Future<void> delete(String id);
  Future<List<CommitmentBlock>> getByDayOfWeek(int day);
}

// Proposed, same shape:
abstract class CalendarSource {
  Future<bool> isAvailable();                       // false on NullCalendarSource
  Future<CalendarPermissionState> requestPermission();
  Future<List<CalendarInfo>> listCalendars();        // CAL-02
  Future<List<CalendarEvent>> listEvents({
    required DateTime start,
    required DateTime end,
    required List<String> calendarIds,               // user's CAL-02 selection
  });
}
```

### Pattern 2: Listing calendars for CAL-02 (device source)

**What:** `device_calendar_plus`'s `Calendar` class already carries everything the settings screen
needs — no additional mapping required.
**Source:** `[CITED: pub.dev/documentation/device_calendar_plus/latest/device_calendar_plus/Calendar-class.html]`
```dart
// Confirmed fields on device_calendar_plus's Calendar class (fetched this session):
// id (String), name (String), colorHex (String?), color (Color?),
// readOnly (bool), accountName (String?), accountType (String?),
// isPrimary (bool), hidden (bool)
final calendars = await DeviceCalendar.instance.listCalendars();
// group by accountName/accountType for the checkbox list —
// this is exactly what lets the settings screen "show him" (CONTEXT.md
// decision 4) instead of asking whether Google is configured.
```

**Naming collision to plan around:** the plugin's own SDK exports a class it also calls
`CalendarSource` (`listSources()` returns `List<CalendarSource>`, representing OS-level accounts like
iCloud/Google/local — a different concept from this app's own `CalendarSource` abstraction).
`[CITED: pub.dev/documentation/device_calendar_plus/latest/device_calendar_plus/DeviceCalendar-class.html]`
**The plan must alias the plugin's import** (`import 'package:device_calendar_plus/device_calendar_plus.dart' as plugin;`)
or rename this app's interface — do not let both compile under the same bare identifier.

### Pattern 3: Never store RRULE in `CommitmentBlock` — materialize one-off instances per sync

**What:** `device_calendar_plus.listEvents(start, end)` is documented and used in its own example as
returning individually-addressable occurrences (`event.instanceId`, described as "includes the
timestamp" for recurring events) within the requested window.
`[CITED: pub.dev/packages/device_calendar_plus (README/example, fetched this session)]` — **not
executed on a device this session (see Common Pitfall 1)**.
**When to use:** Every imported calendar occurrence — whether the source event is a one-time meeting
or the 47th instance of a weekly recurring one — becomes its own one-off `CommitmentBlock`
(`date`-anchored, `daysOfWeek: const []`), synced within a rolling window (e.g., next 14 days), and
re-materialized (upserted, not appended) on every sync. This sidesteps ever needing to translate an
RRULE + its exceptions into `CommitmentBlock`'s own `daysOfWeek` recurrence model, which has no
concept of exceptions at all.
**Example:**
```dart
// Source: lib/data/models/commitment_block.dart (read this session, lines 8-50)
CommitmentBlock({
  String? id,
  required this.name,
  required this.daysOfWeek,   // <- leave as const [] for every imported event
  required this.startMinutes,
  required this.endMinutes,
  this.date,                  // <- always set for an imported event
});
```

### Pattern 4: Idempotent upsert via an additive external-id field

**What:** `CommitmentBlock` currently has HiveFields 0-6 (typeId 1). Fields 7 and 8 are free
(confirmed by reading `commitment_block.dart` end-to-end this session — no field above 6 exists).
`[VERIFIED: lib/data/models/commitment_block.dart:8-50]` — the class declares exactly `@HiveField(0)`
through `@HiveField(6)`; no other field annotations exist in the file.
**Why:** without a stable external-event key, every sync would either duplicate blocks or require a
full delete-and-recreate (losing any user edits — see the editability recommendation below). Add:
```dart
@HiveField(7)
String? externalEventId;   // 'device:<calendarId>:<instanceId>' or 'ics:<url-hash>:<uid>:<recurrence-id>'

@HiveField(8)
bool isFromCalendar = false;   // drives read-only-with-a-reason UI treatment
```
`getByDayOfWeek`-style lookups stay unaffected (additive Hive fields deserialize old records with
`null`/default values, same pattern already used for `date` at field 6's neighbor and `color` at
field 5 — both already additive in this file).

### Pattern 5: Local wall-clock conversion, not UTC

**What:** Reuse the app's existing timezone stack (`timezone` + `flutter_timezone`, already a
dependency, already used in `notification_service.dart`) to convert a calendar event's `DateTime`
(which may carry a distinct IANA zone via `Event.timeZone`) into **device-local** minutes-from-midnight
— never UTC, regardless of what `commitment_block.dart`'s doc comment currently (incorrectly) claims.
**Source:**
```dart
// Source: lib/services/notification_service.dart:36-44 (read this session)
tz.initializeTimeZones();
try {
  final tzInfo = await FlutterTimezone().getLocalTimezone(); // or equivalent call
  tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
} catch (_) {
  tz.setLocalLocation(tz.UTC);
}
```
The mapper should compute `localStart = tz.TZDateTime.from(event.startDate, tz.local)` and derive
`startMinutes = localStart.hour * 60 + localStart.minute` — exactly mirroring how
`commitment_form_sheet.dart`'s `showTimePicker` result already becomes local minutes today.

### Anti-Patterns to Avoid

- **Do not touch `schedule_generator.dart`.** It already consumes `CommitmentBlock` correctly and
  already chunks a commitment window on the lattice (`COMMITBREAK-01`/D-30-04, verified this session
  by reading `buildCommitmentChunks` call site at `schedule_generator.dart:458-478`).
- **Do not store a raw RRULE string anywhere in `CommitmentBlock`.** See Pattern 3 — expansion is the
  OS's job (device source) or the ICS package's job (`.occurrences()`), not this app's.
- **Do not treat `startMinutes`/`endMinutes` as UTC**, despite the existing doc comment. See Pattern 5
  and Common Pitfall 3.
- **Do not let the plugin's `CalendarSource` (calendar-accounts) and this app's `CalendarSource`
  (source abstraction) collide under one bare import.** See Pattern 2.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Reading EventKit/CalendarContract | A federated Swift+Kotlin plugin | `device_calendar_plus` | Already decided (CONTEXT.md decision 2) — Swift and Kotlin maintenance forever, and it still wouldn't cover web/desktop |
| Expanding a recurring event into its actual occurrences, with exceptions | Hand-written RRULE math + exception-date bookkeeping | The device OS (via `listEvents`'s already-expanded instances) for the device source; `firstfloor_calendar.occurrences()` or the `rrule` package for the ICS source | RFC 5545 recurrence (especially `RECURRENCE-ID`/`EXDATE`/leap-year/DST edge cases) is exactly the deceptively-complex problem class this section exists to name — device_calendar's own README treats it as a headline feature, and `eventide` was rejected specifically for leaving it unimplemented |
| Timezone-aware local-time conversion | Manual UTC-offset arithmetic | `timezone` + `flutter_timezone` (already dependencies, already used in `notification_service.dart`) | DST transitions and non-fixed-offset zones make manual arithmetic a guaranteed source of the SEED-006 failure shape |
| ICS parsing | A regex-based `.ics` line reader | `firstfloor_calendar` (pending spike) or `enough_icalendar` | RFC 5545's folding/escaping/multi-value rules are easy to get subtly wrong on real-world calendar exports (Outlook/Google both have quirks) |

**Key insight:** the single biggest hand-roll temptation in this phase is recurrence-exception logic,
precisely because it is *also* the single most load-bearing capability (CONTEXT.md's own framing).
The architecture in Pattern 3 exists specifically to avoid ever writing that logic in this codebase —
route it to whichever layer (OS or library) already solved it, and verify that layer's behavior
rather than reimplementing it as a fallback.

## Common Pitfalls

### Pitfall 1: The recurrence-exception claim is documentation-verified, not device-verified

**What goes wrong:** The plan proceeds as if `device_calendar_plus`'s recurrence handling
(exceptions, "this-and-following" edits, per-instance `listEvents` expansion) is a settled fact,
because it reads confidently in the package's own docs.
**Why it happens:** danserver has no Android SDK (`flutter doctor` confirmed this session:
`✗ Unable to locate Android SDK`) and no Xcode ever will exist here — there is no way to run this
plugin's code on this machine, at all, for either platform.
**How to avoid:** treat every recurrence claim in this document as `[CITED: pub.dev]`, not
`[VERIFIED]`, and make "verify a real recurring event, including one moved single occurrence, on a
real device" the literal first task of the `DeviceCalendarSource` implementation wave — before any
downstream mapping code is trusted. This project has a documented pattern of green
suites/confident-sounding docs being contradicted by an actual device (five times per CLAUDE.md's own
counter for UI work); there is no reason to expect calendar recurrence to be exempt, and here there
isn't even a `flutter test` in between to catch a surprise — the first real signal is the owner's
MacBook or Android phone.
**Warning signs:** a plan that writes mapping/gating logic for recurrence exceptions *before*
scheduling the device-verification task, or that marks CAL-01 done on the strength of `flutter
analyze` alone.

### Pitfall 2: CommitmentBlock's "UTC" doc comment is wrong — the field is local wall-clock

**What goes wrong:** A calendar event's `startDate`/`endDate` get converted to UTC minutes-from-
midnight because the target field's own doc comment says to.
**Why it happens:** `[VERIFIED: lib/data/models/commitment_block.dart:29-35]` —
> `/// Start time as minutes from midnight UTC (e.g. 540 = 9:00am)` (line 29, `startMinutes`)
> `/// End time as minutes from midnight UTC (e.g. 1020 = 5:00pm)` (line 33, `endMinutes`)

But the only production code that constructs those values —
`[VERIFIED: lib/screens/commitments/commitment_form_sheet.dart:105-111]`:
```dart
final result = await showTimePicker(
  context: context,
  initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
);
if (result != null) {
  onSet(result.hour * 60 + result.minute);
}
```
— uses `showTimePicker`, which returns a **device-local** `TimeOfDay`, with no `.toUtc()` or
timezone conversion anywhere in the file. `schedule_generator.dart`'s own `generateToday` computes
`final date = DateTime(now.year, now.month, now.day); // midnight local` (comment says "local," not
UTC) and matches `daysOfWeek` against `date.weekday` — also local. The doc comment is simply stale.
**How to avoid:** convert every calendar event to local wall-clock minutes (Pattern 5), and correct
the doc comment as a one-line fix while the file is open for the new fields anyway — a future reader
should not be misled the way this comment would mislead a calendar importer.
**Warning signs:** a mapper that calls `.toUtc()` on an `Event.startDate` before computing minutes; a
regression test whose fixture happens to run in UTC (danserver's own system timezone) and therefore
cannot distinguish correct-local from accidentally-also-correct-because-UTC-offset-is-zero.

### Pitfall 3: Overlapping commitment blocks are unguarded in the generator

**What goes wrong:** Two imported calendar events overlap (a real, common occurrence — a 25-minute
buffer meeting is scheduled inside a longer "Focus block"), the importer creates two separate
`CommitmentBlock`s for the same day, and the schedule shows overlapping/duplicated content.
**Why it happens:** `[VERIFIED: lib/services/schedule_generator.dart:458-478]` — Step 1 loops over
every block independently:
```dart
for (final block in blocks) {
  // ... anchoredToday check ...
  if (!anchoredToday) continue;
  workChunks.addAll(
    buildCommitmentChunks(block, longBreakEvery: longBreakEvery),
  );
}
```
and STEP C (`[VERIFIED: lib/services/schedule_generator.dart:821]`, `final List<ScheduledChunk>
result = [...commitmentChunks];`) simply concatenates every block's chunks — there is no overlap
detection or merge logic anywhere in the generator, for commitment blocks against each other.
**How to avoid:** this is explicitly out of the generator's bounds to fix (engine unchanged). The
importer/mapper is therefore the only place this can be handled, and the phase must decide
deliberately: import overlapping events as-is (simplest, most honest — "your calendar really does
have you double-booked") vs. detect and visually flag overlaps vs. merge into a union window (loses
per-meeting identity). **Recommendation: import as-is and add a regression test** that generates a
day from two overlapping commitment blocks and asserts the generator does not crash and both blocks'
chunks are present — this is new, uncovered territory (no existing fixture in
`schedule_generator_test.dart` builds two overlapping blocks) and deserves its own explicit assertion
rather than an assumption that "nothing crashes" is already proven.
**Warning signs:** a UAT that only tests one commitment block at a time never exercises this path —
same shape of gap that let COMMITBREAK-01/02 go unnoticed through two whole phases (Phase 29/30
history).

### Pitfall 4: A short/zero-duration/no-end-time calendar event silently vanishes — or silently should

**What goes wrong:** A 15-minute calendar event, or one with no end time, is either imported and
crashes/misbehaves, or is silently dropped in a way that looks like a bug rather than a deliberate
rule.
**Why it happens:** `[VERIFIED: lib/utils/commitment_window.dart:1-13]`:
```dart
/// A scheduled chunk is 25 minutes, so a window shorter than that (including an
/// inverted overnight window like 10pm–6am, where end < start) materializes
/// zero chunks and would silently never appear on the schedule.
const int kMinCommitmentWindowMinutes = 25;
bool commitmentWindowTooShort(int startMinutes, int endMinutes) =>
    endMinutes - startMinutes < kMinCommitmentWindowMinutes;
```
This invariant already exists and is already enforced on the hand-entry form and onboarding. A
calendar-sourced `CommitmentBlock` that skips this same gate would be the one path in the app that
creates a block guaranteed to render as a phantom "commitment" that materializes zero chunks —
confusing, not just silently wrong.
**How to avoid:** reuse `commitmentWindowTooShort` verbatim as the importer's own gate. For a
no-end-time event (some calendar exports omit `DTEND`), the honest default given RFC 5545's own
convention is a 0-duration/point-in-time event — treat it the same as "too short," skip it, and make
the skip **visible** (a "3 events skipped — too short to schedule" line in the sync summary), not
silent, matching CAL-04's spirit of never degrading invisibly.
**Warning signs:** any test suite for this phase that, like the Phase 28/33 near-misses, only
fixtures events that are comfortably longer than 25 minutes — the whole point of this pitfall is that
the *boundary* case is where the existing invariant does its work.

### Pitfall 5: Multi-day / overnight calendar events collide with a standing, deliberate scope boundary

**What goes wrong:** A multi-day calendar event (a 3-day conference, or a single meeting that runs
11pm–2am) gets mapped to one `CommitmentBlock` spanning multiple days or crossing midnight.
**Why it happens:** `CommitmentBlock` has no representation for this at all —
`[VERIFIED: lib/utils/commitment_window.dart:3-4]` calls out the exact case: *"a window shorter than
that (including an inverted overnight window like 10pm–6am, where end < start)."* This is a
pre-existing, deliberately-deferred scope boundary (`overnight-commitments-deferred` memory,
confirmed current this session): *"Canopy does NOT support midnight-crossing (overnight) fixed
commitments — e.g. a 10pm–6am night shift — anywhere in the app,"* scoped out by the owner on
2026-07-03 as its own future feature, not something to "slip in as a bugfix."
**How to avoid:** split a multi-day event into one `CommitmentBlock` per calendar day it touches,
clipped to that day's `00:00`–`24:00` (1440-minute) window, then run each day's slice through the
same `commitmentWindowTooShort` gate from Pitfall 4 (a 1-hour tail-end slice imports; an 11pm–midnight
sliver under 25 minutes gets skipped, same as any other short event). This requires no new engine
feature — it is the existing one-off `date`-anchored `CommitmentBlock` shape, applied once per day.
**Warning signs:** any code path that computes `endMinutes < startMinutes` for a `CommitmentBlock` and
persists it anyway — that is exactly the shape this app's existing validation exists to reject, and
letting the importer bypass it would reopen a bug class the rest of the app already closed.

### Pitfall 6: All-day events are a real product decision, not a mapping detail

**What goes wrong:** All-day calendar entries (which are extremely common and often low-signal —
birthdays, holidays, "Out of Office" banners, a subscribed sports-team calendar) get imported as
full-day `CommitmentBlock`s and consume 100% of the day's discretionary capacity, which is a severe
and surprising failure mode given `_moodCap`'s modest chunk counts.
**Why it happens:** `device_calendar_plus`'s `Event.isAllDay` is a confirmed, well-defined field
`[CITED: pub.dev/documentation/device_calendar_plus/latest]`, but nothing in this app's domain model
distinguishes "an all-day event that should block the day" (a real out-of-office day) from "an
all-day event that is just a banner" (a birthday reminder) — that distinction does not exist in the
calendar data itself.
**How to avoid — recommendation, tagged `[ASSUMED]` as a product judgment, not a verified fact:**
default to **not** importing all-day events as blocking `CommitmentBlock`s at all. Surface them
separately (a label-only list, or omit entirely for v1) rather than let one imported "National Pizza
Day" all-day entry silently consume the whole day's schedule. This is exactly the kind of decision
CONTEXT.md's "Claude's discretion" section exists for — record it as a locked decision once made
(recommend confirming with the owner at plan time given how large the failure mode is), not something
to infer silently mid-implementation.
**Warning signs:** a UAT that never adds a real all-day "Holiday" entry to a test calendar and
therefore never observes the day going empty.

## Code Examples

### Listing calendars for CAL-02 settings

```dart
// Source: pub.dev/documentation/device_calendar_plus (fetched this session, CITED not executed)
final permission = await DeviceCalendar.instance.requestPermissions();
if (permission == CalendarPermissionStatus.granted) {
  final calendars = await DeviceCalendar.instance.listCalendars();
  // calendars[i].id / .name / .accountName / .accountType / .readOnly / .color
}
```

### Listing events in a sync window

```dart
// Source: pub.dev/packages/device_calendar_plus/example (fetched this session)
final now = DateTime.now();
final events = await DeviceCalendar.instance.listEvents(
  now,
  now.add(const Duration(days: 14)),  // rolling sync window, not the whole year
  calendarIds: selectedCalendarIds,   // from the CAL-02 settings selection
);
```

### Permission status handling for CAL-04

```dart
// Source: pub.dev/documentation/device_calendar_plus (CalendarPermissionStatus enum, fetched this session)
switch (status) {
  case CalendarPermissionStatus.granted:
    // proceed with DeviceCalendarSource
  case CalendarPermissionStatus.writeOnly:
    // should not occur for a read-only requestPermissions(level: .full) call,
    // but if the OS returns it anyway, treat identically to `denied` — this
    // app never needs write access and should never request it (CAL-03)
  case CalendarPermissionStatus.denied:
  case CalendarPermissionStatus.restricted:
  case CalendarPermissionStatus.notDetermined:
    // CAL-04: fall back to NullCalendarSource behavior — hand-entered
    // commitments continue to work exactly as they do today
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| `device_calendar` (builttoroam) | `device_calendar_plus` (bullet.to) | `device_calendar`'s last commit was 2025-03-08 per ROADMAP's prior research; `device_calendar_plus` has been the actively-developed successor since at least 2024-11 | The old package is a documented dead end — do not let training-data recall suggest it as "the" Flutter calendar plugin, that recall is stale |

**Deprecated/outdated:** none specific to this phase beyond the above — this is a young, actively
evolving corner of the Flutter ecosystem (`device_calendar_plus` had 8 releases in the ~2 months
before this research), so **re-check package freshness at plan time if planning is delayed by more
than a few weeks past 2026-09-11.**

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `device_calendar_plus.listEvents()` returns already-expanded per-occurrence instances with exceptions applied (moved occurrence, "this-and-following" edits reflected in reads) | Summary, Pattern 3, Pitfall 1 | This is the single most load-bearing claim in the whole phase. If false, `CommitmentBlock`'s recurring-block model would need to represent RRULE natively (a much larger change) or exceptions would silently not appear on the schedule — exactly the failure mode CAL-01 exists to prevent. Must be the first thing verified on a real device. |
| A2 | `Attendee.status` (`AttendeeStatus.declined`) can be reliably matched to "the device owner declined," not just "some attendee declined" | Common Pitfall (declined invitations, discussed in Summary) | No confirmed "isSelf"/"isCurrentUser" field was found in the plugin's documented `Attendee` class this session. Filtering the wrong attendee's decline could hide a commitment the user actually has, or show one they don't. Recommend: only filter on `EventStatus.canceled` (confirmed, unambiguous) at v1; treat per-attendee decline filtering as a stretch goal pending device verification. |
| A3 | All-day calendar events should NOT be imported as blocking `CommitmentBlock`s by default | Common Pitfall 6 | Product judgment call, not verified against any spec or user statement. Wrong in either direction: importing all-day entries risks a silently-empty schedule; never importing them risks missing a genuine out-of-office day. Recommend confirming with the owner before implementation, not inferring silently. |
| A4 | `firstfloor_calendar` correctly implements `EXDATE`/`RECURRENCE-ID` exception handling | Standard Stack, Package Legitimacy Audit | No changelog entry, README excerpt, or example this session confirmed this explicitly — only "full RRULE recurrence expansion" and RDATE support were confirmed. If false, the ICS path (web/desktop — the platform the owner actually tests on) would silently mis-render a moved meeting. Recommend a spike task before adopting. |
| A5 | Overlapping imported commitment blocks should be imported as-is (not merged, not flagged) | Common Pitfall 3 | Minority-impact product decision; if wrong, the owner sees visually confusing overlapping cards on the timeline with no explanation. Low risk given it mirrors "the calendar told the truth," but worth a one-line confirmation at plan/discuss time. |

## Open Questions

1. **Does `device_calendar_plus`'s `listEvents()` genuinely resolve recurrence exceptions on both
   platforms, identically?**
   - What we know: the docs and example strongly imply per-instance expansion (`instanceId`
     "includes the timestamp" for recurring events; three-tier edit granularity requires addressable
     instances to exist for reads to have populated in the first place).
   - What's unclear: nothing in the docs was found that shows a worked example of querying across a
     `RECURRENCE-ID`-exception boundary and confirming the returned instance reflects the moved time.
   - Recommendation: Wave 0 of the device-source implementation should be a throwaway script/screen
     that creates a recurring event *in the OS calendar app* (not through this plugin — CAL-03), moves
     one occurrence, and confirms `listEvents` returns the moved time for that instance. This can only
     happen on the owner's MacBook or an Android device — not on danserver.

2. **Is `firstfloor_calendar` trustworthy enough to adopt, given the GitHub-ownership mismatch?**
   - What we know: pub.dev's own package metadata (`repository` field) still points to
     `firstfloorsoftware/firstfloor_calendar`; that URL is now a permanent redirect to a completely
     different GitHub account (`kozw`).
   - What's unclear: whether this is a benign account rename/transfer (common, harmless) or something
     that should change the recommendation.
   - Recommendation: either spike it with the owner's explicit sign-off (`checkpoint:human-verify`),
     or default to `enough_icalendar` + the standalone `rrule` package for occurrence math, accepting
     more integration work for a package with a cleaner provenance trail.

3. **Should the calendar sync window be fixed (e.g., next 14 days) or tied to something else (e.g.,
   "through the end of the current quarter," matching `quarterly_aggregation_service.dart`'s own
   horizon)?**
   - What we know: the app is local-first and does not want unbounded background syncing.
   - What's unclear: no existing precedent in this codebase for a "rolling sync window" concept.
   - Recommendation: start narrow (14 days) — it directly serves the one thing that actually consumes
     `CommitmentBlock`s (`generateToday`, always for "today"), and a exponentially large window buys
     nothing but query weight. Widen only if a concrete need appears (e.g., a future "preview this
     week" surface).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | all work | ✓ | 3.44.1 (stable) `[VERIFIED: flutter doctor -v, run this session]` | — |
| `flutter analyze` | all work | ✓ | clean, 0 issues, run this session | — |
| `flutter test` (740 tests) | all work | ✓ | 740/740 passing, run this session | — |
| Android SDK (APK build) | Android device-source verification | **✗** `[VERIFIED: flutter doctor -v — "✗ Unable to locate Android SDK"]` | — | None on this machine. Any Android build/run step is the owner's device, not danserver. |
| Xcode / iOS toolchain | iOS build, iOS device-source verification | **✗** (known permanent condition per STATE.md/CLAUDE.md — never present on Linux) | — | The owner's MacBook, always. |
| Chrome | `flutter test -d chrome` / `flutter run -d chrome` | ✗ `[VERIFIED: flutter doctor -v — "Cannot find Chrome executable"]` | — | Not needed for this phase's actual UAT path — `flutter build web --debug` + `tools/serve-uat.py` does not require a local Chrome binary; `go-look-at`'s own headless Chromium is a separate toolchain from `flutter`'s Chrome device target |
| `timezone` / `flutter_timezone` packages | Local wall-clock conversion (Pattern 5) | ✓ — already dependencies, already used in `notification_service.dart` | ^0.11.0 / ^5.0.2 `[VERIFIED: pubspec.yaml, read this session]` | — |

**Missing dependencies with no fallback:**
- Any actual execution of `DeviceCalendarSource` code (Android or iOS) — genuinely cannot happen on
  danserver at any point in this phase's lifecycle. Every plan must treat this as a hard boundary: the
  most this machine can verify is `flutter analyze` + `flutter test` (with a fake/in-memory
  `CalendarSource` for unit tests) + a web/desktop build exercising `IcsCalendarSource` and
  `NullCalendarSource`. Device-source correctness is the owner's job, every time.

**Missing dependencies with fallback:**
- Chrome (web build/serve path already has a working, Chrome-independent alternative per
  `CLAUDE.md`'s "Local hosting for UAT" section).

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` (bundled with Flutter SDK 3.44.1) |
| Config file | none — standard `flutter test` discovery over `test/` |
| Quick run command | `flutter test test/<specific_file>.dart` |
| Full suite command | `flutter test` (740 tests, ~23s, confirmed this session) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CAL-01 | A `CalendarEvent` maps to a correct `CommitmentBlock` (name, local start/end minutes, one-off `date`) | unit | `flutter test test/services/calendar_sync_service_test.dart -x` | ❌ Wave 0 |
| CAL-01 | Short (<25min), zero-duration, and no-end-time events are gated by `commitmentWindowTooShort` and skipped, not silently malformed | unit | `flutter test test/services/calendar_sync_service_test.dart -x` | ❌ Wave 0 |
| CAL-01 | Multi-day events are split per calendar day, clipped to `0..1440` | unit | `flutter test test/services/calendar_sync_service_test.dart -x` | ❌ Wave 0 |
| CAL-02 | Settings screen renders exactly the calendars a fake `CalendarSource.listCalendars()` returns, grouped/labelled by account | widget | `flutter test test/screens/settings/calendar_settings_screen_test.dart -x` | ❌ Wave 0 |
| CAL-03 | No `CalendarSource` implementation ever calls a write method (compile-time/static guard: the interface itself has no write method, so this is provable by interface shape rather than by a runtime test) | static | `flutter analyze` (interface omits write methods entirely — see Pattern 1) | N/A — structural, not test-driven |
| CAL-04 | `NullCalendarSource` returns `isAvailable() == false` and an empty calendar/event list, never throws | unit | `flutter test test/data/calendar/null_calendar_source_test.dart -x` | ❌ Wave 0 |
| CAL-04 | A denied/restricted permission on `DeviceCalendarSource` degrades to the same UI state as `NullCalendarSource`, with hand-entered commitments still fully functional | widget | `flutter test test/screens/settings/calendar_settings_screen_test.dart -x` | ❌ Wave 0 |
| (generator boundary) | Two overlapping commitment blocks on the same day do not crash `schedule_generator.dart` and both contribute chunks (Common Pitfall 3) | unit | `flutter test test/services/schedule_generator_test.dart -x` (new group, existing file) | ❌ Wave 0 — new case in an existing file |
| (local time) | An event with a non-local `Event.timeZone` maps to the correct **local** minutes, not UTC (Common Pitfall 2) | unit | `flutter test test/services/calendar_sync_service_test.dart -x` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** the specific new/changed test file(s)
- **Per wave merge:** `flutter test` (full 740+ suite)
- **Phase gate:** full suite green before `/gsd-verify-work`; **plus** an explicit, separately-tracked
  device-verification step (Open Question 1 / Common Pitfall 1) that this machine cannot perform and
  must not be silently skipped or assumed passing.

### Wave 0 Gaps

- [ ] `test/services/calendar_sync_service_test.dart` — covers CAL-01's mapping rules (all-day,
      timezone, short/zero-duration, multi-day split, overlap-tolerance)
- [ ] `test/data/calendar/null_calendar_source_test.dart` — covers CAL-04's always-safe fallback
- [ ] `test/data/calendar/ics_calendar_source_test.dart` — covers the ICS path with a fixture `.ics`
      file containing a recurring event with a `RECURRENCE-ID` exception (this is also where Open
      Question 2's spike lives — write the fixture and the assertion before picking the package)
- [ ] `test/screens/settings/calendar_settings_screen_test.dart` — covers CAL-02's checkbox list and
      CAL-04's denied-permission UI state
- [ ] New test group inside the existing `test/services/schedule_generator_test.dart` — covers
      Common Pitfall 3 (overlapping commitment blocks), proven RED against the current generator
      first (it should currently just silently render both — confirm that's true, not assumed)
- [ ] Framework: none — `flutter_test` is already fully set up; no new install needed

## Security Domain

No `security_enforcement: false` in `.planning/config.json` — this section is required.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | This phase adds no authentication surface — calendar access is OS-level permission, not app-level auth |
| V3 Session Management | no | N/A — no session concept in this app |
| V4 Access Control | yes | The OS's own permission dialog (`CalendarPermissionStatus`) is the access-control boundary; the app must never request write access (`CalendarAccessLevel.writeOnly`/full write) since CAL-03 forbids writing — **request only read access, never the write-capable level** |
| V5 Input Validation | yes | Calendar event data (titles, locations) is untrusted external input entering the app's data model. Standard control: no interpolation of event text into anything executed (SQL/shell/etc. — moot here, Hive is a key-value store with no query language), and event names should be treated as display-only strings, same as any other user-entered `CommitmentBlock.name` today. `.ics` files from a URL subscription are a stronger case — a malformed or adversarial `.ics` feed is untrusted network input and must not crash the ICS parser or the app; wrap parsing in error handling that degrades to "sync failed" rather than propagating a parse exception into the UI |
| V6 Cryptography | no | HTTPS for `.ics` URL fetches is standard (do not silently accept `http://`); no cryptographic primitives are hand-rolled by this phase |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Malicious/malformed `.ics` feed URL crashes the parser or hangs the app | Denial of Service | Wrap ICS fetch+parse in try/catch with a timeout; treat any failure as "sync failed, using last-known data" (also serves CAL-04's degrade-visibly requirement) — never let a bad feed block the app from functioning |
| Over-broad permission request (asking for write access this app will never use) | Elevation of Privilege (of the app's own footprint, against the user's expectations) | Request only the read-capable permission level; CAL-03 is a product guarantee, and requesting write access the app never uses would itself be a trust violation worth flagging even before any code path uses it |
| `.ics` URL transmitted/stored in plaintext including any embedded credentials (some calendar-subscription URLs embed a secret token in the path) | Information Disclosure | Store the subscribed `.ics` URL the same way other sensitive-ish local config is stored today (Hive, on-device only, never logged) — do not `debugPrint` the full URL anywhere a token might appear in logs |

## Sources

### Primary (HIGH confidence)
- None — the automated `package-legitimacy check` seam does not cover the `pub` ecosystem this phase
  needs, so no claim in this document reached the tool-verified `[VERIFIED: npm registry]`-equivalent
  bar. In-repo code citations (file path + line range + verbatim quote) are the closest equivalent to
  HIGH confidence available this session and are marked `[VERIFIED: <path>:<lines>]` throughout.

### Secondary (MEDIUM confidence) — `[CITED: ...]` throughout this document
- `pub.dev/packages/device_calendar_plus` and its `/changelog`, `/example`, `/score`, and
  `/documentation/*` pages — fetched this session
- `pub.dev/api/packages/<name>` (JSON registry API) — queried directly via `curl` this session for
  `device_calendar_plus`, `firstfloor_calendar`, `enough_icalendar`, `icalendar_parser`,
  `device_calendar`, `eventide`, `flutter_timezone`
- `api.github.com/repos/bullet-to/device_calendar_plus`,
  `api.github.com/repos/firstfloorsoftware/firstfloor_calendar` (→ redirect →
  `api.github.com/repositories/1076056150`), `api.github.com/repos/sncf-connect-tech/eventide` —
  queried directly this session
- `github.com/bullet-to/device_calendar_plus` — fetched this session
- `pub.dev/packages/eventide` — fetched this session, confirming recurrence still unimplemented
- Apple Developer Documentation, `NSCalendarsFullAccessUsageDescription` /
  `NSCalendarsUsageDescription` — web-searched this session
- `pub.dev/packages/firstfloor_calendar`, `/changelog`, `/example` — fetched this session
- `pub.dev/packages/enough_icalendar` — fetched this session

### Tertiary (LOW confidence)
- Any claim not independently cross-checked against a second source in this session — flagged
  explicitly in the Assumptions Log above rather than left implicit.

## Metadata

**Confidence breakdown:**
- Standard stack (device plugin choice): MEDIUM — cross-checked across pub.dev metadata, GitHub API,
  and the ROADMAP's own prior research; not device-executed
- Standard stack (ICS package choice): LOW-MEDIUM — genuinely unresolved, flagged for a spike rather
  than locked
- Architecture (CalendarSource abstraction, CommitmentBlock mapping): HIGH within this session's
  reach — grounded in code read directly (`commitment_block.dart`, `commitment_block_repository.dart`,
  `commitment_form_sheet.dart`, `commitments_notifier.dart`, `schedule_generator.dart`,
  `schedule_notifier.dart`, `checkin_screen.dart`, `main.dart`, `app_settings.dart`,
  `notification_service.dart`, `commitment_window.dart`) — but the recurrence-exception question that
  motivates the architecture is itself CITED, not verified (Pitfall 1)
- Pitfalls: HIGH for the five grounded in this session's code reads (Pitfalls 2-6); MEDIUM for
  Pitfall 1 (grounded in the *absence* of device-build capability, itself directly verified via
  `flutter doctor -v`)

**Research date:** 2026-09-11
**Valid until:** ~2026-09-25 (14 days) for the package-choice claims specifically —
`device_calendar_plus` shipped 8 releases in the ~2 months before this research and is evidently
moving fast; re-check versions/changelogs at plan time if planning starts more than ~2 weeks after
this document. The architectural recommendations (CalendarSource shape, mapping rules, engine
boundary) are stable regardless of package churn.
