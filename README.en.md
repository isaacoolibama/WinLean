<div align="center">

```
   __        ___       _
   \ \      / (_)_ __ | |    ___  __ _ _ __
    \ \ /\ / /| | '_ \| |   / _ \/ _` | '_ \
     \ V  V / | | | | | |__|  __/ (_| | | | |
      \_/\_/  |_|_| |_|_____\___|\__,_|_| |_|
```

**Windows 10/11 debloat, privacy and performance — with a Rust interface and a real rollback.**

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell/)
[![Rust](https://img.shields.io/badge/Rust-TUI-000000?logo=rust&logoColor=white)](ui/)
[![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D6?logo=windows&logoColor=white)](#compatibility)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

🇧🇷 [Versão em português](README.md) *(default)*

</div>

---

## One-line install

Open **Terminal as Administrator** (right-click Start → Terminal (Admin)) and paste:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/isaacoolibama/WinLean/main/install.ps1))) -Lang en
```

The installer downloads everything to `%LOCALAPPDATA%\WinLean`, creates a Start menu shortcut and opens the interface. Nothing is written to `Program Files` and nothing keeps running afterwards.

Other flags: `-NoLaunch` (install only), `-Cli` (skip the Rust interface), `-Force` (re-download everything).

---

## Why another debloater?

Most debloat scripts are a list of `reg add` commands with no memory of what they changed. If something breaks a week later, you reinstall Windows.

WinLean is built around three constraints:

| Constraint | How it is enforced |
|---|---|
| **Nothing is irreversible** | Every registry value, service and scheduled task is written to a JSON rollback journal *with its previous state* before the change is applied. `-Revert` replays it backwards. |
| **Windows must stay usable** | Services are set to `Manual`, not `Disabled`, whenever `Disabled` could break printing, VPN, Bluetooth or casting. Search, Defender and Update are never touched. |
| **Optimizations must be real** | Memory Compression stays **on** and Prefetch is **not** deleted. Both are commonly "optimized" by other scripts, and removing them makes low-RAM machines slower. |

---

## Architecture

```
  ┌────────────────────────┐        ┌──────────────────────────────┐
  │  winlean.exe (Rust)    │        │  WinLean.ps1 (engine)        │
  │  ratatui + crossterm   │──exec──▶  all the mutation logic      │
  │  builds the arguments  │◀─pipe──│  structured text output      │
  └────────────────────────┘        └──────────────┬───────────────┘
                                                   │
                                     ┌─────────────▼──────────────┐
                                     │  journal-<date>.json       │
                                     │  previous state of it all  │
                                     └────────────────────────────┘
```

The interface **never changes the system**. It builds a command line and delegates to `WinLean.ps1`, which remains usable on its own. That keeps a single source of truth about what gets modified — and lets you audit the script without reading a line of Rust.

Rust was chosen for weight: the binary is a few hundred KB, starts instantly, needs no installed runtime and leaves no resident process.

---

## The interface

```
 WinLean  v1.1.0  Windows debloat, privacy and performance          APPLY  [EN]
 ───────────────────────────────────────────────────────────────────────────────────
 ┌─ Modules (7/13) ──────────────────┐┌─ Details ───────────────────────────────────┐
 │ [x] Remove bloatware              ││ Services                                    │
 │ [x] Privacy and telemetry         ││                                             │
 │ [x] Copilot, Recall and AI        ││ 27 services retimed, each with its          │
 │ [x] Services                   ◀  ││ justification in the source.                │
 │ [x] Interface                     ││                                             │
 │ [x] Performance and memory        ││ Disabled is used only where there is no     │
 │ [x] Power plan                    ││ legitimate workstation scenario.            │
 │ [ ] Gaming and latency            ││                                             │
 │ [x] Disk cleanup                  ││ Never touched: Search, Spooler, Windows     │
 │ [ ]   Low-end mode (<= 8 GB)      ││ Update, Defender, Audio, Bluetooth.         │
 │ [ ]   Classic context menu        ││                                             │
 │ [ ]   Disable Fast Startup        ││ Power plan: Auto                            │
 │ [ ]   GPU scheduling (HAGS)       ││                                             │
 └───────────────────────────────────┘└─────────────────────────────────────────────┘
 ───────────────────────────────────────────────────────────────────────────────────
  Up/Dn navigate   Space toggle   1-4 presets   P power   D dry run   S START
```

### Shortcuts

