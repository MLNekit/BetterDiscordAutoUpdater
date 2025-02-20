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

param(
    [switch]$PortableDependencies
)

# Variables and Constants
$DiscordInstallPath     = Join-Path $env:LOCALAPPDATA "Discord"
$UpdateScriptFolder     = Join-Path $env:APPDATA "BetterDiscord Update Script"
$LocalScriptPath        = Join-Path $UpdateScriptFolder "BetterDiscordUpdate.ps1"
$RemoteScriptURL        = "https://raw.githubusercontent.com/MLNekit/BetterDiscordAutoUpdater/main/BetterDiscordUpdate.ps1"
$RepoFolder             = Join-Path $UpdateScriptFolder "BetterDiscord"
$BetterDiscordFolder    = Join-Path $env:APPDATA "BetterDiscord"
$StartMenuFolder        = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs"
$ShortcutPath           = Join-Path $StartMenuFolder "BetterDiscord Update.lnk"
$DependenciesPath       = Join-Path $UpdateScriptFolder "Dependencies"
$LogFilePath            = Join-Path $UpdateScriptFolder "installation.log"

# Logging Function
function Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Timestamp - $Message" | Out-File -FilePath $LogFilePath -Append
}

# ========= 0. ELEVATION CHECK =========
function Ensure-Administrator {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Host "Relaunching with administrator privileges..."
        Log "Script requires elevation. Relaunching as administrator."
        $args = "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
        if ($PortableDependencies) { $args += " -PortableDependencies" }
        Start-Process -FilePath "powershell.exe" -ArgumentList $args -Verb RunAs
        Exit
    }
}

# ========= 1. CHECK DISCORD INSTALLATION =========
function Check-DiscordInstallation {
    try {
        if (-not (Test-Path $DiscordInstallPath)) {
            Write-Host "Discord is not installed. Downloading and installing..."
            Log "Discord not found. Initiating installation."
            $DiscordInstaller = "$env:TEMP\DiscordSetup.exe"
            Invoke-WebRequest "https://discord.com/api/download?platform=win" -OutFile $DiscordInstaller
            Start-Process -FilePath $DiscordInstaller -ArgumentList "--silent" -Wait
            Read-Host -Prompt "Press ENTER to continue once installation is complete"
        } else {
            Write-Host "Discord is already installed."
            Log "Discord is installed."
        }
    } catch {
        Write-Error "Failed to install Discord: $_"
        Log "Error installing Discord: $_"
        Exit 1
    }
}

# ========= 2. TERMINATE DISCORD =========
function Stop-DiscordProcesses {
    try {
        $DiscordProcess = Get-Process -Name "Discord" -ErrorAction SilentlyContinue
        if ($DiscordProcess) {
            Write-Host "Stopping Discord..."
            Log "Discord process found. Stopping."
            Stop-Process -Name "Discord" -Force
            Start-Sleep -Seconds 2
        } else {
            Write-Host "Discord is not running."
            Log "Discord process not running."
        }
    } catch {
        Write-Error "Failed to stop Discord: $_"
        Log "Error stopping Discord: $_"
    }
}

# ========= 3. INSTALL DEPENDENCIES =========
function Install-Dependencies {
    param([switch]$Portable)

    if ($Portable) {
        Install-PortableDependencies
    } else {
        Install-SystemDependencies
    }
}

function Install-PortableDependencies {
    try {
        if (-not (Test-Path $DependenciesPath)) {
            New-Item -ItemType Directory -Path $DependenciesPath -Force | Out-Null
        }

        # Portable Git
        if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
            Write-Host "Installing portable Git..."
            Log "Installing portable Git."
            $GitPortableUrl  = "https://github.com/git-for-windows/git/releases/latest/download/PortableGit-2.42.0-64-bit.7z.exe"
            $GitPortablePath = Join-Path $DependenciesPath "PortableGit.exe"
            if (-not (Test-Path $GitPortablePath)) {
                Invoke-WebRequest $GitPortableUrl -OutFile $GitPortablePath
            }
            & $GitPortablePath -o"$DependenciesPath\Git" -y
            $env:PATH = "$DependenciesPath\Git\cmd;$env:PATH"
        }

        # Portable Node.js
        if (-not (Get-Command node.exe -ErrorAction SilentlyContinue)) {
            Write-Host "Installing portable Node.js..."
            Log "Installing portable Node.js."
            $NodePortableUrl  = "https://nodejs.org/dist/latest/win-x64/node.exe"
            $NodePortablePath = Join-Path $DependenciesPath "node.exe"
            if (-not (Test-Path $NodePortablePath)) {
                Invoke-WebRequest $NodePortableUrl -OutFile $NodePortablePath
            }
            $env:PATH = "$DependenciesPath;$env:PATH"
        }

        # Install pnpm locally
        if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
            Write-Host "Installing pnpm locally..."
            Log "Installing pnpm locally."
            $PnpmInstallScript = "https://get.pnpm.io/install.ps1"
            Invoke-Expression (Invoke-WebRequest $PnpmInstallScript -UseBasicParsing).Content
            $env:PATH = "$env:APPDATA\npm;$env:PATH"
        }
    } catch {
        Write-Error "Failed to install portable dependencies: $_"
        Log "Error installing portable dependencies: $_"
        Exit 1
    }
}

