# Canopy — Privacy Policy

*Last updated: 9 November 2026*

Canopy is a personal scheduling app made by Dan Johnson (dan@danjjohnson.com). This page explains what it
does with your data, including the Google Calendar data it can read.

## The short version

Canopy runs entirely on your device. There is no Canopy server, account, analytics, advertising or
tracking. Nothing you enter, and nothing read from your calendars, is sent to the developer or to anyone
else.

## Google Calendar data

If you choose **Connect Google Calendar**, Canopy asks Google for one permission:
`https://www.googleapis.com/auth/calendar.readonly`. It is read-only, so Canopy cannot create, change or
delete anything in your Google Calendar.

- **What is read:** the list of your calendars, and for the calendars you tick, each event's title, start
  and end times, and whether it was cancelled or is all-day.
- **What it is used for:** only to place those events as fixed blocks on your schedule inside the app.
- **Where it is kept:** in the app's private storage on your device. This includes the sign-in tokens
  Google issues, which let the app refresh your calendar.
- **Who it is shared with:** no one. Canopy talks only to Google's own servers (`oauth2.googleapis.com`
  and `www.googleapis.com`) to sign in and read events. It does not transfer, sell, or use Google user data
  for advertising, and no human reads it.

Canopy's use and transfer of information received from Google APIs adheres to the
[Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy),
including the Limited Use requirements.

## Other calendars

On iPhone, Canopy can also read calendars already on your device, through iOS's calendar permission. On
other platforms it can read a calendar feed (`.ics`) URL that you paste in. The same rules apply: read
only, stored on your device, shared with no one.

## Removing your data

- Use **Disconnect** in Settings → Calendars to stop Canopy reading your Google Calendar. This deletes
  the stored Google sign-in tokens and every meeting Canopy imported from Google from your device.
  Nothing in your Google Calendar itself is changed.
- Revoke Canopy's access at any time at <https://myaccount.google.com/permissions>.
- Deleting the app deletes everything it stored.

## Contact

Questions: dan@danjjohnson.com. Source code: <https://github.com/danieljamesjohnson/canopy>.
