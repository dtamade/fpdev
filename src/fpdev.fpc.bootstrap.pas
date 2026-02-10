unit fpdev.fpc.bootstrap;

{
================================================================================
  fpdev.fpc.bootstrap - FPC Bootstrap Compiler Management
================================================================================

  Provides bootstrap compiler detection and management:
  - DetectPlatformArch: Detect current platform and architecture
  - FindSystemFPC: Find system-installed FPC compiler
  - GetRequiredBootstrapVersion: Determine required bootstrap version
  - IsCompatibleBootstrap: Check if compiler is compatible for bootstrapping

  Extracted from fpdev.fpc.source.pas to reduce file size and improve modularity.

  Author: FPDev Team
================================================================================
}

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes;

type
  { TPlatformInfo - Platform and architecture information }
  TPlatformInfo = record
    Platform: string;      // 'Win64', 'Linux', 'macOS'
    Architecture: string;  // 'x86_64-win64', 'x86_64-linux', 'aarch64-darwin', etc.
  end;

  { TBootstrapManager - Bootstrap compiler management }
  TBootstrapManager = class
  private
    FSourceRoot: string;
  public
    constructor Create(const ASourceRoot: string);

    { Detect current platform and architecture }
    function DetectPlatformArch: TPlatformInfo;

    { Find system-installed FPC compiler path }
    function FindSystemFPC: string;

    { Determine required bootstrap version for target version }
    function GetRequiredBootstrapVersion(const ATargetVersion: string): string;

    { Get bootstrap compiler installation path }
    function GetBootstrapPath(const AVersion: string): string;

    { Check if compiler is compatible for bootstrapping }
    function IsCompatibleBootstrap(const ACompilerPath, ARequiredVersion: string): Boolean;

    { Get bootstrap download URL (deprecated - use fpdev-repo) }
    function GetBootstrapDownloadURL(const AVersion: string): string;

    property SourceRoot: string read FSourceRoot write FSourceRoot;
  end;

implementation

uses
  fpdev.utils.process;

{ TBootstrapManager }

constructor TBootstrapManager.Create(const ASourceRoot: string);
begin
  inherited Create;
  FSourceRoot := ASourceRoot;
end;

function TBootstrapManager.DetectPlatformArch: TPlatformInfo;
begin
  // Initialize result
  Result.Platform := '';
  Result.Architecture := '';

  // Detect platform
  {$IFDEF MSWINDOWS}
    {$IFDEF CPU64}
    Result.Platform := 'Win64';
    Result.Architecture := 'x86_64-win64';
    {$ELSE}
    Result.Platform := 'Win32';
    Result.Architecture := 'i386-win32';
    {$ENDIF}
  {$ENDIF}

  {$IFDEF LINUX}
    {$IFDEF CPU64}
    Result.Platform := 'Linux';
    Result.Architecture := 'x86_64-linux';
    {$ELSE}
    Result.Platform := 'Linux';
    Result.Architecture := 'i386-linux';
    {$ENDIF}
  {$ENDIF}

  {$IFDEF DARWIN}
    {$IFDEF CPUAARCH64}
    Result.Platform := 'macOS';
    Result.Architecture := 'aarch64-darwin';
    {$ELSE}
    Result.Platform := 'macOS';
    Result.Architecture := 'x86_64-darwin';
    {$ENDIF}
  {$ENDIF}
end;

function TBootstrapManager.FindSystemFPC: string;
var
  LResult: TProcessResult;
begin
  Result := '';
  // Try to find system FPC compiler
  LResult := TProcessExecutor.Execute('fpc', ['-v'], '');
  if LResult.Success then
    Result := 'fpc'; // System FPC available
end;

function TBootstrapManager.GetRequiredBootstrapVersion(const ATargetVersion: string): string;
begin
  // Based on FPCUpDeluxe logic: determine required bootstrap version
  if (ATargetVersion = 'main') or (ATargetVersion = '3.3.1') then
    Result := '3.2.2'
  else if (ATargetVersion = '3.2.2') or (ATargetVersion = '3.2.0') then
    Result := '3.0.4'
  else if (ATargetVersion = '3.0.4') or (ATargetVersion = '3.0.2') then
    Result := '2.6.4'
  else
    Result := '3.2.2'; // Default to stable version
end;

function TBootstrapManager.GetBootstrapPath(const AVersion: string): string;
begin
  Result := FSourceRoot + PathDelim + 'bootstrap' + PathDelim + 'fpc-' + AVersion + PathDelim + 'bin' + PathDelim + 'fpc';
  {$IFDEF MSWINDOWS}
  Result := Result + '.exe';
  {$ENDIF}
end;

function TBootstrapManager.IsCompatibleBootstrap(const ACompilerPath, ARequiredVersion: string): Boolean;
var
  LResult: TProcessResult;
  DetectedVersion: string;
  ReqMajor, ReqMinor, DetMajor, DetMinor: Integer;

  procedure ParseVersion(const Ver: string; out Major, Minor: Integer);
  var
    P: Integer;
    S: string;
  begin
    Major := 0;
    Minor := 0;
    S := Ver;
    P := Pos('.', S);
    if P > 0 then
    begin
      TryStrToInt(Copy(S, 1, P - 1), Major);
      Delete(S, 1, P);
      P := Pos('.', S);
      if P > 0 then
        TryStrToInt(Copy(S, 1, P - 1), Minor)
      else
        TryStrToInt(S, Minor);
    end;
  end;

begin
  Result := False;

  // Basic check: file must exist
  if (ACompilerPath = '') or (not FileExists(ACompilerPath)) then
    Exit;

  // If no required version specified, just check existence
  if ARequiredVersion = '' then
  begin
    Result := True;
    Exit;
  end;

  // Execute compiler to get version
  LResult := TProcessExecutor.Execute(ACompilerPath, ['-iV'], '');
  if LResult.Success then
  begin
    DetectedVersion := Trim(LResult.StdOut);
    // Handle multi-line output - take first line
    if Pos(LineEnding, DetectedVersion) > 0 then
      DetectedVersion := Trim(Copy(DetectedVersion, 1, Pos(LineEnding, DetectedVersion) - 1));
  end
  else
    Exit;

  if DetectedVersion = '' then
    Exit;

  // Parse and compare versions (major.minor must match or be compatible)
  ParseVersion(ARequiredVersion, ReqMajor, ReqMinor);
  ParseVersion(DetectedVersion, DetMajor, DetMinor);

  // Bootstrap compiler must be same major version and same or higher minor
  // For example: 3.2.0 can build 3.2.2, but 3.0.4 cannot build 3.2.2
  Result := (DetMajor = ReqMajor) and (DetMinor >= ReqMinor);
end;

function TBootstrapManager.GetBootstrapDownloadURL(const AVersion: string): string;
var
  PlatformInfo: TPlatformInfo;
begin
  // DEPRECATED: This function uses SourceForge URLs which are no longer supported.
  // Bootstrap compilers should be downloaded from fpdev-repo instead.
  // See docs/REPO_SPECIFICATION.md for the new repository format.

  // Detect platform and architecture
  PlatformInfo := DetectPlatformArch;

  // Legacy SourceForge download URL (kept for backward compatibility)
  // Format: https://sourceforge.net/projects/freepascal/files/{Platform}/{Version}/fpc-{Version}.{Arch}.zip/download
  Result := Format('https://sourceforge.net/projects/freepascal/files/%s/%s/fpc-%s.%s.zip/download',
    [PlatformInfo.Platform, AVersion, AVersion, PlatformInfo.Architecture]);
end;

end.