function Install-SystemDependencies {
    function Install-Dependency {
        param (
            [string]$Command,
            [string]$Url,
            [string]$InstallerArgs = ""
        )
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            Write-Host "$Command not found. Installing..."
            Log "Installing $Command."
            $InstallerPath = "$env:TEMP\$($Command)-installer.exe"
            Invoke-WebRequest $Url -OutFile $InstallerPath
            if ($InstallerArgs) {
                Start-Process -FilePath $InstallerPath -ArgumentList $InstallerArgs -Wait
            } else {
                Start-Process -FilePath $InstallerPath -Wait
            }
        } else {
            Write-Host "$Command is already installed."
            Log "$Command is already installed."
        }
    }

    try {
        # Install Git
        $GitUrl = ((Invoke-RestMethod "https://api.github.com/repos/git-for-windows/git/releases/latest").assets | Where-Object name -match "64-bit.exe" | Select-Object -ExpandProperty browser_download_url)
        Install-Dependency "git" $GitUrl "/VERYSILENT"

        # Install Node.js
        Install-Dependency "node" "https://nodejs.org/dist/latest/node-v20.8.0-x64.msi" "/quiet /norestart"

        # Install pnpm
        if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
            Write-Host "Installing pnpm globally..."
            Log "Installing pnpm globally."
            Invoke-Expression (Invoke-WebRequest "https://get.pnpm.io/install.ps1" -UseBasicParsing).Content
        } else {
            Write-Host "pnpm is already installed."
            Log "pnpm is already installed."
        }

        # Install Bun
        if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
            Write-Host "Installing Bun..."
            Log "Installing Bun."
            Invoke-Expression (Invoke-WebRequest "https://bun.sh/install.ps1" -UseBasicParsing).Content
        } else {
            Write-Host "Bun is already installed."
            Log "Bun is already installed."
        }
    } catch {
        Write-Error "Failed to install system dependencies: $_"
        Log "Error installing system dependencies: $_"
        Exit 1
    }
}

# ========= 4. UPDATE SCRIPT =========
function Update-Script {
    try {
        if (-not (Test-Path $UpdateScriptFolder)) {
            New-Item -ItemType Directory -Path $UpdateScriptFolder -Force | Out-Null
        }

        # Path to a temporary flag file indicating an update has occurred
        $UpdateFlagFile = Join-Path $UpdateScriptFolder "update.flag"

        if (Test-Path $UpdateFlagFile) {
            Write-Host "Script has already been updated in this session. Skipping update to prevent recursion."
            Log "Script update already performed in this session. Skipping."
            return
        }

        $RemoteContent = (Invoke-WebRequest $RemoteScriptURL -UseBasicParsing).Content
        $NeedsUpdate = $true

        if (Test-Path $LocalScriptPath) {
            $LocalContent = Get-Content $LocalScriptPath -Raw
            if ($LocalContent -eq $RemoteContent) {
                $NeedsUpdate = $false
            }
        }

        if ($NeedsUpdate) {
            Write-Host "Updater script updated. Relaunching..."
            Log "Updater script updated from remote source."
            $RemoteContent | Out-File -FilePath $LocalScriptPath -Encoding utf8

            # Create the flag file to indicate an update has occurred
            New-Item -Path $UpdateFlagFile -ItemType File -Force | Out-Null

            # Relaunch the updated script
            $args = "-ExecutionPolicy Bypass -File `"$LocalScriptPath`""
            if ($PortableDependencies) { $args += " -PortableDependencies" }
            Start-Process -FilePath "powershell.exe" -ArgumentList $args -Verb RunAs
            Exit
        } else {
            Write-Host "Updater script is up to date."
            Log "Updater script is current."
        }
    } catch {
        Write-Error "Failed to update script: $_"
        Log "Error updating script: $_"
        Exit 1
    }
}

# ========= 5. CLONE/UPDATE BETTERDISCORD REPO =========
function Update-BetterDiscordRepo {
    try {
        if (-not (Test-Path $RepoFolder)) {
            Write-Host "Cloning BetterDiscord repository..."
            Log "Cloning BetterDiscord repository."
            git clone "https://github.com/BetterDiscord/BetterDiscord.git" $RepoFolder
        } else {
            Write-Host "Updating BetterDiscord repository..."
            Log "Updating BetterDiscord repository."
            Push-Location $RepoFolder
            git pull
            Pop-Location
        }
    } catch {
        Write-Error "Failed to update BetterDiscord repository: $_"
        Log "Error updating BetterDiscord repository: $_"
        Exit 1
    }
}

# ========= 6. CREATE START MENU SHORTCUT =========
function Create-StartMenuShortcut {
    try {
        if (-not (Test-Path $ShortcutPath)) {
            Write-Host "Creating Start Menu shortcut..."
            Log "Creating Start Menu shortcut."
            $WshShell = New-Object -ComObject WScript.Shell
            $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
            
            $Shortcut.TargetPath = (Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe")
            
            if ($LocalScriptPath -match "\s") {
                $LocalScriptPath = "`"" + $LocalScriptPath + "`""
            }
            $Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File $LocalScriptPath"
            if ($PortableDependencies) {
                $Arguments += " -PortableDependencies"
            }
            $Shortcut.Arguments = $Arguments
            
            $IconPath = Join-Path $DiscordInstallPath "app.ico"
            if (Test-Path $IconPath) {
                $Shortcut.IconLocation = $IconPath
            } else {
                Write-Error "Icon file not found: $IconPath"
                Log "Icon file not found: $IconPath"
            }
            
            $Shortcut.Save()

            Stop-Process -Name explorer -Force
            Start-Process explorer
        } else {
            Write-Host "Start Menu shortcut already exists."
            Log "Start Menu shortcut already exists."
        }
    } catch {
        Write-Error "Failed to create Start Menu shortcut: $_"
        Log "Error creating Start Menu shortcut: $_"
    }
}

