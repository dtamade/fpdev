unit fpdev.build.toolchain;

{$mode objfpc}{$H+}

{
  TBuildToolchainChecker - Build toolchain detection and verification service

  Extracted from TBuildManager to handle:
  - Tool detection (make, gmake, fpc, etc.)
  - Toolchain validation
  - Build environment verification

  Features:
  - Result caching with TTL to avoid repeated process spawns
  - Configurable cache duration (default 30 seconds)
}

interface

uses
  SysUtils, Classes, DateUtils;

const
  DEFAULT_CACHE_TTL_SECONDS = 30;  // Cache results for 30 seconds

type
  { TToolCacheEntry - Cached tool check result }
  TToolCacheEntry = record
    Key: string;              // Tool name + args hash
    Result: Boolean;          // Check result
    Output: string;           // Command output (if captured)
    Timestamp: TDateTime;     // When cached
  end;

  TToolCacheArray = array of TToolCacheEntry;

  { TToolchainInfo - Information about detected toolchain }
  TToolchainInfo = record
    MakeCommand: string;      // Detected make command
    FPCVersion: string;       // Detected FPC version
    HasMake: Boolean;         // make/gmake available
    HasFPC: Boolean;          // FPC available
    HasGit: Boolean;          // Git available
    IsValid: Boolean;         // Overall toolchain valid
    ErrorMessage: string;     // Error if not valid
  end;

  { TBuildToolchainChecker }
  TBuildToolchainChecker = class
  private
    FVerbose: Boolean;
    FLastInfo: TToolchainInfo;
    FCacheTTL: Integer;       // Cache TTL in seconds
    FCache: TToolCacheArray;  // Tool check cache
    FCacheHits: Integer;      // Statistics: cache hits
    FCacheMisses: Integer;    // Statistics: cache misses

    function MakeCacheKey(const AExe: string; const AArgs: array of string): string;
    function FindCacheEntry(const AKey: string; out AEntry: TToolCacheEntry): Boolean;
    procedure AddCacheEntry(const AKey: string; AResult: Boolean; const AOutput: string);
    function ExecuteCommand(const AExe: string; const AArgs: array of string; out AOutput: string): Boolean;
    function ExecuteCommandCached(const AExe: string; const AArgs: array of string; out AOutput: string): Boolean;

  public
    constructor Create(AVerbose: Boolean = False);

    { Check if a tool exists and can be executed with given arguments }
    function HasTool(const AExe: string; const AArgs: array of string): Boolean;

    { Resolve the make command (make or gmake) }
    function ResolveMakeCmd: string;

    { Check complete toolchain for FPC building }
    function CheckToolchain: Boolean;

    { Get detailed toolchain information }
    function GetToolchainInfo: TToolchainInfo;

    { Get FPC version if available }
    function GetFPCVersion: string;

    { Clear the tool cache }
    procedure ClearCache;

    { Get cache statistics }
    function GetCacheStats: string;

    property Verbose: Boolean read FVerbose write FVerbose;
    property LastInfo: TToolchainInfo read FLastInfo;
    property CacheTTL: Integer read FCacheTTL write FCacheTTL;
    property CacheHits: Integer read FCacheHits;
    property CacheMisses: Integer read FCacheMisses;
  end;

implementation

uses
  Process;

{ TBuildToolchainChecker }

constructor TBuildToolchainChecker.Create(AVerbose: Boolean);
begin
  inherited Create;
  FVerbose := AVerbose;
  FCacheTTL := DEFAULT_CACHE_TTL_SECONDS;
  FCacheHits := 0;
  FCacheMisses := 0;
  SetLength(FCache, 0);
  Initialize(FLastInfo);
end;

function TBuildToolchainChecker.MakeCacheKey(const AExe: string; const AArgs: array of string): string;
var
  i: Integer;
begin
  Result := AExe;
  for i := Low(AArgs) to High(AArgs) do
    Result := Result + '|' + AArgs[i];
end;

function TBuildToolchainChecker.FindCacheEntry(const AKey: string; out AEntry: TToolCacheEntry): Boolean;
var
  i: Integer;
  Age: Int64;
begin
  Result := False;
  Initialize(AEntry);

  for i := 0 to High(FCache) do
  begin
    if FCache[i].Key = AKey then
    begin
      // Check if entry is still valid
      Age := SecondsBetween(Now, FCache[i].Timestamp);
      if Age <= FCacheTTL then
      begin
        AEntry := FCache[i];
        Inc(FCacheHits);
        Result := True;
      end;
      Exit;
    end;
  end;
end;

procedure TBuildToolchainChecker.AddCacheEntry(const AKey: string; AResult: Boolean; const AOutput: string);
var
  i, Idx: Integer;
