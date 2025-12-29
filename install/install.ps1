#Requires -Version 5.1
# install.ps1
# dbAudit Installer for Windows (repo-based)
#
# Usage (PowerShell):
#   git clone git@github.com:averriK/dbAudit.git
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\dbAudit\install\install.ps1
#
# Notes:
#   - Installs from the local repo / extracted package (no GitHub API).
#   - R is required at runtime (Rscript in PATH).
#   - Creates launchers in a per-user bin dir and (optionally) adds it to User PATH.

[CmdletBinding()]
param(
    # Repo root (defaults to parent of this script directory)
    [string]$RepoRoot,

    # Runtime installation directory
    # Default: %LOCALAPPDATA%\Programs\dbAudit\libexec\dbAudit
    [string]$LibexecDir = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Programs\dbAudit\libexec\dbAudit'),

    # User bin directory to place launchers
    # Default: %LOCALAPPDATA%\Programs\dbAudit\bin
    [string]$UserBinDir = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Programs\dbAudit\bin'),

    # Skip adding $UserBinDir to the User PATH
    [switch]$SkipPath
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
$repoBin = Join-Path $RepoRoot "bin\\dbAudit"

if (-not (Test-Path $repoEntrypoint) -or -not (Test-Path $repoSetup) -or -not (Test-Path $repoBin)) {
    Fail "Invalid source tree. Run this installer from inside the dbAudit repo/package (expected DBAudit + R\\setup.R + bin\\dbAudit)."
}

Info "dbAudit Installer (Windows / PowerShell, repo-based)"
Info "RepoRoot: $RepoRoot"
Info "Runtime : $LibexecDir"
Info "Bin     : $UserBinDir"

# Ensure target dirs exist
New-Item -ItemType Directory -Force -Path $UserBinDir | Out-Null

# Replace runtime tree
if (Test-Path $LibexecDir) {
    Warn "Existing runtime directory found at $LibexecDir – it will be replaced."
    Remove-Item -LiteralPath $LibexecDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path (Join-Path $LibexecDir "bin") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $LibexecDir "R") | Out-Null

# Copy runtime
Info "Copying runtime..."
Copy-Item -LiteralPath $repoEntrypoint -Destination (Join-Path $LibexecDir "DBAudit") -Force
Copy-Item -LiteralPath (Join-Path $RepoRoot "R") -Destination (Join-Path $LibexecDir "R") -Recurse -Force
Copy-Item -LiteralPath $repoBin -Destination (Join-Path $LibexecDir "bin\\dbAudit") -Force

# Create launchers in UserBinDir
$cmdPath = Join-Path $UserBinDir "dbAudit.cmd"
$shimPath = Join-Path $UserBinDir "dbAudit"

$cmdTemplate = @"
@echo off
setlocal
set "DBAUDIT_HOME=__LIBEXEC__"

where Rscript >nul 2>nul
if %errorlevel%==0 (
  set "RSCRIPT=Rscript"
) else (
  where Rscript.exe >nul 2>nul
  if %errorlevel%==0 (
    set "RSCRIPT=Rscript.exe"
  ) else (
    echo ERROR: Rscript not found in PATH. Install R and try again. 1>&2
    exit /b 1
  )
)

"%RSCRIPT%" "%DBAUDIT_HOME%\\DBAudit" %*
"@

$cmd = $cmdTemplate.Replace('__LIBEXEC__', $LibexecDir)
# Ensure CRLF for .cmd
$cmd = $cmd -replace "`r?`n", "`r`n"

# Write without BOM
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($cmdPath, $cmd, $utf8NoBom)

$shim = @'
#!/usr/bin/env bash
set -Eeuo pipefail
exec "$(dirname "$0")/dbAudit.cmd" "$@"
'@
Write-LFFile -Path $shimPath -Content $shim

# Ensure executability in Git Bash (best-effort)
$bashExe = Resolve-GitBashExe
if ($bashExe) {
    try {
        $binBash = To-GitBashPath -WinPath $UserBinDir
        & $bashExe -lc "chmod +x '$binBash/dbAudit'" | Out-Null
    } catch {}
}

Ok "Created launchers:"
Ok "  $cmdPath"
Ok "  $shimPath"

# Add to User PATH
if (-not $SkipPath) {
    $added = Add-ToUserPath -Dir $UserBinDir
    if ($added) {
        Ok "Ensured User PATH contains: $UserBinDir"
        Warn "Open a NEW terminal so PATH updates are picked up."
    }
}

# Runtime sanity check
$r = Get-Command Rscript -ErrorAction SilentlyContinue
if (-not $r) { $r = Get-Command Rscript.exe -ErrorAction SilentlyContinue }
if ($r) {
    Ok "Rscript: $($r.Source)"
} else {
    Warn "Rscript not found in PATH (dbAudit will not run until R is installed/discoverable)."
}

Info "Verify in a new terminal:"
Info "  dbAudit --help"
