<#
.SYNOPSIS
    BetterDiscord Auto-Update Script

.DESCRIPTION
    This script automatically updates BetterDiscord. It supports two modes:
      1. Remote Execution (-Remote switch): Run the script from a single command without installing locally.
      2. Installation Mode (default): The script copies itself to "%APPDATA%\BetterDiscord Update Script" and creates a Start Menu shortcut for easy execution.
    It automatically closes Discord if running, checks (and if needed, installs/updates) dependencies (Git, Node.js, pnpm) by comparing versions,
    clones or updates the BetterDiscord repository, builds it, injects it into Discord, and launches Discord.
    It also supports two languages – English ("en") and Russian ("ru") – via a message hashtable and includes a self-update feature.
    
.PARAMETER Remote
    When specified, the script will run in remote execution mode (no local installation or shortcut creation).

.PARAMETER Language
    Specify the language code to use for messages ("en" for English or "ru" for Russian). Default is "en".

.EXAMPLE
    # Run in default installation mode in English:
    .\BetterDiscordUpdate.ps1

    # Run in remote execution mode in Russian:
    .\BetterDiscordUpdate.ps1 -Remote -Language ru

.NOTES
    This script should be executed with appropriate privileges (administrator if installing/updating dependencies or shortcuts).
#>

[CmdletBinding()]
param(
    [switch]$Remote,
    [string]$Language = "en"
)

#----------------------------#
# CONSTANTS AND CONFIGURATION#
#----------------------------#

# Define required versions and installer URLs
$requiredGitVersion  = [version]"2.47.1"
$requiredNodeVersion = [version]"22.13.1"
# (For pnpm we only check if it exists; you can add version check if desired)

$gitInstallerUrl  = "https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.2/Git-2.47.1.2-64-bit.exe"
$nodeInstallerUrl = "https://nodejs.org/dist/v22.13.1/node-v22.13.1-x64.msi"
# For pnpm, we run the installer script from get.pnpm.io
$pnpmInstallerUrl = "https://get.pnpm.io/install.ps1"

# Self-update configuration
$scriptVersion = "1.0.0"  # local version (update manually when releasing changes)
$remoteScriptUrl = "https://raw.githubusercontent.com/MLNekit/BetterDiscordAutoUpdater/main/BetterDiscordUpdate.ps1"

# Base folder for local installation (if not remote)
$BaseFolder = Join-Path $env:APPDATA "BetterDiscord Update Script"
$LocalScriptPath = Join-Path $BaseFolder "BetterDiscordUpdate.ps1"
# Folder for the BetterDiscord repository clone (inside the base folder)
$BetterDiscordFolder = Join-Path $BaseFolder "BetterDiscord"

# Start Menu shortcut location
$StartMenuFolder = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs"
$ShortcutName = "BetterDiscord Update.lnk"

