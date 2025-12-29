#Requires -Version 5.1
# install.ps1
# Windows installer for dbAudit.
#
# Goals:
#   - Windows-native install (PowerShell-first)
#   - Ensure R (Rscript.exe) is installed and discoverable
#   - Deterministic install layout:
#       * Runtime: %LOCALAPPDATA%\dbAudit\libexec\dbAudit
#       * Shims:   %USERPROFILE%\bin\dbAudit.ps1 + dbAudit.cmd
#   - No .bashrc modifications
#
# Usage (recommended):
#   PowerShell:
#     Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#     .\install\install.ps1 -AutoInstall
#
# Usage (remote, no repo checkout):
#   NOTE: raw.githubusercontent.com returns 404 for private repos.
#   Use a GitHub token with read access and download via the GitHub API.
#
#   PowerShell:
#     Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#     $token = Read-Host "GitHub token (read access to averriK/dbAudit)"
#     $headers = @{ Authorization = "Bearer $token"; Accept = "application/vnd.github.raw" }
#
#     $installer = Join-Path $env:TEMP "install-dbAudit.ps1"
#     iwr -UseBasicParsing -Headers $headers "https://api.github.com/repos/averriK/dbAudit/contents/install/install.ps1?ref=main" -OutFile $installer
#
#     & $installer -AutoInstall -GitHubToken $token
#     Remove-Item -Force $installer

[CmdletBinding()]
param(
    # Automatically install missing dependencies (R) and set up shims
    [switch]$AutoInstall,
    # Do not prompt before replacing an existing runtime directory
    [switch]$Force,
    # Skip verification steps (Rscript --version, setup.R)
    [switch]$SkipVerification,

    # GitHub token (required for remote install when the repo is private)
    # If omitted, the installer will read $env:DBAUDIT_GITHUB_TOKEN.
    [string]$GitHubToken,

    # Repo root (defaults to parent of this script directory)
    [string]$RepoRoot,

    # Where to install launchers/shims
    [string]$UserBinDir = "$env:USERPROFILE\bin",

    # Where to install the runtime tree
    [string]$LibexecDir = "$env:LOCALAPPDATA\dbAudit\libexec\dbAudit"
)

$ErrorActionPreference = 'Stop'

function Info  { param([string]$Msg) Write-Host "[INFO]  $Msg" -ForegroundColor Cyan }
function Ok    { param([string]$Msg) Write-Host "[OK]    $Msg" -ForegroundColor Green }
function Warn  { param([string]$Msg) Write-Host "[WARN]  $Msg" -ForegroundColor Yellow }
function Fail  { param([string]$Msg) Write-Host "[ERROR] $Msg" -ForegroundColor Red; exit 1 }

if (-not $RepoRoot -or $RepoRoot.Trim() -eq "") {
    try {
        $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot ".." )).Path
    } catch {
        $RepoRoot = ""
    }
}

# Allow passing token via env var (useful for automation)
if (-not $GitHubToken -or $GitHubToken.Trim() -eq "") {
    $GitHubToken = $env:DBAUDIT_GITHUB_TOKEN
}

function Get-GitHubHeaders {
    param([string]$Token)

    $headers = @{
        "User-Agent" = "dbAudit-installer"
        "Accept"     = "application/vnd.github+json"
    }

    if ($Token -and $Token.Trim() -ne "") {
        $headers["Authorization"] = "Bearer $Token"
    }

    return $headers
}

