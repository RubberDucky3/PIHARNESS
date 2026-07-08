# PIHARNESS State

## Current Position
- **Phase:** Pre-init — no GSD project setup existed until now
- **Last action:** User requested self-evolving system architecture
- **Next:** Plan and implement Phase 1 (Skill Registry & CLI)

## Decisions
- Self-evolving architecture uses git worktrees for isolation
- Skills stored in `~/.piharness/skills/<name>/SKILL.md` format
- Pattern detection via keyword + semantic similarity
- Auto-skill-creation after threshold (3+ similar tasks)
- Pane management: auto-close excess workers before spawning
- `piharness skill` subcommand family for all skill operations
- `piharness learn` subcommand family for pattern tracking
- All implementation done via PIHARNESS workers (eat own dogfood)

## Blockers
- None

## Notes
- Existing lessons in `.piharness/lessons.md` should become skills
- Existing web work (flappy.html, product-finder.html) are pattern candidates
- CLAUDE.md needs updating for skill-aware orchestration
- MCP server needs skill-related tools
