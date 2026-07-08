#!/usr/bin/env bash
# demo-04-self-evolve.sh — Demo: self-evolve + nightly maintenance
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR"

echo "=============================================="
echo "  PIHARNESS Demo 4: Self-Evolution + Nightly"
echo "=============================================="
echo ""

# Ensure we have task history for the demo
PIHARNESS_DIR="${PIHARNESS_DIR:-$HOME/.piharness}"
TASK_HISTORY="$PIHARNESS_DIR/task-history.json"

echo ">>> Pre-Seeded task history contains 6 login/auth tasks"
echo "    These share keywords (login, auth, user, token, etc.)"
echo ""

# Step 1: Show current skills count
echo ">>> Current skills installed:"
./piharness.sh skill list 2>&1
echo ""

# Step 2: Run self-evolve (dry-run first)
echo ">>> Step 1: Dry-run self-evolve to preview skill extraction"
echo "    ./piharness.sh self-evolve --dry-run --min-cluster 2"
echo ""
./piharness.sh self-evolve --dry-run --min-cluster 2 2>&1 || true
echo ""

# Step 3: Run self-evolve for real
echo ">>> Step 2: Extract skills for real"
echo "    ./piharness.sh self-evolve --min-cluster 2"
echo ""
./piharness.sh self-evolve --min-cluster 2 2>&1 || true
echo ""

# Step 4: Show updated skills
echo ">>> Step 3: Skills after evolution"
./piharness.sh skill list 2>&1
echo ""

# Step 5: Run nightly
echo ">>> Step 4: Run nightly maintenance"
echo "    ./piharness.sh nightly"
echo ""
./piharness.sh nightly 2>&1 || true
echo ""

echo "=============================================="
echo "  Demo 4 Complete"
echo "=============================================="
