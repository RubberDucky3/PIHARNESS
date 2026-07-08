# PIHARNESS State

## Current Position
- **Phase:** 1 — Self-Evolving System ✅ **COMPLETE**
- **Last action:** Updated CLAUDE.md with skill-aware orchestration + MCP tools for skill/learn
- **Next:** Plan Phase 2 iteration or end-to-end usage verification

## What was built (Phase 1)

### Skill Registry & CLI (Plan 01-01)
- `~/.piharness/skills/` directory with `registry.json`
- 3 skills migrated from `lessons.md`: prompt-escaping, runtime-fallback, pane-management
- `skill list|show|new` subcommands on `piharness.sh`

### Auto-Learning Engine + Pane Management (Plan 01-02)
- `learn track|history|suggest` subcommands on `piharness.sh`
- `skill extract|suggest` subcommands
- Auto-close oldest workers when MAX_WORKERS exceeded
- Workspace detection fix for cmux
- Task history at `~/.piharness/task-history.json`

### Orchestrator Integration (Plan 01-03)
- CLAUDE.md: Self-Evolving System section with skill lifecycle
- MCP tools: skill_list, skill_show, skill_extract, learn_track, learn_suggest

## Decisions
- Self-evolving architecture uses git worktrees for isolation
- Skills stored in `~/.piharness/skills/<name>/SKILL.md` format
- Pattern detection via keyword clustering (stop words stripped, 2+ shared keywords = cluster)
- Auto-skill-creation after threshold (3+ similar tasks)
- Pane management: auto-close excess workers before spawning
- `piharness skill` subcommand family for all skill operations
- `piharness learn` subcommand family for pattern tracking
- MCP tools delegate to `bash piharness.sh` — no duplicate logic
- Prompt-escaping pattern: write prompts to temp file before task command

## Blockers
- None

## Notes
- 3 skills are active and usable: prompt-escaping, runtime-fallback, pane-management
- Next phase could focus on: semantic clustering, auto-skill-activation, cross-skill composition
- Git worktrees work but `close` destroys branch — use `--keep-worktree` to preserve
