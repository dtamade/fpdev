unit fpdev.lazarus.sourcelifecycleflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.git.types,
  fpdev.lazarus.sourceflow;

type
  TLazarusSourceStatusProc = procedure(const AText: string) of object;
  TLazarusSourceDeleteDirProc = procedure(const APath: string) of object;
  TLazarusSourcePathCheckFunc = function(const APath: string): Boolean of object;
  TLazarusSourceVersionInstalledFunc = function(const AVersion: string): Boolean of object;
  TLazarusSourceVersionActionFunc = function(const AVersion: string): Boolean of object;
  TLazarusSourceConfigureIDEFunc = function(const AVersion, ASourcePath: string): Boolean of object;
  TLazarusSourceGitBackendFunc = function: TGitBackend of object;
  TLazarusSourceGitCloneFunc = function(const AURL, ALocalPath, ARef: string): Boolean of object;
  TLazarusSourceGitPullFunc = function(const ARepoPath: string): Boolean of object;
  TLazarusSourceGitRepoFunc = function(const APath: string): Boolean of object;
  TLazarusSourceGitCheckoutFunc = function(const ARepoPath, AName: string; const Force: Boolean): Boolean of object;
  TLazarusSourceGitLastErrorFunc = function: string of object;

function ExecuteLazarusLegacyCloneCore(
  const APlan: TLazarusLegacySourceClonePlan;
  var ACurrentVersion: string;
  ALog: TLazarusSourceStatusProc;
  ADeleteExistingDir: TLazarusSourceDeleteDirProc;
  AIsValidSourceDirectory: TLazarusSourcePathCheckFunc;
  AGitBackend: TLazarusSourceGitBackendFunc;
  AGitClone: TLazarusSourceGitCloneFunc
): Boolean;

function ExecuteLazarusLegacyUpdateCore(
  const APlan: TLazarusLegacySourceUpdatePlan;
  var ACurrentVersion: string;
  ALog: TLazarusSourceStatusProc;
  AIsValidSourceDirectory: TLazarusSourcePathCheckFunc;
  AGitBackend: TLazarusSourceGitBackendFunc;
  AGitPull: TLazarusSourceGitPullFunc;
  AGitLastError: TLazarusSourceGitLastErrorFunc
): Boolean;

function ExecuteLazarusLegacySwitchCore(
  const AVersion, ASourcePath, ARefName: string;
  AHasGitMetadata: Boolean;
  var ACurrentVersion: string;
  ALog: TLazarusSourceStatusProc;
  AIsVersionInstalled: TLazarusSourceVersionInstalledFunc;
  ACloneSource: TLazarusSourceVersionActionFunc;
  AIsValidSourceDirectory: TLazarusSourcePathCheckFunc;
  AGitBackend: TLazarusSourceGitBackendFunc;
  AGitIsRepository: TLazarusSourceGitRepoFunc;
  AGitCheckout: TLazarusSourceGitCheckoutFunc;
  AGitLastError: TLazarusSourceGitLastErrorFunc
): Boolean;

function ExecuteLazarusLegacyInstallCore(
  const AVersion, ASourcePath, AExecutablePath, APreviousVersion: string;
  ANeedsIDEConfig: Boolean;
  var ACurrentVersion: string;
  ALog: TLazarusSourceStatusProc;
  ACloneSource: TLazarusSourceVersionActionFunc;
  ABuildSource: TLazarusSourceVersionActionFunc;
  AConfigureIDE: TLazarusSourceConfigureIDEFunc;
  ASwitchVersion: TLazarusSourceVersionActionFunc
): Boolean;

implementation

uses
  SysUtils;

procedure WriteStatus(const ALog: TLazarusSourceStatusProc; const AText: string);
begin
  if Assigned(ALog) then
    ALog(AText);
end;

function ResolveBackend(const AGetBackend: TLazarusSourceGitBackendFunc): TGitBackend;
begin
  Result := gbNone;
  if Assigned(AGetBackend) then
    Result := AGetBackend();
end;

function ResolveLastError(const AGetLastError: TLazarusSourceGitLastErrorFunc): string;
begin
  Result := '';
  if Assigned(AGetLastError) then
    Result := AGetLastError();
end;

function ExecuteLazarusLegacyCloneCore(
  const APlan: TLazarusLegacySourceClonePlan;
  var ACurrentVersion: string;
  ALog: TLazarusSourceStatusProc;
  ADeleteExistingDir: TLazarusSourceDeleteDirProc;
  AIsValidSourceDirectory: TLazarusSourcePathCheckFunc;
  AGitBackend: TLazarusSourceGitBackendFunc;
  AGitClone: TLazarusSourceGitCloneFunc
): Boolean;
var
  Backend: TGitBackend;
