# PIHARNESS: Self-Evolving AI Orchestrator

## Vision

PIHARNESS evolves from a simple worker-spawning harness into a **self-evolving system** that automatically captures patterns from its own work and grows its capabilities over time. Every novel task becomes a reusable skill. Every repetitive pattern triggers automatic skill extraction. The system rewires itself.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    ORCHESTRATOR (Claude Code)                │
│  Reads CLAUDE.md, consults skill registry, routes tasks     │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                 SKILL-AWARE ROUTER                           │
│  task → match against skills → matched? → use skill         │
│  task → no match → new pattern → create in worktree         │
└──────────────────────┬──────────────────────────────────────┘
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
   ┌──────────┐ ┌──────────┐ ┌──────────┐
   │ Skill #1 │ │ Skill #2 │ │ Skill #N │  ← learned over time
   └──────────┘ └──────────┘ └──────────┘
          │            │            │
          └────────────┼────────────┘
                       ▼
          ┌─────────────────────────┐
          │   GIT WORKTREE ENGINE   │
          │   Isolated dev lanes    │
          │   for skill creation    │
          └─────────────────────────┘
```

## Self-Evolving Loop

1. **Task arrives** — orchestrator receives a task description
2. **Match** — skill registry checked for matching trigger patterns
3. **If matched** → load skill prompt template, execute with pattern
4. **If novel** → spawn worktree worker, execute ad-hoc, then extract pattern
5. **If repetitive** → after N similar tasks, auto-suggest skill extraction
6. **Extract** → analyze what was done, formalize as reusable skill file
7. **Merge** → skill added to registry, available for future matches
8. **Loop** → system gets smarter with every task

## Key Design Decisions

- Skills stored as markdown files in `~/.piharness/skills/<name>/SKILL.md`
- Each skill has: name, trigger patterns (semantic), prompt template, files modified, metadata
- Git worktrees provide isolation for skill development (no risk to main)
- Pattern matching via keyword + semantic similarity against skill descriptions
- Auto-skill-creation after 3+ similar unskilled tasks detected
- Pane management: auto-close excess workers when spawning new ones
- All state in `~/.piharness/` — no repo pollution
