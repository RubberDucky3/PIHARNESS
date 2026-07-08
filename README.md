# PIHARNESS — AI Worker Orchestrator

Orchestrate multiple AI coding agents (Pi, OpenCode, Gemini, Codex, Droid, Claude, Ollama) across cmux panes with automatic fallback, self-healing runtimes, overnight self-evolution, and role-based pipelines.

## Quick Start

```bash
# Spawn workers
./piharness.sh spawn --label worker-a --worktree
./piharness.sh spawn --label worker-b --worktree

# Send a task (auto-fallback across runtimes)
./piharness.sh auto surface:1 "Build a flappy bird game in 3D"

# Dashboard
./piharness.sh status

# Full pipeline: implement → test → review
./piharness.sh pipeline "Add user authentication" --rounds 3

# Overnight self-evolution
./piharness.sh nightly
```

## Features

### Multi-Runtime Fallback
Tasks automatically fall through a chain of AI backends when one hits rate limits:
`pi:kilo-auto/free → opencode → gemini → codex → droid → ollama → claude`

### Intelligent Failure Detection
- Detects rate limits, token limits, quota exhaustion, and timeouts
- Sets cooldowns on exhausted runtimes, retries the best one after recovery
- Tracks per-runtime usage statistics: `piharness usage stats`

### Self-Evolution (Overnight)
The system watches task patterns and auto-extracts skills:
```bash
piharness self-evolve          # Extract skills from repeated task patterns
piharness nightly              # Full maintenance: evolve + prune + cleanup + report
piharness skill list           # See installed skills
piharness learn suggest        # Preview suggested skills
```

### Orchestrator Supervision
Long-running orchestrator tasks auto-handoff when the current runtime hits token limits:
```bash
piharness supervise "Build and deploy the entire application" --timeout 1800
```

### Role-Based Pipeline
```bash
./piharness.sh spawn --role implementer --worktree --label impl
./piharness.sh spawn --role tester --worktree --label test
./piharness.sh spawn --role reviewer --worktree --label review
./piharness.sh pipeline "Add payment processing" --rounds 3
```

### Deployment Skill
Once an app is sufficiently developed, capture deployment patterns:
```bash
piharness skill show deploy     # See the deployment pattern
```

## Demos

Watch PIHARNESS in action. View the **[interactive demo website](demos/index.html)** with embedded video demos.

| # | Demo | Command |
|---|------|---------|
| 01 | Spawn + Auto Task | `spawn` + `auto` |
| 02 | Status Dashboard | `status` |
| 03 | Role-Based Pipeline | `pipeline` |
| 04 | Self-Evolve + Nightly | `self-evolve` + `nightly` |
| 05 | Orchestrator Supervision | `supervise` |
| 06 | Usage Statistics | `usage stats` |
| 07 | Skills System | `skill list` + `skill show` |

To play a recording locally:
```bash
asciinema play demos/recordings/demo-01-spawn-auto.cast
```

To re-record any demo (e.g. with your own terminal theme):
```bash
asciinema rec --command "bash demos/demo-01-spawn-auto.sh" demos/recordings/demo-01-spawn-auto.cast
```

## Commands

| Command | Description |
|---|---|
| `spawn [--role ROLE]` | Spawn a worker pane |
| `task <s> <prompt>` | One-shot task |
| `auto <s> <prompt>` | Task with runtime fallback |
| `supervise <task>` | Orchestrator with auto-handoff |
| `pipeline <task>` | Impl → test → review loop |
| `orchestrate <s> <task>` | Run on orchestrator worker |
| `handoff [--runtime R]` | Token-limit handoff to new runtime |
| `self-evolve` | Extract skills from task patterns |
| `nightly` | Full maintenance routine |
| `usage stats` | Per-runtime health dashboard |
| `status` | Worker dashboard |

## Requirements

- **cmux** — terminal multiplexer with surface/split support
- **pi** (optional) — Pi AI coding assistant
- **opencode** (optional) — OpenCode CLI
- **gemini/codex/droid/ollama/claude** (optional) — Additional backends

The runtime chain auto-skips missing tools.

## Environment

| Variable | Default | Description |
|---|---|---|
| `PIHARNESS_DIR` | `~/.piharness` | State directory |
| `PIHARNESS_RUNTIMES` | pi,opencode,gemini,codex,droid,ollama,claude | Runtime chain |
| `PIHARNESS_MAX_WORKERS` | 3 | Concurrent worker limit |
| `PIHARNESS_ORCHESTRATOR` | — | Override orchestrator runtime |

## License

MIT
