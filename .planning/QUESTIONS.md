
## 2026-11-10 — v1.7 (watch): the MacBook keeps sleeping (BLOCKING phases 39-41 verification)

All v1.7 code is written and unit-tested on `v1.7-watch` (1128 green). Every remaining check needs Xcode: the
`flutter build ios --no-codesign` with the embedded watch app, the watch Simulator screenshots, and the device
install. `dans-macbook-air` keeps dropping off the tailnet (asleep). An ssh watcher on danserver runs
`caffeinate -dimsu` the moment it reappears.

**Dan:** open the MacBook lid and leave it on power, awake. That is all; the agent does the rest over ssh.
