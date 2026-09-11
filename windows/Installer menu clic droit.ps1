$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$addScript = Join-Path $scriptDir 'Ajouter-Squeak.ps1'
$iconPath = Join-Path $scriptDir 'Squeak.ico'

if (-not (Test-Path $addScript)) {
    Write-Host "Ajouter-Squeak.ps1 est introuvable dans ce dossier." -ForegroundColor Red
    
    exit 1
}

$command = 'powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}" "%1"' -f $addScript
$targets = @('exefile', 'lnkfile', 'InternetShortcut')

foreach ($target in $targets) {
    $keyPath = "HKCU:\Software\Classes\$target\shell\SqueakAdd"
    $cmdPath = "$keyPath\command"

    $key = New-Item -Path $keyPath -Force
    $key.SetValue('', 'Ajouter à Squeak')
    if (Test-Path $iconPath) { $key.SetValue('Icon', $iconPath) }

    $cmdKey = New-Item -Path $cmdPath -Force
    $cmdKey.SetValue('', $command)
}

try {
    $sendTo = [Environment]::GetFolderPath('SendTo')
    $shortcutPath = Join-Path $sendTo 'Ajouter à Squeak.lnk'
    if (Test-Path $shortcutPath) { Remove-Item $shortcutPath -Force }
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = 'powershell.exe'
    $shortcut.Arguments = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $addScript + '"'
    $shortcut.WorkingDirectory = $scriptDir
    if (Test-Path $iconPath) { $shortcut.IconLocation = $iconPath }
    $shortcut.Save()
} catch {
    Write-Host "Le raccourci Envoyer vers n'a pas pu être créé, mais le menu clic droit a été installé." -ForegroundColor Yellow
}

Write-Host "Menu clic droit moderne installé." -ForegroundColor Green
Write-Host "Clic droit sur un raccourci, une application ou une URL, puis : Ajouter à Squeak."
Write-Host "Sur Windows 11, l'option peut être dans 'Afficher d'autres options'."

