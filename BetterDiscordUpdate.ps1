<#
.SYNOPSIS
    BetterDiscord Auto-Update & Installation Script with Menu

.DESCRIPTION
    Этот скрипт поддерживает установку Discord, BetterDiscord, автообновление скрипта,
    а также удаление установленных компонентов. При запуске скрипта выводится меню,
    в котором пользователь может выбрать нужный сценарий. Скрипт включает проверки,
    обновление зависимостей (Git, Node.js, pnpm) и автоматическое обновление себя из GitHub.

.PARAMETER Remote
    Если указан, скрипт работает в режиме удалённого выполнения (без локальной установки).

.PARAMETER Language
    Язык сообщений ("en" или "ru"). По умолчанию определяется по системной культуре, если не задано.

.PARAMETER NoSelfUpdate
    Внутренний переключатель для предотвращения рекурсии при самообновлении.
#>

[CmdletBinding()]
param(
    [switch]$Remote,
    [string]$Language,
    [switch]$NoSelfUpdate  # Внутренний переключатель
)

#------------------------------#
# Определение языка (ru/en)    #
#------------------------------#
if (-not $Language) {
    $sysLang = (Get-UICulture).Name
    if ($sysLang -match "^ru") { $Language = "ru" } else { $Language = "en" }
}

#--------------------------------#
# Константы и пути               #
#--------------------------------#
$requiredGitVersion  = [version]"2.47.1"
$requiredNodeVersion = [version]"22.13.1"

$gitInstallerUrl  = "https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.2/Git-2.47.1.2-64-bit.exe"
$nodeInstallerUrl = "https://nodejs.org/dist/v22.13.1/node-v22.13.1-x64.msi"
$pnpmInstallerUrl = "https://get.pnpm.io/install.ps1"

# Ссылка на удалённую версию скрипта
$scriptVersion = "1.0.0"
$remoteScriptUrl = "https://raw.githubusercontent.com/MLNekit/BetterDiscordAutoUpdater/main/BetterDiscordUpdate.ps1"

# Папки для установки и ярлык
$BaseFolder = Join-Path $env:APPDATA "BetterDiscord Update Script"
$LocalScriptPath = Join-Path $BaseFolder "BetterDiscordUpdate.ps1"
$BetterDiscordFolder = Join-Path $BaseFolder "BetterDiscord"
$StartMenuFolder = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs"
$ShortcutName = "BetterDiscord Update.lnk"

