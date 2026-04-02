param(
  [string]$ExecutablePath = '.\bin\fpdev.exe'
)

function Write-Info($msg) { Write-Host "[SMOKE] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[ OK ] $msg" -ForegroundColor Green }
function Write-Err($msg)  { Write-Host "[FAIL] $msg" -ForegroundColor Red }

if ($ExecutablePath -in @('-h', '--help')) {
  Write-Host 'Usage: scripts/cli_smoke.ps1 [-ExecutablePath .\bin\fpdev.exe]'
  exit 0
}

if (-not (Test-Path $ExecutablePath)) {
  Write-Err "Executable not found: $ExecutablePath"
  exit 2
}

function Invoke-SmokeCommand {
  param(
    [string]$Label,
    [string[]]$Arguments
  )

  Write-Info ("{0}: {1} {2}" -f $Label, $ExecutablePath, ($Arguments -join ' '))
  & $ExecutablePath @Arguments
  if ($LASTEXITCODE -ne 0) {
    Write-Err ("{0} failed with exit code {1}" -f $Label, $LASTEXITCODE)
    exit $LASTEXITCODE
  }
}

Invoke-SmokeCommand -Label 'system version' -Arguments @('system', 'version')
Invoke-SmokeCommand -Label 'system help' -Arguments @('system', 'help')
Invoke-SmokeCommand -Label 'fpc help' -Arguments @('fpc', '--help')
Invoke-SmokeCommand -Label 'fpc list all' -Arguments @('fpc', 'list', '--all')

Write-Ok "CLI smoke passed for $ExecutablePath"
