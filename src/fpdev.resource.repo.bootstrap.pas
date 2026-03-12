unit fpdev.resource.repo.bootstrap;

{$mode objfpc}{$H+}
// acq:allow-hardcoded-constants-file

interface

uses
  SysUtils, fpjson;

type
  TRepoHasBootstrapCompilerFunc = function(
    const AVersion, APlatform: string
  ): Boolean of object;

function ResourceRepoGetRequiredBootstrapVersion(const AManifestData: TJSONObject;
  const AFPCVersion: string): string;
function ResourceRepoGetBootstrapVersionFromMakefile(const ASourcePath: string): string;
function ResourceRepoListBootstrapVersions(const AManifestData: TJSONObject): SysUtils.TStringArray;
function SelectBestBootstrapVersionCore(
  const ARequiredVersion, APlatform: string;
  const AAvailableVersions: SysUtils.TStringArray;
  AHasBootstrapCompiler: TRepoHasBootstrapCompilerFunc;
  out ALogLines: SysUtils.TStringArray
): string;

implementation

function GetHardcodedBootstrapMapping(const AFPCVersion: string): string;
var
  NormVer: string;
begin
  Result := '';
  NormVer := LowerCase(Trim(AFPCVersion));

  if (NormVer = 'main') or (NormVer = '3.3.1') or (NormVer = 'trunk') then
    Result := '3.2.2'
  else if (NormVer = '3.2.4') or (NormVer = '3.2.3') then
    Result := '3.2.2'
  else if NormVer = '3.2.2' then
    Result := '3.2.0'
  else if NormVer = '3.2.0' then
    Result := '3.0.4'
  else if (NormVer = '3.0.5') or (NormVer = '3.0.4') then
    Result := '3.0.2'
  else if (NormVer = '3.0.3') or (NormVer = '3.0.2') or (NormVer = '3.0.1') then
    Result := '3.0.0'
  else if NormVer = '3.0.0' then
    Result := '2.6.4'
  else if (NormVer = '2.6.5') or (NormVer = '2.6.4') then
    Result := '2.6.2'
  else if NormVer = '2.6.2' then
    Result := '2.6.0';
end;

function ResourceRepoGetRequiredBootstrapVersion(const AManifestData: TJSONObject;
  const AFPCVersion: string): string;
var
  VersionMap: TJSONObject;
  NormalizedVersion: string;
  Obj: TJSONData;
begin
  Result := '';

  if not Assigned(AManifestData) then
  begin
    Result := GetHardcodedBootstrapMapping(AFPCVersion);
    Exit;
  end;

  // Use Find() instead of Objects[] to avoid EJSON exception on missing key
  Obj := AManifestData.Find('bootstrap_version_map', jtObject);
  if not Assigned(Obj) then
  begin
    Result := GetHardcodedBootstrapMapping(AFPCVersion);
    Exit;
  end;
  VersionMap := TJSONObject(Obj);

  Result := VersionMap.Get(AFPCVersion, '');
  if Result = '' then
  begin
    NormalizedVersion := LowerCase(Trim(AFPCVersion));
    if NormalizedVersion = 'trunk' then
      Result := VersionMap.Get('main', '');
  end;

  if Result = '' then
    Result := GetHardcodedBootstrapMapping(AFPCVersion);
end;

function VersionNumberToString(ANumericVersion: Integer): string;
var
  Major, Minor, Patch: Integer;
begin
  Major := ANumericVersion div 10000;
  Minor := (ANumericVersion mod 10000) div 100;
  Patch := ANumericVersion mod 100;
  Result := Format('%d.%d.%d', [Major, Minor, Patch]);
end;

function ResourceRepoGetBootstrapVersionFromMakefile(const ASourcePath: string): string;
var
  MakefilePath: string;
  F: TextFile;
  Line: string;
  RequiredVersion: Integer;
  RequiredVersion2: Integer;
  VersionStr: string;
begin
  Result := '';

  MakefilePath := ASourcePath + PathDelim + 'Makefile';
  if not FileExists(MakefilePath) then
  begin
    MakefilePath := ASourcePath + PathDelim + 'Makefile.fpc';
    if not FileExists(MakefilePath) then
      Exit;
  end;

  RequiredVersion := 0;
  RequiredVersion2 := 0;

  AssignFile(F, MakefilePath);
  Reset(F);
  try
    while not Eof(F) do
    begin
      ReadLn(F, Line);
      Line := Trim(Line);

      if Pos('REQUIREDVERSION=', Line) = 1 then
      begin
        VersionStr := Trim(Copy(Line, 17, Length(Line)));
        if Pos('#', VersionStr) > 0 then
          VersionStr := Trim(Copy(VersionStr, 1, Pos('#', VersionStr) - 1));
        if not TryStrToInt(VersionStr, RequiredVersion) then
          RequiredVersion := 0;
      end
      else if Pos('REQUIREDVERSION2=', Line) = 1 then
      begin
        VersionStr := Trim(Copy(Line, 18, Length(Line)));
        if Pos('#', VersionStr) > 0 then
          VersionStr := Trim(Copy(VersionStr, 1, Pos('#', VersionStr) - 1));
        if not TryStrToInt(VersionStr, RequiredVersion2) then
          RequiredVersion2 := 0;
      end;
    end;
  finally
    CloseFile(F);
  end;

  if RequiredVersion > 0 then
  begin
    Result := VersionNumberToString(RequiredVersion);

    if (RequiredVersion2 > 0) and (RequiredVersion2 < RequiredVersion) then
      Result := VersionNumberToString(RequiredVersion2);
  end;
