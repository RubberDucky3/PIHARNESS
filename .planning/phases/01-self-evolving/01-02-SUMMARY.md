# Plan 01-02 Summary: Auto-Learning Engine + Pane Management

**Status:** ✅ Complete
**Date:** 2026-07-08

## What was built

1. **`learn` subcommand** on `piharness.sh`:
   - `learn track <desc> [--surface S] [--outcome O] [--skill NAME]` — log task for pattern detection
   - `learn history [--limit N]` — show recent task history table
   - `learn suggest` — analyze task history via keyword clustering, suggest new skills
2. **`skill extract <surface> [--name N]`** — create skill from worker output with auto-naming
3. **`skill suggest`** — alias for `learn suggest`
4. **Auto-close in spawn** — when `MAX_WORKERS` exceeded, close oldest workers instead of erroring
5. **`--max-workers` flag** on spawn command
6. **Workspace detection fix** — injects `--workspace workspace:N` via `cmux tree --all` parsing
7. **`task-history.json`** stored at `$PIHARNESS_DIR/task-history.json`

## Key decisions
- Keyword clustering: stop words stripped, tasks sharing 2+ keywords form a cluster
- Auto-close strategy: close oldest workers first (from top of registry)
- Task history persists across sessions in JSON format

## Artifacts
- `piharness.sh` — `learn track|history|suggest`, `skill extract|suggest`, auto-close spawn
- `~/.piharness/task-history.json` — task history for pattern detection

## Verification
- ✅ `learn track` logs a task with timestamp and outcome
- ✅ `learn history` displays tracked tasks in table
- ✅ `learn suggest` shows pattern clusters when 3+ similar tasks exist
- ✅ Auto-close closes oldest workers when spawn reaches MAX_WORKERS
