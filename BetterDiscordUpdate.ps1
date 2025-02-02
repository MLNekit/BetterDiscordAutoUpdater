<# 
    BetterDiscord Auto-Update Script
    Version: 1.0.0

    This script automates the process of updating and installing BetterDiscord.
    It supports two modes:
      1. Remote execution mode ("remote"): Closes Discord, verifies/installs dependencies,
         updates/clones the BetterDiscord repository in %APPDATA%\BetterDiscord Update Script,
         applies the BetterDiscord patch, and launches Discord.
      2. Installation mode ("install", default): In addition to the above, it creates the folder 
         %APPDATA%\BetterDiscord Update Script, downloads this script from the repository into that folder,
         and creates a Start Menu shortcut for local execution.
    
    The script auto-updates itself (if run from the installation folder) by checking for newer versions
    in the repository and restarting if necessary.
    
    Usage examples:
      powershell -ExecutionPolicy Bypass -File "BetterDiscordUpdate.ps1" -Mode install -Lang en
      powershell -ExecutionPolicy Bypass -File "BetterDiscordUpdate.ps1" -Mode remote -Lang ru
#>

param(
    [ValidateSet("install","remote")]
    [string]$Mode = "install",
    
    [ValidateSet("en", "ru")]
    [string]$Lang = "en"
)

# ---------------------------
# Global Variables and Messages
# ---------------------------
$ScriptVersion = "1.0.0"

# Required versions for dependencies (adjust as needed)
$RequiredGitVersion   = "2.40.0"
$RequiredNodeVersion  = "18.18.2"
$RequiredPnpmVersion  = "8.6.0"  # Adjust if needed

