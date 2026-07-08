#!/usr/bin/env bash
set -euo pipefail

VAULT="$PWD/obsidian-vault"
mkdir -p "$VAULT/00-Inbox" "$VAULT/01-Projects/PIHARNESS" "$VAULT/02-Areas" "$VAULT/03-Resources" "$VAULT/04-Archive" "$VAULT/Graphify"

sync_file() {
  local src="$1"
  local dest="$2"
  if [ -f "$src" ]; then
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
  fi
}

sync_file "$PWD/README.md" "$VAULT/01-Projects/PIHARNESS/README.md"
sync_file "$PWD/CLAUDE.md" "$VAULT/01-Projects/PIHARNESS/CLAUDE.md"
sync_file "$PWD/.planning/ARCHITECTURE.md" "$VAULT/01-Projects/PIHARNESS/Architecture/Architecture.md"
sync_file "$PWD/.planning/PROJECT.md" "$VAULT/01-Projects/PIHARNESS/Architecture/Project.md"
sync_file "$PWD/.planning/STATE.md" "$VAULT/01-Projects/PIHARNESS/Planning/State.md"

echo "Synced core docs into obsidian-vault/"
