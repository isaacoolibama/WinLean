//! Renderizacao das telas.
//! Screen rendering.

use crate::app::{App, Screen};
use crate::i18n::t;
use crate::runner::LineKind;
use ratatui::{
    layout::{Alignment, Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Clear, List, ListItem, ListState, Paragraph, Wrap},
    Frame,
};

const ACCENT: Color = Color::Cyan;
const DIM: Color = Color::DarkGray;

pub fn draw(f: &mut Frame, app: &mut App) {
    let area = f.area();

    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(if app.elevated { 3 } else { 4 }),
            Constraint::Min(8),
            Constraint::Length(3),
        ])
        .split(area);

    draw_header(f, app, chunks[0]);

    match app.screen {
        Screen::Menu => draw_menu(f, app, chunks[1]),
        Screen::PowerPlan => draw_plans(f, app, chunks[1]),
        Screen::Confirm => draw_confirm(f, app, chunks[1]),
        Screen::Revert => draw_revert(f, app, chunks[1]),
        Screen::Running => draw_running(f, app, chunks[1]),
        Screen::Help => draw_help(f, app, chunks[1]),
    }

    draw_footer(f, app, chunks[2]);
}

// -----------------------------------------------------------------------------
// cabecalho / header
// -----------------------------------------------------------------------------

fn draw_header(f: &mut Frame, app: &App, area: Rect) {
    let mode = if app.dry_run {
        Span::styled(
            format!(" {} ", t(app.lang, "app.dryrun_on")),
            Style::default()
                .fg(Color::Black)
                .bg(Color::Yellow)
                .add_modifier(Modifier::BOLD),
        )
    } else {
        Span::styled(
            format!(" {} ", t(app.lang, "app.dryrun_off")),
            Style::default()
                .fg(Color::Black)
                .bg(Color::Green)
                .add_modifier(Modifier::BOLD),
        )
    };

    let mut lines = vec![Line::from(vec![
        Span::styled(
            "WinLean",
            Style::default().fg(ACCENT).add_modifier(Modifier::BOLD),
        ),
        Span::styled(
            format!("  v{}  ", env!("CARGO_PKG_VERSION")),
            Style::default().fg(DIM),
        ),
        Span::styled(
            t(app.lang, "app.subtitle"),
            Style::default().fg(Color::Gray),
        ),
        Span::raw("   "),
        mode,
        Span::raw("  "),
        Span::styled(
            format!("[{}]", app.lang.label()),
            Style::default().fg(ACCENT),
        ),
    ])];

    if !app.elevated {
        lines.push(Line::from(Span::styled(
            t(app.lang, "app.admin_warn"),
            Style::default()
                .fg(Color::Black)
                .bg(Color::Red)
                .add_modifier(Modifier::BOLD),
        )));
    }

    let block = Block::default()
        .borders(Borders::BOTTOM)
        .border_style(Style::default().fg(DIM));
    f.render_widget(Paragraph::new(lines).block(block), area);
}

// -----------------------------------------------------------------------------
// menu principal / main menu
// -----------------------------------------------------------------------------

fn draw_menu(f: &mut Frame, app: &mut App, area: Rect) {
    let cols = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(48), Constraint::Percentage(52)])
        .split(area);

    let mut items: Vec<ListItem> = Vec::with_capacity(app.modules.len());

    for m in app.modules.iter() {
        let (mark, style) = if m.on {
            ("[x]", Style::default().fg(Color::White))
        } else {
            ("[ ]", Style::default().fg(DIM))
        };
        // Itens avancados ficam recuados, para separar visualmente do bloco padrao.
        let prefix = if m.advanced { "  " } else { "" };
        items.push(ListItem::new(Line::from(vec![
            Span::styled(format!(" {} {}", mark, prefix), style),
            Span::styled(t(app.lang, m.name_key), style),
        ])));
    }

    let title = format!(
        " {} ({}/{}) ",
        t(app.lang, "app.modules"),
        app.selected_count(),
        app.modules.len()
    );

    let list = List::new(items)
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_style(Style::default().fg(DIM))
                .title(Span::styled(title, Style::default().fg(ACCENT))),
        )
        .highlight_style(
            Style::default()
                .bg(ACCENT)
                .fg(Color::Black)
                .add_modifier(Modifier::BOLD),
        )
        .highlight_symbol("");

    let mut state = ListState::default();
    state.select(Some(app.cursor));
    f.render_stateful_widget(list, cols[0], &mut state);

    // Painel de detalhes do item sob o cursor.
    let (name, desc) = app
        .modules
        .get(app.cursor)
        .map(|m| (t(app.lang, m.name_key), t(app.lang, m.desc_key)))
        .unwrap_or(("", ""));

    let mut body = vec![
        Line::from(Span::styled(
            name,
            Style::default().fg(ACCENT).add_modifier(Modifier::BOLD),
        )),
        Line::from(""),
    ];
    for l in desc.split('\n') {
        body.push(Line::from(Span::styled(
            l,
            Style::default().fg(Color::Gray),
        )));
    }
    body.push(Line::from(""));
    body.push(Line::from(vec![
        Span::styled(
            format!("{}: ", t(app.lang, "confirm.plan")),
            Style::default().fg(DIM),
        ),
        Span::styled(app.plan_label(), Style::default().fg(Color::Yellow)),
    ]));

    f.render_widget(
        Paragraph::new(body).wrap(Wrap { trim: true }).block(
            Block::default()
                .borders(Borders::ALL)
                .border_style(Style::default().fg(DIM))
                .title(Span::styled(
                    format!(" {} ", t(app.lang, "app.details")),
                    Style::default().fg(ACCENT),
                )),
        ),
        cols[1],
    );

    if let Some(err) = &app.last_error {
        draw_toast(f, area, err);
    }
}

