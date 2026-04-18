unit fpdev.fpc.installer.lifecycleflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.config,
  fpdev.paths,
  fpdev.fpc.interfaces,
  fpdev.fpc.types;

type
  TFPCInstallerValidateVersionFunc = function(const AVersion: string): Boolean of object;
  TFPCInstallerDirectoryExistsFunc = function(const APath: string): Boolean of object;
  TFPCInstallerDownloadSourceFunc = function(const AVersion,
    ATargetDir: string): TOperationResult of object;
  TFPCInstallerBuildFromSourceFunc = function(const ASourceDir,
    AInstallDir: string): TOperationResult of object;
  TFPCInstallerExecuteProcessFunc = function(const AExecutable: string;
    const AParams: array of string; const AWorkDir: string): TProcessResult of object;

  TFPCInstallerInstallState = record
    Version: string;
    InstallRoot: string;
    Prefix: string;
    FromSource: Boolean;
    Ensure: Boolean;
  end;

  TFPCInstallerProcessPlan = record
    Executable: string;
    Params: array of string;
    WorkDir: string;
  end;

function ResolveFPCInstallerInstallRootCore(
  const ASettings: TFPDevSettings
): string;
function ResolveFPCInstallerVersionInstallDirCore(
  const AInstallRoot, AVersion: string
): string;
function ResolveFPCInstallerInstallPathCore(
  const AInstallRoot, AVersion, APrefix: string
): string;
function ResolveFPCInstallerSourceDirCore(
  const AInstallRoot, AVersion: string
): string;
function CreateFPCInstallerUninstallPlanCore(
  const AInstallDir: string
): TFPCInstallerProcessPlan;
function ExecuteFPCInstallerInstallCore(
  const AState: TFPCInstallerInstallState;
  AValidateVersion: TFPCInstallerValidateVersionFunc;
  ADirectoryExists: TFPCInstallerDirectoryExistsFunc;
  ADownloadSource: TFPCInstallerDownloadSourceFunc;
  ABuildFromSource: TFPCInstallerBuildFromSourceFunc
): TOperationResult;
function ExecuteFPCInstallerUninstallCore(
  const AVersion, AInstallDir: string;
  ADirectoryExists: TFPCInstallerDirectoryExistsFunc;
  AExecuteProcess: TFPCInstallerExecuteProcessFunc
): TOperationResult;

implementation

uses
  SysUtils;

function JoinInstallRoot(const AInstallRoot, ASuffix: string): string;
begin
  Result := ExcludeTrailingPathDelimiter(AInstallRoot);
  if Result = '' then
    Result := PathDelim;

  if (Result <> PathDelim) and (ASuffix <> '') and (ASuffix[1] <> PathDelim) then
    Result := Result + PathDelim;

  Result := Result + ASuffix;
end;

function ResolveFPCInstallerInstallRootCore(
  const ASettings: TFPDevSettings
): string;
begin
  Result := ASettings.InstallRoot;
  if Result = '' then
    Result := GetDataRoot;
end;

function ResolveFPCInstallerVersionInstallDirCore(
  const AInstallRoot, AVersion: string
): string;
begin
  Result := JoinInstallRoot(AInstallRoot, 'fpc' + PathDelim + AVersion);
end;

function ResolveFPCInstallerInstallPathCore(
  const AInstallRoot, AVersion, APrefix: string
): string;
begin
  if APrefix <> '' then
    Exit(APrefix);

  Result := ResolveFPCInstallerVersionInstallDirCore(AInstallRoot, AVersion);
end;

function ResolveFPCInstallerSourceDirCore(
  const AInstallRoot, AVersion: string
): string;
begin
  Result := JoinInstallRoot(AInstallRoot, 'sources' + PathDelim + 'fpc-' + AVersion);
end;

function CreateFPCInstallerUninstallPlanCore(
  const AInstallDir: string
): TFPCInstallerProcessPlan;
begin
  Result.WorkDir := '';
  {$IFDEF MSWINDOWS}
  Result.Executable := 'cmd';
  SetLength(Result.Params, 5);
  Result.Params[0] := '/c';
  Result.Params[1] := 'rmdir';
  Result.Params[2] := '/s';
  Result.Params[3] := '/q';
  Result.Params[4] := AInstallDir;
  {$ELSE}
  Result.Executable := 'rm';
  SetLength(Result.Params, 2);
  Result.Params[0] := '-rf';
  Result.Params[1] := AInstallDir;
  {$ENDIF}
end;

function ExecuteFPCInstallerInstallCore(
  const AState: TFPCInstallerInstallState;
  AValidateVersion: TFPCInstallerValidateVersionFunc;
  ADirectoryExists: TFPCInstallerDirectoryExistsFunc;
  ADownloadSource: TFPCInstallerDownloadSourceFunc;
  ABuildFromSource: TFPCInstallerBuildFromSourceFunc
): TOperationResult;
var
  UseSourceFlow: Boolean;
  InstallPath: string;
  SourceDir: string;
begin
  if Assigned(AValidateVersion) and (not AValidateVersion(AState.Version)) then
    Exit(OperationError(ecVersionInvalid, 'Invalid version: ' + AState.Version));

  InstallPath := ResolveFPCInstallerInstallPathCore(
    AState.InstallRoot,
    AState.Version,
    AState.Prefix
  );

  if Assigned(ADirectoryExists) and ADirectoryExists(InstallPath) then
  begin
    if AState.Ensure then
      Exit(OperationSuccess);

    Exit(OperationError(ecVersionAlreadyInstalled,
      'Version already installed: ' + AState.Version));
  end;

  UseSourceFlow := AState.FromSource;
  if not UseSourceFlow then
  begin
    // The DI installer keeps binary-mode requests on the source path.
    UseSourceFlow := True;
  end;

  SourceDir := ResolveFPCInstallerSourceDirCore(AState.InstallRoot, AState.Version);

  if UseSourceFlow and Assigned(ADirectoryExists) and
     (not ADirectoryExists(SourceDir)) and Assigned(ADownloadSource) then
  begin
    Result := ADownloadSource(AState.Version, SourceDir);
    if not Result.Success then
      Exit;
  end;

  if UseSourceFlow and Assigned(ABuildFromSource) then
  begin
    Result := ABuildFromSource(SourceDir, InstallPath);
    if not Result.Success then
      Exit;
  end;

  Result := OperationSuccess;
end;

function ExecuteFPCInstallerUninstallCore(
  const AVersion, AInstallDir: string;
  ADirectoryExists: TFPCInstallerDirectoryExistsFunc;
  AExecuteProcess: TFPCInstallerExecuteProcessFunc
): TOperationResult;
var
  Plan: TFPCInstallerProcessPlan;
  ProcResult: TProcessResult;
begin
  if Assigned(ADirectoryExists) and (not ADirectoryExists(AInstallDir)) then
    Exit(OperationSuccess);

  Plan := CreateFPCInstallerUninstallPlanCore(AInstallDir);

  if Assigned(AExecuteProcess) then
  begin
    ProcResult := AExecuteProcess(Plan.Executable, Plan.Params, Plan.WorkDir);
    if not ProcResult.Success then
      Exit(OperationError(ecUninstallationFailed,
        'Failed to remove directory: ' + AInstallDir));
  end;

  Result := OperationSuccess;
end;

end.
