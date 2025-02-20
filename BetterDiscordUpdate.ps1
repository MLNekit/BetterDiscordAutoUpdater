<# 
    BetterDiscord Auto-Updater Script
    Last Updated: 2025-02-20

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

    Optional Parameters:
      -PortableDependencies : Use portable versions of dependencies.
      -Debug               : Enable debug logging.
      -DryRun              : Simulate actions without making any changes.
#>

[CmdletBinding()]
param(
    [switch]$PortableDependencies,
    [switch]$Debug,
    [switch]$DryRun
)

# Set strict mode to catch common mistakes
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ====================================
# CONSTANTS
# ====================================
# Paths & Folders
$DISCORD_INSTALL_PATH  = Join-Path $env:LOCALAPPDATA "Discord"
$UPDATE_SCRIPT_FOLDER  = Join-Path $env:APPDATA "BetterDiscord Update Script"
$LOCAL_SCRIPT_PATH     = Join-Path $UPDATE_SCRIPT_FOLDER "BetterDiscordUpdate.ps1"
$REPO_FOLDER           = Join-Path $UPDATE_SCRIPT_FOLDER "BetterDiscord"
$BETTERDISCORD_FOLDER  = Join-Path $env:APPDATA "BetterDiscord"
$START_MENU_FOLDER     = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs"
$SHORTCUT_PATH         = Join-Path $START_MENU_FOLDER "BetterDiscord Update.lnk"
$DEPENDENCIES_PATH     = Join-Path $UPDATE_SCRIPT_FOLDER "Dependencies"
$LOG_FILE_PATH         = Join-Path $UPDATE_SCRIPT_FOLDER "installation.log"

# URLs
$REMOTE_SCRIPT_URL     = "https://raw.githubusercontent.com/MLNekit/BetterDiscordAutoUpdater/main/BetterDiscordUpdate.ps1"
$DISCORD_DOWNLOAD_URL  = "https://discord.com/api/download?platform=win"

# Dependency Versions & URLs (update these constants to use the latest versions)
$GIT_VERSION           = "2.42.0"
$NODE_VERSION          = "20.8.0"
$GIT_PORTABLE_URL      = "https://github.com/git-for-windows/git/releases/latest/download/PortableGit-$GIT_VERSION-64-bit.7z.exe"
$NODE_PORTABLE_URL     = "https://nodejs.org/dist/latest/win-x64/node.exe"

# ====================================
# LOGGING & EXECUTION FUNCTIONS
# ====================================
function Write-Log {
    param(
        [Parameter(Mandatory)]
        [ValidateSet("INFO", "WARN", "ERROR", "DEBUG")]
        [string]$Level,
        [Parameter(Mandatory)]
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp [$Level] - $Message"
    Write-Output $logMessage
    if (-not $DryRun) {
        $logMessage | Out-File -FilePath $LOG_FILE_PATH -Append
    }
}

function Execute-Command {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        [string]$Description = "Executing command"
    )
    Write-Log -Level "DEBUG" -Message $Description
    if (-not $DryRun) {
        & $ScriptBlock
    } else {
        Write-Log -Level "INFO" -Message "DryRun: $Description simulated."
    }
}

# ====================================
# INITIALIZATION: Create Required Folders & Log File
# ====================================
function Initialize-Environment {
    try {
        foreach ($folder in @($UPDATE_SCRIPT_FOLDER, $DEPENDENCIES_PATH)) {
            if (-not (Test-Path $folder)) {
                New-Item -ItemType Directory -Path $folder -Force | Out-Null
                Write-Log -Level "INFO" -Message "Created folder: $folder"
            } else {
                Write-Log -Level "DEBUG" -Message "Folder already exists: $folder"
            }
        }
        if (-not (Test-Path $LOG_FILE_PATH)) {
            New-Item -ItemType File -Path $LOG_FILE_PATH -Force | Out-Null
            Write-Log -Level "INFO" -Message "Created log file: $LOG_FILE_PATH"
        } else {
            Write-Log -Level "DEBUG" -Message "Log file exists: $LOG_FILE_PATH"
        }
    } catch {
        Write-Output "Error during initialization: $_"
        Exit 1
    }
}

