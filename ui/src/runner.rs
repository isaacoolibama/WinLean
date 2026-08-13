//! Execucao do motor PowerShell com streaming de saida.
//! Runs the PowerShell engine and streams its output.
//!
//! O processo roda em uma thread separada e envia cada linha por um canal, para
//! que o loop de renderizacao nunca bloqueie esperando I/O.
//!
//! The process runs on its own thread and pushes each line through a channel, so
//! the render loop never blocks on I/O.

use std::io::{BufRead, BufReader, Read};
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicBool, AtomicI32, Ordering};
use std::sync::mpsc::{channel, Receiver};
use std::sync::Arc;
use std::thread;

/// Severidade inferida do prefixo emitido pelo motor PowerShell.
#[derive(Clone, Copy, PartialEq, Eq)]
pub enum LineKind {
    Section,
    Ok,
    Warn,
    Error,
    Dry,
    Plain,
}

pub struct LogLine {
    pub kind: LineKind,
    pub text: String,
}

impl LogLine {
    fn parse(raw: &str) -> Self {
        let trimmed = raw.trim_end_matches(['\r', '\n']);
        // O motor prefixa cada linha: "== secao", " + ok", " ! aviso", " x erro",
        // " ~ simulacao". Classificar aqui evita ter que colorir no PowerShell,
        // que perde a cor ao ser redirecionado para um pipe.
        let (kind, text) = if let Some(rest) = trimmed.strip_prefix("== ") {
            (LineKind::Section, rest.to_string())
        } else if let Some(rest) = trimmed.strip_prefix(" + ") {
            (LineKind::Ok, rest.to_string())
        } else if let Some(rest) = trimmed.strip_prefix(" ! ") {
            (LineKind::Warn, rest.to_string())
        } else if let Some(rest) = trimmed.strip_prefix(" x ") {
            (LineKind::Error, rest.to_string())
        } else if let Some(rest) = trimmed.strip_prefix(" ~ ") {
            (LineKind::Dry, rest.to_string())
        } else {
            (LineKind::Plain, trimmed.trim_start().to_string())
        };
        LogLine { kind, text }
    }
}

pub struct Runner {
    rx: Receiver<LogLine>,
    finished: Arc<AtomicBool>,
    exit_code: Arc<AtomicI32>,
}

impl Runner {
    /// Inicia `powershell.exe -File <script> <args>`.
    pub fn spawn(script: &PathBuf, args: Vec<String>) -> std::io::Result<Self> {
        let mut cmd = Command::new("powershell.exe");
        cmd.arg("-NoProfile")
            .arg("-NonInteractive")
            .arg("-ExecutionPolicy")
            .arg("Bypass")
            .arg("-File")
            .arg(script);
        for a in &args {
            cmd.arg(a);
        }
        cmd.stdout(Stdio::piped()).stderr(Stdio::piped());

        let mut child = cmd.spawn()?;
        let (tx, rx) = channel::<LogLine>();
        let finished = Arc::new(AtomicBool::new(false));
        let exit_code = Arc::new(AtomicI32::new(0));

        let stdout = child.stdout.take();
        let stderr = child.stderr.take();

        let tx_out = tx.clone();
        let out_handle = thread::spawn(move || {
            if let Some(s) = stdout {
                pump(s, tx_out, false);
            }
        });

        let tx_err = tx.clone();
        let err_handle = thread::spawn(move || {
            if let Some(s) = stderr {
                pump(s, tx_err, true);
            }
        });

        let fin = Arc::clone(&finished);
        let code = Arc::clone(&exit_code);
        thread::spawn(move || {
            let status = child.wait();
            // Esperar as threads de leitura garante que nenhuma linha se perca
            // entre o processo terminar e a UI marcar como concluido.
            let _ = out_handle.join();
            let _ = err_handle.join();
            if let Ok(st) = status {
                code.store(st.code().unwrap_or(-1), Ordering::SeqCst);
            } else {
                code.store(-1, Ordering::SeqCst);
            }
            drop(tx);
            fin.store(true, Ordering::SeqCst);
        });

        Ok(Runner {
            rx,
            finished,
            exit_code,
        })
    }

    /// Coleta tudo que chegou desde o ultimo frame, sem bloquear.
    pub fn drain(&self) -> Vec<LogLine> {
        let mut out = Vec::new();
        while let Ok(line) = self.rx.try_recv() {
            out.push(line);
        }
        out
    }

    pub fn is_finished(&self) -> bool {
        self.finished.load(Ordering::SeqCst)
    }

    pub fn exit_code(&self) -> i32 {
        self.exit_code.load(Ordering::SeqCst)
    }
}

/// Le linha a linha em bytes e converte com `from_utf8_lossy`.
/// O motor forca UTF-8 na saida, mas uma linha malformada nao deve derrubar a UI.
fn pump<R: Read + Send + 'static>(stream: R, tx: std::sync::mpsc::Sender<LogLine>, is_err: bool) {
    let mut reader = BufReader::new(stream);
    let mut buf = Vec::with_capacity(256);
    loop {
        buf.clear();
        match reader.read_until(b'\n', &mut buf) {
            Ok(0) => break,
            Ok(_) => {
                let raw = String::from_utf8_lossy(&buf).to_string();
                if raw.trim().is_empty() && !is_err {
                    let _ = tx.send(LogLine {
                        kind: LineKind::Plain,
                        text: String::new(),
                    });
                    continue;
                }
                let mut line = LogLine::parse(&raw);
                if is_err && line.kind == LineKind::Plain && !line.text.is_empty() {
                    line.kind = LineKind::Error;
                }
                if tx.send(line).is_err() {
                    break;
                }
            }
            Err(_) => break,
        }
    }
}

/// Verifica elevacao perguntando ao proprio Windows via PowerShell.
///
/// Poderia ser feito com a API nativa, mas isso exigiria a crate `windows-sys`.
/// Uma chamada unica na inicializacao custa poucos milissegundos e mantem a
/// arvore de dependencias em um unico crate.
pub fn is_elevated() -> bool {
    Command::new("powershell.exe")
        .args([
            "-NoProfile",
            "-NonInteractive",
            "-Command",
            "([Security.Principal.WindowsPrincipal]\
             [Security.Principal.WindowsIdentity]::GetCurrent())\
             .IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)",
        ])
        .output()
        .map(|o| {
            String::from_utf8_lossy(&o.stdout)
                .trim()
                .eq_ignore_ascii_case("true")
        })
        .unwrap_or(false)
}
