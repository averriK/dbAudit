# test-verify.ps1
# Verify that shims and runtimes exist after install.

$bin = Join-Path $env:LOCALAPPDATA "Programs"
$runtime = Join-Path $env:LOCALAPPDATA "Programs\_runtime"
$failed = $false

$checks = @(
    @{ name = "tito shim"; path = (Join-Path $bin "tito") },
    @{ name = "tito.ps1"; path = (Join-Path $bin "tito.ps1") },
    @{ name = "tito.cmd"; path = (Join-Path $bin "tito.cmd") },
    @{ name = "tito manifest"; path = (Join-Path $bin "tito.INSTALL_MANIFEST") },

    @{ name = "oqt shim"; path = (Join-Path $bin "oqt") },
    @{ name = "oqt.ps1"; path = (Join-Path $bin "oqt.ps1") },
    @{ name = "oqt.cmd"; path = (Join-Path $bin "oqt.cmd") },
    @{ name = "oqt manifest"; path = (Join-Path $bin "oqt.INSTALL_MANIFEST") },
    @{ name = "oqt runtime"; path = (Join-Path $runtime "oqt") },

    @{ name = "dbaudit shim"; path = (Join-Path $bin "dbaudit") },
    @{ name = "dbaudit.cmd"; path = (Join-Path $bin "dbaudit.cmd") },
    @{ name = "dbaudit manifest"; path = (Join-Path $bin "dbaudit.INSTALL_MANIFEST") },
    @{ name = "dbaudit runtime"; path = (Join-Path $runtime "dbAudit") }
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