# ====================================
# 0. ELEVATION CHECK
# ====================================
function Ensure-Administrator {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    if (-not $isAdmin) {
        Write-Output "Relaunching with administrator privileges..."
        Write-Log -Level "INFO" -Message "Script requires elevation. Relaunching as administrator."
        $args = "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
        if ($PortableDependencies) { $args += " -PortableDependencies" }
        if ($Debug) { $args += " -Debug" }
        if ($DryRun) { $args += " -DryRun" }
        if (-not $DryRun) {
            Start-Process -FilePath "powershell.exe" -ArgumentList $args -Verb RunAs
        }
        Exit
    }
}

# ====================================
# 1. CHECK DISCORD INSTALLATION
# ====================================
function Check-DiscordInstallation {
    try {
        if (-not (Test-Path $DISCORD_INSTALL_PATH)) {
            Write-Output "Discord is not installed. Downloading and installing..."
            Write-Log -Level "INFO" -Message "Discord not found. Initiating installation."
            $DiscordInstaller = Join-Path $env:TEMP "DiscordSetup.exe"
            if (-not $DryRun) {
                Invoke-WebRequest -Uri $DISCORD_DOWNLOAD_URL -OutFile $DiscordInstaller
                # Optionally: Validate checksum or digital signature here.
                Start-Process -FilePath $DiscordInstaller -ArgumentList "--silent" -Wait
                Write-Output "Please complete the installation if required, then press ENTER to continue."
                Read-Host -Prompt "Press ENTER once installation is complete"
            } else {
                Write-Log -Level "INFO" -Message "DryRun: Discord installation simulated."
            }
        } else {
            Write-Output "Discord is already installed."
            Write-Log -Level "INFO" -Message "Discord installation found."
        }
    } catch {
        Write-Log -Level "ERROR" -Message "Failed to check/install Discord: $_"
        Exit 1
    }
}

# ====================================
# 2. TERMINATE DISCORD PROCESSES
# ====================================
function Stop-DiscordProcesses {
    try {
        $discordProcs = Get-Process -Name "Discord" -ErrorAction SilentlyContinue
        if ($discordProcs) {
            Write-Output "Stopping Discord processes..."
            Write-Log -Level "INFO" -Message "Found Discord process(es). Terminating."
            if (-not $DryRun) {
                Stop-Process -Name "Discord" -Force
                Start-Sleep -Seconds 2
            }
        } else {
            Write-Output "Discord is not running."
            Write-Log -Level "INFO" -Message "No running Discord processes found."
        }
    } catch {
        Write-Log -Level "ERROR" -Message "Error stopping Discord: $_"
    }
}

# ====================================
# 3. INSTALL DEPENDENCIES
# ====================================
function Install-Dependencies {
    param(
        [switch]$Portable
    )
    if ($Portable) {
        Install-PortableDependencies
    } else {
        Install-SystemDependencies
    }
}

