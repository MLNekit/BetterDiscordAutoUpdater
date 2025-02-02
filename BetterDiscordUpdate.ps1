#Requires -RunAsAdministrator

# Function to display a message box
function Show-MessageBox {
    param([string]$Message, [string]$Title)
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show($Message, $Title, [System.Windows.Forms.MessageBoxButtons]::OK) | Out-Null
}

#region Step 1: Handle Discord process
$discordRunning = Get-Process -Name "Discord" -ErrorAction SilentlyContinue
$discordExePath = "$env:LOCALAPPDATA\Discord\Update.exe"

if ($discordRunning) {
    Write-Host "Closing Discord..."
    Stop-Process -Name "Discord" -Force
    Start-Sleep -Seconds 2
} else {
    # Check if Discord is installed
    if (-not (Test-Path $discordExePath)) {
        Write-Host "Installing Discord..."
        $discordInstaller = "$env:TEMP\DiscordSetup.exe"
        Invoke-WebRequest "https://discord.com/api/downloads/distributions/app/installers/latest?channel=stable&platform=win&arch=x86" -OutFile $discordInstaller
        Start-Process -FilePath $discordInstaller -ArgumentList "--silent" -Wait
    }
    
    # Show confirmation message
    Show-MessageBox -Message "Discord installation completed. Click OK to continue." -Title "Discord Setup"
    
    # Ensure Discord is closed after installation
    Get-Process -Name "Discord" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
#endregion

#region Step 2: Check and install dependencies
$dependenciesMissing = $false

# Check Git
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Git..."
    $gitInstaller = "$env:TEMP\git-installer.exe"
    Invoke-WebRequest "https://github.com/git-for-windows/git/releases/download/v2.40.0.windows.1/Git-2.40.0-64-bit.exe" -OutFile $gitInstaller
    Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT" -Wait
    $dependenciesMissing = $true
}

# Check Node.js
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Node.js..."
    $nodeInstaller = "$env:TEMP\node-installer.msi"
    Invoke-WebRequest "https://nodejs.org/dist/v18.18.2/node-v18.18.2-x64.msi" -OutFile $nodeInstaller
    Start-Process -FilePath $nodeInstaller -ArgumentList "/quiet", "/norestart" -Wait
    $dependenciesMissing = $true
}

# Check pnpm
if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
    Write-Host "Installing pnpm..."
    npm install -g pnpm
    $dependenciesMissing = $true
}

if ($dependenciesMissing) {
    Write-Host "Please restart your terminal and run the script again"
    exit
}
#endregion

#region Step 3: Script self-update
$scriptDir = Join-Path $env:APPDATA "BetterDiscord Update Script"
$scriptPath = Join-Path $scriptDir "BetterDiscordUpdate.ps1"

# Create directory if missing
if (-not (Test-Path $scriptDir)) {
    New-Item -ItemType Directory -Path $scriptDir -Force | Out-Null
}

# Update script from GitHub
try {
    $githubContent = Invoke-WebRequest "https://raw.githubusercontent.com/MLNekit/BetterDiscordAutoUpdater/main/BetterDiscordUpdate.ps1" -UseBasicParsing
    $localContent = Get-Content $scriptPath -Raw -ErrorAction SilentlyContinue
    
    if ($localContent -ne $githubContent) {
        Write-Host "Updating script..."
        Set-Content -Path $scriptPath -Value $githubContent -Force
    }
}
catch {
    Write-Host "Failed to update script: $_"
}

# Re-run with updated script if executed remotely
if ($MyInvocation.MyCommand.Path -ne $scriptPath) {
    & $scriptPath
    exit
}
#endregion

#region Step 4: Handle BetterDiscord repository
$betterDiscordRepo = Join-Path $scriptDir "BetterDiscord"

if (-not (Test-Path $betterDiscordRepo)) {
    Write-Host "Cloning BetterDiscord repository..."
    git clone "https://github.com/BetterDiscord/BetterDiscord.git" $betterDiscordRepo
} else {
    Write-Host "Updating BetterDiscord repository..."
    Set-Location $betterDiscordRepo
    git pull
}
#endregion

#region Step 5: Create shortcut
$shortcutPath = Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs\BetterDiscord Update.lnk"

if (-not (Test-Path $shortcutPath)) {
    try {
        $WshShell = New-Object -ComObject WScript.Shell
        $shortcut = $WshShell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = "powershell.exe"
        $shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$scriptPath`""
        $shortcut.Save()
        Write-Host "Shortcut created successfully"
    }
    catch {
        Write-Host "Failed to create shortcut: $_"
    }
}
#endregion

#region Step 6: Create BetterDiscord data folder
$betterDiscordData = Join-Path $env:APPDATA "BetterDiscord"
if (-not (Test-Path $betterDiscordData)) {
    New-Item -ItemType Directory -Path $betterDiscordData -Force | Out-Null
}
#endregion

#region Step 7: Build and inject
Set-Location $betterDiscordRepo

Write-Host "Installing dependencies..."
npm install -g pnpm
pnpm install
pnpm build
pnpm inject
#endregion

#region Step 8: Launch Discord
Start-Process $discordExePath -ArgumentList "--processStart", "Discord.exe"
Write-Host "BetterDiscord update completed!"
Start-Sleep -Seconds 3
#endregion
