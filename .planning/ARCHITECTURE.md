# Self-Evolving PIHARNESS Architecture

## The Loop

```
                    ┌──────────────────────────┐
                    │     Task Arrives          │
                    └──────────┬───────────────┘
                               │
                               ▼
                    ┌──────────────────────────┐
                    │   Skill Registry Match    │
                    │  (keywords + semantic)    │
                    └──────┬───────────┬───────┘
                           │           │
                      MATCHED      NO MATCH
                           │           │
                           ▼           ▼
                    ┌──────────┐ ┌──────────────────┐
                    │Load Skill│ │ Track as NOVEL    │
                    │Template  │ │ (increment count) │
                    └────┬─────┘ └────────┬─────────┘
                         │                │
                         ▼                ▼
                    ┌──────────────────────────┐
                    │   Execute via Worker(s)   │
                    └──────┬───────────┬───────┘
                           │           │
                      SUCCESS       FAILURE
                           │           │
                           ▼           ▼
                    ┌──────────┐ ┌──────────────────┐
                    │Increment │ │ Log lessons       │
                    │skill cnt │ │ learned           │
                    └────┬─────┘ └────────┬─────────┘
                         │                │
                         ▼                ▼
                    ┌──────────────────────────┐
                    │  Auto-Extract Check       │
                    │  (novel count ≥ 3 OR      │
                    │   similar cluster ≥ 3)    │
                    └──────┬───────────┬───────┘
                           │           │
                       EXTRACT     SKIP (too early)
                           │           │
                           ▼           ▼
                    ┌──────────┐
                    │Create     │
                    │New Skill  │
                    │in Worktree│
                    └──────────┘
```

## Component Map

```
┌──────────────────────────────────────────────────────────────────┐
│                     piharness.sh (1066 lines)                     │
│                                                                  │
│  Existing: spawn, task, auto, wait, collect, pipeline, handoff   │
│  NEW:      skill (list|show|new|extract|test|rm|suggest)         │
│  NEW:      learn  (track|history|suggest)                        │
│  MODIFIED: spawn  (auto-close excess panes)                      │
└──────────────────────────────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────────────────────┐
│                  ~/.piharness/ state directory                    │
│                                                                  │
│  skills/                                                         │
│    registry.json          ← skill index (name, triggers, count)  │
│    prompt-escaping/       ← extracted from lessons.md            │
│    │  SKILL.md            ← trigger patterns, template, metadata │
│    │  template.md         ← prompt template with {{variables}}   │
│    runtime-fallback/                                             │
│       SKILL.md                                                   │
│       template.md                                                │
│    web-builder/           ← extracted from flappy + finder work  │
│       SKILL.md                                                   │
│       template.md                                                │
│  task-history.json        ← tracked tasks for pattern detection  │
│                                                                  │
│  (existing: outputs/, logs/, worktrees/, monitors/, workers.tsv) │
└──────────────────────────────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────────────────────┐
│                    MCP Server (index.js)                          │
│                                                                  │
│  Existing: spawn_worker, run_task, wait_worker, ...              │
│  NEW:      skill_list, skill_show, skill_extract, skill_test     │
│  NEW:      learn_track, learn_suggest                            │
└──────────────────────────────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────────────────────┐
│                    CLAUDE.md Orchestrator Prompt                  │
│                                                                  │
│  Updated to include:                                              │
│  - Skill-aware orchestration workflow                            │
│  - Before each task: check skill registry                         │
│  - After each task: consider extraction                          │
│  - Pane management rules                                         │
└──────────────────────────────────────────────────────────────────┘
```

## Skill Format

`~/.piharness/skills/<name>/SKILL.md`:
```yaml
---
name: web-builder
version: 1
created: 2026-07-07
usage_count: 0
trigger_patterns:
  - "build a web page"
  - "create a website"
  - "html page"
runtime_hint: "pi:kilo-auto/free"
files_modified: ["*.html", "*.css", "*.js"]
---

# Skill: Web Builder

## What it's for
Building complete web pages with HTML, CSS, JS from a description.

## Prompt Template
See template.md

## Workflow
1. Split into 2-3 parallel implementer workers
2. Have them each build a version
3. Compare outputs, select best
4. Auto-extract if used 3+ times

## Examples
- "Build a 3D flappy bird game" -> flappy.html
- "Build a product finder" -> product-finder.html
```

## Task History Format

`~/.piharness/task-history.json`:
```json
{
  "tasks": [
    {
      "id": "task_001",
      "description": "build a 3D flappy bird game using canvas",
      "timestamp": "2026-07-07T20:30:00Z",
      "matched_skill": null,
      "surface": "surface:5",
      "outcome": "success",
      "patterns_extracted": false
    }
  ],
  "clusters": [
    {
      "pattern": "web page building",
      "task_ids": ["task_001", "task_002"],
      "count": 2,
      "suggested_skill_name": "web-builder"
    }
  ]
}
```

## Implementation Plan

### Plan 01: Skill Registry & CLI (Wave 1)
Create the skill storage infrastructure, registry, and CLI commands.

### Plan 02: Auto-Learning Engine (Wave 1, parallel)
Track tasks, detect patterns, auto-suggest skill creation. Also pane management.

### Plan 03: Worktree Workflow & Orchestrator (Wave 2)
Skill testing workflow, MCP tools, CLAUDE.md update.
