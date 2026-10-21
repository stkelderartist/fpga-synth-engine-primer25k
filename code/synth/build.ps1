#Requires -Version 5.1
# Tang Primer 25K + Dock. Default device is current NC production part, version A.
param(
    [ValidateSet('tone_test','synth_board12')]
    [string]$Target = 'synth_board12',
    [string]$GowinHome = $env:GOWINHOME,
    [ValidateSet('GW5A-LV25MG121NC1/I0','GW5A-LV25MG121NES')]
    [string]$Device = 'GW5A-LV25MG121NC1/I0',
    [switch]$GenerateOnly
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$boardDir = Join-Path $repoRoot 'code/boards/tang_primer25k'
$buildDir = Join-Path $repoRoot "build/tang_primer25k/$Target"
[void](New-Item -ItemType Directory -Path $buildDir -Force)
$project = [xml](Get-Content -LiteralPath (Join-Path $boardDir "$Target.gprj") -Raw)
$top = if ($Target -eq 'tone_test') { 'primer25k_tone_top' } else { 'primer25k_top' }
$lines = @(
    "set_device $Device",
    "set_option -top_module $top",
    "set_option -output_base_name $Target",
    'set_option -use_cpu_as_gpio 1',
    'set_option -use_sspi_as_gpio 1',
    'set_option -use_ready_as_gpio 1'
)
foreach ($f in $project.Project.FileList.File) {
    $full = [IO.Path]::GetFullPath((Join-Path $boardDir $f.path))
    if (-not (Test-Path -LiteralPath $full)) { throw "Missing source: $full" }
    $lines += 'add_file {' + $full.Replace('\','/') + '}'
}
$lines += 'run all'
$tclFile = Join-Path $buildDir "$Target.tcl"
# PS 5.1 UTF8 adds a BOM; use .NET to produce BOM-free UTF-8.
[IO.File]::WriteAllLines($tclFile, $lines, (New-Object Text.UTF8Encoding($false)))
Write-Host "Generated $tclFile"
if ($GenerateOnly) { exit 0 }
$gw = if ($GowinHome) { Join-Path $GowinHome 'IDE/bin/gw_sh.exe' } else { $null }
if (-not $gw -or -not (Test-Path -LiteralPath $gw)) {
    $found = Get-Command gw_sh.exe -ErrorAction SilentlyContinue
    if ($found) { $gw = $found.Source }
    else { throw 'Set GOWINHOME or pass -GowinHome pointing to the Gowin installation.' }
}
$started = [DateTime]::UtcNow
Push-Location $buildDir
try {
    & $gw $tclFile
    if ($LASTEXITCODE -ne 0) { throw "Gowin failed (exit $LASTEXITCODE)" }
} finally { Pop-Location }
$fs = Join-Path $buildDir "impl/pnr/$Target.fs"
if (-not (Test-Path -LiteralPath $fs)) { throw "No bitstream generated: $fs" }
if ((Get-Item -LiteralPath $fs).LastWriteTimeUtc -lt $started) {
    throw 'Bitstream is stale; inspect synthesis and P&R diagnostics.'
}
Write-Host "Bitstream: $fs"
Write-Host 'Review timing reports, then use Gowin Programmer with your actual device/flash selection.'
