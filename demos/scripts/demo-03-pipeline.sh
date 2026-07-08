#!/usr/bin/env bash
# demo-03-pipeline.sh — Demo: role-based pipeline (impl → test → review)
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR"

echo "=============================================="
echo "  PIHARNESS Demo 3: Role-Based Pipeline"
echo "=============================================="
echo ""

# Step 1: Explain the pipeline concept
echo ">>> Pipeline: Implement → Test → Review"
echo "    Spawn role-specific workers for each stage."
echo ""

# Step 2: Show pipeline command syntax
echo ">>> Command: ./piharness.sh pipeline <task> --rounds N"
echo "    Runs automatically through all roles."
echo ""

# Step 3: Show spawning individual roles
echo ">>> Spawning role workers:"
echo "    ./piharness.sh spawn --role implementer --worktree --label impl-1"
echo "    ./piharness.sh spawn --role tester --worktree --label test-1"
echo "    ./piharness.sh spawn --role reviewer --worktree --label review-1"
echo ""

# Spawn if not exists
for ROLE_LABEL in "impl-1" "test-1" "review-1"; do
  EXISTING=$(./piharness.sh list-workers 2>/dev/null | grep -c "$ROLE_LABEL" || true)
  if [[ "$EXISTING" -eq 0 ]]; then
    echo "[SPAWN] $ROLE_LABEL..."
    case "$ROLE_LABEL" in
      impl-1)   ./piharness.sh spawn --role implementer --worktree --label "$ROLE_LABEL" 2>&1 || true ;;
      test-1)   ./piharness.sh spawn --role tester --worktree --label "$ROLE_LABEL" 2>&1 || true ;;
      review-1) ./piharness.sh spawn --role reviewer --worktree --label "$ROLE_LABEL" 2>&1 || true ;;
    esac
  fi
done
echo ""

# Step 4: Show status with roles
echo ">>> Pipeline workers ready:"
./piharness.sh status 2>&1 || echo "(status displayed)"
echo ""

# Step 5: Run pipeline
echo ">>> Running pipeline:"
echo "    ./piharness.sh pipeline 'Add a /health endpoint' --rounds 3"
echo ""
./piharness.sh pipeline "Add a /health endpoint" --rounds 3 2>&1 || echo "(pipeline ran or timed out)"
echo ""

echo "=============================================="
echo "  Demo 3 Complete"
echo "=============================================="
