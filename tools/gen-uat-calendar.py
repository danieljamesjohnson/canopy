#!/usr/bin/env python3
"""Generate the Phase 35 UAT calendar fixture, dated relative to TODAY.

Why this exists as a generator instead of a checked-in .ics with literal dates:
the original fixture was written on 2026-09-17 with every one-off event hardcoded
to that day. Four days later every one of them was in the past, the weekly series
fell on a Thursday, and today's timeline would have rendered EMPTY — so the owner
would have opened the UAT, seen nothing, and reasonably concluded the feature was
broken. A fixture that silently expires is worse than no fixture, because it fails
in the direction of a false negative.

Run this immediately before serving a UAT build:

    python3 tools/gen-uat-calendar.py > build/web/sample.ics

Everything is emitted in UTC (`Z`-suffixed) EXCEPT two events that deliberately
exercise the other two RFC 5545 DTSTART forms, because those are the forms a real
Google feed actually sends and the ones Phase 35 had to fix (WINDOWS.md entry 2).
"""

import datetime as dt
import sys

# Local wall-clock "today". The app converts to local via tz.local, and the point
# of the fixture is that the owner sees these at the stated clock times on HIS day.
today = dt.date.today()


def z(d: dt.date, hh: int, mm: int = 0) -> str:
    """A UTC-suffixed value for an intended LOCAL clock time.

    Takes the hour the owner should SEE and converts it to UTC, rather than
    emitting a literal UTC hour. Emitting literal UTC put events at 04:00 and
    06:00 local on a UTC-5 host — outside the 08:00-22:00 working day, so they
    never appeared on the timeline at all. A fixture whose events fall outside
    the visible day is indistinguishable from a broken importer.
    """
    naive_local = dt.datetime(d.year, d.month, d.day, hh, mm)
    utc = naive_local.astimezone().astimezone(dt.timezone.utc)
    return f"{utc:%Y%m%dT%H%M%S}Z"


def floating(d: dt.date, hh: int, mm: int = 0) -> str:
    """No Z, no TZID — 'this clock reading, wherever the viewer is'."""
    return f"{d:%Y%m%d}T{hh:02d}{mm:02d}00"


# The weekly series must have an occurrence TODAY, so anchor it several weeks back
# on the same weekday rather than on a fixed calendar date.
series_anchor = today - dt.timedelta(weeks=6)
# The EXDATE'd (deleted) occurrence is the NEXT one, so it is still in the future.
exdate_day = today + dt.timedelta(weeks=1)
# A second future occurrence proves an ordinary week still renders at the base time.
tomorrow = today + dt.timedelta(days=1)

out = []
A = out.append

A("BEGIN:VCALENDAR")
A("VERSION:2.0")
A("PRODID:-//Canopy UAT Fixture//35-06//EN")
A("CALSCALE:GREGORIAN")
A("X-WR-CALNAME:Canopy UAT Sample Feed")
A("")

# --- The recurring series, with one occurrence MOVED and one DELETED -----------
# This is UAT step 7b's evidence. RECURRENCE-ID and EXDATE are PROVEN unsupported
# on the ICS path (35-02, WINDOWS.md entry 1), so the expected, deliberate result
# is that today shows this meeting TWICE: once at its original 14:00 and once at
# the 16:00 it was moved to. Seeing the duplicate IS the finding.
A("BEGIN:VEVENT")
A("UID:uat-weekly-standup@canopy.test")
A(f"DTSTAMP:{z(today, 8)}")
A(f"DTSTART:{z(series_anchor, 14)}")
A(f"DTEND:{z(series_anchor, 15)}")
A("SUMMARY:Weekly Sync: Product + Eng")
A("STATUS:CONFIRMED")
A("RRULE:FREQ=WEEKLY")
A(f"EXDATE:{z(exdate_day, 14)}")
A("END:VEVENT")
A("")

A("BEGIN:VEVENT")
A("UID:uat-weekly-standup@canopy.test")
A(f"RECURRENCE-ID:{z(today, 14)}")
A(f"DTSTAMP:{z(today, 8)}")
A(f"DTSTART:{z(today, 16)}")
A(f"DTEND:{z(today, 17)}")
A("SUMMARY:Weekly Sync: Product + Eng (moved)")
A("STATUS:CONFIRMED")
A("END:VEVENT")
A("")

