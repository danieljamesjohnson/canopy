#!/usr/bin/env bash
# Pull YOUR real calendar into the UAT build so the browser can read it.
#
# WHY THIS EXISTS
# ---------------
# Pasting a Google/Apple .ics URL straight into Canopy's web build does NOT work,
# and it is not a Canopy bug. `IcsCalendarSource` uses `http.get`, which on Flutter
# web is a browser fetch and therefore subject to CORS. Verified 2026-09-21:
#
#   $ curl -sI -H "Origin: http://danserver:8161" \
#       "https://calendar.google.com/calendar/ical/.../basic.ics"
#   HTTP/2 200
#   content-type: text/calendar; charset=utf-8
#   (no access-control-allow-origin header)
#
# 200 but no CORS header => the browser blocks the read. On iOS there is no CORS
# and the same URL works pasted directly.
#
# This script sidesteps it by fetching server-side and dropping the feed next to
# the app, so Canopy reads it SAME-ORIGIN and CORS never applies.
#
# USAGE
# -----
#   1. Get your calendar's private .ics address:
#        Google Calendar -> (hover your calendar) -> Options (three dots)
#          -> "Settings and sharing" -> scroll to "Integrate calendar"
#          -> copy "Secret address in iCal format"
#        Apple Calendar -> right-click the calendar -> "Share Calendar..."
#          -> tick "Public Calendar" -> copy the link (change webcal:// to https://)
#
#   2. Put it in the gitignored file (NOT in a commit, NOT in chat — anyone
#      holding this URL can read your calendar):
#        echo 'https://calendar.google.com/calendar/ical/..../basic.ics' \
#          > .uat-calendar-url
#        chmod 600 .uat-calendar-url
#
#   3. Run this:
#        ./tools/fetch-my-calendar.sh
#
#   4. In Canopy: Settings -> Calendars -> add feed URL:
#        http://danserver:8161/mycal.ics
#      Then ** tap the re-check-in button ** before judging Today. An
#      already-generated day is never regenerated on load (CLAUDE.md trap #4).
#
# Re-run this script any time you change your real calendar and want Canopy to
# see it — it is a snapshot, not a live subscription.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
URL_FILE="$REPO/.uat-calendar-url"
OUT="$REPO/build/web/mycal.ics"

if [[ ! -f "$URL_FILE" ]]; then
  cat >&2 <<EOF
ERROR: no calendar URL configured.

Create $URL_FILE containing your calendar's private .ics address, then re-run.
See the comments at the top of this script for where to find that address.

  echo 'https://calendar.google.com/calendar/ical/..../basic.ics' > .uat-calendar-url
  chmod 600 .uat-calendar-url

That file is gitignored. Do not paste the URL into a commit or a chat window —
anyone holding it can read your calendar.
EOF
  exit 1
fi

URL="$(tr -d '[:space:]' < "$URL_FILE")"

if [[ -z "$URL" ]]; then
  echo "ERROR: $URL_FILE is empty." >&2
  exit 1
fi

if [[ "$URL" == webcal://* ]]; then
  URL="https://${URL#webcal://}"
  echo "note: rewrote webcal:// -> https://"
fi

if [[ "$URL" != https://* ]]; then
  echo "ERROR: calendar URL must be https:// (got: ${URL%%:*}://...)" >&2
  exit 1
fi

if [[ ! -d "$REPO/build/web" ]]; then
  echo "ERROR: $REPO/build/web does not exist — build the web bundle first:" >&2
  echo "  flutter build web --debug --source-maps --pwa-strategy=none" >&2
  exit 1
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

# Deliberately not printing the URL — it is a read-credential for the calendar.
echo "fetching your calendar (url withheld from output)..."
if ! curl -fsSL --max-time 30 "$URL" -o "$TMP"; then
  echo "ERROR: fetch failed. Check the URL in $URL_FILE is current and still valid." >&2
  exit 1
fi

if ! grep -q "BEGIN:VCALENDAR" "$TMP"; then
  echo "ERROR: that URL did not return iCalendar data." >&2
  echo "       First line was: $(head -c 120 "$TMP")" >&2
  echo "       Make sure you copied the *iCal format* secret address, not the HTML share link." >&2
  exit 1
fi

mv "$TMP" "$OUT"
trap - EXIT

EVENTS=$(grep -c "^BEGIN:VEVENT" "$OUT" || true)
BYTES=$(wc -c < "$OUT" | tr -d ' ')

cat <<EOF

done: $EVENTS events, $BYTES bytes -> build/web/mycal.ics

In Canopy, add this feed URL (it is same-origin, so CORS does not apply):

    http://danserver:8161/mycal.ics

Then press the re-check-in button BEFORE judging today's timeline.
EOF
