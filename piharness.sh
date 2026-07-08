#!/usr/bin/env bash
# piharness - Claude Code orchestrator harness for Pi worker agents via cmux
#
# Usage: ./piharness.sh <command> [args]
# Run:   ./piharness.sh help

set -euo pipefail

PIHARNESS_DIR="${PIHARNESS_DIR:-$HOME/.piharness}"
OUTPUTS_DIR="$PIHARNESS_DIR/outputs"
LOGS_DIR="$PIHARNESS_DIR/logs"
WORKTREES_DIR="$PIHARNESS_DIR/worktrees"
REGISTRY="$PIHARNESS_DIR/workers.tsv"
# Registry cols: surface_id TAB label TAB cwd TAB worktree_path TAB branch TAB start_epoch

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${PIHARNESS_REPO:-$SCRIPT_DIR}"

mkdir -p "$PIHARNESS_DIR" "$OUTPUTS_DIR" "$LOGS_DIR" "$WORKTREES_DIR"
[[ -f "$REGISTRY" ]] || touch "$REGISTRY"

cmd="${1:-help}"; shift || true

# ── helpers ──────────────────────────────────────────────────────────────────

_outfile() { echo "$OUTPUTS_DIR/${1//:/+}.txt"; }
_logfile() { echo "$LOGS_DIR/${1//:/+}.log"; }

_log() {
  local surface="$1" event="$2" detail="${3:-}"
  printf '%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$event" "$detail" \
    >> "$(_logfile "$surface")"
}

_registry_get() {
  # _registry_get <surface> <col>  (1=surface 2=label 3=cwd 4=worktree 5=branch 6=start_epoch)
  awk -F'\t' -v surf="$1" -v c="$2" '$1==surf{print $c; exit}' "$REGISTRY"
}

_elapsed() {
  local start="${1:-0}"
  [[ "$start" == "0" || -z "$start" ]] && echo "-" && return
  local elapsed=$(( $(date +%s) - start ))
  printf '%dm%02ds' $(( elapsed/60 )) $(( elapsed%60 ))
}

_worker_status() {
  local outfile="$(_outfile "$1")"
  if grep -q '__PIHARNESS_DONE__' "$outfile" 2>/dev/null; then echo "done"
  elif [[ -f "$outfile" ]]; then echo "running"
  else echo "idle"; fi
}

# ── commands ──────────────────────────────────────────────────────────────────

