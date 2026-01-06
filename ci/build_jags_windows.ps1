$ErrorActionPreference = 'Stop'

$JagsVersion = '4.3.1'
$JagsMajor = $JagsVersion.Split('.')[0]
$Prefix = 'C:\jags'
$ExpectedRoot = Join-Path $Prefix "JAGS-$JagsVersion"
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

Write-Host "Installing to $ExpectedRoot ..."
Start-Process -FilePath $Installer -ArgumentList "/S","/D=$ExpectedRoot" -Wait -PassThru | Out-Null
Write-Host "JAGS installer completed."

$candidates = @(
  "$ExpectedRoot",
  "$Prefix",
  (Join-Path $Prefix "JAGS-$JagsVersion"),
  (Join-Path $Prefix "JAGS\$JagsVersion"),
  (Join-Path ${env:ProgramFiles} "JAGS\JAGS-$JagsVersion")
)

function Has-JagsLayout([string]$root) {
  return (Test-Path (Join-Path $root "include\JAGS\version.h")) -or
         (Test-Path (Join-Path $root "include\version.h"))
}

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

Write-Host "Environment diagnostics:"
Write-Host "  PATH=$env:PATH"
Write-Host "  MSYSTEM=$env:MSYSTEM"
Write-Host "  MSYS2_ROOT=$env:MSYS2_ROOT"
Write-Host "  RUNNER_TEMP=$env:RUNNER_TEMP"
Write-Host "  g++: $(Get-Command g++.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)"
Write-Host "  gcc: $(Get-Command gcc.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)"
Write-Host "  objdump: $(Get-Command objdump.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)"
Write-Host "  dumpbin: $(Find-Tool "dumpbin")"

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

Write-Host "Expected JAGS root: $ExpectedRoot"
Write-Host "Detected JAGS root: $JagsRoot"

