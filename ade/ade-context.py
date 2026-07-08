#!/usr/bin/env python3
"""ADE Context CLI — query ade-mcp for memory, decisions, diagnostics, agent bus.

Uses raw HTTP/JSON-RPC to ade-mcp's streamable-http endpoint (/mcp).
Manages session ID via response headers for the Initialize handshake.
Session ID is cached so all requests in one invocation share a session.
"""
import json, sys, uuid
from urllib.request import Request, urlopen

MCP_URL = "http://127.0.0.1:9000/mcp"

_session_id: str | None = None

def _rpc(method: str, params: dict | None = None, rid: str | None = None) -> dict:
    global _session_id
    data = json.dumps({"jsonrpc": "2.0", "id": rid or str(uuid.uuid4())[:8], "method": method, "params": params or {}}).encode()
    headers = {"Content-Type": "application/json", "Accept": "application/json, text/event-stream"}

    if _session_id is None:
        init = {"jsonrpc": "2.0", "id": "init-c", "method": "initialize", "params": {
            "protocolVersion": "2025-03-26", "capabilities": {},
            "clientInfo": {"name": "ade-context", "version": "0.1"}}}
        req = Request(MCP_URL, data=json.dumps(init).encode(), headers=headers)
        resp = urlopen(req, timeout=10)
        sid_raw = resp.headers.get("mcp-session-id")
        if not sid_raw:
            raise RuntimeError("No mcp-session-id in initialise response")
        sid: str = sid_raw
        _session_id = sid
        resp.read()
        notif = json.dumps({"jsonrpc": "2.0", "method": "notifications/initialized", "params": {}}).encode()
        nheaders = dict(headers)
        nheaders["mcp-session-id"] = sid
        req2 = Request(MCP_URL, data=notif, headers=nheaders)
        urlopen(req2, timeout=10)

    rheaders = dict(headers)
    rheaders["mcp-session-id"] = _session_id
    req = Request(MCP_URL, data=data, headers=rheaders)
    resp = urlopen(req, timeout=10)
    return json.loads(resp.read().decode())

def _tool_result(body: dict) -> str:
    content = body.get("result", {}).get("content", [])
    if content:
        return "\n".join(c.get("text", "") for c in content if "text" in c)
    return json.dumps(body, indent=2)

def main():
    if len(sys.argv) < 2:
        print("Usage: ade-context.py <memory|decisions|diagnostics|sessions> [query]")
        sys.exit(1)
    cmd = sys.argv[1]
    query = sys.argv[2] if len(sys.argv) > 2 else None

    try:
        match cmd:
            case "memory":
                if query:
                    r = _rpc("tools/call", {"name": "memory_search", "arguments": {"query": query, "limit": 20}})
                else:
                    r = _rpc("tools/call", {"name": "workspace_snapshot", "arguments": {}})
                print(_tool_result(r))

            case "decisions":
                r = _rpc("resources/read", {"uri": "context://decisions"})
                contents = r.get("result", {}).get("contents", [])
                if contents:
                    print(contents[0].get("text", "(empty)"))
                else:
                    print("(no decisions)")

            case "diagnostics":
                r = _rpc("resources/read", {"uri": "context://diagnostics/active"})
                contents = r.get("result", {}).get("contents", [])
                if contents:
                    print(contents[0].get("text", "(empty)"))
                else:
                    print("(no active diagnostics)")

            case "sessions":
                r = _rpc("tools/call", {"name": "session_list", "arguments": {}})
                print(_tool_result(r))

            case _:
                print(f"Unknown command: {cmd}")
                sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
