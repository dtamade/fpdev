param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('windows-x64', 'macos-x64', 'macos-arm64')]
  [string]$Lane,

  [Parameter(Mandatory = $true)]
  [string]$ExecutablePath,

  [Parameter(Mandatory = $true)]
  [string]$OutputDir
)

function Write-Fail($Message) {
  Write-Host "[FAIL] $Message" -ForegroundColor Red
}

$TranscriptPath = Join-Path $OutputDir ("{0}-owner-smoke.txt" -f $Lane)
$SmokeScript = Join-Path $PSScriptRoot 'cli_smoke.ps1'

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

Start-Transcript -Path $TranscriptPath -Force | Out-Null
try {
  & pwsh -NoProfile -File $SmokeScript -ExecutablePath $ExecutablePath
  $ExitCode = $LASTEXITCODE
}
finally {
  try {
    Stop-Transcript | Out-Null
  }
  catch {
  }
}

if ($ExitCode -ne 0) {
  Write-Fail ("owner smoke failed for {0}; transcript preserved at {1}" -f $Lane, $TranscriptPath)
  exit $ExitCode
}

Write-Host ("Recorded owner smoke transcript: {0}" -f $TranscriptPath)
