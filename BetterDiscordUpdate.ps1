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

$ErrorActionPreference = "Stop"

# ========= HELPER FUNCTIONS =========

function Write-Log {
    param($Message, $Color = "Cyan")
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message" -ForegroundColor $Color
}

function Refresh-Env {
    # Refreshes the PATH environment variable in the current session
    $env:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:PATH += ";$env:USERPROFILE\.bun\bin"
    $env:PATH += ";$env:APPDATA\npm"
}

# ========= 0. ELEVATION CHECK =========

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Log "Requesting Administrator privileges..." "Yellow"
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit
}

# ========= 1. PREPARE AND CLOSE DISCORD =========

$procNames = @("Discord", "DiscordCanary", "DiscordPTB")
$running = Get-Process -Name $procNames -ErrorAction SilentlyContinue
if ($running) {
    Write-Log "Closing Discord processes..." "Yellow"
    Stop-Process -InputObject $running -Force
    Start-Sleep -Seconds 2
}

# ========= 2. INSTALL DEPENDENCIES =========

$needsRefresh = $false

# Git Check
if (-not (Get-Command "git" -ErrorAction SilentlyContinue)) {
    Write-Log "Git not found. Installing..." "Yellow"
    $gitUrl = (Invoke-RestMethod "https://api.github.com/repos/git-for-windows/git/releases/latest").assets | Where-Object name -match "64-bit.exe" | Select-Object -ExpandProperty browser_download_url -First 1
    Invoke-WebRequest $gitUrl -OutFile "$env:TEMP\git.exe"
    Start-Process "$env:TEMP\git.exe" -ArgumentList "/VERYSILENT", "/NORESTART" -Wait
    $needsRefresh = $true
}

# Node.js Check
if (-not (Get-Command "node" -ErrorAction SilentlyContinue)) {
    Write-Log "Node.js not found. Installing..." "Yellow"
    Invoke-WebRequest "https://nodejs.org/dist/v20.11.0/node-v20.11.0-x64.msi" -OutFile "$env:TEMP\node.msi"
    Start-Process "msiexec.exe" -ArgumentList "/i `"$env:TEMP\node.msi`" /quiet /norestart" -Wait
    $needsRefresh = $true
}

# Bun Check
$bunPath = Join-Path $env:USERPROFILE ".bun\bin\bun.exe"
if (-not (Get-Command "bun" -ErrorAction SilentlyContinue) -and -not (Test-Path $bunPath)) {
    Write-Log "Bun not found. Installing..." "Yellow"
    powershell -c "irm bun.sh/install.ps1 | iex"
    $needsRefresh = $true
}

if ($needsRefresh) { Refresh-Env }

# pnpm Check
if (-not (Get-Command "pnpm" -ErrorAction SilentlyContinue)) {
    Write-Log "Installing pnpm..." "Yellow"
    Start-Process cmd -ArgumentList "/c npm install -g pnpm" -Wait -NoNewWindow
    Refresh-Env
}

# ========= 3. SELF-UPDATE SCRIPT =========

$updateFolder = "$env:APPDATA\BetterDiscord AutoUpdater"
$localScriptPath = Join-Path $updateFolder "BetterDiscordUpdate.ps1"
$remoteScriptURL = "https://raw.githubusercontent.com/MLNekit/BetterDiscordAutoUpdater/main/BetterDiscordUpdate.ps1"

if (-not (Test-Path $updateFolder)) { New-Item -ItemType Directory -Path $updateFolder -Force | Out-Null }

try {
    $remoteContent = (Invoke-WebRequest $remoteScriptURL -UseBasicParsing -TimeoutSec 5).Content
    if (-not (Test-Path $localScriptPath) -or (Get-Content $localScriptPath -Raw) -ne $remoteContent) {
        [System.IO.File]::WriteAllText($localScriptPath, $remoteContent)
        Write-Log "Updater script updated to the latest version." "Green"
    }
} catch {
    Write-Log "Could not check for script updates (skipping)." "Gray"
}

# ========= 4. UPDATE BETTERDISCORD REPOSITORY =========

$repoFolder = Join-Path $updateFolder "BetterDiscordRepo"

if (-not (Test-Path $repoFolder)) {
    Write-Log "Cloning BetterDiscord repository..." "Cyan"
    git clone "https://github.com/BetterDiscord/BetterDiscord.git" $repoFolder
} else {
    Write-Log "Checking for repository updates..." "Cyan"
    Set-Location $repoFolder
    Start-Process git -ArgumentList "pull" -Wait -NoNewWindow
}

# ========= 5. CREATE START MENU SHORTCUT =========

$shortcutPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\BetterDiscord AutoUpdater.lnk"
if (-not (Test-Path $shortcutPath)) {
    Write-Log "Creating Start Menu shortcut..." "Gray"
    $wshShell = New-Object -ComObject WScript.Shell
    $shortcut = $wshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$localScriptPath`""
    $shortcut.IconLocation = "$env:LOCALAPPDATA\Discord\app.ico"
    $shortcut.Save()
}

# ========= 6. BUILD AND INJECT (NON-INTERACTIVE) =========

Set-Location $repoFolder
Write-Log "Starting Build & Inject process..." "Magenta"
Refresh-Env

try {
    # Fix for pnpm v10: Automatically allow build scripts to prevent interactive prompt
    Write-Log "Configuring pnpm to allow build scripts automatically..." "Gray"
    Start-Process cmd -ArgumentList "/c pnpm config set only-built-dependencies @parcel/watcher,electron,esbuild --location project" -Wait -NoNewWindow

    # Install dependencies
    Write-Log "Step 1: pnpm install" "Gray"
    $p1 = Start-Process cmd -ArgumentList "/c pnpm install" -Wait -NoNewWindow -PassThru
    if ($p1.ExitCode -ne 0) { throw "Error during pnpm install" }

    # Build
    Write-Log "Step 2: pnpm build" "Gray"
    $p2 = Start-Process cmd -ArgumentList "/c pnpm build" -Wait -NoNewWindow -PassThru
    if ($p2.ExitCode -ne 0) { throw "Error during build (pnpm build)." }

    # Inject
    Write-Log "Step 3: pnpm inject" "Gray"
    # Note: Use 'inject' command directly
    $p3 = Start-Process cmd -ArgumentList "/c pnpm run inject" -Wait -NoNewWindow -PassThru
    if ($p3.ExitCode -ne 0) { throw "Error during injection (pnpm inject)" }

    Write-Log "SUCCESS: BetterDiscord successfully installed/updated!" "Green"
} catch {
    Write-Log "CRITICAL ERROR: $_" "Red"
    Write-Host "Please try running the script again. If the issue persists, delete '$repoFolder'." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit
}

# ========= 7. LAUNCH DISCORD =========

$discordLauncher = "$env:LOCALAPPDATA\Discord\Update.exe"
if (Test-Path $discordLauncher) {
    Write-Log "Launching Discord..." "Green"
    Start-Process $discordLauncher -ArgumentList "--processStart", "Discord.exe"
}

Write-Log "Done! Script will exit in 3 seconds." "Cyan"
Start-Sleep -Seconds 3