begin
  Result := False;

  WriteStatus(ALog, 'Cloning Lazarus source...');
  WriteStatus(ALog, '  Version: ' + APlan.Version);
  WriteStatus(ALog, '  Ref: ' + APlan.RefName);
  WriteStatus(ALog, '  Target: ' + APlan.SourcePath);
  WriteStatus(ALog, '');

  Backend := ResolveBackend(AGitBackend);
  if Backend = gbNone then
  begin
    WriteStatus(ALog, 'Error: No Git backend available (neither libgit2 nor git command found)');
    Exit(False);
  end;

  if DirectoryExists(APlan.SourcePath) then
  begin
    WriteStatus(ALog, 'Removing existing source directory...');
    if Assigned(ADeleteExistingDir) then
      ADeleteExistingDir(APlan.SourcePath);
  end;

  WriteStatus(ALog, 'Using backend: ' + GitBackendToString(Backend));

  if (not Assigned(AGitClone)) or
     (not AGitClone(APlan.RepositoryURL, APlan.SourcePath, APlan.RefName)) then
  begin
    WriteStatus(ALog, 'Error: Failed to clone Lazarus source.');
    Exit(False);
  end;

  if (not Assigned(AIsValidSourceDirectory)) or
     (not AIsValidSourceDirectory(APlan.SourcePath)) then
  begin
    WriteStatus(ALog,
      'Error: Cloned repository is not a valid Lazarus source tree: ' + APlan.SourcePath);
    Exit(False);
  end;

  WriteStatus(ALog, 'Lazarus source cloned successfully.');
  ACurrentVersion := APlan.Version;
  Result := True;
end;

function ExecuteLazarusLegacyUpdateCore(
  const APlan: TLazarusLegacySourceUpdatePlan;
  var ACurrentVersion: string;
  ALog: TLazarusSourceStatusProc;
  AIsValidSourceDirectory: TLazarusSourcePathCheckFunc;
  AGitBackend: TLazarusSourceGitBackendFunc;
  AGitPull: TLazarusSourceGitPullFunc;
  AGitLastError: TLazarusSourceGitLastErrorFunc
): Boolean;
var
  Backend: TGitBackend;
  LastError: string;
begin
  Result := False;

  if (not Assigned(AIsValidSourceDirectory)) or
     (not AIsValidSourceDirectory(APlan.SourcePath)) then
  begin
    WriteStatus(ALog, 'Error: Invalid Lazarus source directory: ' + APlan.SourcePath);
    WriteStatus(ALog, 'Please clone the source first.');
    Exit(False);
  end;

  WriteStatus(ALog, 'Updating Lazarus source...');
  WriteStatus(ALog, '  Version: ' + APlan.Version);
  WriteStatus(ALog, '  Path: ' + APlan.SourcePath);

  Backend := ResolveBackend(AGitBackend);
  if Backend = gbNone then
  begin
    WriteStatus(ALog, 'Error: No Git backend available (neither libgit2 nor git command found)');
    Exit(False);
  end;

  WriteStatus(ALog, 'Using backend: ' + GitBackendToString(Backend));
  if (not Assigned(AGitPull)) or (not AGitPull(APlan.SourcePath)) then
  begin
    WriteStatus(ALog, 'Error: Failed to update Lazarus source.');
    LastError := ResolveLastError(AGitLastError);
    if LastError <> '' then
      WriteStatus(ALog, '  ' + LastError);
    Exit(False);
  end;

  ACurrentVersion := APlan.Version;
  WriteStatus(ALog, 'Lazarus source updated successfully.');
  Result := True;
end;

function ExecuteLazarusLegacySwitchCore(
  const AVersion, ASourcePath, ARefName: string;
  AHasGitMetadata: Boolean;
  var ACurrentVersion: string;
  ALog: TLazarusSourceStatusProc;
  AIsVersionInstalled: TLazarusSourceVersionInstalledFunc;
  ACloneSource: TLazarusSourceVersionActionFunc;
  AIsValidSourceDirectory: TLazarusSourcePathCheckFunc;
  AGitBackend: TLazarusSourceGitBackendFunc;
  AGitIsRepository: TLazarusSourceGitRepoFunc;
  AGitCheckout: TLazarusSourceGitCheckoutFunc;
  AGitLastError: TLazarusSourceGitLastErrorFunc
): Boolean;
var
  Backend: TGitBackend;
  LastError: string;
