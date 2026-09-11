param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Items)
$ErrorActionPreference = 'Stop'
$folder = $PSScriptRoot
$candidates = @(
    (Join-Path $folder 'runtime\AutoHotkey64.exe'),
    "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe",
    "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey32.exe",
    "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe"
)
$ahk = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $ahk) { throw 'AutoHotkey v2 est introuvable. Installe AutoHotkey v2.' }
$arguments = @('/CP65001', ('"' + (Join-Path $folder 'Squeak.ahk') + '"'))
if ($Items.Count) {
    $arguments += '--add'
    foreach ($item in $Items) {
        if ($item -match '["\r\n]' -or $item.EndsWith('\')) { throw 'Argument invalide.' }
        $arguments += '"' + $item + '"'
    }
}
# Existing instances receive requests through WM_COPYDATA; never terminate them.
Start-Process -FilePath $ahk -ArgumentList ($arguments -join ' ') -WorkingDirectory $folder -WindowStyle Hidden
