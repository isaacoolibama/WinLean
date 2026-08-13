#![cfg_attr(target_os = "windows", windows_subsystem = "windows")]

//! WinLean - interface grafica no Windows e TUI de desenvolvimento nos demais SOs.
//! WinLean - graphical Windows interface and development TUI on other platforms.
//!
//! A UI nao altera o sistema. Ela monta a linha de comando e delega tudo ao
//! WinLean.ps1, que continua sendo utilizavel sozinho. Isso mantem uma unica
//! fonte de verdade sobre o que e alterado na maquina.
//!
//! The UI never changes the system itself. It builds a command line and delegates
//! everything to WinLean.ps1, which remains usable on its own. That keeps a single
//! source of truth about what gets changed on the machine.

#[cfg(not(target_os = "windows"))]
mod app;
#[cfg(not(target_os = "windows"))]
mod i18n;
mod runner;
#[cfg(not(target_os = "windows"))]
mod ui;
#[cfg(target_os = "windows")]
mod webapp;

#[cfg(not(target_os = "windows"))]
use app::{App, Screen};
#[cfg(not(target_os = "windows"))]
use i18n::Lang;
#[cfg(not(target_os = "windows"))]
use ratatui::crossterm::{
    event::{
        self, DisableMouseCapture, EnableMouseCapture, Event, KeyCode, KeyEventKind, KeyModifiers,
    },
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
#[cfg(not(target_os = "windows"))]
use ratatui::{backend::CrosstermBackend, Terminal};
#[cfg(not(target_os = "windows"))]
use std::io::{self, Stdout};
#[cfg(not(target_os = "windows"))]
use std::path::PathBuf;
#[cfg(not(target_os = "windows"))]
use std::time::Duration;

#[cfg(not(target_os = "windows"))]
const TICK: Duration = Duration::from_millis(80);

#[cfg(target_os = "windows")]
fn main() {
    if let Err(error) = webapp::run() {
        runner::show_error_dialog(&format!(
            "Nao foi possivel abrir o WinLean.\n\nCould not open WinLean.\n\n{error}"
        ));
    }
}

#[cfg(not(target_os = "windows"))]
fn main() -> io::Result<()> {
    let (lang, script) = parse_args();

    let script = match script {
        Some(p) => p,
        None => match locate_script() {
            Some(p) => p,
            None => {
                eprintln!(
                    "WinLean.ps1 nao encontrado. Use --script <caminho>.\n\
                     WinLean.ps1 not found. Use --script <path>."
                );
                std::process::exit(1);
            }
        },
    };

    let elevated = runner::is_elevated();
    let mut app = App::new(lang, script, elevated);

    let mut terminal = setup_terminal()?;
    let result = run_loop(&mut terminal, &mut app);
    restore_terminal(&mut terminal)?;
    result
}

// -----------------------------------------------------------------------------
// argumentos / arguments
// -----------------------------------------------------------------------------

#[cfg(not(target_os = "windows"))]
fn parse_args() -> (Lang, Option<PathBuf>) {
    let mut lang = Lang::Pt; // padrao: portugues / default: Portuguese
    let mut script = None;
    let args: Vec<String> = std::env::args().skip(1).collect();
    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--lang" | "-l" => {
                if i + 1 < args.len() {
                    lang = Lang::from_code(&args[i + 1]);
                    i += 1;
                }
            }
            "--script" | "-s" => {
                if i + 1 < args.len() {
                    script = Some(PathBuf::from(&args[i + 1]));
                    i += 1;
                }
            }
            "--help" | "-h" => {
                println!(
                    "WinLean UI\n\n\
                     --lang  pt|en    idioma da interface / interface language (padrao: pt)\n\
                     --script <path>  caminho do WinLean.ps1 / path to WinLean.ps1\n\
                     --help           esta ajuda / this help"
                );
                std::process::exit(0);
            }
            _ => {}
        }
        i += 1;
    }
    (lang, script)
}

/// Procura o WinLean.ps1 ao lado do executavel, no diretorio atual e na pasta de
/// instalacao padrao. Cobre tanto o uso via instalador quanto `cargo run`.
#[cfg(not(target_os = "windows"))]
fn locate_script() -> Option<PathBuf> {
    let mut candidates: Vec<PathBuf> = Vec::new();

    if let Ok(exe) = std::env::current_exe() {
        if let Some(dir) = exe.parent() {
            candidates.push(dir.join("WinLean.ps1"));
            // target/release/winlean.exe -> raiz do repositorio
            candidates.push(dir.join("../../../WinLean.ps1"));
        }
    }
    if let Ok(cwd) = std::env::current_dir() {
        candidates.push(cwd.join("WinLean.ps1"));
        candidates.push(cwd.join("../WinLean.ps1"));
    }
    if let Ok(local) = std::env::var("LOCALAPPDATA") {
        candidates.push(PathBuf::from(local).join("WinLean").join("WinLean.ps1"));
    }

    candidates.into_iter().find(|p| p.is_file())
}

// -----------------------------------------------------------------------------
// terminal
// -----------------------------------------------------------------------------

#[cfg(not(target_os = "windows"))]
fn setup_terminal() -> io::Result<Terminal<CrosstermBackend<Stdout>>> {
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen, EnableMouseCapture)?;
    Terminal::new(CrosstermBackend::new(stdout))
}