# --- An ordinary timed event, UTC form ----------------------------------------
A("BEGIN:VEVENT")
A("UID:uat-1on1@canopy.test")
A(f"DTSTAMP:{z(today, 8)}")
A(f"DTSTART:{z(today, 11)}")
A(f"DTEND:{z(today, 11, 30)}")
A("SUMMARY:1:1 with Manager")
A("STATUS:CONFIRMED")
A("END:VEVENT")
A("")

# --- The TZID + VTIMEZONE form: what a real Google Calendar feed sends ---------
# WINDOWS.md entry 2. Proven correct in 35-02; here so the owner sees it land at
# the right clock time in a real browser, not just in a unit test.
A("BEGIN:VTIMEZONE")
A("TZID:America/Chicago")
A("BEGIN:DAYLIGHT")
A("TZOFFSETFROM:-0600")
A("TZOFFSETTO:-0500")
A("TZNAME:CDT")
A("DTSTART:19700308T020000")
A("RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU")
A("END:DAYLIGHT")
A("BEGIN:STANDARD")
A("TZOFFSETFROM:-0500")
A("TZOFFSETTO:-0600")
A("TZNAME:CST")
A("DTSTART:19701101T020000")
A("RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU")
A("END:STANDARD")
A("END:VTIMEZONE")
A("")

A("BEGIN:VEVENT")
A("UID:uat-zoned-review@canopy.test")
A(f"DTSTAMP:{z(today, 8)}")
A(f"DTSTART;TZID=America/Chicago:{floating(today, 15)}")
A(f"DTEND;TZID=America/Chicago:{floating(today, 15, 45)}")
A("SUMMARY:Product Review (zoned TZID)")
A("STATUS:CONFIRMED")
A("END:VEVENT")
A("")

# --- The floating form: no Z, no TZID -----------------------------------------
A("BEGIN:VEVENT")
A("UID:uat-floating@canopy.test")
A(f"DTSTAMP:{z(today, 8)}")
A(f"DTSTART:{floating(today, 17)}")
A(f"DTEND:{floating(today, 17, 30)}")
A("SUMMARY:Design Review (floating time)")
A("STATUS:CONFIRMED")
A("END:VEVENT")
A("")

# --- All-day: UAT step 7a's evidence ------------------------------------------
# D-35-06 was ruled import-as-blocking. The span it actually renders at is the
# question the owner is being asked, so this must be present or 7a is unanswerable.
A("BEGIN:VEVENT")
A("UID:uat-allday-offsite@canopy.test")
A(f"DTSTAMP:{z(today, 8)}")
A(f"DTSTART;VALUE=DATE:{today:%Y%m%d}")
A(f"DTEND;VALUE=DATE:{tomorrow:%Y%m%d}")
A("SUMMARY:Team Off-site (all day)")
A("STATUS:CONFIRMED")
A("END:VEVENT")
A("")

# --- Too short to schedule: lands in the skipped-events disclosure -------------
A("BEGIN:VEVENT")
A("UID:uat-quick-checkin@canopy.test")
A(f"DTSTAMP:{z(today, 8)}")
A(f"DTSTART:{z(today, 9)}")
A(f"DTEND:{z(today, 9, 10)}")
A("SUMMARY:Quick Check-in")
A("STATUS:CONFIRMED")
A("END:VEVENT")
A("")

# --- Cancelled: also skipped, with its own reason -----------------------------
A("BEGIN:VEVENT")
A("UID:uat-cancelled@canopy.test")
A(f"DTSTAMP:{z(today, 8)}")
A(f"DTSTART:{z(today, 19)}")
A(f"DTEND:{z(today, 20)}")
A("SUMMARY:Cancelled Thing")
A("STATUS:CANCELLED")
A("END:VEVENT")
A("")

A("END:VCALENDAR")

sys.stdout.write("\r\n".join(out) + "\r\n")
