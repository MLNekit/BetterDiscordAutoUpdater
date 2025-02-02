# BetterDiscord Update Script
# This script updates BetterDiscord by performing several steps:
# 1. Checks if Discord is running, and if so, kills it; if not, installs it silently.
# 2. Checks for required dependencies (git, node.js, and pnpm) and installs them if missing.
# 3. Ensures the update script folder exists and updates the local script if an update is available.
# 4. Clones or updates the BetterDiscord repository.
# 5. Creates a Start Menu shortcut for this update script if one does not exist.
# 6. Ensures the BetterDiscord folder exists.
# 7. Runs build and injection commands in the repository folder.
# 8. Launches Discord.

# ------------------------------
# Step 1: Check if Discord is running

# Try to get the Discord process
$discordProcess = Get-Process -Name discord -ErrorAction SilentlyContinue
if ($discordProcess) {
    Write-Output "Discord is running. Stopping Discord..."
    # Kill all Discord processes
    Stop-Process -Name discord -Force
} else {
    Write-Output "Discord is not running. Installing Discord silently..."
    # Download the Discord installer.
    # Note: The installer URL and silent parameters may change over time.
    $installerUrl = "https://discord.com/api/download?platform=win"
    $installerPath = "$env:TEMP\DiscordSetup.exe"
    Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
    # Run the installer silently. (The /S switch is assumed for silent install.)
    Start-Process -FilePath $installerPath -ArgumentList "/S" -Wait
}

# ------------------------------
# Step 2: Check for dependencies (git, node.js, pnpm)

# Function to check for a command and install using winget if not found.
function Ensure-Dependency {
    param(
        [string]$CommandName,
        [string]$WingetId,   # The Winget package identifier
        [string]$InstallArgs = "--silent"
    )
    if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
        Write-Output "$CommandName not found. Installing $CommandName..."
        winget install --id $WingetId -e $InstallArgs
    }
    else {
        Write-Output "$CommandName is already installed."
    }
}

# Check and install Git
Ensure-Dependency -CommandName "git" -WingetId "Git.Git"

# Check and install Node.js (which includes npm)
Ensure-Dependency -CommandName "node" -WingetId "OpenJS.NodeJS"

# Check for pnpm. If not available, install via npm.
if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
    Write-Output "pnpm not found. Installing pnpm globally via npm..."
    npm install -g pnpm
} else {
    Write-Output "pnpm is already installed."
}

# ------------------------------
# Step 3: Ensure the update script folder exists and update the script file if needed

$updateScriptDir = "$env:USERPROFILE\AppData\Roaming\BetterDiscord Update Script"
if (-not (Test-Path $updateScriptDir)) {
    Write-Output "Creating update script directory at: $updateScriptDir"
    New-Item -ItemType Directory -Path $updateScriptDir | Out-Null
} else {
    Write-Output "Update script directory already exists."
}

$localScriptPath = Join-Path $updateScriptDir "BetterDiscordUpdate.ps1"
$remoteScriptUrl = "https://raw.githubusercontent.com/MLNekit/BetterDiscordAutoUpdater/main/BetterDiscordUpdate.ps1"

# Download remote script content
try {
    $remoteResponse = Invoke-WebRequest -Uri $remoteScriptUrl -UseBasicParsing
    $remoteContent = $remoteResponse.Content
} catch {
    Write-Error "Failed to download remote script from $remoteScriptUrl"
    exit 1
}

# If local script exists, compare its SHA256 hash with the remote version.
if (Test-Path $localScriptPath) {
    $localHashObj = Get-FileHash -Path $localScriptPath -Algorithm SHA256
    # Compute SHA256 hash of the remote content
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $remoteBytes = [System.Text.Encoding]::UTF8.GetBytes($remoteContent)
    $remoteHashBytes = $sha256.ComputeHash($remoteBytes)
    $remoteHash = ([System.BitConverter]::ToString($remoteHashBytes)).Replace("-", "")
    if ($localHashObj.Hash -ne $remoteHash) {
        Write-Output "Local script is outdated. Updating the script..."
        $remoteContent | Out-File -FilePath $localScriptPath -Encoding utf8
    } else {
        Write-Output "Local script is up-to-date."
    }
} else {
    Write-Output "Local script not found. Downloading the script..."
    $remoteContent | Out-File -FilePath $localScriptPath -Encoding utf8
}

# ------------------------------
# Step 4: Clone or update the BetterDiscord repository

$bdRepoDir = Join-Path $updateScriptDir "BetterDiscord"
if (-not (Test-Path $bdRepoDir)) {
    Write-Output "BetterDiscord repository not found. Cloning repository..."
    git clone https://github.com/BetterDiscord/BetterDiscord.git $bdRepoDir
} else {
    Write-Output "BetterDiscord repository found. Updating repository..."
    Push-Location $bdRepoDir
    git pull
    Pop-Location
}

# ------------------------------
# Step 5: Create Start Menu shortcut if not exists

$shortcutPath = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\BetterDiscord Update.lnk"
if (-not (Test-Path $shortcutPath)) {
    Write-Output "Creating Start Menu shortcut for BetterDiscord Update..."
    $wshell = New-Object -ComObject WScript.Shell
    $shortcut = $wshell.CreateShortcut($shortcutPath)
    # Set the target to PowerShell with parameters to bypass execution policy and run this script
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$localScriptPath`""
    $shortcut.WorkingDirectory = $updateScriptDir
    $shortcut.IconLocation = "powershell.exe, 0"
    $shortcut.Save()
} else {
    Write-Output "Start Menu shortcut already exists."
}

# ------------------------------
# Step 6: Ensure the BetterDiscord folder exists

$bdFolder = "$env:USERPROFILE\AppData\Roaming\BetterDiscord"
if (-not (Test-Path $bdFolder)) {
    Write-Output "Creating BetterDiscord folder at: $bdFolder"
    New-Item -ItemType Directory -Path $bdFolder | Out-Null
} else {
    Write-Output "BetterDiscord folder already exists."
}

# ------------------------------
# Step 7: Build and inject BetterDiscord

Write-Output "Installing pnpm globally (if needed) and running build steps..."
Push-Location $bdRepoDir

# (Re)install pnpm globally via npm to ensure it is available.
npm install -g pnpm

# Install repository dependencies and build/inject BetterDiscord
pnpm install
pnpm build
pnpm inject

Pop-Location

# ------------------------------
# Step 8: Launch Discord (without showing the console)

Write-Output "Launching Discord..."
# Attempt to start Discord using Start-Process.
# Adjust the path or method if Discord is installed elsewhere.
try {
    # If Discord is installed in a standard location, you might adjust the path.
    # Here we simply call "discord" so that the system can resolve it.
    Start-Process "discord"
} catch {
    Write-Error "Failed to launch Discord."
}