#-----------------------------------#
# LANGUAGE MESSAGES (English / RU)  #
#-----------------------------------#
$messages = @{
    en = @{
        "ClosingDiscord"           = "Closing Discord..."
        "DiscordNotRunning"        = "Discord is not running."
        "CheckingGit"              = "Checking for Git..."
        "GitInstalled"             = "Git is installed."
        "InstallingGit"            = "Git is not installed or outdated. Installing/updating Git..."
        "GitInstalledSuccess"      = "Git has been installed/updated successfully."
        "CheckingNode"             = "Checking for Node.js..."
        "NodeInstalled"            = "Node.js is installed."
        "InstallingNode"           = "Node.js is not installed or outdated. Installing/updating Node.js..."
        "NodeInstalledSuccess"     = "Node.js has been installed/updated successfully."
        "CheckingPNPM"             = "Checking for pnpm..."
        "PNPMInstalled"            = "pnpm is installed."
        "InstallingPNPM"           = "pnpm not found. Installing pnpm..."
        "PNPMInstalledSuccess"     = "pnpm has been installed successfully."
        "DependenciesInstalled"    = "All dependencies are installed."
        "CloningRepo"              = "BetterDiscord folder not found. Cloning the repository..."
        "RepoCloned"               = "BetterDiscord repository has been cloned."
        "RepoCloneFail"            = "Failed to clone the repository. Check your internet connection."
        "RepoFound"                = "BetterDiscord folder found."
        "UpdatingRepo"             = "Updating the repository..."
        "RepoUpdated"              = "Repository has been updated."
        "RepoUpdateFail"           = "Failed to update the repository. Check your internet connection."
        "InstallingDependencies"   = "Installing dependencies..."
        "DependenciesInstalledSuccess" = "Dependencies have been installed."
        "DependenciesInstallFail"  = "Failed to install dependencies."
        "BuildingProject"          = "Building the project..."
        "ProjectBuilt"             = "Project has been built."
        "ProjectBuildFail"         = "Project build failed."
        "InjectingBetterDiscord"   = "Injecting BetterDiscord..."
        "InjectionSuccess"         = "Injection was successful."
        "InjectionFail"            = "Injection failed."
        "LaunchingDiscord"         = "Launching Discord..."
        "InstallationCompleted"    = "BetterDiscord installation completed!"
        "ScriptUpdating"           = "Updating script to the latest version..."
        "ScriptUpdatedRestarting"  = "Script updated. Restarting..."
        "ErrorOccurred"            = "An error occurred: "
    }
    ru = @{
        "ClosingDiscord"           = "Закрытие Discord..."
        "DiscordNotRunning"        = "Discord не запущен."
        "CheckingGit"              = "Проверка наличия Git..."
        "GitInstalled"             = "Git установлен."
        "InstallingGit"            = "Git не установлен или устарел. Устанавливаем/обновляем Git..."
        "GitInstalledSuccess"      = "Git успешно установлен/обновлён."
        "CheckingNode"             = "Проверка наличия Node.js..."
        "NodeInstalled"            = "Node.js установлен."
        "InstallingNode"           = "Node.js не установлен или устарел. Устанавливаем/обновляем Node.js..."
        "NodeInstalledSuccess"     = "Node.js успешно установлен/обновлён."
        "CheckingPNPM"             = "Проверка наличия pnpm..."
        "PNPMInstalled"            = "pnpm установлен."
        "InstallingPNPM"           = "pnpm не найден. Устанавливаем pnpm..."
        "PNPMInstalledSuccess"     = "pnpm успешно установлен."
        "DependenciesInstalled"    = "Все зависимости установлены."
        "CloningRepo"              = "Папка BetterDiscord не найдена. Клонирование репозитория..."
        "RepoCloned"               = "Репозиторий BetterDiscord склонирован."
        "RepoCloneFail"            = "Не удалось клонировать репозиторий. Проверьте подключение к интернету."
        "RepoFound"                = "Папка BetterDiscord найдена."
        "UpdatingRepo"             = "Обновление репозитория..."
        "RepoUpdated"              = "Репозиторий обновлён."
        "RepoUpdateFail"           = "Не удалось обновить репозиторий. Проверьте подключение к интернету."
        "InstallingDependencies"   = "Установка зависимостей..."
        "DependenciesInstalledSuccess" = "Зависимости успешно установлены."
        "DependenciesInstallFail"  = "Не удалось установить зависимости."
        "BuildingProject"          = "Сборка проекта..."
        "ProjectBuilt"             = "Проект успешно собран."
        "ProjectBuildFail"         = "Сборка проекта не удалась."
        "InjectingBetterDiscord"   = "Инжектинг BetterDiscord..."
        "InjectionSuccess"         = "Инжектинг успешен."
        "InjectionFail"            = "Инжектинг не удался."
        "LaunchingDiscord"         = "Запуск Discord..."
        "InstallationCompleted"    = "Установка BetterDiscord завершена!"
        "ScriptUpdating"           = "Обновление скрипта до последней версии..."
        "ScriptUpdatedRestarting"  = "Скрипт обновлён. Перезапуск..."
        "ErrorOccurred"            = "Произошла ошибка: "
    }
}

# Helper function: Write a localized message
function Write-Message {
    param(
        [Parameter(Mandatory)]
        [string]$Key
    )
    if ($messages.ContainsKey($Language) -and $messages[$Language].ContainsKey($Key)) {
        Write-Host $messages[$Language][$Key]
    }
    else {
        Write-Host $Key
    }
}

# Helper function: Compare version strings (if possible)
function Is-VersionLessThan {
    param(
        [Parameter(Mandatory)]
        [version]$Current,
        [Parameter(Mandatory)]
        [version]$Required
    )
    return ($Current -lt $Required)
}

