# Phase 41: Optional Buzz at Chunk Changes — Context

**Gathered:** 2026-11-10. The brief: "keep it modest; skip if time or risk is high."

- **D-41-01 The watch schedules it, not the phone.** The watch already holds the day's timeline, so it schedules one
  local notification per future `active` entry and reschedules it on every snapshot. This needs no phone, no Dart and
  no reserved phone-notification ID range, and it keeps clear of the iPhone's 64-pending cap and its existing
  morning, mid-day and evening notifications.
- **D-41-02 Off by default.** It is a toggle at the bottom of the watch's now screen ("Buzz when a chunk starts").
  The owner rejected a buzz as the feature, so it stays opt-in.
- **D-41-03 Content.** The title is the chunk's title; the body is "Until 10:25 · then Short break". Breaks buzz too,
  because a break starting is a chunk change. Narrowing that is the owner's cadence call, deferred by decision 4.
- Risk is low: about 60 lines of Swift, isolated in `ios/CanopyWatch/Buzz.swift`, with no effect on anything else
  when it is off.
