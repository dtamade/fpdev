# Demo: ensure local FPC source ZIP into sandbox (.fpdev)
# Usage: Run from repo root (or provide -RepoRoot); requires PowerShell 5+

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

# Prepare an FPC source zip from local tree
$SrcDir = Join-Path $RepoRoot 'sources\fpc\fpc-3.2.2'
if (-not (Test-Path $SrcDir)) {
  Write-Err "Source dir not found: $SrcDir"
  Write-Err "Please ensure sources\\fpc\\fpc-3.2.2 exists (or edit this script to another version)"
  exit 3
}

$OutDir = Join-Path $RepoRoot 'out'
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
$ZipPath = Join-Path $OutDir 'fpc-src-3.2.2.zip'
if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }

Write-Info "Zipping: $SrcDir -> $ZipPath"
Compress-Archive -Path (Join-Path $SrcDir '*') -DestinationPath $ZipPath -Force

$Sha = (Get-FileHash $ZipPath -Algorithm SHA256).Hash
Write-Info "SHA-256: $Sha"

# Ensure source into sandbox using CLI
$Args = @('system','toolchain','ensure-source','fpc-src','3.2.2','--local', $ZipPath, '--sha256', $Sha, '--strict')
Write-Info ("Running: {0} {1}" -f $BinExe, ($Args -join ' '))
$proc = Start-Process -FilePath $BinExe -ArgumentList $Args -NoNewWindow -PassThru -Wait
$exit = $proc.ExitCode
Write-Info ("ExitCode: {0}" -f $exit)
if ($exit -ne 0) { Write-Err 'Ensure source failed'; exit $exit }

# Verify sandbox path
$SandboxPath = Join-Path $RepoRoot '.fpdev\sandbox\sources\fpc-src\3.2.2'
$CompilerDir = Join-Path $SandboxPath 'compiler'
$RtlDir = Join-Path $SandboxPath 'rtl'
$PkgsDir = Join-Path $SandboxPath 'packages'
if ((Test-Path $CompilerDir) -and (Test-Path $RtlDir) -and (Test-Path $PkgsDir)) {
  Write-Ok "Source ready: $SandboxPath"
  exit 0
} else {
  Write-Err "Structure check failed under: $SandboxPath"
  exit 4
}