function Install-PortableDependencies {
    try {
        # Ensure Dependencies folder exists (should have been created during initialization)
        if (-not (Test-Path $DEPENDENCIES_PATH)) {
            New-Item -ItemType Directory -Path $DEPENDENCIES_PATH -Force | Out-Null
            Write-Log -Level "INFO" -Message "Created Dependencies folder."
        }
        # Portable Git
        if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
            Write-Output "Installing portable Git..."
            Write-Log -Level "INFO" -Message "Installing portable Git."
            $gitPortableInstaller = Join-Path $DEPENDENCIES_PATH "PortableGit.exe"
            if (-not (Test-Path $gitPortableInstaller)) {
                if (-not $DryRun) {
                    Invoke-WebRequest -Uri $GIT_PORTABLE_URL -OutFile $gitPortableInstaller
                }
            }
            Execute-Command -ScriptBlock { & $gitPortableInstaller -o ("$DEPENDENCIES_PATH\Git") -y } -Description "Extracting Portable Git"
            $env:PATH = "$DEPENDENCIES_PATH\Git\cmd;$env:PATH"
        } else {
            Write-Log -Level "INFO" -Message "Git is already installed or available in system PATH."
        }
        # Portable Node.js
        if (-not (Get-Command node.exe -ErrorAction SilentlyContinue)) {
            Write-Output "Installing portable Node.js..."
            Write-Log -Level "INFO" -Message "Installing portable Node.js."
            $nodePortablePath = Join-Path $DEPENDENCIES_PATH "node.exe"
            if (-not (Test-Path $nodePortablePath)) {
                if (-not $DryRun) {
                    Invoke-WebRequest -Uri $NODE_PORTABLE_URL -OutFile $nodePortablePath
                }
            }
            $env:PATH = "$DEPENDENCIES_PATH;$env:PATH"
        } else {
            Write-Log -Level "INFO" -Message "Node.js is already installed or available in system PATH."
        }
        # Install pnpm locally
        if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
            Write-Output "Installing pnpm locally..."
            Write-Log -Level "INFO" -Message "Installing pnpm locally."
            if (-not $DryRun) {
                Invoke-Expression (Invoke-WebRequest -Uri "https://get.pnpm.io/install.ps1" -UseBasicParsing).Content
            }
            $env:PATH = "$env:APPDATA\npm;$env:PATH"
        } else {
            Write-Log -Level "INFO" -Message "pnpm is already installed."
        }
    } catch {
        Write-Log -Level "ERROR" -Message "Failed to install portable dependencies: $_"
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
            Write-Output "$Command not found. Installing..."
            Write-Log -Level "INFO" -Message "Installing $Command."
            $installerPath = Join-Path $env:TEMP "$Command-installer.exe"
            if (-not $DryRun) {
                Invoke-WebRequest -Uri $Url -OutFile $installerPath
                # Optionally: Validate digital signature or checksum here.
                if ($InstallerArgs) {
                    Start-Process -FilePath $installerPath -ArgumentList $InstallerArgs -Wait
                } else {
                    Start-Process -FilePath $installerPath -Wait
                }
            } else {
                Write-Log -Level "INFO" -Message "DryRun: $Command installation simulated."
            }
        } else {
            Write-Output "$Command is already installed."
            Write-Log -Level "INFO" -Message "$Command is already installed."
        }
    }
    try {
        # Install Git using GitHub API to retrieve the latest installer URL
        $gitApiUrl = "https://api.github.com/repos/git-for-windows/git/releases/latest"
        if (-not $DryRun) {
            $gitRelease = Invoke-RestMethod -Uri $gitApiUrl
            $gitAsset = $gitRelease.assets | Where-Object { $_.name -match "64-bit.exe" } | Select-Object -First 1
            $gitUrl = $gitAsset.browser_download_url
        } else {
            $gitUrl = "https://example.com/dummy-git-installer.exe"
        }
        Install-Dependency -Command "git" -Url $gitUrl -InstallerArgs "/VERYSILENT"

        # Install Node.js
        $nodeInstallerUrl = "https://nodejs.org/dist/latest/node-v$NODE_VERSION-x64.msi"
        Install-Dependency -Command "node" -Url $nodeInstallerUrl -InstallerArgs "/quiet /norestart"

        # Install pnpm globally
        if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
            Write-Output "Installing pnpm globally..."
            Write-Log -Level "INFO" -Message "Installing pnpm globally."
            if (-not $DryRun) {
                Invoke-Expression (Invoke-WebRequest -Uri "https://get.pnpm.io/install.ps1" -UseBasicParsing).Content
            }
        } else {
            Write-Log -Level "INFO" -Message "pnpm is already installed."
        }

        # Install Bun
        if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
            Write-Output "Installing Bun..."
            Write-Log -Level "INFO" -Message "Installing Bun."
            if (-not $DryRun) {
                Invoke-Expression (Invoke-WebRequest -Uri "https://bun.sh/install.ps1" -UseBasicParsing).Content
            }
        } else {
            Write-Log -Level "INFO" -Message "Bun is already installed."
        }
    } catch {
        Write-Log -Level "ERROR" -Message "Failed to install system dependencies: $_"
        Exit 1
    }
}

