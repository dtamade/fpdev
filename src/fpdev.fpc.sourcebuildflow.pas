unit fpdev.fpc.sourcebuildflow;

{$mode objfpc}{$H+}

interface

type
  TFPCSourcePathCheckFunc = function(const APath: string): Boolean of object;
  TFPCSourceBuildSourceFunc = function(const ASourcePath: string): Boolean of object;
  TFPCSourceManagedStepFunc = function(const AVersion: string): Boolean of object;

function ExecuteFPCSourceBuildCore(
  const AVersion, ASourcePath: string;
  AIsValidSourceDirectory: TFPCSourcePathCheckFunc;
  ABuildSource: TFPCSourceBuildSourceFunc
): Boolean;

function ExecuteFPCSourceManagedBuildStepCore(
  const AVersion, ASourcePath: string;
  AIsValidSourceDirectory: TFPCSourcePathCheckFunc;
  AExecuteStep: TFPCSourceManagedStepFunc
): Boolean;

function ExecuteFPCSourceCacheAvailableCore(
  const ASourceRoot, AVersion: string
): Boolean;

function ExecuteFPCSourceUseCachedBuildCore(
  const ASourceRoot, AVersion, ASourcePath: string;
  AIsValidSourceDirectory: TFPCSourcePathCheckFunc
): Boolean;

implementation

uses
  SysUtils, Classes;

function ExecuteFPCSourceBuildCore(
  const AVersion, ASourcePath: string;
  AIsValidSourceDirectory: TFPCSourcePathCheckFunc;
  ABuildSource: TFPCSourceBuildSourceFunc
): Boolean;
begin
  if AVersion = '' then;
  Result := Assigned(AIsValidSourceDirectory) and
    AIsValidSourceDirectory(ASourcePath);
  if not Result then
    Exit(False);

  Result := Assigned(ABuildSource) and ABuildSource(ASourcePath);
end;

function ExecuteFPCSourceManagedBuildStepCore(
  const AVersion, ASourcePath: string;
  AIsValidSourceDirectory: TFPCSourcePathCheckFunc;
  AExecuteStep: TFPCSourceManagedStepFunc
): Boolean;
begin
  Result := Assigned(AIsValidSourceDirectory) and
    AIsValidSourceDirectory(ASourcePath);
  if not Result then
    Exit(False);

  Result := Assigned(AExecuteStep) and AExecuteStep(AVersion);
end;

function ExecuteFPCSourceCacheAvailableCore(
  const ASourceRoot, AVersion: string
): Boolean;
begin
  Result := FileExists(IncludeTrailingPathDelimiter(ASourceRoot) +
    'cache' + PathDelim + 'fpc-' + AVersion + '.cache');
end;

function ExecuteFPCSourceUseCachedBuildCore(
  const ASourceRoot, AVersion, ASourcePath: string;
  AIsValidSourceDirectory: TFPCSourcePathCheckFunc
): Boolean;
var
  CachePath: string;
  CompilerDir: string;
  RTLDir: string;
  CacheMeta: TStringList;
  CachedVersion: string;
  i: Integer;
begin
  Result := False;

  if (not Assigned(AIsValidSourceDirectory)) or
     (not AIsValidSourceDirectory(ASourcePath)) then
    Exit(False);

  CachePath := IncludeTrailingPathDelimiter(ASourceRoot) +
    'cache' + PathDelim + 'fpc-' + AVersion + '.cache';
  if not FileExists(CachePath) then
    Exit(False);

  CacheMeta := TStringList.Create;
  try
    CacheMeta.LoadFromFile(CachePath);
    CachedVersion := '';
    for i := 0 to CacheMeta.Count - 1 do
      if Pos('version=', CacheMeta[i]) = 1 then
      begin
        CachedVersion := Copy(CacheMeta[i], 9, Length(CacheMeta[i]) - 8);
        Break;
      end;
    if not SameText(CachedVersion, AVersion) then
      Exit(False);
  finally
    CacheMeta.Free;
  end;

  CompilerDir := IncludeTrailingPathDelimiter(ASourcePath) + 'compiler';
  RTLDir := IncludeTrailingPathDelimiter(ASourcePath) + 'rtl';

  if not DirectoryExists(CompilerDir) then
    Exit(False);
  if not DirectoryExists(RTLDir) then
    Exit(False);

  {$IFDEF MSWINDOWS}
  if not FileExists(CompilerDir + PathDelim + 'ppc386.exe') and
     not FileExists(CompilerDir + PathDelim + 'ppcx64.exe') then
    Exit(False);
  {$ELSE}
  if not FileExists(CompilerDir + PathDelim + 'ppc386') and
     not FileExists(CompilerDir + PathDelim + 'ppcx64') and
     not FileExists(CompilerDir + PathDelim + 'ppca64') then
    Exit(False);
  {$ENDIF}

  Result := True;
end;

end.
