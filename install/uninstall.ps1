#Requires -Version 5.1
# uninstall.ps1
# dbaudit Uninstaller for Windows
#
# Usage (PowerShell):
#   git clone git@github.com:averriK/dbAudit.git
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\dbAudit\install\uninstall.ps1
#
# Notes:
#   - Removes the runtime + launchers installed by install.ps1.
#   - Does not uninstall R.
#   - Use -RemoveUserBinFromPath to remove the shim directory from User PATH.

[CmdletBinding()]
param(
    # Runtime installation directory
    # Default: %LOCALAPPDATA%\Programs\_runtime\dbAudit
    [string]$LibexecDir = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Programs\_runtime\dbAudit'),

    # User bin directory to remove launchers from
    # Default: %LOCALAPPDATA%\Programs
    [string]$UserBinDir = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Programs'),

    # Remove the shim directory from the User PATH (opt-in)
    [switch]$RemoveUserBinFromPath
)

$ErrorActionPreference = "Stop"

function Info($msg)  { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Ok($msg)    { Write-Host "[OK]   $msg" -ForegroundColor Green }
function Warn($msg)  { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Read-InstallManifest {
    param([Parameter(Mandatory=$true)][string]$Path)
    $info = @{
        files = @()
        dirs = @()
        props = @{}
    }
    Get-Content -LiteralPath $Path | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') {
            $k = $matches[1]
            $v = $matches[2]
            if ($k -eq 'file') { $info.files += $v }
            elseif ($k -eq 'dir') { $info.dirs += $v }
            else { $info.props[$k] = $v }
        }
    }
    return $info
}

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

Info "dbaudit Uninstaller (Windows / PowerShell)"
Info "Runtime : $LibexecDir"
Info "Bin     : $UserBinDir"
$binDir = $UserBinDir
$binDirSource = 'param/default'
if (-not $PSBoundParameters.ContainsKey('UserBinDir')) {
    $cmd = Get-Command dbaudit -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) {
        $binDir = Split-Path $cmd.Source -Parent
        $binDirSource = 'from PATH (Get-Command dbaudit)'
    }
}
$UserBinDir = $binDir

$manifestPath = Join-Path $UserBinDir "dbaudit.INSTALL_MANIFEST"
$manifestInfo = $null

$versionFile = Join-Path $LibexecDir ".version"
$pathAdded = $false
$cmdPath = $null
$shimPath = $null
if (Test-Path $manifestPath) {
    $manifestInfo = Read-InstallManifest -Path $manifestPath
    if ($manifestInfo.props.ContainsKey("libexec_dir") -and $manifestInfo.props["libexec_dir"]) { $LibexecDir = $manifestInfo.props["libexec_dir"] }
    if ($manifestInfo.props.ContainsKey("bin_dir") -and $manifestInfo.props["bin_dir"]) { $UserBinDir = $manifestInfo.props["bin_dir"] }
    if ($manifestInfo.props.ContainsKey("path_added") -and $manifestInfo.props["path_added"]) {
        $pathAdded = $manifestInfo.props["path_added"] -ieq "true"
    }
} elseif (Test-Path $versionFile) {
    $info = @{}
    Get-Content -LiteralPath $versionFile | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') { $info[$matches[1]] = $matches[2] }
    }
    if ($info.ContainsKey("libexec_dir") -and $info["libexec_dir"]) { $LibexecDir = $info["libexec_dir"] }
    if ($info.ContainsKey("bin_dir") -and $info["bin_dir"]) { $UserBinDir = $info["bin_dir"] }
    if ($info.ContainsKey("cmd_path") -and $info["cmd_path"]) { $cmdPath = $info["cmd_path"] }
    if ($info.ContainsKey("shim_path") -and $info["shim_path"]) { $shimPath = $info["shim_path"] }
    if ($info.ContainsKey("path_added") -and $info["path_added"]) {
        $pathAdded = $info["path_added"] -ieq "true"
    }
}

# Remove launchers installed by this installer
if ($manifestInfo) {
    foreach ($p in $manifestInfo.files) {
        if (Test-Path $p) {
            try {
                Remove-Item -LiteralPath $p -Force
                Ok "Removed: $p"
            } catch {
                Warn "Failed to remove: $p ($_ )"
            }
        }
    }
    foreach ($d in $manifestInfo.dirs) {
        if ($d -and (Test-Path $d)) {
            try {
                Remove-Item -LiteralPath $d -Recurse -Force
                Ok "Removed dir: $d"
            } catch {
                Warn "Failed to remove dir: $d ($_ )"
            }
        }
    }
} else {
    $files = @(
        $(if ($cmdPath) { $cmdPath } else { Join-Path $UserBinDir "dbaudit.cmd" }),
        $(if ($shimPath) { $shimPath } else { Join-Path $UserBinDir "dbaudit" })
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
}

# Remove runtime (only when no manifest was used)
if (-not $manifestInfo) {
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
}

# Remove from User PATH only if installer added it and user requested removal
if ($RemoveUserBinFromPath -and $pathAdded) {
    $removed = Remove-FromUserPath -Dir $UserBinDir
    if ($removed) {
        Ok "Removed from User PATH: $UserBinDir"
        Warn "Open a NEW terminal so PATH updates are picked up."
    } else {
        Ok "User PATH did not contain: $UserBinDir"
    }
}


Ok "Uninstall complete"
