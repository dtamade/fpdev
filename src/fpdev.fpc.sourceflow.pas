unit fpdev.fpc.sourceflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpdev.version.registry;

type
  TFPCReleaseArray = fpdev.version.registry.TFPCReleaseArray;

  TFPCSourceFlowVersionFunc = function(const AVersion: string): Boolean of object;
  TFPCSourceFlowVersionArrayFunc = function: TStringArray of object;
  TFPCSourceFlowStatusProc = procedure(const AText: string) of object;
  TFPCSourceFlowPathValidatorFunc = function(const APath: string): Boolean of object;
  TFPCSourceFlowExecuteCommandFunc = function(
    const AProgram: string;
    const AArgs: array of string;
    const AWorkingDir: string
  ): Boolean of object;

function ExecuteFPCSourceCloneCore(
  const ARequestedVersion: string;
  var ACurrentVersion: string;
  ACloneSource: TFPCSourceFlowVersionFunc
): Boolean;

function ExecuteFPCSourceUpdateCore(
  const ARequestedVersion: string;
  var ACurrentVersion: string;
  AUpdateSource: TFPCSourceFlowVersionFunc;
  AWriteStatus: TFPCSourceFlowStatusProc
): Boolean;

function ExecuteFPCSourceSwitchCore(
  const AVersion: string;
  var ACurrentVersion: string;
  const AIsInstalled: Boolean;
  ASwitchVersion: TFPCSourceFlowVersionFunc
): Boolean;

function BuildAvailableFPCSourceVersionsCore(
  const AReleases: TFPCReleaseArray
): TStringArray; overload;

function BuildAvailableFPCSourceVersionsCore(
  AGetVersions: TFPCSourceFlowVersionArrayFunc
): TStringArray; overload;

function ListLocalFPCSourceVersionsCore(
  const ASourceRoot: string;
  AIsValidSourceDirectory: TFPCSourceFlowPathValidatorFunc
): TStringArray;

function CheckFPCSourceBuildPrerequisitesCore(
  const AVersion, ABootstrapCompiler: string;
  AExecuteCommand: TFPCSourceFlowExecuteCommandFunc
): Boolean;

implementation

uses
  Classes;

const
  DEFAULT_FPC_SOURCE_VERSIONS: array[0..6] of string = (
    'main',
    '3.2.2',
    '3.2.0',
    '3.0.4',
    '3.0.2',
    '2.6.4',
    '2.6.2'
  );

function ResolveRequestedFPCSourceVersion(
  const ARequestedVersion, ACurrentVersion: string
): string;
begin
  if ARequestedVersion <> '' then
    Exit(ARequestedVersion);
  if ACurrentVersion <> '' then
    Exit(ACurrentVersion);
  Result := 'main';
end;

procedure WriteStatusMessage(
  AWriteStatus: TFPCSourceFlowStatusProc;
  const AText: string
);
begin
  if Assigned(AWriteStatus) then
    AWriteStatus(AText);
end;

function RegistryHasFPCReleasesCore(const AReleases: TFPCReleaseArray): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to High(AReleases) do
  begin
    if Trim(AReleases[i].Version) <> '' then
      Exit(True);
  end;
end;

function ExecuteFPCSourceCloneCore(
  const ARequestedVersion: string;
  var ACurrentVersion: string;
  ACloneSource: TFPCSourceFlowVersionFunc
): Boolean;
var
  Version: string;
begin
  Version := ResolveRequestedFPCSourceVersion(ARequestedVersion, '');
  Result := Assigned(ACloneSource) and ACloneSource(Version);
  if Result then
    ACurrentVersion := Version;
end;

function ExecuteFPCSourceUpdateCore(
  const ARequestedVersion: string;
  var ACurrentVersion: string;
  AUpdateSource: TFPCSourceFlowVersionFunc;
  AWriteStatus: TFPCSourceFlowStatusProc
): Boolean;
var
  Version: string;
begin
  Version := ResolveRequestedFPCSourceVersion(ARequestedVersion, ACurrentVersion);
  Result := Assigned(AUpdateSource) and AUpdateSource(Version);
  if Result then
  begin
    ACurrentVersion := Version;
    WriteStatusMessage(AWriteStatus, '[OK] FPC source updated successfully');
  end
  else
    WriteStatusMessage(AWriteStatus, '[FAIL] FPC source update failed');
end;

