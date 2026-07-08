"""SQLite storage layer for ade-mcp shared context."""

import json
import sqlite3
import time
from pathlib import Path
from typing import Any

DB_DIR = Path.home() / ".piharness" / "ade"
DB_PATH = DB_DIR / "context.db"


def get_db() -> sqlite3.Connection:
    DB_DIR.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA busy_timeout=5000")
    return conn


def init_db():
    conn = get_db()
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS workspace_state (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at INTEGER NOT NULL
        );

        CREATE TABLE IF NOT EXISTS memory (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            key TEXT UNIQUE NOT NULL,
            value TEXT NOT NULL,
            tags TEXT DEFAULT '',
            created_at INTEGER NOT NULL,
            ttl INTEGER DEFAULT NULL
        );

        CREATE TABLE IF NOT EXISTS decisions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            context TEXT NOT NULL,
            decision TEXT NOT NULL,
            consequences TEXT DEFAULT '',
            agent_id TEXT DEFAULT '',
            created_at INTEGER NOT NULL
        );

        CREATE TABLE IF NOT EXISTS diagnostics (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            file TEXT NOT NULL,
            line INTEGER DEFAULT 0,
            message TEXT NOT NULL,
            severity TEXT DEFAULT 'error',
            agent_id TEXT DEFAULT '',
            created_at INTEGER NOT NULL,
            resolved_at INTEGER DEFAULT NULL
        );

        CREATE TABLE IF NOT EXISTS agent_messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            channel TEXT NOT NULL,
            sender TEXT DEFAULT '',
            payload TEXT NOT NULL,
            created_at INTEGER NOT NULL
        );

        CREATE TABLE IF NOT EXISTS sessions (
            agent_id TEXT PRIMARY KEY,
            surface_id TEXT DEFAULT '',
            status TEXT DEFAULT 'active',
            metadata TEXT DEFAULT '{}',
            last_seen INTEGER NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_memory_ttl ON memory(ttl);
        CREATE INDEX IF NOT EXISTS idx_diagnostics_active ON diagnostics(resolved_at);
        CREATE INDEX IF NOT EXISTS idx_agent_messages_channel ON agent_messages(channel);
    """)
    conn.commit()
    conn.close()


# ── Workspace ──────────────────────────────────────

def workspace_get(key: str) -> Any | None:
    conn = get_db()
    row = conn.execute("SELECT value FROM workspace_state WHERE key = ?", (key,)).fetchone()
    conn.close()
    return json.loads(row[0]) if row else None


def workspace_set(key: str, value: Any):
    conn = get_db()
    conn.execute(
        "INSERT OR REPLACE INTO workspace_state (key, value, updated_at) VALUES (?, ?, ?)",
        (key, json.dumps(value), int(time.time())),
    )
    conn.commit()
    conn.close()


def workspace_snapshot() -> dict:
    conn = get_db()
    rows = conn.execute("SELECT key, value FROM workspace_state").fetchall()
    conn.close()
    return {row["key"]: json.loads(row["value"]) for row in rows}


# ── Memory ─────────────────────────────────────────

def memory_store(key: str, value: Any, ttl: int | None = None, tags: str = ""):
    now = int(time.time())
    val_str = json.dumps(value)
    conn = get_db()
    conn.execute(
        "INSERT OR REPLACE INTO memory (key, value, tags, created_at, ttl) VALUES (?, ?, ?, ?, ?)",
        (key, val_str, tags, now, ttl),
    )
    conn.commit()
    conn.close()
    _prune_expired()


def memory_search(query: str, limit: int = 10) -> list[dict]:
    _prune_expired()
    conn = get_db()
    like = f"%{query}%"
    rows = conn.execute(
        """SELECT id, key, value, tags, created_at, ttl FROM memory
           WHERE (key LIKE ? OR value LIKE ? OR tags LIKE ?)
             AND (ttl IS NULL OR created_at + ttl > ?)
           ORDER BY id DESC LIMIT ?""",
        (like, like, like, int(time.time()), limit),
    ).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def memory_list(limit: int = 50) -> list[dict]:
    _prune_expired()
    conn = get_db()
    rows = conn.execute(
        "SELECT id, key, value, tags, created_at, ttl FROM memory WHERE ttl IS NULL OR created_at + ttl > ? ORDER BY id DESC LIMIT ?",
        (int(time.time()), limit),
    ).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def _prune_expired():
    conn = get_db()
    now = int(time.time())
    expired = conn.execute(
        "SELECT id, key FROM memory WHERE ttl IS NOT NULL AND created_at + ttl < ?",
        (now,),
    ).fetchall()
    for row in expired:
        conn.execute("DELETE FROM memory_fts WHERE rowid = ?", (row["id"],))
    conn.execute("DELETE FROM memory WHERE ttl IS NOT NULL AND created_at + ttl < ?", (now,))
    conn.commit()
    conn.close()


# ── Decisions ──────────────────────────────────────

def decision_log(title: str, context: str, decision: str, consequences: str = "", agent_id: str = ""):
    conn = get_db()
    conn.execute(
        "INSERT INTO decisions (title, context, decision, consequences, agent_id, created_at) VALUES (?, ?, ?, ?, ?, ?)",
        (title, context, decision, consequences, agent_id, int(time.time())),
    )
    conn.commit()
    conn.close()


def decision_list(limit: int = 20) -> list[dict]:
    conn = get_db()
    rows = conn.execute("SELECT * FROM decisions ORDER BY created_at DESC LIMIT ?", (limit,)).fetchall()
    conn.close()
    return [dict(r) for r in rows]


# ── Diagnostics ────────────────────────────────────

def diagnostics_report(file: str, line: int, message: str, severity: str = "error", agent_id: str = ""):
    conn = get_db()
    conn.execute(
        "UPDATE diagnostics SET resolved_at = ? WHERE file = ? AND resolved_at IS NULL",
        (int(time.time()), file),
    )
    conn.execute(
        "INSERT INTO diagnostics (file, line, message, severity, agent_id, created_at) VALUES (?, ?, ?, ?, ?, ?)",
        (file, line, message, severity, agent_id, int(time.time())),
    )
    conn.commit()
    conn.close()


def diagnostics_active() -> list[dict]:
    conn = get_db()
    rows = conn.execute(
        "SELECT * FROM diagnostics WHERE resolved_at IS NULL ORDER BY created_at DESC LIMIT 50",
    ).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def diagnostics_resolve(file: str | None = None):
    conn = get_db()
    if file:
        conn.execute("UPDATE diagnostics SET resolved_at = ? WHERE file = ? AND resolved_at IS NULL",
                     (int(time.time()), file))
    else:
        conn.execute("UPDATE diagnostics SET resolved_at = ? WHERE resolved_at IS NULL",
                     (int(time.time()),))
    conn.commit()
    conn.close()


# ── Agent Bus ──────────────────────────────────────

def agent_bus_publish(channel: str, message: Any, sender: str = ""):
    conn = get_db()
    conn.execute(
        "INSERT INTO agent_messages (channel, sender, payload, created_at) VALUES (?, ?, ?, ?)",
        (channel, sender, json.dumps(message), int(time.time())),
    )
    conn.commit()
    conn.close()


def agent_bus_poll(channel: str, after_id: int = 0, limit: int = 50) -> list[dict]:
    conn = get_db()
    rows = conn.execute(
        "SELECT * FROM agent_messages WHERE channel = ? AND id > ? ORDER BY id ASC LIMIT ?",
        (channel, after_id, limit),
    ).fetchall()
    conn.close()
    return [dict(r) for r in rows]


# ── Sessions ───────────────────────────────────────

def session_heartbeat(agent_id: str, surface_id: str = "", status: str = "active", metadata: dict | None = None):
    conn = get_db()
    conn.execute(
        """INSERT OR REPLACE INTO sessions (agent_id, surface_id, status, metadata, last_seen)
           VALUES (?, ?, ?, ?, ?)""",
        (agent_id, surface_id, status, json.dumps(metadata or {}), int(time.time())),
    )
    conn.commit()
    conn.close()


def session_list() -> list[dict]:
    conn = get_db()
    rows = conn.execute(
        "SELECT * FROM sessions ORDER BY last_seen DESC LIMIT 20"
    ).fetchall()
    conn.close()
    return [dict(r) for r in rows]
