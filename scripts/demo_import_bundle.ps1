# Demo script: build a sample bundle and import it via fpdev --import-bundle
# Usage: Run from repo root or anywhere; this script resolves relative to its own directory

param(
  [string]$RepoRoot = ''
)

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[ OK ] $msg" -ForegroundColor Green }
function Write-Err($msg)  { Write-Host "[ERR ] $msg" -ForegroundColor Red }

# Resolve repo root
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
  $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
  $RepoRoot = Resolve-Path (Join-Path $ScriptDir '..')
}
Set-Location $RepoRoot

$BinExe = Join-Path $RepoRoot 'bin\fpdev.exe'
if (-not (Test-Path $BinExe)) {
  Write-Err "Executable not found: $BinExe"
  Write-Err "Please build with: lazbuild -B --build-mode=Release src\fpdev.lpi"
  exit 2
}

# Prepare demo bundle contents
$DemoDir = Join-Path $RepoRoot 'out\bundle_test'
New-Item -ItemType Directory -Path $DemoDir -Force | Out-Null

# Create a small payload and zip it as a tool archive
$Payload = Join-Path $DemoDir 'payload.txt'
'Sample payload for fpdev bundle test.' | Out-File -Encoding ascii $Payload

$ToolZipName = 'demo-tool-1.0-win64.zip'
$ToolZip = Join-Path $DemoDir $ToolZipName
Compress-Archive -Path $Payload -DestinationPath $ToolZip -Force

# Create sha256 file for the tool zip
$Sha = (Get-FileHash $ToolZip -Algorithm SHA256).Hash
$ShaFile = [System.IO.Path]::ChangeExtension($ToolZip, '.sha256')
$Sha | Out-File -Encoding ascii $ShaFile

# Create the bundle zip containing the tool zip and sha256
$BundleZip = Join-Path $RepoRoot 'out\bundle.zip'
if (Test-Path $BundleZip) { Remove-Item $BundleZip -Force }
Compress-Archive -Path (Join-Path $DemoDir '*') -DestinationPath $BundleZip -Force

Write-Info "Bundle prepared: $BundleZip"
Write-Info "Expecting import of: $ToolZipName (sha256: $Sha)"

# Run import-bundle
$cmd = '"' + $BinExe + '" --import-bundle "' + $BundleZip + '"'
Write-Info "Running: $cmd"
$proc = Start-Process -FilePath $BinExe -ArgumentList @('--import-bundle', $BundleZip) -NoNewWindow -PassThru -Wait
$exit = $proc.ExitCode
Write-Info ("ExitCode: {0}" -f $exit)

# Check cache results
$CacheDir = Join-Path $RepoRoot '.fpdev\cache\toolchain'
$Imported = Join-Path $CacheDir $ToolZipName
if (Test-Path $Imported) {
  $ImportedSha = (Get-FileHash $Imported -Algorithm SHA256).Hash
  if ($ImportedSha -eq $Sha) { Write-Ok "Imported OK: $Imported (sha256 matches)"; exit 0 }
  else { Write-Err "Imported file sha256 mismatch: $ImportedSha <> $Sha"; exit 3 }
} else {
  Write-Err "Imported file not found in cache: $Imported"
  exit 4
}