function Invoke-Robocopy([string]$Source, [string]$Destination, [string[]]$Options) {
  $robocopy = (Get-Command "robocopy.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source)
  if (-not $robocopy) {
    throw "robocopy.exe not found; cannot move JAGS installation."
  }
  $args = @($Source, $Destination) + $Options + @("/NFL","/NDL","/NJH","/NJS","/NP")
  & $robocopy @args | Out-Null
  if ($LASTEXITCODE -ge 8) {
    throw "robocopy failed moving $Source to $Destination (exit code $LASTEXITCODE)"
  }
}

if ($JagsRoot -ne $ExpectedRoot) {
  Write-Host "Relocating JAGS from $JagsRoot to $ExpectedRoot"
  if (Test-Path $ExpectedRoot) {
    Remove-Item -Path $ExpectedRoot -Recurse -Force
  }
  Invoke-Robocopy -Source $JagsRoot -Destination $ExpectedRoot -Options @("/E","/MOVE")
  $JagsRoot = $ExpectedRoot
}

$ExpectedModulesDir = Join-Path $JagsRoot "x64\lib\JAGS\modules-$JagsMajor"
Write-Host "Expected modules dir: $ExpectedModulesDir"

$ActualModulesDir = $null
$basemod = Get-ChildItem -Path $JagsRoot -Filter "basemod.dll" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if ($basemod) {
  $ActualModulesDir = Split-Path -Path $basemod.FullName -Parent
} else {
  $modulesHit = Get-ChildItem -Path $JagsRoot -Directory -Filter ("modules-" + $JagsMajor) -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($modulesHit) {
    $ActualModulesDir = $modulesHit.FullName
  }
}

Write-Host "Detected modules dir: $ActualModulesDir"
if (-not $ActualModulesDir) {
  throw "JAGS modules directory not found under $JagsRoot"
}

if ($ActualModulesDir -ne $ExpectedModulesDir) {
  Write-Host "Syncing JAGS modules to expected location."
  New-Item -ItemType Directory -Path $ExpectedModulesDir -Force | Out-Null
  Invoke-Robocopy -Source $ActualModulesDir -Destination $ExpectedModulesDir -Options @("/E")
}

if (-not (Test-Path (Join-Path $ExpectedModulesDir "basemod.dll"))) {
  throw "Expected modules directory does not contain basemod.dll: $ExpectedModulesDir"
}

Write-Host "Final JAGS layout:"
Write-Host "  root: $JagsRoot"
Write-Host "  bin: $(Join-Path $JagsRoot 'x64\bin')"
Write-Host "  lib: $(Join-Path $JagsRoot 'x64\lib')"
Write-Host "  modules: $ExpectedModulesDir"

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
  "libwinpthread-1.dll",
  "libgfortran-5.dll",
  "libquadmath-0.dll",
  "libgomp-1.dll",
  "libssp-0.dll",
  "libatomic-1.dll"
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

Write-Host "Runtime search roots:"
foreach ($root in $searchRoots) {
  Write-Host "  root: $root"
}

function Get-DllDependencies([string]$dllPath) {
  $deps = @()
  $objdump = Get-Command "objdump.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
  $dumpbin = Find-Tool "dumpbin"
  if ($objdump -and (Test-Path $objdump)) {
    $lines = & $objdump -p $dllPath 2>$null
    foreach ($line in $lines) {
      if ($line -match "DLL Name:\s*(\S+\.dll)") {
        $deps += $matches[1]
      }
    }
  } elseif ($dumpbin -and (Test-Path $dumpbin)) {
    $lines = & $dumpbin /dependents $dllPath 2>$null
    foreach ($line in $lines) {
      if ($line -match "([A-Za-z0-9_.-]+\.dll)") {
        $deps += $matches[1]
      }
    }
  }
  $system = @(
    "KERNEL32.dll","USER32.dll","ADVAPI32.dll","SHELL32.dll","MSVCRT.dll",
    "VCRUNTIME140.dll","VCRUNTIME140_1.dll","ucrtbase.dll","GDI32.dll",
    "OLE32.dll","OLEAUT32.dll","WS2_32.dll","CRYPT32.dll","COMDLG32.dll"
  )
  $deps = $deps | Where-Object { $_ -and ($system -notcontains $_) } | Select-Object -Unique
  return $deps
}

$depTargets = @(
  (Join-Path $binDir "libjags-4.dll"),
  (Join-Path $binDir "libjrmath-0.dll")
)
$depTargets = $depTargets | Where-Object { $_ -and (Test-Path $_) }
if ($depTargets) {
  $depList = @()
  foreach ($dll in $depTargets) {
    $deps = Get-DllDependencies $dll
    if ($deps) {
      Write-Host ("Dependencies for {0}:" -f $dll)
      foreach ($dep in $deps) { Write-Host "  dep: $dep" }
      $depList += $deps
    } else {
      Write-Host ("Dependencies for {0}: (none detected or tool missing)" -f $dll)
    }
  }
  if ($depList) {
    $runtimeDlls += $depList
    $runtimeDlls = $runtimeDlls | Select-Object -Unique
  }
}

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

Write-Host "JAGS bin contents (trimmed):"
Get-ChildItem -Path $binDir -Filter "*.dll" -ErrorAction SilentlyContinue | Select-Object -First 30 FullName | ForEach-Object { Write-Host "  bin-dll: $_" }

$toolchain = $env:PYJAGS_WINDOWS_TOOLCHAIN
if ($toolchain -eq "mingw") {
  Write-Host "MinGW toolchain requested; skipping MSVC import-lib generation."
  Get-ChildItem -Path (Join-Path $JagsRoot "x64\lib") -Filter "libjags*.dll.a" -ErrorAction SilentlyContinue | Select-Object -First 3 FullName | ForEach-Object { Write-Host "  mingw-lib: $_" }
  Get-ChildItem -Path (Join-Path $JagsRoot "x64\lib") -Filter "libjrmath*.dll.a" -ErrorAction SilentlyContinue | Select-Object -First 3 FullName | ForEach-Object { Write-Host "  mingw-lib: $_" }
} else {
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
