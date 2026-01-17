# test-verify.ps1
# Verify dbAudit shims + runtime exist after install.

$bin = Join-Path $env:LOCALAPPDATA "Programs"
$runtime = Join-Path $env:LOCALAPPDATA "Programs\_runtime\dbAudit"
$version = Join-Path $runtime ".version"
$failed = $false

$checks = @(
    @{ name = "dbaudit shim"; path = (Join-Path $bin "dbaudit") },
    @{ name = "dbaudit.cmd"; path = (Join-Path $bin "dbaudit.cmd") },
    @{ name = "dbaudit manifest"; path = (Join-Path $bin "dbaudit.INSTALL_MANIFEST") },
    @{ name = "dbaudit runtime"; path = $runtime },
    @{ name = "dbaudit version"; path = $version }
)

foreach ($c in $checks) {
    if (Test-Path -LiteralPath $c.path) {
        Write-Host "OK: $($c.name) -> $($c.path)"
    } else {
        Write-Host "FAIL: $($c.name) missing at $($c.path)"
        $failed = $true
    }
}

if ($failed) { exit 1 } else { exit 0 }
