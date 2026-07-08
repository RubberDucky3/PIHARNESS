#!/usr/bin/env bash
# demo-07-skill-list.sh — Demo: skill list + show
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR"

echo "=============================================="
echo "  PIHARNESS Demo 7: Skills System"
echo "=============================================="
echo ""

# Step 1: List all skills
echo ">>> Command: ./piharness.sh skill list"
echo "    Shows all installed skills with version and usage."
echo ""
./piharness.sh skill list 2>&1
echo ""

# Step 2: Show a skill in detail
echo ">>> Command: ./piharness.sh skill show deploy"
echo "    Shows the deploy skill's full instructions."
echo ""
./piharness.sh skill show deploy 2>&1 || echo "(skill may not exist)"
echo ""

# Step 3: Show learn suggest
echo ">>> Command: ./piharness.sh learn suggest"
echo "    Suggests new skills based on task pattern clusters."
echo ""
./piharness.sh learn suggest 2>&1 || echo "(learn suggest output)"
echo ""

echo ">>> Skills are the heart of PIHARNESS self-evolution:"
echo "    - Repeated tasks auto-extract into reusable skills"
echo "    - Skills include trigger patterns, description, and usage count"
echo "    - The orchestrator checks skills before spawning workers"
echo "    - Overnight 'nightly' maintenance evolves the skill library"
echo ""
echo "=============================================="
echo "  Demo 7 Complete"
echo "=============================================="
