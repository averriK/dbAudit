#Requires -Version 5.1
# install.ps1
# dbaudit Installer for Windows (repo-based)
#
# Usage (PowerShell):
#   git clone https://github.com/averriK/dbAudit.git
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\dbAudit\install\install.ps1
#
# Options:
#   -Force         Proceed without prompts (replace existing install)
#   -SkipPackages  Skip R package installation (packages will be installed on first run)
#
# Requirements:
#   - R (>= 4.1.0) must be installed and Rscript must be in PATH
#   - Internet connectivity (for package installation, unless -SkipPackages is used)
#
# Notes:
#   - Installs from the local repo / extracted package (no GitHub API).
#   - Creates launchers in a per-user bin dir and adds it to User PATH.

[CmdletBinding()]
param(
    # Repo root (defaults to parent of this script directory)
    [string]$RepoRoot,

    # Runtime installation directory
    # Default: %LOCALAPPDATA%\Programs\_runtime\dbAudit
    [string]$LibexecDir = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Programs\_runtime\dbAudit'),

    # User bin directory to place launchers
    # Default: %LOCALAPPDATA%\Programs
    [string]$UserBinDir = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Programs'),

    # Proceed without prompts (replace existing install)
    [switch]$Force,

    # Skip R package installation (packages will be installed on first run)
    [switch]$SkipPackages
)

$ErrorActionPreference = "Stop"

function Info($msg)  { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Ok($msg)    { Write-Host "[OK]   $msg" -ForegroundColor Green }
function Warn($msg)  { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Fail($msg)  { Write-Host "[ERROR] $msg" -ForegroundColor Red; exit 1 }

function Write-LFFile {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Content
    )

    # Normalize line endings to LF to avoid CRLF issues in Git Bash.
    $normalized = $Content -replace "`r`n", "`n"
    $normalized = $normalized -replace "`r", "`n"

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $normalized, $utf8NoBom)
}

function Add-ToUserPath {
    param([Parameter(Mandatory=$true)][string]$Dir)

    if (-not (Test-Path $Dir)) { return $false }

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $parts = @()
    if ($userPath) { $parts = $userPath -split ";" | Where-Object { $_ -and $_.Trim() -ne "" } }

    $needle = $Dir.TrimEnd('\\')
    foreach ($p in $parts) {
        if ($p.TrimEnd('\\') -ieq $needle) { return $true }
    }

    $newUserPath = if ($parts.Count -gt 0) { ($parts + $Dir) -join ";" } else { $Dir }
    [Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")

    # Refresh current session too
    if ($env:Path -notlike "*$Dir*") {
        $env:Path = $env:Path.TrimEnd(';') + ";" + $Dir
    }

    return $true
}

function Resolve-GitBashExe {
    if ($env:GIT_BASH -and (Test-Path $env:GIT_BASH)) { return $env:GIT_BASH }

    $candidates = @(
        "C:\\Program Files\\Git\\bin\\bash.exe",
        "C:\\Program Files\\Git\\usr\\bin\\bash.exe",
        "C:\\Program Files (x86)\\Git\\bin\\bash.exe",
        "C:\\Program Files (x86)\\Git\\usr\\bin\\bash.exe"
    )
    foreach ($p in $candidates) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

function To-GitBashPath {
    param([Parameter(Mandatory=$true)][string]$WinPath)

    $p = $WinPath -replace "\\", "/"
    if ($p -match '^([A-Za-z]):/(.*)$') {
        return "/$($matches[1].ToLower())/$($matches[2])"
    }
    return $p
}

if (-not $RepoRoot -or $RepoRoot.Trim() -eq "") {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot ".." )).Path
}

$repoEntrypoint = Join-Path $RepoRoot "DBAudit"
$repoSetup = Join-Path $RepoRoot "R\\setup.R"
$repoBin = Join-Path $RepoRoot "bin\\dbaudit"

