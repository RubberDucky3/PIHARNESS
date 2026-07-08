mod pty;

use pty::PtyManager;
use serde::{Deserialize, Serialize};
use std::process::Command;
use std::sync::Mutex;

// ── Types ─────────────────────────────────────────

#[derive(Serialize, Deserialize, Debug)]
pub struct WorkspaceInfo {
    pub id: String,
    pub title: Option<String>,
    pub description: Option<String>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct DepsStatus {
    pub cmux: bool,
    pub ade_mcp: bool,
    pub version: String,
}

#[derive(Serialize, Deserialize, Debug)]
struct McpRequest {
    jsonrpc: String,
    id: String,
    method: String,
    params: serde_json::Value,
}

// ── MCP Session Manager ──────────────────────────

#[allow(dead_code)]
struct McpSession {
    session_id: String,
    protocol_version: String,
}

static MCP_ENDPOINT: &str = "http://127.0.0.1:9000/mcp";

static MCP_SESSION: Mutex<Option<McpSession>> = Mutex::new(None);

/// Send an MCP request, handling initialize + session ID caching.
async fn mcp_send(body: serde_json::Value) -> Result<String, String> {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .build()
        .map_err(|e| format!("Failed to build client: {e}"))?;

    // Grab existing session ID, or initialize a new one
    let session_id = {
        let guard = MCP_SESSION.lock().map_err(|e| e.to_string())?;
        guard.as_ref().map(|s| s.session_id.clone())
    };

    let session_id = match session_id {
        Some(sid) => sid,
        None => {
            // Step 1: send initialize
            let init_body = serde_json::json!({
                "jsonrpc": "2.0",
                "id": "init-1",
                "method": "initialize",
                "params": {
                    "protocolVersion": "2025-03-26",
                    "capabilities": {},
                    "clientInfo": { "name": "ade-tauri", "version": "0.1.0" }
                }
            });
            let resp = client
                .post(MCP_ENDPOINT)
                .header("Content-Type", "application/json")
                .header("Accept", "application/json, text/event-stream")
                .json(&init_body)
                .send()
                .await
                .map_err(|e| format!("ade-mcp init failed: {e}"))?;

            // Extract session ID from response headers
            let sid = resp
                .headers()
                .get("mcp-session-id")
                .and_then(|v| v.to_str().ok())
                .ok_or_else(|| {
                    format!(
                        "No MCP session ID in response. Is ade-mcp running? Headers: {:?}",
                        resp.headers()
                    )
                })?
                .to_string();

            let _init_text = resp
                .text()
                .await
                .map_err(|e| format!("Failed to read init response: {e}"))?;

            // Step 2: send initialized notification
            let notif_body = serde_json::json!({
                "jsonrpc": "2.0",
                "method": "notifications/initialized",
                "params": {}
            });
            let _notif_resp = client
                .post(MCP_ENDPOINT)
                .header("Content-Type", "application/json")
                .header("Accept", "application/json, text/event-stream")
                .header("mcp-session-id", &sid)
                .json(&notif_body)
                .send()
                .await
                .map_err(|e| format!("ade-mcp initialized notification failed: {e}"))?;

            // Cache session
            let mut guard = MCP_SESSION.lock().map_err(|e| e.to_string())?;
            *guard = Some(McpSession {
                session_id: sid.clone(),
                protocol_version: "2025-03-26".into(),
            });

            sid
        }
    };

    // Step 3: send actual request
    let resp = client
        .post(MCP_ENDPOINT)
        .header("Content-Type", "application/json")
        .header("Accept", "application/json, text/event-stream")
        .header("mcp-session-id", &session_id)
        .json(&body)
        .send()
        .await
        .map_err(|e| format!("ade-mcp request failed: {e}"))?;

    let status = resp.status();
    let text = resp
        .text()
        .await
        .map_err(|e| format!("Failed to read response: {e}"))?;

    if status.is_success() {
        Ok(text)
    } else {
        Err(format!("ade-mcp error ({}): {}", status.as_u16(), text))
    }
}

// ── cmux commands ─────────────────────────────────

/// Resolve the cmux binary path.
///
/// Priority:
/// 1. `CMUX_BUNDLED_CLI_PATH` env var
/// 2. Known macOS/Unix installation paths
/// 3. `which cmux` via shell
/// 4. bare `"cmux"` as last resort (relies on PATH)
fn find_cmux_bin() -> String {
    if let Ok(path) = std::env::var("CMUX_BUNDLED_CLI_PATH") {
        if !path.is_empty() {
            let p = std::path::Path::new(&path);
            if p.exists() {
                return path;
            }
        }
    }

    let candidates = [
        "/Applications/cmux.app/Contents/Resources/bin/cmux",
        "/usr/local/bin/cmux",
        "/opt/homebrew/bin/cmux",
        "/opt/local/bin/cmux",
    ];
    for c in &candidates {
        if std::path::Path::new(c).exists() {
            return c.to_string();
        }
    }

    if let Ok(output) = Command::new("which").arg("cmux").output() {
        if output.status.success() {
            let path = String::from_utf8_lossy(&output.stdout)
                .trim()
                .to_string();
            if !path.is_empty() && std::path::Path::new(&path).exists() {
                return path;
            }
        }
    }

    if let Some(home) = std::env::var_os("HOME") {
        let local = std::path::Path::new(&home)
            .join(".local")
            .join("bin")
            .join("cmux");
        if local.exists() {
            return local.to_string_lossy().to_string();
        }
    }

    "cmux".to_string()
}

/// Resolve the cmux Unix socket path.
///
/// Priority:
/// 1. `CMUX_SOCKET_PATH` env var
/// 2. Scan `$HOME/.local/state/cmux/` for existing `.sock` files
/// 3. Default `$HOME/.local/state/cmux/cmux-501.sock` (macOS first-user UID)
fn find_cmux_socket() -> String {
    if let Ok(path) = std::env::var("CMUX_SOCKET_PATH") {
        if !path.is_empty() {
            return path;
        }
    }

    if let Some(home) = std::env::var_os("HOME") {
        let cmux_dir = std::path::Path::new(&home)
            .join(".local")
            .join("state")
            .join("cmux");

        if let Ok(entries) = std::fs::read_dir(&cmux_dir) {
            let mut socks: Vec<String> = entries
                .filter_map(|e| e.ok())
                .filter(|e| {
                    e.file_name().to_string_lossy().ends_with(".sock")
                })
                .map(|e| e.path().to_string_lossy().to_string())
                .collect();
            socks.sort();
            if let Some(found) = socks.last() {
                return found.clone();
            }
        }

        let fallback = cmux_dir.join("cmux-501.sock");
        return fallback.to_string_lossy().to_string();
    }

    "".to_string()
}

#[tauri::command]
fn cmux_run(args: String) -> Result<String, String> {
    let split_args = shlex::split(&args).ok_or_else(|| {
        format!("Failed to parse cmux args: unbalanced quotes in {args:?}")
    })?;

    let cmux_bin = find_cmux_bin();
    let sock_path = find_cmux_socket();

    let mut cmd = Command::new(&cmux_bin);
    // Use --socket flag to bypass all env-var conflicts (CMUX_SOCKET vs CMUX_SOCKET_PATH).
    // cmux's own contract says: "if both variables are set and differ, the CLI fails before
    // socket commands" — the Tauri process inherits CMUX_SOCKET="" from cmux's shell
    // integration, so env_remove doesn't reliably clear it. The CLI flag takes highest
    // precedence and sidesteps the entire env-var check.
    if sock_path.is_empty() {
        cmd.args(&split_args);
    } else {
        cmd.args(std::iter::once("--socket".to_string())
            .chain(std::iter::once(sock_path))
            .chain(split_args));
    }
    cmd.env("CMUX_QUIET", "1");

    let output = cmd.output().map_err(|e| format!("Failed to run cmux: {e}"))?;

    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr);
        Err(format!("cmux error: {stderr}"))
    }
}

