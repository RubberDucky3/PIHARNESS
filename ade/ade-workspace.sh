#!/usr/bin/env bash
# ADE Workspace Template — creates a structured cmux workspace with
# editor, terminal, browser, and AI agent surfaces
#
# Usage: ./ade/ade-workspace.sh [--name "My Workspace"]
set -euo pipefail

NAME="${1:-ADE-$(date +%s)}"
WS=""
PIHARNESS_DIR="${PIHARNESS_DIR:-$HOME/.piharness}"

echo "=== Creating ADE Workspace: $NAME ==="

# 1. Ensure ade-mcp is running
if nc -z 127.0.0.1 9000 2>/dev/null; then
  echo "  ✓ ade-mcp running"
else
  echo "  Starting ade-mcp..."
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  nohup "$SCRIPT_DIR/ade-mcp/.venv/bin/python3" \
    "$SCRIPT_DIR/ade-mcp/server.py" \
    > /tmp/ade-mcp.log 2>&1 &
  sleep 2
  if nc -z 127.0.0.1 9000 2>/dev/null; then
    echo "  ✓ ade-mcp started"
  else
    echo "  ✗ ade-mcp failed (check /tmp/ade-mcp.log)"
    exit 1
  fi
fi

# 2. Create the workspace
WS=$(cmux new-workspace --name "$NAME" --cwd "$PWD" --description "ADE Environment" 2>/dev/null | grep -oE 'workspace:[0-9]+' | head -1)
if [[ -z "$WS" ]]; then
  echo "  Could not create workspace. Ensure cmux is running." >&2
  exit 1
fi
echo "  Workspace: $WS"

# 3. Create surfaces in a 2x2 grid layout
#    [Terminal]    [Browser (ade-mcp docs)]
#    [Editor]      [Terminal]

# Split right → left side is terminal, right side is browser
echo "  Creating browser surface..."
cmux new-surface --type browser --workspace "$WS" --url "http://localhost:5173" 2>/dev/null || true

# Split the left pane down → top = terminal, bottom = editor/terminal
echo "  Creating editor surface..."
cmux new-split down --workspace "$WS" 2>/dev/null || true

# Split the right pane down → top = browser, bottom = terminal
echo "  Creating utility terminal..."
cmux new-split down --workspace "$WS" 2>/dev/null || true

# 4. Log workspace creation to ade-mcp
python3 -c "
import json, urllib.request
body = {'jsonrpc':'2.0','id':'ws-init','method':'tools/call','params':{'name':'memory_store','arguments':{'key':'workspace:$NAME','value':json.dumps({'name':'$NAME','id':'$WS','created':'$(date -u +%Y-%m-%dT%H:%M:%SZ)'}),'tags':'workspace,ade'}}}
req = urllib.request.Request('http://127.0.0.1:9000/messages/', data=json.dumps(body).encode(), headers={'Content-Type':'application/json'})
urllib.request.urlopen(req, timeout=3)
" 2>/dev/null || true

echo "  Surface layout: 2×2 (terminal, browser, editor, terminal)"
echo "  Tauri ADE:     http://localhost:5173"
echo "  ade-mcp:       ws://127.0.0.1:9000"
echo "=== ADE Workspace Ready ==="
echo "  Switch to it: cmux switch --workspace $WS"
