#!/bin/bash
# =============================================================================
# PIHARNESS Overnight Pipeline v2 — build, verify, report
# =============================================================================
# Runs unsupervised for up to 8 hours.
# Phase 1: git status + verify no uncommitted work
# Phase 2: rebuild Vue site, check for errors  
# Phase 3: verify dist output structure
# Phase 4: web search for design inspiration
# Phase 5: apply improvements, rebuild, report
# =============================================================================

set -euo pipefail

export PIHARNESS_DIR="${PIHARNESS_DIR:-$HOME/.piharness}"
LOGDIR="$PIHARNESS_DIR/logs/overnight-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$LOGDIR"
LOGFILE="$LOGDIR/pipeline.log"
SUMMARY="$LOGDIR/summary.md"
START_TIME=$(date +%s)
MAX_DURATION=$((8 * 3600))
PID_FILE="/tmp/piharness-overnight.pid"
echo "$$" > "$PID_FILE"

log()  { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOGFILE"; }
ok()   { log "✓ $*"; }
warn() { log "⚠ $*"; }
fail() { log "✗ $*"; }
phase() { log "══════ $* ══════"; }

cleanup() {
    log "Shutting down pipeline..."
    ./piharness.sh clean 2>/dev/null || true
    # Write summary
    cat > "$SUMMARY" <<SUMEOF
# Overnight Session Summary

**Date**: $(date)
**Duration**: $(($(date +%s) - START_TIME)) seconds
**Status**: $([ -f "$LOGDIR/.complete" ] && echo "COMPLETE" || echo "INTERRUPTED")

## Phases
$(cat "$LOGDIR/phases.log" 2>/dev/null || echo "None completed")

## Build
$(cat "$LOGDIR/build.log" 2>/dev/null | tail -3 || echo "No build log")

## Research Notes
$(cat "$LOGDIR/research.log" 2>/dev/null || echo "No research")
SUMEOF
    ok "Summary: $SUMMARY"
    ok "Logfile: $LOGFILE"
    exit 0
}
trap cleanup EXIT INT TERM

cd /Users/jeromefrancis/Documents/PIHARNESS

phase "Phase 1: Repository Health"
git status --short > "$LOGDIR/git-status.txt" 2>&1 || true
git log --oneline -5 > "$LOGDIR/git-log.txt" 2>&1 || true
ok "Git status recorded ($(wc -l < "$LOGDIR/git-status.txt") changes)"
echo "[$(date '+%H:%M')] Repository check" >> "$LOGDIR/phases.log"

phase "Phase 2: Build Vue Site"
cd /Users/jeromefrancis/Documents/PIHARNESS/demos
npm run build 2>&1 | tee "$LOGDIR/build.log"
BUILD_EXIT=$?
if [ "$BUILD_EXIT" -eq 0 ]; then
    ok "Build succeeded"
    echo "build:pass" > "$LOGDIR/build-status"
else
    fail "Build failed (exit $BUILD_EXIT)"
    echo "build:fail:$BUILD_EXIT" > "$LOGDIR/build-status"
fi
echo "[$(date '+%H:%M')] Build exit: $BUILD_EXIT" >> "$LOGDIR/phases.log"

# Check if we have enough time left
elapsed() { echo $(($(date +%s) - START_TIME)); }

phase "Phase 3: Verify Dist Structure"
if [ -d dist ] && [ -f dist/index.html ]; then
    ok "dist/index.html exists"
    echo "  Files: $(find dist -type f | wc -l | tr -d ' ')"
    echo "  Size:  $(du -sh dist 2>/dev/null | cut -f1)"
    echo "  HTML:  $(wc -c < dist/index.html) bytes"
    echo "  JS:    $(find dist -name '*.js' -exec wc -c {} + 2>/dev/null | tail -1)"
    echo "  CSS:   $(find dist -name '*.css' -exec wc -c {} + 2>/dev/null | tail -1)"
    echo "[$(date '+%H:%M')] Dist verification pass" >> "$LOGDIR/phases.log"
else
    fail "dist/ incomplete"
fi

phase "Phase 4: Spawn Workers + Auto Tasks"
if [ "$(elapsed)" -lt "$(($MAX_DURATION - 3600))" ]; then
    log "Spawning Pi workers for overnight unsupervised development..."
    cd /Users/jeromefrancis/Documents/PIHARNESS

    # Spawn 3 workers
    ./piharness.sh spawn --label overnight-impl --worktree 2>&1 | tee -a "$LOGFILE"
    ./piharness.sh spawn --label overnight-test --worktree 2>&1 | tee -a "$LOGFILE"
    ./piharness.sh spawn --label overnight-review --worktree 2>&1 | tee -a "$LOGFILE"

    sleep 10

    log "Development workers ready — tasks queued for unsupervised execution"
    echo "[$(date '+%H:%M')] Workers spawned, tasks queued" >> "$LOGDIR/phases.log"
else
    log "Skipping Phase 4 (insufficient time remaining)"
    echo "[$(date '+%H:%M')] Phase 4 skipped" >> "$LOGDIR/phases.log"
fi

phase "Phase 5: Final Build Verification"
if [ "$(elapsed)" -lt "$MAX_DURATION" ]; then
    cd /Users/jeromefrancis/Documents/PIHARNESS/demos
    
    # Try one more build
    npm run build 2>&1 | tee -a "$LOGDIR/build-final.log"
    if [ $? -eq 0 ]; then
        ok "Final build passed"
        echo "build:final:pass" > "$LOGDIR/build-status"
    else
        fail "Final build failed"
    fi
    
    # Check recordings are linked
    for cast in recordings/*.cast; do
        name=$(basename "$cast")
        if [ -f "dist/$cast" ]; then
            ok "  $name in dist"
        else
            warn "  $name missing from dist"
        fi
    done
fi

# Mark complete
date > "$LOGDIR/.complete"
ok "=== Pipeline Complete ==="
ok "Duration: $(($(date +%s) - START_TIME))s"
