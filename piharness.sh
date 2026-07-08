#!/usr/bin/env bash
# piharness - Claude Code orchestrator harness for Pi/OpenCode/Ollama/Claude workers via cmux
#
# Usage: ./piharness.sh <command> [args]
# Run:   ./piharness.sh help

set -euo pipefail

PIHARNESS_DIR="${PIHARNESS_DIR:-$HOME/.piharness}"
OUTPUTS_DIR="$PIHARNESS_DIR/outputs"
LOGS_DIR="$PIHARNESS_DIR/logs"
WORKTREES_DIR="$PIHARNESS_DIR/worktrees"
RUNTIMES_DIR="$PIHARNESS_DIR/runtimes"
MONITORS_DIR="$PIHARNESS_DIR/monitors"
REGISTRY="$PIHARNESS_DIR/workers.tsv"
LAST_SURFACE_FILE="$PIHARNESS_DIR/last_surface"
# Registry cols: surface_id TAB label TAB cwd TAB worktree_path TAB branch TAB start_epoch TAB role

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${PIHARNESS_REPO:-$SCRIPT_DIR}"

# ── Skill system ────────────────────────────────────────────────────────────
SKILLS_DIR="${PIHARNESS_SKILLS_DIR:-$HOME/.piharness/skills}"
SKILLS_REGISTRY="$SKILLS_DIR/registry.json"

# ── Runtime chain ─────────────────────────────────────────────────────────────
# Tried in order when a model hits its limit. Format: TYPE:MODEL
# Types: pi, opencode, ollama, claude
# Override with PIHARNESS_RUNTIMES env var
RUNTIME_CHAIN="${PIHARNESS_RUNTIMES:-pi:kilo-auto/free,opencode:anthropic/claude-haiku-4-5,gemini:gemini-2.5-flash,codex:default,droid:default,ollama:qwen2.5-coder:7b,claude:default}"

MAX_WORKERS="${PIHARNESS_MAX_WORKERS:-3}"

mkdir -p "$PIHARNESS_DIR" "$OUTPUTS_DIR" "$LOGS_DIR" "$WORKTREES_DIR" \
         "$RUNTIMES_DIR" "$MONITORS_DIR"
[[ -f "$REGISTRY" ]] || touch "$REGISTRY"

cmd="${1:-help}"; shift || true

# ── core helpers ──────────────────────────────────────────────────────────────

_outfile()  { echo "$OUTPUTS_DIR/${1//:/+}.txt"; }
_logfile()  { echo "$LOGS_DIR/${1//:/+}.log"; }
_rtfile()   { echo "$RUNTIMES_DIR/${1//:/+}.idx"; }
_monfile()  { echo "$MONITORS_DIR/${1//:/+}.pid"; }

_log() {
  local surface="$1" event="$2" detail="${3:-}"
  printf '%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$event" "$detail" \
    >> "$(_logfile "$surface")"
}

_registry_get() {
  awk -F'\t' -v surf="$1" -v c="$2" '$1==surf{print $c; exit}' "$REGISTRY"
}

_elapsed() {
  local start="${1:-0}"
  [[ "$start" == "0" || -z "$start" ]] && echo "-" && return
  local elapsed=$(( $(date +%s) - start ))
  printf '%dm%02ds' $(( elapsed/60 )) $(( elapsed%60 ))
}

_cmux_surface_healthy() {
  local surf="$1"; [[ -z "$surf" ]] && return 1
  local h; h=$(cmux surface-health --surface "$surf" 2>&1) || true
  echo "$h" | grep -qiE 'not found|error|no such surface' && return 1
  return 0
}

_cmux_label_tab() { cmux rename-tab --surface "$1" "🔧${2}" 2>/dev/null || true; }

_cmux_set_worker_status() {
  local s="$1" st="$2" icon name
  case "$st" in
    running) icon="▶️";  name="progress" ;;
    done)    icon="✅";  name="complete" ;;
    error)   icon="❌";  name="error"    ;;
    idle)    icon="⏸️";  name="idle"     ;;
    *)       icon="⚪";  name="unknown"  ;;
  esac
  cmux set-status "worker:$s" "$name" --icon "$icon" 2>/dev/null || true
}

_cmux_clear_worker_status() { cmux clear-status "worker:$1" 2>/dev/null || true; }

_worker_status() {
  local outfile="$(_outfile "$1")"
  if grep -q '__PIHARNESS_DONE__' "$outfile" 2>/dev/null; then
    grep -q '__PIHARNESS_ERROR__' "$outfile" 2>/dev/null && echo "error" || echo "done"
  elif [[ -f "$outfile" ]]; then echo "running"
  else echo "idle"; fi
}

# Get all surface IDs with a given role
_registry_by_role() {
  awk -F'\t' -v role="$1" '$7==role{print $1}' "$REGISTRY"
}

# Get first surface with a given role
_registry_first_role() {
  _registry_by_role "$1" | head -1
}

# ── runtime chain helpers ─────────────────────────────────────────────────────

_chain_entry() {
  echo "$RUNTIME_CHAIN" | tr ',' '\n' | sed -n "$(($1+1))p"
}

_chain_len() {
  echo "$RUNTIME_CHAIN" | tr ',' '\n' | grep -c . || echo 0
}

_rt_idx() {
  cat "$(_rtfile "$1")" 2>/dev/null || echo "0"
}

_rt_set_idx() {
  echo "$2" > "$(_rtfile "$1")"
}

_rt_current() {
  _chain_entry "$(_rt_idx "$1")"
}

_rt_type()  { echo "${1%%:*}"; }
_rt_model() { echo "${1#*:}"; }

# Build the non-interactive shell command for a given runtime entry
_rt_cmd() {
  local entry="$1" prompt_file="$2" outfile="$3" wt="$4"
  local type model cd_prefix=""
  type=$(_rt_type "$entry")
  model=$(_rt_model "$entry")
  [[ -n "$wt" ]] && cd_prefix="cd $(printf '%q' "$wt") && "

  case "$type" in
    pi)
      printf '%s' "${cd_prefix}pi --print --model $(printf '%q' "$model") \"\$(cat $(printf '%q' "$prompt_file"))\" > $(printf '%q' "$outfile") 2>&1"
      ;;
    opencode)
      local mflag=""
      [[ "$model" != "auto" ]] && mflag="-m $(printf '%q' "$model")"
      printf '%s' "${cd_prefix}opencode run $mflag \"\$(cat $(printf '%q' "$prompt_file"))\" > $(printf '%q' "$outfile") 2>&1"
      ;;
    ollama)
      printf '%s' "${cd_prefix}ollama run $(printf '%q' "$model") \"\$(cat $(printf '%q' "$prompt_file"))\" > $(printf '%q' "$outfile") 2>&1"
      ;;
    claude)
      local mflag=""
      [[ "$model" != "default" ]] && mflag="--model $(printf '%q' "$model")"
      printf '%s' "${cd_prefix}claude --print $mflag \"\$(cat $(printf '%q' "$prompt_file"))\" > $(printf '%q' "$outfile") 2>&1"
      ;;
    gemini)
      printf '%s' "${cd_prefix}gemini --prompt \"\$(cat $(printf '%q' "$prompt_file"))\" > $(printf '%q' "$outfile") 2>&1"
      ;;
    codex)
      printf '%s' "${cd_prefix}codex --prompt \"\$(cat $(printf '%q' "$prompt_file"))\" > $(printf '%q' "$outfile") 2>&1"
      ;;
    droid)
      printf '%s' "${cd_prefix}droid \"\$(cat $(printf '%q' "$prompt_file"))\" > $(printf '%q' "$outfile") 2>&1"
      ;;
    *)
      echo "echo 'ERROR: unknown runtime type $type'" ;;
  esac
}

# Error patterns that signal a runtime hit its limit
_is_error_output() {
  grep -qiE 'token limit|rate limit exceeded|context length|quota exceeded|Error: Model stopped|billing|exceeded.*limit' \
    "$1" 2>/dev/null
}

# Force-break out of any interactive process in a pane (back to shell)
_break_pane() {
  local surface="$1"
  cmux send --surface "$surface" $'\x03' >/dev/null 2>&1 || true
  sleep 0.5
  cmux send --surface "$surface" $'\x03' >/dev/null 2>&1 || true
  sleep 0.5
  cmux send --surface "$surface" "q"$'\n' >/dev/null 2>&1 || true
  sleep 1
}

# Auto-detect and launch the best free interactive CLI in a pane.
# Tries pi first (free), then opencode; skips types not installed.
_autostart_runtime() {
  local surface="$1"
  local entry chain_type model
  while IFS= read -r entry; do
    chain_type=$(_rt_type "$entry")
    model=$(_rt_model "$entry")
    if [[ "$chain_type" == "pi" ]] && command -v pi &>/dev/null; then
      cmux send --surface "$surface" "pi --model $(printf '%q' "$model")"$'\n' >/dev/null
      _log "$surface" "AUTOSTART" "runtime=pi:$model"
      return 0
    elif [[ "$chain_type" == "opencode" ]] && command -v opencode &>/dev/null; then
      cmux send --surface "$surface" "opencode ."$'\n' >/dev/null
      _log "$surface" "AUTOSTART" "runtime=opencode:$model"
      return 0
    elif [[ "$chain_type" == "gemini" ]] && command -v gemini &>/dev/null; then
      cmux send --surface "$surface" "gemini"$'\n' >/dev/null
      _log "$surface" "AUTOSTART" "runtime=gemini:$model"
      return 0
    elif [[ "$chain_type" == "codex" ]] && command -v codex &>/dev/null; then
      cmux send --surface "$surface" "codex"$'\n' >/dev/null
      _log "$surface" "AUTOSTART" "runtime=codex:$model"
      return 0
    elif [[ "$chain_type" == "droid" ]] && command -v droid &>/dev/null; then
      cmux send --surface "$surface" "droid"$'\n' >/dev/null
      _log "$surface" "AUTOSTART" "runtime=droid:$model"
      return 0
    fi
  done < <(echo "$RUNTIME_CHAIN" | tr ',' '\n')
  _log "$surface" "AUTOSTART_SKIP" "no compatible free CLI found in PATH"
}

# Build the interactive restart command for the first available free runtime.
_restart_cmd() {
  local entry chain_type model
  while IFS= read -r entry; do
    chain_type=$(_rt_type "$entry")
    model=$(_rt_model "$entry")
    if [[ "$chain_type" == "pi" ]] && command -v pi &>/dev/null; then
      printf '%s' "pi --model $(printf '%q' "$model")"
      return 0
    elif [[ "$chain_type" == "opencode" ]] && command -v opencode &>/dev/null; then
      printf '%s' "opencode ."
      return 0
    elif [[ "$chain_type" == "gemini" ]] && command -v gemini &>/dev/null; then
      printf '%s' "gemini --prompt"
      return 0
    elif [[ "$chain_type" == "codex" ]] && command -v codex &>/dev/null; then
      printf '%s' "codex --prompt"
      return 0
    elif [[ "$chain_type" == "droid" ]] && command -v droid &>/dev/null; then
      printf '%s' "droid"
      return 0
    fi
  done < <(echo "$RUNTIME_CHAIN" | tr ',' '\n')
}