# Define messages in English and Russian
$messages = @{
    "en" = @{
        "ClosingDiscord"             = "Closing Discord..."
        "DiscordNotRunning"          = "Discord is not running."
        "UpdatingGit"                = "Git update required. Installing latest Git..."
        "GitInstalled"               = "Git is installed."
        "GitNotInstalled"            = "Git is not installed."
        "DownloadingGit"             = "Downloading Git installer..."
        "InstallingGit"              = "Installing Git..."
        "GitInstallFailed"           = "Failed to install Git."
        "UpdatingNode"               = "Node.js update required. Installing latest Node.js..."
        "NodeInstalled"              = "Node.js is installed."
        "NodeNotInstalled"           = "Node.js is not installed."
        "DownloadingNode"            = "Downloading Node.js installer..."
        "InstallingNode"             = "Installing Node.js..."
        "NodeInstallFailed"          = "Failed to install Node.js."
        "UpdatingPnpm"               = "pnpm update required. Installing latest pnpm..."
        "PnpmInstalled"              = "pnpm is installed."
        "PnpmNotInstalled"           = "pnpm is not installed."
        "InstallingPnpm"             = "Installing pnpm..."
        "PnpmInstallFailed"          = "Failed to install pnpm."
        "DependenciesInstalled"      = "All dependencies are installed."
        "CloningRepository"          = "BetterDiscord folder not found. Cloning repository..."
        "RepositoryExists"           = "BetterDiscord folder exists."
        "CloneFailed"                = "Failed to clone the repository. Check your internet connection."
        "UpdatingRepository"         = "Updating the BetterDiscord repository..."
        "RepositoryUpdateFailed"     = "Failed to update the repository. Check your internet connection."
        "InstallingDependencies"     = "Installing project dependencies..."
        "InstallDependenciesFailed"  = "Failed to install project dependencies."
        "BuildingProject"            = "Building the project..."
        "BuildFailed"                = "Project build failed."
        "InjectingBetterDiscord"     = "Injecting BetterDiscord..."
        "InjectionFailed"            = "Injection failed."
        "LaunchingDiscord"           = "Launching Discord..."
        "DiscordLaunchFailed"        = "Discord executable not found."
        "InstallationCompleted"      = "BetterDiscord installation completed!"
        "CheckingForScriptUpdate"    = "Checking for script updates..."
        "NewScriptVersionAvailable"  = "New script version available:"
        "UpdatingScript"             = "Updating script..."
        "ScriptUpdated"              = "Script updated successfully."
        "RestartingScript"           = "Restarting script..."
        "ScriptUpToDate"             = "Script is up to date."
        "ScriptVersionNotFound"      = "Could not determine remote script version."
        "ScriptUpdateFailed"         = "Script update check failed."
        "InstallingLocalCopy"        = "Installing local copy of the script..."
        "CreatingInstallFolder"      = "Creating installation folder..."
        "CreatingShortcut"           = "Creating Start Menu shortcut..."
        "LaunchLocalScript"          = "Launching local script from installation folder..."
        "LocalScriptDownloadFailed"  = "Failed to download the remote script."
    }
    "ru" = @{
        "ClosingDiscord"             = "Закрываем Discord..."
        "DiscordNotRunning"          = "Discord не запущен."
        "UpdatingGit"                = "Требуется обновление Git. Устанавливаем последнюю версию Git..."
        "GitInstalled"               = "Git установлен."
        "GitNotInstalled"            = "Git не установлен."
        "DownloadingGit"             = "Скачиваем установщик Git..."
        "InstallingGit"              = "Устанавливаем Git..."
        "GitInstallFailed"           = "Не удалось установить Git."
        "UpdatingNode"               = "Требуется обновление Node.js. Устанавливаем последнюю версию Node.js..."
        "NodeInstalled"              = "Node.js установлен."
        "NodeNotInstalled"           = "Node.js не установлен."
        "DownloadingNode"            = "Скачиваем установщик Node.js..."
        "InstallingNode"             = "Устанавливаем Node.js..."
        "NodeInstallFailed"          = "Не удалось установить Node.js."
        "UpdatingPnpm"               = "Требуется обновление pnpm. Устанавливаем последнюю версию pnpm..."
        "PnpmInstalled"              = "pnpm установлен."
        "PnpmNotInstalled"           = "pnpm не установлен."
        "InstallingPnpm"             = "Устанавливаем pnpm..."
        "PnpmInstallFailed"          = "Не удалось установить pnpm."
        "DependenciesInstalled"      = "Все зависимости установлены."
        "CloningRepository"          = "Папка BetterDiscord не найдена. Клонируем репозиторий..."
        "RepositoryExists"           = "Папка BetterDiscord найдена."
        "CloneFailed"                = "Не удалось клонировать репозиторий. Проверьте подключение к интернету."
        "UpdatingRepository"         = "Обновляем репозиторий BetterDiscord..."
        "RepositoryUpdateFailed"     = "Не удалось обновить репозиторий. Проверьте подключение к интернету."
        "InstallingDependencies"     = "Устанавливаем зависимости проекта..."
        "InstallDependenciesFailed"  = "Не удалось установить зависимости проекта."
        "BuildingProject"            = "Собираем проект..."
        "BuildFailed"                = "Сборка проекта завершилась неудачно."
        "InjectingBetterDiscord"     = "Внедряем BetterDiscord..."
        "InjectionFailed"            = "Внедрение не удалось."
        "LaunchingDiscord"           = "Запускаем Discord..."
        "DiscordLaunchFailed"        = "Исполняемый файл Discord не найден."
        "InstallationCompleted"      = "Установка BetterDiscord завершена!"
        "CheckingForScriptUpdate"    = "Проверяем обновления скрипта..."
        "NewScriptVersionAvailable"  = "Доступна новая версия скрипта:"
        "UpdatingScript"             = "Обновляем скрипт..."
        "ScriptUpdated"              = "Скрипт успешно обновлен."
        "RestartingScript"           = "Перезапускаем скрипт..."
        "ScriptUpToDate"             = "Скрипт актуален."
        "ScriptVersionNotFound"      = "Не удалось определить версию удаленного скрипта."
        "ScriptUpdateFailed"         = "Не удалось проверить обновления скрипта."
        "InstallingLocalCopy"        = "Устанавливаем локальную копию скрипта..."
        "CreatingInstallFolder"      = "Создаем папку установки..."
        "CreatingShortcut"           = "Создаем ярлык в меню Пуск..."
        "LaunchLocalScript"          = "Запускаем локальный скрипт из папки установки..."
        "LocalScriptDownloadFailed"  = "Не удалось скачать удаленный скрипт."
    }
}

# Function to retrieve message based on key and selected language.
function Get-Message($key) {
    return $messages[$Lang][$key]
}

# ---------------------------
# Version Comparison Function
# ---------------------------
function Compare-Version($current, $required) {
    try {
        return ([version]$current -lt [version]$required)
    } catch {
        return $true
    }
}

# ---------------------------
# Dependency Installation Functions
# ---------------------------
function Install-Git {
    try {
        $gitInstaller = "$env:TEMP\git-installer.exe"
        $gitDownloadUrl = "https://github.com/git-for-windows/git/releases/download/v$RequiredGitVersion.windows.1/Git-$RequiredGitVersion-64-bit.exe"
        Write-Host (Get-Message "DownloadingGit")
        Invoke-WebRequest $gitDownloadUrl -OutFile $gitInstaller -ErrorAction Stop
        Write-Host (Get-Message "InstallingGit")
        Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT" -Wait -ErrorAction Stop
        Write-Host (Get-Message "GitInstalled")
    } catch {
        Write-Error (Get-Message "GitInstallFailed")
        throw $_
    }
}