// -----------------------------------------------------------------------------
// planos de energia / power plans
// -----------------------------------------------------------------------------

fn draw_plans(f: &mut Frame, app: &mut App, area: Rect) {
    let cols = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(48), Constraint::Percentage(52)])
        .split(area);

    let items: Vec<ListItem> = app
        .plans
        .iter()
        .map(|p| {
            let selected = p.value == app.plan;
            let mark = if selected { "(o)" } else { "( )" };
            let style = if selected {
                Style::default()
                    .fg(Color::White)
                    .add_modifier(Modifier::BOLD)
            } else {
                Style::default().fg(Color::Gray)
            };
            ListItem::new(Line::from(vec![
                Span::styled(format!(" {} ", mark), style),
                Span::styled(t(app.lang, p.name_key), style),
            ]))
        })
        .collect();

    let list = List::new(items)
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_style(Style::default().fg(Color::Yellow))
                .title(Span::styled(
                    format!(" {} ", t(app.lang, "plan.title")),
                    Style::default().fg(Color::Yellow),
                )),
        )
        .highlight_style(
            Style::default()
                .bg(Color::Yellow)
                .fg(Color::Black)
                .add_modifier(Modifier::BOLD),
        );

    let mut state = ListState::default();
    state.select(Some(app.plan_cursor));
    f.render_stateful_widget(list, cols[0], &mut state);

    let (name, desc) = app
        .plans
        .get(app.plan_cursor)
        .map(|p| (t(app.lang, p.name_key), t(app.lang, p.desc_key)))
        .unwrap_or(("", ""));

    let mut body = vec![
        Line::from(Span::styled(
            name,
            Style::default()
                .fg(Color::Yellow)
                .add_modifier(Modifier::BOLD),
        )),
        Line::from(""),
    ];
    for l in desc.split('\n') {
        body.push(Line::from(Span::styled(
            l,
            Style::default().fg(Color::Gray),
        )));
    }

    f.render_widget(
        Paragraph::new(body).wrap(Wrap { trim: true }).block(
            Block::default()
                .borders(Borders::ALL)
                .border_style(Style::default().fg(DIM)),
        ),
        cols[1],
    );
}

// -----------------------------------------------------------------------------
// confirmacao / confirm
// -----------------------------------------------------------------------------

fn draw_confirm(f: &mut Frame, app: &App, area: Rect) {
    let mut body = vec![Line::from(Span::styled(
        format!("{}:", t(app.lang, "confirm.modules")),
        Style::default().fg(ACCENT).add_modifier(Modifier::BOLD),
    ))];

    let names = app.selected_names();
    if names.is_empty() {
        body.push(Line::from(Span::styled(
            t(app.lang, "confirm.none"),
            Style::default().fg(Color::Red),
        )));
    } else {
        for n in names {
            body.push(Line::from(Span::styled(
                format!("   - {}", n),
                Style::default().fg(Color::White),
            )));
        }
    }

    body.push(Line::from(""));
    body.push(Line::from(vec![
        Span::styled(
            format!("{}: ", t(app.lang, "confirm.plan")),
            Style::default().fg(ACCENT),
        ),
        Span::styled(app.plan_label(), Style::default().fg(Color::Yellow)),
    ]));
    body.push(Line::from(vec![
        Span::styled(
            format!("{}: ", t(app.lang, "confirm.mode")),
            Style::default().fg(ACCENT),
        ),
        Span::styled(
            if app.dry_run {
                t(app.lang, "confirm.mode_dry")
            } else {
                t(app.lang, "confirm.mode_real")
            },
            Style::default().fg(if app.dry_run {
                Color::Yellow
            } else {
                Color::Green
            }),
        ),
    ]));
    body.push(Line::from(""));
    body.push(Line::from(vec![
        Span::styled(t(app.lang, "confirm.go"), Style::default().fg(Color::Green)),
        Span::styled("     ", Style::default()),
        Span::styled(t(app.lang, "confirm.cancel"), Style::default().fg(DIM)),
    ]));

    f.render_widget(
        Paragraph::new(body).wrap(Wrap { trim: true }).block(
            Block::default()
                .borders(Borders::ALL)
                .border_style(Style::default().fg(ACCENT))
                .title(Span::styled(
                    format!(" {} ", t(app.lang, "confirm.title")),
                    Style::default().fg(ACCENT),
                )),
        ),
        area,
    );
}