# ====================================
# 4. UPDATE THE SCRIPT ITSELF
# ====================================
function Update-Script {
    try {
        if (-not (Test-Path $UPDATE_SCRIPT_FOLDER)) {
            if (-not $DryRun) {
                New-Item -ItemType Directory -Path $UPDATE_SCRIPT_FOLDER -Force | Out-Null
            }
            Write-Log -Level "INFO" -Message "Created Update Script folder."
        }
        # Backup current script
        if (Test-Path $LOCAL_SCRIPT_PATH) {
            $backupPath = "$LOCAL_SCRIPT_PATH.bak"
            if (-not $DryRun) {
                Copy-Item -Path $LOCAL_SCRIPT_PATH -Destination $backupPath -Force
            }
            Write-Log -Level "DEBUG" -Message "Backup of script created at $backupPath."
        }
        # Use a flag file to avoid recursive updates
        $updateFlagFile = Join-Path $UPDATE_SCRIPT_FOLDER "update.flag"
        if (Test-Path $updateFlagFile) {
            Write-Output "Script update already performed this session. Skipping update."
            Write-Log -Level "INFO" -Message "Script update already performed this session."
            return
        }
        $remoteContent = ""
        if (-not $DryRun) {
            $remoteContent = (Invoke-WebRequest -Uri $REMOTE_SCRIPT_URL -UseBasicParsing).Content
        } else {
            $remoteContent = "DryRun content"
        }
        $needsUpdate = $true
        if (Test-Path $LOCAL_SCRIPT_PATH) {
            $localContent = Get-Content -Path $LOCAL_SCRIPT_PATH -Raw
            if ($localContent -eq $remoteContent) {
                $needsUpdate = $false
            }
        }
        if ($needsUpdate) {
            Write-Output "Updater script updated. Relaunching..."
            Write-Log -Level "INFO" -Message "Updater script updated from remote source."
            if (-not $DryRun) {
                $remoteContent | Out-File -FilePath $LOCAL_SCRIPT_PATH -Encoding utf8
                # Create update flag file
                New-Item -Path $updateFlagFile -ItemType File -Force | Out-Null
                $args = "-ExecutionPolicy Bypass -File `"$LOCAL_SCRIPT_PATH`""
                if ($PortableDependencies) { $args += " -PortableDependencies" }
                if ($Debug) { $args += " -Debug" }
                if ($DryRun) { $args += " -DryRun" }
                Start-Process -FilePath "powershell.exe" -ArgumentList $args -Verb RunAs
                Exit
            } else {
                Write-Log -Level "INFO" -Message "DryRun: Script update simulated."
            }
        } else {
            Write-Output "Updater script is up to date."
            Write-Log -Level "INFO" -Message "Updater script is current."
        }
    } catch {
        Write-Log -Level "ERROR" -Message "Failed to update script: $_"
        Exit 1
    }
}

# ====================================
# 5. CLONE OR UPDATE THE BETTERDISCORD REPOSITORY
# ====================================
function Update-BetterDiscordRepo {
    try {
        if (-not (Test-Path $REPO_FOLDER)) {
            Write-Output "Cloning BetterDiscord repository..."
            Write-Log -Level "INFO" -Message "Cloning BetterDiscord repository."
            if (-not $DryRun) {
                git clone "https://github.com/BetterDiscord/BetterDiscord.git" $REPO_FOLDER
            } else {
                Write-Log -Level "INFO" -Message "DryRun: Repository cloning simulated."
            }
        } else {
            Write-Output "Updating BetterDiscord repository..."
            Write-Log -Level "INFO" -Message "Updating BetterDiscord repository."
            if (-not $DryRun) {
                Push-Location $REPO_FOLDER
                git pull
                Pop-Location
            } else {
                Write-Log -Level "INFO" -Message "DryRun: Repository update simulated."
            }
        }
    } catch {
        Write-Log -Level "ERROR" -Message "Failed to update BetterDiscord repository: $_"
        Exit 1
    }
}

# ====================================
# 6. CREATE A START MENU SHORTCUT FOR THE UPDATER
# ====================================
function Create-StartMenuShortcut {
    try {
        if (-not (Test-Path $SHORTCUT_PATH)) {
            Write-Output "Creating Start Menu shortcut..."
            Write-Log -Level "INFO" -Message "Creating Start Menu shortcut."
            $wshShell = New-Object -ComObject WScript.Shell
            $shortcut = $wshShell.CreateShortcut($SHORTCUT_PATH)
            $shortcut.TargetPath = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
            $scriptPathForArgs = $LOCAL_SCRIPT_PATH
            if ($scriptPathForArgs -match "\s") {
                $scriptPathForArgs = "`"" + $scriptPathForArgs + "`""
            }
            $arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File $scriptPathForArgs"
            if ($PortableDependencies) { $arguments += " -PortableDependencies" }
            if ($Debug) { $arguments += " -Debug" }
            if ($DryRun) { $arguments += " -DryRun" }
            $shortcut.Arguments = $arguments
            $iconPath = Join-Path $DISCORD_INSTALL_PATH "app.ico"
            if (Test-Path $iconPath) {
                $shortcut.IconLocation = $iconPath
            } else {
                Write-Log -Level "WARN" -Message "Icon file not found at $iconPath. Using default icon."
            }
            $shortcut.Save()
            Write-Output "Shortcut created. Restart your Start Menu if necessary."
            Write-Log -Level "INFO" -Message "Start Menu shortcut created."
        } else {
            Write-Output "Start Menu shortcut already exists."
            Write-Log -Level "INFO" -Message "Start Menu shortcut exists."
        }
    } catch {
        Write-Log -Level "ERROR" -Message "Failed to create Start Menu shortcut: $_"
    }
}

