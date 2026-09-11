param([string]$AppDir=$PSScriptRoot)
$ErrorActionPreference='Stop'
$extension=Join-Path $AppDir 'browser-extension'
$bridge=Join-Path $AppDir 'browser-bridge'
$id=(Get-Content -LiteralPath (Join-Path $extension 'extension-id.txt') -Raw).Trim()
if ($id -notmatch '^[a-p]{32}$') { throw 'Identifiant extension invalide.' }
$ahk=@((Join-Path $AppDir 'runtime\AutoHotkey64.exe'),"$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe","$env:ProgramFiles\AutoHotkey\v2\AutoHotkey32.exe","$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe") | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $ahk) { throw 'AutoHotkey v2 introuvable.' }
$origin='chrome-extension://'+$id+'/'
$utf8=[Text.UTF8Encoding]::new($false)
$settings=@{origin=$origin;appDir=[IO.Path]::GetFullPath($AppDir);autoHotkey=$ahk;windowTitle='Squeak 2.2'}
[IO.File]::WriteAllText((Join-Path $bridge 'bridge.json'),($settings | ConvertTo-Json),$utf8)
$manifest=@{name='com.squeak.desktop';description='Connexion locale a Squeak';path=(Join-Path $bridge 'SqueakBridge.exe');type='stdio';allowed_origins=@($origin)}
$manifestPath=Join-Path $bridge 'com.squeak.desktop.json'
[IO.File]::WriteAllText($manifestPath,($manifest | ConvertTo-Json),$utf8)
foreach($browser in @('Google\Chrome','Microsoft\Edge')) {
    $key=[Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Software\'+$browser+'\NativeMessagingHosts\com.squeak.desktop')
    try {$key.SetValue('',$manifestPath)} finally {$key.Dispose()}
}
Write-Output 'Liaison locale installee pour Edge et Chrome.'
Write-Output ('Extension a charger dans les deux navigateurs : '+$extension)
Write-Output ('Identifiant : '+$id)
