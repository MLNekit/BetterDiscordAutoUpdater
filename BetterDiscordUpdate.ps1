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

param(
    [switch]$PortableDependencies,
    [switch]$Debug,
    [switch]$DryRun
)

# Global Variables and Constants
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

# Version variables for dependencies (adjust as needed)
$GitVersion  = "2.42.0"
$NodeVersion = "20.8.0"

# ===============================
# Logging and Execution Functions
# ===============================
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("INFO", "WARN", "ERROR", "DEBUG")]
        [string]$Level,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$Timestamp [$Level] - $Message"
    Write-Output $logMessage
    if (-not $DryRun) {
        $logMessage | Out-File -FilePath $LogFilePath -Append
    }
}

function Execute-Command {
    param(
        [Parameter(Mandatory = $true)]
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

# ===============================
# 0. ELEVATION CHECK
# ===============================
function Ensure-Administrator {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
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

# ===============================
# 1. CHECK DISCORD INSTALLATION
# ===============================
function Check-DiscordInstallation {
    try {
        if (-not (Test-Path $DiscordInstallPath)) {
            Write-Output "Discord is not installed. Downloading and installing..."
            Write-Log -Level "INFO" -Message "Discord not found. Initiating installation."
            $DiscordInstaller = Join-Path $env:TEMP "DiscordSetup.exe"
            if (-not $DryRun) {
                Invoke-WebRequest "https://discord.com/api/download?platform=win" -OutFile $DiscordInstaller
                # Optionally: Validate checksum or digital signature here.
                Start-Process -FilePath $DiscordInstaller -ArgumentList "--silent" -Wait
                Write-Output "Please complete the installation if required, then press ENTER to continue."
                Read-Host -Prompt "Press ENTER to continue once installation is complete"
            } else {
                Write-Log -Level "INFO" -Message "DryRun: Discord installation simulated."
            }
        } else {
            Write-Output "Discord is already installed."
            Write-Log -Level "INFO" -Message "Discord is installed."
        }
    } catch {
        Write-Log -Level "ERROR" -Message "Failed to install Discord: $_"
        Exit 1
    }
}

# ===============================
# 2. TERMINATE DISCORD
# ===============================
function Stop-DiscordProcesses {
    try {
        $DiscordProcesses = Get-Process -Name "Discord" -ErrorAction SilentlyContinue
        if ($DiscordProcesses) {
            Write-Output "Stopping Discord..."
            Write-Log -Level "INFO" -Message "Discord process found. Stopping."
            if (-not $DryRun) {
                Stop-Process -Name "Discord" -Force
                Start-Sleep -Seconds 2
            }
        } else {
            Write-Output "Discord is not running."
            Write-Log -Level "INFO" -Message "Discord process not running."
        }
    } catch {
        Write-Log -Level "ERROR" -Message "Failed to stop Discord: $_"
    }
}

# ===============================
# 3. INSTALL DEPENDENCIES
# ===============================
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
            if (-not $DryRun) {
                New-Item -ItemType Directory -Path $DependenciesPath -Force | Out-Null
            }
            Write-Log -Level "INFO" -Message "Dependencies folder created."
        }

        # Portable Git
        if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
            Write-Output "Installing portable Git..."
            Write-Log -Level "INFO" -Message "Installing portable Git."
            $GitPortableUrl  = "https://github.com/git-for-windows/git/releases/latest/download/PortableGit-$GitVersion-64-bit.7z.exe"
            $GitPortablePath = Join-Path $DependenciesPath "PortableGit.exe"
            if (-not (Test-Path $GitPortablePath)) {
                if (-not $DryRun) {
                    Invoke-WebRequest $GitPortableUrl -OutFile $GitPortablePath
                }
            }
            Execute-Command -ScriptBlock { & $GitPortablePath -o"$DependenciesPath\Git" -y } -Description "Extracting Portable Git"
            $env:PATH = "$DependenciesPath\Git\cmd;$env:PATH"
        } else {
            Write-Log -Level "INFO" -Message "Portable Git already installed or available in system PATH."
        }

        # Portable Node.js
        if (-not (Get-Command node.exe -ErrorAction SilentlyContinue)) {
            Write-Output "Installing portable Node.js..."
            Write-Log -Level "INFO" -Message "Installing portable Node.js."
            $NodePortableUrl  = "https://nodejs.org/dist/latest/win-x64/node.exe"
            $NodePortablePath = Join-Path $DependenciesPath "node.exe"
            if (-not (Test-Path $NodePortablePath)) {
                if (-not $DryRun) {
                    Invoke-WebRequest $NodePortableUrl -OutFile $NodePortablePath
                }
            }
            $env:PATH = "$DependenciesPath;$env:PATH"
        } else {
            Write-Log -Level "INFO" -Message "Portable Node.js already installed or available in system PATH."
        }

        # Install pnpm locally
        if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
            Write-Output "Installing pnpm locally..."
            Write-Log -Level "INFO" -Message "Installing pnpm locally."
            if (-not $DryRun) {
                Invoke-Expression (Invoke-WebRequest "https://get.pnpm.io/install.ps1" -UseBasicParsing).Content
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
            $InstallerPath = Join-Path $env:TEMP "$Command-installer.exe"
            if (-not $DryRun) {
                Invoke-WebRequest $Url -OutFile $InstallerPath
                # Optionally: Validate the digital signature or checksum here.
                if ($InstallerArgs) {
                    Start-Process -FilePath $InstallerPath -ArgumentList $InstallerArgs -Wait
                } else {
                    Start-Process -FilePath $InstallerPath -Wait
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
        # Install Git
        $GitApiUrl = "https://api.github.com/repos/git-for-windows/git/releases/latest"
        if (-not $DryRun) {
            $GitRelease = Invoke-RestMethod $GitApiUrl
            $GitAsset = $GitRelease.assets | Where-Object { $_.name -match "64-bit.exe" } | Select-Object -First 1
            $GitUrl = $GitAsset.browser_download_url
        } else {
            $GitUrl = "https://example.com/dummy-git-installer.exe"
        }
        Install-Dependency -Command "git" -Url $GitUrl -InstallerArgs "/VERYSILENT"

        # Install Node.js
        Install-Dependency -Command "node" -Url "https://nodejs.org/dist/latest/node-v$NodeVersion-x64.msi" -InstallerArgs "/quiet /norestart"

        # Install pnpm globally
        if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
            Write-Output "Installing pnpm globally..."
            Write-Log -Level "INFO" -Message "Installing pnpm globally."
            if (-not $DryRun) {
                Invoke-Expression (Invoke-WebRequest "https://get.pnpm.io/install.ps1" -UseBasicParsing).Content
            }
        } else {
            Write-Log -Level "INFO" -Message "pnpm is already installed."
        }

        # Install Bun
        if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
            Write-Output "Installing Bun..."
            Write-Log -Level "INFO" -Message "Installing Bun."
            if (-not $DryRun) {
                Invoke-Expression (Invoke-WebRequest "https://bun.sh/install.ps1" -UseBasicParsing).Content
            }
        } else {
            Write-Log -Level "INFO" -Message "Bun is already installed."
        }
    } catch {
        Write-Log -Level "ERROR" -Message "Failed to install system dependencies: $_"
        Exit 1
    }
}

