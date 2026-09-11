$ErrorActionPreference = 'SilentlyContinue'

$targets = @('exefile', 'lnkfile', 'InternetShortcut')
foreach ($target in $targets) {
    Remove-Item "HKCU:\Software\Classes\$target\shell\SqueakAdd" -Recurse -Force
}

try {
    $sendTo = [Environment]::GetFolderPath('SendTo')
    $shortcutPath = Join-Path $sendTo 'Ajouter à Squeak.lnk'
    if (Test-Path $shortcutPath) {
        Remove-Item $shortcutPath -Force
    }
} catch {}

Write-Host "Menu clic droit Squeak supprimé." -ForegroundColor Green
pause