#----------------------------#
# SELF-UPDATE (if not remote)#
#----------------------------#
function Self-Update {
    try {
        Write-Message "ScriptUpdating"
        # Download remote script content
        $remoteContent = Invoke-WebRequest -Uri $remoteScriptUrl -UseBasicParsing -ErrorAction Stop
        $remoteHash = (New-Object -TypeName System.Security.Cryptography.SHA256Managed).ComputeHash([Text.Encoding]::UTF8.GetBytes($remoteContent.Content))
        $remoteHashString = [BitConverter]::ToString($remoteHash) -replace '-', ''

        # Read local script content
        if (Test-Path $LocalScriptPath) {
            $localContent = Get-Content -Path $LocalScriptPath -Raw
            $localHash = (New-Object -TypeName System.Security.Cryptography.SHA256Managed).ComputeHash([Text.Encoding]::UTF8.GetBytes($localContent))
            $localHashString = [BitConverter]::ToString($localHash) -replace '-', ''
        }
        else {
            # If local file does not exist, treat as update needed.
            $localHashString = ""
        }

        if ($remoteHashString -ne $localHashString) {
            # Update local script file
            $remoteContent.Content | Out-File -FilePath $LocalScriptPath -Encoding UTF8
            Write-Message "ScriptUpdatedRestarting"
            # Restart the script (using the local copy) and exit current instance
            Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$LocalScriptPath`""
            exit
        }
    }
    catch {
        Write-Host "$($messages[$Language]['ErrorOccurred']) $($_.Exception.Message)"
    }
}

#----------------------------#
# DEPENDENCY CHECK FUNCTIONS #
#----------------------------#

function Ensure-Git {
    Write-Message "CheckingGit"
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    $installNeeded = $false
    if ($gitCmd) {
        try {
            $gitVersionOutput = git --version
            if ($gitVersionOutput -match '(\d+\.\d+\.\d+)') {
                $currentGitVersion = [version]$Matches[1]
                if (Is-VersionLessThan -Current $currentGitVersion -Required $requiredGitVersion) {
                    $installNeeded = $true
                }
            }
            else {
                $installNeeded = $true
            }
        }
        catch {
            $installNeeded = $true
        }
    }
    else {
        $installNeeded = $true
    }
    if ($installNeeded) {
        Write-Message "InstallingGit"
        $gitInstallerPath = Join-Path $env:TEMP "git-installer.exe"
        try {
            Invoke-WebRequest -Uri $gitInstallerUrl -OutFile $gitInstallerPath -UseBasicParsing -ErrorAction Stop
            Start-Process -FilePath $gitInstallerPath -ArgumentList "/VERYSILENT" -Wait
            Write-Message "GitInstalledSuccess"
        }
        catch {
            Write-Host "$($messages[$Language]['ErrorOccurred']) $($_.Exception.Message)"
            exit 1
        }
    }
    else {
        Write-Message "GitInstalled"
    }
}

function Ensure-Node {
    Write-Message "CheckingNode"
    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    $installNeeded = $false
    if ($nodeCmd) {
        try {
            $nodeVersionOutput = node --version
            # Remove leading "v" from version string (e.g. v18.18.2)
            $nodeVersionStr = $nodeVersionOutput.TrimStart("v")
            $currentNodeVersion = [version]$nodeVersionStr
            if (Is-VersionLessThan -Current $currentNodeVersion -Required $requiredNodeVersion) {
                $installNeeded = $true
            }
        }
        catch {
            $installNeeded = $true
        }
    }
    else {
        $installNeeded = $true
    }
    if ($installNeeded) {
        Write-Message "InstallingNode"
        $nodeInstallerPath = Join-Path $env:TEMP "node-installer.msi"
        try {
            Invoke-WebRequest -Uri $nodeInstallerUrl -OutFile $nodeInstallerPath -UseBasicParsing -ErrorAction Stop
            Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", "`"$nodeInstallerPath`"", "/quiet", "/norestart" -Wait
            Write-Message "NodeInstalledSuccess"
        }
        catch {
            Write-Host "$($messages[$Language]['ErrorOccurred']) $($_.Exception.Message)"
            exit 1
        }
    }
    else {
        Write-Message "NodeInstalled"
    }
}

function Ensure-Pnpm {
    Write-Message "CheckingPNPM"
    $pnpmCmd = Get-Command pnpm -ErrorAction SilentlyContinue
    if (-not $pnpmCmd) {
        Write-Message "InstallingPNPM"
        try {
            # Execute the installer script from pnpm
            Invoke-WebRequest -Uri $pnpmInstallerUrl -UseBasicParsing -ErrorAction Stop | Invoke-Expression
            Write-Message "PNPMInstalledSuccess"
        }
        catch {
            Write-Host "$($messages[$Language]['ErrorOccurred']) $($_.Exception.Message)"
            exit 1
        }
    }
    else {
        Write-Message "PNPMInstalled"
    }
}

