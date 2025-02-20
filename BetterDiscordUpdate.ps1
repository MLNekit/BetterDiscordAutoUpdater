<#
    BetterDiscord Auto-Updater Script
    Updated: 2025-02-20

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

# ========= 0. ELEVATION CHECK =========
function Test-Administrator {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if (-not (Test-Administrator)) {
    Write-Host "Relaunching with administrator privileges..."
    Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

# ========= 1. CHECK DISCORD INSTALLATION =========
$discordInstallPath = Join-Path $env:LOCALAPPDATA "Discord"
if (-not (Test-Path $discordInstallPath)) {
    Write-Host "Discord is not installed. Downloading and installing..."
    $discordInstaller = "$env:TEMP\DiscordSetup.exe"
    Invoke-WebRequest "https://discord.com/api/download?platform=win" -OutFile $discordInstaller
    Start-Process -FilePath $discordInstaller -ArgumentList "--silent" -Wait
    Read-Host -Prompt "Press ENTER to continue once installation is complete"
}

# ========= 2. TERMINATE DISCORD =========
$discordProcess = Get-Process -Name "Discord" -ErrorAction SilentlyContinue
if ($discordProcess) {
    Write-Host "Stopping Discord..."
    Stop-Process -Name "Discord" -Force
    Start-Sleep -Seconds 2
}

# ========= 3. INSTALL DEPENDENCIES =========
function Install-Dependency {
    param (
        [string]$command, [string]$url, [string]$installerArgs = ""
    )
    
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        Write-Host "$command not found. Installing..."
        $installerPath = "$env:TEMP\$($command)-installer"
        Invoke-WebRequest $url -OutFile $installerPath
        if ($installerArgs) {
            Start-Process -FilePath $installerPath -ArgumentList $installerArgs -Wait
        } else {
            Invoke-Expression (Get-Content $installerPath -Raw)
        }
    }
}

Install-Dependency "git" ((Invoke-RestMethod "https://api.github.com/repos/git-for-windows/git/releases/latest").assets | Where-Object name -match "64-bit.exe" | Select-Object -ExpandProperty browser_download_url) "/VERYSILENT"
Install-Dependency "node" "https://nodejs.org/dist/latest/win-x64/node.exe" "/quiet /norestart"
Install-Dependency "pnpm" "https://get.pnpm.io/install.ps1"
Install-Dependency "bun" "https://bun.sh/install.ps1"

# ========= 4. UPDATE SCRIPT =========
$updateScriptFolder = Join-Path $env:APPDATA "BetterDiscord Update Script"
$localScriptPath = Join-Path $updateScriptFolder "BetterDiscordUpdate.ps1"
$remoteScriptURL = "https://raw.githubusercontent.com/MLNekit/BetterDiscordAutoUpdater/main/BetterDiscordUpdate.ps1"

if (-not (Test-Path $updateScriptFolder)) { New-Item -ItemType Directory -Path $updateScriptFolder -Force | Out-Null }
$remoteContent = (Invoke-WebRequest $remoteScriptURL -UseBasicParsing).Content
if (-not (Test-Path $localScriptPath) -or (Get-Content $localScriptPath -Raw) -ne $remoteContent) {
    $remoteContent | Out-File -FilePath $localScriptPath -Encoding utf8
    Write-Host "Updater script updated."
}

# ========= 5. CLONE/UPDATE BETTERDISCORD REPO =========
$repoFolder = Join-Path $updateScriptFolder "BetterDiscord"
if (-not (Test-Path $repoFolder)) {
    git clone "https://github.com/BetterDiscord/BetterDiscord.git" $repoFolder
} else {
    Push-Location $repoFolder
    git pull
    Pop-Location
}

# ========= 6. CREATE START MENU SHORTCUT =========
$startMenuFolder = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs"
$shortcutPath = Join-Path $startMenuFolder "BetterDiscord Update.lnk"
if (-not (Test-Path $shortcutPath)) {
    $wshShell = New-Object -ComObject WScript.Shell
    $shortcut = $wshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$localScriptPath`""
    $shortcut.Save()
}

# ========= 7. ENSURE BETTERDISCORD FOLDER EXISTS =========
$betterDiscordFolder = Join-Path $env:APPDATA "BetterDiscord"
if (-not (Test-Path $betterDiscordFolder)) { New-Item -ItemType Directory -Path $betterDiscordFolder -Force | Out-Null }

# ========= 8. INSTALL, BUILD, AND INJECT =========
Push-Location $repoFolder
npm install -g pnpm
pnpm install
pnpm build
pnpm inject
Pop-Location

# ========= 9. LAUNCH DISCORD =========
$discordUpdater = Join-Path $env:LOCALAPPDATA "Discord\Update.exe"
if (Test-Path $discordUpdater) {
    Start-Process -FilePath $discordUpdater -ArgumentList "--processStart", "Discord.exe"
}

Write-Host "BetterDiscord installation/update completed!"
