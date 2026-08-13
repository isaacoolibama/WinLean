<#
    WinLean - instalador / installer

    PT: Baixa o WinLean para a pasta do usuario e abre a interface.
        irm https://raw.githubusercontent.com/isaacoolibama/WinLean/main/install.ps1 | iex

    EN: Downloads WinLean into the user folder and opens the interface.
        irm https://raw.githubusercontent.com/isaacoolibama/WinLean/main/install.ps1 | iex

    Parametros / Parameters:
        -Lang pt|en      idioma da interface (padrao: pt)
        -NoLaunch        apenas instala, nao abre a interface
        -Cli             abre o menu PowerShell em vez da interface Rust
        -Force           reinstala tudo, ignorando o cache local
#>

[CmdletBinding()]
param(
    [ValidateSet('pt', 'en')][string]$Lang = 'pt',
    [switch]$NoLaunch,
    [switch]$Cli,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

# ------------------------------------------------------------------------------
#  Config
# ------------------------------------------------------------------------------

$Repo      = 'isaacoolibama/WinLean'
$Branch    = 'main'
$InstallTo = Join-Path $env:LOCALAPPDATA 'WinLean'
$RawBase   = "https://raw.githubusercontent.com/$Repo/$Branch"
$ApiLatest = "https://api.github.com/repos/$Repo/releases/latest"

$Texts = @{
    pt = @{
        Title     = 'Instalador do WinLean'
        Elevating = 'Solicitando privilegios de administrador...'
        Folder    = 'Pasta de instalacao'
        DlEngine  = 'Baixando o motor (WinLean.ps1)...'
        DlUi      = 'Baixando a interface (winlean.exe)...'
        DlRuntime = 'Preparando a interface grafica (Microsoft WebView2)...'
        RuntimeFail = 'Nao foi possivel instalar o Microsoft WebView2 Runtime.'
        NoUi      = 'Nenhum binario de interface publicado ainda. Usando o menu do PowerShell.'
        UiFail    = 'Falha ao baixar a interface. Usando o menu do PowerShell.'
        Cached    = 'Interface atualizada'
        Shortcut  = 'Atalho criado no menu Iniciar.'
        Done      = 'Instalacao concluida.'
        Launch    = 'Abrindo a interface...'
        Manual    = 'Para abrir depois, execute'
        Blocked   = 'Nao foi possivel acessar o GitHub. Verifique a conexao ou o proxy.'
    }
    en = @{
        Title     = 'WinLean installer'
        Elevating = 'Requesting administrator privileges...'
        Folder    = 'Install folder'
        DlEngine  = 'Downloading the engine (WinLean.ps1)...'
        DlUi      = 'Downloading the interface (winlean.exe)...'
        DlRuntime = 'Preparing the graphical interface (Microsoft WebView2)...'
        RuntimeFail = 'Could not install the Microsoft WebView2 Runtime.'
        NoUi      = 'No interface binary published yet. Falling back to the PowerShell menu.'
        UiFail    = 'Interface download failed. Falling back to the PowerShell menu.'
        Cached    = 'Interface is up to date'
        Shortcut  = 'Start menu shortcut created.'
        Done      = 'Installation complete.'
        Launch    = 'Opening the interface...'
        Manual    = 'To open it later, run'
        Blocked   = 'Could not reach GitHub. Check your connection or proxy.'
    }
}
$L = $Texts[$Lang]

function Say {
    param([string]$Text, [string]$Color = 'Gray', [string]$Tag = '  ')
    Write-Host "$Tag $Text" -ForegroundColor $Color
}

# ------------------------------------------------------------------------------
#  Elevacao / elevation
# ------------------------------------------------------------------------------

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $id).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-WebView2Runtime {
    $client = '{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}'
    $paths = @(
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\$client",
        "HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\$client",
        "HKCU:\Software\Microsoft\EdgeUpdate\Clients\$client"
    )
    foreach ($path in $paths) {
        $version = (Get-ItemProperty -Path $path -Name 'pv' -ErrorAction SilentlyContinue).pv
        if ($version -and $version -ne '0.0.0.0') { return $true }
    }
    return $false
}

function Install-WebView2Runtime {
    if (Test-WebView2Runtime) { return }

    Say $L.DlRuntime
    $bootstrapper = Join-Path $env:TEMP 'MicrosoftEdgeWebview2Setup.exe'
    try {
        Invoke-WebRequest -Uri 'https://go.microsoft.com/fwlink/p/?LinkId=2124703' `
            -OutFile $bootstrapper -UseBasicParsing
        $process = Start-Process -FilePath $bootstrapper -ArgumentList '/silent /install' `
            -Wait -PassThru
        if (-not (Test-WebView2Runtime)) {
            throw "WebView2 installer exit code: $($process.ExitCode)"
        }
        Say 'Microsoft WebView2 Runtime' 'Green' ' +'
    } catch {
        Say $L.RuntimeFail 'Red' ' x'
        Say $_.Exception.Message 'DarkGray'
        exit 1
    } finally {
        Remove-Item -LiteralPath $bootstrapper -Force -ErrorAction SilentlyContinue
    }
}

<#
    Quando o script chega via `irm | iex` nao existe arquivo em disco para
    reexecutar. Gravamos uma copia em %TEMP% e reabrimos elevado a partir dela.

    When the script arrives through `irm | iex` there is no file on disk to
    re-run. We write a copy to %TEMP% and relaunch elevated from there.
