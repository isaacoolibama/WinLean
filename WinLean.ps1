<#
.SYNOPSIS
    WinLean - Debloat, privacidade e performance para Windows 10/11.
    WinLean - Windows 10/11 debloat, privacy and performance toolkit.

.DESCRIPTION
    PT: Motor em arquivo unico. Remove bloatware, corta telemetria, ajusta servicos,
        limpa a interface, libera RAM e disco e aplica tweaks de jogos - mantendo o
        Windows funcional. Toda alteracao vai para um journal JSON reversivel.

    EN: Single-file engine. Removes bloatware, disables telemetry, tunes services,
        cleans the interface, frees RAM and disk and applies gaming tweaks - while
        keeping Windows functional. Every change is written to a reversible journal.

    Principios / Principles:
      1. Nada e aplicado sem antes ser gravado no journal de rollback.
      2. Servicos vao para Manual em vez de Disabled sempre que desabilitar puder
         quebrar impressao, VPN, Bluetooth, projecao ou Windows Update.
      3. Memory Compression continua ligada e o Prefetch nao e apagado.

.PARAMETER Language
    pt (padrao) ou en. Define o idioma de toda a saida.

.PARAMETER Preset
    Minimal | Work | Gaming | Full

.PARAMETER PowerPlan
    Keep | Balanced | HighPerformance | Ultimate | PowerSaver | Auto
    Auto = Ultimate em desktop, Balanced em notebook.

.EXAMPLE
    .\WinLean.ps1 -Preset Work -DryRun

.EXAMPLE
    .\WinLean.ps1 -Preset Gaming -PowerPlan Ultimate -Silent

.EXAMPLE
    .\WinLean.ps1 -Revert

.NOTES
    Autor  : Isaac Oolibama R. Lacerda
    Licenca: MIT
    Repo   : https://github.com/isaacoolibama/WinLean
#>

[CmdletBinding(DefaultParameterSetName = 'Apply')]
param(
    [ValidateSet('pt', 'en')]
    [string]$Language = 'pt',

    [Parameter(ParameterSetName = 'Apply')]
    [ValidateSet('Minimal', 'Work', 'Gaming', 'Full')]
    [string]$Preset,

    [Parameter(ParameterSetName = 'Apply')]
    [ValidateSet('Keep', 'Balanced', 'HighPerformance', 'Ultimate', 'PowerSaver', 'Auto')]
    [string]$PowerPlan = 'Keep',

    [Parameter(ParameterSetName = 'Apply')][switch]$RemoveApps,
    [Parameter(ParameterSetName = 'Apply')][switch]$Privacy,
    [Parameter(ParameterSetName = 'Apply')][switch]$DisableAI,
    [Parameter(ParameterSetName = 'Apply')][switch]$Services,
    [Parameter(ParameterSetName = 'Apply')][switch]$Interface,
    [Parameter(ParameterSetName = 'Apply')][switch]$Performance,
    [Parameter(ParameterSetName = 'Apply')][switch]$Gaming,
    [Parameter(ParameterSetName = 'Apply')][switch]$CleanDisk,
    [Parameter(ParameterSetName = 'Apply')][switch]$Energy,

    [Parameter(ParameterSetName = 'Apply')][switch]$ClassicContextMenu,
    [Parameter(ParameterSetName = 'Apply')][switch]$DisableFastStartup,
    [Parameter(ParameterSetName = 'Apply')][switch]$LowEndMode,
    [Parameter(ParameterSetName = 'Apply')][switch]$HAGS,
    [Parameter(ParameterSetName = 'Apply')][switch]$KeepXbox,
    [Parameter(ParameterSetName = 'Apply')][switch]$NoRestorePoint,

    [Parameter(ParameterSetName = 'Revert')][switch]$Revert,
    [Parameter(ParameterSetName = 'Revert')][string]$JournalPath,

    [switch]$DryRun,
    [switch]$Silent,

    # Saida sem cor e sem banner, para ser consumida pela interface Rust.
    # Plain, uncolored output meant to be consumed by the Rust front-end.
    [switch]$Plain
)

#Requires -Version 5.1

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

# UTF-8 garante que os acentos cheguem intactos ao pipe lido pela TUI.
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }

# ==============================================================================
#  GLOBAIS / GLOBALS
# ==============================================================================

$script:Version     = '1.3.0'
$script:Lang        = $Language
$script:RootDir     = Join-Path $env:ProgramData 'WinLean'
$script:BackupDir   = Join-Path $script:RootDir 'backups'
$script:LogDir      = Join-Path $script:RootDir 'logs'
$script:Stamp       = Get-Date -Format 'yyyyMMdd-HHmmss'
$script:LogFile     = Join-Path $script:LogDir  "winlean-$($script:Stamp).log"
$script:JournalFile = Join-Path $script:BackupDir "journal-$($script:Stamp).json"
$script:Journal     = [System.Collections.Generic.List[object]]::new()
$script:Stats       = [ordered]@{ Apps = 0; Registry = 0; Services = 0; Tasks = 0; TasksSkipped = 0; DiskFreedMB = 0; Errors = 0 }
$script:IsDomain    = $false
$script:IsLaptop    = $false
$script:HasSSD      = $false
$script:RamGB       = 0
$script:Build       = 0
$script:OSName      = ''

# ==============================================================================
#  I18N
# ==============================================================================

<#
    Convencao: toda string visivel ao usuario e escrita como 'portugues|english'.
    Resolve-Text corta no pipe e devolve o idioma ativo. Isso mantem cada
    mensagem em uma unica linha, junto do codigo que a produz, em vez de espalhar
    a traducao por um dicionario distante.

    Convention: every user-facing string is written as 'portugues|english'.
    Resolve-Text splits on the pipe and returns the active language, keeping each
    message on one line next to the code that produces it.
#>
function Resolve-Text {
    param([AllowEmptyString()][AllowNull()][string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return '' }
    if ($Text -notmatch '\|') { return $Text }
    $parts = $Text -split '\|', 2
    if ($script:Lang -eq 'en') { return $parts[1].Trim() }
    return $parts[0].Trim()
}
Set-Alias T Resolve-Text

# ==============================================================================
#  SAIDA / OUTPUT
# ==============================================================================

function Write-Log {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Message,
        [ValidateSet('INFO', 'OK', 'WARN', 'ERROR', 'STEP', 'DRY')][string]$Level = 'INFO',
        [switch]$NoConsole
    )

    $msg  = Resolve-Text $Message
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'HH:mm:ss'), $Level.PadRight(5), $msg
    try { Add-Content -Path $script:LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue } catch { }

    if ($NoConsole) { return }

    $tags = @{ INFO = '  '; OK = ' +'; WARN = ' !'; ERROR = ' x'; STEP = '=='; DRY = ' ~' }
    $text = '{0} {1}' -f $tags[$Level], $msg

    if ($Plain) { Write-Output $text; return }

    $colors = @{ INFO = 'Gray'; OK = 'Green'; WARN = 'Yellow'; ERROR = 'Red'; STEP = 'Cyan'; DRY = 'DarkGray' }
    Write-Host $text -ForegroundColor $colors[$Level]
}

function Write-Section {
    param([string]$Title)
    $t = Resolve-Text $Title
    if ($Plain) {
        Write-Output ''
        Write-Output "== $t"
        return
    }
    Write-Host ''
    Write-Host ('  ' + ('-' * 68)) -ForegroundColor DarkCyan
    Write-Host "  $t" -ForegroundColor Cyan
    Write-Host ('  ' + ('-' * 68)) -ForegroundColor DarkCyan
    Write-Log -Message "SECTION: $t" -Level STEP -NoConsole
}

function Show-Banner {
    if ($Plain) { return }
    Clear-Host
    # Here-string com aspas simples: a arte ASCII contem crase, que seria
    # interpretada como caractere de escape em here-string de aspas duplas.
    $b = @'

   __        ___       _
   \ \      / (_)_ __ | |    ___  __ _ _ __
    \ \ /\ / /| | '_ \| |   / _ \/ _` | '_ \
     \ V  V / | | | | | |__|  __/ (_| | | | |
      \_/\_/  |_|_| |_|_____\___|\__,_|_| |_|
'@
    Write-Host $b -ForegroundColor Cyan
    Write-Host "   v$($script:Version) - $(T 'debloat, privacidade e performance|debloat, privacy and performance')" -ForegroundColor DarkCyan
    Write-Host "   $(T 'Reversivel por design: toda alteracao e registrada.|Reversible by design: every change is journaled.')" -ForegroundColor DarkGray
    Write-Host ''
}

# ==============================================================================
#  AMBIENTE / ENVIRONMENT
# ==============================================================================

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $id).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Initialize-Environment {
    foreach ($d in @($script:RootDir, $script:BackupDir, $script:LogDir)) {
        if (-not (Test-Path $d)) { New-Item -Path $d -ItemType Directory -Force | Out-Null }
    }

    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem

    $script:OSName   = $os.Caption
    $script:Build    = [int]$os.BuildNumber
    $script:RamGB    = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
    $script:IsDomain = $cs.PartOfDomain

    # Chassis 8-14, 18, 21 e 30-32 sao formatos portateis.
    try {
        $chassis = (Get-CimInstance Win32_SystemEnclosure).ChassisTypes
        $hit = @(8, 9, 10, 11, 12, 14, 18, 21, 30, 31, 32) | Where-Object { $chassis -contains $_ } | Select-Object -First 1
        $script:IsLaptop = [bool]$hit
    } catch { $script:IsLaptop = $false }

    try {
        $sysLetter = $env:SystemDrive.TrimEnd(':')
        $part = Get-Partition -DriveLetter $sysLetter -ErrorAction Stop
        $num  = (Get-Disk -Number $part.DiskNumber).Number
        $disk = Get-PhysicalDisk -ErrorAction Stop | Where-Object { $_.DeviceId -eq $num }
        $script:HasSSD = ($disk.MediaType -eq 'SSD') -or ($disk.MediaType -eq 4)
    } catch { $script:HasSSD = $true }  # assume SSD: o padrao mais seguro para os ajustes
}