#[cfg(not(target_os = "windows"))]
fn restore_terminal(terminal: &mut Terminal<CrosstermBackend<Stdout>>) -> io::Result<()> {
    disable_raw_mode()?;
    execute!(
        terminal.backend_mut(),
        LeaveAlternateScreen,
        DisableMouseCapture
    )?;
    terminal.show_cursor()
}

// -----------------------------------------------------------------------------
// loop principal / main loop
// -----------------------------------------------------------------------------

#[cfg(not(target_os = "windows"))]
fn run_loop(terminal: &mut Terminal<CrosstermBackend<Stdout>>, app: &mut App) -> io::Result<()> {
    loop {
        // Altura util do painel de log, usada pelo autoscroll.
        let viewport = terminal.size()?.height.saturating_sub(9);
        app.tick(viewport);

        terminal.draw(|f| ui::draw(f, app))?;

        if event::poll(TICK)? {
            if let Event::Key(key) = event::read()? {
                // No Windows o crossterm entrega Press e Release; sem este filtro
                // cada tecla contaria duas vezes.
                if key.kind != KeyEventKind::Press {
                    continue;
                }
                if key.modifiers.contains(KeyModifiers::CONTROL)
                    && key.code == KeyCode::Char('c')
                    && (app.screen != Screen::Running || app.running_done())
                {
                    return Ok(());
                }
                handle_key(app, key.code, viewport);
            }
        }

        if app.quit {
            return Ok(());
        }
    }
}

#[cfg(not(target_os = "windows"))]
fn handle_key(app: &mut App, code: KeyCode, viewport: u16) {
    app.last_error = None;

    match app.screen {
        // ---------------------------------------------------------------- menu
        Screen::Menu => match code {
            KeyCode::Up | KeyCode::Char('k') => app.move_cursor(-1),
            KeyCode::Down | KeyCode::Char('j') => app.move_cursor(1),
            KeyCode::Home => app.cursor = 0,
            KeyCode::End => app.cursor = app.modules.len().saturating_sub(1),
            KeyCode::Char(' ') | KeyCode::Enter => app.toggle_current(),

            KeyCode::Char('1') => app.apply_preset("Minimal"),
            KeyCode::Char('2') => app.apply_preset("Work"),
            KeyCode::Char('3') => app.apply_preset("Gaming"),
            KeyCode::Char('4') => app.apply_preset("Full"),

            KeyCode::Char('a') | KeyCode::Char('A') => {
                let all_on = app.selected_count() == app.modules.len();
                for m in app.modules.iter_mut() {
                    m.on = !all_on;
                }
            }
            KeyCode::Char('p') | KeyCode::Char('P') => app.screen = Screen::PowerPlan,
            KeyCode::Char('d') | KeyCode::Char('D') => app.dry_run = !app.dry_run,
            KeyCode::Char('l') | KeyCode::Char('L') | KeyCode::F(2) => app.toggle_lang(),
            KeyCode::Char('r') | KeyCode::Char('R') => app.screen = Screen::Revert,
            KeyCode::Char('?') | KeyCode::F(1) => app.screen = Screen::Help,
            KeyCode::Char('s') | KeyCode::Char('S') | KeyCode::F(5) => app.screen = Screen::Confirm,
            KeyCode::Char('q') | KeyCode::Char('Q') | KeyCode::Esc => app.quit = true,
            _ => {}
        },

        // ------------------------------------------------------ plano de energia
        Screen::PowerPlan => match code {
            KeyCode::Up | KeyCode::Char('k') => app.move_cursor(-1),
            KeyCode::Down | KeyCode::Char('j') => app.move_cursor(1),
            KeyCode::Enter | KeyCode::Char(' ') => app.confirm_plan(),
            KeyCode::Esc | KeyCode::Char('q') => app.screen = Screen::Menu,
            KeyCode::Char('l') | KeyCode::F(2) => app.toggle_lang(),
            _ => {}
        },

        // -------------------------------------------------------- confirmacao
        Screen::Confirm => match code {
            KeyCode::Enter => {
                if app.selected_count() > 0 {
                    app.start(false);
                }
            }
            KeyCode::Esc | KeyCode::Char('q') => app.screen = Screen::Menu,
            _ => {}
        },

        Screen::Revert => match code {
            KeyCode::Enter => app.start(true),
            KeyCode::Esc | KeyCode::Char('q') => app.screen = Screen::Menu,
            _ => {}
        },

        // ----------------------------------------------------------- execucao
        Screen::Running => match code {
            KeyCode::PageUp => app.scroll_log(-(viewport as i32) / 2, viewport),
            KeyCode::PageDown => app.scroll_log((viewport as i32) / 2, viewport),
            KeyCode::Up | KeyCode::Char('k') => app.scroll_log(-1, viewport),
            KeyCode::Down | KeyCode::Char('j') => app.scroll_log(1, viewport),
            KeyCode::Home => app.scroll_log(-(app.log.len() as i32), viewport),
            KeyCode::End => app.scroll_log(app.log.len() as i32, viewport),
            // Sair da tela so e permitido apos o termino, para nao dar a impressao
            // de que a execucao foi cancelada quando ela segue rodando.
            KeyCode::Esc | KeyCode::Enter | KeyCode::Char('q') if app.running_done() => {
                app.runner = None;
                app.screen = Screen::Menu;
            }
            _ => {}
        },

        Screen::Help => match code {
            KeyCode::Esc | KeyCode::Enter | KeyCode::Char('q') | KeyCode::Char('?') => {
                app.screen = Screen::Menu
            }
            _ => {}
        },
    }
}