case "$cmd" in

  # ---------------------------------------------------------------------------
  spawn)
  # Usage: piharness spawn [--cwd DIR] [--label LABEL] [--worktree] [--branch NAME]
  # Spawns a new cmux pane. With --worktree, creates an isolated git branch.
  # Prints the surface ID on success.
  # ---------------------------------------------------------------------------
    cwd="$(pwd)"
    label="worker-$$"
    use_worktree=false
    branch=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --cwd)      cwd="$2";   shift 2 ;;
        --label)    label="$2"; shift 2 ;;
        --worktree) use_worktree=true; shift ;;
        --branch)   branch="$2"; shift 2 ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
      esac
    done

    raw=$(cmux new-split right --focus false 2>&1)
    surface=$(printf '%s' "$raw" | grep -oE 'surface:[0-9]+' | head -1)
    if [[ -z "$surface" ]]; then
      echo "ERROR: could not parse surface from: $raw" >&2; exit 1
    fi

    worktree_path=""
    if [[ "$use_worktree" == true ]]; then
      branch="${branch:-piharness/$label}"
      worktree_path="$WORKTREES_DIR/$label"
      git -C "$REPO_DIR" worktree add -b "$branch" "$worktree_path" HEAD >/dev/null 2>&1
      cwd="$worktree_path"
    fi

    cmux send --surface "$surface" "cd $(printf '%q' "$cwd")"$'\n' >/dev/null

    start_epoch=$(date +%s)
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$surface" "$label" "$cwd" \
      "$worktree_path" "$branch" "$start_epoch" >> "$REGISTRY"

    _log "$surface" "SPAWNED" "label=$label cwd=$cwd worktree=${worktree_path} branch=${branch}"

    echo "$surface"
    ;;

  # ---------------------------------------------------------------------------
  use)
  # Usage: piharness use <surface> [--label LABEL]
  # Register an already-open pane as a worker.
  # ---------------------------------------------------------------------------
    [[ $# -lt 1 ]] && { echo "Usage: piharness use <surface> [--label LABEL]" >&2; exit 1; }
    surface="$1"; shift
    label="worker-$$"
    [[ "${1:-}" == "--label" ]] && { label="$2"; }
    start_epoch=$(date +%s)
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$surface" "$label" "$(pwd)" "" "" "$start_epoch" >> "$REGISTRY"
    _log "$surface" "REGISTERED" "label=$label"
    echo "Registered $surface as $label"
    ;;

  # ---------------------------------------------------------------------------
  task)
  # Usage: piharness task <surface> <prompt>
  # Runs `pi --print <prompt>` in the worker pane; saves output to file.
  # ---------------------------------------------------------------------------
    [[ $# -lt 2 ]] && { echo "Usage: piharness task <surface> <prompt>" >&2; exit 1; }
    surface="$1"; prompt="$2"
    outfile="$(_outfile "$surface")"
    rm -f "$outfile"

    # Use temp file to safely pass prompt without quoting nightmares
    tmpfile=$(mktemp /tmp/piharness_prompt.XXXXXX)
    printf '%s' "$prompt" > "$tmpfile"

    # Check if this worker has a worktree so we can auto-commit after task
    worktree=$(_registry_get "$surface" 4)
    branch=$(_registry_get "$surface" 5)

    if [[ -n "$worktree" ]]; then
      cmux send --surface "$surface" \
        "pi --print \"\$(cat $(printf '%q' "$tmpfile"))\" \
> $(printf '%q' "$outfile") 2>&1; \
git -C $(printf '%q' "$worktree") add -A 2>/dev/null; \
git -C $(printf '%q' "$worktree") commit -m 'feat: task output' --allow-empty 2>/dev/null; \
echo '__PIHARNESS_DONE__' >> $(printf '%q' "$outfile"); \
rm -f $(printf '%q' "$tmpfile")"$'\n' >/dev/null
    else
      cmux send --surface "$surface" \
        "pi --print \"\$(cat $(printf '%q' "$tmpfile"))\" \
> $(printf '%q' "$outfile") 2>&1; \
echo '__PIHARNESS_DONE__' >> $(printf '%q' "$outfile"); \
rm -f $(printf '%q' "$tmpfile")"$'\n' >/dev/null
    fi

    _log "$surface" "TASK_SENT" "${prompt:0:100}"
    echo "Task sent → $outfile"
    ;;

  # ---------------------------------------------------------------------------
  wait)
  # Usage: piharness wait <surface> [--timeout N]
  # Polls until done marker appears. Exits 0=done, 1=timeout.
  # ---------------------------------------------------------------------------
    [[ $# -lt 1 ]] && { echo "Usage: piharness wait <surface> [--timeout N]" >&2; exit 1; }
    surface="$1"; shift
    timeout=300
    [[ "${1:-}" == "--timeout" ]] && timeout="$2"

    outfile="$(_outfile "$surface")"
    deadline=$(( SECONDS + timeout ))

    printf "Waiting for %s " "$surface"
    while [[ $SECONDS -lt $deadline ]]; do
      if grep -q '__PIHARNESS_DONE__' "$outfile" 2>/dev/null; then
        echo " done"
        _log "$surface" "TASK_DONE" ""
        exit 0
      fi
      printf '.'
      sleep 2
    done
    echo " TIMEOUT" >&2
    _log "$surface" "TASK_TIMEOUT" "after ${timeout}s"
    exit 1
    ;;

  # ---------------------------------------------------------------------------
  collect)
  # Usage: piharness collect <surface>
  # Print completed worker output (strips internal markers).
  # ---------------------------------------------------------------------------
    [[ $# -lt 1 ]] && { echo "Usage: piharness collect <surface>" >&2; exit 1; }
    outfile="$(_outfile "$1")"
    [[ -f "$outfile" ]] || { echo "No output for $1" >&2; exit 1; }
    grep -v '__PIHARNESS_DONE__' "$outfile"
    ;;

  # ---------------------------------------------------------------------------
  peek)
  # Usage: piharness peek <surface>
  # Show partial output so far, even if task is still running.
  # ---------------------------------------------------------------------------
    [[ $# -lt 1 ]] && { echo "Usage: piharness peek <surface>" >&2; exit 1; }
    outfile="$(_outfile "$1")"
    [[ -f "$outfile" ]] || { echo "(no output yet)" ; exit 0; }
    local_status=$(_worker_status "$1")
    echo "── $1 [$local_status] ──"
    grep -v '__PIHARNESS_DONE__' "$outfile"
    ;;

  # ---------------------------------------------------------------------------
  screen)
  # Usage: piharness screen <surface>
  # Capture live terminal view of the worker pane.
  # ---------------------------------------------------------------------------
    [[ $# -lt 1 ]] && { echo "Usage: piharness screen <surface>" >&2; exit 1; }
    echo "── screen: $1 ──"
    cmux capture-pane --surface "$1" 2>&1
    ;;

  # ---------------------------------------------------------------------------
  watch)
  # Usage: piharness watch <surface>
  # Stream output file in real time. Ctrl-C to stop.
  # ---------------------------------------------------------------------------
    [[ $# -lt 1 ]] && { echo "Usage: piharness watch <surface>" >&2; exit 1; }
    echo "Watching $1 (Ctrl-C to stop)..."
    tail -f "$(_outfile "$1")" 2>/dev/null | grep -v '__PIHARNESS_DONE__' || true
    ;;

  # ---------------------------------------------------------------------------
  log)
  # Usage: piharness log <surface>
  # Show the structured event log for a worker.
  # ---------------------------------------------------------------------------
    [[ $# -lt 1 ]] && { echo "Usage: piharness log <surface>" >&2; exit 1; }
    logfile="$(_logfile "$1")"
    [[ -f "$logfile" ]] || { echo "No log for $1" >&2; exit 1; }
    printf '%-25s %-16s %s\n' "TIMESTAMP" "EVENT" "DETAIL"
    printf '%-25s %-16s %s\n' "---------" "-----" "------"
    while IFS=$'\t' read -r ts event detail; do
      printf '%-25s %-16s %s\n' "$ts" "$event" "$detail"
    done < "$logfile"
    ;;

  # ---------------------------------------------------------------------------
  status)
  # Usage: piharness status
  # Rich dashboard: all workers with elapsed time and last output line.
  # ---------------------------------------------------------------------------
    if [[ ! -s "$REGISTRY" ]]; then
      echo "No registered workers."; exit 0
    fi
    echo ""
    printf '%-14s %-16s %-9s %-9s %s\n' "SURFACE" "LABEL" "STATUS" "ELAPSED" "LAST OUTPUT"
    printf '%-14s %-16s %-9s %-9s %s\n' "───────" "─────" "──────" "───────" "───────────"
    while IFS=$'\t' read -r surf lbl cwd wt br start_epoch; do
      outfile="$(_outfile "$surf")"
      status=$(_worker_status "$surf")
      elapsed=$(_elapsed "${start_epoch:-0}")
      last=$(grep -v '__PIHARNESS_DONE__' "$outfile" 2>/dev/null \
             | grep -v '^$' | tail -1 | cut -c1-50 || echo "-")
      printf '%-14s %-16s %-9s %-9s %s\n' "$surf" "$lbl" "$status" "$elapsed" "${last:--}"
    done < "$REGISTRY"
    echo ""
    ;;

  # ---------------------------------------------------------------------------
  compare)
  # Usage: piharness compare <surface1> <surface2>
  # Show both outputs side-by-side (for orchestrator review).
  # ---------------------------------------------------------------------------
    [[ $# -lt 2 ]] && { echo "Usage: piharness compare <surface1> <surface2>" >&2; exit 1; }
    for s in "$1" "$2"; do
      echo "══ $s ($(_worker_status "$s")) ══"
      grep -v '__PIHARNESS_DONE__' "$(_outfile "$s")" 2>/dev/null || echo "(no output yet)"
      echo
    done
    ;;

  # ---------------------------------------------------------------------------
  diff)
  # Usage: piharness diff <surface1> <surface2>
  # Git diff between the two workers' worktree branches.
  # ---------------------------------------------------------------------------
    [[ $# -lt 2 ]] && { echo "Usage: piharness diff <surface1> <surface2>" >&2; exit 1; }
    b1=$(_registry_get "$1" 5)
    b2=$(_registry_get "$2" 5)
    if [[ -z "$b1" || -z "$b2" ]]; then
      echo "ERROR: workers need --worktree to use diff" >&2; exit 1
    fi
    echo "── diff $b1 → $b2 ──"
    git -C "$REPO_DIR" diff "$b1".."$b2" || true
    ;;

  # ---------------------------------------------------------------------------
  list)
  # Usage: piharness list
  # ---------------------------------------------------------------------------
    if [[ ! -s "$REGISTRY" ]]; then
      echo "No registered workers."; exit 0
    fi
    printf '%-14s %-16s %-9s %-32s %s\n' "SURFACE" "LABEL" "STATUS" "CWD" "BRANCH"
    printf '%-14s %-16s %-9s %-32s %s\n' "───────" "─────" "──────" "───" "──────"
    while IFS=$'\t' read -r surf lbl cwd wt br start_epoch; do
      status=$(_worker_status "$surf")
      printf '%-14s %-16s %-9s %-32s %s\n' \
        "$surf" "$lbl" "$status" "${cwd:0:32}" "${br:-none}"
    done < "$REGISTRY"
    ;;

  # ---------------------------------------------------------------------------
  close)
  # Usage: piharness close <surface> [--keep-worktree]
  # ---------------------------------------------------------------------------
    [[ $# -lt 1 ]] && { echo "Usage: piharness close <surface> [--keep-worktree]" >&2; exit 1; }
    surface="$1"; shift
    keep_wt=false
    [[ "${1:-}" == "--keep-worktree" ]] && keep_wt=true

    wt=$(_registry_get "$surface" 4)
    br=$(_registry_get "$surface" 5)

    cmux send --surface "$surface" "exit"$'\n' >/dev/null 2>&1 || true

    if [[ -n "$wt" && "$keep_wt" == false ]]; then
      git -C "$REPO_DIR" worktree remove --force "$wt" 2>/dev/null || true
      git -C "$REPO_DIR" branch -D "$br" 2>/dev/null || true
    fi

    tmp=$(mktemp)
    grep -v "^${surface}	" "$REGISTRY" > "$tmp" 2>/dev/null || true
    mv "$tmp" "$REGISTRY"

    _log "$surface" "CLOSED" ""
    rm -f "$(_outfile "$surface")"
    echo "Closed $surface"
    ;;

  # ---------------------------------------------------------------------------
  clean)
  # Usage: piharness clean
  # ---------------------------------------------------------------------------
    rm -f "$OUTPUTS_DIR"/*.txt "$LOGS_DIR"/*.log
    > "$REGISTRY"
    echo "Cleaned."
    ;;

  # ---------------------------------------------------------------------------
  help|*)
  # ---------------------------------------------------------------------------
    cat <<'EOF'
piharness - orchestrate Pi worker agents via cmux

Spawn / Register:
  spawn [--cwd DIR] [--label L] [--worktree] [--branch B]
  use   <surface> [--label L]

Task lifecycle:
  task    <surface> <prompt>          Send pi --print task
  wait    <surface> [--timeout N]     Block until done (default 300s)
  collect <surface>                   Print final output
  peek    <surface>                   Print partial output (mid-run ok)

Observability:
  status                              Dashboard: all workers, elapsed, last line
  screen  <surface>                   Live pane capture
  watch   <surface>                   Stream output file (tail -f)
  log     <surface>                   Structured event log
  list                                Table of workers and branches

Comparison:
  compare <surface1> <surface2>       Show both outputs
  diff    <surface1> <surface2>       Git diff worktree branches

Cleanup:
  close  <surface> [--keep-worktree]  Exit pane + remove worktree
  clean                               Reset all state

Env:
  PIHARNESS_DIR   State dir (default: ~/.piharness)
  PIHARNESS_REPO  Git repo for worktrees (default: script dir)
EOF
    ;;
esac
