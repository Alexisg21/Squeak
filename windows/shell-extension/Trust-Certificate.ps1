$ErrorActionPreference='Stop'
$expected=(Get-Content (Join-Path $PSScriptRoot 'certificate-thumbprint.txt') -Raw).Trim()
$path=Join-Path $PSScriptRoot 'Squeak.ContextMenu.cer'
$cert=New-Object Security.Cryptography.X509Certificates.X509Certificate2($path)
if($cert.Thumbprint -ne $expected -or $cert.Subject -ne 'CN=Squeak Local'){throw 'Certificat inattendu'}
$null=Import-Certificate -FilePath $path -CertStoreLocation 'Cert:\LocalMachine\TrustedPeople'
