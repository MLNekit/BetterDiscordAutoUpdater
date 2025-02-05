<#
    BetterDiscord Auto-Updater Script
    Updated: 2025-02-05

    This script performs the following steps:
    0. If Discord is not installed, installs it silently and prompts the user to press ENTER when ready.
    1. Checks if Discord is running; if so, terminates the process.
    2. Checks and installs dependencies (Git, Node.js, pnpm, Bun).
    3. Ensures the update script folder exists and updates the script file if needed.
    4. Clones or updates the BetterDiscord repository.
    5. Creates a Start Menu shortcut for this updater.
    6. Ensures the BetterDiscord folder exists.
    7. In the repository folder, runs: npm install -g pnpm, pnpm install, pnpm build, pnpm inject.
    8. Launches Discord.
#>

# ========= 0. ELEVATION CHECK =========
# Function to check if the current session is running with administrator rights
function Test-Administrator {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if (-not (Test-Administrator)) {
    Write-Host "Script is not running as administrator. Relaunching with elevated privileges..."
    Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

# ========= 0. CHECK IF DISCORD IS INSTALLED =========
# We assume Discord is installed if the Discord folder exists in LocalAppData
$discordInstallPath = Join-Path $env:LOCALAPPDATA "Discord"
if (-not (Test-Path $discordInstallPath)) {
    Write-Host "Discord is not installed. Downloading and installing Discord silently..."

    # Download Discord installer
    $discordInstaller = "$env:TEMP\DiscordSetup.exe"
    # The official Discord download link for Windows:
    Invoke-WebRequest "https://discord.com/api/download?platform=win" -OutFile $discordInstaller

    # Run the installer silently (Discord supports a silent install switch)
    Start-Process -FilePath $discordInstaller -ArgumentList "--silent" -Wait

    Write-Host "Discord installation initiated. Discord may launch automatically."
    Write-Host "If the Discord installation is complete and you wish to continue, press ENTER."
    Read-Host -Prompt "Press ENTER to continue"
}
else {
    Write-Host "Discord is installed."
}

# ========= 1. TERMINATE DISCORD IF RUNNING =========
$discordProcess = Get-Process -Name "Discord" -ErrorAction SilentlyContinue
if ($discordProcess) {
    Write-Host "Discord is running. Terminating Discord..."
    Stop-Process -Name "Discord" -Force
    Start-Sleep -Seconds 2
} else {
    Write-Host "Discord is not running."
}

# ========= 2. CHECK AND INSTALL DEPENDENCIES =========

# --- Check for Git ---
Write-Host "Checking for Git..."
$gitInstalled = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitInstalled) {
    Write-Host "Git is not installed. Installing Git..."
    $gitInstaller = "$env:TEMP\git-installer.exe"
    Invoke-WebRequest "https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.2/Git-2.47.1.2-64-bit.exe" -OutFile $gitInstaller
    Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT" -Wait
    Write-Host "Git has been installed."
} else {
    Write-Host "Git is installed."
}

# --- Check for Node.js ---
Write-Host "Checking for Node.js..."
$nodeInstalled = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodeInstalled) {
    Write-Host "Node.js is not installed. Installing Node.js..."
    $nodeInstaller = "$env:TEMP\node-installer.msi"
    Invoke-WebRequest "https://nodejs.org/dist/v22.13.1/node-v22.13.1-x64.msi" -OutFile $nodeInstaller
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", "`"$nodeInstaller`"", "/quiet", "/norestart" -Wait
    Write-Host "Node.js has been installed."
} else {
    Write-Host "Node.js is installed."
}

# --- Check for pnpm ---
Write-Host "Checking for pnpm..."
$pnpmInstalled = Get-Command pnpm -ErrorAction SilentlyContinue
if (-not $pnpmInstalled) {
    Write-Host "pnpm is not installed. Installing pnpm..."
    Invoke-WebRequest "https://get.pnpm.io/install.ps1" -UseBasicParsing | Invoke-Expression
    Write-Host "pnpm has been installed."
} else {
    Write-Host "pnpm is installed."
}

# --- Check for Bun ---
Write-Host "Checking for Bun..."
$bunInstalled = Get-Command bun -ErrorAction SilentlyContinue
if (-not $bunInstalled) {
    Write-Host "Bun is not installed. Installing Bun..."
    Start-Process -FilePath "powershell.exe" -ArgumentList "-c", "irm bun.sh/install.ps1 | iex" -Wait
    Write-Host "Bun has been installed."
} else {
    Write-Host "Bun is installed."
}

