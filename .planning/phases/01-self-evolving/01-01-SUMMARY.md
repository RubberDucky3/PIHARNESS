# Plan 01-01 Summary: Skill Registry & CLI

**Status:** ✅ Complete
**Date:** 2026-07-08

## What was built

1. **Skill directory structure** at `~/.piharness/skills/` with `registry.json` for skill metadata
2. **3 skills migrated from `lessons.md`:**
   - `prompt-escaping` — avoid shell mangling of prompts with special characters
   - `runtime-fallback` — reliable Pi worker error handling with runtime chain fallback
   - `pane-management` — manage worker pane state and lifecycle
3. **`skill` subcommand** on `piharness.sh`:
   - `skill list` — formatted table of installed skills
   - `skill show <name>` — view full SKILL.md content
   - `skill new <name>` — create scaffold directory + register

## Key decisions
- Skills stored in `~/.piharness/skills/` (outside repo) so multiple repos share them
- Registry format: JSON with version, path, trigger_patterns, usage_count
- Python3 used for JSON manipulation (more portable than jq)
- Prompt-escaping pattern used: write prompts to temp file first

## Artifacts
- `~/.piharness/skills/registry.json` — skill index with metadata
- `~/.piharness/skills/prompt-escaping/SKILL.md` + `template.md`
- `~/.piharness/skills/runtime-fallback/SKILL.md` + `template.md`
- `~/.piharness/skills/pane-management/SKILL.md` + `template.md`
- `piharness.sh` — `skill list|show|new` added before `help|*)` case

## Verification
- ✅ `skill list` shows 3 skills
- ✅ `skill show` displays skill content with frontmatter
- ✅ `skill new` creates scaffold and registers
