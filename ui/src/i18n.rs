//! Tabela de textos PT/EN. Portugues e o padrao.
//! PT/EN string table. Portuguese is the default.
//!
//! Cada entrada e um par `(pt, en)`. Manter os dois idiomas lado a lado torna
//! obvio quando uma traducao ficou para tras.
//!
//! Each entry is a `(pt, en)` pair. Keeping both languages side by side makes it
//! obvious when a translation falls behind.

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Lang {
    Pt,
    En,
}

impl Lang {
    pub fn toggle(self) -> Self {
        match self {
            Lang::Pt => Lang::En,
            Lang::En => Lang::Pt,
        }
    }

    /// Codigo passado ao motor PowerShell via `-Language`.
    pub fn code(self) -> &'static str {
        match self {
            Lang::Pt => "pt",
            Lang::En => "en",
        }
    }

    pub fn label(self) -> &'static str {
        match self {
            Lang::Pt => "PT-BR",
            Lang::En => "EN",
        }
    }

    pub fn from_code(s: &str) -> Self {
        if s.eq_ignore_ascii_case("en") {
            Lang::En
        } else {
            Lang::Pt
        }
    }
}

/// Resolve uma chave no idioma ativo. Chave desconhecida volta como ela mesma,
/// o que deixa o erro visivel na tela em vez de sumir silenciosamente.
pub fn t(lang: Lang, key: &str) -> &str {
    let (pt, en) = lookup(key);
    match lang {
        Lang::Pt => pt,
        Lang::En => en,
    }
}