function Ensure-Git {
    try {
        $gitCmd = Get-Command git -ErrorAction Stop
        $gitVersionOutput = & git --version
        if ($gitVersionOutput -match "(\d+\.\d+\.\d+)") {
            $currentVersion = $Matches[1]
        } else {
            $currentVersion = "0.0.0"
        }
        if (Compare-Version $currentVersion $RequiredGitVersion) {
            Write-Host (Get-Message "UpdatingGit")
            Install-Git
        } else {
            Write-Host (Get-Message "GitInstalled")
        }
    } catch {
        Write-Host (Get-Message "GitNotInstalled")
        Install-Git
    }
}

function Install-Node {
    try {
        $nodeInstaller = "$env:TEMP\node-installer.msi"
        $nodeDownloadUrl = "https://nodejs.org/dist/v$RequiredNodeVersion/node-v$RequiredNodeVersion-x64.msi"
        Write-Host (Get-Message "DownloadingNode")
        Invoke-WebRequest $nodeDownloadUrl -OutFile $nodeInstaller -ErrorAction Stop
        Write-Host (Get-Message "InstallingNode")
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", $nodeInstaller, "/quiet", "/norestart" -Wait -ErrorAction Stop
        Write-Host (Get-Message "NodeInstalled")
    } catch {
        Write-Error (Get-Message "NodeInstallFailed")
        throw $_
    }
}

function Ensure-Node {
    try {
        $nodeCmd = Get-Command node -ErrorAction Stop
        $nodeVersionOutput = & node -v
        $nodeVersion = $nodeVersionOutput.TrimStart("v").Trim()
        if (Compare-Version $nodeVersion $RequiredNodeVersion) {
            Write-Host (Get-Message "UpdatingNode")
            Install-Node
        } else {
            Write-Host (Get-Message "NodeInstalled")
        }
    } catch {
        Write-Host (Get-Message "NodeNotInstalled")
        Install-Node
    }
}

function Install-Pnpm {
    try {
        Write-Host (Get-Message "InstallingPnpm")
        npm install -g pnpm --silent -ErrorAction Stop
        Write-Host (Get-Message "PnpmInstalled")
    } catch {
        Write-Error (Get-Message "PnpmInstallFailed")
        throw $_
    }
}

function Ensure-Pnpm {
    try {
        $pnpmCmd = Get-Command pnpm -ErrorAction Stop
        $pnpmVersionOutput = & pnpm -v
        $pnpmVersion = $pnpmVersionOutput.Trim()
        if (Compare-Version $pnpmVersion $RequiredPnpmVersion) {
            Write-Host (Get-Message "UpdatingPnpm")
            Install-Pnpm
        } else {
            Write-Host (Get-Message "PnpmInstalled")
        }
    } catch {
        Write-Host (Get-Message "PnpmNotInstalled")
        Install-Pnpm
    }
}

# ---------------------------
# Self-Update Functionality
# ---------------------------
function Self-Update {
    try {
        Write-Host (Get-Message "CheckingForScriptUpdate")
        $remoteScriptUrl = "https://raw.githubusercontent.com/MLNekit/BetterDiscordAutoUpdater/main/BetterDiscordUpdate.ps1"
        $remoteScriptResponse = Invoke-WebRequest $remoteScriptUrl -UseBasicParsing -ErrorAction Stop
        $remoteScriptContent = $remoteScriptResponse.Content
        if ($remoteScriptContent -match "#\s*Version:\s*([\d\.]+)") {
            $remoteVersion = $Matches[1]
            if (Compare-Version $ScriptVersion $remoteVersion) {
                Write-Host (Get-Message "NewScriptVersionAvailable"), $remoteVersion
                Write-Host (Get-Message "UpdatingScript")
                # Overwrite local script file with updated version
                $localScriptPath = $MyInvocation.MyCommand.Definition
                $remoteScriptContent | Out-File -FilePath $localScriptPath -Encoding utf8
                Write-Host (Get-Message "ScriptUpdated")
                Write-Host (Get-Message "RestartingScript")
                & $localScriptPath @PSBoundParameters
                Exit
            } else {
                Write-Host (Get-Message "ScriptUpToDate")
            }
        } else {
            Write-Host (Get-Message "ScriptVersionNotFound")
        }
    } catch {
        Write-Warning (Get-Message "ScriptUpdateFailed")
    }
}

