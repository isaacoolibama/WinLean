//! Estado da aplicacao: modulos, presets, planos de energia e navegacao.
//! Application state: modules, presets, power plans and navigation.

use crate::i18n::{t, Lang};
use crate::runner::{LogLine, Runner};
use std::path::PathBuf;

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum Screen {
    Menu,
    PowerPlan,
    Confirm,
    Running,
    Help,
    Revert,
}

/// Um item do menu. `flag` e o parametro passado ao WinLean.ps1.
pub struct Module {
    pub flag: &'static str,
    pub name_key: &'static str,
    pub desc_key: &'static str,
    pub on: bool,
    /// Itens avancados ficam agrupados no fim da lista.
    pub advanced: bool,
}

pub struct PowerPlanItem {
    pub value: &'static str,
    pub name_key: &'static str,
    pub desc_key: &'static str,
}

pub struct App {
    pub lang: Lang,
    pub screen: Screen,
    pub modules: Vec<Module>,
    pub cursor: usize,
    pub plans: Vec<PowerPlanItem>,
    pub plan_cursor: usize,
    pub plan: &'static str,
    pub dry_run: bool,
    pub elevated: bool,
    pub script: PathBuf,
    pub log: Vec<LogLine>,
    pub log_scroll: u16,
    pub follow: bool,
    pub runner: Option<Runner>,
    pub spinner: usize,
    pub quit: bool,
    pub last_error: Option<String>,
}

impl App {
    pub fn new(lang: Lang, script: PathBuf, elevated: bool) -> Self {
        let modules = vec![
            Module {
                flag: "-RemoveApps",
                name_key: "mod.apps",
                desc_key: "mod.apps.d",
                on: true,
                advanced: false,
            },
            Module {
                flag: "-Privacy",
                name_key: "mod.privacy",
                desc_key: "mod.privacy.d",
                on: true,
                advanced: false,
            },
            Module {
                flag: "-DisableAI",
                name_key: "mod.ai",
                desc_key: "mod.ai.d",
                on: true,
                advanced: false,
            },
            Module {
                flag: "-Services",
                name_key: "mod.services",
                desc_key: "mod.services.d",
                on: true,
                advanced: false,
            },
            Module {
                flag: "-Interface",
                name_key: "mod.interface",
                desc_key: "mod.interface.d",
                on: true,
                advanced: false,
            },
            Module {
                flag: "-Performance",
                name_key: "mod.perf",
                desc_key: "mod.perf.d",
                on: true,
                advanced: false,
            },
            Module {
                flag: "-Energy",
                name_key: "mod.energy",
                desc_key: "mod.energy.d",
                on: true,
                advanced: false,
            },
            Module {
                flag: "-Gaming",
                name_key: "mod.gaming",
                desc_key: "mod.gaming.d",
                on: false,
                advanced: false,
            },
            Module {
                flag: "-CleanDisk",
                name_key: "mod.disk",
                desc_key: "mod.disk.d",
                on: true,
                advanced: false,
            },
            Module {
                flag: "-LowEndMode",
                name_key: "mod.lowend",
                desc_key: "mod.lowend.d",
                on: false,
                advanced: true,
            },
            Module {
                flag: "-ClassicContextMenu",
                name_key: "mod.ctxmenu",
                desc_key: "mod.ctxmenu.d",
                on: false,
                advanced: true,
            },
            Module {
                flag: "-DisableFastStartup",
                name_key: "mod.faststartup",
                desc_key: "mod.faststartup.d",
                on: false,
                advanced: true,
            },
            Module {
                flag: "-HAGS",
                name_key: "mod.hags",
                desc_key: "mod.hags.d",
                on: false,
                advanced: true,
            },
        ];

        let plans = vec![
            PowerPlanItem {
                value: "Keep",
                name_key: "plan.keep",
                desc_key: "plan.keep.d",
            },
            PowerPlanItem {
                value: "Auto",
                name_key: "plan.auto",
                desc_key: "plan.auto.d",
            },
            PowerPlanItem {
                value: "Balanced",
                name_key: "plan.balanced",
                desc_key: "plan.balanced.d",
            },
            PowerPlanItem {
                value: "HighPerformance",
                name_key: "plan.high",
                desc_key: "plan.high.d",
            },
            PowerPlanItem {
                value: "Ultimate",
                name_key: "plan.ultimate",
                desc_key: "plan.ultimate.d",
            },
            PowerPlanItem {
                value: "PowerSaver",
                name_key: "plan.saver",
                desc_key: "plan.saver.d",
            },
        ];

        App {
            lang,
            screen: Screen::Menu,
            modules,
            cursor: 0,
            plans,
            plan_cursor: 1, // Auto
            plan: "Auto",
            dry_run: false,
            elevated,
            script,
            log: Vec::new(),
            log_scroll: 0,
            follow: true,
            runner: None,
            spinner: 0,
            quit: false,
            last_error: None,
        }
    }

    // ---- navegacao / navigation -------------------------------------------

