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
& $curl -L --retry 5 --retry-delay 2 --fail -o $Installer $PrimaryUrl
$primaryOk = ($LASTEXITCODE -eq 0)

if (-not $primaryOk -or !(Test-Path $Installer) -or ((Get-Item $Installer).Length -lt 1000000)) {
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

# Try to discover the actual install root (some installers nest a JAGS-<ver> directory).
$candidates = @(
  "$Prefix",
  (Join-Path $Prefix "JAGS-$JagsVersion"),
  (Join-Path $Prefix "JAGS\$JagsVersion"),
  (Join-Path ${env:ProgramFiles} "JAGS\JAGS-$JagsVersion")
)

function Has-JagsLayout([string]$root) {
  return (Test-Path (Join-Path $root "include\JAGS\version.h")) -or
         (Test-Path (Join-Path $root "include\version.h"))
}

$JagsRoot = $null
foreach ($c in $candidates) {
  Write-Host "Checking candidate: $c"
  if (Has-JagsLayout $c) { $JagsRoot = $c; break }
}

# Last-resort search within the prefix for version.h to locate the root.
if (-not $JagsRoot) {
  $hit = Get-ChildItem -Path $Prefix -Filter version.h -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match 'JAGS' } |
    Select-Object -First 1
  if ($hit) {
    $JagsRoot = Split-Path -Path $hit.Directory -Parent
  }
}

if (-not $JagsRoot) {
  throw "Installed JAGS layout not found under $Prefix"
}

Write-Host "Detected JAGS root: $JagsRoot"
$env:PYJAGS_VENDOR_JAGS_ROOT = $JagsRoot
Add-Content -Path $env:GITHUB_ENV -Value "PYJAGS_VENDOR_JAGS_ROOT=$JagsRoot"

# Log a brief inventory to help debugging in CI
Write-Host "JAGS inventory (trimmed):"
Get-ChildItem -Path (Join-Path $JagsRoot "include") -Filter "version.h" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 5 FullName | ForEach-Object { Write-Host "  include: $_" }
Get-ChildItem -Path (Join-Path $JagsRoot "include") -Recurse -ErrorAction SilentlyContinue -Depth 2 | Select-Object -First 10 FullName | ForEach-Object { Write-Host "  include entry: $_" }
Get-ChildItem -Path (Join-Path $JagsRoot "bin") -ErrorAction SilentlyContinue | Select-Object -First 10 FullName | ForEach-Object { Write-Host "  bin entry: $_" }
Get-ChildItem -Path (Join-Path $JagsRoot "lib") -ErrorAction SilentlyContinue | Select-Object -First 10 FullName | ForEach-Object { Write-Host "  lib entry: $_" }
Get-ChildItem -Path $JagsRoot -Recurse -ErrorAction SilentlyContinue -Depth 3 | Where-Object { $_.Name -like 'jags*' -or $_.Name -like 'libjags*' } | Select-Object -First 15 FullName | ForEach-Object { Write-Host "  jagspath: $_" }

# Ensure an MSVC import library exists (the installer ships a GCC .dll.a)
$dllPath = Join-Path $JagsRoot "x64\bin\libjags-4.dll"
$implibPath = Join-Path $JagsRoot "x64\lib\libjags-4.lib"
if (Test-Path $dllPath -and -not (Test-Path $implibPath)) {
  Write-Host "MSVC import library not found; generating $implibPath from $dllPath"
  $tempDef = Join-Path $env:TEMP "jags_exports.def"

  function Find-Tool($tool) {
    $candidates = @(
      "$env:VCToolsInstallDir\bin\Hostx64\x64\$tool.exe",
      "$env:VSINSTALLDIR\VC\Tools\MSVC\*\bin\Hostx64\x64\$tool.exe"
    ) + (Get-Command "$tool.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
    foreach ($c in $candidates) {
      if ($null -ne $c -and (Test-Path $c)) { return $c }
    }
    $found = Get-ChildItem "C:\Program Files\Microsoft Visual Studio" -Recurse -Filter "$tool.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
    return $found
  }

  $dumpbin = Find-Tool "dumpbin"
  $libexe = Find-Tool "lib"
  if (-not $dumpbin -or -not $libexe) {
    throw "Required MSVC tools dumpbin/lib not found to generate import library"
  }

  & $dumpbin /exports $dllPath | Where-Object { $_ -match "^[ ]+[0-9]+" } |
    ForEach-Object {
      if ($_ -match "^[ ]+[0-9]+\s+[0-9A-F]+\s+[0-9A-F]+\s+(\S+)$") { $matches[1] }
    } | Where-Object { $_ } | Set-Content -Path $tempDef -Encoding ASCII
  # Prepend EXPORTS header
  $lines = Get-Content $tempDef
  @("EXPORTS") + $lines | Set-Content -Path $tempDef -Encoding ASCII

  & $libexe /def:$tempDef /machine:x64 /out:$implibPath
  Write-Host "Generated import lib: $implibPath"
}