# ===============================
# 4. UPDATE SCRIPT
# ===============================
function Update-Script {
    try {
        if (-not (Test-Path $UpdateScriptFolder)) {
            if (-not $DryRun) {
                New-Item -ItemType Directory -Path $UpdateScriptFolder -Force | Out-Null
            }
            Write-Log -Level "INFO" -Message "Update Script folder created."
        }

        # Backup current script before updating
        if (Test-Path $LocalScriptPath) {
            $BackupPath = "$LocalScriptPath.bak"
            if (-not $DryRun) {
                Copy-Item $LocalScriptPath $BackupPath -Force
            }
            Write-Log -Level "DEBUG" -Message "Backup created at $BackupPath."
        }

        # Use a flag file to prevent update recursion
        $UpdateFlagFile = Join-Path $UpdateScriptFolder "update.flag"
        if (Test-Path $UpdateFlagFile) {
            Write-Output "Script update already performed this session. Skipping update."
            Write-Log -Level "INFO" -Message "Script update already performed this session."
            return
        }

        $RemoteContent = ""
        if (-not $DryRun) {
            $RemoteContent = (Invoke-WebRequest $RemoteScriptURL -UseBasicParsing).Content
        } else {
            $RemoteContent = "DryRun content"
        }
        $NeedsUpdate = $true

        if (Test-Path $LocalScriptPath) {
            $LocalContent = Get-Content $LocalScriptPath -Raw
            if ($LocalContent -eq $RemoteContent) {
                $NeedsUpdate = $false
            }
        }

        if ($NeedsUpdate) {
            Write-Output "Updater script updated. Relaunching..."
            Write-Log -Level "INFO" -Message "Updater script updated from remote source."
            if (-not $DryRun) {
                $RemoteContent | Out-File -FilePath $LocalScriptPath -Encoding utf8
                # Create update flag file
                New-Item -Path $UpdateFlagFile -ItemType File -Force | Out-Null
                $args = "-ExecutionPolicy Bypass -File `"$LocalScriptPath`""
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

# ===============================
# 5. CLONE/UPDATE BETTERDISCORD REPO
# ===============================
function Update-BetterDiscordRepo {
    try {
        if (-not (Test-Path $RepoFolder)) {
            Write-Output "Cloning BetterDiscord repository..."
            Write-Log -Level "INFO" -Message "Cloning BetterDiscord repository."
            if (-not $DryRun) {
                git clone "https://github.com/BetterDiscord/BetterDiscord.git" $RepoFolder
            } else {
                Write-Log -Level "INFO" -Message "DryRun: Repository cloning simulated."
            }
        } else {
            Write-Output "Updating BetterDiscord repository..."
            Write-Log -Level "INFO" -Message "Updating BetterDiscord repository."
            if (-not $DryRun) {
                Push-Location $RepoFolder
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

# ===============================
# 6. CREATE START MENU SHORTCUT
# ===============================
function Create-StartMenuShortcut {
    try {
        if (-not (Test-Path $ShortcutPath)) {
            Write-Output "Creating Start Menu shortcut..."
            Write-Log -Level "INFO" -Message "Creating Start Menu shortcut."
            $WshShell = New-Object -ComObject WScript.Shell
            $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
            $Shortcut.TargetPath = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
            $ScriptPathForArgs = $LocalScriptPath
            if ($ScriptPathForArgs -match "\s") {
                $ScriptPathForArgs = "`"" + $ScriptPathForArgs + "`""
            }
            $Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File $ScriptPathForArgs"
            if ($PortableDependencies) { $Arguments += " -PortableDependencies" }
            if ($Debug) { $Arguments += " -Debug" }
            if ($DryRun) { $Arguments += " -DryRun" }
            $Shortcut.Arguments = $Arguments
            $IconPath = Join-Path $DiscordInstallPath "app.ico"
            if (Test-Path $IconPath) {
                $Shortcut.IconLocation = $IconPath
            } else {
                Write-Log -Level "WARN" -Message "Icon file not found at $IconPath. Default icon will be used."
            }
            $Shortcut.Save()
            Write-Output "Shortcut created. Please restart your Start Menu if necessary."
            Write-Log -Level "INFO" -Message "Start Menu shortcut created."
        } else {
            Write-Output "Start Menu shortcut already exists."
            Write-Log -Level "INFO" -Message "Start Menu shortcut already exists."
        }
    } catch {
        Write-Log -Level "ERROR" -Message "Failed to create Start Menu shortcut: $_"
    }
}