#--------------------------------#
# Локализованные сообщения       #
#--------------------------------#
$messages = @{
    en = @{
        "MenuTitle"                = "BetterDiscord Auto-Update Script - Select a scenario:"
        "Option0"                  = "0) Exit"
        "Option1"                  = "1) Install Discord"
        "Option2"                  = "2) Install Discord (and Start)"
        "Option3"                  = "3) Install Discord and BetterDiscord"
        "Option4"                  = "4) Install Discord and BetterDiscord (and Start)"
        "Option5"                  = "5) Install BetterDiscord"
        "Option6"                  = "6) Install BetterDiscord (and Start)"
        "Option7"                  = "7) Install Discord, BetterDiscord and Auto-Update Script"
        "Option8"                  = "8) Install Discord, BetterDiscord and Auto-Update Script (and Start)"
        "Option9"                  = "9) Install/Update Auto-Update Script"
        "Option10"                 = "10) Install/Update Auto-Update Script (and Start)"
        "Option11"                 = "11) Uninstall Auto-Update Script"
        "Option12"                 = "12) Uninstall Git/Node.JS/pnpm"
        "EnterChoice"              = "Enter your choice: "
        "InvalidChoice"            = "Invalid choice. Please try again."
        "ErrorOccurred"            = "An error occurred: "
        "ClosingDiscord"           = "Closing Discord..."
        "DiscordRunningAbort"      = "Discord is running! Aborting scenario."
        "DiscordNotRunning"        = "Discord is not running."
        "DiscordNotInstalled"      = "Discord is not installed. Installing..."
        "DiscordAlreadyInstalled"  = "Discord is already installed."
        "InstallingDiscord"        = "Downloading and installing Discord..."
        "DiscordInstallFailed"     = "Discord installation failed."
        "LaunchingDiscord"         = "Launching Discord..."
        "DiscordLaunchFailed"      = "Failed to launch Discord."
        "DependenciesInstalled"    = "All dependencies are installed."
        "CheckingGit"              = "Checking for Git..."
        "GitInstalled"             = "Git is installed."
        "InstallingGit"            = "Git not installed/outdated. Installing/updating Git..."
        "GitInstalledSuccess"      = "Git installed/updated successfully."
        "CheckingNode"             = "Checking for Node.js..."
        "NodeInstalled"            = "Node.js is installed."
        "InstallingNode"           = "Node.js not installed/outdated. Installing/updating Node.js..."
        "NodeInstalledSuccess"     = "Node.js installed/updated successfully."
        "CheckingPNPM"             = "Checking for pnpm..."
        "PNPMInstalled"            = "pnpm is installed."
        "InstallingPNPM"           = "pnpm not found. Installing pnpm..."
        "PNPMInstalledSuccess"     = "pnpm installed successfully."
        "CloningRepo"              = "BetterDiscord repository not found. Cloning repository..."
        "RepoCloned"               = "Repository cloned successfully."
        "RepoFound"                = "BetterDiscord repository found."
        "UpdatingRepo"             = "Updating repository..."
        "RepoUpdated"              = "Repository updated successfully."
        "RepoUpdateFail"           = "Failed to update repository."
        "InstallingDependencies"   = "Installing project dependencies..."
        "DependenciesInstalledSuccess" = "Project dependencies installed."
        "DependenciesInstallFail"  = "Failed to install project dependencies."
        "BuildingProject"          = "Building BetterDiscord..."
        "ProjectBuilt"             = "Project built successfully."
        "ProjectBuildFail"         = "Project build failed."
        "InjectingBetterDiscord"   = "Injecting BetterDiscord..."
        "InjectionSuccess"         = "BetterDiscord injected successfully."
        "InjectionFail"            = "Injection failed."
        "AutoUpdateInstalled"      = "Auto-Update Script installed/updated successfully."
        "AutoUpdateUninstalled"    = "Auto-Update Script uninstalled successfully."
        "DependenciesUninstalled"  = "Uninstall command executed. Please verify manually if needed."
        "PressEnterToContinue"     = "Press Enter to return to the menu..."
    }
    ru = @{
        "MenuTitle"                = "BetterDiscord Автообновление - Выберите сценарий:"
        "Option0"                  = "0) Выход"
        "Option1"                  = "1) Установить Discord"
        "Option2"                  = "2) Установить Discord (и запустить)"
        "Option3"                  = "3) Установить Discord и BetterDiscord"
        "Option4"                  = "4) Установить Discord и BetterDiscord (и запустить)"
        "Option5"                  = "5) Установить BetterDiscord"
        "Option6"                  = "6) Установить BetterDiscord (и запустить)"
        "Option7"                  = "7) Установить Discord, BetterDiscord и Автообновление Скрипта"
        "Option8"                  = "8) Установить Discord, BetterDiscord и Автообновление Скрипта (и запустить)"
        "Option9"                  = "9) Установить/Обновить Автообновление Скрипта"
        "Option10"                 = "10) Установить/Обновить Автообновление Скрипта (и запустить)"
        "Option11"                 = "11) Удалить Автообновление Скрипта"
        "Option12"                 = "12) Удалить Git/Node.JS/pnpm"
        "EnterChoice"              = "Введите номер сценария: "
        "InvalidChoice"            = "Неверный выбор. Попробуйте ещё раз."
        "ErrorOccurred"            = "Произошла ошибка: "
        "ClosingDiscord"           = "Закрытие Discord..."
        "DiscordRunningAbort"      = "Discord запущен! Сценарий прерван."
        "DiscordNotRunning"        = "Discord не запущен."
        "DiscordNotInstalled"      = "Discord не установлен. Устанавливаем..."
        "DiscordAlreadyInstalled"  = "Discord уже установлен."
        "InstallingDiscord"        = "Загружаем и устанавливаем Discord..."
        "DiscordInstallFailed"     = "Не удалось установить Discord."
        "LaunchingDiscord"         = "Запуск Discord..."
        "DiscordLaunchFailed"      = "Не удалось запустить Discord."
        "DependenciesInstalled"    = "Все зависимости установлены."
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
        "CloningRepo"              = "Папка BetterDiscord не найдена. Клонирование репозитория..."
        "RepoCloned"               = "Репозиторий успешно склонирован."
        "RepoFound"                = "Папка BetterDiscord найдена."
        "UpdatingRepo"             = "Обновление репозитория..."
        "RepoUpdated"              = "Репозиторий успешно обновлён."
        "RepoUpdateFail"           = "Не удалось обновить репозиторий."
        "InstallingDependencies"   = "Устанавливаем зависимости проекта..."
        "DependenciesInstalledSuccess" = "Зависимости проекта успешно установлены."
        "DependenciesInstallFail"  = "Не удалось установить зависимости проекта."
        "BuildingProject"          = "Сборка BetterDiscord..."
        "ProjectBuilt"             = "Проект успешно собран."
        "ProjectBuildFail"         = "Сборка проекта не удалась."
        "InjectingBetterDiscord"   = "Инжектинг BetterDiscord..."
        "InjectionSuccess"         = "BetterDiscord успешно инжектирован."
        "InjectionFail"            = "Инжектинг не удался."
        "AutoUpdateInstalled"      = "Скрипт автообновления установлен/обновлён."
        "AutoUpdateUninstalled"    = "Скрипт автообновления удалён."
        "DependenciesUninstalled"  = "Команда удаления выполнена. Проверьте состояние вручную."
        "PressEnterToContinue"     = "Нажмите Enter для возврата в меню..."
    }
}