fn draw_revert(f: &mut Frame, app: &App, area: Rect) {
    let mut body = Vec::new();
    for l in t(app.lang, "revert.body").split('\n') {
        body.push(Line::from(Span::styled(
            l,
            Style::default().fg(Color::Gray),
        )));
    }
    body.push(Line::from(""));
    body.push(Line::from(vec![
        Span::styled(t(app.lang, "confirm.go"), Style::default().fg(Color::Green)),
        Span::styled("     ", Style::default()),
        Span::styled(t(app.lang, "confirm.cancel"), Style::default().fg(DIM)),
    ]));

    f.render_widget(
        Paragraph::new(body).wrap(Wrap { trim: true }).block(
            Block::default()
                .borders(Borders::ALL)
                .border_style(Style::default().fg(Color::Magenta))
                .title(Span::styled(
                    format!(" {} ", t(app.lang, "revert.title")),
                    Style::default().fg(Color::Magenta),
                )),
        ),
        area,
    );
}

// -----------------------------------------------------------------------------
// execucao / running
// -----------------------------------------------------------------------------

const SPINNER: [&str; 8] = ["|", "/", "-", "\\", "|", "/", "-", "\\"];

fn draw_running(f: &mut Frame, app: &App, area: Rect) {
    let done = app.running_done();

    let title = if done {
        let ok = app.exit_code() == 0;
        format!(
            " {} - {} {} ",
            if ok {
                t(app.lang, "run.done")
            } else {
                t(app.lang, "run.failed")
            },
            app.log.len(),
            t(app.lang, "run.lines")
        )
    } else {
        format!(
            " {} {} - {} {} ",
            SPINNER[(app.spinner / 2) % SPINNER.len()],
            t(app.lang, "run.title"),
            app.log.len(),
            t(app.lang, "run.lines")
        )
    };

    let border = if !done {
        Color::Yellow
    } else if app.exit_code() == 0 {
        Color::Green
    } else {
        Color::Red
    };

    let lines: Vec<Line> = app
        .log
        .iter()
        .map(|l| {
            let style = match l.kind {
                LineKind::Section => Style::default().fg(ACCENT).add_modifier(Modifier::BOLD),
                LineKind::Ok => Style::default().fg(Color::Green),
                LineKind::Warn => Style::default().fg(Color::Yellow),
                LineKind::Error => Style::default().fg(Color::Red),
                LineKind::Dry => Style::default().fg(DIM),
                LineKind::Plain => Style::default().fg(Color::Gray),
            };
            let prefix = match l.kind {
                LineKind::Section => "== ",
                LineKind::Ok => " + ",
                LineKind::Warn => " ! ",
                LineKind::Error => " x ",
                LineKind::Dry => " ~ ",
                LineKind::Plain => "   ",
            };
            Line::from(vec![
                Span::styled(prefix, style),
                Span::styled(l.text.clone(), style),
            ])
        })
        .collect();

    f.render_widget(
        Paragraph::new(lines).scroll((app.log_scroll, 0)).block(
            Block::default()
                .borders(Borders::ALL)
                .border_style(Style::default().fg(border))
                .title(Span::styled(title, Style::default().fg(border))),
        ),
        area,
    );
}

// -----------------------------------------------------------------------------
// ajuda / help
// -----------------------------------------------------------------------------

