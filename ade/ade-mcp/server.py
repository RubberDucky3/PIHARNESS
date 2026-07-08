"""ade-mcp: Shared context MCP server for the AI Development Environment.

Run: python3 server.py
Connect agents via MCP protocol (SSE at http://127.0.0.1:9000/sse).
"""

import sys
from pathlib import Path

# Ensure we can import db from the same directory
sys.path.insert(0, str(Path(__file__).parent))

from mcp.server.fastmcp import FastMCP
import db

mcp = FastMCP(
    "ade-mcp",
    instructions="""Shared context server for the AI Development Environment (ADE).
    
Agents use this server to share memory, log decisions, report diagnostics,
publish/subscribe to messages, and snapshot workspace state. All data is
persisted in SQLite at ~/.piharness/ade/context.db.
""",
    host="127.0.0.1",
    port=9000,
    log_level="INFO",
    json_response=True,
)


# ── Resources ──────────────────────────────────────

@mcp.resource("context://workspace")
def workspace_resource() -> str:
    """Current workspace state snapshot (open files, active task, surfaces)."""
    snap = db.workspace_snapshot()
    return str(snap)


@mcp.resource("context://memory")
def memory_resource() -> str:
    """All active memory entries (non-expired)."""
    items = db.memory_list(limit=100)
    return str(items)


@mcp.resource("context://decisions")
def decisions_resource() -> str:
    """Recent architecture decision records."""
    items = db.decision_list(limit=20)
    return str(items)


@mcp.resource("context://diagnostics/active")
def diagnostics_resource() -> str:
    """Currently unresolved diagnostics (errors/warnings)."""
    items = db.diagnostics_active()
    return str(items)


# ── Tools ─────────────────────────────────────────

@mcp.tool()
def memory_store(key: str, value: str, ttl: int | None = None, tags: str = "") -> str:
    """Store a value in shared memory with optional TTL (seconds) and tags.
    
    Args:
        key: Unique identifier for the memory entry.
        value: Value to store (will be JSON-encoded).
        ttl: Time-to-live in seconds (None = permanent).
        tags: Comma-separated tags for filtering.
    """
    import json
    try:
        parsed = json.loads(value)
    except json.JSONDecodeError:
        parsed = value
    db.memory_store(key, parsed, ttl=ttl, tags=tags)
    return f"Stored memory key='{key}'" + (f" ttl={ttl}s" if ttl else "")


@mcp.tool()
def memory_search(query: str, limit: int = 10) -> str:
    """Search shared memory by keyword or phrase (FTS5 full-text search).
    
    Args:
        query: Search query (supports FTS5 syntax like 'keyword' or '"phrase"').
        limit: Maximum results to return.
    """
    results = db.memory_search(query, limit=limit)
    if not results:
        return "No results found."
    lines = []
    for r in results:
        lines.append(f"[{r['id']}] {r['key']} = {r['value'][:200]}  tags=({r['tags']})")
    return "\n".join(lines)


@mcp.tool()
def decision_log(title: str, context: str, decision: str, consequences: str = "", agent_id: str = "") -> str:
    """Log an Architecture Decision Record (ADR).
    
    Args:
        title: Short title of the decision (e.g. 'Use SQLite for context store').
        context: Why this decision was needed.
        decision: What was decided.
        consequences: Expected outcomes or trade-offs.
        agent_id: Optional identifier for the agent logging this.
    """
    db.decision_log(title, context, decision, consequences, agent_id)
    return f"Logged decision: {title}"


@mcp.tool()
def diagnostics_report(file: str, line: int, message: str, severity: str = "error", agent_id: str = "") -> str:
    """Report a diagnostic (error/warning) for a file.
    
    Previous diagnostics for the same file are auto-resolved.
    
    Args:
        file: File path relative to workspace root.
        line: Line number (0 for general).
        message: Diagnostic message.
        severity: 'error', 'warning', 'info', or 'hint'.
        agent_id: Optional agent identifier.
    """
    db.diagnostics_report(file, line, message, severity, agent_id)
    return f"Reported {severity} in {file}:{line}"


@mcp.tool()
def diagnostics_resolve(file: str | None = None) -> str:
    """Resolve (clear) active diagnostics. If file is provided, resolves only for that file.
    
    Args:
        file: Optional file path to resolve diagnostics for (all files if omitted).
    """
    db.diagnostics_resolve(file)
    if file:
        return f"Resolved diagnostics for {file}"
    return "Resolved all diagnostics"


@mcp.tool()
def agent_bus_publish(channel: str, message: str, sender: str = "") -> str:
    """Publish a message to an agent bus channel. Subscribers can poll for new messages.
    
    Args:
        channel: Channel name (e.g. 'tasks/api', 'status/build').
        message: Message payload (JSON string).
        sender: Optional sender identifier.
    """
    import json
    try:
        parsed = json.loads(message)
    except json.JSONDecodeError:
        parsed = message
    db.agent_bus_publish(channel, parsed, sender)
    return f"Published to channel '{channel}'"


@mcp.tool()
def agent_bus_poll(channel: str, after_id: int = 0, limit: int = 50) -> str:
    """Poll for new messages on an agent bus channel.
    
    Args:
        channel: Channel to poll.
        after_id: Only return messages with ID greater than this.
        limit: Maximum messages to return.
    """
    msgs = db.agent_bus_poll(channel, after_id, limit)
    if not msgs:
        return "No new messages."
    lines = []
    for m in msgs:
        lines.append(f"[{m['id']}] {m['sender']}: {m['payload']}")
    return "\n".join(lines)


@mcp.tool()
def workspace_snapshot() -> str:
    """Capture and return the current workspace state snapshot (open files, active task, surfaces)."""
    snap = db.workspace_snapshot()
    return str(snap)


@mcp.tool()
def workspace_set(key: str, value: str) -> str:
    """Set a workspace state value.
    
    Args:
        key: State key (e.g. 'active_task', 'open_files').
        value: JSON value string.
    """
    import json
    try:
        parsed = json.loads(value)
    except json.JSONDecodeError:
        parsed = value
    db.workspace_set(key, parsed)
    return f"Set workspace.{key}"


@mcp.tool()
def session_heartbeat(agent_id: str, surface_id: str = "", status: str = "active", metadata: str = "{}") -> str:
    """Register or update an agent session heartbeat.
    
    Args:
        agent_id: Unique agent identifier.
        surface_id: cmux surface ID where the agent runs.
        status: 'active', 'idle', 'busy', or 'offline'.
        metadata: JSON string with additional info.
    """
    import json
    try:
        meta = json.loads(metadata)
    except json.JSONDecodeError:
        meta = {}
    db.session_heartbeat(agent_id, surface_id, status, meta)
    return f"Heartbeat for {agent_id} (status={status})"


@mcp.tool()
def session_list() -> str:
    """List all active agent sessions."""
    sessions = db.session_list()
    if not sessions:
        return "No active sessions."
    lines = []
    for s in sessions:
        lines.append(f"  {s['agent_id']} | surface={s['surface_id']} | status={s['status']}")
    return "\n".join(lines)


# ── Main ───────────────────────────────────────────

def main():
    print("Starting ade-mcp on ws://127.0.0.1:9000 ...", flush=True)
    db.init_db()
    mcp.run(transport="streamable-http")


if __name__ == "__main__":
    main()
