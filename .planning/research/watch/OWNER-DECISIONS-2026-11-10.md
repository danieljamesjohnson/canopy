# v1.7 On Your Wrist: owner decisions (2026-11-10)

These answer section 8 of WATCH-RESEARCH.md. They supersede the earlier "Tier 0 notifications first, then decide
after a week" recommendation.

## The goal, in the owner's words

> "what i want is to be able to look down at my watch and remind myself what im doing. so a buzz alert won't be
> enough. this is one of the critical features, so we gotta figure out how to make it work."

## Answers

1. **Watch:** Apple Watch Series 7 on watchOS 26.3.
   - WidgetKit complications and Smart Stack work on it.
   - **Double Tap and wrist flick do not.** They need a Series 9 / Ultra 2 or later, so do not design around them.
2. **Scope ceiling:** a watch app with a **complication as the core deliverable** (Tier 2). A buzz on its own was
   rejected. A Live Activity was not adopted as the base: it has an 8-hour cap, and without a push server it cannot
   move to the next chunk while the app is asleep. It may come later as an extra.
3. **Developer account:** team H637CCV562 is a **paid** Apple Developer Program membership, so App Groups and
   non-expiring installs are available.
4. **Notification cadence:** deferred. Buzzing is now the last phase, an add-on.
5. **Privacy:** real meeting and goal titles **may** appear on the watch.
6. **Outbox latency:** not yet asked explicitly. The owner accepted the plan summary that "taps queue up and get
   applied when the app next opens". Confirm this when planning the Complete/Skip phase.
7. **Wear OS:** treated as out of scope; not contested.
8. **CI cost:** not yet asked.

## Revised phase order (to replace ROADMAP phases 38–42)

1. **Wrist timeline and outbox, pure Dart.** Build the day as a list of `(instant, state)` entries, and keep an outbox
   of taps replayed with the tap time. Fully testable on danserver.
2. **Watch app and complication, read-only.** The phone sends the timeline over WCSession. The watch WidgetKit
   timeline flips the "now / next" display at each chunk boundary without the phone. Includes a Smart Stack widget
   and a "now / next" screen. **This is the feature the owner asked for.**
3. **Complete/Skip from the wrist**, through the outbox.
4. **Buzz at chunk changes**, an optional add-on.
