#Requires -RunAsAdministrator

#region Функции

# Функция для вывода MessageBox
function Show-MessageBox {
    param (
        [Parameter(Mandatory)]
        [string]$Message,
        [Parameter(Mandatory)]
        [string]$Title
    )
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    [System.Windows.Forms.MessageBox]::Show($Message, $Title, [System.Windows.Forms.MessageBoxButtons]::OK) | Out-Null
}

# Функция для установки зависимости через инсталлятор
function Install-Dependency {
    param (
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [string]$InstallerUrl,
        [Parameter(Mandatory)]
        [string]$InstallerPath,
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )
    Write-Host "Устанавливается $Name..."
    try {
        Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath -ErrorAction Stop
        Start-Process -FilePath $InstallerPath -ArgumentList $Arguments -Wait -ErrorAction Stop
        Write-Host "$Name установлен(а)."
    }
    catch {
        Write-Host "Ошибка установки $Name: $_"
        exit 1
    }
}

#endregion

#region 1. Работа с процессом Discord и его установкой

$discordProcessName = "Discord"
$discordExePath = "$env:LOCALAPPDATA\Discord\Update.exe"

# Если Discord запущен, завершаем процесс
if (Get-Process -Name $discordProcessName -ErrorAction SilentlyContinue) {
    Write-Host "Закрываем Discord..."
    Stop-Process -Name $discordProcessName -Force
    Start-Sleep -Seconds 2
}

# Если Discord не установлен, запускаем установку
if (-not (Test-Path $discordExePath)) {
    Write-Host "Discord не найден. Запускается установка..."
    $discordInstaller = "$env:TEMP\DiscordSetup.exe"
    try {
        Invoke-WebRequest -Uri "https://discord.com/api/downloads/distributions/app/installers/latest?channel=stable&platform=win&arch=x86" -OutFile $discordInstaller -ErrorAction Stop
        Start-Process -FilePath $discordInstaller -ArgumentList "--silent" -Wait -ErrorAction Stop
        Show-MessageBox -Message "Установка Discord завершена. Нажмите OK для продолжения." -Title "Discord Setup"
        # Если после установки Discord запустился, завершаем процесс
        if (Get-Process -Name $discordProcessName -ErrorAction SilentlyContinue) {
            Write-Host "Закрываем Discord..."
            Stop-Process -Name $discordProcessName -Force
            Start-Sleep -Seconds 2
        }
    }
    catch {
        Write-Host "Ошибка установки Discord: $_"
        exit 1
    }
}

#endregion

#region 2. Проверка и установка зависимостей (Git, Node.js, pnpm)

$dependenciesInstalled = $true

# Проверка Git
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    $dependenciesInstalled = $false
    Install-Dependency -Name "Git" `
        -InstallerUrl "https://github.com/git-for-windows/git/releases/download/v2.40.0.windows.1/Git-2.40.0-64-bit.exe" `
        -InstallerPath "$env:TEMP\git-installer.exe" `
        -Arguments "/VERYSILENT"
}

# Проверка Node.js
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    $dependenciesInstalled = $false
    Install-Dependency -Name "Node.js" `
        -InstallerUrl "https://nodejs.org/dist/v18.18.2/node-v18.18.2-x64.msi" `
        -InstallerPath "$env:TEMP\node-installer.msi" `
        -Arguments "/quiet", "/norestart"
}

# Проверка pnpm (если npm доступен)
if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        Write-Host "Устанавливается pnpm..."
        try {
            npm install -g pnpm | Out-Null
            Write-Host "pnpm установлен."
        }
        catch {
            Write-Host "Ошибка установки pnpm: $_"
            exit 1
        }
    }
    else {
        Write-Host "npm не найден. Установка pnpm невозможна."
        exit 1
    }
}

# Если какие-либо зависимости были установлены, рекомендуем перезапустить скрипт для обновления PATH
if (-not $dependenciesInstalled) {
    Write-Host "Некоторые зависимости установлены. Пожалуйста, перезапустите терминал и запустите скрипт снова."
    Pause
    exit
}

