# test-installers.ps1
# Uninstall + install for tito, oqt, dbAudit. Leaves all installed at the end.

$toolsRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$repos = @("tito","oqt","dbAudit")
$failed = $false

foreach ($r in $repos) {
    Write-Host "=== $r ==="

    $root = Join-Path $toolsRoot $r
    $un = Join-Path $root "install\uninstall.ps1"
    $in = Join-Path $root "install\install.ps1"

    if (-not (Test-Path -LiteralPath $un)) {
        Write-Host "FAIL: missing $un"
        $failed = $true
        Write-Host ""
        continue
    }
    if (-not (Test-Path -LiteralPath $in)) {
        Write-Host "FAIL: missing $in"
        $failed = $true
        Write-Host ""
        continue
    }

    powershell -NoProfile -ExecutionPolicy Bypass -File $un
    if ($LASTEXITCODE -ne 0) { Write-Host "FAIL: uninstall"; $failed = $true } else { Write-Host "OK: uninstall" }

    powershell -NoProfile -ExecutionPolicy Bypass -File $in -Force
    if ($LASTEXITCODE -ne 0) { Write-Host "FAIL: install"; $failed = $true } else { Write-Host "OK: install" }

    Write-Host ""
}

if ($failed) { exit 1 } else { exit 0 }
