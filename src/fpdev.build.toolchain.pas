unit fpdev.build.toolchain;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, DateUtils, fpdev.build.interfaces,
  fpdev.build.toolchain.detectflow;

type
  TBuildToolHasToolFunc = function(const AExe: string; const AArgs: array of string): Boolean of object;

  { TToolchainInfo - Information about detected toolchain }
  TToolchainInfo = record
    MakeCommand: string;
    FPCVersion: string;
    HasMake: Boolean;
    HasFPC: Boolean;
    HasGit: Boolean;
    IsValid: Boolean;
    ErrorMessage: string;
  end;

  { TBuildToolchainChecker }
  TBuildToolchainChecker = class(TInterfacedObject, IToolchainChecker)
  private
    FVerbose: Boolean;
    FLastInfo: TToolchainInfo;
    FDetectionCache: TToolDetectionCache;

  public
    constructor Create(AVerbose: Boolean = False);
    destructor Destroy; override;

    { IToolchainChecker interface methods }
    function IsMakeAvailable: Boolean;
    function IsFPCAvailable: Boolean;
    function IsSourceDirValid(const ASourceDir: string): Boolean;
    function IsSandboxWritable(const ASandboxDir: string): Boolean;
    function GetMakeCommand: string;
    function GetFPCCommand: string;
    function GetVerbosity: Integer;
    procedure SetVerbosity(AValue: Integer);

    { Legacy methods }
    function HasTool(const AExe: string; const AArgs: array of string): Boolean;
    function ResolveMakeCmd: string;
    function CheckToolchain: Boolean;
    function GetToolchainInfo: TToolchainInfo;
    function GetFPCVersion: string;
    procedure ClearCache;
    function GetCacheStats: string;

    property Verbose: Boolean read FVerbose write FVerbose;
    property LastInfo: TToolchainInfo read FLastInfo;
  end;

function BuildToolchainResolveMakeCommandCore(
  const AIsWindows: Boolean;
  AHasTool: TBuildToolHasToolFunc
): string;

function BuildToolchainMakeAvailableCore(
  const AIsWindows: Boolean;
  AHasTool: TBuildToolHasToolFunc
): Boolean;

implementation

{ TBuildToolchainChecker }

constructor TBuildToolchainChecker.Create(AVerbose: Boolean);
begin
  inherited Create;
  FVerbose := AVerbose;
  FDetectionCache := TToolDetectionCache.Create;
  Initialize(FLastInfo);
end;

destructor TBuildToolchainChecker.Destroy;
begin
  FDetectionCache.Free;
  inherited Destroy;
end;

function BuildToolchainResolveMakeCommandCore(
  const AIsWindows: Boolean;
  AHasTool: TBuildToolHasToolFunc
): string;
begin
  if Assigned(AHasTool) then
  begin
    if AIsWindows then
    begin
      if AHasTool('mingw32-make', ['--version']) then
        Exit('mingw32-make');
      if AHasTool('make', ['--version']) then
        Exit('make');
      if AHasTool('gmake', ['--version']) then
        Exit('gmake');
    end
    else
    begin
      if AHasTool('gmake', ['--version']) then
        Exit('gmake');
      if AHasTool('make', ['--version']) then
        Exit('make');
    end;
  end;

  Result := 'make';
end;

function BuildToolchainMakeAvailableCore(
  const AIsWindows: Boolean;
  AHasTool: TBuildToolHasToolFunc
): Boolean;
begin
  if not Assigned(AHasTool) then
    Exit(False);

  if AIsWindows then
    Result := AHasTool('mingw32-make', ['--version']) or
              AHasTool('make', ['--version']) or
              AHasTool('gmake', ['--version'])
  else
    Result := AHasTool('gmake', ['--version']) or
              AHasTool('make', ['--version']);
end;

function TBuildToolchainChecker.HasTool(const AExe: string; const AArgs: array of string): Boolean;
begin
  Result := FDetectionCache.HasTool(AExe, AArgs);
end;

