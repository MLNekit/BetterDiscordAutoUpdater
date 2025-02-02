# BetterDiscordUpdate.ps1
# This script updates BetterDiscord by checking for dependencies, updating the repository,
# and then installing/injecting BetterDiscord. It also creates an update shortcut.

# --- Function: Relaunch as Administrator if not already ---
function Ensure-RunAsAdmin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "Restarting script with administrative privileges..."
        Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        Exit
    }
}
Ensure-RunAsAdmin

# --- Step 1: Check if Discord is running; if not, install silently and then prompt user ---
Write-Host "`n[Step 1] Checking Discord process status..."
$discordProcess = Get-Process -Name "Discord" -ErrorAction SilentlyContinue
if ($discordProcess) {
    Write-Host "Discord is currently running. Closing Discord..."
    Stop-Process -Name "Discord" -Force
    Start-Sleep -Seconds 2
} else {
    Write-Host "Discord is not running. Installing Discord silently..."
    # Download the Discord installer (adjust URL and silent parameters as needed)
    $discordInstaller = "$env:TEMP\DiscordSetup.exe"
    try {
        Invoke-WebRequest "https://discord.com/api/download?platform=win" -OutFile $discordInstaller
    }
    catch {
        Write-Error "Failed to download Discord installer. Check your internet connection."
        Pause
        Exit
    }
    Write-Host "Launching Discord installer in silent mode..."
    Start-Process -FilePath $discordInstaller -ArgumentList "/S" -Wait

    # Discord may auto-launch after install; prompt user to close it
    Write-Host "If Discord installation has finished and Discord has launched, press ENTER to continue. This will terminate Discord and resume the update."
    Read-Host "Press ENTER to continue"
    
    # After the prompt, ensure Discord is not running
    $discordProcess = Get-Process -Name "Discord" -ErrorAction SilentlyContinue
    if ($discordProcess) {
        Write-Host "Closing Discord..."
        Stop-Process -Name "Discord" -Force
        Start-Sleep -Seconds 2
    }
}

# --- Step 2: Check for required dependencies: Git, Node.js, and pnpm ---
Write-Host "`n[Step 2] Checking dependencies..."

# Check for Git
Write-Host "Checking for Git..."
$gitInstalled = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitInstalled) {
    Write-Host "Git is not installed. Installing Git..."
    $gitInstaller = "$env:TEMP\git-installer.exe"
    try {
        Invoke-WebRequest "https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.2/Git-2.47.1.2-64-bit.exe" -OutFile $gitInstaller
    }
    catch {
        Write-Error "Failed to download Git installer."
        Pause
        Exit
    }
    Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT" -Wait
    Write-Host "Git has been installed."
} else {
    Write-Host "Git is installed."
}

# Check for Node.js
Write-Host "Checking for Node.js..."
$nodeInstalled = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodeInstalled) {
    Write-Host "Node.js is not installed. Installing Node.js..."
    $nodeInstaller = "$env:TEMP\node-installer.msi"
    try {
        Invoke-WebRequest "https://nodejs.org/dist/v22.13.1/node-v22.13.1-x64.msi" -OutFile $nodeInstaller
    }
    catch {
        Write-Error "Failed to download Node.js installer."
        Pause
        Exit
    }
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", "`"$nodeInstaller`"", "/quiet", "/norestart" -Wait
    Write-Host "Node.js has been installed."
} else {
    Write-Host "Node.js is installed."
}

# Check for pnpm
Write-Host "Checking for pnpm..."
$pnpmInstalled = Get-Command pnpm -ErrorAction SilentlyContinue
if (-not $pnpmInstalled) {
    Write-Host "pnpm is not installed. Installing pnpm..."
    try {
        Invoke-WebRequest "https://get.pnpm.io/install.ps1" -UseBasicParsing | Invoke-Expression
    }
    catch {
        Write-Error "Failed to install pnpm."
        Pause
        Exit
    }
    Write-Host "pnpm has been installed."
} else {
    Write-Host "pnpm is installed."
}

# Confirm that all dependencies are now available
if (-not (Get-Command git -ErrorAction SilentlyContinue) -or
    -not (Get-Command node -ErrorAction SilentlyContinue) -or
    -not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
    Write-Host "One or more dependencies are missing. Please restart the script."
    Pause
    Exit
}
Write-Host "All dependencies are installed."

# --- Step 3: Check and update the local update script folder ---
Write-Host "`n[Step 3] Checking update script folder..."
$updateScriptFolder = Join-Path $env:APPDATA "BetterDiscord Update Script"
if (-not (Test-Path $updateScriptFolder)) {
    Write-Host "Creating update script folder at $updateScriptFolder..."
    New-Item -Path $updateScriptFolder -ItemType Directory -Force | Out-Null
} else {
    Write-Host "Update script folder exists."
}