# Функция для вывода локализованных сообщений
function Write-Message {
    param([Parameter(Mandatory)][string]$Key)
    if ($messages.ContainsKey($Language) -and $messages[$Language].ContainsKey($Key)) {
        Write-Host $messages[$Language][$Key]
    }
    else {
        Write-Host $Key
    }
}

#---------------------------------------#
# Функция самообновления скрипта        #
#---------------------------------------#
function Self-Update {
    if ($NoSelfUpdate) { return }
    try {
        Write-Message "ScriptUpdating" 2>$null
        $remoteContent = Invoke-WebRequest -Uri $remoteScriptUrl -UseBasicParsing -ErrorAction Stop
        $remoteHash = (New-Object -TypeName System.Security.Cryptography.SHA256Managed).ComputeHash([Text.Encoding]::UTF8.GetBytes($remoteContent.Content))
        $remoteHashString = [BitConverter]::ToString($remoteHash) -replace '-', ''
        if (Test-Path $LocalScriptPath) {
            $localContent = Get-Content -Path $LocalScriptPath -Raw
            $localHash = (New-Object -TypeName System.Security.Cryptography.SHA256Managed).ComputeHash([Text.Encoding]::UTF8.GetBytes($localContent))
            $localHashString = [BitConverter]::ToString($localHash) -replace '-', ''
        }
        else { $localHashString = "" }
        if ($remoteHashString -ne $localHashString) {
            $remoteContent.Content | Out-File -FilePath $LocalScriptPath -Encoding UTF8
            Write-Host ($Language -eq "ru" ? "Скрипт обновлён. Перезапуск..." : "Script updated. Restarting...")
            Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$LocalScriptPath`" -NoSelfUpdate"
            exit
        }
    }
    catch { Write-Host "$($messages[$Language]['ErrorOccurred']) $($_.Exception.Message)" }
}

#---------------------------------------#
# Функции проверки и установки зависимостей
#---------------------------------------#
function Ensure-Git {
    Write-Message "CheckingGit"
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    $needInstall = $false
    if ($gitCmd) {
        try {
            $versionOutput = git --version
            if ($versionOutput -match '(\d+\.\d+\.\d+)') {
                $curVer = [version]$Matches[1]
                if ($curVer -lt $requiredGitVersion) { $needInstall = $true }
            }
            else { $needInstall = $true }
        }
        catch { $needInstall = $true }
    }
    else { $needInstall = $true }
    if ($needInstall) {
        Write-Message "InstallingGit"
        $gitInstaller = Join-Path $env:TEMP "git-installer.exe"
        try {
            Invoke-WebRequest -Uri $gitInstallerUrl -OutFile $gitInstaller -UseBasicParsing -ErrorAction Stop
            Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT" -Wait
            Write-Message "GitInstalledSuccess"
        }
        catch { throw "Git installation failed: $($_.Exception.Message)" }
    }
    else { Write-Message "GitInstalled" }
}

function Ensure-Node {
    Write-Message "CheckingNode"
    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    $needInstall = $false
    if ($nodeCmd) {
        try {
            $nodeVerStr = (node --version).TrimStart("v")
            $curVer = [version]$nodeVerStr
            if ($curVer -lt $requiredNodeVersion) { $needInstall = $true }
        }
        catch { $needInstall = $true }
    }
    else { $needInstall = $true }
    if ($needInstall) {
        Write-Message "InstallingNode"
        $nodeInstaller = Join-Path $env:TEMP "node-installer.msi"
        try {
            Invoke-WebRequest -Uri $nodeInstallerUrl -OutFile $nodeInstaller -UseBasicParsing -ErrorAction Stop
            Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", "`"$nodeInstaller`"", "/quiet", "/norestart" -Wait
            Write-Message "NodeInstalledSuccess"
        }
        catch { throw "Node.js installation failed: $($_.Exception.Message)" }
    }
    else { Write-Message "NodeInstalled" }
}