function Add-ToUserPath {
    param([Parameter(Mandatory=$true)][string]$Dir)

    if (-not $Dir -or $Dir.Trim() -eq "") { return }
    if (-not (Test-Path $Dir)) { return }

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $parts = @()
    if ($userPath) {
        $parts = $userPath -split ";" | Where-Object { $_ -and $_.Trim() -ne "" }
    }

    if ($parts -contains $Dir) {
        return
    }

    $newUserPath = if ($userPath -and $userPath.Trim().Length -gt 0) { $userPath.TrimEnd(';') + ";" + $Dir } else { $Dir }
    [Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")

    # Refresh current process PATH too
    if ($env:Path -notlike "*$Dir*") {
        $env:Path += ";" + $Dir
    }
}

function Ensure-UserBin {
    param([Parameter(Mandatory=$true)][string]$BinDir)

    if (-not (Test-Path $BinDir)) {
        New-Item -ItemType Directory -Path $BinDir | Out-Null
    }
    Add-ToUserPath -Dir $BinDir
}

function Resolve-RscriptFromInstalls {
    $roots = @(
        "C:\\Program Files\\R",
        "C:\\R"
    )

    foreach ($root in $roots) {
        if (-not (Test-Path $root)) { continue }

        $dirs = Get-ChildItem $root -Directory -Filter "R-*" -ErrorAction SilentlyContinue
        if (-not $dirs) { continue }

        $candidates = @()
        foreach ($d in $dirs) {
            $verText = $d.Name.Substring(2)
            $ver = $null
            try { $ver = [version]$verText } catch { $ver = $null }
            $candidates += [pscustomobject]@{ Path = $d.FullName; Version = $ver }
        }

        $sorted = $candidates | Sort-Object -Property Version -Descending
        foreach ($c in $sorted) {
            $p1 = Join-Path $c.Path "bin\\x64\\Rscript.exe"
            $p2 = Join-Path $c.Path "bin\\Rscript.exe"
            $p3 = Join-Path $c.Path "bin\\i386\\Rscript.exe"

            if (Test-Path $p1) { return $p1 }
            if (Test-Path $p2) { return $p2 }
            if (Test-Path $p3) { return $p3 }
        }
    }

    return $null
}

function Install-R {
    # Best-effort: try winget first, then chocolatey.
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Info "Installing R via winget (RProject.R)..."
        $null = & winget install --id RProject.R -e --silent --accept-package-agreements --accept-source-agreements 2>&1
        if ($LASTEXITCODE -eq 0) {
            Ok "winget install completed"
            return $true
        }
        Warn "winget install RProject.R failed (exit code $LASTEXITCODE)"
    }

    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Info "Installing R via Chocolatey (r.project)..."
        $null = & choco install r.project -y 2>&1
        if ($LASTEXITCODE -eq 0) {
            Ok "choco install completed"
            return $true
        }
        Warn "choco install r.project failed (exit code $LASTEXITCODE)"
    }

    return $false
}

function Ensure-Rscript {
    $cmd = Get-Command Rscript -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    Info "Rscript not found in PATH; searching for an existing R installation..."
    $found = Resolve-RscriptFromInstalls

    if (-not $found -and $AutoInstall) {
        Warn "Rscript.exe not found in common install locations. Attempting to install R..."
        $ok = Install-R
        if (-not $ok) {
            Fail "Could not install R automatically. Install R manually, then rerun this installer."
        }
        $found = Resolve-RscriptFromInstalls
    }

    if (-not $found) {
        Fail "Rscript.exe not found. Install R for Windows and rerun this installer."
    }

    $rDir = Split-Path $found
    Add-ToUserPath -Dir $rDir

    # Refresh command lookup
    $cmd2 = Get-Command Rscript -ErrorAction SilentlyContinue
    if (-not $cmd2) {
        Warn "Rscript was found at '$found' but is still not discoverable via PATH in this PowerShell session."
        Warn "Close and reopen PowerShell to refresh PATH."
    }

    return $found
}

