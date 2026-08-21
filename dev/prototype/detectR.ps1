# detectR.ps1 — report every R installation this machine has.
#
# Detection only: no installation, no PATH change, no file written
# outside the optional -Json report.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\detectR.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\detectR.ps1 -Json report.json
#
# On Windows an installation is a REGISTRY FACT: the CRAN installer
# writes SOFTWARE\R-core\{R,R64,R32} with InstallPath and Current
# Version, per machine or per user. The PATH is incidental — R does not
# add itself to it — so PATH presence proves nothing either way.

param([string]$Json)

$ErrorActionPreference = "SilentlyContinue"

$rows = New-Object System.Collections.ArrayList

function Add-Candidate($path, $source, $regVersion) {
    if (-not $path) { return }
    if (-not (Test-Path -LiteralPath $path)) { return }
    $full = (Resolve-Path -LiteralPath $path).Path
    [void]$rows.Add([pscustomobject]@{
        Rscript     = $full
        Source      = $source
        RegVersion  = $regVersion
        Version     = $null
        RHome       = $null
        Arch        = $null
        OnPath      = $false
    })
}

function Add-FromInstallPath($installPath, $source, $regVersion) {
    if (-not $installPath) { return }
    foreach ($rel in @("bin\x64\Rscript.exe", "bin\i386\Rscript.exe", "bin\Rscript.exe")) {
        Add-Candidate (Join-Path $installPath $rel) $source $regVersion
    }
}

# ---- 1. The registry: the record of what is installed -----------------
foreach ($hive in @("HKLM:", "HKCU:")) {
    foreach ($branch in @("SOFTWARE\R-core", "SOFTWARE\WOW6432Node\R-core")) {
        foreach ($flavour in @("R", "R64", "R32")) {
            $key = "$hive\$branch\$flavour"
            if (-not (Test-Path $key)) { continue }

            $props = Get-ItemProperty -LiteralPath $key
            Add-FromInstallPath $props.InstallPath "registry $key" $props.'Current Version'

            # Each installed version keeps its own subkey; a machine with
            # several versions shows them all here.
            foreach ($sub in Get-ChildItem -LiteralPath $key) {
                $sp = Get-ItemProperty -LiteralPath $sub.PSPath
                Add-FromInstallPath $sp.InstallPath "registry $key\$($sub.PSChildName)" $sub.PSChildName
            }
        }
    }
}

# ---- 2. The PATH: convenience, not evidence of installation ----------
foreach ($n in @("Rscript", "Rscript.exe")) {
    foreach ($c in (Get-Command $n -All)) {
        if ($c.Source) { Add-Candidate $c.Source "PATH" $null }
    }
}

# ---- 3. Unregistered trees: portable copies, manual extractions ------
foreach ($base in @(
    (Join-Path $env:ProgramFiles "R"),
    (Join-Path ${env:ProgramFiles(x86)} "R"),
    (Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "Programs\R")
)) {
    if (-not $base -or -not (Test-Path -LiteralPath $base)) { continue }
    foreach ($d in Get-ChildItem -LiteralPath $base -Directory) {
        Add-FromInstallPath $d.FullName "filesystem $($d.FullName)" $null
    }
}

# ---- Interrogate each binary: the version it REPORTS, not the one a
# ---- folder name or a registry value claims --------------------------
$onPath = @()
foreach ($n in @("Rscript", "Rscript.exe")) {
    foreach ($c in (Get-Command $n -All)) { if ($c.Source) { $onPath += (Resolve-Path -LiteralPath $c.Source).Path } }
}

foreach ($r in $rows) {
    $out = & $r.Rscript --version 2>&1 | Out-String
    if ($out -match "version (\d+\.\d+\.\d+)") { $r.Version = $matches[1] }
    elseif ($out -match "version (\d+\.\d+)") { $r.Version = $matches[1] }
    $r.RHome = (& $r.Rscript -e "cat(R.home())" 2>&1 | Out-String).Trim()
    $r.Arch  = (& $r.Rscript -e "cat(R.version[['arch']])" 2>&1 | Out-String).Trim()
    $r.OnPath = $onPath -contains $r.Rscript
}

# ---- Collapse to installations: several paths and registry keys can
# ---- describe ONE install; R.home() is the identity ------------------
$installs = @()
foreach ($g in ($rows | Where-Object { $_.RHome } | Group-Object RHome)) {
    $installs += [pscustomobject]@{
        RHome    = $g.Name
        Version  = ($g.Group | Select-Object -First 1).Version
        Arch     = (($g.Group | ForEach-Object { $_.Arch } | Select-Object -Unique) -join ",")
        OnPath   = [bool]($g.Group | Where-Object { $_.OnPath })
        Rscripts = @($g.Group | ForEach-Object { $_.Rscript } | Select-Object -Unique)
        Sources  = @($g.Group | ForEach-Object { $_.Source } | Select-Object -Unique)
    }
}

$unreadable = @($rows | Where-Object { -not $_.RHome })

Write-Host ""
Write-Host "R installations found: $($installs.Count)"
Write-Host ""
foreach ($i in $installs) {
    Write-Host ("  version {0} [{1}]  on PATH: {2}" -f $i.Version, $i.Arch, $i.OnPath)
    Write-Host ("    R_HOME : {0}" -f $i.RHome)
    foreach ($p in $i.Rscripts) { Write-Host ("    Rscript: {0}" -f $p) }
    foreach ($s in $i.Sources)  { Write-Host ("    seen by: {0}" -f $s) }
    Write-Host ""
}
if ($unreadable.Count -gt 0) {
    Write-Host "Paths that exist but did not answer --version:"
    foreach ($u in $unreadable) { Write-Host ("  {0}  ({1})" -f $u.Rscript, $u.Source) }
    Write-Host ""
}

$usable = @($installs | Where-Object { $_.Version -and ([version]$_.Version) -ge ([version]"4.1.0") })
Write-Host ("Usable by dbaudit (>= 4.1.0): {0}" -f $usable.Count)
if ($usable.Count -gt 0 -and -not ($usable | Where-Object { $_.OnPath })) {
    Write-Host "R is installed but absent from the PATH: dbaudit's current launcher would not find it."
}
Write-Host ""

if ($Json) {
    $report = [pscustomobject]@{
        generated   = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss UTC")
        computer    = $env:COMPUTERNAME
        installs    = $installs
        unreadable  = $unreadable
        pathRscript = $onPath
    }
    $report | ConvertTo-Json -Depth 6 | Out-File -FilePath $Json -Encoding utf8
    Write-Host "Report written: $Json"
}
