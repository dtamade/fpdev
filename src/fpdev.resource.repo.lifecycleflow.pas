unit fpdev.resource.repo.lifecycleflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpjson,
  fpdev.git.types,
  fpdev.resource.repo.lifecycle;

type
  TResourceRepoLifecycleEnsureDirProc = procedure(const APath: string) of object;
  TResourceRepoLifecycleCloneFunc = function(const AURL, ALocalPath,
    ABranch: string): Boolean of object;
  TResourceRepoLifecyclePullFunc = function(const ALocalPath: string): Boolean of object;
  TResourceRepoLifecycleStringFunc = function: string of object;
  TResourceRepoLifecycleLogFmtProc = procedure(const AFormat: string;
    const AArgs: array of const) of object;
  TResourceRepoEnsureManifestLoadedFunc = function: Boolean of object;
  TResourceRepoHasPackageQueryFunc = function(const ALocalPath, AName,
    AVersion: string): Boolean of object;

function ExecuteResourceRepoGitCloneCore(
  const AURL, ALocalPath, ABranch: string;
  ABackend: TGitBackend;
  AClone: TResourceRepoLifecycleCloneFunc;
  AGetLastError: TResourceRepoLifecycleStringFunc;
  AEnsureDir: TResourceRepoLifecycleEnsureDirProc;
  ALogLine: TRepoLifecycleLogProc
): Boolean;

function ExecuteResourceRepoGitPullCore(
  const ALocalPath: string;
  ABackend: TGitBackend;
  APull: TResourceRepoLifecyclePullFunc;
  AGetLastError: TResourceRepoLifecycleStringFunc;
  ALogLine: TRepoLifecycleLogProc
): Boolean;

function LoadResourceRepoManifestSurfaceCore(
  const ALocalPath: string;
  ALogLine: TRepoLifecycleLogProc;
  out AManifestData: TJSONObject;
  out AManifestLoaded: Boolean
): Boolean;

procedure ApplyLoadedResourceRepoManifestStateCore(
  var ACurrentManifestData: TJSONObject;
  var ACurrentManifestLoaded: Boolean;
  ANewManifestData: TJSONObject;
  ANewManifestLoaded: Boolean
);

function GetResourceRepoManifestVersionSurfaceCore(
  AManifestData: TJSONObject;
  AEnsureManifestLoaded: TResourceRepoEnsureManifestLoadedFunc
): string;

function ExecuteResourceRepoHasPackageSurfaceCore(
  const ALocalPath, AName, AVersion: string;
  ALogFmt: TResourceRepoLifecycleLogFmtProc;
  AQuery: TResourceRepoHasPackageQueryFunc
): Boolean;

implementation

function ExecuteResourceRepoGitCloneCore(
  const AURL, ALocalPath, ABranch: string;
  ABackend: TGitBackend;
  AClone: TResourceRepoLifecycleCloneFunc;
  AGetLastError: TResourceRepoLifecycleStringFunc;
  AEnsureDir: TResourceRepoLifecycleEnsureDirProc;
  ALogLine: TRepoLifecycleLogProc
): Boolean;
var
  ParentDir: string;
  LastError: string;

  procedure LogLine(const AMsg: string);
  begin
    if Assigned(ALogLine) then
      ALogLine(AMsg);
  end;

begin
  Result := False;
  if ABackend = gbNone then
  begin
    LogLine('Error: No Git backend available (neither libgit2 nor git command found)');
    Exit(False);
  end;

  LogLine(Format('Cloning resource repository from %s...', [AURL]));
  LogLine(Format('  Using backend: %s', [GitBackendToString(ABackend)]));

  ParentDir := ExtractFileDir(ALocalPath);
  if (ParentDir <> '') and (not DirectoryExists(ParentDir)) and Assigned(AEnsureDir) then
    AEnsureDir(ParentDir);

  Result := Assigned(AClone) and AClone(AURL, ALocalPath, ABranch);
  if Result then
    LogLine('Resource repository cloned successfully')
  else
  begin
    if Assigned(AGetLastError) then
      LastError := AGetLastError()
    else
      LastError := '';
    LogLine(Format('Failed to clone from %s: %s', [AURL, LastError]));
  end;
end;

function ExecuteResourceRepoGitPullCore(
  const ALocalPath: string;
  ABackend: TGitBackend;
  APull: TResourceRepoLifecyclePullFunc;
  AGetLastError: TResourceRepoLifecycleStringFunc;
  ALogLine: TRepoLifecycleLogProc
): Boolean;
var
  LastError: string;

  procedure LogLine(const AMsg: string);
  begin
    if Assigned(ALogLine) then
      ALogLine(AMsg);
  end;

begin
  if ABackend = gbNone then
  begin
    LogLine('Warning: No Git backend available, skipping update');
    Exit(False);
  end;

  LogLine('Updating resource repository...');
  Result := Assigned(APull) and APull(ALocalPath);
  if Result then
    LogLine('Resource repository updated')
  else
  begin
    if Assigned(AGetLastError) then
      LastError := AGetLastError()
    else
      LastError := '';
    LogLine(Format('Warning: Failed to update (using cached version): %s', [
      LastError
    ]));
  end;
end;

function LoadResourceRepoManifestSurfaceCore(
  const ALocalPath: string;
  ALogLine: TRepoLifecycleLogProc;
  out AManifestData: TJSONObject;
  out AManifestLoaded: Boolean
): Boolean;
begin
  Result := LoadResourceRepoManifestCore(
    IncludeTrailingPathDelimiter(ALocalPath) + 'manifest.json',
    ALogLine,
    AManifestData,
    AManifestLoaded
  );
end;

procedure ApplyLoadedResourceRepoManifestStateCore(
  var ACurrentManifestData: TJSONObject;
  var ACurrentManifestLoaded: Boolean;
  ANewManifestData: TJSONObject;
  ANewManifestLoaded: Boolean
);
begin
  FreeAndNil(ACurrentManifestData);
  ACurrentManifestData := ANewManifestData;
  ACurrentManifestLoaded := ANewManifestLoaded;
end;

function GetResourceRepoManifestVersionSurfaceCore(
  AManifestData: TJSONObject;
  AEnsureManifestLoaded: TResourceRepoEnsureManifestLoadedFunc
): string;
begin
  Result := 'unknown';
  if Assigned(AEnsureManifestLoaded) and (not AEnsureManifestLoaded()) then
    Exit;
  if Assigned(AManifestData) then
    Result := AManifestData.Get('version', 'unknown');
end;

function ExecuteResourceRepoHasPackageSurfaceCore(
  const ALocalPath, AName, AVersion: string;
  ALogFmt: TResourceRepoLifecycleLogFmtProc;
  AQuery: TResourceRepoHasPackageQueryFunc
): Boolean;
begin
  Result := False;
  try
    if Assigned(AQuery) then
      Result := AQuery(ALocalPath, AName, AVersion);
  except
    on E: Exception do
    begin
      if Assigned(ALogFmt) then
        ALogFmt('Error checking package availability: %s', [E.Message]);
      Result := False;
    end;
  end;
end;

end.