fn draw_help(f: &mut Frame, app: &App, area: Rect) {
    let rows: [(&str, &str, &str); 12] = [
        (
            "Up / Down, j / k",
            "navegar pela lista",
            "move through the list",
        ),
        (
            "Space / Enter",
            "marcar ou desmarcar o item",
            "toggle the item",
        ),
        (
            "1 2 3 4",
            "presets Minimo, Trabalho, Jogos, Tudo",
            "Minimal, Work, Gaming, Full presets",
        ),
        ("P", "escolher o plano de energia", "choose the power plan"),
        ("D", "alternar simulacao", "toggle dry run"),
        (
            "L / F2",
            "alternar portugues e ingles",
            "switch Portuguese and English",
        ),
        (
            "A",
            "marcar ou desmarcar tudo",
            "select or clear everything",
        ),
        ("R", "desfazer a ultima execucao", "roll back the last run"),
        ("S / F5", "iniciar", "start"),
        (
            "PgUp / PgDn",
            "rolar o log durante a execucao",
            "scroll the log while running",
        ),
        ("?", "esta tela", "this screen"),
        ("Q / Esc", "sair", "quit"),
    ];

    let mut body = Vec::new();
    for (key, pt, en) in rows.iter() {
        let desc = if app.lang == crate::i18n::Lang::Pt {
            pt
        } else {
            en
        };
        body.push(Line::from(vec![
            Span::styled(
                format!("  {:<18}", key),
                Style::default().fg(ACCENT).add_modifier(Modifier::BOLD),
            ),
            Span::styled(*desc, Style::default().fg(Color::Gray)),
        ]));
    }

    f.render_widget(
        Paragraph::new(body).block(
            Block::default()
                .borders(Borders::ALL)
                .border_style(Style::default().fg(ACCENT))
                .title(Span::styled(
                    format!(" {} ", t(app.lang, "help.title")),
                    Style::default().fg(ACCENT),
                )),
        ),
        area,
    );
}

// -----------------------------------------------------------------------------
// rodape / footer
// -----------------------------------------------------------------------------

fn draw_footer(f: &mut Frame, app: &App, area: Rect) {
    let hints: Vec<(&str, &str)> = match app.screen {
        Screen::Menu => vec![
            ("Up/Dn", t(app.lang, "key.nav")),
            ("Space", t(app.lang, "key.toggle")),
            ("1-4", t(app.lang, "key.presets")),
            ("P", t(app.lang, "key.power")),
            ("D", t(app.lang, "key.dry")),
            ("L", t(app.lang, "key.lang")),
            ("R", t(app.lang, "key.revert")),
            ("S", t(app.lang, "key.start")),
            ("Q", t(app.lang, "key.quit")),
        ],
        Screen::PowerPlan => vec![
            ("Up/Dn", t(app.lang, "key.nav")),
            ("Enter", t(app.lang, "key.select")),
            ("Esc", t(app.lang, "key.back")),
        ],
        Screen::Confirm | Screen::Revert => vec![
            ("Enter", t(app.lang, "key.start")),
            ("Esc", t(app.lang, "key.back")),
        ],
        Screen::Running => {
            if app.running_done() {
                vec![("Esc/Enter", t(app.lang, "key.back"))]
            } else {
                vec![
                    ("PgUp/PgDn", t(app.lang, "key.scroll")),
                    ("", t(app.lang, "run.wait")),
                ]
            }
        }
        Screen::Help => vec![("Esc", t(app.lang, "key.back"))],
    };

    let mut spans = Vec::new();
    for (k, d) in hints {
        if !k.is_empty() {
            spans.push(Span::styled(
                format!(" {} ", k),
                Style::default()
                    .fg(Color::Black)
                    .bg(ACCENT)
                    .add_modifier(Modifier::BOLD),
            ));
            spans.push(Span::raw(" "));
        }
        spans.push(Span::styled(d, Style::default().fg(Color::Gray)));
        spans.push(Span::raw("   "));
    }

    f.render_widget(
        Paragraph::new(Line::from(spans))
            .alignment(Alignment::Left)
            .block(
                Block::default()
                    .borders(Borders::TOP)
                    .border_style(Style::default().fg(DIM)),
            ),
        area,
    );
}

/// Mensagem flutuante de erro, centralizada sobre a tela atual.
fn draw_toast(f: &mut Frame, area: Rect, msg: &str) {
    let w = area.width.saturating_sub(8).min(70);
    let h = 5u16;
    let rect = Rect {
        x: area.x + (area.width.saturating_sub(w)) / 2,
        y: area.y + (area.height.saturating_sub(h)) / 2,
        width: w,
        height: h,
    };
    f.render_widget(Clear, rect);
    f.render_widget(
        Paragraph::new(msg)
            .wrap(Wrap { trim: true })
            .style(Style::default().fg(Color::White))
            .block(
                Block::default()
                    .borders(Borders::ALL)
                    .border_style(Style::default().fg(Color::Red)),
            ),
        rect,
    );
}