function ExecuteFPCSourceSwitchCore(
  const AVersion: string;
  var ACurrentVersion: string;
  const AIsInstalled: Boolean;
  ASwitchVersion: TFPCSourceFlowVersionFunc
): Boolean;
begin
  if not AIsInstalled then
    Exit(False);

  Result := Assigned(ASwitchVersion) and ASwitchVersion(AVersion);
  if Result then
    ACurrentVersion := AVersion;
end;

function BuildAvailableFPCSourceVersionsCore(
  const AReleases: TFPCReleaseArray
): TStringArray;
var
  Values: TStringList;
  i: Integer;
begin
  Result := nil;
  Values := TStringList.Create;
  try
    for i := 0 to High(AReleases) do
    begin
      if (Trim(AReleases[i].Version) <> '') and
         (Values.IndexOf(AReleases[i].Version) < 0) then
        Values.Add(AReleases[i].Version);
    end;

    if not RegistryHasFPCReleasesCore(AReleases) then
      for i := 0 to High(DEFAULT_FPC_SOURCE_VERSIONS) do
      begin
        if Values.IndexOf(DEFAULT_FPC_SOURCE_VERSIONS[i]) < 0 then
          Values.Add(DEFAULT_FPC_SOURCE_VERSIONS[i]);
      end;

    SetLength(Result, Values.Count);
    for i := 0 to Values.Count - 1 do
      Result[i] := Values[i];
  finally
    Values.Free;
  end;
end;

function BuildAvailableFPCSourceVersionsCore(
  AGetVersions: TFPCSourceFlowVersionArrayFunc
): TStringArray;
var
  Versions: TStringArray;
  Values: TStringList;
  i: Integer;
  HasExplicitVersions: Boolean;
begin
  if Assigned(AGetVersions) then
    Versions := AGetVersions()
  else
    Versions := nil;

  Result := nil;
  Values := TStringList.Create;
  try
    HasExplicitVersions := False;
    for i := 0 to High(Versions) do
    begin
      if Trim(Versions[i]) = '' then
        Continue;
      HasExplicitVersions := True;
      if Values.IndexOf(Versions[i]) < 0 then
        Values.Add(Versions[i]);
    end;

    if not HasExplicitVersions then
      for i := 0 to High(DEFAULT_FPC_SOURCE_VERSIONS) do
      begin
        if Values.IndexOf(DEFAULT_FPC_SOURCE_VERSIONS[i]) < 0 then
          Values.Add(DEFAULT_FPC_SOURCE_VERSIONS[i]);
      end;

    SetLength(Result, Values.Count);
    for i := 0 to Values.Count - 1 do
      Result[i] := Values[i];
  finally
    Values.Free;
  end;
end;

function ListLocalFPCSourceVersionsCore(
  const ASourceRoot: string;
  AIsValidSourceDirectory: TFPCSourceFlowPathValidatorFunc
): TStringArray;
var
  SearchRec: TSearchRec;
  VersionList: TStringList;
  DirName: string;
  SourcePath: string;
  Version: string;
  i: Integer;
begin
  Result := nil;
  VersionList := TStringList.Create;
  try
    if FindFirst(IncludeTrailingPathDelimiter(ASourceRoot) + 'fpc-*', faDirectory, SearchRec) = 0 then
    begin
      repeat
        if (SearchRec.Attr and faDirectory) = 0 then
          Continue;

        DirName := SearchRec.Name;
        if Pos('fpc-', DirName) <> 1 then
          Continue;

        SourcePath := IncludeTrailingPathDelimiter(ASourceRoot) + DirName;
        if Assigned(AIsValidSourceDirectory) and
           (not AIsValidSourceDirectory(SourcePath)) then
          Continue;

        Version := Copy(DirName, 5, Length(DirName) - 4);
        VersionList.Add(Version);
      until FindNext(SearchRec) <> 0;
      FindClose(SearchRec);
    end;

    SetLength(Result, VersionList.Count);
    for i := 0 to VersionList.Count - 1 do
      Result[i] := VersionList[i];
  finally
    VersionList.Free;
  end;
end;

function CheckFPCSourceBuildPrerequisitesCore(
  const AVersion, ABootstrapCompiler: string;
  AExecuteCommand: TFPCSourceFlowExecuteCommandFunc
): Boolean;
begin
  if AVersion <> '' then;

  if (not Assigned(AExecuteCommand)) or
     (not AExecuteCommand('make', ['--version'], '')) then
    Exit(False);

  Result := ABootstrapCompiler <> '';
end;

end.
