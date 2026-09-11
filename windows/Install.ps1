param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'Squeak'),
    [string]$DesktopDir = [Environment]::GetFolderPath('Desktop'),
    [string]$MigrationSource = '',
    [switch]$NoLaunch
)
$ErrorActionPreference = 'Stop'
$source = [IO.Path]::GetFullPath($PSScriptRoot)
$target = [IO.Path]::GetFullPath($InstallDir)
if ($target -eq [IO.Path]::GetPathRoot($target)) { throw 'Dossier installation invalide.' }
$null = New-Item -ItemType Directory -Path $target -Force
$backup = Join-Path $target ('backups\' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
$null = New-Item -ItemType Directory -Path $backup -Force
$files = @('Squeak.ahk','Theme.ahk','SiteIcons.ahk','Fetch-SiteIcon.ps1','Squeak.ico','Squeak.png','StartSafe.ps1','Start-Squeak.ps1','Ajouter-Squeak.ps1','Lancer Squeak.bat','Installer-Squeak.ps1','Install.ps1','Installer menu clic droit.ps1','Installer menu clic droit.bat','Desinstaller menu clic droit.ps1','Desinstaller menu clic droit.bat','README.txt')
if (Test-Path -LiteralPath (Join-Path $target 'theme')) { Copy-Item -LiteralPath (Join-Path $target 'theme') -Destination $backup -Recurse }
foreach ($file in $files + @('squeak_apps.txt','settings.ini')) {
    $existing = Join-Path $target $file
    if (Test-Path -LiteralPath $existing) { Copy-Item -LiteralPath $existing -Destination $backup }
}
$shortcutPath = Join-Path $DesktopDir 'Squeak.lnk'
if (Test-Path -LiteralPath $shortcutPath) { Copy-Item -LiteralPath $shortcutPath -Destination $backup }
# Stop only AutoHotkey processes whose script belongs to a known Squeak copy.
$knownScripts = @((Join-Path $target 'Squeak.ahk'))
if ($MigrationSource) { $knownScripts += Join-Path $MigrationSource 'Squeak.ahk' }
$desktopOld = Join-Path $env:USERPROFILE 'Desktop\Squeak-mini-app (1)\Squeak'
$knownScripts += Join-Path $desktopOld 'Squeak.ahk'
foreach ($oldDir in @($MigrationSource, $desktopOld)) {
    if ($oldDir -and (Test-Path -LiteralPath (Join-Path $oldDir 'squeak_apps.txt'))) {
        $label = if ($oldDir -eq $MigrationSource) { 'migration' } else { 'desktop-old' }
        Copy-Item -LiteralPath (Join-Path $oldDir 'squeak_apps.txt') -Destination (Join-Path $backup ($label + '-apps.txt'))
    }
}
Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^AutoHotkey.*\.exe$' -and $_.CommandLine } | ForEach-Object {
    $process = $_
    foreach ($script in $knownScripts) {
        if ($process.CommandLine -match ('(?i)(?:"|\s)' + [regex]::Escape($script) + '(?:"|\s|$)')) {
            Stop-Process -Id $process.ProcessId -ErrorAction Stop
            break
        }
    }
}
if ($source -ne $target) {
    foreach ($file in $files) { Copy-Item -LiteralPath (Join-Path $source $file) -Destination (Join-Path $target $file) -Force }
    Copy-Item -LiteralPath (Join-Path $source 'theme') -Destination $target -Recurse -Force
    foreach ($folder in @('browser-extension','browser-bridge','shell-extension','runtime')) {
        if (Test-Path -LiteralPath (Join-Path $source $folder)) {
            Copy-Item -LiteralPath (Join-Path $source $folder) -Destination $target -Recurse -Force
        }
    }
    if (Test-Path -LiteralPath (Join-Path $source 'Installer les navigateurs.ps1')) {
        Copy-Item -LiteralPath (Join-Path $source 'Installer les navigateurs.ps1') -Destination $target -Force
    }
}
$config = Join-Path $target 'squeak_apps.txt'
$settings = Join-Path $target 'settings.ini'
if (-not (Test-Path -LiteralPath $settings) -and $MigrationSource -and (Test-Path -LiteralPath (Join-Path $MigrationSource 'settings.ini'))) {
    Copy-Item -LiteralPath (Join-Path $MigrationSource 'settings.ini') -Destination $settings
}
if (-not (Test-Path -LiteralPath $config)) {
    if ($MigrationSource -and (Test-Path -LiteralPath (Join-Path $MigrationSource 'squeak_apps.txt'))) {
        Copy-Item -LiteralPath (Join-Path $MigrationSource 'squeak_apps.txt') -Destination $config
    } else { [IO.File]::WriteAllText($config, '', [Text.UTF8Encoding]::new($true)) }
}
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$shortcut.Arguments = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + (Join-Path $target 'StartSafe.ps1') + '"'
$shortcut.WorkingDirectory = $target
$shortcut.IconLocation = Join-Path $target 'Squeak.ico'
$shortcut.Save()
& (Join-Path $target 'Installer menu clic droit.ps1')
$installKey=New-Item 'HKCU:\Software\Squeak' -Force
$installKey.SetValue('InstallDir',$target)
if (Test-Path -LiteralPath (Join-Path $target 'shell-extension\Install-Client.ps1')) {
    & (Join-Path $target 'shell-extension\Install-Client.ps1')
}
if (Test-Path -LiteralPath (Join-Path $target 'Installer les navigateurs.ps1')) {
    & (Join-Path $target 'Installer les navigateurs.ps1') -AppDir $target
}
if (-not $NoLaunch) { & (Join-Path $target 'StartSafe.ps1') }
Write-Output "Installation: $target"
Write-Output "Sauvegarde: $backup"
Write-Output "Raccourci: $shortcutPath"
