#!/bin/bash
# Emberpit QA test suite. Usage: tests/run_all.sh [--soak]   (exit 0 = all green)
# --soak also runs the quick crash soak (tools/soak.py, ~2-3 min on 4 cores).
cd "$(dirname "$0")/.."
set -o pipefail
rc=0
# a SCRIPT ERROR anywhere fails the suite, even if every check passed
filter() { tee "$1" | grep -E "FAIL|RESULT|SCRIPT ERROR"; ! grep -q "SCRIPT ERROR" "$1"; }
L=$(mktemp -d)
godot --headless --path . --import >/dev/null 2>&1
echo "== logic (headless)"
timeout 400 godot --headless --path . res://tests/test_logic.tscn 2>&1 | filter $L/logic.log || rc=1
echo "== regressions (headless)"
timeout 600 godot --headless --path . res://tests/test_regressions.tscn 2>&1 | filter $L/regressions.log || rc=1
echo "== allies and duels (headless)"
timeout 900 godot --headless --path . res://tests/test_party.tscn 2>&1 | filter $L/party.log || rc=1
echo "== flows + touch (xvfb, 2400x1080)"
timeout 400 xvfb-run -a -s "-screen 0 2400x1080x24" godot --rendering-driver opengl3 --path . --resolution 2400x1080 \
  res://tests/test_flows.tscn -- --weather=clear 2>&1 | filter $L/flows.log || rc=1
if [ "$1" == "--soak" ]; then
  echo "== crash soak (quick)"
  python3 tools/soak.py --seconds 60 || rc=1
fi
echo "logs: $L"
exit $rc