# Verify all dependencies are now available
if (-not (Get-Command git -ErrorAction SilentlyContinue) -or `
    -not (Get-Command node -ErrorAction SilentlyContinue) -or `
    -not (Get-Command pnpm -ErrorAction SilentlyContinue) -or `
    -not (Get-Command bun -ErrorAction SilentlyContinue)) {
    Write-Host "One or more dependencies failed to install. Please restart the script."
    Pause
    Exit
}

Write-Host "All dependencies are installed."

# ========= 3. ENSURE UPDATE SCRIPT FOLDER EXISTS AND UPDATE SCRIPT =========
$updateScriptFolder = Join-Path $env:APPDATA "Roaming\BetterDiscord Update Script"
if (-not (Test-Path $updateScriptFolder)) {
    Write-Host "Creating BetterDiscord Update Script folder..."
    New-Item -ItemType Directory -Path $updateScriptFolder -Force | Out-Null
} else {
    Write-Host "Update script folder exists."
}

# Define the local script file path and the remote URL for the auto-updater script.
$localScriptPath = Join-Path $updateScriptFolder "BetterDiscordUpdate.ps1"
$remoteScriptURL = "https://raw.githubusercontent.com/MLNekit/BetterDiscordAutoUpdater/main/BetterDiscordUpdate.ps1"

# Download remote script content
try {
    $remoteScriptContent = Invoke-WebRequest $remoteScriptURL -UseBasicParsing -ErrorAction Stop
    $remoteContent = $remoteScriptContent.Content
} catch {
    Write-Host "Failed to download remote update script. Please check your internet connection."
    Pause
    Exit
}

# If the file does not exist or its content differs from the remote version, update it.
$updateScriptNeeded = $true
if (Test-Path $localScriptPath) {
    $localContent = Get-Content $localScriptPath -Raw
    if ($localContent -eq $remoteContent) {
        Write-Host "The local update script is already the latest version."
        $updateScriptNeeded = $false
    }
}

if ($updateScriptNeeded) {
    Write-Host "Updating the BetterDiscord update script..."
    $remoteContent | Out-File -FilePath $localScriptPath -Encoding utf8
}

# ========= 4. CLONE OR UPDATE THE BETTERDISCORD REPOSITORY =========
$repoFolder = Join-Path $updateScriptFolder "BetterDiscord"
if (-not (Test-Path $repoFolder)) {
    Write-Host "Cloning the BetterDiscord repository..."
    git clone "https://github.com/BetterDiscord/BetterDiscord.git" $repoFolder
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Repository cloned successfully."
    } else {
        Write-Host "Failed to clone the repository. Check your internet connection."
        Pause
        Exit
    }
} else {
    Write-Host "BetterDiscord repository exists. Updating repository..."
    Push-Location $repoFolder
    git pull
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Repository updated successfully."
    } else {
        Write-Host "Failed to update the repository. Check your internet connection."
        Pop-Location
        Pause
        Exit
    }
    Pop-Location
}

# ========= 5. CREATE A START MENU SHORTCUT =========
$startMenuFolder = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs"
$shortcutPath = Join-Path $startMenuFolder "BetterDiscord Update.lnk"
if (-not (Test-Path $shortcutPath)) {
    Write-Host "Creating Start Menu shortcut for BetterDiscord Update..."
    $target = "powershell.exe"
    # Use the local update script file in the shortcut target
    $arguments = "-ExecutionPolicy Bypass -File `"$localScriptPath`""

    $wshShell = New-Object -ComObject WScript.Shell
    $shortcut = $wshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $target
    $shortcut.Arguments = $arguments
    $shortcut.WindowStyle = 1
    $shortcut.Description = "BetterDiscord Auto-Updater Script"
    $shortcut.Save()
    Write-Host "Shortcut created successfully."
} else {
    Write-Host "Start Menu shortcut already exists."
}

# ========= 6. ENSURE THE BETTERDISCORD FOLDER EXISTS =========
$betterDiscordFolder = Join-Path $env:APPDATA "Roaming\BetterDiscord"
if (-not (Test-Path $betterDiscordFolder)) {
    Write-Host "Creating BetterDiscord folder..."
    New-Item -ItemType Directory -Path $betterDiscordFolder -Force | Out-Null
} else {
    Write-Host "BetterDiscord folder exists."
}

# ========= 7. INSTALL DEPENDENCIES, BUILD, AND INJECT =========
# Change directory to the repository folder
Push-Location $repoFolder

Write-Host "Installing pnpm globally via npm..."
npm install -g pnpm
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to install pnpm globally."
    Pop-Location
    Pause
    Exit
}

Write-Host "Installing project dependencies using pnpm..."
pnpm install
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to install dependencies."
    Pop-Location
    Pause
    Exit
}

Write-Host "Building the project using pnpm..."
pnpm build
if ($LASTEXITCODE -ne 0) {
    Write-Host "Project build failed."
    Pop-Location
    Pause
    Exit
}

Write-Host "Injecting BetterDiscord into Discord using pnpm..."
pnpm inject
if ($LASTEXITCODE -ne 0) {
    Write-Host "Injection failed."
    Pop-Location
    Pause
    Exit
}
Pop-Location

# ========= 8. LAUNCH DISCORD =========
Write-Host "Launching Discord..."
# Launch Discord via its updater executable so that it starts normally (without a console)
$discordUpdater = Join-Path $env:LOCALAPPDATA "Discord\Update.exe"
if (Test-Path $discordUpdater) {
    Start-Process -FilePath $discordUpdater -ArgumentList "--processStart", "Discord.exe"
} else {
    Write-Host "Discord updater not found. Please check your Discord installation."
}

Write-Host "BetterDiscord installation/update completed successfully!"
Start-Sleep -Seconds 3
Exit