if (-not (Test-Path $repoEntrypoint) -or -not (Test-Path $repoSetup) -or -not (Test-Path $repoBin)) {
    Fail "Invalid source tree. Run this installer from inside the dbAudit repo/package (expected DBAudit + R\\setup.R + bin\\dbaudit)."
}

Info "dbaudit Installer (Windows / PowerShell, repo-based)"
Info "RepoRoot: $RepoRoot"
Info "Runtime : $LibexecDir"
Info "Bin     : $UserBinDir"
$versionPath = Join-Path $LibexecDir ".version"
$cmdPath = Join-Path $UserBinDir "dbaudit.cmd"
$shimPath = Join-Path $UserBinDir "dbaudit"
# If an existing install is detected, confirm removal first.
$existingCmd = Join-Path $UserBinDir "dbaudit.cmd"
$existingShim = Join-Path $UserBinDir "dbaudit"
$removeLibexec = $LibexecDir
$removeCmd = $existingCmd
$removeShim = $existingShim
if ((Test-Path $LibexecDir) -or (Test-Path $existingCmd) -or (Test-Path $existingShim)) {
    Warn "Existing dbaudit installation detected."
    $versionFile = Join-Path $LibexecDir ".version"
    if (Test-Path $versionFile) {
        $info = @{}
        Get-Content -LiteralPath $versionFile | ForEach-Object {
            if ($_ -match '^([^=]+)=(.*)$') { $info[$matches[1]] = $matches[2] }
        }
        if ($info.ContainsKey("bin_dir") -and $info["bin_dir"]) {
            $removeCmd = Join-Path $info["bin_dir"] "dbaudit.cmd"
            $removeShim = Join-Path $info["bin_dir"] "dbaudit"
        }
        if ($info.ContainsKey("libexec_dir") -and $info["libexec_dir"]) {
            $removeLibexec = $info["libexec_dir"]
        }
        if ($info.ContainsKey("commit")) {
            $ver = $info["commit"]
            if ($info.ContainsKey("branch") -and $info["branch"]) { $ver = "$ver ($($info["branch"]))" }
            if ($info.ContainsKey("tag") -and $info["tag"]) { $ver = "$ver [$($info["tag"])]" }
            Warn "  version: $ver"
        }
        if ($info.ContainsKey("install_date") -and $info["install_date"]) {
            Warn "  installed: $($info["install_date"])"
        }
    }
    if (-not $Force) {
        $resp = Read-Host "Existing dbaudit will be removed. Continue? [y/N]"
        if ($resp -notmatch '^[Yy]$') { Fail "Aborted by user." }
    }

    if (Test-Path $removeCmd) {
        try { Remove-Item -LiteralPath $removeCmd -Force } catch { Fail "Failed to remove ${removeCmd}: $_" }
    }
    if (Test-Path $removeShim) {
        try { Remove-Item -LiteralPath $removeShim -Force } catch { Fail "Failed to remove ${removeShim}: $_" }
    }
    if (Test-Path $removeLibexec) {
        try { Remove-Item -LiteralPath $removeLibexec -Recurse -Force } catch { Fail "Failed to remove ${removeLibexec}: $_" }
    }
}

# Ensure target dirs exist
New-Item -ItemType Directory -Force -Path $UserBinDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $LibexecDir "bin") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $LibexecDir "R") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $LibexecDir "inst") | Out-Null

# Copy runtime
Info "Copying runtime..."
Copy-Item -LiteralPath $repoEntrypoint -Destination (Join-Path $LibexecDir "DBAudit") -Force

# Copy the *contents* of R/ into $LibexecDir\R (avoid $LibexecDir\R\R\...)
$srcR = Join-Path $RepoRoot "R"
$dstR = Join-Path $LibexecDir "R"
Copy-Item -Path (Join-Path $srcR "*") -Destination $dstR -Recurse -Force

$srcInst = Join-Path $RepoRoot "inst"
Copy-Item -Path (Join-Path $srcInst "*") -Destination (Join-Path $LibexecDir "inst") -Recurse -Force
Copy-Item -LiteralPath $repoBin -Destination (Join-Path $LibexecDir "bin\\dbaudit") -Force