| Key | Action |
|---|---|
| `↑` `↓` / `j` `k` | Navigate |
| `Space` / `Enter` | Toggle |
| `1` `2` `3` `4` | Minimal, Work, Gaming, Full presets |
| `P` | Choose the power plan |
| `D` | Toggle dry run |
| `L` / `F2` | Switch Portuguese and English |
| `A` | Select or clear everything |
| `R` | Roll back the last run |
| `S` / `F5` | Start |
| `PgUp` `PgDn` | Scroll the log while running |
| `?` / `F1` | Help |
| `Q` / `Esc` | Quit |

The language switches live and is passed on to the engine via `-Language`.

---

## Presets

| Preset | What it does | Power plan |
|---|---|---|
| **Minimal** | Telemetry, tracking and AI policies only. No UI or app changes. | Keep |
| **Work** | Bloatware, telemetry, AI, services, interface, performance, cleanup | Auto |
| **Gaming** | Everything in Work **+** GameDVR off, Game Mode on, MMCSS, network throttling off | Ultimate |
| **Full** | Everything, plus low-end mode, classic menu and Fast Startup disabled | Ultimate |

---

## Power plans

Selectable with `P` in the interface or with `-PowerPlan` on the command line.

| Option | Description |
|---|---|
| **Keep** | Leaves everything power-related untouched |
| **Auto** | Desktops get Ultimate Performance, laptops stay on Balanced |
| **Balanced** | Windows default. Scales frequency with load |
| **High performance** | Keeps the CPU at high clocks. More power and heat |
| **Ultimate performance** | Removes power-management micro-latencies |
| **Power saver** | Prioritizes battery, noticeably reduces performance |

Two details the script handles for you:

- **Ultimate Performance ships hidden** in Windows. The script duplicates the scheme before activating it and **verifies the hardware accepted it** — many laptops refuse this plan. If refused, nothing is changed and you are told, instead of the script claiming success.
- On desktops, **USB selective suspend** is also turned off. It is a classic cause of peripherals dropping out.

---

## Modules

<details>
<summary><b>1. Bloatware removal</b></summary>

Removes ~70 UWP packages for the current user **and** deprovisions them so new profiles start clean. Includes Copilot, Widgets, the new Outlook, Teams, Bing apps, Phone Link, Clipchamp, DevHome and the usual OEM shovelware.

A hard-coded **protected list** guarantees the Microsoft Store, winget, Terminal, Calculator, Notepad, Paint, Snipping Tool, Photos, Camera, Windows Security, media codecs and `Microsoft.XboxIdentityProvider` (required by many PC games) are never removed — even if a wildcard would match them.
</details>

<details>
<summary><b>2. Privacy and telemetry</b></summary>

- `AllowTelemetry = 0` on both policy paths
- Advertising ID, tailored experiences, activity history and timeline upload off
- 19 `ContentDeliveryManager` suggestion/ad keys zeroed
- Typing, inking and contact-harvesting personalization off
- Windows Error Reporting off
- `DiagTrack` and `dmwappushservice` disabled; WER, PcaSvc, MapsBroker set to Manual
- 21 telemetry scheduled tasks disabled
</details>

<details>
<summary><b>3. Copilot, Recall and Windows AI</b></summary>

`TurnOffWindowsCopilot` on both machine and user policies. Under `WindowsAI`: `DisableAIDataAnalysis`, `AllowRecallEnablement=0`, `TurnOffSavingSnapshots`, `DisableClickToDo`, plus Paint Cocreator, Image Creator and generative fill.

Edge AI is handled separately because **Edge 141+ decoupled it from the OS Copilot**: sidebar, page context, Compose and shopping assistant disabled by policy.
</details>

<details>
<summary><b>4. Services</b></summary>

27 services retimed, each with an explicit justification in the source. `Disabled` is used only where there is no legitimate workstation scenario (AllJoyn router, Fax, RRAS, Retail Demo, telemetry).

Also sets `SvcHostSplitThresholdInKB` to the installed RAM. Above 3.5 GB, Windows isolates every service into its own `svchost.exe`; raising the threshold re-groups them and visibly cuts the process count.

Never touched: **Windows Search, Print Spooler, Windows Update, Defender, Audio, Bluetooth, Themes, BITS, iphlpsvc, Netlogon**. On domain-joined machines, Remote Registry and Offline Files are skipped too.
</details>

<details>
<summary><b>5. Interface</b></summary>

File extensions visible, Explorer opens on *This PC*, Task View / Widgets / Chat buttons hidden, Start recommendations and account nags off, OneDrive ads off, Bing web results removed from search (four keys — one is not enough), taskbar search shrunk to an icon.
</details>

<details>
<summary><b>6. Performance and memory</b></summary>

Menu delay 400→200 ms, startup app delay removed, shutdown timeouts trimmed, Reserved Storage disabled (~7 GB back).

**Low-end mode** additionally disables transparency, animations and drag-redraw while keeping ClearType on — unreadable text is not an optimization.
</details>

