#!/usr/bin/env bash
# piharness - Claude Code orchestrator harness for Pi worker agents via cmux
#
# Usage: piharness <command> [args]
# Run: piharness help

set -euo pipefail

PIHARNESS_DIR="${PIHARNESS_DIR:-$HOME/.piharness}"
OUTPUTS_DIR="$PIHARNESS_DIR/outputs"
REGISTRY="$PIHARNESS_DIR/workers.tsv"   # columns: surface_id TAB label TAB cwd

mkdir -p "$PIHARNESS_DIR" "$OUTPUTS_DIR"
[[ -f "$REGISTRY" ]] || touch "$REGISTRY"

cmd="${1:-help}"; shift || true

_outfile() { echo "$OUTPUTS_DIR/${1//:/+}.txt"; }

case "$cmd" in

  # -----------------------------------------------------------------------
  spawn)
  # Usage: piharness spawn [--cwd DIR] [--label LABEL]
  # Spawns a new cmux pane, prints the surface ID.
  # -----------------------------------------------------------------------
    cwd="$(pwd)"
    label="worker-$$"
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --cwd)   cwd="$2";   shift 2 ;;
        --label) label="$2"; shift 2 ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
      esac
    done

    raw=$(cmux new-split right --focus false 2>&1)
    surface=$(printf '%s' "$raw" | grep -oE 'surface:[0-9]+' | head -1)
    if [[ -z "$surface" ]]; then
      echo "ERROR: could not parse surface from cmux output:" >&2
      echo "$raw" >&2
      exit 1
    fi

    # cd into target directory
    cmux send --surface "$surface" "cd $(printf '%q' "$cwd")"$'\n' >/dev/null

    # Register worker
    printf '%s\t%s\t%s\n' "$surface" "$label" "$cwd" >> "$REGISTRY"

    echo "$surface"
    ;;

  # -----------------------------------------------------------------------
  task)
  # Usage: piharness task <surface> <prompt>
  # Sends a pi --print task to a worker; output goes to ~/.piharness/outputs/.
  # -----------------------------------------------------------------------
    [[ $# -lt 2 ]] && { echo "Usage: piharness task <surface> <prompt>" >&2; exit 1; }
    surface="$1"; prompt="$2"
    outfile="$(_outfile "$surface")"
    rm -f "$outfile"

    # Write prompt to a temp file to avoid quoting issues in cmux send
    tmpfile=$(mktemp /tmp/piharness_prompt.XXXXXX)
    printf '%s' "$prompt" > "$tmpfile"

    cmux send --surface "$surface" \
      "pi --print \"\$(cat $(printf '%q' "$tmpfile"))\" \
> $(printf '%q' "$outfile") 2>&1; \
echo '__PIHARNESS_DONE__' >> $(printf '%q' "$outfile"); \
rm -f $(printf '%q' "$tmpfile")"$'\n' >/dev/null

    echo "Task sent to $surface"
    echo "Output: $outfile"
    ;;

  # -----------------------------------------------------------------------
  wait)
  # Usage: piharness wait <surface> [--timeout N]
  # Polls for task completion. Exits 0 on done, 1 on timeout.
  # -----------------------------------------------------------------------
    [[ $# -lt 1 ]] && { echo "Usage: piharness wait <surface> [--timeout N]" >&2; exit 1; }
    surface="$1"; shift
    timeout=120
    [[ "${1:-}" == "--timeout" ]] && { timeout="$2"; }

    outfile="$(_outfile "$surface")"
    deadline=$((SECONDS + timeout))

    printf "Waiting for %s " "$surface"
    while [[ $SECONDS -lt $deadline ]]; do
      if grep -q '__PIHARNESS_DONE__' "$outfile" 2>/dev/null; then
        echo " done"
        exit 0
      fi
      printf '.'
      sleep 2
    done
    echo " TIMEOUT" >&2
    exit 1
    ;;

  # -----------------------------------------------------------------------
  collect)
  # Usage: piharness collect <surface>
  # Prints the worker output, stripping the internal done marker.
  # -----------------------------------------------------------------------
    [[ $# -lt 1 ]] && { echo "Usage: piharness collect <surface>" >&2; exit 1; }
    outfile="$(_outfile "$1")"
    [[ -f "$outfile" ]] || { echo "No output for $1 (run a task first)" >&2; exit 1; }
    grep -v '__PIHARNESS_DONE__' "$outfile"
    ;;

  # -----------------------------------------------------------------------
  compare)
  # Usage: piharness compare <surface1> <surface2>
  # Prints both outputs labelled for the orchestrator to review.
  # -----------------------------------------------------------------------
    [[ $# -lt 2 ]] && { echo "Usage: piharness compare <surface1> <surface2>" >&2; exit 1; }
    for s in "$1" "$2"; do
      echo "=== $s ==="
      grep -v '__PIHARNESS_DONE__' "$(_outfile "$s")" 2>/dev/null || echo "(no output yet)"
      echo
    done
    ;;

  # -----------------------------------------------------------------------
  list)
  # Usage: piharness list
  # Lists registered workers with their status.
  # -----------------------------------------------------------------------
    if [[ ! -s "$REGISTRY" ]]; then
      echo "No registered workers."
      exit 0
    fi
    printf '%-18s %-20s %s\n' "SURFACE" "LABEL" "CWD"
    printf '%-18s %-20s %s\n' "-------" "-----" "---"
    while IFS=$'\t' read -r surf lbl cwd; do
      outfile="$(_outfile "$surf")"
      if grep -q '__PIHARNESS_DONE__' "$outfile" 2>/dev/null; then
        status="done"
      elif [[ -f "$outfile" ]]; then
        status="running"
      else
        status="idle"
      fi
      printf '%-18s %-20s %-30s [%s]\n' "$surf" "$lbl" "$cwd" "$status"
    done < "$REGISTRY"
    ;;

  # -----------------------------------------------------------------------
  use)
  # Usage: piharness use <surface> [--label LABEL]
  # Register an already-open cmux pane as a worker (skips spawning).
  # -----------------------------------------------------------------------
    [[ $# -lt 1 ]] && { echo "Usage: piharness use <surface> [--label LABEL]" >&2; exit 1; }
    surface="$1"; shift
    label="worker-$$"
    [[ "${1:-}" == "--label" ]] && { label="$2"; }
    cwd="$(pwd)"
    printf '%s\t%s\t%s\n' "$surface" "$label" "$cwd" >> "$REGISTRY"
    echo "Registered $surface as $label"
    ;;

  # -----------------------------------------------------------------------
  close)
  # Usage: piharness close <surface>
  # Sends exit to the pane and removes it from the registry.
  # -----------------------------------------------------------------------
    [[ $# -lt 1 ]] && { echo "Usage: piharness close <surface>" >&2; exit 1; }
    surface="$1"
    cmux send --surface "$surface" "exit"$'\n' >/dev/null 2>&1 || true
    # Remove from registry
    tmp=$(mktemp)
    grep -v "^$surface	" "$REGISTRY" > "$tmp" 2>/dev/null || true
    mv "$tmp" "$REGISTRY"
    rm -f "$(_outfile "$surface")"
    echo "Closed $surface"
    ;;

  # -----------------------------------------------------------------------
  clean)
  # Usage: piharness clean
  # Removes all output files and clears the registry.
  # -----------------------------------------------------------------------
    rm -f "$OUTPUTS_DIR"/*.txt
    > "$REGISTRY"
    echo "Cleaned."
    ;;

  # -----------------------------------------------------------------------
  test)
  # Usage: piharness test
  # Smoke test: spawn one worker, run a trivial pi task, collect output.
  # -----------------------------------------------------------------------
    echo "=== piharness smoke test ==="
    echo "Spawning worker..."
    surface=$(bash "$(dirname "$0")/piharness.sh" spawn --label smoke-test)
    echo "Surface: $surface"

    echo "Sending task..."
    bash "$(dirname "$0")/piharness.sh" task "$surface" "Reply with exactly: PIHARNESS_OK"

    bash "$(dirname "$0")/piharness.sh" wait "$surface" --timeout 60

    echo ""
    echo "--- Output ---"
    bash "$(dirname "$0")/piharness.sh" collect "$surface"
    echo "--------------"
    echo "Smoke test complete."
    ;;

  # -----------------------------------------------------------------------
  help|*)
  # -----------------------------------------------------------------------
    cat <<'EOF'
piharness - orchestrate Pi worker agents via cmux

Commands:
  spawn [--cwd DIR] [--label LABEL]    Spawn a new Pi worker pane; prints surface ID
  use   <surface> [--label LABEL]      Register an existing pane as a worker
  task  <surface> <prompt>             Run pi --print task in worker; saves output
  wait  <surface> [--timeout N]        Wait for task completion (default: 120s)
  collect <surface>                    Print worker output
  compare <surface1> <surface2>        Print both outputs for orchestrator review
  list                                 List registered workers and their status
  close <surface>                      Exit pane and deregister worker
  clean                                Clear all outputs and registry
  test                                 Run a quick smoke test

Environment:
  PIHARNESS_DIR    State/output directory (default: ~/.piharness)

Example workflow:
  w1=$(piharness spawn --cwd /my/project --label "worker-a")
  w2=$(piharness spawn --cwd /my/project --label "worker-b")
  piharness task "$w1" "Implement a binary search function in Python"
  piharness task "$w2" "Implement a binary search function in Python"
  piharness wait "$w1"
  piharness wait "$w2"
  piharness compare "$w1" "$w2"
EOF
    ;;
esac