function Show-SystemInfo {
    Write-Section 'Sistema detectado|System detected'
    Write-Log "$(T 'Sistema     |OS          '): $($script:OSName) (build $($script:Build))"
    Write-Log "$(T 'Memoria     |RAM         '): $($script:RamGB) GB"
    Write-Log "$(T 'Formato     |Form factor '): $(if ($script:IsLaptop) { T 'Notebook|Laptop' } else { T 'Desktop|Desktop' })"
    Write-Log "$(T 'Disco       |System disk '): $(if ($script:HasSSD) { 'SSD / NVMe' } else { 'HDD' })"
    Write-Log "$(T 'Dominio     |Domain      '): $(if ($script:IsDomain) { T 'SIM|YES' } else { T 'Nao (workgroup)|No (workgroup)' })"
    Write-Log "$(T 'Usuario     |User        '): $env:USERNAME"
    if ($script:IsDomain) {
        Write-Log 'Maquina em dominio: Netlogon, Arquivos Offline e Registro Remoto nao serao tocados.|Domain-joined machine: Netlogon, Offline Files and Remote Registry are left untouched.' -Level WARN
    }
}

# ==============================================================================
#  JOURNAL / ROLLBACK
# ==============================================================================

function Add-JournalEntry {
    param([Parameter(Mandatory)][hashtable]$Entry)
    $Entry['Timestamp'] = (Get-Date).ToString('o')
    $script:Journal.Add([pscustomobject]$Entry)
}

function Save-Journal {
    if ($script:Journal.Count -eq 0 -or $DryRun) { return }
    $payload = [pscustomobject]@{
        Version   = $script:Version
        CreatedAt = (Get-Date).ToString('o')
        Computer  = $env:COMPUTERNAME
        User      = $env:USERNAME
        OS        = $script:OSName
        Build     = $script:Build
        Changes   = $script:Journal
    }
    $payload | ConvertTo-Json -Depth 6 | Set-Content -Path $script:JournalFile -Encoding UTF8
    Write-Log "$(T 'Journal de rollback salvo|Rollback journal saved'): $($script:JournalFile)" -Level OK
}

<#
    Grava um valor de registro guardando o estado anterior. Chaves inexistentes
    sao criadas; valores inexistentes sao marcados como tal, para que o revert
    os REMOVA em vez de escrever um padrao chutado.

    Writes a registry value while recording the previous state. Missing values are
    flagged so the revert removes them instead of writing a guessed default back.
#>
function Set-RegValue {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][AllowEmptyString()][AllowNull()]$Value,
        [ValidateSet('DWord', 'QWord', 'String', 'ExpandString', 'Binary', 'MultiString')]
        [string]$Type = 'DWord',
        [string]$Description
    )

    $label = if ($Description) { Resolve-Text $Description } else { "$Path\$Name" }

    if ($DryRun) {
        Write-Log "$label  ->  $Path\$Name = $Value" -Level DRY
        $script:Stats.Registry++
        return
    }

    try {
        $keyExisted = Test-Path $Path
        if (-not $keyExisted) { New-Item -Path $Path -Force | Out-Null }

        $old = $null; $oldType = $null; $valExists = $false
        if ($keyExisted) {
            $prop = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
            if ($null -ne $prop -and $null -ne $prop.$Name) {
                $valExists = $true
                $old       = $prop.$Name
                try { $oldType = (Get-Item $Path).GetValueKind($Name).ToString() } catch { $oldType = $Type }
            }
        }

        if ($valExists -and ("$old" -eq "$Value")) { return }

        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null

        Add-JournalEntry @{
            Type = 'Registry'; Path = $Path; Name = $Name; NewValue = $Value
            OldValue = $old; OldType = $oldType; ValueExisted = $valExists
            KeyExisted = $keyExisted; Description = $label
        }
        $script:Stats.Registry++
        Write-Log $label -Level OK
    } catch {
        $script:Stats.Errors++
        Write-Log "$(T 'falha no registro|registry failed') [$Path\$Name]: $($_.Exception.Message)" -Level ERROR
    }
}

function Set-ServiceStartup {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('Automatic', 'Manual', 'Disabled')][string]$Startup,
        [string]$Reason
    )

    $why = Resolve-Text $Reason

    # Servicos por usuario carregam sufixo aleatorio (ex.: OneSyncSvc_3f2a1).
    # Resolvemos pelo template para que a mudanca valha em toda sessao.
    $targets = @()
    if ($Name -like '*_TEMPLATE') {
        $base = $Name -replace '_TEMPLATE$', ''
        $targets += (Get-Service -Name "$base*" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
        $tmpl = "HKLM:\SYSTEM\CurrentControlSet\Services\$base"
        if (Test-Path $tmpl) {
            $startVal = @{ Automatic = 2; Manual = 3; Disabled = 4 }[$Startup]
            Set-RegValue -Path $tmpl -Name 'Start' -Value $startVal -Type DWord -Description "template $base -> $Startup"
        }
    } else {
        $targets += $Name
    }

    foreach ($svcName in ($targets | Sort-Object -Unique)) {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if (-not $svc) { continue }

        if ($DryRun) {
            Write-Log "$svcName -> $Startup   ($why)" -Level DRY
            $script:Stats.Services++
            continue
        }

        try {
            $current    = (Get-CimInstance Win32_Service -Filter "Name='$svcName'" -ErrorAction SilentlyContinue).StartMode
            $normalized = switch ($current) { 'Auto' { 'Automatic' } 'Boot' { 'Automatic' } 'System' { 'Automatic' } default { $current } }
            if ($normalized -eq $Startup) { continue }

            Set-Service -Name $svcName -StartupType $Startup -ErrorAction Stop
            if ($Startup -eq 'Disabled' -and $svc.Status -eq 'Running') {
                Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
            }

            Add-JournalEntry @{
                Type = 'Service'; Name = $svcName; NewStartup = $Startup
                OldStartup = $normalized; WasRunning = ($svc.Status -eq 'Running'); Description = $why
            }
            $script:Stats.Services++
            Write-Log "$svcName -> $Startup   ($why)" -Level OK
        } catch {
            $script:Stats.Errors++
            Write-Log "$(T 'servico|service') '$svcName': $($_.Exception.Message)" -Level WARN
        }
    }
}

function Disable-Task {
    param([Parameter(Mandatory)][string]$TaskPath, [Parameter(Mandatory)][string]$TaskName)
    try {
        $task = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue
        if (-not $task) { $script:Stats.TasksSkipped++; return }
        if ($task.State -eq 'Disabled') { return }

        if ($DryRun) {
            Write-Log "$(T 'tarefa|task'): $TaskName" -Level DRY
            $script:Stats.Tasks++
            return
        }

        Disable-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction Stop | Out-Null
        Add-JournalEntry @{ Type = 'ScheduledTask'; TaskPath = $TaskPath; TaskName = $TaskName; OldState = $task.State.ToString() }
        $script:Stats.Tasks++
        Write-Log "$(T 'tarefa desativada|task disabled'): $TaskName" -Level OK
    } catch {
        $script:Stats.Errors++
        Write-Log "$(T 'tarefa|task') '$TaskName': $($_.Exception.Message)" -Level WARN
    }
}

function New-RestorePoint {
    if ($NoRestorePoint -or $DryRun) { return }
    Write-Section 'Ponto de restauracao|System Restore point'
    try {
        Enable-ComputerRestore -Drive $env:SystemDrive -ErrorAction SilentlyContinue

        # O Windows limita a um ponto por 24h. Suspendemos o limite so nesta execucao.
        $srKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'
        $prev  = (Get-ItemProperty -Path $srKey -Name 'SystemRestorePointCreationFrequency' -ErrorAction SilentlyContinue).SystemRestorePointCreationFrequency
        New-ItemProperty -Path $srKey -Name 'SystemRestorePointCreationFrequency' -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null

        Write-Log 'Criando ponto de restauracao (pode levar um minuto)...|Creating restore point (this can take a minute)...'
        Checkpoint-Computer -Description "WinLean $($script:Version) - $($script:Stamp)" -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
        Write-Log 'Ponto de restauracao criado.|Restore point created.' -Level OK

        if ($null -ne $prev) {
            New-ItemProperty -Path $srKey -Name 'SystemRestorePointCreationFrequency' -Value $prev -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
        }
    } catch {
        Write-Log "$(T 'Nao foi possivel criar o ponto de restauracao|Restore point could not be created'): $($_.Exception.Message)" -Level WARN
        Write-Log 'O journal de rollback continua cobrindo toda alteracao feita pelo script.|The rollback journal still covers every change made by this script.' -Level INFO
    }
}

