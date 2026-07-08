#!/bin/bash
# =============================================================================
# PIHARNESS Progress Check — runs via cron every 30 minutes
# Checks if overnight pipeline is running, reports status.
# =============================================================================
set -euo pipefail

PIHARNESS_DIR="${PIHARNESS_DIR:-$HOME/.piharness}"
LOGDIR="$PIHARNESS_DIR/logs"
PIPELINE_LOG=$(ls -t "$LOGDIR"/overnight-*/pipeline.log 2>/dev/null | head -1)
BUILD_STATUS="$PIHARNESS_DIR/last-build-status.txt"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] PIHARNESS Progress Check"
echo ""

# 1. Check if overnight pipeline is running
if [ -f /tmp/piharness-overnight.pid ]; then
    PID=$(cat /tmp/piharness-overnight.pid)
    if kill -0 "$PID" 2>/dev/null; then
        echo "✓ Overnight pipeline RUNNING (PID $PID)"
    else
        echo "✗ Overnight pipeline NOT RUNNING (stale PID)"
        rm -f /tmp/piharness-overnight.pid
    fi
else
    echo "— Overnight pipeline not started yet"
fi

# 2. Check pipeline log tail
if [ -n "$PIPELINE_LOG" ]; then
    echo ""
    echo "=== Last pipeline log entries ==="
    tail -10 "$PIPELINE_LOG"
fi

# 3. Check build status
if [ -d /Users/jeromefrancis/Documents/PIHARNESS/demos/dist ]; then
    FILE_COUNT=$(find /Users/jeromefrancis/Documents/PIHARNESS/demos/dist -type f | wc -l | tr -d ' ')
    echo ""
    echo "✓ Build output: $FILE_COUNT files in dist/"
fi

# 4. Check cmux surfaces
CMUX="/Applications/cmux.app/Contents/Resources/bin/cmux"
if [ -x "$CMUX" ]; then
    SURFACES=$("$CMUX" rpc list-surfaces 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
active=[s for s in d if s.get('pid')]
for s in active:
    ref=s.get('surface_ref','?')
    lbl=s.get('label','worker')
    print(f'{ref} {lbl}')
" 2>/dev/null)
    if [ -n "$SURFACES" ]; then
        echo ""
        echo "=== Active cmux surfaces ==="
        echo "$SURFACES"
    fi
fi

echo ""
echo "========================================"