    pub fn move_cursor(&mut self, delta: isize) {
        let len = match self.screen {
            Screen::PowerPlan => self.plans.len(),
            _ => self.modules.len(),
        };
        if len == 0 {
            return;
        }
        let cur = match self.screen {
            Screen::PowerPlan => self.plan_cursor,
            _ => self.cursor,
        } as isize;
        // Lista circular: descer no ultimo item volta para o primeiro.
        let next = (cur + delta).rem_euclid(len as isize) as usize;
        match self.screen {
            Screen::PowerPlan => self.plan_cursor = next,
            _ => self.cursor = next,
        }
    }

    pub fn toggle_current(&mut self) {
        if let Some(m) = self.modules.get_mut(self.cursor) {
            m.on = !m.on;
        }
    }

    pub fn confirm_plan(&mut self) {
        if let Some(p) = self.plans.get(self.plan_cursor) {
            self.plan = p.value;
        }
        // Escolher um plano explicito implica rodar o modulo de energia.
        if self.plan != "Keep" {
            if let Some(m) = self.modules.iter_mut().find(|m| m.flag == "-Energy") {
                m.on = true;
            }
        }
        self.screen = Screen::Menu;
    }

    pub fn apply_preset(&mut self, preset: &str) {
        let enabled: &[&str] = match preset {
            "Minimal" => &["-Privacy", "-DisableAI"],
            "Work" => &[
                "-RemoveApps",
                "-Privacy",
                "-DisableAI",
                "-Services",
                "-Interface",
                "-Performance",
                "-Energy",
                "-CleanDisk",
            ],
            "Gaming" => &[
                "-RemoveApps",
                "-Privacy",
                "-DisableAI",
                "-Services",
                "-Interface",
                "-Performance",
                "-Energy",
                "-Gaming",
                "-CleanDisk",
            ],
            "Full" => &[
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
            ],
            _ => &[],
        };
        for m in self.modules.iter_mut() {
            m.on = enabled.contains(&m.flag);
        }
        self.plan = match preset {
            "Minimal" => "Keep",
            "Gaming" | "Full" => "Ultimate",
            _ => "Auto",
        };
        self.plan_cursor = self
            .plans
            .iter()
            .position(|p| p.value == self.plan)
            .unwrap_or(1);
    }

    pub fn toggle_lang(&mut self) {
        self.lang = self.lang.toggle();
    }

    pub fn selected_count(&self) -> usize {
        self.modules.iter().filter(|m| m.on).count()
    }

    pub fn selected_names(&self) -> Vec<&'static str> {
        self.modules
            .iter()
            .filter(|m| m.on)
            .map(|m| t(self.lang, m.name_key))
            .collect()
    }

    /// Monta a linha de comando entregue ao WinLean.ps1.
    pub fn build_args(&self, revert: bool) -> Vec<String> {
        let mut args = vec![
            "-Language".into(),
            self.lang.code().into(),
            "-Plain".into(),
            "-Silent".into(),
        ];
        if revert {
            args.push("-Revert".into());
            return args;
        }
        for m in self.modules.iter().filter(|m| m.on) {
            args.push(m.flag.into());
        }
        args.push("-PowerPlan".into());
        args.push(self.plan.into());
        if self.dry_run {
            args.push("-DryRun".into());
        }
        args
    }

    // ---- execucao / execution ---------------------------------------------

    pub fn start(&mut self, revert: bool) {
        self.log.clear();
        self.log_scroll = 0;
        self.follow = true;
        self.last_error = None;
        let args = self.build_args(revert);
        match Runner::spawn(&self.script, args) {
            Ok(r) => {
                self.runner = Some(r);
                self.screen = Screen::Running;
            }
            Err(e) => {
                self.last_error = Some(format!("{}: {}", t(self.lang, "run.spawn_err"), e));
            }
        }
    }

    /// Chamado a cada tick do loop principal.
    pub fn tick(&mut self, viewport: u16) {
        self.spinner = self.spinner.wrapping_add(1);
        if let Some(r) = &self.runner {
            let mut incoming = r.drain();
            if !incoming.is_empty() {
                self.log.append(&mut incoming);
                if self.follow {
                    // Autoscroll: manter a ultima linha visivel.
                    let total = self.log.len() as u16;
                    self.log_scroll = total.saturating_sub(viewport);
                }
            }
        }
    }

    pub fn running_done(&self) -> bool {
        self.runner
            .as_ref()
            .map(|r| r.is_finished())
            .unwrap_or(true)
    }

    pub fn exit_code(&self) -> i32 {
        self.runner.as_ref().map(|r| r.exit_code()).unwrap_or(0)
    }

    pub fn scroll_log(&mut self, delta: i32, viewport: u16) {
        let total = self.log.len() as i32;
        let max = (total - viewport as i32).max(0);
        let next = (self.log_scroll as i32 + delta).clamp(0, max);
        self.log_scroll = next as u16;
        // Sair do fim desliga o autoscroll; voltar ao fim religa.
        self.follow = next >= max;
    }

    pub fn plan_label(&self) -> &'static str {
        let key = self
            .plans
            .iter()
            .find(|p| p.value == self.plan)
            .map(|p| p.name_key)
            .unwrap_or("plan.keep");
        t(self.lang, key)
    }
}