function Invoke-Revert {
    if (-not $Plain) { Show-Banner }
    Write-Section 'Rollback'

    if (-not $JournalPath) {
        $latest = Get-ChildItem -Path $script:BackupDir -Filter 'journal-*.json' -ErrorAction SilentlyContinue |
                  Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if (-not $latest) { Write-Log 'Nenhum journal encontrado.|No journal found.' -Level ERROR; return }
        $JournalPath = $latest.FullName
    }
    if (-not (Test-Path $JournalPath)) { Write-Log "Journal: $JournalPath" -Level ERROR; return }

    $data = Get-Content $JournalPath -Raw | ConvertFrom-Json
    Write-Log "Journal      : $JournalPath"
    Write-Log "$(T 'Criado em    |Created at   '): $($data.CreatedAt)"
    Write-Log "$(T 'Alteracoes   |Changes      '): $($data.Changes.Count)"

    if (-not $Silent) {
        $ans = Read-Host (T '  Restaurar todas estas alteracoes? (s/N)|  Restore all of these changes? (y/N)')
        if ($ans -notmatch '^[yYsS]') { Write-Log 'Cancelado.|Cancelled.' -Level WARN; return }
    }

    $done = 0; $fail = 0
    # Ordem inversa para que mudancas dependentes desfacam-se limpo.
    for ($i = $data.Changes.Count - 1; $i -ge 0; $i--) {
        $c = $data.Changes[$i]
        try {
            switch ($c.Type) {
                'Registry' {
                    if ($c.ValueExisted) {
                        $t = if ($c.OldType) { $c.OldType } else { 'DWord' }
                        New-ItemProperty -Path $c.Path -Name $c.Name -Value $c.OldValue -PropertyType $t -Force -ErrorAction Stop | Out-Null
                    } else {
                        Remove-ItemProperty -Path $c.Path -Name $c.Name -Force -ErrorAction SilentlyContinue
                        if (-not $c.KeyExisted) {
                            $k = Get-Item $c.Path -ErrorAction SilentlyContinue
                            if ($k -and $k.ValueCount -eq 0 -and $k.SubKeyCount -eq 0) {
                                Remove-Item $c.Path -Force -ErrorAction SilentlyContinue
                            }
                        }
                    }
                }
                'Service' {
                    if ($c.OldStartup) { Set-Service -Name $c.Name -StartupType $c.OldStartup -ErrorAction Stop }
                    if ($c.WasRunning) { Start-Service -Name $c.Name -ErrorAction SilentlyContinue }
                }
                'ScheduledTask' { Enable-ScheduledTask -TaskPath $c.TaskPath -TaskName $c.TaskName -ErrorAction Stop | Out-Null }
                'PowerPlan'     { powercfg /setactive $c.OldGuid 2>$null }
                'ReservedStorage' { Set-WindowsReservedStorageState -State Enabled -ErrorAction SilentlyContinue | Out-Null }
                'AppRemoved'    { }  # ver README: apps nao voltam sozinhos
            }
            $done++
        } catch { $fail++ }
    }

    Write-Log "$(T 'Restaurado|Restored'): $done   $(T 'Falhou|Failed'): $fail" -Level OK

    $apps = @($data.Changes | Where-Object { $_.Type -eq 'AppRemoved' })
    if ($apps.Count -gt 0) {
        Write-Log "$($apps.Count) $(T 'apps foram removidos e NAO sao reinstalados automaticamente.|apps were removed and are NOT reinstalled automatically.')" -Level WARN
        $listFile = Join-Path $script:BackupDir "removed-apps-$($script:Stamp).txt"
        $apps.Name | Set-Content $listFile -Encoding UTF8
        Write-Log "$(T 'Lista salva em|List saved to'): $listFile" -Level INFO
    }
    Write-Log 'Reinicie o PC para concluir o rollback.|Restart your PC to complete the rollback.' -Level WARN
}

# ==============================================================================
#  MODULO 1 - BLOATWARE
# ==============================================================================

# Nunca removidos, mesmo que um curinga os alcance.
$script:ProtectedApps = @(
    'Microsoft.WindowsStore', 'Microsoft.DesktopAppInstaller', 'Microsoft.WindowsTerminal'
    'Microsoft.SecHealthUI', 'Microsoft.WindowsNotepad', 'Microsoft.Paint', 'Microsoft.ScreenSketch'
    'Microsoft.WindowsCalculator', 'Microsoft.Windows.Photos', 'Microsoft.WindowsCamera'
    'Microsoft.VCLibs', 'Microsoft.NET', 'Microsoft.UI.Xaml', 'Microsoft.WindowsAppRuntime'
    'Microsoft.WebpImageExtension', 'Microsoft.HEIFImageExtension', 'Microsoft.RawImageExtension'
    'Microsoft.AV1VideoExtension', 'Microsoft.HEVCVideoExtension', 'Microsoft.VP9VideoExtensions'
    'Microsoft.WebMediaExtensions', 'Microsoft.StorePurchaseApp'
    'Microsoft.XboxIdentityProvider'          # exigido por muitos jogos de PC
    'Microsoft.Windows.ShellExperienceHost', 'Microsoft.Windows.StartMenuExperienceHost'
    'Microsoft.AAD.BrokerPlugin', 'Microsoft.AccountsControl', 'Microsoft.CredDialogHost'
    'Microsoft.LockApp', 'Microsoft.Win32WebViewHost', 'Microsoft.Windows.CloudExperienceHost'
    'Microsoft.Windows.ContentDeliveryManager', 'Microsoft.Windows.SecureAssessmentBrowser'
    'Windows.CBSPreview', 'Windows.PrintDialog', 'Windows.immersivecontrolpanel'
    'NcsiUwpApp', 'MicrosoftWindows.Client.CBS', 'MicrosoftWindows.UndockedDevKit'
)

$script:BloatApps = @(
    'Microsoft.3DBuilder', 'Microsoft.549981C3F5F10', 'Microsoft.BingFinance'
    'Microsoft.BingFoodAndDrink', 'Microsoft.BingHealthAndFitness', 'Microsoft.BingNews'
    'Microsoft.BingSearch', 'Microsoft.BingSports', 'Microsoft.BingTranslator'
    'Microsoft.BingTravel', 'Microsoft.BingWeather', 'Microsoft.Copilot'
    'Microsoft.Windows.Ai.Copilot.Provider', 'MicrosoftWindows.Client.CoPilot'
    'Microsoft.GetHelp', 'Microsoft.Getstarted', 'Microsoft.Messaging'
    'Microsoft.Microsoft3DViewer', 'Microsoft.MicrosoftJournal', 'Microsoft.MicrosoftOfficeHub'
    'Microsoft.MicrosoftPowerBIForWindows', 'Microsoft.MicrosoftSolitaireCollection'
    'Microsoft.MixedReality.Portal', 'Microsoft.NetworkSpeedTest', 'Microsoft.News'
    'Microsoft.Office.OneNote', 'Microsoft.Office.Sway', 'Microsoft.OneConnect'
    'Microsoft.OutlookForWindows', 'Microsoft.People', 'Microsoft.PowerAutomateDesktop'
    'Microsoft.Print3D', 'Microsoft.SkypeApp', 'Microsoft.Todos', 'Microsoft.Wallet'
    'Microsoft.WindowsAlarms', 'Microsoft.WindowsFeedbackHub', 'Microsoft.WindowsMaps'
    'Microsoft.WindowsSoundRecorder', 'Microsoft.YourPhone', 'Microsoft.ZuneVideo'
    'Microsoft.Windows.DevHome', 'MicrosoftCorporationII.MicrosoftFamily'
    'MicrosoftCorporationII.QuickAssist', 'MicrosoftTeams', 'MSTeams', 'Clipchamp.Clipchamp'
    'MicrosoftWindows.Client.WebExperience', 'Microsoft.Windows.PeopleExperienceHost'
    'Microsoft.MicrosoftEdgeDevToolsClient'
    # OEM / parceiros
    '*ActiproSoftware*', '*AdobeSystemsIncorporated.AdobePhotoshopExpress*', '*Amazon.com.Amazon*'
    '*AmazonVideo.PrimeVideo*', '*BubbleWitch*', '*CandyCrush*', '*COOKINGFEVER*', '*Disney*'
    '*Dolby*', '*Duolingo*', '*EclipseManager*', '*Facebook*', '*FarmHeroes*', '*Flipboard*'
    '*HiddenCity*', '*Hulu*', '*Instagram*', '*LinkedIn*', '*MarchofEmpires*', '*Netflix*'
    '*PandoraMedia*', '*Plex*', '*RoyalRevolt*', '*Sidia.LiveWallpaper*', '*SlingTV*'
    '*Speed*Test*', '*Spotify*', '*TikTok*', '*Twitter*', '*Viber*', '*WhatsApp*'
    '*Wunderlist*', '*king.com*'
)

$script:XboxApps = @(
    'Microsoft.GamingApp', 'Microsoft.XboxApp', 'Microsoft.XboxGameOverlay'
    'Microsoft.XboxGamingOverlay', 'Microsoft.XboxSpeechToTextOverlay', 'Microsoft.Xbox.TCUI'
)

