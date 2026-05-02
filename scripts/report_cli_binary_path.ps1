param(
  [Parameter(Mandatory = $true)]
  [string]$ExecutablePath,

  [Parameter(Mandatory = $true)]
  [string]$OutputFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ExecutablePath)) {
  throw 'ExecutablePath must not be empty'
}

$OutputDir = Split-Path -Parent $OutputFile
if (-not [string]::IsNullOrWhiteSpace($OutputDir)) {
  New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
}

Set-Content -Path $OutputFile -Value $ExecutablePath -Encoding ascii
Write-Host "[INFO] Reported CLI binary path: $ExecutablePath"
