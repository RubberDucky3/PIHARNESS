#!/usr/bin/env bash
# setup.sh — Prepare PIHARNESS demo environment
# Run this once before recording demos to seed data and state.
set -e
PIHARNESS_DIR="${PIHARNESS_DIR:-$HOME/.piharness}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== PIHARNESS Demo Environment Setup ==="
echo ""

# 1. Seed task history for self-evolve demo
TASK_HISTORY="$PIHARNESS_DIR/task-history.json"
if [[ -f "$TASK_HISTORY" ]]; then
  echo "[SKIP] Task history already exists at $TASK_HISTORY"
else
  echo "[CREATE] Seeding task history..."
  cat > "$TASK_HISTORY" <<'TASKS'
{
  "version": 1,
  "tasks": [
    {"id":"demo_task_001","description":"Build user login API endpoint","timestamp":"2026-07-06T10:00:00Z","matched_skill":null,"surface":"surface:1","outcome":"success","patterns_extracted":false},
    {"id":"demo_task_002","description":"Create login form component","timestamp":"2026-07-06T11:00:00Z","matched_skill":null,"surface":"surface:2","outcome":"success","patterns_extracted":false},
    {"id":"demo_task_003","description":"Add JWT authentication middleware","timestamp":"2026-07-06T12:00:00Z","matched_skill":null,"surface":"surface:3","outcome":"success","patterns_extracted":false},
    {"id":"demo_task_004","description":"Design database schema for users","timestamp":"2026-07-06T13:00:00Z","matched_skill":null,"surface":"surface:1","outcome":"success","patterns_extracted":false},
    {"id":"demo_task_005","description":"Write unit tests for login flow","timestamp":"2026-07-06T14:00:00Z","matched_skill":null,"surface":"surface:2","outcome":"success","patterns_extracted":false},
    {"id":"demo_task_006","description":"Refactor login controller for readability","timestamp":"2026-07-07T09:00:00Z","matched_skill":null,"surface":"surface:3","outcome":"success","patterns_extracted":false}
  ],
  "clusters": [],
  "last_updated": "2026-07-07T14:00:00Z"
}
TASKS
  echo "  -> Added 6 tasks"
fi

# 2. Seed usage data for usage stats demo
USAGE_FILE="$PIHARNESS_DIR/usage.json"
if [[ -f "$USAGE_FILE" ]]; then
  echo "[SKIP] Usage data already exists at $USAGE_FILE"
else
  echo "[CREATE] Seeding usage data..."
  NOW=$(date -u +%s)
  cat > "$USAGE_FILE" <<USAGE
{
  "runtimes": {},
  "cooldowns": {},
  "history": [
    {"runtime":"pi:kilo-auto/free","timestamp":$((NOW - 86400)),"success":true,"latency":4.2,"tokens":1200,"model":"kilo-auto"},
    {"runtime":"pi:kilo-auto/free","timestamp":$((NOW - 43200)),"success":true,"latency":3.8,"tokens":980,"model":"kilo-auto"},
    {"runtime":"opencode:anthropic/claude-haiku-4-5","timestamp":$((NOW - 36000)),"success":true,"latency":8.1,"tokens":2400,"model":"claude-haiku"},
    {"runtime":"pi:kilo-auto/free","timestamp":$((NOW - 7200)),"success":false,"latency":0.0,"tokens":0,"model":"kilo-auto","error":"rate_limited"},
    {"runtime":"opencode:anthropic/claude-haiku-4-5","timestamp":$((NOW - 1800)),"success":true,"latency":7.5,"tokens":3100,"model":"claude-haiku"},
    {"runtime":"gemini:gemini-2.5-flash","timestamp":$((NOW - 600)),"success":true,"latency":5.2,"tokens":1800,"model":"gemini-2.5-flash"}
  ],
  "patterns_extracted": 0,
  "last_evolved": "",
  "last_updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
USAGE
  echo "  -> Added 6 usage entries"
fi

echo ""
echo "=== Setup complete ==="
echo "Ready to record demos."