# ── usage tracking (per-runtime success/failure/limits) ────────────────────────
# Tracks every task attempt so auto-fallback can make intelligent routing decisions.

USAGE_FILE="$PIHARNESS_DIR/runtimes/usage.json"

_usage_init() {
  mkdir -p "$(dirname "$USAGE_FILE")"
  [[ -f "$USAGE_FILE" ]] || echo '{"version":1,"entries":[],"cooldowns":{}}' > "$USAGE_FILE"
}

_usage_record() {
  local runtime="$1" status="$2" desc="${3:-}"
  _usage_init
  python3 -c "
import json, os, time
from datetime import datetime, timezone
path = os.path.expanduser('$USAGE_FILE')
with open(path) as f:
    u = json.load(f)
entry = {
    'runtime': '$runtime',
    'status': '$status',
    'timestamp': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'description': '${desc//\'/\\\'}'
}
u.setdefault('entries', []).append(entry)
# Trim to last 2000 entries
if len(u['entries']) > 2000:
    u['entries'] = u['entries'][-2000:]
u['last_updated'] = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
with open(path, 'w') as f:
    json.dump(u, f, indent=2)
"
}

_usage_stats() {
  _usage_init
  python3 -c "
import json, os
path = os.path.expanduser('$USAGE_FILE')
with open(path) as f:
    u = json.load(f)
entries = u.get('entries', [])
if not entries:
    print('No usage data yet')
    exit(0)
# Per-runtime stats
from collections import Counter
by_runtime = {}
for e in entries:
    r = e['runtime']
    s = e['status']
    by_runtime.setdefault(r, Counter())
    by_runtime[r][s] += 1
print(f'{\"RUNTIME\":<35} {\"OK\":<6} {\"LIMIT\":<8} {\"TIMEOUT\":<8} {\"ERROR\":<8} {\"FAIL%\":<7} {\"TOTAL\":<7}')
print('-' * 85)
for r in sorted(by_runtime.keys()):
    c = by_runtime[r]
    total = sum(c.values())
    fails = c.get('rate_limited',0) + c.get('timeout',0) + c.get('error',0)
    fail_pct = (fails/total*100) if total > 0 else 0
    print(f'{r:<35} {c.get(\"success\",0):<6} {c.get(\"rate_limited\",0):<8} {c.get(\"timeout\",0):<8} {c.get(\"error\",0):<8} {fail_pct:<7.1f} {total:<7}')
"
}

# Returns the runtime name with the lowest failure rate
_usage_best_runtime() {
  _usage_init
  python3 -c "
import json, os
path = os.path.expanduser('$USAGE_FILE')
with open(path) as f:
    u = json.load(f)
entries = u.get('entries', [])
if not entries:
    exit(0)
runtimes = set(e['runtime'] for e in entries)
best = None
best_rate = 999.0
for r in runtimes:
    re = [e for e in entries if e['runtime'] == r]
    total = len(re)
    failures = sum(1 for e in re if e['status'] in ('rate_limited','timeout','error'))
    rate = failures / total if total > 0 else 0
    if rate < best_rate:
        best_rate = rate
        best = r
if best:
    print(best)
"
}

_usage_get_cooldown() {
  local runtime="$1"
  _usage_init
  python3 -c "
import json, os, time
path = os.path.expanduser('$USAGE_FILE')
with open(path) as f:
    u = json.load(f)
cooldowns = u.get('cooldowns', {})
expires = cooldowns.get('$runtime', 0)
remaining = max(0, expires - time.time())
print(int(remaining))
"
}

_usage_set_cooldown() {
  local runtime="$1" seconds="$2"
  _usage_init
  python3 -c "
import json, os, time
path = os.path.expanduser('$USAGE_FILE')
with open(path) as f:
    u = json.load(f)
u.setdefault('cooldowns', {})
u['cooldowns']['$runtime'] = time.time() + $seconds
u['last_updated'] = __import__('datetime').datetime.now().strftime('%Y-%m-%dT%H:%M:%SZ')
with open(path, 'w') as f:
    json.dump(u, f, indent=2)
"
}

_usage_prune() {
  # Remove entries older than 7 days and expired cooldowns
  _usage_init
  python3 -c "
import json, os, time
from datetime import datetime, timezone, timedelta
path = os.path.expanduser('$USAGE_FILE')
with open(path) as f:
    u = json.load(f)
cutoff = (datetime.now(timezone.utc) - timedelta(days=7)).isoformat()
old_count = len(u.get('entries', []))
u['entries'] = [e for e in u.get('entries', []) if e.get('timestamp','') >= cutoff]
pruned = old_count - len(u['entries'])
# Prune expired cooldowns
u['cooldowns'] = {k:v for k,v in u.get('cooldowns',{}).items() if v > time.time()}
print(f'Pruned {pruned} old entries, {len(u[\"cooldowns\"])} active cooldowns')
with open(path, 'w') as f:
    json.dump(u, f, indent=2)
"
}

# Categorize why a runtime failed: 'rate_limited', 'timeout', 'error', or '' (success)
_usage_classify_failure() {
  local outfile="$1" timed_out="${2:-false}"
  [[ "$timed_out" == "true" ]] && { echo "timeout"; return; }
  if grep -qiE '429|rate limit|too many requests|quota exceeded|insufficient_quota' "$outfile" 2>/dev/null; then
    echo "rate_limited"; return
  fi
  if grep -qiE 'token limit|context length|maximum context|too many tokens' "$outfile" 2>/dev/null; then
    echo "rate_limited"; return
  fi
  if grep -qiE 'billing|payment|credit|exceeded.*limit|model.*not.*available|server error|50[0-9]' "$outfile" 2>/dev/null; then
    echo "rate_limited"; return
  fi
  if grep -q '__PIHARNESS_ERROR__' "$outfile" 2>/dev/null; then
    echo "error"; return
  fi
  echo "error"
}

# Advance to next runtime in chain, return 1 if chain exhausted
_advance_runtime() {
  local s="$1" clen="$2"
  local nxt=$(( $(_rt_idx "$s") + 1 ))
  if [[ "$nxt" -ge "$clen" ]]; then
    return 1
  fi
  _rt_set_idx "$s" "$nxt"
  local new_entry=$(_chain_entry "$nxt")
  _log "$s" "RUNTIME_SWITCH" "advance"
  echo "  Switched to $new_entry"
  rm -f "$(_outfile "$s")"
  return 0
}

# ── commands ──────────────────────────────────────────────────────────────────

