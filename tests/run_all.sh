#!/bin/bash
# Emberpit QA test suite. Usage: tests/run_all.sh   (exit 0 = all green)
cd "$(dirname "$0")/.."
set -o pipefail
rc=0
echo "== logic (headless)"
timeout 400 godot --headless --path . res://tests/test_logic.tscn 2>&1 | grep -E "FAIL|RESULT" || rc=1
echo "== flows + touch (xvfb, 2400x1080)"
timeout 400 xvfb-run -a -s "-screen 0 2400x1080x24" godot --rendering-driver opengl3 --path . --resolution 2400x1080 \
  res://tests/test_flows.tscn -- --weather=clear 2>&1 | grep -E "FAIL|RESULT" || rc=1
exit $rc