$localScriptPath = Join-Path $updateScriptFolder "BetterDiscordUpdate.ps1"
$remoteScriptUrl = "https://raw.githubusercontent.com/MLNekit/BetterDiscordAutoUpdater/main/BetterDiscordUpdate.ps1"
$downloadNewScript = $true
if (Test-Path $localScriptPath) {
    Write-Host "Comparing local update script with the remote version..."
    try {
        $localContent = Get-Content $localScriptPath -Raw
        $remoteContent = (Invoke-WebRequest -Uri $remoteScriptUrl -UseBasicParsing).Content
        if ($localContent -eq $remoteContent) {
            Write-Host "Local update script is up-to-date."
            $downloadNewScript = $false
        }
        else {
            Write-Host "Local update script is outdated. Updating..."
        }
    }
    catch {
        Write-Host "Error comparing scripts. Updating local copy..."
    }
}
if ($downloadNewScript) {
    try {
        Invoke-WebRequest -Uri $remoteScriptUrl -OutFile $localScriptPath -UseBasicParsing
        Write-Host "Update script has been downloaded/updated."
    }
    catch {
        Write-Error "Failed to download the update script."
        Pause
        Exit
    }
}

# --- Step 4: Check and update the BetterDiscord repository ---
Write-Host "`n[Step 4] Checking BetterDiscord repository..."
$repoPath = Join-Path $updateScriptFolder "BetterDiscord"
if (-not (Test-Path $repoPath)) {
    Write-Host "Repository not found. Cloning BetterDiscord repository..."
    Push-Location $updateScriptFolder
    git clone "https://github.com/BetterDiscord/BetterDiscord.git" "BetterDiscord"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Repository has been cloned successfully."
    }
    else {
        Write-Error "Failed to clone the repository. Check your internet connection."
        Pause
        Exit
    }
    Pop-Location
} else {
    Write-Host "Repository exists. Updating repository..."
    Push-Location $repoPath
    git pull
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Repository has been updated successfully."
    }
    else {
        Write-Error "Failed to update the repository."
        Pause
        Exit
    }
    Pop-Location
}

# --- Step 5: Check and create the update shortcut in the Start Menu ---
Write-Host "`n[Step 5] Checking for update shortcut in Start Menu..."
$shortcutPath = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\BetterDiscord Update.lnk"
if (-not (Test-Path $shortcutPath)) {
    Write-Host "Creating shortcut 'BetterDiscord Update'..."
    $wshShell = New-Object -ComObject WScript.Shell
    $shortcut = $wshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "powershell.exe"
    # Note: Using the local update script path for the shortcut
    $shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$localScriptPath`""
    $shortcut.WorkingDirectory = Split-Path $localScriptPath
    $shortcut.IconLocation = "powershell.exe, 0"
    $shortcut.Save()
    Write-Host "Shortcut created."
} else {
    Write-Host "Update shortcut already exists."
}

# --- Step 6: Ensure BetterDiscord configuration folder exists ---
Write-Host "`n[Step 6] Checking for BetterDiscord configuration folder..."
$betterDiscordConfigPath = Join-Path $env:APPDATA "BetterDiscord"
if (-not (Test-Path $betterDiscordConfigPath)) {
    Write-Host "Creating BetterDiscord folder at $betterDiscordConfigPath..."
    New-Item -Path $betterDiscordConfigPath -ItemType Directory -Force | Out-Null
} else {
    Write-Host "BetterDiscord folder exists."
}

# --- Step 7: Install and build BetterDiscord in the repository folder ---
Write-Host "`n[Step 7] Installing dependencies and building BetterDiscord..."
Push-Location $repoPath
# Install pnpm globally using npm
Write-Host "Installing pnpm globally..."
npm install -g pnpm
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to install pnpm globally."
    Pause
    Exit
}

# Install repository dependencies, build, and inject BetterDiscord
Write-Host "Installing repository dependencies..."
pnpm install
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to install repository dependencies."
    Pause
    Exit
}

Write-Host "Building the project..."
pnpm build
if ($LASTEXITCODE -ne 0) {
    Write-Error "Project build failed."
    Pause
    Exit
}

Write-Host "Injecting BetterDiscord..."
pnpm inject
if ($LASTEXITCODE -ne 0) {
    Write-Error "Injection failed."
    Pause
    Exit
}
Pop-Location

# --- Step 8: Launch Discord (non-console) ---
Write-Host "`n[Step 8] Launching Discord..."
$discordLauncher = Join-Path $env:USERPROFILE "AppData\Local\Discord\Update.exe"
if (Test-Path $discordLauncher) {
    Start-Process -FilePath $discordLauncher -ArgumentList "--processStart", "Discord.exe" -WindowStyle Normal
    Write-Host "Discord is launching..."
}
else {
    Write-Error "Discord launcher not found. Please check the installation."
}

Write-Host "`nBetterDiscord installation completed successfully!"
Start-Sleep -Seconds 3
Exit
