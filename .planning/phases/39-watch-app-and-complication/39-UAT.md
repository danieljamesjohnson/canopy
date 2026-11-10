---
phase: 39-watch-app-and-complication
covers: [39, 40, 41]
status: awaiting owner
---

# On Your Wrist: owner UAT (Phases 39, 40, 41)

What you are checking: **look at your watch face and see what you're doing.** About 10 minutes, with your iPhone
and your Series 7.

## Before you start (one time)

1. **The agent installs Canopy to your iPhone** from the Mac. The watch app rides along. If the watch does not have
   it within a few minutes, open the **Watch** app on the iPhone → scroll to **Available Apps** → **Canopy** →
   **Install**.
2. If watchOS asks, turn on **Developer Mode** on the watch: Settings → Privacy & Security → Developer Mode → on.
   The watch restarts.
3. **Add the complication.** Long-press your watch face → **Edit** → swipe to the complications page → tap the
   **large rectangular slot** (Modular, Infograph Modular, Smart Stack faces) → scroll to **Canopy** →
   **Canopy · Now**. Press the crown to save.

## 1. MANDATORY FIRST: Re-check-in on the phone

The watch shows the schedule the phone *saved*, and the phone only rebuilds the day at check-in (CLAUDE.md trap #4).
Open Canopy on the iPhone → Today → **⟳ Re-check-in**, and finish it. Then open **Canopy on the watch**. The bottom
line says **"Synced <time>"** and that time should be just now. If it isn't, the snapshot did not arrive; stop and
tell the agent.

## 2. Glance (Phase 39, the core feature)

| # | Do | You should see |
|---|----|----------------|
| 2a | Lower your wrist, then raise it to look at the face | The rectangular complication: **NOW**, the chunk's title (your real goal or meeting name), **"mm:ss left"** counting down live, and **"then <next>"** |
| 2b | Compare with Today on the phone | Same chunk, same next chunk, same end time. They must never disagree |
| 2c | Wait for the chunk's end time, **with the iPhone locked in another room** | The complication flips to the next chunk **by itself**: a break reads **RESTING**, a gap reads **UP NEXT · at hh:mm** |
| 2d | Optional: add Canopy to a **circular**, **corner** or **inline** slot | Circular: a ring draining with an icon. Corner: an icon plus a countdown. Inline: "Title · mm:ss" |
| 2e | Turn the crown up from the watch face (Smart Stack) | Canopy sits near the top while a chunk is running |
| 2f | After your last chunk | **DONE · Day complete**. After midnight, **Check in on iPhone** (never yesterday's last chunk) |

## 3. Tap it done (Phase 40)

| # | Do | You should see |
|---|----|----------------|
| 3a | On the watch, open Canopy while a work chunk is running → **Done** | A tap haptic; the buttons become **"Sent to iPhone"**; the complication's kicker becomes **SENT ✓** |
| 3b | With the iPhone nearby and unlocked, open Canopy on the phone | That chunk shows **completed**. If you finished early and a break followed, the break starts at the time you tapped, not the time you opened the phone |
| 3c | Within a few seconds | The watch moves on: the next chunk is NOW, and "Sent" is gone |
| 3d | **Phone out of range:** leave the iPhone in another room (or put the watch in Airplane Mode with Bluetooth off) → **Skip** a chunk → come back → open Canopy on the phone | The skip is applied with the time you tapped it |
| 3e | On a **break** | Only **Skip** is offered. On a **meal**, nothing is offered (as on the phone) |

## 4. Buzz (Phase 41, optional, off by default)

| # | Do | You should see |
|---|----|----------------|
| 4a | Watch app → scroll to the bottom → **Buzz when a chunk starts** → on → Allow | — |
| 4b | Wait for the next chunk to start | A tap on the wrist: "<Title>", then "Until hh:mm · then <next>" |
| 4c | Turn it off | No more buzzes |

## Report

Pass/fail per row, and a photo of the face for 2a. Anything that disagrees between phone and watch (2b) is the most
important thing to report.
