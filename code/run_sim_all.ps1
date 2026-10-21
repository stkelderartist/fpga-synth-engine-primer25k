# Portable entry point; prefer Python 3 on PATH or Windows py launcher.
$ErrorActionPreference = 'Stop'
$python = Get-Command python -ErrorAction SilentlyContinue
if ($python) { & $python.Source (Join-Path $PSScriptRoot 'run_sim.py') @args }
else { & py -3 (Join-Path $PSScriptRoot 'run_sim.py') @args }
exit $LASTEXITCODE
