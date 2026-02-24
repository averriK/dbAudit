# test-installers.ps1
# Uninstall + install for dbAudit. Leaves dbAudit installed at the end.

$repoRoot = Split-Path -Parent $PSScriptRoot
$repoName = Split-Path -Leaf $repoRoot
$failed = $false

Write-Host "=== $repoName ==="

$un = Join-Path $repoRoot "install\uninstall.ps1"
$in = Join-Path $repoRoot "install\install.ps1"

if (-not (Test-Path -LiteralPath $un)) {
    Write-Host "FAIL: missing $un"
    exit 1
}
if (-not (Test-Path -LiteralPath $in)) {
    Write-Host "FAIL: missing $in"
    exit 1
}

powershell -NoProfile -ExecutionPolicy Bypass -File $un
if ($LASTEXITCODE -ne 0) { Write-Host "FAIL: uninstall"; $failed = $true } else { Write-Host "OK: uninstall" }

powershell -NoProfile -ExecutionPolicy Bypass -File $in -Force
if ($LASTEXITCODE -ne 0) { Write-Host "FAIL: install"; $failed = $true } else { Write-Host "OK: install" }

if ($failed) { exit 1 } else { exit 0 }
