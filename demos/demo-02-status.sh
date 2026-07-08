#!/usr/bin/env bash
# demo-02-status.sh — Demo: worker status dashboard
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR"

echo "=============================================="
echo "  PIHARNESS Demo 2: Status Dashboard"
echo "=============================================="
echo ""

# Step 1: Show the status command
echo ">>> Command: ./piharness.sh status"
echo "    Shows all registered workers and their current state"
echo ""

# Step 2: Show full status
./piharness.sh status 2>&1
echo ""

if command -v cmux &>/dev/null; then
  echo ">>> Bonus: cmux surface list"
  echo "    Underlying terminal pane layout:"
  cmux surface ls 2>&1 || cmux ls 2>&1 || echo "(cmux surfaces)"
  echo ""
fi

echo ">>> The dashboard shows:"
echo "    - Worker ID and label"
echo "    - Current status (idle/running/done)"
echo "    - Role (implementer/tester/reviewer)"
echo "    - Elapsed time"
echo "    - Last output"
echo ""
echo "=============================================="
echo "  Demo 2 Complete"
echo "=============================================="