#[tauri::command]
fn cmux_tree() -> Result<String, String> {
    cmux_run("tree --all".to_string())
}

#[tauri::command]
fn cmux_tree_json() -> Result<String, String> {
    cmux_run("tree --all --json".to_string())
}

// ── ade-mcp commands ─────────────────────────────

#[tauri::command]
async fn ade_mcp_list_tools() -> Result<String, String> {
    let req = McpRequest {
        jsonrpc: "2.0".into(),
        id: "tauri-1".into(),
        method: "tools/list".into(),
        params: serde_json::Value::Null,
    };
    mcp_send(serde_json::to_value(req).unwrap()).await
}

#[tauri::command]
async fn ade_mcp_list_resources() -> Result<String, String> {
    let req = McpRequest {
        jsonrpc: "2.0".into(),
        id: "tauri-2".into(),
        method: "resources/list".into(),
        params: serde_json::Value::Null,
    };
    mcp_send(serde_json::to_value(req).unwrap()).await
}

#[tauri::command]
async fn ade_mcp_call_tool(name: String, args: String) -> Result<String, String> {
    let parsed_args: serde_json::Value =
        serde_json::from_str(&args).unwrap_or(serde_json::Value::Null);

    let params = serde_json::json!({
        "name": name,
        "arguments": parsed_args,
    });

    let req = McpRequest {
        jsonrpc: "2.0".into(),
        id: "tauri-3".into(),
        method: "tools/call".into(),
        params,
    };
    mcp_send(serde_json::to_value(req).unwrap()).await
}

