$ErrorActionPreference = 'Stop'

$JagsVersion = '4.3.1'  # Windows installer available for 4.3.1
$Prefix = 'C:\\jags'
$Installer = Join-Path $env:TEMP "JAGS-$JagsVersion.exe"
$PrimaryUrl = "https://sourceforge.net/projects/mcmc-jags/files/JAGS/4.x/Windows/JAGS-$JagsVersion.exe/download"
# Known mirror fallback (keep in sync with SourceForge structure)
$MirrorUrl = "https://cfhcable.dl.sourceforge.net/project/mcmc-jags/JAGS/4.x/Windows/JAGS-$JagsVersion.exe"

Write-Host "Downloading JAGS $JagsVersion ..."
if (Test-Path $Installer) { Remove-Item $Installer -Force }

# Use curl.exe to follow redirects reliably on GitHub runners
$curl = "${env:ProgramFiles}\Git\mingw64\bin\curl.exe"
if (!(Test-Path $curl)) { $curl = "curl.exe" }
Write-Host "Trying $PrimaryUrl"
& $curl -L --retry 5 --retry-delay 2 --fail -o $Installer $PrimaryUrl || $null

if (!(Test-Path $Installer) -or ((Get-Item $Installer).Length -lt 1000000)) {
  Write-Host "Primary download failed or too small; trying mirror $MirrorUrl"
  if (Test-Path $Installer) { Remove-Item $Installer -Force }
  & $curl -L --retry 5 --retry-delay 2 --fail -o $Installer $MirrorUrl
}

if (!(Test-Path $Installer) -or ((Get-Item $Installer).Length -lt 1000000)) {
  throw "Failed to download JAGS installer from $PrimaryUrl or mirror"
}

Write-Host "Installing to $Prefix ..."
Start-Process -FilePath $Installer -ArgumentList "/S","/D=$Prefix" -Wait -PassThru | Out-Null

Write-Host "JAGS installed under $Prefix"
