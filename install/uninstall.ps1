#Requires -Version 5.1
# uninstall.ps1
# dbAudit Uninstaller for Windows
#
# Usage (PowerShell):
#   git clone git@github.com:averriK/dbAudit.git
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\dbAudit\install\uninstall.ps1
#
# Notes:
#   - Removes the runtime + launchers installed by install.ps1.
#   - Does not uninstall R.

[CmdletBinding()]
param(
    # Runtime installation directory
    # Default: %LOCALAPPDATA%\Programs\dbAudit\libexec\dbAudit
    [string]$LibexecDir = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Programs\dbAudit\libexec\dbAudit'),

    # User bin directory to remove launchers from
    # Default: %LOCALAPPDATA%\Programs\dbAudit\bin
    [string]$UserBinDir = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Programs\dbAudit\bin'),

    # Skip removing $UserBinDir from the User PATH
    [switch]$SkipPath
)

$ErrorActionPreference = "Stop"

function Info($msg)  { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Ok($msg)    { Write-Host "[OK]   $msg" -ForegroundColor Green }
function Warn($msg)  { Write-Host "[WARN] $msg" -ForegroundColor Yellow }

function Remove-FromUserPath {
    param([Parameter(Mandatory=$true)][string]$Dir)

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if (-not $userPath) { return $false }

    $needle = $Dir.TrimEnd('\\')
    $parts = $userPath -split ";" | Where-Object { $_ -and $_.Trim() -ne "" }

    $kept = @()
    $removed = $false
    foreach ($p in $parts) {
        if ($p.TrimEnd('\\') -ieq $needle) { $removed = $true; continue }
        $kept += $p
    }

    if (-not $removed) { return $false }

    $newUserPath = ($kept | Select-Object -Unique) -join ";"
    [Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")

    # Refresh current session too (best-effort)
    try {
        $envParts = $env:Path -split ";" | Where-Object { $_ -and $_.Trim() -ne "" }
        $envKept = @()
        foreach ($p in $envParts) {
            if ($p.TrimEnd('\\') -ine $needle) { $envKept += $p }
        }
        $env:Path = ($envKept | Select-Object -Unique) -join ";"
    } catch {}

    return $true
}

Info "dbAudit Uninstaller (Windows / PowerShell)"
Info "Runtime : $LibexecDir"
Info "Bin     : $UserBinDir"

# Remove launchers
$files = @(
    (Join-Path $UserBinDir "dbAudit.cmd"),
    (Join-Path $UserBinDir "dbAudit"),
    # Cleanup from older experiments if present
    (Join-Path $UserBinDir "dbAudit.ps1")
)

foreach ($f in $files) {
    if (Test-Path $f) {
        try {
            Remove-Item -LiteralPath $f -Force
            Ok "Removed: $f"
        } catch {
            Warn "Failed to remove: $f ($_ )"
        }
    }
}

# Remove runtime
if (Test-Path $LibexecDir) {
    try {
        Remove-Item -LiteralPath $LibexecDir -Recurse -Force
        Ok "Removed runtime: $LibexecDir"
    } catch {
        Warn "Failed to remove runtime: $LibexecDir ($_ )"
    }
} else {
    Warn "Runtime not found: $LibexecDir"
}

# Remove bin dir if empty
if (Test-Path $UserBinDir) {
    try {
        $remaining = Get-ChildItem -LiteralPath $UserBinDir -Force -ErrorAction SilentlyContinue
        if (-not $remaining) {
            Remove-Item -LiteralPath $UserBinDir -Force
            Ok "Removed empty bin dir: $UserBinDir"
        }
    } catch {}
}

# Remove from User PATH
if (-not $SkipPath) {
    $removed = Remove-FromUserPath -Dir $UserBinDir
    if ($removed) {
        Ok "Removed from User PATH: $UserBinDir"
        Warn "Open a NEW terminal so PATH updates are picked up."
    } else {
        Ok "User PATH did not contain: $UserBinDir"
    }
}

Ok "Uninstall complete"