fn lookup(key: &str) -> (&str, &str) {
    match key {
        // --- cabecalho / header ---
        "app.subtitle" => (
            "Debloat, privacidade e performance para Windows",
            "Windows debloat, privacy and performance",
        ),
        "app.modules" => ("Modulos", "Modules"),
        "app.details" => ("Detalhes", "Details"),
        "app.dryrun_on" => ("SIMULACAO", "DRY RUN"),
        "app.dryrun_off" => ("APLICAR", "APPLY"),
        "app.admin_warn" => (
            " Sem privilegios de administrador - reabra em um terminal elevado ",
            " Not running as administrator - reopen in an elevated terminal ",
        ),

        // --- modulos / modules ---
        "mod.apps" => ("Remover bloatware", "Remove bloatware"),
        "mod.apps.d" => (
            "Remove cerca de 70 apps pre-instalados do usuario atual e faz o \
             deprovisioning, para que novos perfis nascam limpos.\n\n\
             Inclui Copilot, Widgets, novo Outlook, Teams, apps Bing, Phone Link, \
             Clipchamp e a shovelware de fabricante.\n\n\
             Uma lista de protecao impede que curingas alcancem Store, winget, \
             Terminal, Defender, codecs e o Xbox Identity Provider, exigido por \
             muitos jogos.",
            "Removes about 70 pre-installed apps for the current user and \
             deprovisions them so new profiles start clean.\n\n\
             Includes Copilot, Widgets, the new Outlook, Teams, Bing apps, Phone \
             Link, Clipchamp and OEM shovelware.\n\n\
             A protected list stops wildcards from reaching the Store, winget, \
             Terminal, Defender, codecs and the Xbox Identity Provider, which many \
             games require.",
        ),
        "mod.privacy" => ("Privacidade e telemetria", "Privacy and telemetry"),
        "mod.privacy.d" => (
            "AllowTelemetry = 0 nos dois caminhos de politica, ID de publicidade, \
             historico de atividades e experiencias personalizadas desligados.\n\n\
             19 chaves de sugestao e anuncio zeradas, personalizacao de digitacao e \
             tinta off, relatorio de erros off.\n\n\
             DiagTrack e dmwappushservice desabilitados, 21 tarefas agendadas de \
             telemetria desativadas.",
            "AllowTelemetry = 0 on both policy paths; advertising ID, activity \
             history and tailored experiences off.\n\n\
             19 suggestion and ad keys zeroed, typing and inking personalization \
             off, error reporting off.\n\n\
             DiagTrack and dmwappushservice disabled, 21 telemetry scheduled tasks \
             turned off.",
        ),
        "mod.ai" => ("Copilot, Recall e IA", "Copilot, Recall and AI"),
        "mod.ai.d" => (
            "TurnOffWindowsCopilot nas politicas de maquina e de usuario.\n\n\
             WindowsAI: Recall bloqueado, snapshots desligados, Click to Do, \
             Cocreator e preenchimento generativo off.\n\n\
             A IA do Edge e tratada a parte, porque o Edge 141+ desacoplou-a do \
             Copilot do sistema: sidebar, contexto de pagina e Compose off.",
            "TurnOffWindowsCopilot on both machine and user policies.\n\n\
             WindowsAI: Recall blocked, snapshots off, Click to Do, Cocreator and \
             generative fill off.\n\n\
             Edge AI is handled separately because Edge 141+ decoupled it from the \
             OS Copilot: sidebar, page context and Compose off.",
        ),
        "mod.services" => ("Servicos", "Services"),
        "mod.services.d" => (
            "27 servicos reajustados, cada um com justificativa no codigo-fonte.\n\n\
             Disabled so onde nao existe cenario legitimo em estacao de trabalho. \
             Nos demais casos, Manual: o Windows inicia sob demanda.\n\n\
             Ajusta tambem o SvcHostSplitThresholdInKB para o total de RAM, o que \
             reagrupa os servicos e reduz a contagem de svchost.exe.\n\n\
             Nunca tocados: Search, Spooler, Windows Update, Defender, Audio, \
             Bluetooth e Temas.",
            "27 services retimed, each with its justification in the source.\n\n\
             Disabled is used only where there is no legitimate workstation \
             scenario. Everything else goes to Manual so Windows can start it on \
             demand.\n\n\
             Also sets SvcHostSplitThresholdInKB to the installed RAM, which \
             re-groups services and cuts the svchost.exe count.\n\n\
             Never touched: Search, Spooler, Windows Update, Defender, Audio, \
             Bluetooth and Themes.",
        ),
        "mod.interface" => ("Interface", "Interface"),
        "mod.interface.d" => (
            "Extensoes de arquivo visiveis, Explorer abrindo em Este Computador, \
             botoes de Visao de Tarefas, Widgets e Chat ocultos.\n\n\
             Recomendacoes e avisos de conta no Iniciar off, propaganda do OneDrive \
             no Explorer off.\n\n\
             Resultados web do Bing removidos da busca - quatro chaves diferentes, \
             porque uma so nao resolve.",
            "File extensions visible, Explorer opening on This PC, Task View, \
             Widgets and Chat buttons hidden.\n\n\
             Start recommendations and account nags off, OneDrive ads in Explorer \
             off.\n\n\
             Bing web results removed from search - four separate keys, because one \
             is not enough.",
        ),
        "mod.perf" => ("Performance e memoria", "Performance and memory"),
        "mod.perf.d" => (
            "Delay de menu 400 -> 200 ms, atraso de apps na inicializacao removido, \
             timeouts de desligamento reduzidos.\n\n\
             Reserved Storage desativado, o que devolve cerca de 7 GB.\n\n\
             Memory Compression continua LIGADA de proposito: em maquina de 8 GB ela \
             evita paginacao, que custa muito mais caro que comprimir pagina.",
            "Menu delay 400 -> 200 ms, startup app delay removed, shutdown timeouts \
             trimmed.\n\n\
             Reserved Storage disabled, which gives back roughly 7 GB.\n\n\
             Memory Compression stays ON on purpose: on an 8 GB machine it prevents \
             paging, which is far more expensive than compressing a page.",
        ),
        "mod.energy" => ("Plano de energia", "Power plan"),
        "mod.energy.d" => (
            "Define o plano de energia do Windows. Pressione P para escolher.\n\n\
             Desempenho maximo vem oculto de fabrica e precisa ser duplicado antes \
             de ser ativado - o script faz isso automaticamente.\n\n\
             Em desktop, a suspensao seletiva de USB tambem e desligada: e causa \
             classica de periferico sumindo do nada.",
            "Sets the Windows power plan. Press P to choose.\n\n\
             Ultimate Performance ships hidden and must be duplicated before it can \
             be activated - the script does that automatically.\n\n\
             On desktops, USB selective suspend is also turned off: it is a classic \
             cause of peripherals dropping out.",
        ),
        "mod.gaming" => ("Jogos e latencia", "Gaming and latency"),
        "mod.gaming.d" => (
            "Gravacao em segundo plano do GameDVR off, Modo Jogo ligado.\n\n\
             MMCSS: SystemResponsiveness de 20 para 10, throttling de rede off, \
             prioridades de GPU, CPU e I/O elevadas para a tarefa Games.\n\n\
             Nagle desativado apenas nos adaptadores realmente ativos.\n\n\
             Servicos Xbox preservados: Game Pass e launchers seguem funcionando.",
            "GameDVR background recording off, Game Mode on.\n\n\
             MMCSS: SystemResponsiveness from 20 to 10, network throttling off, GPU, \
             CPU and I/O priorities raised for the Games task.\n\n\
             Nagle disabled only on adapters that are actually active.\n\n\
             Xbox services preserved: Game Pass and launchers keep working.",
        ),
        "mod.disk" => ("Limpeza de disco", "Disk cleanup"),
        "mod.disk.d" => (
            "Temp do usuario e do Windows, logs CBS, fila de relatorio de erros, \
             cache de shaders DirectX, crash dumps.\n\n\
             Cache de download do Windows Update com o servico parado antes, cache do \
             Delivery Optimization e Lixeira.\n\n\
             O Prefetch e deixado intacto de proposito: o Windows apenas o \
             reconstroi e os apps abrem mais devagar ate la.",
            "User and Windows temp, CBS logs, error report queue, DirectX shader \
             cache, crash dumps.\n\n\
             Windows Update download cache with the service stopped first, Delivery \
             Optimization cache and Recycle Bin.\n\n\
             Prefetch is left alone on purpose: Windows just rebuilds it and apps \
             open more slowly until it does.",
        ),
        "mod.lowend" => ("Modo low-end (<= 8 GB)", "Low-end mode (<= 8 GB)"),
        "mod.lowend.d" => (
            "Transparencia, animacoes de janela e redesenho ao arrastar desligados.\n\n\
             O ClearType permanece ativo: texto ilegivel nao e otimizacao.\n\n\
             Em SSD, o SysMain vai para Manual. Em disco mecanico ele fica ligado, \
             porque ali o SuperFetch realmente ajuda.",
            "Transparency, window animations and drag-redraw turned off.\n\n\
             ClearType stays on: unreadable text is not an optimization.\n\n\
             On SSD, SysMain goes to Manual. On a mechanical disk it stays enabled, \
             because SuperFetch genuinely helps there.",
        ),
        "mod.ctxmenu" => ("Menu de contexto classico", "Classic context menu"),
        "mod.ctxmenu.d" => (
            "Restaura o menu de clique direito completo do Windows 10, sem o passo \
             extra de \"Mostrar mais opcoes\".\n\n\
             Somente Windows 11. Em Windows 10 o item e ignorado.",
            "Restores the full Windows 10 right-click menu, without the extra \
             \"Show more options\" step.\n\n\
             Windows 11 only. On Windows 10 the item is ignored.",
        ),
        "mod.faststartup" => ("Desativar Fast Startup", "Disable Fast Startup"),
        "mod.faststartup.d" => (
            "O Fast Startup nao desliga o Windows de verdade: ele hiberna o kernel. \
             Isso preserva estado antigo entre reinicios e e causa frequente de \
             problema que \"so some reinstalando\".\n\n\
             Recomendado em dual boot e em maquina de diagnostico.",
            "Fast Startup does not really shut Windows down: it hibernates the \
             kernel. That carries stale state across boots and is a frequent cause \
             of problems that \"only a reinstall fixes\".\n\n\
             Recommended for dual boot and diagnostic machines.",
        ),
        "mod.hags" => ("Agendamento de GPU (HAGS)", "GPU scheduling (HAGS)"),
        "mod.hags.d" => (
            "Transfere o agendamento de memoria da GPU para o proprio hardware.\n\n\
             Experimental: em algumas combinacoes de placa e driver o ganho e nulo \
             ou negativo. Meca antes de manter.",
            "Moves GPU memory scheduling onto the hardware itself.\n\n\
             Experimental: on some GPU and driver combinations the gain is zero or \
             negative. Measure before keeping it.",
        ),

        // --- planos de energia / power plans ---
        "plan.title" => ("Escolha o plano de energia", "Choose the power plan"),
        "plan.keep" => ("Manter o plano atual", "Keep the current plan"),
        "plan.keep.d" => (
            "Nao altera nada relacionado a energia.",
            "Leaves everything power-related untouched.",
        ),
        "plan.balanced" => ("Equilibrado", "Balanced"),
        "plan.balanced.d" => (
            "Padrao do Windows. Escala a frequencia conforme a carga. Melhor escolha \
             para notebook e para quem se importa com consumo.",
            "Windows default. Scales frequency with load. Best choice for laptops and \
             for anyone who cares about power draw.",
        ),
        "plan.high" => ("Alto desempenho", "High performance"),
        "plan.high.d" => (
            "Mantem a CPU em frequencia alta o tempo todo. Mais consumo, mais calor e \
             ventoinha mais audivel, em troca de resposta mais previsivel.",
            "Keeps the CPU at high clocks all the time. More power, more heat and a \
             louder fan, in exchange for more predictable response.",
        ),
        "plan.ultimate" => ("Desempenho maximo", "Ultimate performance"),
        "plan.ultimate.d" => (
            "Elimina micro-latencias do gerenciamento de energia. Vem oculto no \
             Windows e o script o cria antes de ativar.\n\n\
             Pensado para desktop ligado na tomada. Muitos notebooks simplesmente \
             recusam este plano - se isso acontecer, nada e alterado.",
            "Removes power-management micro-latencies. It ships hidden in Windows and \
             the script creates it before activating.\n\n\
             Meant for desktops on AC power. Many laptops simply refuse this plan - \
             if that happens, nothing is changed.",
        ),
        "plan.saver" => ("Economia de energia", "Power saver"),
        "plan.saver.d" => (
            "Prioriza bateria. Reduz o desempenho de forma perceptivel. Util em \
             viagem ou em maquina que fica ociosa a maior parte do tempo.",
            "Prioritizes battery. Noticeably reduces performance. Useful while \
             travelling or on a machine that idles most of the time.",
        ),
        "plan.auto" => ("Automatico", "Auto"),
        "plan.auto.d" => (
            "Desktop recebe Desempenho maximo, notebook fica em Equilibrado. \
             A deteccao usa o tipo de chassi reportado pelo firmware.",
            "Desktops get Ultimate Performance, laptops stay on Balanced. Detection \
             uses the chassis type reported by the firmware.",
        ),

        // --- presets ---
        "preset.minimal" => ("Minimo", "Minimal"),
        "preset.work" => ("Trabalho", "Work"),
        "preset.gaming" => ("Jogos", "Gaming"),
        "preset.full" => ("Tudo", "Full"),

        // --- rodape / footer ---
        "key.nav" => ("navegar", "navigate"),
        "key.toggle" => ("marcar", "toggle"),
        "key.presets" => ("presets", "presets"),
        "key.power" => ("energia", "power"),
        "key.dry" => ("simular", "dry run"),
        "key.lang" => ("idioma", "language"),
        "key.revert" => ("desfazer", "revert"),
        "key.start" => ("INICIAR", "START"),
        "key.quit" => ("sair", "quit"),
        "key.back" => ("voltar", "back"),
        "key.select" => ("selecionar", "select"),
        "key.scroll" => ("rolar", "scroll"),

        // --- confirmacao / confirm ---
        "confirm.title" => ("Confirmar execucao", "Confirm run"),
        "confirm.modules" => ("Modulos selecionados", "Selected modules"),
        "confirm.plan" => ("Plano de energia", "Power plan"),
        "confirm.mode" => ("Modo", "Mode"),
        "confirm.mode_dry" => (
            "Simulacao - nada sera alterado",
            "Dry run - nothing will be changed",
        ),
        "confirm.mode_real" => (
            "Aplicacao real - um ponto de restauracao sera criado antes",
            "Real run - a restore point will be created first",
        ),
        "confirm.none" => ("Nenhum modulo selecionado.", "No module selected."),
        "confirm.go" => ("Enter para executar", "Enter to run"),
        "confirm.cancel" => ("Esc para cancelar", "Esc to cancel"),

        // --- execucao / running ---
        "run.title" => ("Executando", "Running"),
        "run.done" => ("Concluido", "Finished"),
        "run.failed" => ("Falhou", "Failed"),
        "run.lines" => ("linhas", "lines"),
        "run.wait" => (
            "Aguarde. Nao feche a janela.",
            "Please wait. Do not close the window.",
        ),
        "run.back" => (
            "Esc ou Enter para voltar ao menu",
            "Esc or Enter to return to the menu",
        ),
        "run.spawn_err" => (
            "Nao foi possivel iniciar o PowerShell",
            "Could not start PowerShell",
        ),

        // --- rollback ---
        "revert.title" => ("Desfazer ultima execucao", "Roll back the last run"),
        "revert.body" => (
            "Isto restaura cada chave de registro, servico e tarefa agendada ao \
             estado anterior, usando o journal da execucao mais recente.\n\n\
             Aplicativos removidos NAO voltam automaticamente. A lista deles e \
             gravada em um arquivo de texto para reinstalacao manual.",
            "This restores every registry value, service and scheduled task to its \
             previous state using the journal from the most recent run.\n\n\
             Removed apps do NOT come back automatically. Their list is written to a \
             text file for manual reinstallation.",
        ),

        // --- ajuda / help ---
        "help.title" => ("Atalhos", "Shortcuts"),

        _ => (key, key),
    }
}

#[cfg(test)]
mod tests {
    use super::{t, Lang};

    #[test]
    fn resolves_both_languages() {
        assert_eq!(t(Lang::Pt, "app.modules"), "Modulos");
        assert_eq!(t(Lang::En, "app.modules"), "Modules");
    }

    #[test]
    fn preserves_unknown_keys() {
        let key = String::from("missing.translation");
        assert_eq!(t(Lang::Pt, &key), key);
        assert_eq!(t(Lang::En, &key), key);
    }
}