case "$cmd" in

  # ---------------------------------------------------------------------------
  spawn)
  # Usage: piharness spawn [--cwd DIR] [--label LABEL] [--worktree] [--branch B] [--role ROLE]
  # Spawns a new worker pane. Prints the surface ID.
  # ---------------------------------------------------------------------------
    cwd="$(pwd)"
    label="worker-$$"
    use_worktree=false
    branch=""
    role="worker"
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --cwd)        cwd="$2";   shift 2 ;;
        --label)      label="$2"; shift 2 ;;
        --worktree)   use_worktree=true; shift ;;
        --branch)     branch="$2"; shift 2 ;;
        --role)       role="$2";  shift 2 ;;
        --max-workers) MAX_WORKERS="$2"; shift 2 ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
      esac
    done

    worker_count=$(wc -l < "$REGISTRY" | tr -d ' ')
    if [[ "$worker_count" -ge "$MAX_WORKERS" ]]; then
      close_count=$(( worker_count - MAX_WORKERS + 1 ))
      echo "Auto-closing $close_count old worker(s) to make room for new one..."
      while IFS=$'\t' read -r surf lbl cwd wt br start_epoch role; do
        [[ $close_count -le 0 ]] && break
        bash "$SCRIPT_DIR/piharness.sh" close "$surf" >/dev/null 2>&1 || true
        echo "  Closed $surf ($lbl)"
        close_count=$(( close_count - 1 ))
      done < "$REGISTRY"
      worker_count=$(wc -l < "$REGISTRY" | tr -d ' ')
    fi

    ws_flag=""
    # Detect current workspace from cmux tree output (prefers ref format like workspace:1)
    detected_ws=$(cmux tree --all 2>/dev/null | grep -oE 'workspace:[0-9]+' | head -1)
    if [[ -n "$detected_ws" ]]; then
      ws_flag="--workspace $detected_ws"
    elif [[ -n "${CMUX_WORKSPACE_ID:-}" ]]; then
      # Fallback: convert UUID to ref by listing workspaces
      ws_ref=$(cmux list-workspaces 2>/dev/null | grep -oE 'workspace:[0-9]+' | head -1)
      [[ -n "$ws_ref" ]] && ws_flag="--workspace $ws_ref"
    fi

    if [[ "$worker_count" -eq 0 ]]; then
      raw=$(cmux new-split right $ws_flag --focus false 2>&1)
    else
      split_from=$(cat "$LAST_SURFACE_FILE" 2>/dev/null || echo "")
      if [[ -n "$split_from" ]]; then
        raw=$(cmux new-split down --surface "$split_from" $ws_flag --focus false 2>&1)
      else
        raw=$(cmux new-split down $ws_flag --focus false 2>&1)
      fi
    fi

    surface=$(printf '%s' "$raw" | grep -oE 'surface:[0-9]+' | head -1)
    [[ -z "$surface" ]] && { echo "ERROR: could not parse surface from: $raw" >&2; exit 1; }

    worktree_path=""
    if [[ "$use_worktree" == true ]]; then
      branch="${branch:-piharness/$label}"
      worktree_path="$WORKTREES_DIR/$label"
      git -C "$REPO_DIR" worktree add -B "$branch" "$worktree_path" HEAD >/dev/null 2>&1
      cwd="$worktree_path"
    fi

    _cmux_label_tab "$surface" "$label"
    cmux send --surface "$surface" "cd $(printf '%q' "$cwd")"$'\n' >/dev/null
    _cmux_set_worker_status "$surface" "idle"
    _autostart_runtime "$surface"
    echo "$surface" > "$LAST_SURFACE_FILE"

    start_epoch=$(date +%s)
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$surface" "$label" "$cwd" "$worktree_path" "$branch" "$start_epoch" "$role" >> "$REGISTRY"
    _log "$surface" "SPAWNED" "label=$label cwd=$cwd worktree=${worktree_path} branch=${branch} role=${role}"
    echo "$surface"
    ;;

  # ---------------------------------------------------------------------------
  use)
  # Usage: piharness use <surface> [--label LABEL] [--role ROLE]
  # ---------------------------------------------------------------------------
    [[ $# -lt 1 ]] && { echo "Usage: piharness use <surface> [--label LABEL] [--role ROLE]" >&2; exit 1; }
    surface="$1"; shift
    label="worker-$$"
    role="worker"
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --label) label="$2"; shift 2 ;;
        --role)  role="$2";  shift 2 ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
      esac
    done
    start_epoch=$(date +%s)
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$surface" "$label" "$(pwd)" "" "" "$start_epoch" "$role" >> "$REGISTRY"
    _log "$surface" "REGISTERED" "label=$label role=$role"
    echo "Registered $surface as $label (role=$role)"
    ;;

  # ---------------------------------------------------------------------------
  start)
  # Usage: piharness start <surface> [--runtime TYPE:MODEL] [--continue]
  # Start an interactive runtime (Pi/opencode/ollama/claude) in the worker pane.
  # ---------------------------------------------------------------------------
    [[ $# -lt 1 ]] && { echo "Usage: piharness start <surface> [--runtime TYPE:MODEL] [--continue]" >&2; exit 1; }
    surface="$1"; shift
    entry=$(_rt_current "$surface")
    do_continue=false
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --runtime)  entry="$2"; shift 2 ;;
        --continue) do_continue=true; shift ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
      esac
    done

    type=$(_rt_type "$entry")
    model=$(_rt_model "$entry")
    cont_flag=""
    [[ "$do_continue" == true ]] && cont_flag=" --continue"

    case "$type" in
      pi)
        cmux send --surface "$surface" "pi --model $(printf '%q' "$model")${cont_flag}"$'\n' >/dev/null
        ;;
      opencode)
        local_mflag=""
        [[ "$model" != "auto" ]] && local_mflag=" -m $(printf '%q' "$model")"
        cmux send --surface "$surface" "opencode${local_mflag}"$'\n' >/dev/null
        ;;
      ollama)
        cmux send --surface "$surface" "ollama run $(printf '%q' "$model")"$'\n' >/dev/null
        ;;
      claude)
        local_mflag=""
        [[ "$model" != "default" ]] && local_mflag=" --model $(printf '%q' "$model")"
        cmux send --surface "$surface" "claude${local_mflag}"$'\n' >/dev/null
        ;;
      gemini)
        cmux send --surface "$surface" "gemini"$'\n' >/dev/null
        ;;
      codex)
        cmux send --surface "$surface" "codex"$'\n' >/dev/null
        ;;
      droid)
        cmux send --surface "$surface" "droid"$'\n' >/dev/null
        ;;
    esac
    _log "$surface" "STARTED" "runtime=$entry continue=$do_continue"
    echo "Started $type ($model) on $surface"
    ;;

  # ---------------------------------------------------------------------------
  task)
  # Usage: piharness task <surface> <prompt>
  # Run task non-interactively. Output saved to file.
  # ---------------------------------------------------------------------------
    [[ $# -lt 2 ]] && { echo "Usage: piharness task <surface> <prompt>" >&2; exit 1; }
    surface="$1"; prompt="$2"
    _cmux_surface_healthy "$surface" || { echo "ERROR: $surface not found or unhealthy" >&2; exit 1; }
    outfile="$(_outfile "$surface")"
    rm -f "$outfile"

    entry=$(_rt_current "$surface")
    wt=$(_registry_get "$surface" 4)

    tmpfile=$(mktemp /tmp/piharness_prompt.XXXXXX)
    printf '%s' "$prompt" > "$tmpfile"

    runtime_cmd=$(_rt_cmd "$entry" "$tmpfile" "$outfile" "$wt")

    # Break out of any interactive CLI session before running non-interactive task
    _break_pane "$surface"

    # Build post-run: mark errors, auto-commit if worktree, mark done, relaunch CLI
    error_check="if grep -qiE 'token limit|rate limit|quota|Error: Model stopped|context length' $(printf '%q' "$outfile") 2>/dev/null; then echo '__PIHARNESS_ERROR__' >> $(printf '%q' "$outfile"); fi"
    git_commit=""
    [[ -n "$wt" ]] && git_commit="git -C $(printf '%q' "$wt") add -A 2>/dev/null; git -C $(printf '%q' "$wt") commit -m 'feat: task output' --allow-empty 2>/dev/null; "
    relaunch=$(_restart_cmd)

    full_cmd="${runtime_cmd}; ${error_check}; ${git_commit}echo '__PIHARNESS_DONE__' >> $(printf '%q' "$outfile"); rm -f $(printf '%q' "$tmpfile")${relaunch:+; $relaunch}"

    cmux send --surface "$surface" "$full_cmd"$'\n' >/dev/null
    _cmux_set_worker_status "$surface" "running"
    _log "$surface" "TASK_SENT" "runtime=$entry prompt=${prompt:0:100}"
    echo "Task sent via $entry → $outfile"
    ;;

  # ---------------------------------------------------------------------------
  auto)
  # Usage: piharness auto <surface> <prompt> [--timeout N] [--no-cooldown]
  # Send task and auto-switch runtimes on failure until the chain is exhausted.
  # Tracks usage, detects rate limits intelligently, and retries the best
  # runtime after a cooldown period when all runtimes are exhausted.
  # ---------------------------------------------------------------------------
    [[ $# -lt 2 ]] && { echo "Usage: piharness auto <surface> <prompt> [--timeout N] [--no-cooldown]" >&2; exit 1; }
    surface="$1"; prompt="$2"; shift 2
    timeout=300; no_cooldown=false
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --timeout)    timeout="$2";     shift 2 ;;
        --no-cooldown) no_cooldown=true; shift   ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
      esac
    done

    chain_len=$(_chain_len)
    attempt=0

    while true; do
      idx=$(_rt_idx "$surface")
      entry=$(_chain_entry "$idx")

      # Check cooldown — if this runtime is cooling down, skip to next
      cooldown_sec=$(_usage_get_cooldown "$entry")
      if [[ "$cooldown_sec" -gt 0 ]]; then
        echo "  $entry cooling down for ${cooldown_sec}s — skipping"
        _advance_runtime "$surface" "$chain_len" "$entry" || exit 1
        continue
      fi

      echo "Attempt $((attempt+1)) via $entry"
      attempt=$((attempt + 1))

      bash "$SCRIPT_DIR/piharness.sh" task "$surface" "$prompt"

      outfile="$(_outfile "$surface")"
      deadline=$(( SECONDS + timeout ))
      printf "  Waiting"
      done_flag=false
      while [[ $SECONDS -lt $deadline ]]; do
        if grep -q '__PIHARNESS_DONE__' "$outfile" 2>/dev/null; then
          done_flag=true; break
        fi
        printf '.'; sleep 3
      done
      echo ""

      if [[ "$done_flag" == true ]]; then
        if grep -q '__PIHARNESS_ERROR__' "$outfile" 2>/dev/null; then
          fail_reason=$(_usage_classify_failure "$outfile" false)
          _usage_record "$entry" "$fail_reason" "attempt $attempt: $(echo "$prompt" | head -c 80)"
          echo "  $entry error ($fail_reason) — switching runtime"
          _log "$surface" "RUNTIME_ERROR" "$entry ($fail_reason)"

          if [[ "$fail_reason" == "rate_limited" ]]; then
            _usage_set_cooldown "$entry" 60
          fi
          _advance_runtime "$surface" "$chain_len" "$entry" || exit 1
          continue
        else
          _usage_record "$entry" "success" "attempt $attempt: $(echo "$prompt" | head -c 80)"
          _cmux_set_worker_status "$surface" "done"
          echo "Done via $entry"
          _log "$surface" "TASK_COMPLETE" "attempts=$attempt runtime=$entry"
          exit 0
        fi
      else
        fail_reason=$(_usage_classify_failure "$outfile" true)
        _usage_record "$entry" "$fail_reason" "attempt $attempt: timeout"
        _cmux_set_worker_status "$surface" "error"
        _log "$surface" "RUNTIME_TIMEOUT" "$entry"
        echo "  $entry timeout ($fail_reason)"

        if [[ "$fail_reason" == "rate_limited" ]]; then
          _usage_set_cooldown "$entry" 60
        fi

        if ! _advance_runtime "$surface" "$chain_len" "$entry"; then
          if [[ "$no_cooldown" == false ]]; then
            echo "All $chain_len runtimes exhausted. Waiting for cooldown before retry..."
            _usage_stats 2>/dev/null || true
            best=$(_usage_best_runtime)
            if [[ -n "$best" ]]; then
              best_cooldown=$(_usage_get_cooldown "$best")
              if [[ "$best_cooldown" -gt 0 ]]; then
                echo "Best runtime ($best) cooling down ${best_cooldown}s — waiting..."
                sleep "$best_cooldown"
              fi
              echo "Retrying with best runtime: $best"
              _rt_set_idx "$surface" 0
              attempt=0
              prompt="Continue from where you left off. Complete the task that was interrupted. Resume and finish."
              rm -f "$outfile"
              continue
            fi
          fi
          echo "ERROR: all runtimes exhausted" >&2
          exit 1
        fi
        continue
      fi
    done
    ;;

  # ---------------------------------------------------------------------------
  pipeline)
  # Usage: piharness pipeline <task-description> [--rounds N] [--timeout N]
  #
  # Orchestrates: implementer → tester → reviewer → back to implementer if rejected
  # Workers must already be spawned with --role implementer/tester/reviewer.
  # The loop runs up to N rounds (default 3) until reviewer approves.
  # ---------------------------------------------------------------------------
    [[ $# -lt 1 ]] && { echo "Usage: piharness pipeline <task> [--rounds N] [--timeout N]" >&2; exit 1; }
    pipeline_task="$1"; shift
    pipeline_rounds=3
    pipeline_timeout=300
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --rounds)  pipeline_rounds="$2";  shift 2 ;;
        --timeout) pipeline_timeout="$2"; shift 2 ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
      esac
    done

    impl_surface=$(_registry_first_role "implementer")
    test_surface=$(_registry_first_role "tester")
    review_surface=$(_registry_first_role "reviewer")

    if [[ -z "$impl_surface" ]]; then
      echo "ERROR: no implementer found. Spawn one with: piharness spawn --role implementer" >&2
      exit 1
    fi
    if [[ -z "$test_surface" ]]; then
      echo "ERROR: no tester found. Spawn one with: piharness spawn --role tester" >&2
      exit 1
    fi
    if [[ -z "$review_surface" ]]; then
      echo "ERROR: no reviewer found. Spawn one with: piharness spawn --role reviewer" >&2
      exit 1
    fi

    echo "Pipeline surfaces — implementer: $impl_surface  tester: $test_surface  reviewer: $review_surface"

    feedback=""
    round=1
    while [[ $round -le $pipeline_rounds ]]; do
      echo ""
      echo "── Round $round/$pipeline_rounds ──────────────────────────────"

      # Build implementer prompt
      if [[ -n "$feedback" ]]; then
        impl_prompt="ROLE: Implementer. Task: ${pipeline_task}. Feedback from previous review: ${feedback}. Write the implementation. When done, end your response with IMPLEMENTATION COMPLETE."
      else
        impl_prompt="ROLE: Implementer. Task: ${pipeline_task}. Write the implementation. When done, end your response with IMPLEMENTATION COMPLETE."
      fi

      echo "[Round $round] Sending to implementer ($impl_surface)..."
      bash "$SCRIPT_DIR/piharness.sh" task "$impl_surface" "$impl_prompt"
      bash "$SCRIPT_DIR/piharness.sh" wait "$impl_surface" --timeout "$pipeline_timeout" || true

      impl_output=$(grep -v -E '__PIHARNESS_DONE__|__PIHARNESS_ERROR__' \
        "$(_outfile "$impl_surface")" 2>/dev/null | head -c 2000 || true)

      echo "[Round $round] Sending to tester ($test_surface)..."
      test_prompt="ROLE: Tester. Review this implementation and write tests:

