$ErrorActionPreference = 'Stop'

$JagsVersion = '4.3.2'
$Prefix = 'C:\\jags'
$Installer = "$env:TEMP\JAGS-$JagsVersion.exe"
$Url = "https://sourceforge.net/projects/mcmc-jags/files/JAGS/4.x/Windows/JAGS-$JagsVersion.exe/download"

Write-Host "Downloading JAGS $JagsVersion ..."
Invoke-WebRequest -Uri $Url -OutFile $Installer

Write-Host "Installing to $Prefix ..."
Start-Process -FilePath $Installer -ArgumentList "/S","/D=$Prefix" -Wait

Write-Host "JAGS installed under $Prefix"
