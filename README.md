<div align="center">

```
   __        ___       _
   \ \      / (_)_ __ | |    ___  __ _ _ __
    \ \ /\ / /| | '_ \| |   / _ \/ _` | '_ \
     \ V  V / | | | | | |__|  __/ (_| | | | |
      \_/\_/  |_|_| |_|_____\___|\__,_|_| |_|
```

**Debloat, privacidade e performance para Windows 10/11 — com interface em Rust e rollback de verdade.**

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell/)
[![Rust](https://img.shields.io/badge/Rust-GUI-000000?logo=rust&logoColor=white)](ui/)
[![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D6?logo=windows&logoColor=white)](#compatibilidade)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

🇺🇸 [English version](README.en.md)

</div>

---

## Instalação em uma linha

Abra o **Terminal como Administrador** (botão direito no Iniciar → Terminal (Admin)) e cole:

```powershell
irm https://raw.githubusercontent.com/isaacoolibama/WinLean/main/install.ps1 | iex
```

O instalador baixa tudo para `%LOCALAPPDATA%\WinLean`, cria um atalho no menu Iniciar e abre a interface. Nada é escrito em `Program Files` e nada roda em segundo plano depois.

Em inglês:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/isaacoolibama/WinLean/main/install.ps1))) -Lang en
```

Outras opções: `-NoLaunch` (só instala), `-Cli` (usa o menu PowerShell), `-Force` (força uma reinstalação).

---

## Por que mais um debloater?

A maioria dos scripts de debloat é uma lista de `reg add` sem nenhuma memória do que foi alterado. Se algo quebrar uma semana depois, o caminho é reinstalar o Windows.

O WinLean foi construído sobre três restrições:

| Restrição | Como é garantida |
|---|---|
| **Nada é irreversível** | Cada valor de registro, serviço e tarefa agendada é gravado em um journal JSON *com o estado anterior* antes da alteração. O `-Revert` executa o journal ao contrário. |
| **O Windows precisa continuar usável** | Serviços vão para `Manual`, não `Disabled`, sempre que desabilitar pudesse quebrar impressão, VPN, Bluetooth ou projeção. Search, Defender e Update nunca são tocados. |
| **Otimização precisa ser real** | Memory Compression permanece **ligada** e o Prefetch **não** é apagado. Os dois costumam ser "otimizados" por outros scripts, e remover ambos deixa máquinas com pouca RAM mais lentas. |

---

## Arquitetura

```
  ┌────────────────────────┐        ┌──────────────────────────────┐
  │  winlean.exe (Rust)    │        │  WinLean.ps1 (motor)         │
  │  HTML/CSS + WebView2   │──exec──▶  toda a lógica de alteração  │
  │  monta a linha de cmd  │◀─pipe──│  saída em texto estruturado  │
  └────────────────────────┘        └──────────────┬───────────────┘
                                                   │
                                     ┌─────────────▼──────────────┐
                                     │  journal-<data>.json       │
                                     │  estado anterior de tudo   │
                                     └────────────────────────────┘
```

A interface **não altera o sistema**. Ela monta a linha de comando e delega ao `WinLean.ps1`, que continua utilizável sozinho. Isso mantém uma única fonte de verdade sobre o que é modificado na máquina — e permite auditar o script sem ler uma linha de Rust.

A janela nativa é controlada por Rust e renderizada pelo Microsoft WebView2. O instalador verifica o runtime e o instala automaticamente quando necessário, inclusive no Windows LTSC. O PowerShell executa apenas como motor oculto e nenhum processo fica residente depois que o aplicativo é fechado.

---

## A interface

A v1.2.0 abre como um aplicativo gráfico normal do Windows: painel em HTML/CSS,
presets em cartões, seleção visual dos módulos, plano de energia, modo de simulação
e log em tempo real. Antes de qualquer alteração, uma confirmação resume exatamente
o que será executado.

O botão **Desfazer última execução** usa o journal mais recente. Português e inglês
podem ser alternados no topo da janela, e a escolha é repassada ao motor via
`-Language`.

---

## Presets

| Preset | O que faz | Plano de energia |
|---|---|---|
| **Mínimo** | Só telemetria, rastreamento e políticas de IA. Nenhuma mudança de interface ou app. | Manter |
| **Trabalho** | Bloatware, telemetria, IA, serviços, interface, performance, limpeza | Automático |
| **Jogos** | Tudo do Trabalho **+** GameDVR off, Game Mode on, MMCSS, throttling de rede off | Desempenho máximo |
| **Tudo** | Tudo, mais modo low-end, menu clássico e Fast Startup desativado | Desempenho máximo |

---

## Planos de energia

Selecionáveis na lista **Plano de energia** da interface ou com `-PowerPlan` na linha de comando.

