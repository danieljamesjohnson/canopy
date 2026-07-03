#!/usr/bin/env bash
# Canopy loop done-check: convergence = `flutter analyze` clean AND `flutter test` green.
# The AGENT runs this and it stamps .mission-control/check.json (the advisory
# convergence signal MC renders as a chip). MC never writes/infers this file.
# Write is atomic (tmp + rename) so the emitter never reads a half-written file.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1
export PATH="$PATH:/home/dan/development/flutter/bin"

CHECK_FILE=".mission-control/check.json"
AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

analyze_out="$(flutter analyze 2>&1)"
# Convergence bar: errors/warnings block; info-level lints are advisory (don't fail).
analyze_blocking="$(printf '%s\n' "$analyze_out" | grep -Ec '^[[:space:]]*(error|warning) •')"
[ "$analyze_blocking" -eq 0 ] && analyze_rc=0 || analyze_rc=1

test_out="$(flutter test 2>&1)";       test_rc=$?

# Pull a short test tally for the label if present (e.g. "All tests passed!" or "+N").
test_tally="$(printf '%s\n' "$test_out" | grep -Eo '\+[0-9]+( -[0-9]+)?' | tail -1)"

if [ "$analyze_rc" -eq 0 ] && [ "$test_rc" -eq 0 ]; then
  status="pass"
  label="analyze clean, tests ${test_tally:-passing}"
else
  status="fail"
  if [ "$analyze_rc" -ne 0 ] && [ "$test_rc" -ne 0 ]; then
    label="analyze + tests failing"
  elif [ "$analyze_rc" -ne 0 ]; then
    label="analyze failing"
  else
    label="tests failing ${test_tally}"
  fi
fi

tmp="$(mktemp "${CHECK_FILE}.XXXXXX")"
cat > "$tmp" <<EOF
{
  "status": "$status",
  "at": "$AT",
  "label": "$label"
}
EOF
mv -f "$tmp" "$CHECK_FILE"

echo "done-check: $status — $label (stamped $CHECK_FILE)"
[ "$status" = "pass" ]
