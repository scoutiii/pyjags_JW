$ErrorActionPreference = 'Stop'

$JagsVersion = '4.3.2'
$Prefix = 'C:\\jags'
$Installer = Join-Path $env:TEMP "JAGS-$JagsVersion.exe"
$Url = "https://downloads.sourceforge.net/project/mcmc-jags/JAGS/4.x/Windows/JAGS-$JagsVersion.exe"

Write-Host "Downloading JAGS $JagsVersion ..."
if (Test-Path $Installer) { Remove-Item $Installer -Force }

# Use curl.exe to follow redirects reliably on GitHub runners
$curl = "${env:ProgramFiles}\Git\mingw64\bin\curl.exe"
if (!(Test-Path $curl)) { $curl = "curl.exe" }
& $curl -L --retry 5 --retry-delay 2 --fail -o $Installer $Url

if (!(Test-Path $Installer) -or ((Get-Item $Installer).Length -lt 1000000)) {
  throw "Failed to download JAGS installer from $Url"
}

Write-Host "Installing to $Prefix ..."
Start-Process -FilePath $Installer -ArgumentList "/S","/D=$Prefix" -Wait -PassThru | Out-Null

Write-Host "JAGS installed under $Prefix"