end;

function ResourceRepoListBootstrapVersions(const AManifestData: TJSONObject): SysUtils.TStringArray;
var
  BootstrapCompilers: TJSONObject;
  Obj: TJSONData;
  i: Integer;
begin
  Result := nil;

  if not Assigned(AManifestData) then
    Exit;

  // Use Find() instead of Objects[] to avoid EJSON exception on missing key
  Obj := AManifestData.Find('bootstrap_compilers', jtObject);
  if not Assigned(Obj) then
    Exit;
  BootstrapCompilers := TJSONObject(Obj);

  SetLength(Result, BootstrapCompilers.Count);
  for i := 0 to BootstrapCompilers.Count - 1 do
    Result[i] := BootstrapCompilers.Names[i];
end;

const
  DEFAULT_BOOTSTRAP_VERSION = '3.2.2';
  BOOTSTRAP_FALLBACK_CHAIN: array[0..7] of string = (
    '3.2.2',
    '3.2.0',
    '3.0.4',
    '3.0.2',
    '3.0.0',
    '2.6.4',
    '2.6.2',
    '2.6.0'
  );

procedure AddBootstrapLogLine(var ALogLines: SysUtils.TStringArray; const ALine: string);
var
  Index: Integer;
begin
  Index := Length(ALogLines);
  SetLength(ALogLines, Index + 1);
  ALogLines[Index] := ALine;
end;

function SelectBestBootstrapVersionCore(
  const ARequiredVersion, APlatform: string;
  const AAvailableVersions: SysUtils.TStringArray;
  AHasBootstrapCompiler: TRepoHasBootstrapCompilerFunc;
  out ALogLines: SysUtils.TStringArray
): string;
var
  EffectiveRequiredVersion: string;
  ChainIdx: Integer;
  Index: Integer;
begin
  Result := '';
  ALogLines := Default(SysUtils.TStringArray);
  SetLength(ALogLines, 0);

  EffectiveRequiredVersion := ARequiredVersion;
  if EffectiveRequiredVersion = '' then
  begin
    AddBootstrapLogLine(ALogLines,
      Format('Warning: No bootstrap version mapping found for FPC %s', [ARequiredVersion]));
    EffectiveRequiredVersion := DEFAULT_BOOTSTRAP_VERSION;
  end;

  if Assigned(AHasBootstrapCompiler) and
     AHasBootstrapCompiler(EffectiveRequiredVersion, APlatform) then
    Exit(EffectiveRequiredVersion);

  ChainIdx := -1;
  for Index := Low(BOOTSTRAP_FALLBACK_CHAIN) to High(BOOTSTRAP_FALLBACK_CHAIN) do
  begin
    if BOOTSTRAP_FALLBACK_CHAIN[Index] = EffectiveRequiredVersion then
    begin
      ChainIdx := Index;
      Break;
    end;
  end;
  if ChainIdx < 0 then
    ChainIdx := 0;

  for Index := ChainIdx to High(BOOTSTRAP_FALLBACK_CHAIN) do
  begin
    if Assigned(AHasBootstrapCompiler) and
       AHasBootstrapCompiler(BOOTSTRAP_FALLBACK_CHAIN[Index], APlatform) then
    begin
      if BOOTSTRAP_FALLBACK_CHAIN[Index] <> EffectiveRequiredVersion then
        AddBootstrapLogLine(ALogLines,
          Format('Note: Using bootstrap %s instead of %s (fallback due to availability)', [
            BOOTSTRAP_FALLBACK_CHAIN[Index],
            EffectiveRequiredVersion
          ]));
      Exit(BOOTSTRAP_FALLBACK_CHAIN[Index]);
    end;
  end;

  for Index := Low(AAvailableVersions) to High(AAvailableVersions) do
  begin
    if Assigned(AHasBootstrapCompiler) and
       AHasBootstrapCompiler(AAvailableVersions[Index], APlatform) then
    begin
      AddBootstrapLogLine(ALogLines,
        Format('Warning: Using bootstrap %s (only available version for platform %s)', [
          AAvailableVersions[Index],
          APlatform
        ]));
      Exit(AAvailableVersions[Index]);
    end;
  end;

  AddBootstrapLogLine(ALogLines,
    Format('Error: No bootstrap compiler available for platform %s', [APlatform]));
end;

end.
