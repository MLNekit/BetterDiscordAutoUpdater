# Check if Discord is running
$discordProcess = Get-Process -Name "Discord" -ErrorAction SilentlyContinue
if ($discordProcess) {
    Write-Host "Closing Discord..."
    Stop-Process -Name "Discord" -Force
    Start-Sleep -Seconds 2
} else {
    Write-Host "Discord is not running."
}

# Check if Git is installed
Write-Host "Checking for Git..."
$gitInstalled = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitInstalled) {
    Write-Host "Git is not installed. Installing Git..."
    # Download and install Git
    $gitInstaller = "$env:TEMP\git-installer.exe"
    Invoke-WebRequest "https://github.com/git-for-windows/git/releases/download/v2.40.0.windows.1/Git-2.40.0-64-bit.exe" -OutFile $gitInstaller
    Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT" -Wait
    Write-Host "Git has been installed."
} else {
    Write-Host "Git is installed."
}

# Check if Node.js is installed
Write-Host "Checking for Node.js..."
$nodeInstalled = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodeInstalled) {
    Write-Host "Node.js is not installed. Installing Node.js..."
    # Download and install Node.js
    $nodeInstaller = "$env:TEMP\node-installer.msi"
    Invoke-WebRequest "https://nodejs.org/dist/v18.18.2/node-v18.18.2-x64.msi" -OutFile $nodeInstaller
    Start-Process -FilePath $nodeInstaller -ArgumentList "/quiet", "/norestart" -Wait
    Write-Host "Node.js has been installed."
} else {
    Write-Host "Node.js is installed."
}

# Check if pnpm is installed
Write-Host "Checking for pnpm..."
$pnpmInstalled = Get-Command pnpm -ErrorAction SilentlyContinue
if (-not $pnpmInstalled) {
    Write-Host "pnpm not found. Installing pnpm..."
    # Install pnpm
    Invoke-WebRequest "https://get.pnpm.io/install.ps1" -UseBasicPasing | Invoke-Expression
    Write-Host "pnpm has been installed."
} else {
    Write-Host "pnpm is installed."
}

if (-not (Get-Command git -ErrorAction SilentlyContinue) -or
    -not (Get-Command node -ErrorAction SilentlyContinue) -or
    -not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
    
    Write-Host "Please restart the script"
    Pause
    Exit
}

Write-Host "All dependencies are installed."


# Check if the BetterDiscord folder exists
$betterDiscordPath = Join-Path $PSScriptRoot "BetterDiscord"
if (-not (Test-Path $betterDiscordPath)) {
    Write-Host "BetterDiscord folder not found. Cloning the repository..."
    git clone "https://github.com/BetterDiscord/BetterDiscord.git" $betterDiscordPath
    if ($?) {
        Write-Host "BetterDiscord repository has been cloned."
    } else {
        Write-Host "Failed to clone the repository. Check your internet connection."
        Pause
        Exit
    }
} else {
    Write-Host "BetterDiscord folder found."
}

# Change directory to the project folder
Set-Location -Path $betterDiscordPath

# Update the repository
Write-Host "Updating the repository..."
git pull
if ($?) {
    Write-Host "Repository has been updated."
} else {
    Write-Host "Failed to update the repository. Check your internet connection."
    Pause
    Exit
}

# Install dependencies and build the project
Write-Host "Installing dependencies..."
pnpm install
if ($?) {
    Write-Host "Dependencies have been installed."
} else {
    Write-Host "Failed to install dependencies."
    Pause
    Exit
}

Write-Host "Building the project..."
pnpm build
if ($?) {
    Write-Host "Project has been built."
} else {
    Write-Host "Project build failed."
    Pause
    Exit
}

# Inject BetterDiscord into Discord
Write-Host "Injecting BetterDiscord..."
pnpm inject stable
if ($?) {
    Write-Host "Injection was successful."
} else {
    Write-Host "Injection failed."
    Pause
    Exit
}

# Launch Discord
Write-Host "Launching Discord..."
Start-Process "$env:USERPROFILE\AppData\Local\Discord\Update.exe" -ArgumentList "--processStart", "Discord.exe"

Write-Host "BetterDiscord installation completed!"
Start-Sleep -Seconds 3
Exit