function Invoke-RemoveApps {
    Write-Section 'Removendo bloatware pre-instalado|Removing pre-installed bloatware'

    $list = @($script:BloatApps)
    if ($KeepXbox -or $Gaming) {
        Write-Log 'Stack Xbox / Game Bar preservada (perfil de jogos).|Xbox / Game Bar stack preserved (gaming profile).' -Level INFO
    } else {
        $list += $script:XboxApps
    }

    $installed   = @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue)
    $provisioned = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue)

    foreach ($pattern in $list) {
        foreach ($pkg in @($installed | Where-Object { $_.Name -like $pattern })) {
            if ($script:ProtectedApps | Where-Object { $pkg.Name -like "$_*" }) { continue }
            if ($pkg.NonRemovable) { continue }

            if ($DryRun) { Write-Log "$(T 'remover app|remove app'): $($pkg.Name)" -Level DRY; $script:Stats.Apps++; continue }

            try {
                Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
                Add-JournalEntry @{ Type = 'AppRemoved'; Name = $pkg.Name; PackageFullName = $pkg.PackageFullName }
                $script:Stats.Apps++
                Write-Log "$(T 'removido|removed'): $($pkg.Name)" -Level OK
            } catch {
                Write-Log "$($pkg.Name): $($_.Exception.Message.Split([Environment]::NewLine)[0])" -Level WARN
            }
        }

        # Remove tambem o pacote provisionado, para novos perfis nascerem limpos.
        foreach ($prov in @($provisioned | Where-Object { $_.DisplayName -like $pattern })) {
            if ($script:ProtectedApps | Where-Object { $prov.DisplayName -like "$_*" }) { continue }
            if ($DryRun) { continue }
            try { Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction Stop | Out-Null } catch { }
        }
    }

    Set-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 1 `
        -Description 'Bloqueia reinstalacao automatica de apps sugeridos|Block automatic reinstall of suggested apps'
}

# ==============================================================================
#  MODULO 2 - PRIVACIDADE E TELEMETRIA
# ==============================================================================

function Invoke-Privacy {
    Write-Section 'Privacidade e telemetria|Privacy and telemetry'

    $pol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows'
    $cv  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion'

    Set-RegValue "$pol\DataCollection" 'AllowTelemetry'                 0 -Description 'Telemetria desativada|Telemetry disabled'
    Set-RegValue "$pol\DataCollection" 'AllowDeviceNameInTelemetry'     0 -Description 'Nao enviar nome do dispositivo|Do not send device name'
    Set-RegValue "$pol\DataCollection" 'DoNotShowFeedbackNotifications' 1 -Description 'Sem pedidos de feedback|No feedback prompts'
    Set-RegValue "$pol\DataCollection" 'LimitDiagnosticLogCollection'   1 -Description 'Limita coleta de logs de diagnostico|Limit diagnostic log collection'
    Set-RegValue "$pol\DataCollection" 'LimitDumpCollection'            1 -Description 'Limita coleta de dumps|Limit crash dump collection'
    Set-RegValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' 'AllowTelemetry' 0 -Description 'Telemetria (caminho secundario)|Telemetry (secondary path)'

    Set-RegValue "$cv\AdvertisingInfo"  'Enabled'                0 -Description 'ID de publicidade off|Advertising ID off'
    Set-RegValue "$pol\AdvertisingInfo" 'DisabledByGroupPolicy'  1 -Description 'ID de publicidade bloqueado por politica|Advertising ID blocked by policy'
    Set-RegValue "$cv\Privacy" 'TailoredExperiencesWithDiagnosticDataEnabled' 0 -Description 'Experiencias personalizadas off|Tailored experiences off'

    Set-RegValue "$pol\System" 'EnableActivityFeed'    0 -Description 'Historico de atividades off|Activity feed off'
    Set-RegValue "$pol\System" 'PublishUserActivities' 0 -Description 'Nao publicar atividades|Do not publish activities'
    Set-RegValue "$pol\System" 'UploadUserActivities'  0 -Description 'Nao enviar atividades|Do not upload activities'

    $cdm = "$cv\ContentDeliveryManager"
    $cdmKeys = @(
        'ContentDeliveryAllowed', 'FeatureManagementEnabled', 'OemPreInstalledAppsEnabled'
        'PreInstalledAppsEnabled', 'PreInstalledAppsEverEnabled', 'SilentInstalledAppsEnabled'
        'SoftLandingEnabled', 'SystemPaneSuggestionsEnabled', 'RotatingLockScreenEnabled'
        'RotatingLockScreenOverlayEnabled', 'SubscribedContent-310093Enabled'
        'SubscribedContent-338387Enabled', 'SubscribedContent-338388Enabled'
        'SubscribedContent-338389Enabled', 'SubscribedContent-338393Enabled'
        'SubscribedContent-353694Enabled', 'SubscribedContent-353696Enabled'
        'SubscribedContent-353698Enabled'
    )
    foreach ($k in $cdmKeys) { Set-RegValue $cdm $k 0 -Description "$(T 'Sugestao/anuncio off|Suggestion/ad off'): $k" }

    Set-RegValue "$pol\CloudContent" 'DisableWindowsConsumerFeatures'     1 -Description 'Recursos de consumidor off|Consumer features off'
    Set-RegValue "$pol\CloudContent" 'DisableCloudOptimizedContent'       1 -Description 'Conteudo otimizado por nuvem off|Cloud optimized content off'
    Set-RegValue "$pol\CloudContent" 'DisableConsumerAccountStateContent' 1 -Description 'Anuncios de estado de conta off|Account state ads off'
    Set-RegValue "$pol\CloudContent" 'DisableSoftLanding'                 1 -Description 'Dicas do Windows off|Windows tips off'

    Set-RegValue 'HKCU:\Software\Microsoft\Input\TIPC' 'Enabled' 0 -Description 'Telemetria de digitacao off|Typing telemetry off'
    Set-RegValue 'HKCU:\Software\Microsoft\InputPersonalization' 'RestrictImplicitTextCollection' 1 -Description 'Sem coleta implicita de texto|No implicit text collection'
    Set-RegValue 'HKCU:\Software\Microsoft\InputPersonalization' 'RestrictImplicitInkCollection'  1 -Description 'Sem coleta implicita de tinta|No implicit ink collection'
    Set-RegValue 'HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore' 'HarvestContacts' 0 -Description 'Nao coletar contatos|Do not harvest contacts'
    Set-RegValue 'HKCU:\Software\Microsoft\Personalization\Settings' 'AcceptedPrivacyPolicy' 0 -Description 'Personalizacao de voz off|Speech personalization off'

    Set-RegValue "$pol\Windows Error Reporting" 'Disabled' 1 -Description 'Relatorio de erros off|Error reporting off'
    Set-RegValue "$cv\Explorer\Advanced" 'Start_TrackProgs' 0 -Description 'Rastreio de apps abertos off|App launch tracking off'

    Set-ServiceStartup 'DiagTrack'        'Disabled' 'Telemetria e experiencias conectadas|Connected User Experiences and Telemetry'
    Set-ServiceStartup 'dmwappushservice' 'Disabled' 'Roteamento de mensagens WAP (telemetria)|WAP push routing (telemetry)'
    Set-ServiceStartup 'diagnosticshub.standardcollector.service' 'Manual' 'Coletor do hub de diagnostico|Diagnostics hub collector'
    Set-ServiceStartup 'diagsvc'          'Manual'   'Execucao de diagnostico|Diagnostic execution service'
    Set-ServiceStartup 'WerSvc'           'Manual'   'Relatorio de erros do Windows|Windows Error Reporting'
    Set-ServiceStartup 'RetailDemo'       'Disabled' 'Modo demonstracao de loja|Retail demo mode'
    Set-ServiceStartup 'WMPNetworkSvc'    'Disabled' 'Compartilhamento de rede do WMP|WMP network sharing'
    Set-ServiceStartup 'MapsBroker'       'Manual'   'Gerenciador de mapas baixados|Downloaded maps manager'
    Set-ServiceStartup 'PcaSvc'           'Manual'   'Assistente de compatibilidade|Program compatibility assistant'
    if (-not $script:IsDomain) {
        Set-ServiceStartup 'RemoteRegistry' 'Disabled' 'Acesso remoto ao registro|Remote registry access'
        Set-ServiceStartup 'CscService'     'Disabled' 'Arquivos Offline|Offline Files'
    }

    $tasks = @(
        @{ P = '\Microsoft\Windows\Application Experience\'; N = 'Microsoft Compatibility Appraiser' }
        @{ P = '\Microsoft\Windows\Application Experience\'; N = 'ProgramDataUpdater' }
        @{ P = '\Microsoft\Windows\Application Experience\'; N = 'StartupAppTask' }
        @{ P = '\Microsoft\Windows\Application Experience\'; N = 'PcaPatchDbTask' }
        @{ P = '\Microsoft\Windows\Application Experience\'; N = 'MareBackup' }
        @{ P = '\Microsoft\Windows\Autochk\';                N = 'Proxy' }
        @{ P = '\Microsoft\Windows\Customer Experience Improvement Program\'; N = 'Consolidator' }
        @{ P = '\Microsoft\Windows\Customer Experience Improvement Program\'; N = 'UsbCeip' }
        @{ P = '\Microsoft\Windows\Customer Experience Improvement Program\'; N = 'KernelCeipTask' }
        @{ P = '\Microsoft\Windows\Customer Experience Improvement Program\'; N = 'Uploader' }
        @{ P = '\Microsoft\Windows\DiskDiagnostic\';          N = 'Microsoft-Windows-DiskDiagnosticDataCollector' }
        @{ P = '\Microsoft\Windows\Feedback\Siuf\';           N = 'DmClient' }
        @{ P = '\Microsoft\Windows\Feedback\Siuf\';           N = 'DmClientOnScenarioDownload' }
        @{ P = '\Microsoft\Windows\Windows Error Reporting\'; N = 'QueueReporting' }
        @{ P = '\Microsoft\Windows\CloudExperienceHost\';     N = 'CreateObjectTask' }
        @{ P = '\Microsoft\Windows\Maps\';                    N = 'MapsToastTask' }
        @{ P = '\Microsoft\Windows\Maps\';                    N = 'MapsUpdateTask' }
        @{ P = '\Microsoft\Windows\Retail Demo\';             N = 'CleanupOfflineContent' }
        @{ P = '\Microsoft\Office\';                          N = 'OfficeTelemetryAgentLogOn' }
        @{ P = '\Microsoft\Office\';                          N = 'OfficeTelemetryAgentFallBack' }
    )
    foreach ($t in $tasks) { Disable-Task -TaskPath $t.P -TaskName $t.N }
}

# ==============================================================================
#  MODULO 3 - COPILOT / RECALL / WINDOWS AI
# ==============================================================================

function Invoke-DisableAI {
    Write-Section 'Copilot, Recall e Windows AI|Copilot, Recall and Windows AI'

    Set-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1 -Description 'Copilot off (politica de maquina)|Copilot off (machine policy)'
    Set-RegValue 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1 -Description 'Copilot off (politica de usuario)|Copilot off (user policy)'

    $ai = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'
    Set-RegValue $ai 'DisableAIDataAnalysis'  1 -Description 'Analise de snapshots do Recall off|Recall snapshot analysis off'
    Set-RegValue $ai 'AllowRecallEnablement'  0 -Description 'Recall nao pode ser ativado|Recall cannot be enabled'
    Set-RegValue $ai 'TurnOffSavingSnapshots' 1 -Description 'Snapshots do Recall bloqueados|Recall snapshots blocked'
    Set-RegValue $ai 'DisableClickToDo'       1 -Description 'Click to Do off|Click to Do off'
    Set-RegValue $ai 'DisableImageCreator'    1 -Description 'Image Creator do Paint off|Paint Image Creator off'
    Set-RegValue $ai 'DisableCocreator'       1 -Description 'Cocreator do Paint off|Paint Cocreator off'
    Set-RegValue $ai 'DisableGenerativeFill'  1 -Description 'Preenchimento generativo off|Generative fill off'
    Set-RegValue $ai 'SetCopilotHardwareKey'  0 -Description 'Tecla Copilot remapeada|Copilot key remapped'
    Set-RegValue 'HKCU:\Software\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis' 1 -Description 'Recall off (politica de usuario)|Recall off (user policy)'
    Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowCopilotButton' 0 -Description 'Botao Copilot oculto|Copilot taskbar button hidden'

    # A IA do Edge e tratada a parte: o Edge 141+ desacoplou-a do Copilot do sistema.
    $edge = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
    Set-RegValue $edge 'HubsSidebarEnabled'           0 -Description 'Sidebar do Edge off|Edge sidebar off'
    Set-RegValue $edge 'CopilotPageContext'           0 -Description 'Contexto de pagina do Copilot off|Edge Copilot page context off'
    Set-RegValue $edge 'ComposeInlineEnabled'         0 -Description 'Compose do Edge off|Edge Compose AI off'
    Set-RegValue $edge 'EdgeShoppingAssistantEnabled' 0 -Description 'Assistente de compras off|Shopping assistant off'
    Set-RegValue $edge 'ShowRecommendationsEnabled'   0 -Description 'Recomendacoes do Edge off|Edge recommendations off'

    Set-ServiceStartup 'WSAIFabricSvc' 'Disabled' 'Servico de fabric do Windows AI|Windows AI fabric service'
}

# ==============================================================================
#  MODULO 4 - SERVICOS
# ==============================================================================

<#
    Criterio: Disabled apenas onde nao existe cenario legitimo em estacao de
    trabalho. Manual quando o Windows pode iniciar sob demanda.
    Nunca tocados: WSearch, Spooler, Themes, Audio, BITS, wuauserv, WinDefend,
    Bluetooth, iphlpsvc, Netlogon, TabletInputService, WpnService.
#>
$script:ServicePlan = @(
    @{ N = 'AJRouter';      M = 'Disabled'; W = 'Roteador AllJoyn (IoT) - sem uso em PC|AllJoyn IoT router - unused on PCs' }
    @{ N = 'ALG';           M = 'Manual';   W = 'Gateway de camada de aplicacao|Application Layer Gateway' }
    @{ N = 'BthHFSrv';      M = 'Manual';   W = 'Bluetooth viva-voz sob demanda|Bluetooth handsfree on demand' }
    @{ N = 'DoSvc';         M = 'Manual';   W = 'Delivery Optimization (updates P2P)|Delivery Optimization (P2P updates)' }
    @{ N = 'Fax';           M = 'Disabled'; W = 'Servico de fax|Fax service' }
    @{ N = 'lfsvc';         M = 'Manual';   W = 'Geolocalizacao sob demanda|Geolocation on demand' }
    @{ N = 'MessagingService_TEMPLATE'; M = 'Manual'; W = 'Sincronizacao de SMS (por usuario)|SMS sync (per-user)' }
    @{ N = 'PhoneSvc';      M = 'Manual';   W = 'Estado de telefonia|Phone telephony state' }
    @{ N = 'PimIndexMaintenanceSvc_TEMPLATE'; M = 'Manual'; W = 'Indexacao de contatos (por usuario)|Contact indexing (per-user)' }
    @{ N = 'PrintNotify';   M = 'Manual';   W = 'Notificacoes de impressora|Printer notification popups' }
    @{ N = 'RemoteAccess';  M = 'Disabled'; W = 'Roteamento e acesso remoto|Routing and Remote Access' }
    @{ N = 'SCardSvr';      M = 'Manual';   W = 'Smart card sob demanda|Smart card on demand' }
    @{ N = 'SEMgrSvc';      M = 'Manual';   W = 'Pagamentos por NFC|NFC payments' }
    @{ N = 'SharedAccess';  M = 'Manual';   W = 'Compartilhamento de conexao|Internet Connection Sharing' }
    @{ N = 'SSDPSRV';       M = 'Manual';   W = 'Descoberta SSDP (projecao) sob demanda|SSDP discovery on demand' }
    @{ N = 'TrkWks';        M = 'Manual';   W = 'Rastreamento de link distribuido|Distributed Link Tracking' }
    @{ N = 'upnphost';      M = 'Manual';   W = 'Host UPnP sob demanda|UPnP host on demand' }
    @{ N = 'WalletService'; M = 'Manual';   W = 'Carteira|Wallet' }
    @{ N = 'WdiServiceHost';M = 'Manual';   W = 'Host de servico de diagnostico|Diagnostic service host' }
    @{ N = 'WdiSystemHost'; M = 'Manual';   W = 'Host de sistema de diagnostico|Diagnostic system host' }
    @{ N = 'WpcMonSvc';     M = 'Manual';   W = 'Controle dos pais|Parental controls' }
    @{ N = 'edgeupdate';    M = 'Manual';   W = 'Atualizador do Edge sob demanda|Edge updater on demand' }
    @{ N = 'edgeupdatem';   M = 'Manual';   W = 'Atualizador do Edge (maquina)|Edge updater (machine)' }
    @{ N = 'MicrosoftEdgeElevationService'; M = 'Manual'; W = 'Elevacao do Edge|Edge elevation service' }
    @{ N = 'gupdate';       M = 'Manual';   W = 'Atualizador Google|Google updater' }
    @{ N = 'gupdatem';      M = 'Manual';   W = 'Atualizador Google (maquina)|Google updater (machine)' }
    @{ N = 'AdobeARMservice'; M = 'Manual'; W = 'Atualizador do Adobe Acrobat|Adobe Acrobat updater' }
)

function Invoke-Services {
    Write-Section 'Otimizacao de servicos|Service optimization'

    foreach ($s in $script:ServicePlan) { Set-ServiceStartup -Name $s.N -Startup $s.M -Reason $s.W }

    if (-not $KeepXbox -and -not $Gaming) {
        foreach ($x in @('XblAuthManager', 'XblGameSave', 'XboxGipSvc', 'XboxNetApiSvc')) {
            Set-ServiceStartup -Name $x -Startup 'Manual' -Reason 'Servico Xbox sob demanda|Xbox service on demand'
        }
    }

    # SysMain: util de verdade em HD mecanico, quase so overhead em NVMe.
    if ($script:HasSSD -and ($LowEndMode -or $Preset -eq 'Full')) {
        Set-ServiceStartup 'SysMain' 'Manual' 'SuperFetch - pouco ganho em SSD, libera RAM e I/O|SuperFetch - low benefit on SSD, frees RAM and I/O'
    } else {
        Write-Log 'SysMain mantido ativo - ele acelera discos mecanicos.|SysMain left enabled - it speeds up mechanical disks.' -Level INFO
    }

    # Acima de 3,5 GB o Windows isola cada servico em um svchost.exe proprio.
    # Elevar o limite ao total de RAM reagrupa os servicos e reduz processos.
    $ramKB = [int]((Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum / 1KB)
    if ($ramKB -gt 0) {
        Set-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control' 'SvcHostSplitThresholdInKB' $ramKB -Type DWord `
            -Description "$(T 'Agrupamento de svchost ajustado a RAM instalada|svchost grouping set to installed RAM') ($([math]::Round($ramKB/1MB,1)) GB)"
    }

    Write-Log 'Intocados por decisao: Windows Search, Spooler, Windows Update, Defender, Audio, Bluetooth, Temas.|Untouched by design: Windows Search, Print Spooler, Windows Update, Defender, Audio, Bluetooth, Themes.' -Level INFO
}

