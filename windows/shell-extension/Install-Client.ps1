$ErrorActionPreference='Stop'
if([Environment]::OSVersion.Version.Build -lt 22000){Write-Output 'Windows 10 : menu classique installe.';return}
$thumb=(Get-Content (Join-Path $PSScriptRoot 'certificate-thumbprint.txt') -Raw).Trim()
if($thumb -notmatch '^[A-F0-9]{40}$'){throw 'Empreinte invalide'}
if(-not(Test-Path -LiteralPath ('Cert:\LocalMachine\TrustedPeople\'+$thumb))){
    Write-Host 'Le menu Windows necessite le certificat local Squeak. Windows va demander une autorisation administrateur.'
    $script=Join-Path $PSScriptRoot 'Trust-Certificate.ps1'
    $process=Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Verb RunAs -WindowStyle Hidden -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$script+'"')) -Wait -PassThru
    if($process.ExitCode -ne 0){throw 'Certificat non installe. Relancez Installer Squeak pour terminer.'}
}
# Register for the original user, even when UAC used another administrator account.
Add-AppxPackage -Path (Join-Path $PSScriptRoot 'Squeak.ContextMenu.msix')
if(-not(Get-AppxPackage -Name Squeak.ContextMenu)){throw 'Menu Windows non installe'}
Write-Output 'Menu principal Windows 11 : installe.'