#[tauri::command]
async fn ade_mcp_read_resource(uri: String) -> Result<String, String> {
    let params = serde_json::json!({ "uri": uri });
    let req = McpRequest {
        jsonrpc: "2.0".into(),
        id: "tauri-4".into(),
        method: "resources/read".into(),
        params,
    };
    mcp_send(serde_json::to_value(req).unwrap()).await
}

// ── System ────────────────────────────────────────

#[tauri::command]
fn check_deps() -> DepsStatus {
    let cmux_ok = Command::new(find_cmux_bin())
        .arg("version")
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false);

    let ade_mcp_ok = std::net::TcpStream::connect("127.0.0.1:9000").is_ok();

    DepsStatus {
        cmux: cmux_ok,
        ade_mcp: ade_mcp_ok,
        version: env!("CARGO_PKG_VERSION").to_string(),
    }
}

// ── Terminal commands ─────────────────────────────

#[tauri::command]
fn create_terminal(
    id: String,
    cmd: String,
    cwd: Option<String>,
    cols: u16,
    rows: u16,
    state: tauri::State<'_, PtyManager>,
    app: tauri::AppHandle,
) -> Result<(), String> {
    state.create_session(&id, &cmd, cwd.as_deref(), cols, rows, app)
}

#[tauri::command]
fn write_stdin(
    id: String,
    data: String,
    state: tauri::State<'_, PtyManager>,
) -> Result<(), String> {
    state.write_stdin(&id, &data)
}

#[tauri::command]
fn resize_terminal(
    id: String,
    cols: u16,
    rows: u16,
    state: tauri::State<'_, PtyManager>,
) -> Result<(), String> {
    state.resize_terminal(&id, cols, rows)
}

#[tauri::command]
fn close_terminal(id: String, state: tauri::State<'_, PtyManager>) -> Result<(), String> {
    state.close_session(&id)
}

// ── App entry ─────────────────────────────────────

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .manage(PtyManager::new())
        .invoke_handler(tauri::generate_handler![
            cmux_run,
            cmux_tree,
            cmux_tree_json,
            ade_mcp_list_tools,
            ade_mcp_list_resources,
            ade_mcp_call_tool,
            ade_mcp_read_resource,
            check_deps,
            create_terminal,
            write_stdin,
            resize_terminal,
            close_terminal,
        ])
        .run(tauri::generate_context!())
        .expect("error while running ADE");
}