# ==============================================================================
#  MODULO 5 - INTERFACE
# ==============================================================================

function Invoke-Interface {
    Write-Section 'Limpeza da interface|Interface cleanup'

    $adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'

    Set-RegValue $adv 'HideFileExt'                   0 -Description 'Mostrar extensoes de arquivo|Show file extensions'
    Set-RegValue $adv 'LaunchTo'                      1 -Description 'Explorer abre em Este Computador|Explorer opens on This PC'
    Set-RegValue $adv 'ShowTaskViewButton'            0 -Description 'Botao Visao de Tarefas oculto|Task View button hidden'
    Set-RegValue $adv 'ShowSyncProviderNotifications' 0 -Description 'Propaganda do OneDrive no Explorer off|OneDrive ads in Explorer off'
    Set-RegValue $adv 'Start_IrisRecommendations'     0 -Description 'Recomendacoes do Iniciar off|Start recommendations off'
    Set-RegValue $adv 'Start_AccountNotifications'    0 -Description 'Avisos de conta no Iniciar off|Start account notifications off'
    Set-RegValue $adv 'Start_TrackDocs'               0 -Description 'Rastreio de documentos recentes off|Recent documents tracking off'

    if ($script:Build -ge 22000) {
        Set-RegValue $adv 'TaskbarDa' 0 -Description 'Botao Widgets oculto|Widgets button hidden'
        Set-RegValue $adv 'TaskbarMn' 0 -Description 'Botao Chat/Teams oculto|Chat / Teams button hidden'
        Set-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 0 -Description 'Noticias e interesses off|News and interests off'
    }

    # Resultados web no Iniciar: quatro chaves, porque uma so nao resolve.
    Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled' 0 -Description 'Bing na busca do Iniciar off|Bing in Start search off'
    Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'CortanaConsent'    0 -Description 'Consentimento da Cortana revogado|Cortana consent revoked'
    Set-RegValue 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1 -Description 'Sugestoes web na busca off|Search box web suggestions off'
    Set-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'DisableWebSearch'      1 -Description 'Busca web off (politica)|Web search off (policy)'
    Set-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'ConnectedSearchUseWeb' 0 -Description 'Busca conectada off|Connected web search off'
    Set-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'AllowCortana'          0 -Description 'Cortana off (politica)|Cortana off (policy)'
    Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'SearchboxTaskbarMode' 1 -Description 'Caixa de pesquisa reduzida a icone|Taskbar search shrunk to icon'

    Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement' 'ScoobeSystemSettingEnabled' 0 `
        -Description 'Tela pos-atualizacao "concluir configuracao" off|Post-update "finish setup" screen off'

    if ($ClassicContextMenu -and $script:Build -ge 22000) {
        $clsid = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
        Set-RegValue $clsid '(Default)' '' -Type String -Description 'Menu de contexto do Windows 10 restaurado|Windows 10 style context menu restored'
    }

    if (-not $DryRun) {
        Write-Log 'Reiniciando o Explorer para aplicar...|Restarting Explorer to apply...'
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Start-Process explorer }
    }
}