function TBuildToolchainChecker.ResolveMakeCmd: string;
begin
  Result := BuildToolchainResolveMakeCommandCore({$IFDEF MSWINDOWS}True{$ELSE}False{$ENDIF}, @HasTool);

  FLastInfo.MakeCommand := Result;
  FLastInfo.HasMake := (Result <> '') and HasTool(Result, ['--version']);
end;

function TBuildToolchainChecker.CheckToolchain: Boolean;
var
  Output: string;
begin
  Initialize(FLastInfo);
  Result := True;

  FLastInfo.MakeCommand := ResolveMakeCmd;
  FLastInfo.HasMake := HasTool(FLastInfo.MakeCommand, ['--version']);
  if not FLastInfo.HasMake then
  begin
    FLastInfo.ErrorMessage := 'make/gmake not found';
    FLastInfo.IsValid := False;
    Exit(False);
  end;

  FLastInfo.HasFPC := HasTool('fpc', ['-iV']);
  if FLastInfo.HasFPC then
  begin
    if FDetectionCache.ExecuteCached('fpc', ['-iV'], Output) then
      FLastInfo.FPCVersion := Trim(Output);
  end;

  FLastInfo.HasGit := HasTool('git', ['--version']);

  FLastInfo.IsValid := FLastInfo.HasMake;
  Result := FLastInfo.IsValid;
end;

function TBuildToolchainChecker.GetToolchainInfo: TToolchainInfo;
begin
  if not FLastInfo.IsValid and (FLastInfo.MakeCommand = '') then
    CheckToolchain;
  Result := FLastInfo;
end;

function TBuildToolchainChecker.GetFPCVersion: string;
var
  Output: string;
begin
  if FLastInfo.FPCVersion <> '' then
    Exit(FLastInfo.FPCVersion);

  if FDetectionCache.ExecuteCached('fpc', ['-iV'], Output) then
  begin
    Result := Trim(Output);
    FLastInfo.FPCVersion := Result;
    FLastInfo.HasFPC := True;
  end
  else
  begin
    Result := '';
    FLastInfo.HasFPC := False;
  end;
end;

function TBuildToolchainChecker.IsMakeAvailable: Boolean;
begin
  Result := BuildToolchainMakeAvailableCore({$IFDEF MSWINDOWS}True{$ELSE}False{$ENDIF}, @HasTool);
end;

function TBuildToolchainChecker.IsFPCAvailable: Boolean;
begin
  Result := HasTool('fpc', ['-iV']);
end;

function TBuildToolchainChecker.IsSourceDirValid(const ASourceDir: string): Boolean;
begin
  Result := DirectoryExists(ASourceDir) and
            FileExists(ASourceDir + PathDelim + 'Makefile');
end;

function TBuildToolchainChecker.IsSandboxWritable(const ASandboxDir: string): Boolean;
var
  TestFile: string;
  F: TextFile;
begin
  Result := False;

  if not DirectoryExists(ASandboxDir) then
  begin
    try
      ForceDirectories(ASandboxDir);
    except
      Exit(False);
    end;
  end;

  TestFile := ASandboxDir + PathDelim + '.fpdev_write_test';
  try
    AssignFile(F, TestFile);
    try
      Rewrite(F);
      WriteLn(F, 'test');
      CloseFile(F);
      DeleteFile(TestFile);
      Result := True;
    except
      Result := False;
    end;
  except
    Result := False;
  end;
end;

function TBuildToolchainChecker.GetMakeCommand: string;
begin
  Result := ResolveMakeCmd;
end;

function TBuildToolchainChecker.GetFPCCommand: string;
begin
  if IsFPCAvailable then
    Result := 'fpc'
  else
    Result := '';
end;

function TBuildToolchainChecker.GetVerbosity: Integer;
begin
  if FVerbose then
    Result := 1
  else
    Result := 0;
end;

procedure TBuildToolchainChecker.SetVerbosity(AValue: Integer);
begin
  FVerbose := (AValue > 0);
end;

procedure TBuildToolchainChecker.ClearCache;
begin
  FDetectionCache.ClearCache;
end;

function TBuildToolchainChecker.GetCacheStats: string;
begin
  Result := FDetectionCache.GetCacheStats;
end;

end.