begin
  // Check if entry already exists (update it)
  for i := 0 to High(FCache) do
  begin
    if FCache[i].Key = AKey then
    begin
      FCache[i].Result := AResult;
      FCache[i].Output := AOutput;
      FCache[i].Timestamp := Now;
      Exit;
    end;
  end;

  // Add new entry
  Idx := Length(FCache);
  SetLength(FCache, Idx + 1);
  FCache[Idx].Key := AKey;
  FCache[Idx].Result := AResult;
  FCache[Idx].Output := AOutput;
  FCache[Idx].Timestamp := Now;
end;

procedure TBuildToolchainChecker.ClearCache;
begin
  SetLength(FCache, 0);
  FCacheHits := 0;
  FCacheMisses := 0;
end;

function TBuildToolchainChecker.GetCacheStats: string;
var
  Total: Integer;
  HitRate: Double;
begin
  Total := FCacheHits + FCacheMisses;
  if Total > 0 then
    HitRate := (FCacheHits * 100.0) / Total
  else
    HitRate := 0;

  Result := Format('Cache: %d entries, %d hits, %d misses (%.1f%% hit rate)',
    [Length(FCache), FCacheHits, FCacheMisses, HitRate]);
end;

function TBuildToolchainChecker.ExecuteCommand(const AExe: string; const AArgs: array of string; out AOutput: string): Boolean;
var
  Process: TProcess;
  OutStream: TStringStream;
  i: Integer;
begin
  Result := False;
  AOutput := '';

  Process := TProcess.Create(nil);
  OutStream := TStringStream.Create('');
  try
    Process.Executable := AExe;
    for i := Low(AArgs) to High(AArgs) do
      Process.Parameters.Add(AArgs[i]);

    Process.Options := [poUsePipes, poNoConsole];

    try
      Process.Execute;

      // Read output
      while Process.Running or (Process.Output.NumBytesAvailable > 0) do
      begin
        if Process.Output.NumBytesAvailable > 0 then
          OutStream.CopyFrom(Process.Output, Process.Output.NumBytesAvailable);
        Sleep(10);
      end;

      AOutput := OutStream.DataString;
      Result := (Process.ExitCode = 0);
    except
      Result := False;
    end;
  finally
    OutStream.Free;
    Process.Free;
  end;
end;

function TBuildToolchainChecker.ExecuteCommandCached(const AExe: string; const AArgs: array of string; out AOutput: string): Boolean;
var
  Key: string;
  Entry: TToolCacheEntry;
begin
  Key := MakeCacheKey(AExe, AArgs);

  // Check cache first
  if FindCacheEntry(Key, Entry) then
  begin
    AOutput := Entry.Output;
    Result := Entry.Result;
    Exit;
  end;

  // Cache miss - execute command
  Inc(FCacheMisses);
  Result := ExecuteCommand(AExe, AArgs, AOutput);

  // Cache the result
  AddCacheEntry(Key, Result, AOutput);
end;

function TBuildToolchainChecker.HasTool(const AExe: string; const AArgs: array of string): Boolean;
var
  Output: string;
begin
  Result := ExecuteCommandCached(AExe, AArgs, Output);
end;

function TBuildToolchainChecker.ResolveMakeCmd: string;
begin
  // Try gmake first (BSD/macOS)
  if HasTool('gmake', ['--version']) then
    Result := 'gmake'
  // Try make
  else if HasTool('make', ['--version']) then
    Result := 'make'
  // Fallback
  else
    Result := 'make';

  FLastInfo.MakeCommand := Result;
  FLastInfo.HasMake := (Result <> '') and HasTool(Result, ['--version']);
end;

function TBuildToolchainChecker.CheckToolchain: Boolean;
var
  Output: string;
begin
  Initialize(FLastInfo);
  Result := True;

  // Check make/gmake
  FLastInfo.MakeCommand := ResolveMakeCmd;
  FLastInfo.HasMake := HasTool(FLastInfo.MakeCommand, ['--version']);
  if not FLastInfo.HasMake then
  begin
    FLastInfo.ErrorMessage := 'make/gmake not found';
    FLastInfo.IsValid := False;
    Exit(False);
  end;

  // Check FPC
  FLastInfo.HasFPC := HasTool('fpc', ['-iV']);
  if FLastInfo.HasFPC then
  begin
    if ExecuteCommandCached('fpc', ['-iV'], Output) then
      FLastInfo.FPCVersion := Trim(Output);
  end
  else
  begin
    // FPC not strictly required for bootstrap builds
    if FVerbose then
      ; // Could log warning
  end;

  // Check Git (optional but useful)
  FLastInfo.HasGit := HasTool('git', ['--version']);

  // Overall validation
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

  if ExecuteCommandCached('fpc', ['-iV'], Output) then
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

end.
