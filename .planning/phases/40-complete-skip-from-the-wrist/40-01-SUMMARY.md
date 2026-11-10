---
phase: 40-complete-skip-from-the-wrist
plan: 01
subsystem: watch
requires: [38-01, 39-01]
provides: ["MethodChannelWristOutboxStore", "WristOutboxCoordinator", "WristOutbox (Swift file store)", "watch Done/Skip + pending overlay"]
---

# 40-01 Summary

- **Dart:** `MethodChannelWristOutboxStore` and `WristOutboxCoordinator`, which drains at start, on resume and on
  `outboxChanged`. 5 tests; mutation: 4/4 killed (C1 start drain, C2 `outboxChanged`, C3 resume drain, C4 corrupt
  file).
- **Swift (phone):** one atomic JSON file per tap, written *before* replying to `sendMessage`;
  `didReceiveUserInfo` for the queued path; the `outboxPending`/`outboxRemove` channel methods.
- **Swift (watch):** Done/Skip with the phone's gates (breaks skip-only, meals nothing), a success haptic,
  "Sent to iPhone" and "SENT ✓" overlays, and pending marks that clear when a snapshot no longer offers the chunk an
  action.
- **Found while writing it:** the watch's `sendMessage` must carry a reply handler. Without one, the phone's
  `didReceiveMessage:replyHandler:` is never called and the tap is silently lost.
- It compiles in both the watch and phone builds (Mac). Delivery itself (`sendMessage` waking the phone,
  `transferUserInfo`) cannot be simulated; it is owner UAT §3.