function Resolve-SourceRoot {
    param(
        [string]$LocalRepoRoot,
        [string]$Token
    )

    if ($LocalRepoRoot -and (Test-Path (Join-Path $LocalRepoRoot "DBAudit")) -and (Test-Path (Join-Path $LocalRepoRoot "R")) -and (Test-Path (Join-Path $LocalRepoRoot "bin\dbAudit"))) {
        Info "Local checkout detected at: $LocalRepoRoot"
        return $LocalRepoRoot
    }

    # Remote mode: download zipball for main.
    # For private repos this requires a token.
    $repo = "averriK/dbAudit"
    $ref = "main"
    $zipUrl = "https://api.github.com/repos/$repo/zipball/$ref"

    $tmp = Join-Path $env:TEMP ("dbAudit-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tmp | Out-Null

    $zipPath = Join-Path $tmp "dbAudit-main.zip"

    $headers = Get-GitHubHeaders -Token $Token
    Info "Downloading $zipUrl"

    try {
        Invoke-WebRequest -Headers $headers -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
    } catch {
        if (-not $Token -or $Token.Trim() -eq "") {
            Fail "Failed to download dbAudit. If this repo is private, provide -GitHubToken or set DBAUDIT_GITHUB_TOKEN."
        }
        Fail "Failed to download dbAudit from GitHub API: $_"
    }

    Info "Extracting archive..."
    Expand-Archive -Path $zipPath -DestinationPath $tmp -Force

    # GitHub zip typically extracts as <repo>-<hash>
    $candidates = Get-ChildItem $tmp -Directory | Where-Object { Test-Path (Join-Path $_.FullName "DBAudit") }
    $src = $null
    if ($candidates -and $candidates.Count -ge 1) {
        $src = $candidates[0].FullName
    }

    if (-not $src) {
        Fail "Downloaded source tree did not contain expected files (DBAudit, R/, bin/dbAudit)."
    }

    Info "Remote source prepared at: $src"
    return $src
}

function Install-Runtime {
    param(
        [Parameter(Mandatory=$true)][string]$SrcRoot,
        [Parameter(Mandatory=$true)][string]$DestRoot
    )

    if (Test-Path $DestRoot) {
        if (-not $Force) {
            Warn "Existing runtime directory found at $DestRoot – it will be replaced."
        }
        Remove-Item -Recurse -Force $DestRoot
    }

    New-Item -ItemType Directory -Path $DestRoot | Out-Null

    Copy-Item (Join-Path $SrcRoot "DBAudit") (Join-Path $DestRoot "DBAudit") -Force
    Copy-Item (Join-Path $SrcRoot "R") (Join-Path $DestRoot "R") -Recurse -Force
    Copy-Item (Join-Path $SrcRoot "bin") (Join-Path $DestRoot "bin") -Recurse -Force
}

function Write-DbAuditShims {
    param(
        [Parameter(Mandatory=$true)][string]$BinDir,
        [Parameter(Mandatory=$true)][string]$RuntimeRoot,
        [Parameter(Mandatory=$true)][string]$RscriptPath
    )

    Ensure-UserBin -BinDir $BinDir

    $ps1Path = Join-Path $BinDir "dbAudit.ps1"
    $cmdPath = Join-Path $BinDir "dbAudit.cmd"

    $ps1 = @"
param(
    [Parameter(ValueFromRemainingArguments = `$true)]
    [string[]] `$Args
)

`$ErrorActionPreference = 'Stop'

`$runtime = '$RuntimeRoot'
`$rscript = '$RscriptPath'

if (-not (Test-Path `$runtime)) {
  Write-Host "[ERROR] dbAudit runtime not found at: `$runtime" -ForegroundColor Red
  exit 1
}

if (-not (Test-Path `$rscript)) {
  Write-Host "[ERROR] Rscript.exe not found at: `$rscript" -ForegroundColor Red
  exit 1
}

`$env:DBAUDIT_HOME = `$runtime

& `$rscript (Join-Path `$runtime 'DBAudit') @Args
exit `$LASTEXITCODE
"@

    Set-Content -Path $ps1Path -Value $ps1 -Encoding UTF8

    $cmd = @'
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0dbAudit.ps1" %*
exit /b %errorlevel%
'@
    # Ensure CRLF for .cmd
    $cmd = $cmd -replace "`r?`n", "`r`n"
    [System.IO.File]::WriteAllText($cmdPath, $cmd, [System.Text.Encoding]::ASCII)

    Ok "Shims installed in $BinDir"
}

# ---------------------------
# Main

Info "dbAudit Windows installer (PowerShell)"

Info "Install targets:"
Info "  Runtime: $LibexecDir"
Info "  Shims  : $UserBinDir (dbAudit.ps1 + dbAudit.cmd)"

$rscript = Ensure-Rscript

if (-not $SkipVerification) {
    try {
        $v = & $rscript --version 2>&1 | Select-Object -First 1
        Ok "Rscript detected: $v"
    } catch {
        Ok "Rscript detected: $rscript"
    }
}

$srcRoot = Resolve-SourceRoot -LocalRepoRoot $RepoRoot -Token $GitHubToken

Info "Installing runtime..."
Install-Runtime -SrcRoot $srcRoot -DestRoot $LibexecDir
Ok "Runtime installed"

Info "Installing shims..."
Write-DbAuditShims -BinDir $UserBinDir -RuntimeRoot $LibexecDir -RscriptPath $rscript

if (-not $SkipVerification) {
    Info "Installing / verifying R package dependencies (data.table, stringr, lubridate)..."
    try {
        & $rscript -e "source('$LibexecDir\\R\\setup.R'); cat('OK: R dependencies installed and loaded.\n')" | Out-Null
        Ok "R dependencies OK"
    } catch {
        Warn "R dependency installation failed: $_"
        Warn "You can rerun: dbAudit --help (it will attempt to install packages again)"
    }
}

Info "Next steps:"
Info "  1) Close and reopen PowerShell (or Git Bash) so PATH updates are picked up."
Info "  2) Verify: dbAudit --help"

Info "Documentation:"
Info "  https://averrik.github.io/dbAudit/"
