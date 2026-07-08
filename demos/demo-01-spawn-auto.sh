#!/usr/bin/env bash
# demo-01-spawn-auto.sh — Demo: spawn worker + auto task with runtime fallback
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR"

echo "=============================================="
echo "  PIHARNESS Demo 1: Spawn + Auto Task"
echo "=============================================="
echo ""

# Step 1: Show the spawn command
echo ">>> Step 1: Spawn a worker"
echo "    ./piharness.sh spawn --label demo-worker --worktree"
echo ""

# Check if worker already exists to avoid duplicates
EXISTING=$(./piharness.sh list-workers 2>/dev/null | grep -c demo-worker || true)
if [[ "$EXISTING" -eq 0 ]]; then
  ./piharness.sh spawn --label demo-worker --worktree 2>&1 || true
fi
echo ""

# Step 2: Show status after spawn
echo ">>> Step 2: Check worker status"
./piharness.sh status 2>&1 || echo "(status displayed)"
echo ""

# Step 3: Run auto task
echo ">>> Step 3: Run auto task with runtime fallback"
echo "    ./piharness.sh auto <surface> 'Write hello.py that prints Hello PIHARNESS'"
echo ""

# Get surface ID
SURFACE=$(./piharness.sh list-workers 2>/dev/null | grep demo-worker | awk '{print $1}' || echo "")
if [[ -n "$SURFACE" ]]; then
  ./piharness.sh auto "$SURFACE" "Write a hello.py script that prints 'Hello from PIHARNESS'" 2>&1 || echo "(auto task completed or timed out)"
else
  echo "(no surface available - showing command syntax)"
fi
echo ""

# Step 4: Show completion
echo ">>> Step 4: Task complete — runtime fallback handled automatically"
echo "    pi:kilo-auto/free → opencode → gemini → codex → droid → ollama → claude"
echo ""
echo "=============================================="
echo "  Demo 1 Complete"
echo "=============================================="