# Validate installed layout
$installedEntrypoint = Join-Path $LibexecDir "DBAudit"
$installedSetup = Join-Path $LibexecDir "R\\setup.R"
$installedBin = Join-Path $LibexecDir "bin\\dbaudit"
if (-not (Test-Path $installedEntrypoint) -or -not (Test-Path $installedSetup) -or -not (Test-Path $installedBin)) {
    Fail "Invalid installed layout: missing expected runtime files under $LibexecDir"
}

# Generate version file
Info "Generating version file..."
try {
    Push-Location $RepoRoot
    $ErrorActionPreference = "SilentlyContinue"

    # git may be absent from this PowerShell PATH, or refuse a shared
    # checkout as dubious ownership (a Parallels-mounted Mac tree). Try
    # git first with the repo whitelisted; on any failure fall back to
    # reading .git/HEAD and the ref files directly, so the manifest
    # never silently records "unknown" while a real checkout is there.
    # git absent throws CommandNotFoundException, which would skip the
    # manifest write entirely (an extracted ZIP has no git): resolve the
    # command first, so the .git fallback and the write always run.
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    $commit = $null; $branch = $null; $tag = $null
    if ($gitCmd) {
        $commit = & git -C $RepoRoot -c "safe.directory=$RepoRoot" rev-parse --short HEAD 2>$null
        $branch = & git -C $RepoRoot -c "safe.directory=$RepoRoot" rev-parse --abbrev-ref HEAD 2>$null
        $tag = & git -C $RepoRoot -c "safe.directory=$RepoRoot" describe --tags --exact-match 2>$null
    }

    if (-not $commit -or -not $branch) {
        $headFile = Join-Path $RepoRoot ".git\HEAD"
        if (Test-Path $headFile) {
            $head = (Get-Content -LiteralPath $headFile -TotalCount 1).Trim()
            if ($head -match '^ref:\s*refs/heads/(.+)$') {
                if (-not $branch) { $branch = $matches[1] }
                $refFile = Join-Path $RepoRoot (".git\refs\heads\" + $matches[1].Replace("/", "\"))
                $sha = $null
                if (Test-Path $refFile) {
                    $sha = (Get-Content -LiteralPath $refFile -TotalCount 1).Trim()
                } else {
                    $packed = Join-Path $RepoRoot ".git\packed-refs"
                    if (Test-Path $packed) {
                        $hit = Get-Content -LiteralPath $packed | Where-Object { $_ -match ("\srefs/heads/" + [regex]::Escape($matches[1]) + "$") } | Select-Object -First 1
                        if ($hit) { $sha = ($hit -split "\s+")[0] }
                    }
                }
                if ($sha -and -not $commit) { $commit = $sha.Substring(0, [Math]::Min(7, $sha.Length)) }
            } elseif ($head -match '^[0-9a-f]{7,40}$') {
                if (-not $commit) { $commit = $head.Substring(0, 7) }
                if (-not $branch) { $branch = "detached" }
            }
        }
    }

    $installDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss UTC")

    if (-not $commit) { $commit = "unknown"; Warn "Build identity not captured: git unavailable and .git unreadable." }
    if (-not $branch) { $branch = "unknown" }
    if (-not $tag) { $tag = "" }

    $versionContent = @"
commit=$commit
branch=$branch
tag=$tag
install_date=$installDate
rscript_path=$rscriptPath
bin_path=$cmdPath
libexec_dir=$LibexecDir
bin_dir=$UserBinDir
cmd_path=$cmdPath
shim_path=$shimPath
"@

    # UTF-8 WITHOUT BOM: .NET Encoding.UTF8 prepends a BOM, which turns
    # the first line into "\ufeffcommit=..." and blinds every key=value
    # reader (dbaudit --version showed "Build: unknown" on Windows).
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($versionPath, $versionContent, $utf8NoBom)
    Pop-Location
    $ErrorActionPreference = "Stop"
} catch {
    Warn "Could not generate version file: $_"
    if ((Get-Location).Path -ne (Get-Item $PSScriptRoot).Parent.FullName) {
        Pop-Location
    }
    $ErrorActionPreference = "Stop"
}

# Strict R availability check
# On Windows an R installation is a registry fact: the CRAN installer
# writes SOFTWARE\R-core\{R,R64,R32} with InstallPath and Current
# Version, per machine or per user, one subkey per installed version. R
# does not add itself to the PATH, so resolving Rscript through the PATH
# alone reports a working installation as missing. The registry is read
# first, the PATH second, unregistered trees last; candidates are
# collapsed by the R_HOME each binary reports, so several paths and keys
# describing one installation count once. This detects; it never
# installs R.
function Resolve-RInstallation {
    $eap = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"
    $paths = New-Object System.Collections.ArrayList

    function Add-Bin($installPath) {
        if (-not $installPath) { return }
        foreach ($rel in @("bin\x64\Rscript.exe", "bin\i386\Rscript.exe", "bin\Rscript.exe")) {
            $c = Join-Path $installPath $rel
            if (Test-Path -LiteralPath $c) { [void]$paths.Add((Resolve-Path -LiteralPath $c).Path) }
        }
    }

    foreach ($hive in @("HKLM:", "HKCU:")) {
        foreach ($branch in @("SOFTWARE\R-core", "SOFTWARE\WOW6432Node\R-core")) {
            foreach ($flavour in @("R", "R64", "R32")) {
                $key = "$hive\$branch\$flavour"
                if (-not (Test-Path $key)) { continue }
                Add-Bin (Get-ItemProperty -LiteralPath $key).InstallPath
                foreach ($sub in Get-ChildItem -LiteralPath $key) {
                    Add-Bin (Get-ItemProperty -LiteralPath $sub.PSPath).InstallPath
                }
            }
        }
    }

    $onPath = @()
    foreach ($n in @("Rscript", "Rscript.exe")) {
        foreach ($c in (Get-Command $n -All)) {
            if ($c.Source -and (Test-Path -LiteralPath $c.Source)) {
                $rp = (Resolve-Path -LiteralPath $c.Source).Path
                $onPath += $rp
                [void]$paths.Add($rp)
            }
        }
    }

    foreach ($base in @(
        (Join-Path $env:ProgramFiles "R"),
        (Join-Path ${env:ProgramFiles(x86)} "R"),
        (Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "Programs\R")
    )) {
        if (-not $base -or -not (Test-Path -LiteralPath $base)) { continue }
        foreach ($d in Get-ChildItem -LiteralPath $base -Directory) { Add-Bin $d.FullName }
    }

    $found = @()
    foreach ($rp in ($paths | Select-Object -Unique)) {
        $out = & $rp --version 2>&1 | Out-String
        $ver = $null
        if ($out -match "version (\d+)\.(\d+)\.(\d+)") {
            $ver = [version]("{0}.{1}.{2}" -f $matches[1], $matches[2], $matches[3])
        } elseif ($out -match "version (\d+)\.(\d+)") {
            $ver = [version]("{0}.{1}.0" -f $matches[1], $matches[2])
        }
        if (-not $ver) { continue }
        $home = (& $rp -e "cat(R.home())" 2>&1 | Out-String).Trim()
        $found += [pscustomobject]@{
            Path = $rp; Version = $ver; RHome = $home; OnPath = ($onPath -contains $rp)
        }
    }

    $ErrorActionPreference = $eap
    if ($found.Count -eq 0) { return $null }

    # One installation, however many paths reached it.
    $installs = @()
    foreach ($g in ($found | Group-Object RHome)) {
        $best = $g.Group | Sort-Object Version -Descending | Select-Object -First 1
        $installs += [pscustomobject]@{
            Path = ($g.Group | Where-Object { $_.OnPath } | Select-Object -First 1 -ExpandProperty Path)
            Version = $best.Version
            RHome = $g.Name
            OnPath = [bool]($g.Group | Where-Object { $_.OnPath })
        }
        if (-not $installs[-1].Path) { $installs[-1].Path = $best.Path }
    }
    return ($installs | Sort-Object Version -Descending)
}

Write-Host ""
Info "Checking R installation..."
$installs = Resolve-RInstallation
$rscript = $null
$rscriptPath = $null
if ($installs) {
    $usable = @($installs | Where-Object { $_.Version -ge [version]"4.1.0" })
    Info ("R installations found: {0}" -f @($installs).Count)
    foreach ($i in $installs) {
        Info ("  {0}  {1}{2}" -f $i.Version, $i.RHome, $(if ($i.OnPath) { "  [on PATH]" } else { "" }))
    }
    if ($usable.Count -gt 0) {
        $pick = @($usable | Where-Object { $_.OnPath } | Select-Object -First 1)
        if (-not $pick) { $pick = @($usable | Select-Object -First 1) }
        $rscriptPath = $pick[0].Path
        $rscript = [pscustomobject]@{ Source = $rscriptPath }
        if (-not $pick[0].OnPath) {
            Warn "R $($pick[0].Version) is installed but not on the PATH."
            Warn "The launcher will use it directly: $rscriptPath"
            Warn "Adding $(Split-Path $rscriptPath -Parent) to your PATH is still recommended."
        }
    }
}

if (-not $rscript) {
    # Installing dbaudit does not need R; running it does, and the
    # launcher resolves R again on every invocation. Aborting here would
    # strand a user who is about to install R, so the install completes
    # and says exactly what is missing.
    Warn @"
No R installation (>= 4.1.0) was found on this machine.

dbaudit needs R to run. Install R for Windows from CRAN:
  https://cran.r-project.org/bin/windows/base/

dbaudit will find it on the next run, whether or not R is on the PATH.
The R packages were not installed; they install on first run.
"@
    $SkipPackages = $true
}

# Verify R version >= 4.1 (DESCRIPTION: R (>= 4.1.0)).
# R <= 4.1.x prints its banner on stderr (it moved to stdout in 4.2.0),
# and PowerShell 5.1 turns redirected native stderr into a terminating
# error while ErrorActionPreference is Stop: the version gate would kill
# the install on the very minimum version it exists to admit.
$versionOutput = ""
if ($rscript) {
    $eapPrev = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"
    $versionOutput = & $rscript.Source --version 2>&1 | Out-String
    $ErrorActionPreference = $eapPrev
}
if ($versionOutput -match 'version (\d+)\.(\d+)') {
    $major = [int]$matches[1]
    $minor = [int]$matches[2]

    if (($major -lt 4) -or ($major -eq 4 -and $minor -lt 1)) {
        Fail @"
R version $major.$minor found, but dbaudit requires R >= 4.1.0.

Please upgrade R from: https://cran.r-project.org/bin/windows/base/
"@
    }

    Ok "R version $major.$minor detected"
} else {
    Warn "Could not parse R version - assuming it's compatible"
}

# Install R package dependencies
Write-Host ""
if (-not $SkipPackages) {
    Info "Installing R package dependencies (data.table, stringr, lubridate, readxl, jsonlite)..."
    Info "This may take a few minutes..."

    $installScript = @'
repos <- "https://cloud.r-project.org"
required <- c("data.table", "stringr", "lubridate", "readxl", "jsonlite")
missing <- required[!sapply(required, requireNamespace, quietly = TRUE)]

if (length(missing) > 0) {
  cat(sprintf("Installing: %s\n", paste(missing, collapse=", ")))
  cat("Note: Installing pre-compiled binaries (Windows does not compile from source)\n\n")

  # Windows: ALWAYS use binaries, never compile from source (would require Rtools)
  install.packages(missing, repos = repos, type = "binary", quiet = FALSE)

  # Verify installation succeeded
  still_missing <- missing[!sapply(missing, requireNamespace, quietly = TRUE)]
  if (length(still_missing) > 0) {
    cat(sprintf("\nERROR: Failed to install packages: %s\n", paste(still_missing, collapse=", ")))
    cat("\nTroubleshooting:\n")
    cat("  1. Check internet connectivity\n")
    cat("  2. Verify CRAN mirror is accessible: https://cloud.r-project.org\n")
    cat("  3. Check if binary packages are available for your R version\n")
    cat("  4. Try manual installation in PowerShell:\n")
    cat("       Rscript -e 'install.packages(c(\"data.table\", \"stringr\", \"lubridate\", \"readxl\", \"jsonlite\"), type=\"binary\")'\n")
    cat("  5. Check R library permissions: .libPaths()\n")
    cat("\nNOTE: Windows cannot compile R packages from source without Rtools.\n")
    cat("      If binaries are unavailable, upgrade R to a version with binary packages.\n")
    quit(status = 1)
  }

  cat("\nPackages installed successfully.\n")
} else {
  cat("All required packages already installed.\n")
}
'@

    try {
        $installScript | & $rscript.Source -
        if ($LASTEXITCODE -ne 0) {
            Fail "Failed to install R packages. See troubleshooting steps above."
        }
        Ok "R packages installed successfully"
    } catch {
        Fail "Failed to install R packages: $_"
    }
} else {
    Warn "Skipping R package installation (-SkipPackages flag used)"
    Info "Packages will be auto-installed on first dbaudit run"
}

Write-Host ""

# Create launchers in UserBinDir

# NOTE: avoid PowerShell here-strings for .cmd content; they are easy to break when a file is copied/rewritten.

# The .cmd is written as ASCII, so an accented profile path baked in
# literally would be mangled into a path that does not exist. Emit the
# %LOCALAPPDATA% variable instead and let cmd.exe expand it at runtime.
$lad = [Environment]::GetFolderPath("LocalApplicationData")
if ($lad -and $LibexecDir.StartsWith($lad, [System.StringComparison]::OrdinalIgnoreCase)) {
    $cmdHome = "%LOCALAPPDATA%" + $LibexecDir.Substring($lad.Length)
} else {
    $cmdHome = $LibexecDir
}

# The launcher resolves R on every run, not only at install time: the
# PATH first, then the path this install resolved, then the registry —
# where the CRAN installer records every installation. R absent from the
# PATH is the normal state on Windows, not an error.
$cmdLines = @(
    '@echo off',
    'setlocal',
    ('set "DBAUDIT_HOME={0}"' -f $cmdHome),
    ('set "RSCRIPT_PINNED={0}"' -f $rscriptPath),
    'set "RSCRIPT="',
    '',
    'where Rscript >nul 2>nul',
    'if %errorlevel%==0 (set "RSCRIPT=Rscript" & goto :run)',
    'where Rscript.exe >nul 2>nul',
    'if %errorlevel%==0 (set "RSCRIPT=Rscript.exe" & goto :run)',
    'if defined RSCRIPT_PINNED if exist "%RSCRIPT_PINNED%" (set "RSCRIPT=%RSCRIPT_PINNED%" & goto :run)',
    '',
    'call :fromreg "HKLM\SOFTWARE\R-core\R64"',
    'if defined RSCRIPT goto :run',
    'call :fromreg "HKLM\SOFTWARE\R-core\R"',
    'if defined RSCRIPT goto :run',
    'call :fromreg "HKCU\SOFTWARE\R-core\R64"',
    'if defined RSCRIPT goto :run',
    'call :fromreg "HKCU\SOFTWARE\R-core\R"',
    'if defined RSCRIPT goto :run',
    '',
    'echo ERROR: R not found. Install R ^(4.1.0 or newer^) from 1>&2',
    'echo        https://cran.r-project.org/bin/windows/base/ 1>&2',
    'exit /b 1',
    '',
    ':fromreg',
    'for /f "tokens=2,*" %%A in (''reg query %~1 /v InstallPath 2^>nul ^| findstr /i "InstallPath"'') do (',
    '  if exist "%%~B\bin\x64\Rscript.exe" set "RSCRIPT=%%~B\bin\x64\Rscript.exe"',
    '  if not defined RSCRIPT if exist "%%~B\bin\Rscript.exe" set "RSCRIPT=%%~B\bin\Rscript.exe"',
    ')',
    'exit /b 0',
    '',
    ':run',
    '"%RSCRIPT%" "%DBAUDIT_HOME%\DBAudit" %*'
)

# Ensure CRLF for .cmd
$cmd = ($cmdLines -join "`r`n") + "`r`n"
if ($cmd -match "[^\x00-\x7F]") {
    # A custom install path outside %LOCALAPPDATA% can still carry
    # non-ASCII: write the codepage cmd.exe parses with, and say so
    # rather than corrupt the launcher silently.
    try {
        $oem = [System.Text.Encoding]::GetEncoding([System.Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage)
        if ($oem.GetString($oem.GetBytes($cmd)) -ceq $cmd) {
            [System.IO.File]::WriteAllText($cmdPath, $cmd, $oem)
        } else {
            [System.IO.File]::WriteAllText($cmdPath, $cmd, $oem)
            Warn "Install path has characters the console codepage cannot represent; if dbaudit fails to start, reinstall under a plain-ASCII path."
        }
    } catch {
        [System.IO.File]::WriteAllText($cmdPath, $cmd, [System.Text.Encoding]::ASCII)
        Warn "Could not resolve the console codepage; launcher written as ASCII."
    }
} else {
    [System.IO.File]::WriteAllText($cmdPath, $cmd, [System.Text.Encoding]::ASCII)
}

$shimLines = @(
    '#!/usr/bin/env bash',
    'set -Eeuo pipefail',
    'exec "$(dirname "$0")/dbaudit.cmd" "$@"'
)
$shim = ($shimLines -join "`n") + "`n"
Write-LFFile -Path $shimPath -Content $shim

# Ensure executability in Git Bash (best-effort)
$bashExe = Resolve-GitBashExe
if ($bashExe) {
    try {
        $binBash = To-GitBashPath -WinPath $UserBinDir
        & $bashExe -lc "chmod +x '$binBash/dbaudit'" | Out-Null
    } catch {}
}

Ok "Created launchers:"
Ok "  $cmdPath"
Ok "  $shimPath"

#
# Add to User PATH
$pathAdded = $false
$pathAdded = Add-ToUserPath -Dir $UserBinDir
if ($pathAdded) {
    Ok "Ensured User PATH contains: $UserBinDir"
    Warn "Open a NEW terminal so PATH updates are picked up."
}

# Persist PATH modification status in manifest (best-effort)
if (Test-Path $versionPath) {
    try {
        Add-Content -LiteralPath $versionPath -Value ("path_added=" + ($(if ($pathAdded) { "true" } else { "false" })))
    } catch {
        Warn "Could not update manifest with path_added: $_"
    }
}

# Write install manifest in UserBinDir (tito-style)
$installManifestPath = Join-Path $UserBinDir "dbaudit.INSTALL_MANIFEST"
$installLines = @(
    "manifest_version=1",
    ("installed_at_utc=" + (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')),
    ("libexec_dir=" + $LibexecDir),
    ("bin_dir=" + $UserBinDir),
    ("path_added=" + ($(if ($pathAdded) { "true" } else { "false" }))),
    ("file=" + $cmdPath),
    ("file=" + $shimPath),
    ("file=" + $versionPath),
    ("file=" + $installManifestPath),
    ("dir=" + $LibexecDir)
)
Write-LFFile -Path $installManifestPath -Content (($installLines -join "`n") + "`n")


Write-Host ""
Info "Verify installation in a new terminal:"
Info "  dbaudit --check"
Info ""
Info "Get help:"
Info "  dbaudit --help"

Write-Host ""
Info "Documentation:"
Info "  https://averrik.github.io/dbAudit/docs/"
