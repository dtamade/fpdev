unit fpdev.resource.repo.bootstrap;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpjson;

function ResourceRepoGetRequiredBootstrapVersion(const AManifestData: TJSONObject;
  const AFPCVersion: string): string;
function ResourceRepoGetBootstrapVersionFromMakefile(const ASourcePath: string): string;
function ResourceRepoListBootstrapVersions(const AManifestData: TJSONObject): SysUtils.TStringArray;

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
begin
  Result := '';

  if not Assigned(AManifestData) then
  begin
    Result := GetHardcodedBootstrapMapping(AFPCVersion);
    Exit;
  end;

  VersionMap := AManifestData.Objects['bootstrap_version_map'];
  if not Assigned(VersionMap) then
  begin
    Result := GetHardcodedBootstrapMapping(AFPCVersion);
    Exit;
  end;

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
  i: Integer;
begin
  Result := nil;

  if not Assigned(AManifestData) then
    Exit;

  BootstrapCompilers := AManifestData.Objects['bootstrap_compilers'];
  if not Assigned(BootstrapCompilers) then
    Exit;

  SetLength(Result, BootstrapCompilers.Count);
  for i := 0 to BootstrapCompilers.Count - 1 do
    Result[i] := BootstrapCompilers.Names[i];
end;

end.
