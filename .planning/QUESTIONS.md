
## 2026-11-10 — v1.7 (watch): the MacBook keeps sleeping (BLOCKING phases 39-41 verification)

All v1.7 code is written and unit-tested on `v1.7-watch` (1128 green). Every remaining check needs Xcode: the
`flutter build ios --no-codesign` with the embedded watch app, the watch Simulator screenshots, and the device
install. `dans-macbook-air` keeps dropping off the tailnet (asleep). An ssh watcher on danserver runs
`caffeinate -dimsu` the moment it reappears.

**Dan:** open the MacBook lid and leave it on power, awake. That is all; the agent does the rest over ssh.

## 2026-11-10 — v1.7 (watch): sign Xcode into your Apple ID (BLOCKING the install to your watch)

The Mac is awake now, thank you. The watch app builds (`flutter build ios --no-codesign` passes; Simulator
screenshots in `phases/39-watch-app-and-complication/media/`). The **signed** build fails:

    Error (Xcode): No Accounts: Add a new account in Accounts settings.
    Provisioning profile "iOS Team Provisioning Profile: *" doesn't include the App Groups capability.

Xcode on the MacBook has no Apple ID signed in, so signing falls back to the wildcard team profile, which can never
carry App Groups. The complication needs an App Group: it is how the watch app hands the day's snapshot to the
complication. Only you can add your account.

**Dan:** on the MacBook, Xcode → Settings → Accounts → **+** → Apple ID → sign in with the account on team
H637CCV562. That is all. The agent's next build then registers the watch App IDs and the App Group automatically.
Also, for the install: the iPhone must be **unlocked and connected** (`devicectl` currently shows it "available
(paired)", not "connected").
