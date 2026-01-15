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

function Refresh-EnvironmentVariables {
    # Refreshes the PATH variable in the current session without restarting
    Write-Log "Refreshing environment variables..." "Gray"
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:PATH = "$machinePath;$userPath"
}

# ========= 0. ELEVATION CHECK =========
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Log "Requesting Administrator privileges..." "Yellow"
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# ========= 1. CHECK DISCORD INSTALLATION =========
$discordPath = "$env:LOCALAPPDATA\Discord"
if (-not (Test-Path $discordPath)) {
    Write-Log "Discord not found. Downloading installer..." "Yellow"
    $discordInstaller = "$env:TEMP\DiscordSetup.exe"
    try {
        Invoke-WebRequest "https://discord.com/api/download?platform=win" -OutFile $discordInstaller
        Write-Log "Installing Discord..." "Yellow"
        Start-Process -FilePath $discordInstaller -ArgumentList "--silent" -Wait
        Write-Log "Discord installed." "Green"
    } catch {
        Write-Log "Failed to install Discord: $_" "Red"
        exit
    }
}

# ========= 2. TERMINATE DISCORD PROCESSES =========
$procNames = @("Discord", "DiscordCanary", "DiscordPTB")
$running = Get-Process -Name $procNames -ErrorAction SilentlyContinue
if ($running) {
    Write-Log "Closing Discord processes..." "Yellow"
    Stop-Process -InputObject $running -Force
    Start-Sleep -Seconds 2
}

# ========= 3. INSTALL DEPENDENCIES =========
$depsUpdated = $false

# 3.1 Check/Install Git
if (-not (Get-Command "git" -ErrorAction SilentlyContinue)) {
    Write-Log "Git not found. Installing..." "Yellow"
    $gitUrl = (Invoke-RestMethod "https://api.github.com/repos/git-for-windows/git/releases/latest").assets | Where-Object name -match "64-bit.exe" | Select-Object -ExpandProperty browser_download_url -First 1
    $gitInstaller = "$env:TEMP\git-install.exe"
    Invoke-WebRequest $gitUrl -OutFile $gitInstaller
    Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT", "/NORESTART" -Wait
    $depsUpdated = $true
}

# 3.2 Check/Install Node.js (via MSI to get NPM)
if (-not (Get-Command "node" -ErrorAction SilentlyContinue)) {
    Write-Log "Node.js not found. Installing..." "Yellow"
    # Downloading latest LTS MSI
    $nodeUrl = "https://nodejs.org/dist/v20.11.0/node-v20.11.0-x64.msi" # Можно парсить сайт, но LTS ссылка надежнее
    $nodeInstaller = "$env:TEMP\node-install.msi"
    Invoke-WebRequest $nodeUrl -OutFile $nodeInstaller
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$nodeInstaller`" /quiet /norestart" -Wait
    $depsUpdated = $true
}

# 3.3 Refresh Path if anything was installed
if ($depsUpdated) {
    Refresh-EnvironmentVariables
}

# 3.4 Install pnpm (using npm is safer/standard for BD)
if (-not (Get-Command "pnpm" -ErrorAction SilentlyContinue)) {
    Write-Log "Installing pnpm..." "Yellow"
    try {
        # Sometimes npm is not yet available even after path refresh in rare cases, so we explicitly call the binary if needed, 
        # but usually Refresh-Env works.
        npm install -g pnpm
    } catch {
        Write-Log "Error installing pnpm via npm. Attempting standalone script..." "Red"
        Invoke-WebRequest "https://get.pnpm.io/install.ps1" -UseBasicParsing | Invoke-Expression
        Refresh-EnvironmentVariables
    }
}

# ========= 4. SELF-UPDATE SCRIPT =========
$updateScriptFolder = "$env:APPDATA\BetterDiscord AutoUpdater"
$localScriptPath = Join-Path $updateScriptFolder "BetterDiscordUpdate.ps1"
$remoteScriptURL = "https://raw.githubusercontent.com/MLNekit/BetterDiscordAutoUpdater/main/BetterDiscordUpdate.ps1"

if (-not (Test-Path $updateScriptFolder)) { New-Item -ItemType Directory -Path $updateScriptFolder -Force | Out-Null }

try {
    $remoteContent = (Invoke-WebRequest $remoteScriptURL -UseBasicParsing).Content
    # Check if file exists and differs
    if (-not (Test-Path $localScriptPath) -or (Get-Content $localScriptPath -Raw) -ne $remoteContent) {
        [System.IO.File]::WriteAllText($localScriptPath, $remoteContent)
        Write-Log "Updater script updated to latest version." "Green"
    }
} catch {
    Write-Log "Could not check for script updates (Internet issues?)" "Red"
}

# ========= 5. CLONE/UPDATE BETTERDISCORD REPO =========
$repoFolder = Join-Path $updateScriptFolder "BetterDiscordRepo"

if (-not (Test-Path $repoFolder)) {
    Write-Log "Cloning BetterDiscord repository..." "Cyan"
    git clone "https://github.com/BetterDiscord/BetterDiscord.git" $repoFolder
} else {
    Write-Log "Pulling latest changes..." "Cyan"
    Push-Location $repoFolder
    git pull
    Pop-Location
}

# ========= 6. CREATE SHORTCUT =========
$shortcutPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\BetterDiscord AutoUpdater.lnk"
if (-not (Test-Path $shortcutPath)) {
    Write-Log "Creating Start Menu shortcut..." "Gray"
    $wshShell = New-Object -ComObject WScript.Shell
    $shortcut = $wshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$localScriptPath`""
    $shortcut.IconLocation = "$env:LOCALAPPDATA\Discord\app.ico" # Optional: looks nicer
    $shortcut.Save()
}

# ========= 7. BUILD AND INJECT =========
Write-Log "Starting Build & Inject process..." "Magenta"
Push-Location $repoFolder

try {
    # Ensure dependencies are installed
    Write-Log "Installing repo dependencies (pnpm install)..." "Gray"
    # call pnpm via cmd /c to avoid PowerShell parsing issues with batch files sometimes
    cmd /c "pnpm install"
    
    Write-Log "Building BetterDiscord (pnpm build)..." "Gray"
    cmd /c "pnpm build"

    Write-Log "Injecting into Discord (pnpm inject)..." "Gray"
    # Inject usually asks for target if multiple exist, usually defaults to stable
    cmd /c "pnpm run inject" 

    Write-Log "BetterDiscord successfully injected!" "Green"
} catch {
    Write-Log "An error occurred during build/inject: $_" "Red"
    Read-Host "Press ENTER to exit..."
    exit
} finally {
    Pop-Location
}

# ========= 8. LAUNCH DISCORD =========
$discordUpdater = "$env:LOCALAPPDATA\Discord\Update.exe"
if (Test-Path $discordUpdater) {
    Write-Log "Launching Discord..." "Green"
    Start-Process -FilePath $discordUpdater -ArgumentList "--processStart", "Discord.exe"
} else {
    Write-Log "Could not find Discord launcher." "Red"
}

Write-Log "All done. Exiting in 3 seconds..." "Cyan"
Start-Sleep -Seconds 3