# ==============================================================================
#  MODULO 6 - PERFORMANCE E MEMORIA
# ==============================================================================

function Invoke-Performance {
    Write-Section 'Performance e memoria|Performance and memory'

    # Memory Compression fica LIGADA de proposito: em maquina de 8 GB ela evita
    # paginacao, que custa muito mais caro que comprimir pagina.
    Write-Log 'Memory Compression mantida ATIVA - reduz paginacao em maquinas com pouca RAM.|Memory Compression kept ENABLED - it reduces paging on low-RAM systems.' -Level INFO

    Set-RegValue 'HKCU:\Control Panel\Desktop' 'MenuShowDelay'         '200'  -Type String -Description 'Delay de menu 400ms -> 200ms|Menu delay 400ms -> 200ms'
    Set-RegValue 'HKCU:\Control Panel\Desktop' 'AutoEndTasks'          '1'    -Type String -Description 'Fecha apps travados no desligamento|Auto-close hung apps on shutdown'
    Set-RegValue 'HKCU:\Control Panel\Desktop' 'HungAppTimeout'        '4000' -Type String -Description 'Timeout de app travado 4s|Hung app timeout 4s'
    Set-RegValue 'HKCU:\Control Panel\Desktop' 'WaitToKillAppTimeout'  '5000' -Type String -Description 'Espera de desligamento 5s|Shutdown wait 5s'
    Set-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control' 'WaitToKillServiceTimeout' '5000' -Type String -Description 'Espera de servicos no desligamento 5s|Service shutdown wait 5s'
    Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize' 'StartupDelayInMSec' 0 -Description 'Atraso de apps na inicializacao removido|Startup app delay removed'

    if (-not $DryRun) {
        try {
            $rs = Get-WindowsReservedStorageState -ErrorAction Stop
            if ($rs.ReservedStorageState -eq 'Enabled') {
                Set-WindowsReservedStorageState -State Disabled -ErrorAction Stop | Out-Null
                Add-JournalEntry @{ Type = 'ReservedStorage'; OldState = 'Enabled' }
                Write-Log 'Reserved Storage desativado (~7 GB liberados).|Reserved Storage disabled (~7 GB reclaimed).' -Level OK
            }
        } catch { Write-Log 'Reserved Storage indisponivel nesta build.|Reserved Storage not available on this build.' -Level INFO }
    }

    if ($LowEndMode) {
        Write-Log 'Perfil low-end: reduzindo efeitos visuais sem prejudicar a leitura.|Low-end profile: trimming visual effects while keeping text readable.' -Level INFO
        Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' 3 -Description 'Perfil de efeitos personalizado|Custom visual effects profile'
        Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 0 -Description 'Transparencia off|Transparency off'
        Set-RegValue 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate' '0' -Type String -Description 'Animacoes de janela off|Window animations off'
        Set-RegValue 'HKCU:\Control Panel\Desktop' 'DragFullWindows' '0' -Type String -Description 'Nao redesenhar janela ao arrastar|Do not redraw windows while dragging'
        Set-RegValue 'HKCU:\Control Panel\Desktop' 'FontSmoothing'   '2' -Type String -Description 'ClearType mantido (legibilidade)|ClearType kept on (readability)'
    }

    if ($DisableFastStartup) {
        Set-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled' 0 -Description 'Fast Startup desativado (desligamento limpo)|Fast Startup disabled (clean shutdowns)'
    }

    if ($HAGS) {
        Write-Log 'Ativando HAGS - faca benchmark antes de manter.|Enabling HAGS - benchmark before keeping it.' -Level WARN
        Set-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 2 -Description 'Agendamento de GPU por hardware ativado|Hardware GPU scheduling enabled'
    }
}

# ==============================================================================
#  MODULO 7 - PLANOS DE ENERGIA / POWER PLANS
# ==============================================================================