| Opção | Descrição |
|---|---|
| **Manter** | Não altera nada relacionado a energia |
| **Automático** | Desktop recebe Desempenho máximo, notebook fica em Equilibrado |
| **Equilibrado** | Padrão do Windows. Escala a frequência conforme a carga |
| **Alto desempenho** | Mantém a CPU em frequência alta. Mais consumo e calor |
| **Desempenho máximo** | Elimina micro-latências do gerenciamento de energia |
| **Economia de energia** | Prioriza bateria, reduz desempenho de forma perceptível |

Dois detalhes que o script resolve por você:

- **Desempenho máximo vem oculto** no Windows. O script duplica o esquema antes de ativá-lo, e **verifica se o hardware aceitou** — muitos notebooks recusam esse plano. Se for recusado, nada é alterado e você é avisado, em vez de o script mentir que aplicou.
- Em desktop, a **suspensão seletiva de USB** também é desligada. É causa clássica de periférico sumindo do nada.

---

## Módulos

<details>
<summary><b>1. Remoção de bloatware</b></summary>

Remove cerca de 70 pacotes UWP para o usuário atual **e** faz o deprovisioning, para que novos perfis já nasçam limpos. Inclui Copilot, Widgets, o "novo Outlook", Teams, apps Bing, Phone Link, Clipchamp, DevHome e a shovelware de OEM de sempre.

Uma **lista de proteção** fixa garante que Microsoft Store, winget, Terminal, Calculadora, Bloco de Notas, Paint, Ferramenta de Captura, Fotos, Câmera, Segurança do Windows, codecs de mídia e o `Microsoft.XboxIdentityProvider` (exigido por muitos jogos) nunca sejam removidos — mesmo que algum curinga os alcance.
</details>

<details>
<summary><b>2. Privacidade e telemetria</b></summary>

- `AllowTelemetry = 0` nos dois caminhos de política
- ID de publicidade, experiências personalizadas, histórico de atividades e upload de timeline desligados
- 19 chaves de sugestão/anúncio do `ContentDeliveryManager` zeradas
- Personalização de digitação, tinta digital e coleta de contatos desligadas
- Relatório de Erros do Windows desligado
- `DiagTrack` e `dmwappushservice` desabilitados; WER, PcaSvc e MapsBroker em Manual
- 21 tarefas agendadas de telemetria desativadas
</details>

<details>
<summary><b>3. Copilot, Recall e Windows AI</b></summary>

`TurnOffWindowsCopilot` nas políticas de máquina e de usuário. Em `WindowsAI`: `DisableAIDataAnalysis`, `AllowRecallEnablement=0`, `TurnOffSavingSnapshots`, `DisableClickToDo`, além de Cocreator, Image Creator e preenchimento generativo do Paint.

A IA do Edge é tratada à parte, porque o **Edge 141+ desacoplou-a do Copilot do sistema**: sidebar, contexto de página, Compose e assistente de compras desligados por política.
</details>

<details>
<summary><b>4. Serviços</b></summary>

27 serviços reajustados, cada um com a justificativa explícita no código-fonte. `Disabled` só é usado onde não existe cenário legítimo em estação de trabalho (roteador AllJoyn, Fax, RRAS, Retail Demo, telemetria).

Também ajusta o `SvcHostSplitThresholdInKB` para o total de RAM instalada. Acima de 3,5 GB o Windows isola cada serviço em um `svchost.exe` próprio; elevar o limite reagrupa os serviços e reduz visivelmente a contagem de processos.

Nunca tocados: **Windows Search, Spooler, Windows Update, Defender, Áudio, Bluetooth, Temas, BITS, iphlpsvc, Netlogon**. Em máquinas de domínio, Registro Remoto e Arquivos Offline também são pulados.
</details>

<details>
<summary><b>5. Interface</b></summary>

Extensões visíveis, Explorer abrindo em *Este Computador*, botões de Visão de Tarefas / Widgets / Chat ocultos, recomendações e avisos de conta no Iniciar off, propaganda do OneDrive off, resultados web do Bing removidos da busca (quatro chaves — uma só não resolve), caixa de pesquisa reduzida a ícone.
</details>

<details>
<summary><b>6. Performance e memória</b></summary>

Delay de menu 400→200 ms, atraso de apps na inicialização removido, timeouts de desligamento reduzidos, Reserved Storage desativado (~7 GB de volta).

O **modo low-end** adiciona transparência, animações e redesenho ao arrastar desligados, mantendo o ClearType ativo — texto ilegível não é otimização.
</details>

<details>
<summary><b>7. Jogos</b></summary>

GameDVR off (política + chaves de usuário), Game Mode on, `SystemResponsiveness` 20→10, `NetworkThrottlingIndex` off, prioridades de GPU/CPU/SFIO elevadas em `Tasks\Games`, Nagle desativado apenas nos adaptadores ativos.

Serviços Xbox e o Xbox Identity Provider são preservados — Game Pass, EA App e launchers continuam funcionando.
</details>