# ===============================
# 7. ENSURE BETTERDISCORD FOLDER EXISTS
# ===============================
function Ensure-BetterDiscordFolder {
    try {
        if (-not (Test-Path $BetterDiscordFolder)) {
            if (-not $DryRun) {
                New-Item -ItemType Directory -Path $BetterDiscordFolder -Force | Out-Null
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

# ===============================
# 8. INSTALL, BUILD, AND INJECT BETTERDISCORD
# ===============================
function Install-BetterDiscord {
    try {
        if (-not (Test-Path $RepoFolder)) {
            Write-Log -Level "ERROR" -Message "Repository folder not found. Cannot build BetterDiscord."
            Exit 1
        }
        Push-Location $RepoFolder

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

# ===============================
# 9. LAUNCH DISCORD
# ===============================
function Launch-Discord {
    try {
        $DiscordUpdater = Join-Path $env:LOCALAPPDATA "Discord\Update.exe"
        if (Test-Path $DiscordUpdater) {
            Write-Output "Launching Discord..."
            Write-Log -Level "INFO" -Message "Launching Discord."
            if (-not $DryRun) {
                Start-Process -FilePath $DiscordUpdater -ArgumentList "--processStart", "Discord.exe"
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

# ===============================
# MAIN SCRIPT EXECUTION
# ===============================
try {
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

    # Remove update flag file for next session
    $UpdateFlagFile = Join-Path $UpdateScriptFolder "update.flag"
    if (Test-Path $UpdateFlagFile -and -not $DryRun) {
        Remove-Item $UpdateFlagFile -Force
    }
    Write-Log -Level "INFO" -Message "Script execution completed successfully."
} catch {
    Write-Log -Level "ERROR" -Message "An unexpected error occurred: $_"
    Exit 1
}