function Ensure-Pnpm {
    Write-Message "CheckingPNPM"
    $pnpmCmd = Get-Command pnpm -ErrorAction SilentlyContinue
    if (-not $pnpmCmd) {
        Write-Message "InstallingPNPM"
        try {
            Invoke-WebRequest -Uri $pnpmInstallerUrl -UseBasicParsing -ErrorAction Stop | Invoke-Expression
            Write-Message "PNPMInstalledSuccess"
        }
        catch { throw "pnpm installation failed: $($_.Exception.Message)" }
    }
    else { Write-Message "PNPMInstalled" }
}

#---------------------------------------#
# Функции для работы с Discord          #
#---------------------------------------#
function Test-DiscordRunning {
    return (Get-Process -Name "Discord" -ErrorAction SilentlyContinue)
}

function Close-Discord {
    Write-Message "ClosingDiscord"
    $proc = Test-DiscordRunning
    if ($proc) {
        Stop-Process -Name "Discord" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }
    else {
        Write-Message "DiscordNotRunning"
    }
}

# Попытка обнаружить установленный Discord по пути Update.exe
function Test-DiscordInstalled {
    $updatePath = Join-Path $env:LOCALAPPDATA "Discord\Update.exe"
    return (Test-Path $updatePath)
}

# Установка Discord (схематично) – загружаем инсталлятор и запускаем его
function Install-Discord {
    if (Test-DiscordInstalled) {
        Write-Message "DiscordAlreadyInstalled"
        return $true
    }
    Write-Message "DiscordNotInstalled"
    Write-Message "InstallingDiscord"
    $discordInstaller = Join-Path $env:TEMP "DiscordSetup.exe"
    try {
        # URL для скачивания инсталлятора (ссылка может меняться)
        $discordInstallerUrl = "https://discord.com/api/download?platform=win"
        Invoke-WebRequest -Uri $discordInstallerUrl -OutFile $discordInstaller -UseBasicParsing -ErrorAction Stop
        Start-Process -FilePath $discordInstaller -ArgumentList "/S" -Wait
        Start-Sleep -Seconds 5
        if (Test-DiscordInstalled) {
            return $true
        }
        else { throw "Installation did not complete." }
    }
    catch { throw "Discord installation failed: $($_.Exception.Message)" }
}

