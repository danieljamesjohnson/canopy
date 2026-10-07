#!/bin/bash
# ios-build-agent.sh — let an agent on danserver start a real iOS DEVICE build over ssh.
#
# THE PROBLEM THIS SOLVES
# -----------------------
# `ssh dans-macbook-air tools/build-ios.sh build` always fails signing:
#
#     codesign ... Flutter.framework/Flutter: errSecInternalComponent
#     Failed to codesign ... ** BUILD FAILED **
#
# Measured 2026-10-07: this is NOT a keychain-lock problem and NOT a bad identity.
# `security find-identity -v -p codesigning` lists the right identity from the ssh
# session, and it is the same hash codesign tries to use. Unlocking the keychain,
# and `security set-key-partition-list` + clicking "Always Allow", both changed
# nothing — a scratch-file `codesign --force --sign <id> /tmp/probe` still returned
# errSecInternalComponent after each.
#
# The actual cause is the launchd DOMAIN:
#
#     ssh session   -> `launchctl managername` = Background
#     GUI terminal  -> `launchctl managername` = Aqua
#
# The Background domain has no window server and macOS will not release a
# login-keychain private key to it. `security show-keychain-info` from ssh says
# "User interaction is not allowed." You cannot unlock your way out of the wrong
# domain.
#
# THE FIX: don't sign from Background — get the build to EXECUTE in Aqua.
# A LaunchAgent registered in the `gui/<uid>` domain runs in Aqua. An ssh session
# can trigger it with `launchctl kickstart` WITHOUT root and WITHOUT any stored
# password. The build then signs with the same access a GUI terminal has.
#
# USAGE
# -----
#   tools/ios-build-agent.sh install     # once, from a GUI terminal (Ghostty)
#   tools/ios-build-agent.sh diagnose    # log session context + a codesign probe
#   tools/ios-build-agent.sh build       # run a build right now, in this session
#   tools/ios-build-agent.sh status      # is the agent registered? last log?
#   tools/ios-build-agent.sh uninstall   # remove the agent
#
# Then, from danserver over ssh:
#   launchctl kickstart -p gui/$(id -u)/com.canopy.iosbuild
#   tail -f ~/Library/Logs/canopy-ios-build.log
#
# Nothing here stores a password or weakens signing. The agent runs as you, in
# your own GUI session, only when explicitly kicked.

set -uo pipefail

LABEL="com.canopy.iosbuild"
UID_NUM="$(id -u)"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
RUNNER="$HOME/Library/Application Support/canopy/ios-build-runner.sh"
LOG_DIR="$HOME/Library/Logs"
BUILD_LOG="$LOG_DIR/canopy-ios-build.log"
DIAG_LOG="$LOG_DIR/canopy-ios-signing-diagnosis.log"
REPO="$HOME/CodeProjects/canopy"

# The phone's *flutter* device id (a UDID). NOTE this is NOT the same string as
# its devicectl CoreDevice identifier (66110258-0097-5E64-9C90-B9815966D67E).
# `flutter run -d` wants this one; `devicectl --device` wants the other.
DEVICE_UDID="${CANOPY_IOS_DEVICE:-00008130-001014892891401C}"

BREW_PATH="/opt/homebrew/bin:$HOME/Library/Python/3.9/bin"

say() { printf '%s\n' "$*"; }

probe_codesign() {
  # Returns 0 if signing works in the CURRENT session, 1 if blocked.
  local identity tmp out
  identity="$(security find-identity -v -p codesigning 2>/dev/null \
    | awk '/Apple Development|Apple Distribution/ {gsub(/[()]/,"",$2); print $2; exit}')"
  if [[ -z "$identity" ]]; then
    say "  no codesigning identity visible at all"
    return 1
  fi
  tmp="$(mktemp -d)"
  cp /bin/echo "$tmp/probe"
  out="$(/usr/bin/codesign --force --sign "$identity" "$tmp/probe" 2>&1)"
  rm -rf "$tmp"
  say "  identity: $identity"
  say "  codesign said: ${out:-<silent, which means success>}"
  if printf '%s' "$out" | grep -q 'errSecInternalComponent'; then
    return 1
  fi
  return 0
}

cmd_diagnose() {
  mkdir -p "$LOG_DIR"
  {
    say "=============================================================="
    say "canopy iOS signing diagnosis — $(date)"
    say "=============================================================="
    say ""
    say "WHO AND WHERE"
    say "  user:          $(whoami) (uid $UID_NUM)"
    say "  hostname:      $(hostname)"
    say "  TERM:          ${TERM:-<unset>}"
    say "  SSH_TTY:       ${SSH_TTY:-<unset>}"
    say "  SSH_CONNECTION:${SSH_CONNECTION:-<unset>}"
    say ""
    say "THE DECIDING FACT — launchd domain"
    local mgr
    mgr="$(launchctl managername 2>&1)"
    say "  launchctl managername: $mgr"
    if [[ "$mgr" == "Aqua" ]]; then
      say "  -> Aqua. This session CAN reach login-keychain private keys."
    else
      say "  -> NOT Aqua ($mgr). This session is expected to FAIL signing."
      say "     This is the root cause, not a keychain-lock problem."
    fi
    say ""
    say "KEYCHAIN"
    say "  default: $(security default-keychain 2>&1 | tr -d ' \"')"
    say "  show-keychain-info: $(security show-keychain-info \
      "$HOME/Library/Keychains/login.keychain-db" 2>&1)"
    say "    ('User interaction is not allowed' here is a SYMPTOM of the domain,"
    say "     not proof the keychain is locked.)"
    say ""
    say "IDENTITIES VISIBLE"
    security find-identity -v -p codesigning 2>&1 | sed 's/^/  /'
    say ""
    say "LIVE CODESIGN PROBE (the actual question)"
    if probe_codesign; then
      say "  VERDICT: SIGNING WORKS in this session"
    else
      say "  VERDICT: SIGNING BLOCKED in this session"
    fi
    say ""
    say "LAUNCHAGENT STATE"
    if [[ -f "$PLIST" ]]; then
      say "  plist present: $PLIST"
      say "  registered:    $(launchctl print "gui/$UID_NUM/$LABEL" >/dev/null 2>&1 \
        && echo yes || echo no)"
    else
      say "  plist absent — run: tools/ios-build-agent.sh install"
    fi
    say ""
    say "TOOLCHAIN"
    say "  flutter: $(PATH="$BREW_PATH:$PATH" command -v flutter || echo '<not on PATH>')"
    say "  xcode:   $(xcode-select -p 2>&1)"
    say "  device:  $(xcrun devicectl list devices 2>/dev/null \
      | awk 'NR>2 && NF {print $1, $3, $(NF-2); exit}')"
    say ""
  } | tee -a "$DIAG_LOG"
  say "Written to: $DIAG_LOG"
}