${impl_output}

Test the code, report any failures. End with TEST RESULTS: PASS or TEST RESULTS: FAIL with details."

      bash "$SCRIPT_DIR/piharness.sh" task "$test_surface" "$test_prompt"
      bash "$SCRIPT_DIR/piharness.sh" wait "$test_surface" --timeout "$pipeline_timeout" || true

      test_output=$(grep -v -E '__PIHARNESS_DONE__|__PIHARNESS_ERROR__' \
        "$(_outfile "$test_surface")" 2>/dev/null | head -c 2000 || true)

      echo "[Round $round] Sending to reviewer ($review_surface)..."
      review_prompt="ROLE: Reviewer. Review this implementation and test results:

IMPLEMENTATION:
${impl_output}

TEST RESULTS:
${test_output}

Provide your review. End with either:
APPROVED
or
REJECTED
{reason}"

      bash "$SCRIPT_DIR/piharness.sh" task "$review_surface" "$review_prompt"
      bash "$SCRIPT_DIR/piharness.sh" wait "$review_surface" --timeout "$pipeline_timeout" || true

      review_output=$(grep -v -E '__PIHARNESS_DONE__|__PIHARNESS_ERROR__' \
        "$(_outfile "$review_surface")" 2>/dev/null || true)

      if echo "$review_output" | grep -qiE '^APPROVED$|^APPROVED[[:space:]]'; then
        echo ""
        echo "Pipeline APPROVED after $round round(s)."
        exit 0
      elif echo "$review_output" | grep -qiE '^REJECTED'; then
        feedback=$(echo "$review_output" | grep -iA9999 '^REJECTED' | tail -n +2 | head -c 1000 || true)
        echo "Round $round: REJECTED. Feedback: ${feedback:0:200}"
      else
        echo "Round $round: reviewer output did not contain APPROVED or REJECTED — treating as rejection."
        feedback=$(echo "$review_output" | tail -c 1000 || true)
      fi

      round=$(( round + 1 ))
    done

    echo "Pipeline stalled after $pipeline_rounds rounds without approval." >&2
    exit 1
    ;;

  # ---------------------------------------------------------------------------
  supervise)
  # Usage: piharness supervise <task> [--runtime TYPE:MODEL] [--timeout N]
  #
  # Run an orchestrator task with automatic handoff on token exhaustion.
  # Wraps the orchestrator in a monitoring loop: if the orchestrator hits
  # token limits (context window, rate limits, token budget), this detects
  # it in the output, snapshots state, and hands off to the next runtime
  # in the chain. Keeps going until the task is complete or all runtimes
  # are exhausted.
  #
  # This is the "it just works" orchestrator mode — use it for overnight
  # self-evolution and long-running tasks.
  # ---------------------------------------------------------------------------
    [[ $# -lt 1 ]] && { echo "Usage: piharness supervise <task> [--runtime TYPE:MODEL] [--timeout N]" >&2; exit 1; }
    sup_task="$1"; shift
    sup_timeout=600
    sup_runtime="${PIHARNESS_ORCHESTRATOR:-}"
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --runtime) sup_runtime="$2"; shift 2 ;;
        --timeout) sup_timeout="$2"; shift 2 ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
      esac
    done

    trap 'bash "$SCRIPT_DIR/piharness.sh" clean 2>/dev/null || true' EXIT

    chain_len=$(_chain_len)
    attempt=0

    while [[ $attempt -lt $chain_len ]]; do
      if [[ -n "$sup_runtime" ]]; then
        idx=0
        while IFS= read -r entry; do
          [[ "$entry" == "$sup_runtime" ]] && break
          idx=$((idx + 1))
        done < <(echo "$RUNTIME_CHAIN" | tr ',' '\n')
        sup_runtime=""
      else
        idx=$attempt
      fi

      entry=$(_chain_entry "$idx")
      sup_surface=$(_registry_first_role "orchestrator")
      if [[ -z "$sup_surface" ]]; then
        sup_surface=$(cmux new-split right --focus false 2>&1 | grep -oE 'surface:[0-9]+' | head -1)
        if [[ -z "$sup_surface" ]]; then
          echo "ERROR: could not create orchestrator surface" >&2; exit 1
        fi
        start_epoch=$(date +%s)
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
          "$sup_surface" "supervise-orch" "$SCRIPT_DIR" "" "" "$start_epoch" "orchestrator" >> "$REGISTRY"
        _rt_set_idx "$sup_surface" "$idx"
        bash "$SCRIPT_DIR/piharness.sh" start "$sup_surface" --runtime "$entry" 2>/dev/null || true
        sleep 2
      else
        _rt_set_idx "$sup_surface" "$idx"
      fi

      echo "Supervise attempt $((attempt+1))/$chain_len via $entry"
      _log "$sup_surface" "SUPERVISE_START" "runtime=$entry task=${sup_task:0:80}"

      bash "$SCRIPT_DIR/piharness.sh" task "$sup_surface" "$sup_task"

      outfile="$(_outfile "$sup_surface")"
      deadline=$(( SECONDS + sup_timeout ))
      printf "  Monitoring"
      done_flag=false
      limited_flag=false

      while [[ $SECONDS -lt $deadline ]]; do
        # Check for completion
        if grep -q '__PIHARNESS_DONE__' "$outfile" 2>/dev/null; then
          if ! grep -q '__PIHARNESS_ERROR__' "$outfile" 2>/dev/null; then
            done_flag=true; break
          fi
        fi
        # Check for token limit / context exhaustion signals
        if grep -qiE \
          'token limit|rate limit|context length|maximum context|too many tokens|billing|quota exceeded|context_window|token budget|insufficient_quota|model.*not.*available|hit.*limit|exceeded.*limit|Context exceeded|token.*exhausted' \
          "$outfile" 2>/dev/null; then
          if [[ "$done_flag" == false ]]; then
            limited_flag=true; break
          fi
        fi
        printf '.'; sleep 5
      done
      echo ""

      if [[ "$done_flag" == true ]]; then
        _usage_record "$entry" "success" "supervise: ${sup_task:0:80}"
        echo "Orchestration complete via $entry"
        _log "$sup_surface" "SUPERVISE_DONE" "runtime=$entry"
        exit 0
      fi

      # Token limit or timeout — handoff to next runtime
      if [[ "$limited_flag" == true ]]; then
        _usage_record "$entry" "rate_limited" "supervise: ${sup_task:0:80}"
        echo "  $entry hit a limit — handing off"
        _usage_set_cooldown "$entry" 60
      else
        _usage_record "$entry" "timeout" "supervise: ${sup_task:0:80}"
        echo "  $entry timed out — handing off"
      fi

      _log "$sup_surface" "SUPERVISE_HANDOFF" "runtime=$entry -> chain[$((idx+1))]"

      next_idx=$((idx + 1))
      if [[ "$next_idx" -ge "$chain_len" ]]; then
        best=$(_usage_best_runtime)
        if [[ -n "$best" ]]; then
          cooldown=$(_usage_get_cooldown "$best")
          echo "  All runtimes exhausted, best=$best cooldown=${cooldown}s"
          if [[ "$cooldown" -gt 0 ]]; then sleep "$cooldown"; fi
          attempt=0
          sup_task="Continue from handoff. ${sup_task}"
          continue
        fi
        echo "ERROR: all runtimes exhausted, no handoff target available" >&2
        exit 1
      fi

      next_entry=$(_chain_entry "$next_idx")
      echo "  Handing off to $next_entry"

      bash "$SCRIPT_DIR/piharness.sh" handoff \
        --runtime "$next_entry" \
        --task "Continue orchestrating. Previous runtime ($entry) hit a limit. ${sup_task}" 2>&1 || true

      sup_task="Continue from handoff. ${sup_task}"
      attempt=$((attempt + 1))
    done

    echo "ERROR: all $chain_len orchestration attempts exhausted" >&2
    exit 1
    ;;

  # ---------------------------------------------------------------------------
  orchestrate)
  # Usage: piharness orchestrate <surface> <task>
  # Run a task on the orchestrator-role worker (or any worker if none designated).
  # Supports PIHARNESS_ORCHESTRATOR env var to override runtime for orchestration.
  # ---------------------------------------------------------------------------
    [[ $# -lt 2 ]] && { echo "Usage: piharness orchestrate <surface> <task>" >&2; exit 1; }
    orch_surface="$1"; orch_task="$2"

    # If surface is "auto", find the orchestrator-role surface
    if [[ "$orch_surface" == "auto" ]]; then
      orch_surface=$(_registry_first_role "orchestrator")
      if [[ -z "$orch_surface" ]]; then
        orch_surface=$(_registry_first_role "worker")
      fi
      if [[ -z "$orch_surface" ]]; then
        echo "ERROR: no orchestrator or worker surface found in registry" >&2
        exit 1
      fi
    fi

    # If PIHARNESS_ORCHESTRATOR is set, temporarily override the runtime index
    if [[ -n "${PIHARNESS_ORCHESTRATOR:-}" ]]; then
      # Find the index of the requested runtime in the chain
      override_idx=0
      found_idx=""
      while IFS= read -r entry; do
        if [[ "$entry" == "$PIHARNESS_ORCHESTRATOR" ]]; then
          found_idx="$override_idx"
          break
        fi
        override_idx=$(( override_idx + 1 ))
      done < <(echo "$RUNTIME_CHAIN" | tr ',' '\n')
      if [[ -n "$found_idx" ]]; then
        _rt_set_idx "$orch_surface" "$found_idx"
        echo "Orchestrate: overriding runtime to $PIHARNESS_ORCHESTRATOR (idx=$found_idx)"
      else
        echo "WARNING: PIHARNESS_ORCHESTRATOR='$PIHARNESS_ORCHESTRATOR' not found in chain, using current runtime" >&2
      fi
    fi

    bash "$SCRIPT_DIR/piharness.sh" task "$orch_surface" "$orch_task"
    ;;

  # ---------------------------------------------------------------------------
  handoff)
  # Usage: piharness handoff [--runtime TYPE:MODEL] [--task "what to continue"]
  #
  # Snapshot current orchestration state and hand off to a different AI runtime
  # (Pi, OpenCode, Ollama, Claude) so work continues when the current master
  # orchestrator (e.g. Claude Code) hits its token/session limit.
  # The new orchestrator is launched interactively with a full briefing.
  # ---------------------------------------------------------------------------
    handoff_runtime="${PIHARNESS_ORCHESTRATOR:-}"
    handoff_task="Continue orchestrating the workers toward task completion."
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --runtime) handoff_runtime="$2"; shift 2 ;;
        --task)    handoff_task="$2";    shift 2 ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
      esac
    done

    if [[ -z "$handoff_runtime" ]]; then
      echo "ERROR: specify --runtime TYPE:MODEL or set PIHARNESS_ORCHESTRATOR" >&2
      echo "  Examples:" >&2
      echo "    piharness handoff --runtime ollama:qwen2.5-coder:7b" >&2
      echo "    piharness handoff --runtime pi:kilo-auto/free" >&2
      echo "    piharness handoff --runtime opencode:anthropic/claude-haiku-4-5" >&2
      exit 1
    fi

    # ── Build state snapshot ──────────────────────────────────────────────────
    state_snap="CURRENT WORKERS:\n"
    if [[ -s "$REGISTRY" ]]; then
      while IFS=$'\t' read -r surf lbl cwd wt br start_epoch role; do
        status=$(_worker_status "$surf")
        runtime=$(_rt_current "$surf")
        state_snap+="  $surf  role=${role:-worker}  status=$status  runtime=${runtime}  branch=${br:-none}  label=$lbl\n"
        outfile="$(_outfile "$surf")"
        if [[ -f "$outfile" ]]; then
          recent=$(grep -v -E '__PIHARNESS_DONE__|__PIHARNESS_ERROR__' "$outfile" \
                   2>/dev/null | tail -8 | cut -c1-120 | tr '\n' '|' || true)
          [[ -n "$recent" ]] && state_snap+="    recent: ${recent}\n"
        fi
      done < "$REGISTRY"
    else
      state_snap+="  (none)\n"
    fi

    # ── Build handoff prompt ──────────────────────────────────────────────────
    harness_path="$SCRIPT_DIR/piharness.sh"
    handoff_prompt="You are taking over as the PIHARNESS orchestrator. The previous master orchestrator hit its token limit and has handed control to you.