function Launch-Discord {
    Write-Message "LaunchingDiscord"
    $updatePath = Join-Path $env:LOCALAPPDATA "Discord\Update.exe"
    if (Test-Path $updatePath) {
        try {
            Start-Process -FilePath $updatePath -ArgumentList "--processStart Discord.exe"
        }
        catch { throw "Discord launch failed: $($_.Exception.Message)" }
    }
    else {
        throw "Discord Update.exe not found."
    }
}

#---------------------------------------#
# Функция установки BetterDiscord       #
#---------------------------------------#
function Install-BetterDiscord {
    # Создаём базовую папку, если её нет
    if (-not (Test-Path $BaseFolder)) { New-Item -ItemType Directory -Path $BaseFolder -Force | Out-Null }
    if (-not (Test-Path $BetterDiscordFolder)) {
        Write-Message "CloningRepo"
        try {
            git clone "https://github.com/BetterDiscord/BetterDiscord.git" $BetterDiscordFolder
            Write-Message "RepoCloned"
        }
        catch { throw "Failed to clone BetterDiscord repository: $($_.Exception.Message)" }
    }
    else {
        Write-Message "RepoFound"
    }
    # Обновляем репозиторий
    Push-Location $BetterDiscordFolder
    Write-Message "UpdatingRepo"
    try {
        git pull
        Write-Message "RepoUpdated"
    }
    catch { throw "Failed to update repository: $($_.Exception.Message)" }
    # Устанавливаем зависимости, билдим и инжектим
    Write-Message "InstallingDependencies"
    try {
        Ensure-Git
        Ensure-Node
        Ensure-Pnpm
        pnpm install
        Write-Message "DependenciesInstalledSuccess"
    }
    catch { throw "Failed to install project dependencies: $($_.Exception.Message)" }
    Write-Message "BuildingProject"
    try {
        pnpm build
        Write-Message "ProjectBuilt"
    }
    catch { throw "Project build failed: $($_.Exception.Message)" }
    Write-Message "InjectingBetterDiscord"
    try {
        # Если требуется указать ветку, можно добавить параметр (например, stable)
        pnpm inject stable
        Write-Message "InjectionSuccess"
    }
    catch { throw "BetterDiscord injection failed: $($_.Exception.Message)" }
    Pop-Location
}