begin
  Result := False;

  if Assigned(AIsVersionInstalled) and (not AIsVersionInstalled(AVersion)) then
  begin
    WriteStatus(ALog, 'Version ' + AVersion + ' not installed, cloning...');
    if Assigned(ACloneSource) then
      Result := ACloneSource(AVersion);
    Exit;
  end;

  if (not Assigned(AIsValidSourceDirectory)) or
     (not AIsValidSourceDirectory(ASourcePath)) then
  begin
    WriteStatus(ALog, 'Error: Invalid Lazarus source directory: ' + ASourcePath);
    Exit(False);
  end;

  if AHasGitMetadata then
  begin
    Backend := ResolveBackend(AGitBackend);
    if Backend = gbNone then
    begin
      WriteStatus(ALog, 'Error: No Git backend available (neither libgit2 nor git command found)');
      Exit(False);
    end;

    if (not Assigned(AGitIsRepository)) or (not AGitIsRepository(ASourcePath)) then
    begin
      WriteStatus(ALog,
        'Error: Existing Lazarus source tree is not an accessible git repository: ' + ASourcePath);
      Exit(False);
    end;

    if (not Assigned(AGitCheckout)) or
       (not AGitCheckout(ASourcePath, ARefName, True)) then
    begin
      WriteStatus(ALog, 'Error: Failed to switch Lazarus source to ref: ' + ARefName);
      LastError := ResolveLastError(AGitLastError);
      if LastError <> '' then
        WriteStatus(ALog, '  ' + LastError);
      Exit(False);
    end;

    if not AIsValidSourceDirectory(ASourcePath) then
    begin
      WriteStatus(ALog,
        'Error: Switched repository is not a valid Lazarus source tree: ' + ASourcePath);
      Exit(False);
    end;

    WriteStatus(ALog, 'Switching to Lazarus version: ' + AVersion);
    WriteStatus(ALog, '  Ref: ' + ARefName);
  end
  else
    WriteStatus(ALog, 'Switching to Lazarus version: ' + AVersion);

  ACurrentVersion := AVersion;
  Result := True;
end;

function ExecuteLazarusLegacyInstallCore(
  const AVersion, ASourcePath, AExecutablePath, APreviousVersion: string;
  ANeedsIDEConfig: Boolean;
  var ACurrentVersion: string;
  ALog: TLazarusSourceStatusProc;
  ACloneSource: TLazarusSourceVersionActionFunc;
  ABuildSource: TLazarusSourceVersionActionFunc;
  AConfigureIDE: TLazarusSourceConfigureIDEFunc;
  ASwitchVersion: TLazarusSourceVersionActionFunc
): Boolean;
begin
  Result := False;

  WriteStatus(ALog, 'Installing Lazarus version: ' + AVersion);
  if ANeedsIDEConfig then
    WriteStatus(ALog, 'Steps: 1. Clone source -> 2. Build -> 3. Configure IDE -> 4. Activate source tree')
  else
    WriteStatus(ALog, 'Steps: 1. Clone source -> 2. Build -> 3. Activate source tree');
  WriteStatus(ALog, '');

  WriteStatus(ALog, '[1/3] Cloning Lazarus source...');
  if (not Assigned(ACloneSource)) or (not ACloneSource(AVersion)) then
  begin
    ACurrentVersion := APreviousVersion;
    WriteStatus(ALog, 'Error: Source clone failed, installation aborted.');
    Exit(False);
  end;

  WriteStatus(ALog, '[2/3] Building Lazarus IDE...');
  if (not Assigned(ABuildSource)) or (not ABuildSource(AVersion)) then
  begin
    ACurrentVersion := APreviousVersion;
    WriteStatus(ALog, 'Error: Build failed, installation aborted.');
    Exit(False);
  end;

  if not FileExists(AExecutablePath) then
  begin
    ACurrentVersion := APreviousVersion;
    WriteStatus(ALog, 'Error: Lazarus executable not found after build: ' + AExecutablePath);
    Exit(False);
  end;

  if ANeedsIDEConfig then
  begin
    WriteStatus(ALog, '[3/4] Configuring Lazarus IDE for custom FPC...');
    if (not Assigned(AConfigureIDE)) or
       (not AConfigureIDE(AVersion, ASourcePath)) then
    begin
      ACurrentVersion := APreviousVersion;
      WriteStatus(ALog, 'Error: Failed to configure Lazarus IDE for custom FPC path.');
      Exit(False);
    end;
  end;

  if ANeedsIDEConfig then
    WriteStatus(ALog, '[4/4] Setting as current source environment...')
  else
    WriteStatus(ALog, '[3/3] Setting as current source environment...');

  if Assigned(ASwitchVersion) and ASwitchVersion(AVersion) then
  begin
    WriteStatus(ALog, 'Lazarus source tree ' + AVersion + ' is ready.');
    WriteStatus(ALog, 'Current Lazarus version: ' + AVersion);
    WriteStatus(ALog, 'Source path: ' + ASourcePath);
    WriteStatus(ALog, 'Executable path: ' + AExecutablePath);
    Result := True;
  end
  else
  begin
    ACurrentVersion := APreviousVersion;
    WriteStatus(ALog, 'Error: Failed to activate source tree.');
  end;
end;

end.