CONTINUATION TASK: ${handoff_task}

$(printf '%b' "$state_snap")
YOUR SHELL TOOLS (run these in the terminal):
  bash ${harness_path} status                        # see all workers + statuses
  bash ${harness_path} task <surface> \"<prompt>\"    # send work to a worker
  bash ${harness_path} wait <surface>                # block until worker finishes
  bash ${harness_path} collect <surface>             # read worker output
  bash ${harness_path} peek <surface>                # partial output mid-run
  bash ${harness_path} pipeline \"<task>\"            # full impl→test→review loop
  bash ${harness_path} spawn --role implementer      # spawn new worker
  bash ${harness_path} screen <surface>              # capture live pane
  bash ${harness_path} diff <s1> <s2>               # git diff worktree branches
  bash ${harness_path} close <surface>              # close worker pane

INSTRUCTIONS:
1. Run status first: bash ${harness_path} status
2. Continue the task above using the registered workers.
3. When complete, commit each worktree and output: HANDOFF COMPLETE"

    tmpfile=$(mktemp /tmp/piharness_handoff.XXXXXX)
    printf '%s' "$handoff_prompt" > "$tmpfile"

    # ── Spawn new pane ────────────────────────────────────────────────────────
    split_from=$(cat "$LAST_SURFACE_FILE" 2>/dev/null || echo "")
    if [[ -n "$split_from" ]]; then
      raw=$(cmux new-split down --surface "$split_from" --focus false 2>&1)
    else
      raw=$(cmux new-split right --focus false 2>&1)
    fi
    new_surface=$(printf '%s' "$raw" | grep -oE 'surface:[0-9]+' | head -1)
    if [[ -z "$new_surface" ]]; then
      echo "ERROR: could not spawn handoff pane: $raw" >&2
      rm -f "$tmpfile"; exit 1
    fi

    start_epoch=$(date +%s)
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$new_surface" "orch-handoff" "$SCRIPT_DIR" "" "" "$start_epoch" "orchestrator" >> "$REGISTRY"
    echo "$new_surface" > "$LAST_SURFACE_FILE"

    cmux send --surface "$new_surface" "cd $(printf '%q' "$SCRIPT_DIR")"$'\n' >/dev/null
    sleep 0.5

    # ── Launch the new orchestrator runtime ───────────────────────────────────
    htype=$(_rt_type "$handoff_runtime")
    hmodel=$(_rt_model "$handoff_runtime")
    case "$htype" in
      pi)
        cmux send --surface "$new_surface" \
          "pi --model $(printf '%q' "$hmodel") \"$(cat "$tmpfile")\""$'\n' >/dev/null
        ;;
      opencode)
        local_mf=""
        [[ "$hmodel" != "auto" ]] && local_mf="-m $(printf '%q' "$hmodel")"
        cmux send --surface "$new_surface" "opencode $local_mf"$'\n' >/dev/null
        sleep 2
        # Send the briefing as first message
        cmux send --surface "$new_surface" "$(cat "$tmpfile")"$'\n' >/dev/null
        ;;
      ollama)
        cmux send --surface "$new_surface" \
          "ollama run $(printf '%q' "$hmodel") \"$(cat "$tmpfile")\""$'\n' >/dev/null
        ;;
      claude)
        local_mf=""
        [[ "$hmodel" != "default" ]] && local_mf="--model $(printf '%q' "$hmodel")"
        cmux send --surface "$new_surface" "claude $local_mf"$'\n' >/dev/null
        sleep 2
        cmux send --surface "$new_surface" "$(cat "$tmpfile")"$'\n' >/dev/null
        ;;
      gemini)
        cmux send --surface "$new_surface" "gemini --prompt \"$(cat "$tmpfile")\""$'\n' >/dev/null
        ;;
      codex)
        cmux send --surface "$new_surface" "codex --prompt \"$(cat "$tmpfile")\""$'\n' >/dev/null
        ;;
      droid)
        cmux send --surface "$new_surface" "droid \"$(cat "$tmpfile")\""$'\n' >/dev/null
        ;;
      *)
        echo "ERROR: unknown runtime type: $htype" >&2
        rm -f "$tmpfile"; exit 1 ;;
    esac

    rm -f "$tmpfile"
    _log "$new_surface" "HANDOFF" "runtime=$handoff_runtime task=${handoff_task:0:80}"

    echo ""
    echo "Handoff initiated."
    echo "  New orchestrator : $handoff_runtime"
    echo "  Pane             : $new_surface"
    echo "  Task             : ${handoff_task:0:80}"
    echo ""
    echo "Monitor it: bash $harness_path screen $new_surface"
    ;;

  # ---------------------------------------------------------------------------
  monitor)
  # Usage: piharness monitor <surface> [--daemon]
  # Background process: watches interactive pane for errors and auto-switches.
  # ---------------------------------------------------------------------------
    [[ $# -lt 1 ]] && { echo "Usage: piharness monitor <surface> [--daemon]" >&2; exit 1; }
    surface="$1"; shift
    daemon=false
    [[ "${1:-}" == "--daemon" ]] && daemon=true

    monpid_file="$(_monfile "$surface")"

    if [[ "$daemon" == true ]]; then
      # Launch self in background
      bash "$SCRIPT_DIR/piharness.sh" monitor "$surface" &
      echo $! > "$monpid_file"
      echo "Monitor started (PID $(cat "$monpid_file")) for $surface"
      exit 0
    fi

    # Foreground monitor loop
    chain_len=$(_chain_len)
    echo "Monitoring $surface (Ctrl-C to stop)"
    while true; do
      screen=$(cmux read-screen --surface "$surface" --scrollback 2>&1 || cmux capture-pane --surface "$surface" 2>&1 || echo "SURFACE_GONE")

      if [[ "$screen" == "SURFACE_GONE" ]]; then
        echo "Surface $surface gone — monitor exiting"
        break
      fi

      if echo "$screen" | grep -qiE 'token limit|rate limit|quota|Error: Model stopped|context length'; then
        idx=$(_rt_idx "$surface")
        next_idx=$((idx + 1))
        if [[ $next_idx -ge $chain_len ]]; then
          echo "$(date): All runtimes exhausted for $surface"
          _log "$surface" "MONITOR_EXHAUSTED" ""
          break
        fi
        next_entry=$(_chain_entry "$next_idx")
        echo "$(date): Error detected on $surface — switching to $next_entry"
        _log "$surface" "MONITOR_SWITCH" "$(_chain_entry "$idx") → $next_entry"

        _rt_set_idx "$surface" "$next_idx"
        _break_pane "$surface"
        sleep 2

        # Start next runtime with continue
        bash "$SCRIPT_DIR/piharness.sh" start "$surface" --runtime "$next_entry" --continue
        sleep 5
        cmux send --surface "$surface" "Continue from where you left off. Complete the implementation."$'\n' >/dev/null
      fi

      sleep 5
    done
    ;;

  # ---------------------------------------------------------------------------
  switch)
  # Usage: piharness switch <surface> [--runtime TYPE:MODEL] [--next]
  # Manually switch a worker to the next runtime or a specific one.
  # ---------------------------------------------------------------------------
    [[ $# -lt 1 ]] && { echo "Usage: piharness switch <surface> [--runtime TYPE:MODEL|--next]" >&2; exit 1; }
    surface="$1"; shift
    target=""
    next_mode=false
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --runtime) target="$2"; shift 2 ;;
        --next)    next_mode=true; shift ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
      esac
    done

    if [[ "$next_mode" == true || -z "$target" ]]; then
      idx=$(_rt_idx "$surface")
      next_idx=$((idx + 1))
      chain_len=$(_chain_len)
      [[ $next_idx -ge $chain_len ]] && { echo "Already at last runtime in chain" >&2; exit 1; }
      _rt_set_idx "$surface" "$next_idx"
      target=$(_chain_entry "$next_idx")
    fi

    _break_pane "$surface"
    sleep 2
    bash "$SCRIPT_DIR/piharness.sh" start "$surface" --runtime "$target" --continue
    _log "$surface" "MANUAL_SWITCH" "→ $target"
    echo "Switched $surface to $target"
    ;;

  # ---------------------------------------------------------------------------
  wait)
  # Usage: piharness wait <surface> [--timeout N]
  # ---------------------------------------------------------------------------
    [[ $# -lt 1 ]] && { echo "Usage: piharness wait <surface> [--timeout N]" >&2; exit 1; }
    surface="$1"; shift
    _cmux_surface_healthy "$surface" || { echo "WARNING: $surface not found via cmux, checking output files anyway..." >&2; }
    timeout=300
    [[ "${1:-}" == "--timeout" ]] && timeout="$2"

    outfile="$(_outfile "$surface")"
    deadline=$(( SECONDS + timeout ))
    printf "Waiting for %s " "$surface"
    while [[ $SECONDS -lt $deadline ]]; do
      if grep -q '__PIHARNESS_DONE__' "$outfile" 2>/dev/null; then
        echo " done"
        _cmux_set_worker_status "$surface" "done"
        cmux notify --title "PIHARNESS" --body "Worker $surface done" 2>/dev/null || true
        _log "$surface" "TASK_DONE" ""
        exit 0
      fi
      printf '.'; sleep 2
    done
    echo " TIMEOUT" >&2
    _cmux_set_worker_status "$surface" "error"
    _log "$surface" "TASK_TIMEOUT" "after ${timeout}s"
    exit 1
    ;;

  # ---------------------------------------------------------------------------
  collect)
  # Usage: piharness collect <surface>
  # ---------------------------------------------------------------------------
    [[ $# -lt 1 ]] && { echo "Usage: piharness collect <surface>" >&2; exit 1; }
    surface="$1"
    _cmux_surface_healthy "$surface" || { echo "WARNING: $surface may be gone" >&2; }
    outfile="$(_outfile "$surface")"
    [[ -f "$outfile" ]] || { echo "No output for $surface" >&2; exit 1; }
    st=$(_worker_status "$surface")
    _cmux_set_worker_status "$surface" "$st"
    grep -v -E '__PIHARNESS_DONE__|__PIHARNESS_ERROR__' "$outfile"
    ;;

  # ---------------------------------------------------------------------------
  peek)
  # Usage: piharness peek <surface>
  # ---------------------------------------------------------------------------
    [[ $# -lt 1 ]] && { echo "Usage: piharness peek <surface>" >&2; exit 1; }
    surface="$1"
    _cmux_surface_healthy "$surface" || { echo "WARNING: $surface may be gone" >&2; }
    outfile="$(_outfile "$surface")"
    [[ -f "$outfile" ]] || { echo "(no output yet)"; exit 0; }
    echo "── $surface [$(_worker_status "$surface")] ──"
    grep -v -E '__PIHARNESS_DONE__|__PIHARNESS_ERROR__' "$outfile"
    ;;

  # ---------------------------------------------------------------------------
  screen)
  # Usage: piharness screen <surface>
  # ---------------------------------------------------------------------------
    [[ $# -lt 1 ]] && { echo "Usage: piharness screen <surface>" >&2; exit 1; }
    echo "── screen: $1 ──"
    cmux read-screen --surface "$1" --scrollback 2>&1 || cmux capture-pane --surface "$1" 2>&1 || echo "SURFACE_GONE"
    ;;

  # ---------------------------------------------------------------------------
  watch)
  # Usage: piharness watch <surface>
  # ---------------------------------------------------------------------------
    [[ $# -lt 1 ]] && { echo "Usage: piharness watch <surface>" >&2; exit 1; }
    echo "Watching $1 (Ctrl-C to stop)..."
    tail -f "$(_outfile "$1")" 2>/dev/null \
      | grep -v -E '__PIHARNESS_DONE__|__PIHARNESS_ERROR__' || true
    ;;

  # ---------------------------------------------------------------------------
  log)
  # Usage: piharness log <surface>
  # ---------------------------------------------------------------------------
    [[ $# -lt 1 ]] && { echo "Usage: piharness log <surface>" >&2; exit 1; }
    logfile="$(_logfile "$1")"
    [[ -f "$logfile" ]] || { echo "No log for $1" >&2; exit 1; }
    printf '%-25s %-18s %s\n' "TIMESTAMP" "EVENT" "DETAIL"
    printf '%-25s %-18s %s\n' "---------" "-----" "------"
    while IFS=$'\t' read -r ts event detail; do
      printf '%-25s %-18s %s\n' "$ts" "$event" "$detail"
    done < "$logfile"
    ;;

  # ---------------------------------------------------------------------------
  runtimes)
  # Usage: piharness runtimes [<surface>]
  # Show the runtime chain, highlighting current for a given worker.
  # ---------------------------------------------------------------------------
    echo "Runtime chain ($( _chain_len) entries):"
    idx=0
    while IFS= read -r entry; do
      marker="  "
      if [[ $# -ge 1 ]]; then
        cur=$(_rt_idx "$1")
        [[ "$idx" -eq "$cur" ]] && marker="->"
      fi
      printf '  %s [%d] %s\n' "$marker" "$idx" "$entry"
      idx=$((idx+1))
    done < <(echo "$RUNTIME_CHAIN" | tr ',' '\n')
    ;;

  # ---------------------------------------------------------------------------
  status)
  # Usage: piharness status
  # ---------------------------------------------------------------------------
    if [[ ! -s "$REGISTRY" ]]; then echo "No registered workers."; exit 0; fi
    echo ""
    printf '%-14s %-16s %-9s %-10s %-14s %-30s %s\n' \
      "SURFACE" "LABEL" "STATUS" "ELAPSED" "ROLE" "RUNTIME" "LAST OUTPUT"
    printf '%-14s %-16s %-9s %-10s %-14s %-30s %s\n' \
      "───────" "─────" "──────" "───────" "────" "───────" "───────────"
    while IFS=$'\t' read -r surf lbl cwd wt br start_epoch role; do
      outfile="$(_outfile "$surf")"
      status=$(_worker_status "$surf")
      elapsed=$(_elapsed "${start_epoch:-0}")
      runtime=$(_rt_current "$surf")
      last=$(grep -v -E '__PIHARNESS_DONE__|__PIHARNESS_ERROR__' "$outfile" 2>/dev/null \
             | grep -v '^$' | tail -1 | cut -c1-40 || echo "-")
      printf '%-14s %-16s %-9s %-10s %-14s %-30s %s\n' \
        "$surf" "$lbl" "$status" "$elapsed" "${role:-worker}" "${runtime:0:30}" "${last:--}"
    done < "$REGISTRY"
    echo ""
    cmux tree --all 2>/dev/null || true
    ;;

  # ---------------------------------------------------------------------------
  compare)
  # ---------------------------------------------------------------------------
    [[ $# -lt 2 ]] && { echo "Usage: piharness compare <surface1> <surface2>" >&2; exit 1; }
    for s in "$1" "$2"; do
      echo "══ $s ($(_worker_status "$s")) ══"
      grep -v -E '__PIHARNESS_DONE__|__PIHARNESS_ERROR__' \
        "$(_outfile "$s")" 2>/dev/null || echo "(no output yet)"
      echo
    done
    ;;

  # ---------------------------------------------------------------------------
  diff)
  # Usage: piharness diff <surface1> <surface2>
  # ---------------------------------------------------------------------------
    [[ $# -lt 2 ]] && { echo "Usage: piharness diff <surface1> <surface2>" >&2; exit 1; }
    b1=$(_registry_get "$1" 5); b2=$(_registry_get "$2" 5)
    [[ -z "$b1" || -z "$b2" ]] && { echo "ERROR: workers need --worktree to use diff" >&2; exit 1; }
    echo "── diff $b1 → $b2 ──"
    git -C "$REPO_DIR" diff "$b1".."$b2" || true
    ;;

  # ---------------------------------------------------------------------------
  list)
  # ---------------------------------------------------------------------------
    if [[ ! -s "$REGISTRY" ]]; then echo "No registered workers."; exit 0; fi
    printf '%-14s %-16s %-9s %-14s %-30s %-30s %s\n' \
      "SURFACE" "LABEL" "STATUS" "ROLE" "RUNTIME" "CWD" "BRANCH"
    printf '%-14s %-16s %-9s %-14s %-30s %-30s %s\n' \
      "───────" "─────" "──────" "────" "───────" "───" "──────"
    while IFS=$'\t' read -r surf lbl cwd wt br start_epoch role; do
      status=$(_worker_status "$surf")
      runtime=$(_rt_current "$surf")
      printf '%-14s %-16s %-9s %-14s %-30s %-30s %s\n' \
        "$surf" "$lbl" "$status" "${role:-worker}" "${runtime:0:30}" "${cwd:0:30}" "${br:-none}"
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

    # Stop monitor if running
    monpid_file="$(_monfile "$surface")"
    if [[ -f "$monpid_file" ]]; then
      kill "$(cat "$monpid_file")" 2>/dev/null || true
      rm -f "$monpid_file"
    fi

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

    last=$(cat "$LAST_SURFACE_FILE" 2>/dev/null || echo "")
    [[ "$last" == "$surface" ]] && rm -f "$LAST_SURFACE_FILE"

    _cmux_clear_worker_status "$surface"
    rm -f "$(_outfile "$surface")" "$(_rtfile "$surface")"
    _log "$surface" "CLOSED" ""
    echo "Closed $surface"
    ;;

  # ---------------------------------------------------------------------------
  clean)
  # ---------------------------------------------------------------------------
    rm -f "$OUTPUTS_DIR"/*.txt "$LOGS_DIR"/*.log \
          "$RUNTIMES_DIR"/*.idx "$MONITORS_DIR"/*.pid \
          "$LAST_SURFACE_FILE"
    > "$REGISTRY"
    echo "Cleaned."
    ;;

  # ---------------------------------------------------------------------------
  skill)
  # ---------------------------------------------------------------------------
  # Usage: piharness skill list|show|new|extract|suggest [args]
  # Manage the PIHARNESS skill library at ~/.piharness/skills/
    skill_cmd="${1:-list}"; shift || true
    case "$skill_cmd" in
      list)
        if [[ ! -f "$SKILLS_REGISTRY" ]]; then
          echo "No skills registry found at $SKILLS_REGISTRY. Create skills with 'skill new'." >&2
          exit 0
        fi
        echo ""
        printf '%-24s %-8s %-10s %-14s %s\n' "NAME" "VERSION" "USAGE" "CREATED" "DESCRIPTION"
        printf '%-24s %-8s %-10s %-14s %s\n' "────" "──────" "─────" "───────" "───────────"
        python3 -c "
import json
with open('$SKILLS_REGISTRY') as f:
    reg = json.load(f)
for s in reg.get('skills', []):
    print(f\"{s['name']:<24} {s['version']:<8} {s['usage_count']:<10} {s['created']:<14} {s['description']}\")
" 2>/dev/null || echo "Error reading registry"
        echo ""
        ;;
      show)
        [[ $# -lt 1 ]] && { echo "Usage: piharness skill show <name>" >&2; exit 1; }
        skill_name="$1"; shift
        skill_file="$SKILLS_DIR/$skill_name/SKILL.md"
        if [[ ! -f "$skill_file" ]]; then
          echo "ERROR: skill not found: $skill_name" >&2
          exit 1
        fi
        echo "── Skill: $skill_name ──"
        cat "$skill_file"
        echo ""
        # Increment usage_count
        python3 -c "
import json
with open('$SKILLS_REGISTRY') as f:
    reg = json.load(f)
for s in reg.get('skills', []):
    if s['name'] == '$skill_name':
        s['usage_count'] = s.get('usage_count', 0) + 1
        break
with open('$SKILLS_REGISTRY', 'w') as f:
    json.dump(reg, f, indent=2)
" 2>/dev/null || true
        ;;
      new)
        [[ $# -lt 1 ]] && { echo "Usage: piharness skill new <name> [--pattern P] [--desc D]" >&2; exit 1; }
        new_name="$1"; shift
        new_pattern=""; new_desc=""
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --pattern) new_pattern="$2"; shift 2 ;;
            --desc)    new_desc="$2";    shift 2 ;;
            *) echo "Unknown arg: $1" >&2; exit 1 ;;
          esac
        done
        [[ -z "$new_desc" ]] && new_desc="Custom skill: $new_name"
        new_dir="$SKILLS_DIR/$new_name"
        [[ -d "$new_dir" ]] && { echo "ERROR: skill already exists: $new_name" >&2; exit 1; }
        mkdir -p "$new_dir"
        cat > "$new_dir/SKILL.md" <<SKILL_EOF
---
name: $new_name
version: 1
created: $(date -u +%Y-%m-%d)
usage_count: 0
trigger_patterns: [${new_pattern:+$new_pattern}]
description: "$new_desc"
---
# Skill: $new_name

## Problem
[Describe the problem this skill solves]

## Pattern
[Describe the recommended pattern]

## Prevention
[Describe how to prevent this issue]
SKILL_EOF
        cat > "$new_dir/template.md" <<TEMPLATE_EOF
<skill:$new_name>
Apply the pattern from [[SKILL.md]] — $new_desc.
</skill>
TEMPLATE_EOF
        if [[ -f "$SKILLS_REGISTRY" ]]; then
          python3 -c "
import json
from datetime import datetime, timezone
reg_path = '$SKILLS_REGISTRY'
with open(reg_path) as f:
    reg = json.load(f)
new_skill = {
    'name': '$new_name',
    'version': 1,
    'created': datetime.now(timezone.utc).strftime('%Y-%m-%d'),
    'usage_count': 0,
    'trigger_patterns': [p.strip() for p in '$new_pattern'.split(',') if p.strip()],
    'description': '$new_desc',
    'path': '$new_dir'
}
reg['skills'].append(new_skill)
reg['last_updated'] = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
with open(reg_path, 'w') as f:
    json.dump(reg, f, indent=2)
print('Registered: $new_name')
" || echo "Warning: could not register skill"
        fi
        echo "Created skill: $new_name"
        echo "  Directory: $new_dir"
        echo "  SKILL.md:  $new_dir/SKILL.md"
        echo "  Template:  $new_dir/template.md"
        ;;
      extract)
        [[ $# -lt 1 ]] && { echo "Usage: piharness skill extract <surface> [--name N] [--trigger T] [--desc D]" >&2; exit 1; }
        ext_surface="$1"; shift
        ext_name=""; ext_trigger=""; ext_desc=""
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --name)    ext_name="$2";    shift 2 ;;
            --trigger) ext_trigger="$2"; shift 2 ;;
            --desc)    ext_desc="$2";    shift 2 ;;
            *) echo "Unknown: $1" >&2; exit 1 ;;
          esac
        done
        ext_outfile="$OUTPUTS_DIR/${ext_surface//:/+}.txt"
        [[ ! -f "$ext_outfile" ]] && { echo "No output for $ext_surface" >&2; exit 1; }
        if [[ -z "$ext_name" ]]; then
          ext_name=$(grep -v -E '__PIHARNESS_DONE__|__PIHARNESS_ERROR__' "$ext_outfile" 2>/dev/null \
            | tr ' ' '\n' | grep -oE '[a-zA-Z][a-zA-Z0-9]{3,}' | tr '[:upper:]' '[:lower:]' \
            | sort | uniq -c | sort -rn | head -5 | awk '{print $2}' | tr '\n' '-' | sed 's/-$//')
          [[ -z "$ext_name" ]] && ext_name="extracted-$(date +%s)"
        fi
        [[ -z "$ext_trigger" ]] && ext_trigger="$ext_name"
        [[ -z "$ext_desc" ]] && ext_desc="Auto-extracted from worker $ext_surface"
        bash "$SCRIPT_DIR/piharness.sh" skill new "$ext_name" --pattern "$ext_trigger" --desc "$ext_desc"
        echo ""
        echo "Extracted skill: $ext_name from $ext_surface"
        echo "  Edit: $SKILLS_DIR/$ext_name/SKILL.md"
        echo "  Template: $SKILLS_DIR/$ext_name/template.md"
        ;;
      suggest)
        bash "$SCRIPT_DIR/piharness.sh" learn suggest
        ;;
      *)
        echo "Usage: piharness skill <list|show|new|extract|suggest>" >&2; exit 1 ;;
    esac
    ;;

  # ---------------------------------------------------------------------------
  learn)
  # ---------------------------------------------------------------------------
  # Usage: piharness learn track|history|suggest [args]
  # Track tasks and detect patterns for auto-suggestion
    TASK_HISTORY="$PIHARNESS_DIR/task-history.json"
    learn_cmd="${1:-suggest}"; shift || true
    case "$learn_cmd" in
      track)
        [[ $# -lt 1 ]] && { echo "Usage: piharness learn track <description> [--surface S] [--outcome O] [--skill NAME]" >&2; exit 1; }
        task_desc="$1"; shift
        task_surface=""; task_outcome=""; task_skill=""
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --surface) task_surface="$2"; shift 2 ;;
            --outcome) task_outcome="$2"; shift 2 ;;
            --skill)   task_skill="$2";   shift 2 ;;
            *) echo "Unknown: $1" >&2; exit 1 ;;
          esac
        done
        if [[ ! -f "$TASK_HISTORY" ]]; then
          echo '{"version":1,"tasks":[],"clusters":[]}' > "$TASK_HISTORY"
        fi
        task_skill_py="None"
        [[ -n "$task_skill" ]] && task_skill_py="'$task_skill'"
        python3 -c "
import json, os
path = os.path.expanduser('$TASK_HISTORY')
with open(path) as f:
    hist = json.load(f)
task_num = len(hist.get('tasks', [])) + 1
task = {
    'id': f'task_{task_num:03d}',
    'description': '$task_desc',
    'timestamp': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
    'matched_skill': $task_skill_py,
    'surface': '${task_surface:-}',
    'outcome': '${task_outcome:-unknown}',
    'patterns_extracted': False
}
hist.setdefault('tasks', []).append(task)
hist['last_updated'] = '$(date -u +%Y-%m-%dT%H:%M:%SZ)'
with open(path, 'w') as f:
    json.dump(hist, f, indent=2)
print(f'Tracked task_{task_num:03d}: $task_desc')
" || echo "Error tracking task"
        ;;
      history)
        limit=20
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --limit) limit="$2"; shift 2 ;;
            *) echo "Unknown: $1" >&2; exit 1 ;;
          esac
        done
        if [[ ! -f "$TASK_HISTORY" ]]; then
          echo "No task history yet."; exit 0
        fi
        echo ""
        printf '%-10s %-22s %-24s %-10s %s\n' "ID" "TIMESTAMP" "DESCRIPTION" "OUTCOME" "SKILL"
        printf '%-10s %-22s %-24s %-10s %s\n' "──" "─────────" "───────────" "───────" "─────"
        python3 -c "
import json, os
path = os.path.expanduser('$TASK_HISTORY')
with open(path) as f:
    hist = json.load(f)
tasks = hist.get('tasks', [])[-${limit}:]
for t in tasks:
    skill = t.get('matched_skill') or '-'
    desc = t.get('description', '')[:23]
    print(f\"{t['id']:<10} {t['timestamp']:<22} {desc:<24} {t.get('outcome',''):<10} {skill}\")
" 2>/dev/null || echo "Error reading history"
        echo ""
        ;;
      suggest)
        if [[ ! -f "$TASK_HISTORY" ]]; then
          echo "No patterns detected yet — keep working!"
          exit 0
        fi
        python3 -c "
import json, os, re
STOP_WORDS = {'a','an','the','for','to','in','on','at','with','by','from','and','or','of','is','are','was','were','be','been','being','have','has','had','do','does','did','but','not','what','which','who','whom','this','that','these','those','build','create','make','using','into','out','up','down','new','old','fix','add','run','set','get','use','implement'}
path = os.path.expanduser('$TASK_HISTORY')
with open(path) as f:
    hist = json.load(f)
tasks = hist.get('tasks', [])
if not tasks:
    print('No patterns detected yet — keep working!')
    exit(0)
keywords = {}
for t in tasks:
    words = set(re.findall(r'[a-zA-Z][a-zA-Z0-9]{2,}', t['description'].lower())) - STOP_WORDS
    keywords[t['id']] = words
clusters = []
used = set()
for t1 in tasks:
    if t1['id'] in used: continue
    cluster = [t1]
    used.add(t1['id'])
    for t2 in tasks:
        if t2['id'] in used: continue
        shared = len(keywords.get(t1['id'], set()) & keywords.get(t2['id'], set()))
        if shared >= 2:
            cluster.append(t2)
            used.add(t2['id'])
    if len(cluster) >= 2:
        all_kw = set()
        for t in cluster: all_kw |= keywords.get(t['id'], set())
        clusters.append({'tasks': [t['id'] for t in cluster], 'count': len(cluster), 'keywords': list(all_kw)[:5]})
if not clusters:
    print('No patterns detected yet — keep working!')
    exit(0)
print()
print('Suggestions for new skills:')
print('─' * 40)
for c in clusters:
    name = '-'.join(c['keywords'][:2]) if c['keywords'] else 'unnamed-pattern'
    print(f'{name} ({c[\"count\"]} similar tasks)')
    print(f'  Keywords: {\", \".join(c[\"keywords\"])}')
    print(f'  Run: piharness skill new {name} --pattern \"{c[\"keywords\"][0] if c[\"keywords\"] else name}\" --desc \"Auto-suggested from {c[\"count\"]} tasks\"')
    print()
" 2>/dev/null || echo "Error analyzing patterns"
        ;;
      *)
        echo "Usage: piharness learn <track|history|suggest>" >&2; exit 1 ;;
    esac
    ;;

  # ---------------------------------------------------------------------------
  usage)
  # Usage: piharness usage stats|prune
  # Query and manage per-runtime usage tracking data.
  # ---------------------------------------------------------------------------
    usage_cmd="${1:-stats}"; shift || true
    case "$usage_cmd" in
      stats) _usage_stats ;;
      prune) _usage_prune ;;
      *) echo "Usage: piharness usage <stats|prune>" >&2; exit 1 ;;
    esac
    ;;

  # ---------------------------------------------------------------------------
  self-evolve)
  # Usage: piharness self-evolve [--dry-run] [--min-cluster N]
  # Auto-extract skills from repeated task patterns in the task history.
  # Scans all successful tasks, clusters by keyword similarity, and creates
  # a skill for any cluster with 3+ tasks. This is the core of the overnight
  # self-evolution loop — run nightly to build up the skill library.
  # ---------------------------------------------------------------------------
    TASK_HISTORY="$PIHARNESS_DIR/task-history.json"
    dry_run=false
    min_cluster=3
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --dry-run)   dry_run=true;     shift ;;
        --min-cluster) min_cluster="$2"; shift 2 ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
      esac
    done
    if [[ ! -f "$TASK_HISTORY" ]]; then
      echo "No task history yet. Run tasks first, then self-evolve."
      exit 0
    fi
    python3 -c "
import json, os, re, sys
from datetime import datetime, timezone
STOP_WORDS = {'a','an','the','for','to','in','on','at','with','by','from','and','or','of','is','are','was','were','be','been','being','have','has','had','do','does','did','but','not','what','which','who','whom','this','that','these','those','build','create','make','using','into','out','up','down','new','old','fix','add','run','set','get','use','implement','via','also','one','two','three','first','second','last','next','done'}
SKILLS_DIR = os.path.expanduser('$SKILLS_DIR')
SKILLS_REG = os.path.expanduser('$SKILLS_REGISTRY')
path = os.path.expanduser('$TASK_HISTORY')
dry_run = $dry_run
min_cluster = $min_cluster

with open(path) as f:
    hist = json.load(f)
tasks = hist.get('tasks', [])
unmatched = [t for t in tasks if not t.get('matched_skill') and not t.get('patterns_extracted') and t.get('outcome') == 'success']
if not unmatched:
    print('No new tasks to analyze for skill extraction.')
    sys.exit(0)

# Build keyword index
keywords = {}
for t in unmatched:
    words = set(re.findall(r'[a-zA-Z][a-zA-Z0-9]{2,}', t['description'].lower())) - STOP_WORDS
    keywords[t['id']] = words

# Cluster by shared keywords
clusters = []
used = set()
for t1 in unmatched:
    if t1['id'] in used: continue
    cluster = [t1]
    used.add(t1['id'])
    for t2 in unmatched:
        if t2['id'] in used: continue
        shared = len(keywords.get(t1['id'], set()) & keywords.get(t2['id'], set()))
        if shared >= 2:
            cluster.append(t2)
            used.add(t2['id'])
    if len(cluster) >= min_cluster:
        all_kw = set()
        for t in cluster: all_kw |= keywords.get(t['id'], set())
        clusters.append({'tasks': [t['id'] for t in cluster], 'count': len(cluster), 'keywords': sorted(all_kw)[:6]})

if not clusters:
    print('No clusters large enough for skill extraction (need $min_cluster+ similar tasks).')
    sys.exit(0)

created = 0
for c in clusters:
    name = '-'.join(c['keywords'][:3]) if c['keywords'] else f'pattern-{int(datetime.now().timestamp())}'
    desc = f'Auto-extracted from {c[\"count\"]} similar tasks: {\", \".join(c[\"keywords\"][:4])}'
    trigger = c['keywords'][0] if c['keywords'] else name
    print(f'Cluster: {name} ({c[\"count\"]} tasks, keywords: {\", \".join(c[\"keywords\"])})')
    if not dry_run:
        # Create the skill
        skill_dir = os.path.join(SKILLS_DIR, name)
        os.makedirs(skill_dir, exist_ok=True)
        skill_file = os.path.join(skill_dir, 'SKILL.md')
        with open(skill_file, 'w') as sf:
            sf.write(f'''---
name: {name}
version: 1
created: {datetime.now().strftime(\"%Y-%m-%d\")}
usage_count: 0
trigger_patterns: [{trigger}]
description: \"{desc}\"
---
# Skill: {name}

## Problem
[Describe the problem this skill solves]

## Pattern
[Describe the recommended pattern]

## Prevention
[Describe how to prevent this issue]
''')
        # Register in skills registry
        if os.path.exists(SKILLS_REG):
            with open(SKILLS_REG) as f:
                reg = json.load(f)
        else:
            reg = {'version': 1, 'skills': [], 'last_updated': ''}
        new_skill = {
            'name': name,
            'version': 1,
            'created': datetime.now().strftime('%Y-%m-%d'),
            'usage_count': 0,
            'trigger_patterns': [trigger],
            'description': desc,
            'path': skill_dir
        }
        # Avoid duplicates
        existing = [s for s in reg.get('skills', []) if s['name'] == name]
        if not existing:
            reg.setdefault('skills', []).append(new_skill)
            reg['last_updated'] = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
            with open(SKILLS_REG, 'w') as f:
                json.dump(reg, f, indent=2)
        # Mark tasks as extracted
        task_ids = set(t['id'] for t in cluster)
        for t in hist.get('tasks', []):
            if t['id'] in task_ids:
                t['patterns_extracted'] = True
                t['matched_skill'] = name
        with open(path, 'w') as f:
            json.dump(hist, f, indent=2)
        created += 1
        print(f'  -> Created skill: {name}')

if dry_run:
    print(f'\\nDry-run: {len(clusters)} skills would be created.')
else:
    print(f'\\nCreated {created} new skills from {len(clusters)} clusters.')
    if created > 0:
        print('Run: piharness skill list')
" 2>/dev/null || echo "Error during self-evolution"
    ;;

  # ---------------------------------------------------------------------------
  nightly)
  # Usage: piharness nightly
  # Full overnight maintenance routine. Run this on a timer (cron/launchd) to
  # keep the system self-evolving without supervision.
  #   1. Self-evolve — extract skills from task pattern clusters
  #   2. Usage prune — clean old runtime usage data (>7 days)
  #   3. Stale workers — close workers idle >24h
  #   4. Output clean — remove old output files
  #   5. Summary report
  # ---------------------------------------------------------------------------
    echo "=== PIHARNESS Nightly Maintenance ==="
    echo "Started: $(date)"
    echo ""

    # Step 1: Self-evolve
    echo "--- Step 1: Self-evolve (skill extraction) ---"
    bash "$SCRIPT_DIR/piharness.sh" self-evolve 2>&1 || true
    echo ""

    # Step 2: Prune usage data
    echo "--- Step 2: Prune runtime usage data ---"
    _usage_prune 2>&1 || true
    echo ""

    # Step 3: Prune stale workers
    echo "--- Step 3: Close stale workers (>24h idle) ---"
    if [[ -s "$REGISTRY" ]]; then
      now=$(date +%s)
      while IFS=$'\t' read -r surf lbl cwd wt br start_epoch role; do
        if [[ -n "$start_epoch" && "$start_epoch" != "0" ]]; then
          age=$(( now - start_epoch ))
          if [[ "$age" -gt 86400 ]]; then
            echo "  Closing stale worker: $surf ($lbl, ${age}s old)"
            bash "$SCRIPT_DIR/piharness.sh" close "$surf" 2>&1 || true
          fi
        fi
      done < "$REGISTRY"
    else
      echo "  No workers registered."
    fi
    echo ""

    # Step 4: Clean old output files
    echo "--- Step 4: Clean output/rt/monitor files ---"
    old_count=$(find "$OUTPUTS_DIR" -name '*.txt' -type f 2>/dev/null | wc -l | tr -d ' ')
    find "$OUTPUTS_DIR" -name '*.txt' -type f -mtime +1 -delete 2>/dev/null || true
    fresh_count=$(find "$OUTPUTS_DIR" -name '*.txt' -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "  Outputs: removed $((old_count - fresh_count)) old files, $fresh_count remain"
    # Clean stale runtime idx files for non-existent surfaces
    for idxf in "$RUNTIMES_DIR"/*.idx; do
      [[ -f "$idxf" ]] || continue
      surf=$(basename "$idxf" .idx | tr '+' ':')
      if ! grep -q "^$surf" "$REGISTRY" 2>/dev/null; then
        rm -f "$idxf"
        echo "  Removed stale runtime idx: $(basename "$idxf")"
      fi
    done
    echo ""

    # Step 5: Summary
    echo "--- Step 5: System Summary ---"
    skill_count=$(python3 -c "import json; reg=json.load(open('$SKILLS_REGISTRY')); print(len(reg.get('skills',[])))" 2>/dev/null || echo "0")
    task_count=$(python3 -c "import json; hist=json.load(open('$PIHARNESS_DIR/task-history.json')); print(len(hist.get('tasks',[])))" 2>/dev/null || echo "0")
    worker_count=$(( $(wc -l < "$REGISTRY" 2>/dev/null || echo 0) ))
    echo "  Skills:  $skill_count"
    echo "  Tasks:   $task_count"
    echo "  Workers: $worker_count"
    echo ""
    echo "=== Nightly Complete: $(date) ==="
    ;;

  # ---------------------------------------------------------------------------
  help|*)
  # ---------------------------------------------------------------------------
    cat <<'EOF'
piharness - orchestrate Pi/OpenCode/Ollama/Claude workers via cmux

Spawn / Register:
  spawn  [--cwd DIR] [--label L] [--worktree] [--branch B] [--role ROLE]
  use    <surface> [--label L] [--role ROLE]

Runtime:
  start   <surface> [--runtime TYPE:MODEL] [--continue]   Start interactive runtime
  switch  <surface> [--next | --runtime TYPE:MODEL]        Switch runtime in pane
  runtimes [<surface>]                                     Show chain + current

Task lifecycle:
  task    <surface> <prompt>               Fire-and-forget task (uses current runtime)
  auto    <surface> <prompt> [--timeout N] [--no-cooldown]
                                           Task with intelligent auto-switch on failure.
                                           Detects rate limits, tracks per-runtime usage,
                                           and retries the best runtime after cooldown.
                                           This is the main command for reliable execution.
  wait    <surface> [--timeout N]          Block until done
  collect <surface>                        Print final output
  peek    <surface>                        Print partial output (mid-run ok)

Observability:
  status                                   Dashboard: runtime, status, elapsed, role, last line
  screen  <surface>                        Live pane capture
  watch   <surface>                        Stream output file (tail -f)
  log     <surface>                        Structured event log
  list                                     Table of workers, roles, and runtimes
  monitor <surface> [--daemon]             Auto-switch monitor (background watchdog)

Usage tracking (runtime health database):
  usage stats                              Per-runtime success/failure/limit stats
  usage prune                              Prune entries older than 7 days

Self-evolution (overnight skill extraction):
  self-evolve [--dry-run] [--min-cluster N]
                                           Auto-extract skills from task pattern clusters.
                                           Run nightly to build the skill library.
  nightly                                  Full maintenance: self-evolve + prune + stale
                                           worker cleanup + summary report
  skill list                               List installed skills
  skill show <name>                        Show skill details (+ usage count)
  skill new <name> [--pattern P]           Create skill scaffold
  skill extract <surface> [--name N]       Create skill from worker output
  skill suggest                            Suggest skills from task patterns

Learning & pattern detection:
  learn track <desc> [--surface S]         Log a task for pattern detection
  learn history [--limit N]                Show recent task history
  learn suggest                            Suggest new skills from repeated patterns

Cleanup:
  close  <surface> [--keep-worktree]
  clean

Role-based pipeline:
  spawn --role implementer|tester|reviewer|orchestrator
  pipeline <task> [--rounds N] [--timeout N]   Run full impl→test→review cycle
  orchestrate <surface> <task>                  Run task on orchestrator worker
  handoff [--runtime TYPE:MODEL] [--task "..."] Hand off master orchestration to
                                                 another AI when Claude Code runs out

Env:
  PIHARNESS_DIR            State dir (default: ~/.piharness)
  PIHARNESS_REPO           Git repo for worktrees (default: script dir)
  PIHARNESS_RUNTIMES       Comma-sep runtime chain (TYPE:MODEL,...)
  PIHARNESS_MAX_WORKERS    Max concurrent workers (default: 3)
  PIHARNESS_ORCHESTRATOR   Runtime to use for orchestrator role (overrides chain)

Default runtime chain (auto-detected tools):
  pi:kilo-auto/free
  opencode:anthropic/claude-haiku-4-5
  gemini:gemini-2.5-flash
  codex:default
  droid:default
  ollama:qwen2.5-coder:7b
  claude:default
EOF
    ;;
esac