#>
if (-not (Test-Admin)) {
    Say $L.Elevating 'Yellow' ' !'
    $self = Join-Path $env:TEMP 'winlean-install.ps1'
    if ($PSCommandPath -and (Test-Path $PSCommandPath)) {
        Copy-Item $PSCommandPath $self -Force
    } else {
        Invoke-WebRequest -Uri "$RawBase/install.ps1" -OutFile $self -UseBasicParsing
    }

    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$self`"", '-Lang', $Lang)
    if ($NoLaunch) { $argList += '-NoLaunch' }
    if ($Cli)      { $argList += '-Cli' }
    if ($Force)    { $argList += '-Force' }

    Start-Process powershell.exe -Verb RunAs -ArgumentList $argList
    return
}

# ------------------------------------------------------------------------------
#  Banner
# ------------------------------------------------------------------------------

Write-Host ''
Write-Host '   __        ___       _' -ForegroundColor Cyan
Write-Host '   \ \      / (_)_ __ | |    ___  __ _ _ __' -ForegroundColor Cyan
Write-Host "    \ \ /\ / /| | '_ \| |   / _ \/ _`` | '_ \" -ForegroundColor Cyan
Write-Host '     \ V  V / | | | | | |__|  __/ (_| | | | |' -ForegroundColor Cyan
Write-Host '      \_/\_/  |_|_| |_|_____\___|\__,_|_| |_|' -ForegroundColor Cyan
Write-Host ''
Say $L.Title 'Cyan' '=='
Write-Host ''

New-Item -Path $InstallTo -ItemType Directory -Force | Out-Null
Say "$($L.Folder): $InstallTo"

if (-not $Cli) { Install-WebView2Runtime }

# ------------------------------------------------------------------------------
#  Motor / engine
# ------------------------------------------------------------------------------

$enginePath = Join-Path $InstallTo 'WinLean.ps1'
Say $L.DlEngine
try {
    # O instalador tambem funciona como atualizador. O motor vem da branch main
    # em toda execucao para que uma instalacao anterior nunca fique desatualizada.
    Invoke-WebRequest -Uri "$RawBase/WinLean.ps1" -OutFile $enginePath -UseBasicParsing
    Say 'WinLean.ps1' 'Green' ' +'
} catch {
    Say $L.Blocked 'Red' ' x'
    Say $_.Exception.Message 'DarkGray'
    exit 1
}

# ------------------------------------------------------------------------------
#  Interface Rust / Rust interface
# ------------------------------------------------------------------------------

$uiPath = Join-Path $InstallTo 'winlean.exe'
$versionPath = Join-Path $InstallTo '.version'
$hasUi  = Test-Path $uiPath

if (-not $Cli) {
    Say $L.DlUi
    try {
        $headers = @{ 'User-Agent' = 'WinLean-Installer' }
        $release = Invoke-RestMethod -Uri $ApiLatest -Headers $headers -UseBasicParsing
        $asset   = $release.assets | Where-Object { $_.name -eq 'winlean.exe' } | Select-Object -First 1
        $localVersion = if (Test-Path $versionPath) {
            (Get-Content -LiteralPath $versionPath -Raw).Trim()
        } else { '' }

        if ($asset) {
            if ($Force -or -not $hasUi -or $localVersion -ne $release.tag_name) {
                Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $uiPath -UseBasicParsing
                Set-Content -LiteralPath $versionPath -Value $release.tag_name -Encoding ASCII
                Say "winlean.exe ($($release.tag_name))" 'Green' ' +'
            } else {
                Say "winlean.exe ($localVersion) - $($L.Cached)" 'DarkGray'
            }
            $hasUi = $true
        } else {
            Say $L.NoUi 'Yellow' ' !'
        }
    } catch {
        # Sem release publicada ou sem acesso a API: o menu do PowerShell cobre
        # exatamente as mesmas funcoes, entao a instalacao segue normalmente.
        Say $L.UiFail 'Yellow' ' !'
    }
}

# ------------------------------------------------------------------------------
#  Atalho / shortcut
# ------------------------------------------------------------------------------

try {
    $startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
    $lnk       = Join-Path $startMenu 'WinLean.lnk'
    $shell     = New-Object -ComObject WScript.Shell
    $s         = $shell.CreateShortcut($lnk)

    if ($hasUi -and -not $Cli) {
        $s.TargetPath = $uiPath
        $s.Arguments  = "--lang $Lang --script `"$enginePath`""
    } else {
        $s.TargetPath = 'powershell.exe'
        $s.Arguments  = "-NoProfile -ExecutionPolicy Bypass -File `"$enginePath`" -Language $Lang"
    }
    $s.WorkingDirectory = $InstallTo
    $s.IconLocation     = 'shell32.dll,21'
    $s.Description      = 'WinLean'
    $s.Save()
    Say $L.Shortcut 'Green' ' +'
} catch { }

Write-Host ''
Say $L.Done 'Green' ' +'

if ($hasUi -and -not $Cli) {
    Say "$($L.Manual): $uiPath --lang $Lang" 'DarkGray'
} else {
    Say "$($L.Manual): powershell -File `"$enginePath`" -Language $Lang" 'DarkGray'
}
Write-Host ''

# ------------------------------------------------------------------------------
#  Abrir / launch
# ------------------------------------------------------------------------------

if ($NoLaunch) { return }

Say $L.Launch 'Cyan' '=='
Start-Sleep -Milliseconds 600

if ($hasUi -and -not $Cli) {
    # Abre o aplicativo Rust em processo proprio. O instalador termina e o
    # usuario ve apenas a janela grafica; o PowerShell permanece como motor oculto.
    $uiArguments = "--lang $Lang --script `"$enginePath`""
    Start-Process -FilePath $uiPath -ArgumentList $uiArguments `
        -WorkingDirectory $InstallTo -WindowStyle Normal
} else {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $enginePath -Language $Lang
}
