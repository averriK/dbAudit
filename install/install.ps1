#Requires -Version 5.1
# install.ps1
# dbaudit Installer for Windows (repo-based)
#
# Usage (PowerShell):
#   git clone git@github.com:averriK/dbAudit.git
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\dbAudit\install\install.ps1
#
# Options:
#   -Force         Proceed without prompts (replace existing install)
#   -SkipPackages  Skip R package installation (packages will be installed on first run)
#
# Requirements:
#   - R (>= 3.5) must be installed and Rscript must be in PATH
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
$installedSetup = Join-Path $LibexecDir "R\\setup.R"
if (-not (Test-Path $installedSetup)) {
    Fail "Invalid installed layout: missing $installedSetup"
}

# Generate version file
Info "Generating version file..."
try {
    Push-Location $RepoRoot
    $ErrorActionPreference = "SilentlyContinue"

    $commit = & git rev-parse --short HEAD 2>$null
    $branch = & git rev-parse --abbrev-ref HEAD 2>$null
    $tag = & git describe --tags --exact-match 2>$null
    $installDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss UTC")

    if (-not $commit) { $commit = "unknown" }
    if (-not $branch) { $branch = "unknown" }
    if (-not $tag) { $tag = "" }

    $versionContent = @"
commit=$commit
branch=$branch
tag=$tag
install_date=$installDate
libexec_dir=$LibexecDir
bin_dir=$UserBinDir
cmd_path=$cmdPath
shim_path=$shimPath
"@

    [System.IO.File]::WriteAllText($versionPath, $versionContent, [System.Text.Encoding]::UTF8)
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
Write-Host ""
Info "Checking R installation..."
$rscript = $null
try {
    $rscript = Get-Command Rscript -ErrorAction SilentlyContinue
    if (-not $rscript) { $rscript = Get-Command Rscript.exe -ErrorAction SilentlyContinue }
} catch {}

if (-not $rscript) {
    Fail @"
R is not installed or Rscript is not in PATH.

dbaudit requires R (>= 3.5) to run.

Install R for Windows from CRAN:
  https://cran.r-project.org/bin/windows/base/

After installing R:
  1. Restart your terminal (to pick up PATH changes)
  2. Run this installer again

"@
}

# Verify R version >= 3.5
$versionOutput = & $rscript.Source --version 2>&1 | Out-String
if ($versionOutput -match 'version (\d+)\.(\d+)') {
    $major = [int]$matches[1]
    $minor = [int]$matches[2]

    if (($major -lt 3) -or ($major -eq 3 -and $minor -lt 5)) {
        Fail @"
R version $major.$minor found, but dbaudit requires R >= 3.5.

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
    Info "Installing R package dependencies (data.table, stringr, lubridate)..."
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
    cat("       Rscript -e 'install.packages(c(\"data.table\", \"stringr\", \"lubridate\"), type=\"binary\")'\n")
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
        $result = $installScript | & $rscript.Source -
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
$cmdLines = @(
    '@echo off',
    'setlocal',
    ('set "DBAUDIT_HOME={0}"' -f $LibexecDir),
    '',
    'where Rscript >nul 2>nul',
    'if %errorlevel%==0 (',
    '  set "RSCRIPT=Rscript"',
    ') else (',
    '  where Rscript.exe >nul 2>nul',
    '  if %errorlevel%==0 (',
    '    set "RSCRIPT=Rscript.exe"',
    '  ) else (',
    '    echo ERROR: Rscript not found in PATH. Install R and try again. 1>&2',
    '    exit /b 1',
    '  )',
    ')',
    '',
    '"%RSCRIPT%" "%DBAUDIT_HOME%\DBAudit" %*'
)

# Ensure CRLF for .cmd
$cmd = ($cmdLines -join "`r`n") + "`r`n"
[System.IO.File]::WriteAllText($cmdPath, $cmd, [System.Text.Encoding]::ASCII)

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