#---------------------------------------#
# Функции установки/обновления скрипта  #
#---------------------------------------#
function InstallOrUpdate-AutoUpdateScript {
    # Копируем текущий скрипт в $BaseFolder
    if (-not (Test-Path $BaseFolder)) { New-Item -ItemType Directory -Path $BaseFolder -Force | Out-Null }
    try {
        Copy-Item -Path $MyInvocation.MyCommand.Path -Destination $LocalScriptPath -Force
    }
    catch { throw "Failed to copy script file: $($_.Exception.Message)" }
    # Создаём ярлык в Start Menu
    try {
        $WshShell = New-Object -ComObject WScript.Shell
        $ShortcutPath = Join-Path $StartMenuFolder $ShortcutName
        $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
        $Shortcut.TargetPath = "powershell.exe"
        $Shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$LocalScriptPath`" -NoSelfUpdate"
        # Если Discord установлен, можно указать его иконку (опционально)
        $discordIcon = Join-Path $env:LOCALAPPDATA "Discord\Update.exe"
        if (Test-Path $discordIcon) { $Shortcut.IconLocation = $discordIcon }
        $Shortcut.Save()
    }
    catch { throw "Failed to create Start Menu shortcut: $($_.Exception.Message)" }
    Write-Message "AutoUpdateInstalled"
}

#---------------------------------------#
# Функция удаления автообновления скрипта#
#---------------------------------------#
function Uninstall-AutoUpdateScript {
    try {
        if (Test-Path $BaseFolder) { Remove-Item -Path $BaseFolder -Recurse -Force }
        $ShortcutPath = Join-Path $StartMenuFolder $ShortcutName
        if (Test-Path $ShortcutPath) { Remove-Item -Path $ShortcutPath -Force }
        Write-Message "AutoUpdateUninstalled"
    }
    catch { throw "Failed to uninstall auto-update script: $($_.Exception.Message)" }
}

#---------------------------------------#
# Функция удаления зависимостей         #
#---------------------------------------#
function Uninstall-Dependencies {
    try {
        # Если в системе установлен winget – попытаемся удалить через него.
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Start-Process -FilePath "winget" -ArgumentList "uninstall --id Git.Git -e" -Wait
            Start-Process -FilePath "winget" -ArgumentList "uninstall --id OpenJS.NodeJS -e" -Wait
            Start-Process -FilePath "winget" -ArgumentList "uninstall --id pnpm.pnpm -e" -Wait
        }
        else {
            Write-Host "winget not found. Please uninstall Git/Node.js/pnpm manually."
        }
        Write-Message "DependenciesUninstalled"
    }
    catch { throw "Failed to uninstall dependencies: $($_.Exception.Message)" }
}

#---------------------------------------#
# Сценарии (варианты меню)              #
#---------------------------------------#

# Сценарий 1: Install Discord – если Discord запущен, сценарий завершается; если не установлен – устанавливается.
function Scenario-InstallDiscord {
    param([switch]$StartAfter)
    try {
        if (Test-DiscordRunning) {
            Write-Message "DiscordRunningAbort"
            return
        }
        if (-not (Test-DiscordInstalled)) {
            if (-not (Install-Discord)) { return }
        }
        if ($StartAfter) {
            Launch-Discord
        }
    }
    catch { Write-Host "$($messages[$Language]['ErrorOccurred']) $($_.Exception.Message)" }
}

# Сценарий 3/4: Install Discord and BetterDiscord
function Scenario-InstallDiscordAndBetterDiscord {
    param(
        [switch]$StartAfter,
        [switch]$InstallDiscordSwitch  # Если true – устанавливаем Discord, иначе только проверяем его наличие
    )
    try {
        if ($InstallDiscordSwitch) {
            # Если Discord запущен – прерываем сценарий
            if (Test-DiscordRunning) {
                Write-Message "DiscordRunningAbort"
                return
            }
            if (-not (Test-DiscordInstalled)) {
                if (-not (Install-Discord)) { return }
            }
        }
        else {
            # Если Discord не установлен – прерываем сценарий
            if (-not (Test-DiscordInstalled)) {
                Write-Host ($Language -eq "ru" ? "Discord не установлен. Прерывание сценария." : "Discord is not installed. Aborting scenario.")
                return
            }
            # Если запущен – закрываем
            if (Test-DiscordRunning) { Close-Discord }
        }
        # Устанавливаем BetterDiscord
        Install-BetterDiscord
        if ($StartAfter) { Launch-Discord }
    }
    catch { Write-Host "$($messages[$Language]['ErrorOccurred']) $($_.Exception.Message)" }
}

# Сценарий 7/8: Install Discord, BetterDiscord and Auto-Update Script
function Scenario-InstallDiscordBetterDiscordAutoUpdate {
    param(
        [switch]$StartAfter,
        [switch]$InstallDiscordSwitch
    )
    try {
        # Делаем то же, что и в сценарии 3/4
        Scenario-InstallDiscordAndBetterDiscord -InstallDiscordSwitch:$InstallDiscordSwitch
        # Устанавливаем/обновляем автообновление скрипта
        InstallOrUpdate-AutoUpdateScript
        if ($StartAfter) { Launch-Discord }
    }
    catch { Write-Host "$($messages[$Language]['ErrorOccurred']) $($_.Exception.Message)" }
}

# Сценарий 9/10: Install/Update Auto-Update Script (с параметром запуска Discord)
function Scenario-AutoUpdateScriptOnly {
    param([switch]$StartAfter)
    try {
        InstallOrUpdate-AutoUpdateScript
        if ($StartAfter) { Launch-Discord }
    }
    catch { Write-Host "$($messages[$Language]['ErrorOccurred']) $($_.Exception.Message)" }
}

# Сценарий 11: Uninstall Auto-Update Script
function Scenario-UninstallAutoUpdateScript {
    try { Uninstall-AutoUpdateScript }
    catch { Write-Host "$($messages[$Language]['ErrorOccurred']) $($_.Exception.Message)" }
}

# Сценарий 12: Uninstall Git/Node.JS/pnpm
function Scenario-UninstallDependencies {
    try { Uninstall-Dependencies }
    catch { Write-Host "$($messages[$Language]['ErrorOccurred']) $($_.Exception.Message)" }
}

#---------------------------------------#
# Основное меню                         #
#---------------------------------------#
function Show-Menu {
    Clear-Host
    Write-Host "========================================="
    Write-Host ($messages[$Language]["MenuTitle"])
    Write-Host "========================================="
    Write-Host $messages[$Language]["Option0"]
    Write-Host $messages[$Language]["Option1"]
    Write-Host $messages[$Language]["Option2"]
    Write-Host $messages[$Language]["Option3"]
    Write-Host $messages[$Language]["Option4"]
    Write-Host $messages[$Language]["Option5"]
    Write-Host $messages[$Language]["Option6"]
    Write-Host $messages[$Language]["Option7"]
    Write-Host $messages[$Language]["Option8"]
    Write-Host $messages[$Language]["Option9"]
    Write-Host $messages[$Language]["Option10"]
    Write-Host $messages[$Language]["Option11"]
    Write-Host $messages[$Language]["Option12"]
    Write-Host "========================================="
}

#---------------------------------------#
# Режим установки (локальный)           #
#---------------------------------------#
if (-not $Remote) {
    if (-not (Test-Path $BaseFolder)) { New-Item -ItemType Directory -Path $BaseFolder -Force | Out-Null }
    if ($MyInvocation.MyCommand.Path -ne $LocalScriptPath) {
        Copy-Item -Path $MyInvocation.MyCommand.Path -Destination $LocalScriptPath -Force
    }
    Self-Update
}

#---------------------------------------#
# Главный цикл меню                     #
#---------------------------------------#
do {
    Show-Menu
    $choice = Read-Host $messages[$Language]["EnterChoice"]
    switch ($choice) {
        "0" { break }
        "1" { Scenario-InstallDiscord }
        "2" { Scenario-InstallDiscord -StartAfter }
        "3" { Scenario-InstallDiscordAndBetterDiscord -InstallDiscordSwitch -StartAfter:$false }
        "4" { Scenario-InstallDiscordAndBetterDiscord -InstallDiscordSwitch -StartAfter }
        "5" { Scenario-InstallDiscordAndBetterDiscord -StartAfter:$false }  # Здесь Discord не устанавливается, а только BetterDiscord – предварительно проверка
        "6" { Scenario-InstallDiscordAndBetterDiscord -StartAfter }
        "7" { Scenario-InstallDiscordBetterDiscordAutoUpdate -InstallDiscordSwitch -StartAfter:$false }
        "8" { Scenario-InstallDiscordBetterDiscordAutoUpdate -InstallDiscordSwitch -StartAfter }
        "9" { Scenario-AutoUpdateScriptOnly -StartAfter:$false }
        "10" { Scenario-AutoUpdateScriptOnly -StartAfter }
        "11" { Scenario-UninstallAutoUpdateScript }
        "12" { Scenario-UninstallDependencies }
        default { Write-Message "InvalidChoice" }
    }
    Write-Host ""
    Write-Host $messages[$Language]["PressEnterToContinue"]
    Read-Host
} while ($true)