<details>
<summary><b>8. Limpeza de disco</b></summary>

Temp do usuário e do Windows, logs CBS, fila do WER, cache de shaders DirectX, crash dumps, cache do Windows Update (com o serviço parado antes), Delivery Optimization e Lixeira. O preset Tudo ainda roda o DISM `/StartComponentCleanup`.

O Prefetch é deixado intacto de propósito.
</details>

---

## Rollback

Cada execução grava `C:\ProgramData\WinLean\backups\journal-<timestamp>.json` contendo, para cada mudança, o valor anterior **e se a chave sequer existia** — assim o revert remove o que o WinLean criou em vez de escrever um padrão chutado.

Pela interface: botão **Desfazer última execução**. Pela linha de comando:

```powershell
& "$env:LOCALAPPDATA\WinLean\WinLean.ps1" -Revert
& "$env:LOCALAPPDATA\WinLean\WinLean.ps1" -Revert -JournalPath "C:\...\journal-20260813-101500.json"
```

Um ponto de Restauração do Sistema também é criado antes da primeira alteração.

### Revertendo a remoção de apps

Apps UWP removidos **não** voltam automaticamente — o revert grava a lista em um arquivo de texto. Reinstale pela Microsoft Store, pelo `winget`, ou tudo de uma vez:

```powershell
Get-AppxPackage -AllUsers | ForEach-Object {
    Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml"
}
```

---

## Uso pela linha de comando

O motor funciona sozinho, sem a interface:

```powershell
# Simular tudo, sem alterar nada
.\WinLean.ps1 -Preset Work -DryRun

# Sem interação, em inglês, com plano de energia explícito
.\WinLean.ps1 -Preset Gaming -PowerPlan Ultimate -Language en -Silent

# Módulos avulsos
.\WinLean.ps1 -Privacy -DisableAI -Energy -PowerPlan Balanced
```

| Parâmetro | Descrição |
|---|---|
| `-Language pt\|en` | Idioma da saída (padrão: `pt`) |
| `-Preset Minimal\|Work\|Gaming\|Full` | Perfil pronto |
| `-PowerPlan Keep\|Auto\|Balanced\|HighPerformance\|Ultimate\|PowerSaver` | Plano de energia |
| `-RemoveApps -Privacy -DisableAI -Services -Interface -Performance -Energy -Gaming -CleanDisk` | Módulos individuais |
| `-LowEndMode` `-ClassicContextMenu` `-DisableFastStartup` `-HAGS` `-KeepXbox` | Opcionais |
| `-DryRun` | Simula tudo, não altera nada |
| `-Silent` | Sem perguntas |
| `-Plain` | Saída sem cor, para consumo pela interface |
| `-Revert [-JournalPath <arquivo>]` | Desfaz uma execução anterior |

---

## Compilando a interface

```bash
cd ui
cargo build --release
# binário em ui/target/release/winlean.exe
```

Requer Rust 1.88+. No Windows, a janela usa `winit` + `wry` e renderiza o HTML/CSS
embutido com o Microsoft WebView2. Em outros sistemas, a interface de terminal
continua disponível para desenvolvimento.

---

## Compatibilidade

| | Status |
|---|---|
| Windows 11 24H2 / 25H2 | Suportado |
| Windows 11 22H2 / 23H2 | Suportado |
| Windows 10 22H2 | Suportado — tweaks exclusivos do Win11 são pulados automaticamente |
| Windows 10 / 11 LTSC | Funciona; a maior parte do bloat já não existe |
| Windows Server | Não testado |

O WinLean detecta RAM, SSD vs HDD, notebook vs desktop e ingresso em domínio, e se adapta: o SysMain só é relaxado em SSD, o plano de energia é escolhido conforme o formato da máquina, e serviços sensíveis a ambiente corporativo são pulados em domínio.

---

## Arquivos

```
%LOCALAPPDATA%\WinLean\                        instalação
C:\ProgramData\WinLean\logs\winlean-*.log      trace completo
C:\ProgramData\WinLean\backups\journal-*.json  dados de rollback
```

---

## Créditos

Construído após estudar as abordagens de
[Raphire/Win11Debloat](https://github.com/Raphire/Win11Debloat),
[ChrisTitusTech/winutil](https://github.com/ChrisTitusTech/winutil) e
[zoicware/RemoveWindowsAI](https://github.com/zoicware/RemoveWindowsAI).
O motor de rollback por journal, a interface em Rust, a lista de apps protegidos
e a lógica adaptativa por hardware são autorais deste projeto.

---

## Aviso

O WinLean altera configurações do sistema, serviços e aplicativos instalados. É fornecido **no estado em que se encontra**, sem garantias. Leia o código, rode com simulação primeiro e mantenha backup. Você é responsável pelo que executa na sua máquina.

## Licença

[MIT](LICENSE) — Isaac Oolibama R. Lacerda
