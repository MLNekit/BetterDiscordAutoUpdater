<#
BetterDiscord Auto-Updater Script

Updated: 2026-01-15

This script performs the following steps:
    0. Checks if running as administrator and relaunches if not.
    1. Ensures Discord is installed; installs it if missing.
    2. Terminates Discord if running.
    3. Checks and installs dependencies (Git, Node.js, pnpm, Bun).
    4. Ensures the update script folder exists and updates the script.
    5. Clones or updates the BetterDiscord repository.
    6. Creates a Start Menu shortcut for the updater.
    7. Ensures the BetterDiscord folder exists.
    8. Installs dependencies, builds, and injects BetterDiscord.
    9. Launches Discord.
#>

<#
    BetterDiscord Auto-Updater Script (Final Stable)
    Updated: 2025
#>

$ErrorActionPreference = "Stop"

function Write-Log {
    param($Message, $Color = "Cyan")
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message" -ForegroundColor $Color
}

# ========= 0. ELEVATION =========
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit
}

# ========= 1. PREPARE ENVIRONMENT =========
$procNames = @("Discord", "DiscordCanary", "DiscordPTB")
$running = Get-Process -Name $procNames -ErrorAction SilentlyContinue
if ($running) {
    Write-Log "Closing Discord..." "Yellow"
    Stop-Process -InputObject $running -Force
    Start-Sleep -Seconds 2
}

# ========= 2. DEPENDENCIES (GIT, NODE, BUN) =========
# Git check
if (-not (Get-Command "git" -ErrorAction SilentlyContinue)) {
    Write-Log "Installing Git..." "Yellow"
    $gitUrl = (Invoke-RestMethod "https://api.github.com/repos/git-for-windows/git/releases/latest").assets | Where-Object name -match "64-bit.exe" | Select-Object -ExpandProperty browser_download_url -First 1
    Invoke-WebRequest $gitUrl -OutFile "$env:TEMP\git.exe"
    Start-Process "$env:TEMP\git.exe" -ArgumentList "/VERYSILENT", "/NORESTART" -Wait
}

# Node check
if (-not (Get-Command "node" -ErrorAction SilentlyContinue)) {
    Write-Log "Installing Node.js..." "Yellow"
    Invoke-WebRequest "https://nodejs.org/dist/v20.11.0/node-v20.11.0-x64.msi" -OutFile "$env:TEMP\node.msi"
    Start-Process "msiexec.exe" -ArgumentList "/i `"$env:TEMP\node.msi`" /quiet /norestart" -Wait
}

# Bun check & Path handling
$bunPath = Join-Path $env:USERPROFILE ".bun\bin\bun.exe"
if (-not (Get-Command "bun" -ErrorAction SilentlyContinue) -and -not (Test-Path $bunPath)) {
    Write-Log "Installing Bun..." "Yellow"
    powershell -c "irm bun.sh/install.ps1 | iex"
}

# Находим pnpm
if (-not (Get-Command "pnpm" -ErrorAction SilentlyContinue)) {
    Write-Log "Installing pnpm..." "Yellow"
    npm install -g pnpm
}

# ========= 3. REPO UPDATE =========
$updateFolder = "$env:APPDATA\BetterDiscord AutoUpdater"
$repoFolder = Join-Path $updateFolder "BetterDiscordRepo"
if (-not (Test-Path $updateFolder)) { New-Item -ItemType Directory -Path $updateFolder -Force }

if (-not (Test-Path $repoFolder)) {
    Write-Log "Cloning BetterDiscord..." "Cyan"
    git clone "https://github.com/BetterDiscord/BetterDiscord.git" $repoFolder
} else {
    Write-Log "Updating Repo..." "Cyan"
    Set-Location $repoFolder
    git pull
}

# ========= 4. BUILD & INJECT (THE CRITICAL PART) =========
Set-Location $repoFolder
Write-Log "Starting Build & Inject..." "Magenta"

# Принудительно добавляем путь к Bun в текущую сессию, если он там появился
$env:PATH += ";$env:USERPROFILE\.bun\bin"

try {
    Write-Log "Running: pnpm install" "Gray"
    $install = Start-Process pnpm -ArgumentList "install" -Wait -NoNewWindow -PassThru
    if ($install.ExitCode -ne 0) { throw "pnpm install failed" }

    Write-Log "Running: pnpm build" "Gray"
    # Запускаем через cmd чтобы наверняка подхватить пути
    $build = Start-Process cmd -ArgumentList "/c pnpm build" -Wait -NoNewWindow -PassThru
    if ($build.ExitCode -ne 0) { 
        Write-Log "Build failed! Checking if Bun is accessible..." "Red"
        if (-not (Test-Path $bunPath)) { throw "Bun not found at $bunPath. Please restart your PC or this script." }
        throw "Build failed even with Bun present."
    }

    Write-Log "Running: pnpm inject" "Gray"
    $inject = Start-Process cmd -ArgumentList "/c pnpm run inject" -Wait -NoNewWindow -PassThru
    if ($inject.ExitCode -ne 0) { throw "Injection failed" }

    Write-Log "SUCCESS: BetterDiscord injected!" "Green"
} catch {
    Write-Log "ERROR: $_" "Red"
    Write-Log "If it says 'bun not recognized', just RUN THE SCRIPT AGAIN." "Yellow"
    Read-Host "Press Enter to exit"
    exit
}

# ========= 5. LAUNCH =========
$discord = "$env:LOCALAPPDATA\Discord\Update.exe"
if (Test-Path $discord) {
    Write-Log "Launching Discord..." "Green"
    Start-Process $discord -ArgumentList "--processStart", "Discord.exe"
}
Start-Sleep -Seconds 3