write_runner() {
  mkdir -p "$(dirname "$RUNNER")" "$LOG_DIR"
  cat > "$RUNNER" <<RUNNER_EOF
#!/bin/bash
# Generated by tools/ios-build-agent.sh — runs the device build inside the Aqua
# session so codesign can reach the login keychain.
set -uo pipefail
export PATH="$BREW_PATH:/usr/bin:/bin:/usr/sbin:/sbin"
exec >> "$BUILD_LOG" 2>&1
echo ""
echo "=============================================================="
echo "BUILD START \$(date)  (triggered via LaunchAgent)"
echo "  launchctl managername: \$(launchctl managername 2>&1)"
echo "=============================================================="
cd "$REPO" || { echo "FATAL: no repo at $REPO"; exit 1; }
echo "--- HEAD: \$(git log --oneline -1) ---"
./tools/build-ios.sh build --debug
RC=\$?
echo "--- build-ios.sh exit=\$RC ---"
if [[ \$RC -eq 0 ]]; then
  APP="\$(ls -d "$REPO"/build/ios/Debug-iphoneos/*.app 2>/dev/null | head -1)"
  echo "--- app: \${APP:-<none found>} ---"
  if [[ -n "\$APP" ]]; then
    echo "--- installing to $DEVICE_UDID ---"
    xcrun devicectl device install app --device "\${CANOPY_DEVICECTL_ID:-66110258-0097-5E64-9C90-B9815966D67E}" "\$APP" 2>&1 | tail -20
    echo "--- install exit=\$? ---"
  fi
fi
echo "BUILD END \$(date) rc=\$RC"
RUNNER_EOF
  chmod +x "$RUNNER"
}

cmd_install() {
  local mgr
  mgr="$(launchctl managername 2>&1)"
  if [[ "$mgr" != "Aqua" ]]; then
    say "WARNING: installing from a '$mgr' session, not Aqua."
    say "The agent will still register, but run 'install' from a GUI terminal"
    say "(Ghostty) if anything behaves oddly."
  fi
  write_runner
  mkdir -p "$HOME/Library/LaunchAgents"
  cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array><string>$RUNNER</string></array>
  <key>RunAtLoad</key><false/>
  <key>KeepAlive</key><false/>
  <key>ProcessType</key><string>Interactive</string>
  <key>StandardOutPath</key><string>$LOG_DIR/canopy-ios-build.launchd.out</string>
  <key>StandardErrorPath</key><string>$LOG_DIR/canopy-ios-build.launchd.err</string>
</dict>
</plist>
PLIST_EOF

  launchctl bootout "gui/$UID_NUM/$LABEL" 2>/dev/null
  if launchctl bootstrap "gui/$UID_NUM" "$PLIST" 2>&1; then
    say "registered $LABEL in gui/$UID_NUM"
  else
    say "bootstrap reported a problem; checking anyway..."
  fi
  if launchctl print "gui/$UID_NUM/$LABEL" >/dev/null 2>&1; then
    say ""
    say "INSTALLED. From danserver over ssh, an agent can now run:"
    say "  launchctl kickstart -p gui/$UID_NUM/$LABEL"
    say "  tail -200 $BUILD_LOG"
  else
    say "FAILED to register. Paste the output above."
  fi
}

cmd_build() {
  write_runner
  say "running the build in THIS session ($(launchctl managername 2>&1))..."
  "$RUNNER"
  say "done — log: $BUILD_LOG"
}

cmd_status() {
  say "plist:      $([[ -f "$PLIST" ]] && echo present || echo absent)"
  say "registered: $(launchctl print "gui/$UID_NUM/$LABEL" >/dev/null 2>&1 \
    && echo yes || echo no)"
  say "session:    $(launchctl managername 2>&1)"
  if [[ -f "$BUILD_LOG" ]]; then
    say ""
    say "--- last 25 lines of $BUILD_LOG ---"
    tail -25 "$BUILD_LOG"
  else
    say "no build log yet at $BUILD_LOG"
  fi
}

cmd_uninstall() {
  launchctl bootout "gui/$UID_NUM/$LABEL" 2>/dev/null
  rm -f "$PLIST"
  say "removed $LABEL (runner and logs left in place)"
}

case "${1:-status}" in
  install)   cmd_install ;;
  diagnose)  cmd_diagnose ;;
  build)     cmd_build ;;
  status)    cmd_status ;;
  uninstall) cmd_uninstall ;;
  *) say "usage: $0 {install|diagnose|build|status|uninstall}"; exit 2 ;;
esac
