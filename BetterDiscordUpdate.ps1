# Проверка запуска от администратора
if (-not ([Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Start-Process powershell "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit
}

# Проверка установки и завершение Discord
$discordPath = "$env:LOCALAPPDATA\Discord"
if (-not (Test-Path $discordPath)) {
    Invoke-WebRequest "https://discord.com/api/download?platform=win" -OutFile "$env:TEMP\DiscordSetup.exe"
    Start-Process "$env:TEMP\DiscordSetup.exe" -ArgumentList "--silent" -Wait
}
Get-Process -Name "Discord" -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep 2

# Функция установки зависимостей
function Install-Dependency($command, $url, $args="") {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        Invoke-WebRequest $url -OutFile "$env:TEMP\$command-installer"
        Start-Process "$env:TEMP\$command-installer" -ArgumentList $args -Wait
    }
}

# Установка зависимостей
Install-Dependency "git" ((Invoke-RestMethod "https://api.github.com/repos/git-for-windows/git/releases/latest").assets | Where-Object name -match "64-bit.exe" | Select-Object -ExpandProperty browser_download_url) "/VERYSILENT"
Install-Dependency "node" "https://nodejs.org/dist/latest/win-x64/node.exe" "/quiet /norestart"
Install-Dependency "pnpm" "https://get.pnpm.io/install.ps1"
Install-Dependency "bun" "https://bun.sh/install.ps1"

# Обновление скрипта
$scriptPath = "$env:APPDATA\BetterDiscordUpdate.ps1"
Invoke-WebRequest "https://raw.githubusercontent.com/MLNekit/BetterDiscordAutoUpdater/main/BetterDiscordUpdate.ps1" -OutFile $scriptPath

# Клонирование/обновление BetterDiscord
$repoPath = "$env:APPDATA\BetterDiscordRepo"
if (-not (Test-Path $repoPath)) { git clone "https://github.com/BetterDiscord/BetterDiscord.git" $repoPath }
else { Push-Location $repoPath; git pull; Pop-Location }

# Создание ярлыка
$shortcut = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\BetterDiscord Update.lnk"
if (-not (Test-Path $shortcut)) {
    $link = (New-Object -ComObject WScript.Shell).CreateShortcut($shortcut)
    $link.TargetPath = "powershell.exe"; $link.Arguments = "-ExecutionPolicy Bypass -File `"$scriptPath`""; $link.Save()
}

# Установка и запуск BetterDiscord
Push-Location $repoPath; npm install -g pnpm; pnpm install; pnpm build; pnpm inject; Pop-Location

# Запуск Discord
Start-Process "$env:LOCALAPPDATA\Discord\Update.exe" -ArgumentList "--processStart Discord.exe"

Write-Host "BetterDiscord успешно установлен/обновлён!"
