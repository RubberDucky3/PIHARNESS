use portable_pty::{ChildKiller, CommandBuilder, MasterPty, NativePtySystem, PtyPair, PtySize, PtySystem};
use std::collections::HashMap;
use std::io::{Read, Write};
use std::sync::Mutex;
use tauri::{AppHandle, Emitter};

pub struct PtySession {
    child: Box<dyn ChildKiller + Send>,
    writer: Box<dyn Write + Send>,
    master: Box<dyn MasterPty + Send>,
}

pub struct PtyManager {
    sessions: Mutex<HashMap<String, PtySession>>,
}

impl PtyManager {
    pub fn new() -> Self {
        Self {
            sessions: Mutex::new(HashMap::new()),
        }
    }

    pub fn create_session(
        &self,
        id: &str,
        cmd: &str,
        cwd: Option<&str>,
        cols: u16,
        rows: u16,
        app: AppHandle,
    ) -> Result<(), String> {
        let pty_system = NativePtySystem::default();
        let size = PtySize {
            cols,
            rows,
            ..Default::default()
        };

        let pair: PtyPair = pty_system
            .openpty(size)
            .map_err(|e| format!("Failed to open PTY: {e}"))?;

        let mut cmd_builder = CommandBuilder::new(cmd);
        cmd_builder.env("TERM", "xterm-256color");
        if let Some(dir) = cwd {
            cmd_builder.cwd(dir);
        }

        let child = pair
            .slave
            .spawn_command(cmd_builder)
            .map_err(|e| format!("Failed to spawn command: {e}"))?;

        let mut reader = pair
            .master
            .try_clone_reader()
            .map_err(|e| format!("Failed to clone reader: {e}"))?;

        let writer = pair
            .master
            .take_writer()
            .map_err(|e| format!("Failed to take writer: {e}"))?;

        let sid = id.to_string();
        let app_clone = app.clone();

        // Reader thread: forwards raw PTY chunks to the frontend so ANSI
        // sequences and partial lines survive intact (required for TUIs).
        std::thread::spawn(move || {
            let mut buf = [0u8; 4096];
            loop {
                match reader.read(&mut buf) {
                    Ok(0) | Err(_) => break,
                    Ok(n) => {
                        let chunk = String::from_utf8_lossy(&buf[..n]).to_string();
                        let _ = app_clone.emit(
                            "terminal-output",
                            serde_json::json!({ "id": sid, "data": chunk }),
                        );
                    }
                }
            }
            let _ = app_clone.emit(
                "terminal-output",
                serde_json::json!({ "id": sid, "data": null }),
            );
        });

        let session = PtySession {
            child,
            writer,
            master: pair.master,
        };

        let mut sessions = self.sessions.lock().map_err(|e| e.to_string())?;
        sessions.insert(id.to_string(), session);

        Ok(())
    }

    pub fn write_stdin(&self, id: &str, data: &str) -> Result<(), String> {
        let mut sessions = self.sessions.lock().map_err(|e| e.to_string())?;
        let session = sessions
            .get_mut(id)
            .ok_or_else(|| format!("Session not found: {id}"))?;
        session
            .writer
            .write_all(data.as_bytes())
            .map_err(|e| format!("Failed to write to PTY: {e}"))?;
        session
            .writer
            .flush()
            .map_err(|e| format!("Failed to flush PTY: {e}"))?;
        Ok(())
    }

    pub fn resize_terminal(&self, id: &str, cols: u16, rows: u16) -> Result<(), String> {
        let sessions = self.sessions.lock().map_err(|e| e.to_string())?;
        let session = sessions
            .get(id)
            .ok_or_else(|| format!("Session not found: {id}"))?;
        session
            .master
            .resize(PtySize {
                cols,
                rows,
                pixel_width: 0,
                pixel_height: 0,
            })
            .map_err(|e| format!("Failed to resize PTY: {e}"))
    }

    pub fn close_session(&self, id: &str) -> Result<(), String> {
        let mut sessions = self.sessions.lock().map_err(|e| e.to_string())?;
        if let Some(mut session) = sessions.remove(id) {
            let _ = session.child.kill();
        }
        Ok(())
    }
}
