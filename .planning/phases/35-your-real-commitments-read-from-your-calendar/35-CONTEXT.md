# Phase 35: Your Real Commitments, Read From Your Calendar - Context

**Gathered:** 2026-09-11
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped via `workflow.skip_discuss`)

<domain>
## Phase Boundary

The commitments Canopy schedules around come from the calendar the user already keeps, instead of
being typed in twice — read-only, on every platform where a calendar exists, and degrading honestly
on the platforms where one does not.

**This is an input-layer phase.** `schedule_generator.dart` already consumes `CommitmentBlock` and
already chunks work up inside a commitment's window (`COMMITBREAK-01`, D-30-04). Calendar events map
onto that existing model. **Touching the generator means you have misunderstood the phase.**

**Why it is the thing blocking real use.** `CommitmentBlock` already supports recurring weekly blocks
and one-off dated ones, so a *stable* week is a one-time setup that works today. The failure mode is
ad-hoc meetings: miss one and the generator schedules work chunks straight over it, and the day is
wrong in the way that makes someone stop trusting the app.

</domain>

<decisions>
## Implementation Decisions

### Already ruled by the owner — do NOT re-litigate

These are in the ROADMAP entry as taken decisions, not suggestions. They were researched on
2026-09-11 rather than assumed.

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

4. **One device integration covers both vendors.** EventKit and CalendarContract read the *device's
   calendar store*, which already aggregates every account the user has added. Google needs no OAuth
   and no separate integration, **provided the account is added at OS level**.

   **Do not ask the owner whether his Google account is added — show him.** The settings surface
   lists whatever calendars the device actually exposes, with checkboxes. If Google is there he ticks
   it; if not, that is an OS Settings fix, not a code path. This replaces a question with an
   observation — the same move that closed Phase 32's G-32-05 after three rounds of non-answers.

### A scope boundary was deliberately MOVED — do not refuse on it

`PROJECT.md` listed calendar sync as out of scope / v2. The owner promoted it to v1 on 2026-09-11:
*"it needs to be able to read from apple calendar and google calendar. as a v1."* The Out of Scope
entry is struck through with the ruling recorded beside it. **Do not "helpfully" decline to build
this** on the strength of a boundary that has been consciously moved.

It does **not** reopen the AI boundary. A calendar is deterministic input to the same rule-based
engine — the opposite of a model guessing at your day. CLAUDE.md's "dumb on purpose" rule stands.

### Claude's discretion

Everything not fixed above is an implementation choice, guided by the ROADMAP success criteria and
this codebase's conventions. Discuss was skipped per `workflow.skip_discuss`.

</decisions>

<code_context>
## Existing Code Insights

Detailed codebase context is gathered during plan-phase research. What is already known and must
hold:

- **`CommitmentBlock` is the target model and it already exists**, supporting recurring weekly blocks
  and one-off dated ones. It stores **minutes-from-midnight**, which is the shape any event→block
  mapping must land in.
- **`lib/data/repositories/` is the precedent** for the `CalendarSource` interface: one interface per
  aggregate, with `hive_*` and `in_memory_*` implementations side by side.
- **`schedule_generator.dart` is out of bounds.** It already does the work — D-30-04 /
  `COMMITBREAK-01` applies the 25+5 lattice inside a commitment window, seeded from the block's own
  unrounded start.
- **`Info.plist` currently has neither calendar usage description** —
  `NSCalendarsFullAccessUsageDescription` (iOS 17+) and its pre-17 counterpart are both needed.
- **`com.example.canopy` is still the bundle identifier.** Out of scope here; noted because it blocks
  any future App Store distribution.

</code_context>

<specifics>
## Specific Ideas

### Requirements (from ROADMAP)

- **CAL-01** — commitments can be imported from the device's calendar without retyping
- **CAL-02** — the user chooses which calendars feed the schedule, from the list the device actually
  exposes
- **CAL-03** — Canopy never writes to the user's calendar
- **CAL-04** — a platform with no calendar access, or a denied permission, still gives a fully usable
  app with hand-entered commitments

### Open questions routed to research — these are genuinely unsettled

1. **Recurrence, end to end.** `device_calendar_plus` advertises full RRULE. Verify it against a real
   recurring event, including exceptions ("this and following", a single moved occurrence). This is
   the load-bearing capability and the reason `eventide` was rejected.
2. **Event → `CommitmentBlock` mapping.** All-day events (a whole day blocked, or ignored?).
   Timezones — `CommitmentBlock` stores minutes-from-midnight and the engine has **already been
   bitten once** by a time-of-day normalisation bug (SEED-006: `weekStart` did not normalise, so a
   Monday completion never counted toward its week). Declined invitations. Overlapping events.
   Multi-day events. Events with no end time.
3. **Are imported commitments editable in Canopy?** If the user edits one, the next sync overwrites
   it. Read-only-with-a-reason is probably right, but it is a real UX decision, not an obvious one.
4. **Sync trigger.** On check-in, on app resume, on a timer? The app is local-first and offline by
   design; a stale calendar must **degrade visibly rather than silently**.

### Constraints

- **Nothing writes to the user's calendar, ever.** Read-only is a product guarantee, not an
  implementation detail.
- **Permissions are a first-class surface.** A denied permission must leave the app fully usable with
  hand-entered commitments.
- **The build workflow splits.** `flutter analyze` and the full 740-test suite run on danserver, but
  **iOS cannot be compiled here at all** — no Xcode, and there never will be. That happens on the
  owner's MacBook. Plan for the owner as the compile-and-run step, and **do not claim an iOS build
  works without him running it.**

### Traps this phase is specifically exposed to

- **CLAUDE.md trap #4 applies if any UAT judges generated days.** An already-generated day is never
  regenerated on load, so a UAT that imports a calendar event and then looks at today's timeline
  **must ⟳ Re-check-in first**, stated as a mandatory first step in the UAT's own instructions. This
  has cost a real round trip before.
- **Assertions that cannot fail.** A test that asserts a mapped `CommitmentBlock`'s start equals the
  constant the mapper used is symbolic and cannot fail. Encode the claim, not the constant — and
  mutation-test the load-bearing assertion by introducing the defect and watching it go red.
- **The suite can test the one input where the bug cannot fire.** SEED-006 survived 3248 green lines
  because every generator fixture builds its date at midnight — the single value the bug exempted.
  Timezone and all-day handling here is the same shape of risk.

</specifics>

<deferred>
## Deferred Ideas

- **Writing to the user's calendar** — permanently out of scope, by product guarantee (CAL-03).
- **Google Calendar API / OAuth as a separate integration** — unnecessary by decision 4 above, as
  long as the account is added at OS level.
- **`com.example.canopy` bundle identifier** — noted in the ROADMAP as out of scope for this phase.
- **A federated first-party Flutter plugin** — considered and rejected with reasons (decision 2).

</deferred>
