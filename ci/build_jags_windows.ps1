$ErrorActionPreference = 'Stop'

$JagsVersion = '4.3.1'
$Prefix = 'C:\jags'
$Installer = Join-Path $env:TEMP "JAGS-$JagsVersion.exe"
$PrimaryUrl = "https://sourceforge.net/projects/mcmc-jags/files/JAGS/4.x/Windows/JAGS-$JagsVersion.exe/download"
$MirrorUrl = "https://cfhcable.dl.sourceforge.net/project/mcmc-jags/JAGS/4.x/Windows/JAGS-$JagsVersion.exe"

Write-Host "Downloading JAGS $JagsVersion ..."
if (Test-Path $Installer) { Remove-Item $Installer -Force }

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

Write-Host "JAGS inventory (trimmed):"
Get-ChildItem -Path (Join-Path $JagsRoot "include") -Filter "version.h" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 5 FullName | ForEach-Object { Write-Host "  include: $_" }
Get-ChildItem -Path $JagsRoot -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'jags*' -or $_.Name -like 'libjags*' -or $_.Name -like 'libjrmath*' } | Select-Object -First 15 FullName | ForEach-Object { Write-Host "  jagspath: $_" }

$binDir = Join-Path $JagsRoot "x64\bin"
if (!(Test-Path $binDir)) {
  $binDir = Join-Path $JagsRoot "bin"
}
if (!(Test-Path $binDir)) {
  New-Item -ItemType Directory -Path $binDir -Force | Out-Null
}

$runtimeDlls = @(
  "libstdc++-6.dll",
  "libgcc_s_seh-1.dll",
  "libgcc_s_dw2-1.dll",
  "libwinpthread-1.dll"
)

$gpp = Get-Command "g++.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source
$searchRoots = @()
if ($gpp) {
  $searchRoots += (Split-Path -Path $gpp -Parent)
}
if ($env:MSYS2_ROOT) {
  $searchRoots += (Join-Path $env:MSYS2_ROOT "ucrt64\bin")
  $searchRoots += (Join-Path $env:MSYS2_ROOT "mingw64\bin")
}
$searchRoots += @(
  "C:\msys64\ucrt64\bin",
  "C:\msys64\mingw64\bin",
  "$env:RUNNER_TEMP\setup-msys2\msys64\ucrt64\bin",
  "$env:RUNNER_TEMP\setup-msys2\msys64\mingw64\bin",
  "C:\mingw64\bin"
)
$searchRoots = $searchRoots | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

foreach ($dll in $runtimeDlls) {
  $found = $false
  foreach ($root in $searchRoots) {
    $candidate = Join-Path $root $dll
    if (Test-Path $candidate) {
      Copy-Item -Path $candidate -Destination $binDir -Force
      Write-Host "Copied runtime DLL: $candidate -> $binDir"
      $found = $true
      break
    }
  }
  if (-not $found) {
    Write-Warning "Runtime DLL not found in MSYS2 search roots: $dll"
  }
}

$toolchain = $env:PYJAGS_WINDOWS_TOOLCHAIN
if ($toolchain -eq "mingw") {
  Write-Host "MinGW toolchain requested; skipping MSVC import-lib generation."
  Get-ChildItem -Path (Join-Path $JagsRoot "x64\lib") -Filter "libjags*.dll.a" -ErrorAction SilentlyContinue | Select-Object -First 3 FullName | ForEach-Object { Write-Host "  mingw-lib: $_" }
  Get-ChildItem -Path (Join-Path $JagsRoot "x64\lib") -Filter "libjrmath*.dll.a" -ErrorAction SilentlyContinue | Select-Object -First 3 FullName | ForEach-Object { Write-Host "  mingw-lib: $_" }
} else {
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
    throw "Required MSVC tools dumpbin/lib not found to generate import libraries"
  }

  function Ensure-ImportLib($dllPath, $implibPath) {
    if (-not (Test-Path $dllPath)) { return }
    Write-Host "Generating MSVC import library $implibPath from $dllPath"
    $tempDef = Join-Path $env:TEMP ("jags_exports_" + [IO.Path]::GetFileNameWithoutExtension($dllPath) + ".def")

    & $dumpbin /exports $dllPath | Where-Object { $_ -match "^[ ]+[0-9]+" } |
      ForEach-Object {
        if ($_ -match "^[ ]+[0-9]+\s+[0-9A-F]+\s+[0-9A-F]+\s+(\S+)$") { $matches[1] }
      } | Where-Object { $_ } | Set-Content -Path $tempDef -Encoding ASCII
    $lines = Get-Content $tempDef
    @("EXPORTS") + $lines | Set-Content -Path $tempDef -Encoding ASCII

    & $libexe /def:$tempDef /machine:x64 /out:$implibPath
  }

  $dlls = @(
    @{dll = Join-Path $JagsRoot "x64\bin\libjags-4.dll"; lib = Join-Path $JagsRoot "x64\lib\libjags-4.lib"}
  )

  $jrmathDll = Get-ChildItem -Path (Join-Path $JagsRoot "x64\bin") -Filter "libjrmath-*.dll" -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($jrmathDll) {
    $base = [IO.Path]::GetFileNameWithoutExtension($jrmathDll.Name)
    $jrmathLib = Join-Path $JagsRoot ("x64\lib\" + $base + ".lib")
    $dlls += @(@{dll = $jrmathDll.FullName; lib = $jrmathLib})
  } else {
    Write-Warning "No jrmath DLL found under $JagsRoot\x64\bin"
  }

  foreach ($entry in $dlls) {
    if (Test-Path $entry.dll) {
      Ensure-ImportLib -dllPath $entry.dll -implibPath $entry.lib
    } else {
      Write-Warning "Expected DLL not found: $($entry.dll)"
    }
  }
}
