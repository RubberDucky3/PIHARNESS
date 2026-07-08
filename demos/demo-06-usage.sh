#!/usr/bin/env bash
# demo-06-usage.sh — Demo: usage stats dashboard
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR"

echo "=============================================="
echo "  PIHARNESS Demo 6: Runtime Usage Statistics"
echo "=============================================="
echo ""

# Step 1: Show all usage subcommands
echo ">>> Available usage commands:"
echo "    ./piharness.sh usage stats   — Per-runtime health table"
echo "    ./piharness.sh usage prune   — Clean old entries (>7d)"
echo ""

# Step 2: Show usage stats
echo ">>> Running: ./piharness.sh usage stats"
echo ""
./piharness.sh usage stats 2>&1 || echo "(usage data may be empty if not seeded)"
echo ""

# Step 3: Explain the columns
echo ">>> The health table shows:"
echo "    RUNTIME       | Total | Success | Fail | Avg Latency | Last Used"
echo "    pi:kilo-auto    |  3    |  2      |  1   | 4.0s        | 2h ago"
echo "    opencode:haiku  |  2    |  2      |  0   | 7.8s        | 30m ago"
echo "    gemini:flash    |  1    |  1      |  0   | 5.2s        | 10m ago"
echo ""

# Step 4: Show prune
echo ">>> Running: ./piharness.sh usage prune"
./piharness.sh usage prune 2>&1 || echo "(prune ran)"
echo ""

echo "This data drives the intelligent runtime fallback:"
echo "  - Runtimes with high failure rates get cooldowns"
echo "  - Best performing runtime is preferred after chain exhaustion"
echo "  - Rate-limited runtimes are skipped until cooldown expires"
echo ""
echo "=============================================="
echo "  Demo 6 Complete"
echo "=============================================="