# ====================================
# 7. ENSURE THE BETTERDISCORD FOLDER EXISTS
# ====================================
function Ensure-BetterDiscordFolder {
    try {
        if (-not (Test-Path $BETTERDISCORD_FOLDER)) {
            if (-not $DryRun) {
                New-Item -ItemType Directory -Path $BETTERDISCORD_FOLDER -Force | Out-Null
            }
            Write-Output "Created BetterDiscord folder."
            Write-Log -Level "INFO" -Message "BetterDiscord folder created."
        } else {
            Write-Output "BetterDiscord folder already exists."
            Write-Log -Level "INFO" -Message "BetterDiscord folder exists."
        }
    } catch {
        Write-Log -Level "ERROR" -Message "Failed to ensure BetterDiscord folder: $_"
        Exit 1
    }
}

# ====================================
# 8. INSTALL, BUILD, AND INJECT BETTERDISCORD
# ====================================
function Install-BetterDiscord {
    try {
        if (-not (Test-Path $REPO_FOLDER)) {
            Write-Log -Level "ERROR" -Message "Repository folder not found. Cannot build BetterDiscord."
            Exit 1
        }
        Push-Location $REPO_FOLDER
        # Ensure pnpm is available
        if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
            Write-Output "Installing pnpm..."
            Write-Log -Level "INFO" -Message "Installing pnpm."
            if (-not $DryRun) {
                npm install -g pnpm
            }
        }
        Write-Output "Installing BetterDiscord dependencies..."
        Write-Log -Level "INFO" -Message "Installing BetterDiscord dependencies."
        if (-not $DryRun) {
            pnpm install
        }
        Write-Output "Building BetterDiscord..."
        Write-Log -Level "INFO" -Message "Building BetterDiscord."
        if (-not $DryRun) {
            pnpm build
        }
        Write-Output "Injecting BetterDiscord..."
        Write-Log -Level "INFO" -Message "Injecting BetterDiscord."
        if (-not $DryRun) {
            pnpm inject
        }
        Pop-Location
    } catch {
        Write-Log -Level "ERROR" -Message "Failed to install BetterDiscord: $_"
        Exit 1
    }
}

# ====================================
# 9. LAUNCH DISCORD
# ====================================
function Launch-Discord {
    try {
        $discordUpdater = Join-Path $DISCORD_INSTALL_PATH "Update.exe"
        if (Test-Path $discordUpdater) {
            Write-Output "Launching Discord..."
            Write-Log -Level "INFO" -Message "Launching Discord."
            if (-not $DryRun) {
                Start-Process -FilePath $discordUpdater -ArgumentList "--processStart", "Discord.exe"
            }
        } else {
            Write-Log -Level "ERROR" -Message "Discord updater not found."
        }
        Write-Output "BetterDiscord installation/update completed!"
        Write-Log -Level "INFO" -Message "BetterDiscord installation/update completed."
    } catch {
        Write-Log -Level "ERROR" -Message "Failed to launch Discord: $_"
    }
}

# ====================================
# MAIN SCRIPT EXECUTION
# ====================================
try {
    Initialize-Environment
    Write-Log -Level "INFO" -Message "Script execution started."
    
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

    # Remove the update flag for future sessions
    $updateFlagFile = Join-Path $UPDATE_SCRIPT_FOLDER "update.flag"
    if (Test-Path $updateFlagFile -and -not $DryRun) {
        Remove-Item -Path $updateFlagFile -Force
    }
    Write-Log -Level "INFO" -Message "Script execution completed successfully."
} catch {
    Write-Log -Level "ERROR" -Message "An unexpected error occurred: $_"
    Exit 1
}
