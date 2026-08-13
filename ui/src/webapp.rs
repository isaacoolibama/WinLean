//! Interface grafica do Windows: HTML/CSS renderizado pelo WebView2, com Rust
//! controlando a janela e executando o motor PowerShell sem console visivel.

use crate::runner::{self, LineKind, Runner};
use serde::Deserialize;
use serde_json::{json, Value};
use std::error::Error;
use std::path::{Path, PathBuf};
use std::time::{Duration, Instant};
use winit::application::ApplicationHandler;
use winit::dpi::LogicalSize;
use winit::event::WindowEvent;
use winit::event_loop::{ActiveEventLoop, ControlFlow, EventLoop, EventLoopProxy};
use winit::window::{Window, WindowId};
use wry::{WebView, WebViewBuilder};

const HTML: &str = include_str!("../assets/index.html");
const POLL_INTERVAL: Duration = Duration::from_millis(60);
const ALLOWED_MODULES: [&str; 13] = [
    "-RemoveApps",
    "-Privacy",
    "-DisableAI",
    "-Services",
    "-Interface",
    "-Performance",
    "-Energy",
    "-Gaming",
    "-CleanDisk",
    "-LowEndMode",
    "-ClassicContextMenu",
    "-DisableFastStartup",
    "-HAGS",
];
const ALLOWED_POWER_PLANS: [&str; 6] = [
    "Keep",
    "Auto",
    "Balanced",
    "HighPerformance",
    "Ultimate",
    "PowerSaver",
];

#[derive(Debug)]
enum UserEvent {
    Ipc(String),
}

#[derive(Deserialize)]
#[serde(tag = "cmd", rename_all = "snake_case")]
enum IpcCommand {
    Ready,
    Run {
        language: String,
        modules: Vec<String>,
        power_plan: String,
        dry_run: bool,
    },
    Revert {
        language: String,
    },
    Close,
}

struct WebApp {
    proxy: EventLoopProxy<UserEvent>,
    script: PathBuf,
    language: String,
    window: Option<Window>,
    webview: Option<WebView>,
    runner: Option<Runner>,
}

impl WebApp {
    fn new(proxy: EventLoopProxy<UserEvent>, script: PathBuf, language: String) -> Self {
        Self {
            proxy,
            script,
            language,
            window: None,
            webview: None,
            runner: None,
        }
    }

    fn emit(&self, method: &str, payload: Value) {
        let Some(webview) = &self.webview else {
            return;
        };
        let script = format!("window.WinLean?.{method}({payload});");
        let _ = webview.evaluate_script(&script);
    }

    fn emit_error(&self, message: impl Into<String>) {
        self.emit("onError", json!(message.into()));
    }

    fn handle_ipc(&mut self, event_loop: &ActiveEventLoop, raw: &str) {
        let command = match serde_json::from_str::<IpcCommand>(raw) {
            Ok(command) => command,
            Err(error) => {
                self.emit_error(format!("Comando invalido / Invalid command: {error}"));
                return;
            }
        };

        match command {
            IpcCommand::Ready => {
                self.emit(
                    "init",
                    json!({
                        "language": self.language,
                        "version": env!("CARGO_PKG_VERSION"),
                        "elevated": true,
                    }),
                );
            }
            IpcCommand::Run {
                language,
                modules,
                power_plan,
                dry_run,
            } => {
                if self.runner.is_some() {
                    self.emit_error(
                        "Uma execucao ja esta em andamento. / A run is already active.",
                    );
                    return;
                }

                let selected: Vec<&str> = modules
                    .iter()
                    .map(String::as_str)
                    .filter(|flag| ALLOWED_MODULES.contains(flag))
                    .collect();
                if selected.is_empty() {
                    self.emit_error(
                        "Selecione pelo menos um modulo. / Select at least one module.",
                    );
                    return;
                }

                let language = normalize_language(&language);
                let has_energy = selected.contains(&"-Energy");
                let power_plan = if has_energy && ALLOWED_POWER_PLANS.contains(&power_plan.as_str())
                {
                    power_plan
                } else {
                    "Keep".to_string()
                };
                let mut args = vec![
                    "-Language".to_string(),
                    language.to_string(),
                    "-Plain".to_string(),
                    "-Silent".to_string(),
                ];
                args.extend(selected.into_iter().map(str::to_string));
                args.push("-PowerPlan".to_string());
                args.push(power_plan);
                if dry_run {
                    args.push("-DryRun".to_string());
                }
                self.start_runner(event_loop, args);
            }
            IpcCommand::Revert { language } => {
                if self.runner.is_some() {
                    self.emit_error(
                        "Aguarde a execucao atual terminar. / Wait for the current run.",
                    );
                    return;
                }
                let args = vec![
                    "-Language".to_string(),
                    normalize_language(&language).to_string(),
                    "-Plain".to_string(),
                    "-Silent".to_string(),
                    "-Revert".to_string(),
                ];
                self.start_runner(event_loop, args);
            }
            IpcCommand::Close => {
                if self.runner.is_some() {
                    self.emit_error(
                        "Aguarde a operacao terminar antes de fechar. / Wait for the operation to finish.",
                    );
                } else {
                    event_loop.exit();
                }
            }
        }
    }

    fn start_runner(&mut self, event_loop: &ActiveEventLoop, args: Vec<String>) {
        match Runner::spawn(&self.script, args) {
            Ok(runner) => {
                self.runner = Some(runner);
                self.emit("onStarted", json!({}));
                event_loop.set_control_flow(ControlFlow::WaitUntil(Instant::now() + POLL_INTERVAL));
            }
            Err(error) => self.emit_error(format!(
                "Nao foi possivel iniciar o motor. / Could not start the engine.\n{error}"
            )),
        }
    }

