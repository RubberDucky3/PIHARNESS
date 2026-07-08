#!/usr/bin/env bash
# demo-05-supervise.sh — Demo: orchestrator supervision with auto-handoff
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR"

echo "=============================================="
echo "  PIHARNESS Demo 5: Orchestrator Supervision"
echo "=============================================="
echo ""

# Step 1: Show supervise help
echo ">>> What is supervise?"
echo "    Wraps a long-running orchestrator task with token-limit"
echo "    monitoring and auto-handoff to the next runtime."
echo ""

# Step 2: Show the command
echo ">>> Command:"
echo "    ./piharness.sh supervise \"Build and deploy the app\" --timeout 1800"
echo ""
echo "    When the current runtime hits its token limit:"
echo "      1. State is compacted into a handoff brief"
echo "      2. Next runtime in chain picks up seamlessly"
echo "      3. Runtime chain: pi → opencode → gemini → codex → droid → ollama → claude"
echo ""

# Step 3: Simulate a short supervise run
echo ">>> Running a brief supervise session..."
echo "    (limited to 30 seconds for the demo)"
echo ""
echo "--- supervise output ---"
./piharness.sh supervise "echo 'PIHARNESS supervise demo'" --timeout 30 2>&1 || true
echo "--- end supervise output ---"
echo ""

# Step 4: Show the handoff flow
echo ">>> Auto-handoff preserves:"
echo "    - Current task state and progress"
echo "    - Worker relationships and surface IDs"
echo "    - Runtime chain position"
echo "    - Error history and cooldowns"
echo ""
echo "=============================================="
echo "  Demo 5 Complete"
echo "=============================================="
