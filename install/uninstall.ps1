#Requires -Version 5.1
# uninstall.ps1
# Windows uninstaller for dbAudit.
#
# Removes:
#   - %LOCALAPPDATA%\dbAudit\libexec\dbAudit
#   - %USERPROFILE%\bin\dbAudit.ps1
#   - %USERPROFILE%\bin\dbAudit.cmd
#
# Notes:
#   - This script does NOT remove PATH entries (User PATH) automatically.
#     Leaving %USERPROFILE%\bin and the R bin directory on PATH is usually desirable.

[CmdletBinding()]
param(
    [string]$UserBinDir = "$env:USERPROFILE\bin",
    [string]$LibexecDir = "$env:LOCALAPPDATA\dbAudit\libexec\dbAudit",
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Info  { param([string]$Msg) Write-Host "[INFO]  $Msg" -ForegroundColor Cyan }
function Ok    { param([string]$Msg) Write-Host "[OK]    $Msg" -ForegroundColor Green }
function Warn  { param([string]$Msg) Write-Host "[WARN]  $Msg" -ForegroundColor Yellow }

Info "dbAudit Windows uninstaller"

$ps1Path = Join-Path $UserBinDir "dbAudit.ps1"
$cmdPath = Join-Path $UserBinDir "dbAudit.cmd"

foreach ($p in @($ps1Path, $cmdPath)) {
    if (Test-Path $p) {
        Info "Removing $p"
        Remove-Item -Force $p
        Ok "Removed $p"
    } else {
        Warn "Not found: $p"
    }
}

if (Test-Path $LibexecDir) {
    Info "Removing runtime directory: $LibexecDir"
    Remove-Item -Recurse -Force $LibexecDir
    Ok "Removed $LibexecDir"
} else {
    Warn "Not found: $LibexecDir"
}

Ok "Uninstall complete"

Info "If 'dbAudit' still resolves in an open shell, close and reopen the shell to refresh PATH."