<details>
<summary><b>7. Gaming</b></summary>

GameDVR off (policy + user keys), Game Mode on, `SystemResponsiveness` 20→10, `NetworkThrottlingIndex` off, `Tasks\Games` GPU/CPU/SFIO priorities raised, Nagle disabled on active adapters only.

Xbox services and Xbox Identity Provider are preserved — Game Pass, EA App and launchers keep working.
</details>

<details>
<summary><b>8. Disk cleanup</b></summary>

User and Windows temp, CBS logs, WER queue, DirectX shader cache, crash dumps, Windows Update cache (with the service stopped first), Delivery Optimization and Recycle Bin. The Full preset also runs DISM `/StartComponentCleanup`.

Prefetch is intentionally left alone.
</details>

---

## Rollback

Every run writes `C:\ProgramData\WinLean\backups\journal-<timestamp>.json` containing, for each change, the previous value **and whether the key existed at all** — so the revert removes what WinLean created instead of writing a guessed default back.

From the interface: press `R`. From the command line:

```powershell
& "$env:LOCALAPPDATA\WinLean\WinLean.ps1" -Revert
& "$env:LOCALAPPDATA\WinLean\WinLean.ps1" -Revert -JournalPath "C:\...\journal-20260813-101500.json"
```

A System Restore point is also created before the first change.

### Reverting app removal

Removed UWP apps are **not** reinstalled automatically — the revert writes the list to a text file. Reinstall from the Store, with `winget`, or all at once:

```powershell
Get-AppxPackage -AllUsers | ForEach-Object {
    Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml"
}
```

---

## Command-line usage

The engine works standalone, without the interface:

```powershell
# Preview everything, change nothing
.\WinLean.ps1 -Preset Work -DryRun -Language en

# Unattended, explicit power plan
.\WinLean.ps1 -Preset Gaming -PowerPlan Ultimate -Language en -Silent

# Individual modules
.\WinLean.ps1 -Privacy -DisableAI -Energy -PowerPlan Balanced -Language en
```

| Parameter | Description |
|---|---|
| `-Language pt\|en` | Output language (default: `pt`) |
| `-Preset Minimal\|Work\|Gaming\|Full` | Predefined profile |
| `-PowerPlan Keep\|Auto\|Balanced\|HighPerformance\|Ultimate\|PowerSaver` | Power plan |
| `-RemoveApps -Privacy -DisableAI -Services -Interface -Performance -Energy -Gaming -CleanDisk` | Individual modules |
| `-LowEndMode` `-ClassicContextMenu` `-DisableFastStartup` `-HAGS` `-KeepXbox` | Optional tweaks |
| `-DryRun` | Preview everything, touch nothing |
| `-Silent` | No prompts |
| `-Plain` | Uncolored output, for the interface to consume |
| `-Revert [-JournalPath <file>]` | Roll back a previous run |

---

## Building the interface

```bash
cd ui
cargo build --release
# binary at ui/target/release/winlean.exe
```

Requires Rust 1.74+. The only dependency is `ratatui` (which re-exports `crossterm` at a matching version, avoiding a version clash between the two crates).

---

## Compatibility

| | Status |
|---|---|
| Windows 11 24H2 / 25H2 | Supported |
| Windows 11 22H2 / 23H2 | Supported |
| Windows 10 22H2 | Supported — Win11-only tweaks are skipped automatically |
| Windows 10 / 11 LTSC | Works; most bloat is already absent |
| Windows Server | Not tested |

WinLean detects RAM, SSD vs HDD, laptop vs desktop and domain membership, and adapts: SysMain is only relaxed on SSDs, the power plan follows the form factor, and enterprise-sensitive services are skipped on domain-joined machines.

---

## Files

```
%LOCALAPPDATA%\WinLean\                        installation
C:\ProgramData\WinLean\logs\winlean-*.log      full trace
C:\ProgramData\WinLean\backups\journal-*.json  rollback data
```

---

## Credits

Built after studying the approaches in
[Raphire/Win11Debloat](https://github.com/Raphire/Win11Debloat),
[ChrisTitusTech/winutil](https://github.com/ChrisTitusTech/winutil) and
[zoicware/RemoveWindowsAI](https://github.com/zoicware/RemoveWindowsAI).
The journal-based rollback engine, the Rust interface, the protected-app guard and
the hardware-adaptive logic are original to this project.

---

## Disclaimer

WinLean modifies system settings, services and installed applications. It is provided **as is**, without warranty of any kind. Read the source, run a dry run first, and keep a backup. You are responsible for what you run on your machine.

## License

[MIT](LICENSE) — Isaac Oolibama R. Lacerda