    fn poll_runner(&mut self, event_loop: &ActiveEventLoop) {
        let Some(runner) = &self.runner else {
            event_loop.set_control_flow(ControlFlow::Wait);
            return;
        };

        let logs: Vec<Value> = runner
            .drain()
            .into_iter()
            .map(|line| {
                let kind = match line.kind {
                    LineKind::Section => "section",
                    LineKind::Ok => "ok",
                    LineKind::Warn => "warn",
                    LineKind::Error => "error",
                    LineKind::Dry => "dry",
                    LineKind::Plain => "plain",
                };
                json!({ "kind": kind, "text": line.text })
            })
            .collect();
        if !logs.is_empty() {
            self.emit("onLogs", json!(logs));
        }

        if runner.is_finished() {
            let exit_code = runner.exit_code();
            self.runner = None;
            self.emit(
                "onFinished",
                json!({ "ok": exit_code == 0, "exitCode": exit_code }),
            );
            event_loop.set_control_flow(ControlFlow::Wait);
        } else {
            event_loop.set_control_flow(ControlFlow::WaitUntil(Instant::now() + POLL_INTERVAL));
        }
    }
}

impl ApplicationHandler<UserEvent> for WebApp {
    fn resumed(&mut self, event_loop: &ActiveEventLoop) {
        if self.window.is_some() {
            return;
        }

        let attributes = Window::default_attributes()
            .with_title(format!("WinLean {}", env!("CARGO_PKG_VERSION")))
            .with_inner_size(LogicalSize::new(1180.0, 780.0))
            .with_min_inner_size(LogicalSize::new(920.0, 640.0))
            .with_resizable(true);
        let window = match event_loop.create_window(attributes) {
            Ok(window) => window,
            Err(error) => {
                runner::show_error_dialog(&error.to_string());
                event_loop.exit();
                return;
            }
        };

        let proxy = self.proxy.clone();
        let webview = WebViewBuilder::new()
            .with_html(HTML)
            .with_devtools(cfg!(debug_assertions))
            .with_general_autofill_enabled(false)
            .with_ipc_handler(move |request| {
                let _ = proxy.send_event(UserEvent::Ipc(request.body().clone()));
            })
            .build(&window);

        match webview {
            Ok(webview) => {
                self.window = Some(window);
                self.webview = Some(webview);
            }
            Err(error) => {
                runner::show_error_dialog(&format!(
                    "Falha ao iniciar o WebView2. Atualize o Microsoft Edge WebView2 Runtime.\n\nFailed to start WebView2. Update the Microsoft Edge WebView2 Runtime.\n\n{error}"
                ));
                event_loop.exit();
            }
        }
    }

    fn user_event(&mut self, event_loop: &ActiveEventLoop, event: UserEvent) {
        match event {
            UserEvent::Ipc(raw) => self.handle_ipc(event_loop, &raw),
        }
    }

    fn window_event(
        &mut self,
        event_loop: &ActiveEventLoop,
        _window_id: WindowId,
        event: WindowEvent,
    ) {
        if event == WindowEvent::CloseRequested {
            if self.runner.is_some() {
                self.emit_error(
                    "Aguarde a operacao terminar antes de fechar. / Wait for the operation to finish.",
                );
            } else {
                event_loop.exit();
            }
        }
    }

    fn about_to_wait(&mut self, event_loop: &ActiveEventLoop) {
        self.poll_runner(event_loop);
    }
}

pub fn run() -> Result<(), Box<dyn Error>> {
    let (language, requested_script) = parse_args();
    let script = requested_script
        .filter(|path| path.is_file())
        .or_else(locate_script)
        .ok_or("WinLean.ps1 nao encontrado / WinLean.ps1 not found")?;

    if !runner::is_elevated() {
        runner::relaunch_elevated(&language, &script)?;
        return Ok(());
    }

    let event_loop = EventLoop::<UserEvent>::with_user_event().build()?;
    let proxy = event_loop.create_proxy();
    let mut app = WebApp::new(proxy, script, language);
    event_loop.run_app(&mut app)?;
    Ok(())
}

fn parse_args() -> (String, Option<PathBuf>) {
    let mut language = "pt".to_string();
    let mut script = None;
    let args: Vec<String> = std::env::args().skip(1).collect();
    let mut index = 0;
    while index < args.len() {
        match args[index].as_str() {
            "--lang" | "-l" if index + 1 < args.len() => {
                language = normalize_language(&args[index + 1]).to_string();
                index += 1;
            }
            "--script" | "-s" if index + 1 < args.len() => {
                script = Some(PathBuf::from(&args[index + 1]));
                index += 1;
            }
            _ => {}
        }
        index += 1;
    }
    (language, script)
}

fn locate_script() -> Option<PathBuf> {
    let mut candidates = Vec::new();
    if let Ok(executable) = std::env::current_exe() {
        if let Some(directory) = executable.parent() {
            candidates.push(directory.join("WinLean.ps1"));
            candidates.push(directory.join("../../../WinLean.ps1"));
        }
    }
    if let Ok(current) = std::env::current_dir() {
        candidates.push(current.join("WinLean.ps1"));
        candidates.push(current.join("../WinLean.ps1"));
    }
    if let Ok(local_app_data) = std::env::var("LOCALAPPDATA") {
        candidates.push(
            Path::new(&local_app_data)
                .join("WinLean")
                .join("WinLean.ps1"),
        );
    }
    candidates.into_iter().find(|path| path.is_file())
}

fn normalize_language(language: &str) -> &'static str {
    if language.eq_ignore_ascii_case("en") {
        "en"
    } else {
        "pt"
    }
}