# ---------------------------
# Installation Mode: Copy script to local folder and create shortcut
# ---------------------------
if ($Mode -eq "install") {
    $installFolder = Join-Path $env:APPDATA "BetterDiscord Update Script"
    if (-not (Test-Path $installFolder)) {
        Write-Host (Get-Message "CreatingInstallFolder")
        New-Item -Path $installFolder -ItemType Directory | Out-Null
    }
    $localScriptPath = Join-Path $installFolder "BetterDiscordUpdate.ps1"
    $remoteScriptUrl = "https://raw.githubusercontent.com/MLNekit/BetterDiscordAutoUpdater/main/BetterDiscordUpdate.ps1"
    Write-Host (Get-Message "InstallingLocalCopy")
    try {
        Invoke-WebRequest $remoteScriptUrl -OutFile $localScriptPath -ErrorAction Stop
    } catch {
        Write-Error (Get-Message "LocalScriptDownloadFailed")
        Exit 1
    }
    # Create shortcut in Start Menu
    $shortcutPath = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\BetterDiscord Update.lnk"
    try {
        Write-Host (Get-Message "CreatingShortcut")
        $WshShell = New-Object -ComObject WScript.Shell
        $shortcut = $WshShell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = "powershell.exe"
        $shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$localScriptPath`" -Lang $Lang -Mode remote"
        $shortcut.WorkingDirectory = $installFolder
        $shortcut.IconLocation = "powershell.exe"
        $shortcut.Save()
    } catch {
        Write-Warning "Failed to create Start Menu shortcut."
    }
    Write-Host (Get-Message "LaunchLocalScript")
    Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$localScriptPath`" -Lang $Lang -Mode remote" -Wait
    Exit
}

# ---------------------------
# Remote Mode Execution
# ---------------------------
# In remote mode we use the installation folder to store the BetterDiscord repository.
$installFolder = Join-Path $env:APPDATA "BetterDiscord Update Script"
if (-not (Test-Path $installFolder)) {
    New-Item -Path $installFolder -ItemType Directory | Out-Null
}

# If the script is running from the installation folder, perform self-update.
$localScriptPath = Join-Path $installFolder "BetterDiscordUpdate.ps1"
if ($MyInvocation.MyCommand.Definition -ieq $localScriptPath) {
    Self-Update
}

# Close Discord if running.
$discordProcess = Get-Process -Name "Discord" -ErrorAction SilentlyContinue
if ($discordProcess) {
    Write-Host (Get-Message "ClosingDiscord")
    Stop-Process -Name "Discord" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
} else {
    Write-Host (Get-Message "DiscordNotRunning")
}

# Ensure all dependencies are installed/updated.
Ensure-Git
Ensure-Node
Ensure-Pnpm
Write-Host (Get-Message "DependenciesInstalled")

# Define the BetterDiscord repository folder inside the installation folder.
$betterDiscordPath = Join-Path $installFolder "BetterDiscord"

# Clone or update the BetterDiscord repository.
if (-not (Test-Path $betterDiscordPath)) {
    Write-Host (Get-Message "CloningRepository")
    git clone "https://github.com/BetterDiscord/BetterDiscord.git" $betterDiscordPath
    if (-not $?) { throw (Get-Message "CloneFailed") }
} else {
    Write-Host (Get-Message "RepositoryExists")
}
Set-Location -Path $betterDiscordPath
Write-Host (Get-Message "UpdatingRepository")
git pull
if (-not $?) { throw (Get-Message "RepositoryUpdateFailed") }

# Install dependencies and build the project.
Write-Host (Get-Message "InstallingDependencies")
pnpm install
if (-not $?) { throw (Get-Message "InstallDependenciesFailed") }

Write-Host (Get-Message "BuildingProject")
pnpm build
if (-not $?) { throw (Get-Message "BuildFailed") }

# Inject BetterDiscord.
Write-Host (Get-Message "InjectingBetterDiscord")
pnpm inject stable
if (-not $?) { throw (Get-Message "InjectionFailed") }

# Launch Discord.
Write-Host (Get-Message "LaunchingDiscord")
$discordExePath = "$env:USERPROFILE\AppData\Local\Discord\Update.exe"
if (Test-Path $discordExePath) {
    Start-Process $discordExePath -ArgumentList "--processStart", "Discord.exe"
} else {
    Write-Warning (Get-Message "DiscordLaunchFailed")
}

Write-Host (Get-Message "InstallationCompleted")
Start-Sleep -Seconds 3
Exit