#----------------------------#
# MAIN EXECUTION BLOCK       #
#----------------------------#
try {
    # If running in installation mode, ensure the base folder exists and copy the script to local folder.
    if (-not $Remote) {
        if (-not (Test-Path $BaseFolder)) {
            New-Item -ItemType Directory -Path $BaseFolder -Force | Out-Null
        }
        # If the current script is not already the local copy, copy it.
        if ($MyInvocation.MyCommand.Path -ne $LocalScriptPath) {
            Copy-Item -Path $MyInvocation.MyCommand.Path -Destination $LocalScriptPath -Force
        }
        # Perform self-update check (only in installation mode)
        Self-Update
    }
    
    # Close Discord if running
    Write-Message "ClosingDiscord"
    $discordProcess = Get-Process -Name "Discord" -ErrorAction SilentlyContinue
    if ($discordProcess) {
        Stop-Process -Name "Discord" -Force
        Start-Sleep -Seconds 2
    }
    else {
        Write-Message "DiscordNotRunning"
    }

    # Ensure dependencies are installed/up-to-date
    Ensure-Git
    Ensure-Node
    Ensure-Pnpm
    Write-Message "DependenciesInstalled"

    # Set working folder for BetterDiscord repository
    if (-not (Test-Path $BetterDiscordFolder)) {
        Write-Message "CloningRepo"
        try {
            git clone "https://github.com/BetterDiscord/BetterDiscord.git" $BetterDiscordFolder
            Write-Message "RepoCloned"
        }
        catch {
            Write-Host "$($messages[$Language]['ErrorOccurred']) $($_.Exception.Message)"
            exit 1
        }
    }
    else {
        Write-Message "RepoFound"
    }

    # Change to the repository folder
    Set-Location -Path $BetterDiscordFolder

    # Update the repository
    Write-Message "UpdatingRepo"
    try {
        git pull
        Write-Message "RepoUpdated"
    }
    catch {
        Write-Message "RepoUpdateFail"
        exit 1
    }

    # Install project dependencies
    Write-Message "InstallingDependencies"
    try {
        pnpm install
        Write-Message "DependenciesInstalledSuccess"
    }
    catch {
        Write-Message "DependenciesInstallFail"
        exit 1
    }

    # Build the project
    Write-Message "BuildingProject"
    try {
        pnpm build
        Write-Message "ProjectBuilt"
    }
    catch {
        Write-Message "ProjectBuildFail"
        exit 1
    }

    # Inject BetterDiscord into Discord (using stable branch)
    Write-Message "InjectingBetterDiscord"
    try {
        pnpm inject stable
        Write-Message "InjectionSuccess"
    }
    catch {
        Write-Message "InjectionFail"
        exit 1
    }

    # Launch Discord
    Write-Message "LaunchingDiscord"
    $discordUpdateExe = Join-Path $env:LOCALAPPDATA "Discord\Update.exe"
    if (Test-Path $discordUpdateExe) {
        Start-Process -FilePath $discordUpdateExe -ArgumentList "--processStart", "Discord.exe"
    }
    else {
        Write-Host "Discord Update.exe not found. Please start Discord manually."
    }

    Write-Message "InstallationCompleted"

    # If in installation mode, create a Start Menu shortcut for easier execution
    if (-not $Remote) {
        try {
            $WshShell = New-Object -ComObject WScript.Shell
            $ShortcutPath = Join-Path $StartMenuFolder $ShortcutName
            $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
            $Shortcut.TargetPath = "powershell.exe"
            # Use ExecutionPolicy Bypass and point to the local copy of the script.
            $Shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$LocalScriptPath`""
            $Shortcut.IconLocation = $discordUpdateExe  # Optionally use Discord's icon
            $Shortcut.Save()
        }
        catch {
            Write-Host "$($messages[$Language]['ErrorOccurred']) $($_.Exception.Message)"
        }
    }

    # Wait a few seconds before exit
    Start-Sleep -Seconds 3
}
catch {
    Write-Host "$($messages[$Language]['ErrorOccurred']) $($_.Exception.Message)"
    exit 1
}
