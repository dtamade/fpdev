unit fpdev.build.toolchain.detectflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, DateUtils;

const
  DEFAULT_CACHE_TTL_SECONDS = 30;

type
  { TToolCacheEntry - Cached tool check result }
  TToolCacheEntry = record
    Key: string;
    Result: Boolean;
    Output: string;
    Timestamp: TDateTime;
  end;

  TToolCacheArray = array of TToolCacheEntry;

  { TToolDetectionCache - Command execution with TTL-based caching }
  TToolDetectionCache = class
  private
    FCacheTTL: Integer;
    FCache: TToolCacheArray;
    FCacheHits: Integer;
    FCacheMisses: Integer;

    function MakeCacheKey(const AExe: string; const AArgs: array of string): string;
    function FindCacheEntry(const AKey: string; out AEntry: TToolCacheEntry): Boolean;
    procedure AddCacheEntry(const AKey: string; AResult: Boolean; const AOutput: string);
    function ExecuteCommand(const AExe: string; const AArgs: array of string;
      out AOutput: string): Boolean;
  public
    constructor Create;

    function ExecuteCached(const AExe: string; const AArgs: array of string;
      out AOutput: string): Boolean;
    function HasTool(const AExe: string; const AArgs: array of string): Boolean;

    procedure ClearCache;
    function GetCacheStats: string;

    property CacheTTL: Integer read FCacheTTL write FCacheTTL;
    property CacheHits: Integer read FCacheHits;
    property CacheMisses: Integer read FCacheMisses;
  end;

implementation

uses
  Process;

{ TToolDetectionCache }

constructor TToolDetectionCache.Create;
begin
  inherited Create;
  FCacheTTL := DEFAULT_CACHE_TTL_SECONDS;
  FCacheHits := 0;
  FCacheMisses := 0;
  SetLength(FCache, 0);
end;

function TToolDetectionCache.MakeCacheKey(const AExe: string;
  const AArgs: array of string): string;
var
  i: Integer;
begin
  Result := AExe;
  for i := Low(AArgs) to High(AArgs) do
    Result := Result + '|' + AArgs[i];
end;

function TToolDetectionCache.FindCacheEntry(const AKey: string;
  out AEntry: TToolCacheEntry): Boolean;
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

procedure TToolDetectionCache.AddCacheEntry(const AKey: string;
  AResult: Boolean; const AOutput: string);
var
  i, Idx: Integer;
begin
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

  Idx := Length(FCache);
  SetLength(FCache, Idx + 1);
  FCache[Idx].Key := AKey;
  FCache[Idx].Result := AResult;
  FCache[Idx].Output := AOutput;
  FCache[Idx].Timestamp := Now;
end;

procedure TToolDetectionCache.ClearCache;
begin
  SetLength(FCache, 0);
  FCacheHits := 0;
  FCacheMisses := 0;
end;

function TToolDetectionCache.GetCacheStats: string;
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

function TToolDetectionCache.ExecuteCommand(const AExe: string;
  const AArgs: array of string; out AOutput: string): Boolean;
var
  Proc: TProcess;
  OutStream: TStringStream;
  i: Integer;
begin
  Result := False;
  AOutput := '';

  Proc := TProcess.Create(nil);
  OutStream := TStringStream.Create('');
  try
    Proc.Executable := AExe;
    for i := Low(AArgs) to High(AArgs) do
      Proc.Parameters.Add(AArgs[i]);

    Proc.Options := [poUsePipes, poNoConsole];

    try
      Proc.Execute;

      while Proc.Running or (Proc.Output.NumBytesAvailable > 0) do
      begin
        if Proc.Output.NumBytesAvailable > 0 then
          OutStream.CopyFrom(Proc.Output, Proc.Output.NumBytesAvailable);
        Sleep(10);
      end;

      AOutput := OutStream.DataString;
      Result := (Proc.ExitCode = 0);
    except
      Result := False;
    end;
  finally
    OutStream.Free;
    Proc.Free;
  end;
end;

function TToolDetectionCache.ExecuteCached(const AExe: string;
  const AArgs: array of string; out AOutput: string): Boolean;
var
  Key: string;
  Entry: TToolCacheEntry;
begin
  Key := MakeCacheKey(AExe, AArgs);

  if FindCacheEntry(Key, Entry) then
  begin
    AOutput := Entry.Output;
    Result := Entry.Result;
    Exit;
  end;

  Inc(FCacheMisses);
  Result := ExecuteCommand(AExe, AArgs, AOutput);
  AddCacheEntry(Key, Result, AOutput);
end;

function TToolDetectionCache.HasTool(const AExe: string;
  const AArgs: array of string): Boolean;
var
  Output: string;
begin
  Result := ExecuteCached(AExe, AArgs, Output);
end;

end.
