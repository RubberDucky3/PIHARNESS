# PIHARNESS Roadmap

## Milestone 1: Self-Evolving Foundation

**Goal:** PIHARNESS learns from its own work. Novel tasks create skills. Repetitive tasks auto-extract patterns.

### Phase 1: Skill Registry & CLI
**Goal:** Skill storage exists, `skill` CLI subcommand works, lessons migrate to skills.
**Requirements:** SKILL-01, SKILL-02, SKILL-03

- [ ] Plan
- [ ] Execute

### Phase 2: Auto-Learning Engine
**Goal:** PIHARNESS tracks task patterns and auto-suggests skill creation when repetition detected.
**Requirements:** LEARN-01, LEARN-02, LEARN-03

- [ ] Plan
- [ ] Execute

### Phase 3: Skill Extraction
**Goal:** After a successful task, the system can extract the pattern as a reusable skill.
**Requirements:** EXTRACT-01, EXTRACT-02

- [ ] Plan
- [ ] Execute

### Phase 4: Orchestrator Integration
**Goal:** CLAUDE.md, MCP server, and workflow all skill-aware. Auto-load matching skills.
**Requirements:** INTEG-01, INTEG-02, INTEG-03

- [ ] Plan
- [ ] Execute

---

## Architecture Blueprint

```
~/.piharness/
├── skills/                    # ← NEW: skill library
│   ├── registry.json          #   skill index with metadata
│   ├── lesson-skills/         #   extracted from lessons.md
│   │   ├── prompt-escaping/
│   │   └── runtime-fallback/
│   ├── web-builder/           #   learned from flappy.html, product-finder.html
│   │   └── SKILL.md
│   └── ...
├── outputs/
├── logs/
├── worktrees/                 # isolated dev lanes for skill creation
├── monitors/
├── registry.json
└── workers.tsv
```

```
piharness.sh commands (NEW):
  skill list                           # List all installed skills
  skill show <name>                    # Show skill details
  skill new <name> [--from <surface>]  # Create skill in worktree
  skill extract <surface> [--name X]   # Extract pattern from task output
  skill test <name> [--input "..."]    # Test skill against input
  skill rm <name>                      # Remove skill
  skill suggest                        # Show suggestions based on task history
  learn track <task>                   # Log a task for pattern detection
  learn history                        # Show task history with clusters
  learn suggest                        # Suggest skills from repetitive patterns
```
