# Changelog

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/);
versionamento segue [Semantic Versioning](https://semver.org/lang/pt-BR/).

## [1.3.0] - 2026-08-13

### Adicionado / Added
- Ícone próprio do WinLean em SVG, PNG e ICO, embutido nos recursos do executável
  e usado pelo atalho do menu Iniciar.
- Limpeza pós-encerramento restrita à instalação, ao atalho e aos arquivos
  temporários do WinLean. Logs e journals de rollback são preservados.

### Alterado / Changed
- A janela agora sempre inicia maximizada.
- O progresso e o log de execução passaram para um modal central bloqueante.
- A interface foi redesenhada com cores e superfícies sólidas, sem degradês.

## [1.2.0] - 2026-08-13

### Adicionado / Added
- **Aplicativo gráfico para Windows** em Rust com HTML/CSS embutido, presets em
  cartões, seleção visual de módulos, confirmação antes de aplicar e log ao vivo.
- Verificação e instalação automática do Microsoft WebView2 Runtime no instalador.
- Atualização automática do motor e da interface ao executar novamente o instalador.

### Alterado / Changed
- O PowerShell agora roda oculto como motor; iniciar pelo atalho abre diretamente
  a janela gráfica, sem console visível.
- A interface do Windows migrou de `ratatui` para `winit` + `wry`. O TUI segue
  disponível fora do Windows para desenvolvimento.
- O guia interno de publicação foi removido do repositório público.

## [1.1.0] - 2026-08-13

### Adicionado / Added
- **Interface de terminal em Rust** (`ui/`, ratatui): lista de módulos com painel de
  detalhes, presets, seletor de plano de energia, log com streaming em tempo real,
  autoscroll e rolagem manual.
- **Instalador de uma linha** (`install.ps1`): eleva, baixa para
  `%LOCALAPPDATA%\WinLean`, cria atalho no menu Iniciar e abre a interface.
  Cai para o menu PowerShell quando não há binário publicado.
- **Internacionalização PT/EN** na interface e no motor, com português como padrão.
  Alternância em tempo real pela tecla `L`.
- **Módulo de plano de energia** com seis opções (Manter, Automático, Equilibrado,
  Alto desempenho, Desempenho máximo, Economia). Desempenho máximo é duplicado
  antes de ser ativado e o resultado é verificado, porque muitos notebooks recusam
  o esquema.
- Workflows de CI: build do binário Rust por tag, análise do PowerShell com
  PSScriptAnalyzer e verificação de sintaxe que reprova o build em caso de erro.

### Alterado / Changed
- O plano de energia saiu do módulo de performance e virou módulo próprio.
- `Run.bat` prefere a interface Rust e cai para o menu PowerShell.
- Toda string visível ao usuário no motor passou a ser escrita como `pt|en` e
  resolvida em tempo de execução.

## [1.0.0] - 2026-08-13

### Adicionado / Added
- Motor de rollback por journal: cada valor de registro, serviço e tarefa agendada
  é gravado com o estado anterior e pode ser desfeito com `-Revert`.
- Quatro presets: `Minimal`, `Work`, `Gaming`, `Full`.
- Oito módulos: bloatware, privacidade, Windows AI, serviços, interface,
  performance, jogos e limpeza de disco.
- Lógica adaptativa por hardware: RAM, SSD vs HDD, notebook vs desktop e domínio.
- Lista de apps protegidos contra curingas.
- Modo de simulação (`-DryRun`).
- Menu interativo em console.
- Ponto de restauração com bypass temporário do limite de 24h.

### Notas / Notes
- Memory Compression permanece habilitada de propósito.
- O Prefetch não é limpo de propósito.
- Windows Search, Spooler, Windows Update e Defender nunca são modificados.