#endregion

#region 3. Самообновление скрипта

$scriptDir = Join-Path $env:APPDATA "BetterDiscord Update Script"
$scriptPath = Join-Path $scriptDir "BetterDiscordUpdate.ps1"

if (-not (Test-Path $scriptDir)) {
    New-Item -ItemType Directory -Path $scriptDir -Force | Out-Null
}

try {
    $githubUrl = "https://raw.githubusercontent.com/MLNekit/BetterDiscordAutoUpdater/main/BetterDiscordUpdate.ps1"
    $githubContent = (Invoke-WebRequest -Uri $githubUrl -UseBasicParsing -ErrorAction Stop).Content
    if (Test-Path $scriptPath) {
        $localContent = Get-Content $scriptPath -Raw
    }
    else {
        $localContent = ""
    }
    if ($localContent -ne $githubContent) {
        Write-Host "Обновление скрипта..."
        Set-Content -Path $scriptPath -Value $githubContent -Force
    }
}
catch {
    Write-Host "Не удалось обновить скрипт: $_"
}

# Если текущий скрипт запущен не из $scriptPath, перезапускаем его оттуда
if ($MyInvocation.MyCommand.Path -ne $scriptPath) {
    Write-Host "Перезапуск скрипта..."
    & $scriptPath
    exit
}

#endregion

#region 4. Работа с репозиторием BetterDiscord

$betterDiscordRepo = Join-Path $scriptDir "BetterDiscord"

if (-not (Test-Path $betterDiscordRepo)) {
    Write-Host "Клонирование репозитория BetterDiscord..."
    try {
        git clone "https://github.com/BetterDiscord/BetterDiscord.git" $betterDiscordRepo
    }
    catch {
        Write-Host "Ошибка клонирования репозитория: $_"
        exit 1
    }
}
else {
    Write-Host "Обновление репозитория BetterDiscord..."
    try {
        Set-Location $betterDiscordRepo
        git pull
    }
    catch {
        Write-Host "Ошибка обновления репозитория: $_"
        exit 1
    }
}

#endregion

#region 5. Создание ярлыка для обновления

$shortcutPath = Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs\BetterDiscord Update.lnk"
if (-not (Test-Path $shortcutPath)) {
    try {
        $WshShell = New-Object -ComObject WScript.Shell
        $shortcut = $WshShell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = "powershell.exe"
        $shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$scriptPath`""
        $shortcut.WorkingDirectory = $scriptDir
        $shortcut.Save()
        Write-Host "Ярлык создан."
    }
    catch {
        Write-Host "Ошибка создания ярлыка: $_"
    }
}

#endregion

#region 6. Создание папки данных BetterDiscord

$betterDiscordData = Join-Path $env:APPDATA "BetterDiscord"
if (-not (Test-Path $betterDiscordData)) {
    New-Item -ItemType Directory -Path $betterDiscordData -Force | Out-Null
}

#endregion

#region 7. Сборка и инъекция BetterDiscord

try {
    Set-Location $betterDiscordRepo
    Write-Host "Установка зависимостей для BetterDiscord..."
    # Убеждаемся, что pnpm доступен
    if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
        Write-Host "pnpm не найден, установка через npm..."
        npm install -g pnpm | Out-Null
    }
    pnpm install
    pnpm build
    pnpm inject
}
catch {
    Write-Host "Ошибка сборки или инъекции: $_"
    exit 1
}

#endregion

#region 8. Запуск Discord

try {
    Write-Host "Запуск Discord..."
    Start-Process -FilePath $discordExePath -ArgumentList "--processStart", "Discord.exe"
    Write-Host "Обновление BetterDiscord завершено!"
    Start-Sleep -Seconds 3
}
catch {
    Write-Host "Не удалось запустить Discord: $_"
}

#endregion