# ========= 7. ENSURE BETTERDISCORD FOLDER EXISTS =========
function Ensure-BetterDiscordFolder {
    try {
        if (-not (Test-Path $BetterDiscordFolder)) {
            New-Item -ItemType Directory -Path $BetterDiscordFolder -Force | Out-Null
            Write-Host "Created BetterDiscord folder."
            Log "BetterDiscord folder created."
        } else {
            Write-Host "BetterDiscord folder already exists."
            Log "BetterDiscord folder exists."
        }
    } catch {
        Write-Error "Failed to ensure BetterDiscord folder: $_"
        Log "Error ensuring BetterDiscord folder: $_"
        Exit 1
    }
}

# ========= 8. INSTALL, BUILD, AND INJECT BETTERDISCORD =========
function Install-BetterDiscord {
    try {
        Push-Location $RepoFolder

        # Install pnpm if not already installed
        if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
            Write-Host "Installing pnpm..."
            Log "Installing pnpm."
            npm install -g pnpm
        }

        Write-Host "Installing BetterDiscord dependencies..."
        Log "Installing BetterDiscord dependencies."
        pnpm install

        Write-Host "Building BetterDiscord..."
        Log "Building BetterDiscord."
        pnpm build

        Write-Host "Injecting BetterDiscord..."
        Log "Injecting BetterDiscord."
        pnpm inject

        Pop-Location
    } catch {
        Write-Error "Failed to install BetterDiscord: $_"
        Log "Error installing BetterDiscord: $_"
        Exit 1
    }
}

# ========= 9. LAUNCH DISCORD =========
function Launch-Discord {
    try {
        $DiscordUpdater = Join-Path $env:LOCALAPPDATA "Discord\Update.exe"
        if (Test-Path $DiscordUpdater) {
            Write-Host "Launching Discord..."
            Log "Launching Discord."
            Start-Process -FilePath $DiscordUpdater -ArgumentList "--processStart", "Discord.exe"
        } else {
            Write-Error "Discord updater not found."
            Log "Discord updater not found."
        }

        Write-Host "BetterDiscord installation/update completed!"
        Log "BetterDiscord installation/update completed."
    } catch {
        Write-Error "Failed to launch Discord: $_"
        Log "Error launching Discord: $_"
    }
}

# ========= MAIN SCRIPT EXECUTION =========
try {
    Log "Script execution started."

    Ensure-Administrator
    Update-Script
    Install-Dependencies -Portable:$PortableDependencies
    Check-DiscordInstallation
    Stop-DiscordProcesses
    Update-BetterDiscordRepo
    Create-StartMenuShortcut
    Ensure-BetterDiscordFolder
    Install-BetterDiscord
    Launch-Discord

    # Remove the update flag file to allow updates in the next session
    $UpdateFlagFile = Join-Path $UpdateScriptFolder "update.flag"
    if (Test-Path $UpdateFlagFile) {
        Remove-Item $UpdateFlagFile -Force
    }

    Log "Script execution completed successfully."
} catch {
    Write-Error "An unexpected error occurred: $_"
    Log "Unexpected error: $_"
    Exit 1
}