$script:PowerPlans = [ordered]@{
    'Balanced'        = @{ Guid = '381b4222-f694-41f0-9685-ff5bb260df2e'; Label = 'Equilibrado|Balanced';                Desc = 'Padrao do Windows. Escala a frequencia conforme a carga.|Windows default. Scales frequency with load.' }
    'HighPerformance' = @{ Guid = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'; Label = 'Alto desempenho|High performance';    Desc = 'Mantem a CPU em frequencia alta. Mais consumo e calor.|Keeps the CPU at high clocks. More power and heat.' }
    'Ultimate'        = @{ Guid = 'e9a42b02-d5df-448d-aa00-03f14749eb61'; Label = 'Desempenho maximo|Ultimate performance'; Desc = 'Elimina micro-latencias de gerenciamento de energia. Desktop.|Removes power-management micro-latencies. Desktop only.' }
    'PowerSaver'      = @{ Guid = 'a1841308-3541-4fab-bc81-f71556f20b4a'; Label = 'Economia de energia|Power saver';     Desc = 'Prioriza bateria. Reduz desempenho de forma perceptivel.|Prioritizes battery. Noticeably reduces performance.' }
}

function Invoke-PowerPlan {
    param([string]$Plan = 'Auto')

    Write-Section 'Plano de energia|Power plan'

    if ($Plan -eq 'Keep') {
        Write-Log 'Plano de energia mantido como esta.|Power plan left as is.' -Level INFO
        return
    }

    if ($Plan -eq 'Auto') {
        $Plan = if ($script:IsLaptop) { 'Balanced' } else { 'Ultimate' }
        Write-Log "$(T 'Automatico ->|Auto ->') $Plan" -Level INFO
    }

    # Em notebook, autonomia costuma valer mais que 2% de throughput.
    if ($script:IsLaptop -and $Plan -in @('Ultimate', 'HighPerformance')) {
        Write-Log 'Notebook detectado: este plano reduz bastante a autonomia da bateria.|Laptop detected: this plan will noticeably reduce battery life.' -Level WARN
    }

    $info = $script:PowerPlans[$Plan]
    if (-not $info) { Write-Log "$(T 'Plano desconhecido|Unknown plan'): $Plan" -Level ERROR; return }

    if ($DryRun) {
        Write-Log "$(T 'Ativaria o plano|Would activate plan'): $(T $info.Label)" -Level DRY
        return
    }

    try {
        $guidRx  = [regex]'([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})'
        $current = $guidRx.Match((powercfg /getactivescheme | Out-String)).Value

        # Desempenho maximo vem oculto de fabrica: precisa ser duplicado antes.
        if ($Plan -eq 'Ultimate') {
            powercfg /duplicatescheme $info.Guid 2>$null | Out-Null
        }

        powercfg /setactive $info.Guid 2>$null
        Start-Sleep -Milliseconds 300
        $now = $guidRx.Match((powercfg /getactivescheme | Out-String)).Value

        if ($now -eq $info.Guid) {
            Add-JournalEntry @{ Type = 'PowerPlan'; OldGuid = $current; NewGuid = $info.Guid; Description = (T $info.Label) }
            Write-Log "$(T 'Plano ativo|Active plan'): $(T $info.Label)" -Level OK
            Write-Log (T $info.Desc) -Level INFO
        } else {
            Write-Log 'O plano nao foi aceito por este hardware (comum em notebooks). Nada foi alterado.|This hardware refused the plan (common on laptops). Nothing was changed.' -Level WARN
        }

        # Portas USB nunca dormem em desktop: causa classica de periferico sumindo.
        if (-not $script:IsLaptop) {
            powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null
            powercfg /setactive SCHEME_CURRENT 2>$null
            Write-Log 'Suspensao seletiva de USB desativada.|USB selective suspend disabled.' -Level OK
        }
    } catch {
        $script:Stats.Errors++
        Write-Log "powercfg: $($_.Exception.Message)" -Level ERROR
    }
}

# ==============================================================================
#  MODULO 8 - JOGOS / GAMING
# ==============================================================================

function Invoke-Gaming {
    Write-Section 'Jogos e latencia|Gaming and latency'

    Set-RegValue 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled'         0 -Description 'Gravacao em segundo plano do GameDVR off|GameDVR background recording off'
    Set-RegValue 'HKCU:\System\GameConfigStore' 'GameDVR_FSEBehaviorMode' 2 -Description 'Comportamento de tela cheia|Fullscreen optimizations behavior'
    Set-RegValue 'HKCU:\System\GameConfigStore' 'GameDVR_HonorUserFSEBehaviorMode' 1 -Description 'Respeitar preferencia de tela cheia|Honor user FSE preference'
    Set-RegValue 'HKCU:\System\GameConfigStore' 'GameDVR_DXGIHonorFSEWindowsCompatible' 1 -Description 'Compatibilidade DXGI de tela cheia|DXGI FSE compatibility'
    Set-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' 0 -Description 'GameDVR bloqueado por politica|GameDVR blocked by policy'

    Set-RegValue 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled'       1 -Description 'Modo Jogo ativado|Game Mode enabled'
    Set-RegValue 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode'         1 -Description 'Modo Jogo automatico permitido|Auto Game Mode allowed'
    Set-RegValue 'HKCU:\Software\Microsoft\GameBar' 'ShowStartupPanel'          0 -Description 'Dica inicial da Game Bar off|Game Bar startup tip off'
    Set-RegValue 'HKCU:\Software\Microsoft\GameBar' 'UseNexusForGameBarEnabled' 0 -Description 'Nexus da Game Bar off|Game Bar nexus off'

    $sp = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
    Set-RegValue $sp 'SystemResponsiveness' 10 -Description 'Reserva 10% ao segundo plano (padrao 20%)|Reserve 10% for background (default 20%)'
    # -1 grava 0xFFFFFFFF. Passar 4294967295 estouraria o Int32 exigido por DWord.
    Set-RegValue $sp 'NetworkThrottlingIndex' -1 -Description 'Throttling de rede off (0xFFFFFFFF)|Network throttling off (0xFFFFFFFF)'

    $games = "$sp\Tasks\Games"
    Set-RegValue $games 'GPU Priority'        8      -Description 'Prioridade de GPU alta para jogos|Games GPU priority high'
    Set-RegValue $games 'Priority'            6      -Description 'Prioridade de CPU alta para jogos|Games CPU priority high'
    Set-RegValue $games 'Scheduling Category' 'High' -Type String -Description 'Categoria de agendamento alta|Scheduling category High'
    Set-RegValue $games 'SFIO Priority'       'High' -Type String -Description 'Prioridade de I/O alta|Storage I/O priority High'

    # Nagle desativado apenas nos adaptadores realmente ativos.
    try {
        foreach ($i in (Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces' -ErrorAction Stop)) {
            $props = Get-ItemProperty $i.PSPath -ErrorAction SilentlyContinue
            if ($props.DhcpIPAddress -or $props.IPAddress) {
                Set-RegValue $i.PSPath 'TcpAckFrequency' 1 -Description "Nagle off ($($i.PSChildName))"
                Set-RegValue $i.PSPath 'TCPNoDelay'      1 -Description "TCPNoDelay ($($i.PSChildName))"
            }
        }
    } catch { Write-Log 'Nao foi possivel enumerar as interfaces de rede.|Could not enumerate network interfaces.' -Level WARN }

    Write-Log 'Servicos Xbox e Xbox Identity Provider preservados - Game Pass e launchers seguem funcionando.|Xbox services and Xbox Identity Provider preserved - Game Pass and launchers keep working.' -Level INFO
}

# ==============================================================================
#  MODULO 9 - LIMPEZA DE DISCO
# ==============================================================================

function Get-FolderSizeMB {
    param([string]$Path)
    try {
        if (-not (Test-Path $Path)) { return 0 }
        $b = (Get-ChildItem $Path -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        return [math]::Round(($b / 1MB), 1)
    } catch { return 0 }
}

function Clear-FolderContents {
    param([string]$Path, [string]$Label)
    if (-not (Test-Path $Path)) { return }
    $before = Get-FolderSizeMB $Path
    if ($before -le 0) { return }

    if ($DryRun) { Write-Log "$(T $Label): $before MB" -Level DRY; return }

    Get-ChildItem $Path -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    $freed = [math]::Max(0, $before - (Get-FolderSizeMB $Path))
    $script:Stats.DiskFreedMB += $freed
    Write-Log ("{0}: {1} MB" -f (Resolve-Text $Label), $freed) -Level OK
}

function Invoke-CleanDisk {
    Write-Section 'Limpeza de disco|Disk cleanup'

    Clear-FolderContents "$env:TEMP"                              'Temp do usuario|User temp'
    Clear-FolderContents "$env:SystemRoot\Temp"                   'Temp do Windows|Windows temp'
    Clear-FolderContents "$env:SystemRoot\Logs\CBS"               'Logs CBS|CBS logs'
    Clear-FolderContents "$env:LOCALAPPDATA\Microsoft\Windows\WER" 'Fila de relatorio de erros|Error report queue'
    Clear-FolderContents "$env:LOCALAPPDATA\D3DSCache"            'Cache de shaders DirectX|DirectX shader cache'
    Clear-FolderContents "$env:LOCALAPPDATA\CrashDumps"           'Crash dumps|Crash dumps'
    # O Prefetch NAO e limpo: o Windows apenas o reconstroi e os apps abrem mais
    # devagar ate la. Apagar e cosmetico, nao otimizacao.

    if (-not $DryRun) {
        try {
            $sd = "$env:SystemRoot\SoftwareDistribution\Download"
            $before = Get-FolderSizeMB $sd
            if ($before -gt 50) {
                Stop-Service wuauserv, bits -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
                Get-ChildItem $sd -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                Start-Service wuauserv, bits -ErrorAction SilentlyContinue
                $freed = $before - (Get-FolderSizeMB $sd)
                $script:Stats.DiskFreedMB += $freed
                Write-Log ("$(T 'Cache do Windows Update|Windows Update cache'): {0} MB" -f [math]::Round($freed, 1)) -Level OK
            }
        } catch { Write-Log "Windows Update cache: $($_.Exception.Message)" -Level WARN }

        try {
            if (Get-DeliveryOptimizationStatus -ErrorAction SilentlyContinue) {
                Delete-DeliveryOptimizationCache -Force -ErrorAction SilentlyContinue
                Write-Log 'Cache do Delivery Optimization limpo.|Delivery Optimization cache cleared.' -Level OK
            }
        } catch { }

        try { Clear-RecycleBin -Force -ErrorAction SilentlyContinue; Write-Log 'Lixeira esvaziada.|Recycle Bin emptied.' -Level OK } catch { }
    }

    if ($Preset -eq 'Full' -and -not $DryRun) {
        Write-Log 'Executando limpeza de componentes DISM (pode demorar)...|Running DISM component cleanup (may take several minutes)...'
        Start-Process dism.exe -ArgumentList '/Online /Cleanup-Image /StartComponentCleanup /Quiet /NoRestart' -Wait -NoNewWindow
        Write-Log 'WinSxS limpo.|WinSxS component store cleaned.' -Level OK
    }
}

# ==============================================================================
#  MENU DE FALLBACK (usado sem a interface Rust)
# ==============================================================================

function Show-Menu {
    $opts = [ordered]@{
        '1' = @{ Key = 'RemoveApps';  Text = 'Remover bloatware pre-instalado|Remove pre-installed bloatware'; On = $true }
        '2' = @{ Key = 'Privacy';     Text = 'Desativar telemetria e rastreamento|Disable telemetry and tracking'; On = $true }
        '3' = @{ Key = 'DisableAI';   Text = 'Desativar Copilot / Recall / IA|Disable Copilot / Recall / AI'; On = $true }
        '4' = @{ Key = 'Services';    Text = 'Otimizar servicos e svchost|Optimize services and svchost'; On = $true }
        '5' = @{ Key = 'Interface';   Text = 'Limpar barra, Iniciar e Explorer|Clean taskbar, Start and Explorer'; On = $true }
        '6' = @{ Key = 'Performance'; Text = 'Performance e memoria|Performance and memory'; On = $true }
        '7' = @{ Key = 'Energy';      Text = 'Plano de energia|Power plan'; On = $true }
        '8' = @{ Key = 'Gaming';      Text = 'Jogos e latencia|Gaming and latency'; On = $false }
        '9' = @{ Key = 'CleanDisk';   Text = 'Limpeza de disco|Disk cleanup'; On = $true }
        'A' = @{ Key = 'LowEndMode';  Text = 'Modo low-end (8 GB ou menos)|Low-end mode (8 GB or less)'; On = $false }
        'B' = @{ Key = 'ClassicContextMenu'; Text = 'Menu de contexto classico (Win11)|Classic context menu (Win11)'; On = $false }
        'C' = @{ Key = 'DisableFastStartup';  Text = 'Desativar Fast Startup|Disable Fast Startup'; On = $false }
        'D' = @{ Key = 'HAGS';        Text = 'Agendamento de GPU por hardware|Hardware GPU scheduling'; On = $false }
    }

    while ($true) {
        Show-Banner
        Write-Host "  $(T 'Numero alterna o item. Presets: W=Trabalho G=Jogos M=Minimo F=Tudo|Type a number to toggle. Presets: W=Work G=Gaming M=Minimal F=Full')" -ForegroundColor DarkGray
        Write-Host ''
        foreach ($k in $opts.Keys) {
            $mark  = if ($opts[$k].On) { '[x]' } else { '[ ]' }
            $color = if ($opts[$k].On) { 'White' } else { 'DarkGray' }
            Write-Host "   $k  $mark  $(T $opts[$k].Text)" -ForegroundColor $color
        }
        Write-Host ''
        Write-Host "   P  $(T 'Escolher plano de energia|Choose power plan') [$script:SelectedPlan]" -ForegroundColor DarkGray
        Write-Host "   L  $(T 'Idioma|Language') [$($script:Lang)]" -ForegroundColor DarkGray
        Write-Host "   V  $(T 'Simulacao (nao altera nada)|Dry run (changes nothing)')" -ForegroundColor DarkGray
        Write-Host "   R  $(T 'Desfazer ultima execucao|Roll back the last run')" -ForegroundColor DarkGray
        Write-Host "   S  $(T 'INICIAR|START')" -ForegroundColor Green
        Write-Host "   Q  $(T 'Sair|Quit')" -ForegroundColor DarkGray
        Write-Host ''
        if ($DryRun) { Write-Host "   *** $(T 'SIMULACAO ATIVA|DRY RUN ACTIVE') ***" -ForegroundColor Yellow; Write-Host '' }

        $choice = (Read-Host '  >').Trim().ToUpper()

        switch ($choice) {
            'Q' { return @() }
            'S' { return @($opts.Values | Where-Object { $_.On } | Select-Object -ExpandProperty Key) }
            'V' { $script:DryRun = -not $script:DryRun }
            'L' { $script:Lang = if ($script:Lang -eq 'pt') { 'en' } else { 'pt' } }
            'R' { Invoke-Revert; Read-Host (T '  Enter para voltar|  Press Enter'); return @() }
            'P' { Show-PowerPlanMenu }
            'W' { foreach ($k in $opts.Keys) { $opts[$k].On = $k -in @('1','2','3','4','5','6','7','9') } }
            'G' { foreach ($k in $opts.Keys) { $opts[$k].On = $k -in @('1','2','3','4','5','6','7','8','9') } }
            'M' { foreach ($k in $opts.Keys) { $opts[$k].On = $k -in @('2','3') } }
            'F' { foreach ($k in $opts.Keys) { $opts[$k].On = $k -ne 'D' } }
            default { if ($opts.Contains($choice)) { $opts[$choice].On = -not $opts[$choice].On } }
        }
    }
}

function Show-PowerPlanMenu {
    Show-Banner
    Write-Host "  $(T 'Escolha o plano de energia|Choose the power plan')" -ForegroundColor Cyan
    Write-Host ''
    $i = 1
    $map = @{}
    Write-Host "   0  $(T 'Manter o plano atual|Keep the current plan')" -ForegroundColor White
    $map['0'] = 'Keep'
    foreach ($k in $script:PowerPlans.Keys) {
        Write-Host "   $i  $(T $script:PowerPlans[$k].Label)" -ForegroundColor White
        Write-Host "      $(T $script:PowerPlans[$k].Desc)" -ForegroundColor DarkGray
        $map["$i"] = $k
        $i++
    }
    Write-Host "   $i  $(T 'Automatico (desktop = maximo, notebook = equilibrado)|Auto (desktop = ultimate, laptop = balanced)')" -ForegroundColor White
    $map["$i"] = 'Auto'
    Write-Host ''
    $sel = (Read-Host '  >').Trim()
    if ($map.ContainsKey($sel)) { $script:SelectedPlan = $map[$sel] }
}

function Sync-ModuleFlags {
    param([string[]]$Modules)
    foreach ($f in @('RemoveApps','Privacy','DisableAI','Services','Interface','Performance',
                     'Gaming','CleanDisk','Energy','LowEndMode','ClassicContextMenu',
                     'DisableFastStartup','HAGS','KeepXbox')) {
        if ($Modules -contains $f) { Set-Variable -Name $f -Value $true -Scope Script }
    }
}

function Resolve-Preset {
    switch ($Preset) {
        'Minimal' { return @('Privacy', 'DisableAI') }
        'Work'    { return @('RemoveApps','Privacy','DisableAI','Services','Interface','Performance','Energy','CleanDisk') }
        'Gaming'  { return @('RemoveApps','Privacy','DisableAI','Services','Interface','Performance','Energy','Gaming','CleanDisk') }
        'Full'    { return @('RemoveApps','Privacy','DisableAI','Services','Interface','Performance','Energy','Gaming','CleanDisk','LowEndMode','ClassicContextMenu','DisableFastStartup') }
    }
    return @()
}

function Show-Summary {
    Write-Section 'Resumo|Summary'
    $rows = @(
        @{ L = 'Apps removidos      |Apps removed        '; V = $script:Stats.Apps }
        @{ L = 'Chaves de registro  |Registry changes    '; V = $script:Stats.Registry }
        @{ L = 'Servicos ajustados  |Services adjusted   '; V = $script:Stats.Services }
        @{ L = 'Tarefas desativadas |Tasks disabled      '; V = $script:Stats.Tasks }
        @{ L = 'Disco liberado (MB) |Disk freed (MB)     '; V = [math]::Round($script:Stats.DiskFreedMB, 1) }
        @{ L = 'Erros               |Errors              '; V = $script:Stats.Errors }
    )
    foreach ($r in $rows) { Write-Log "$(T $r.L): $($r.V)" }

    Write-Log "Log: $($script:LogFile)"
    if (-not $DryRun -and $script:Journal.Count -gt 0) {
        Write-Log "Journal: $($script:JournalFile)"
        Write-Log 'Desfaca tudo com: WinLean.ps1 -Revert|Roll everything back with: WinLean.ps1 -Revert' -Level INFO
    }
    if ($DryRun) {
        Write-Log 'SIMULACAO - nada foi alterado.|DRY RUN - nothing was changed.' -Level WARN
    } else {
        Write-Log 'Reinicie o PC para aplicar todas as alteracoes.|Restart your PC to apply all changes.' -Level WARN
    }
}

# ==============================================================================
#  MAIN
# ==============================================================================

$script:SelectedPlan = $PowerPlan

function Invoke-Main {
    if (-not (Test-Admin)) {
        Write-Log 'O WinLean precisa ser executado como Administrador.|WinLean must run as Administrator.' -Level ERROR
        exit 1
    }

    Initialize-Environment

    if ($Revert) { Invoke-Revert; return }

    if (-not $Plain) { Show-Banner }
    Show-SystemInfo

    $modules = @()
    if ($Preset) {
        $modules = @(Resolve-Preset)
    } else {
        $modules = @(@('RemoveApps','Privacy','DisableAI','Services','Interface',
                       'Performance','Gaming','CleanDisk','Energy') |
                     Where-Object { Get-Variable -Name $_ -ValueOnly -ErrorAction SilentlyContinue })
    }

    # Escolher um plano explicito ja implica rodar o modulo de energia.
    if ($script:SelectedPlan -ne 'Keep' -and $modules -notcontains 'Energy') { $modules += 'Energy' }

    if ($modules.Count -eq 0 -and -not $Silent -and -not $Plain) {
        $modules = @(Show-Menu)
        if ($modules.Count -eq 0) { return }
        if ($script:SelectedPlan -ne 'Keep' -and $modules -notcontains 'Energy') { $modules += 'Energy' }
    }

    Sync-ModuleFlags -Modules $modules

    if ($modules.Count -eq 0) {
        Write-Log 'Nada selecionado. Use -Preset Work ou rode sem -Silent.|Nothing selected. Use -Preset Work or run without -Silent.' -Level WARN
        return
    }

    if (-not $Plain) { Show-Banner }
    Write-Section 'Plano de execucao|Execution plan'
    foreach ($m in $modules) { Write-Log "- $m" }
    if ($modules -contains 'Energy') { Write-Log "- $(T 'Plano de energia|Power plan'): $($script:SelectedPlan)" }

    if (-not $Silent -and -not $DryRun -and -not $Plain) {
        $ok = Read-Host (T '  Aplicar estas alteracoes? (s/N)|  Apply these changes? (y/N)')
        if ($ok -notmatch '^[yYsS]') { Write-Log 'Cancelado.|Cancelled.' -Level WARN; return }
    }

    $sw = [Diagnostics.Stopwatch]::StartNew()
    New-RestorePoint

    if ($modules -contains 'RemoveApps')  { Invoke-RemoveApps }
    if ($modules -contains 'Privacy')     { Invoke-Privacy }
    if ($modules -contains 'DisableAI')   { Invoke-DisableAI }
    if ($modules -contains 'Services')    { Invoke-Services }
    if ($modules -contains 'Interface')   { Invoke-Interface }
    if ($modules -contains 'Performance') { Invoke-Performance }
    if ($modules -contains 'Energy')      { Invoke-PowerPlan -Plan $script:SelectedPlan }
    if ($modules -contains 'Gaming')      { Invoke-Gaming }
    if ($modules -contains 'CleanDisk')   { Invoke-CleanDisk }

    Save-Journal
    $sw.Stop()
    Write-Log "$(T 'Concluido em|Completed in') $([math]::Round($sw.Elapsed.TotalSeconds, 1))s" -Level INFO -NoConsole
    Show-Summary

    if (-not $Silent -and -not $DryRun -and -not $Plain) {
        $r = Read-Host (T '  Reiniciar agora? (s/N)|  Restart now? (y/N)')
        if ($r -match '^[yYsS]') { Restart-Computer -Force }
    }
}

Invoke-Main
