unit fpdev.resource.repo.bootstrapflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.resource.repo.types;

type
  TResourceRepoBootstrapLogProc = procedure(const AMsg: string) of object;
  TResourceRepoBootstrapLogFmtProc = procedure(const AFormat: string;
    const AArgs: array of const) of object;
  TResourceRepoBootstrapRequiredVersionGetter = function(
    const AFPCVersion: string): string of object;
  TResourceRepoBootstrapVersionsGetter = function: SysUtils.TStringArray of object;
  TResourceRepoBootstrapAvailabilityChecker = function(
    const AVersion, APlatform: string): Boolean of object;
  TResourceRepoBootstrapInfoGetter = function(const AVersion, APlatform: string;
    out AInfo: TPlatformInfo): Boolean of object;
  TResourceRepoBootstrapInstaller = function(const AInfo: TPlatformInfo;
    const AVersion, APlatform, ADestDir: string): Boolean of object;

function ExecuteResourceRepoFindBestBootstrapVersionCore(
  const AFPCVersion, APlatform: string;
  AGetRequiredBootstrapVersion: TResourceRepoBootstrapRequiredVersionGetter;
  AListBootstrapVersions: TResourceRepoBootstrapVersionsGetter;
  AHasBootstrapCompiler: TResourceRepoBootstrapAvailabilityChecker;
  ALog: TResourceRepoBootstrapLogProc
): string;

function ExecuteResourceRepoVerifyChecksumCore(
  const AFile, AExpectedSHA256: string;
  ALog: TResourceRepoBootstrapLogProc;
  ALogFmt: TResourceRepoBootstrapLogFmtProc
): Boolean;

function ExecuteResourceRepoInstallBootstrapCore(
  const AVersion, APlatform, ADestDir: string;
  AGetBootstrapInfo: TResourceRepoBootstrapInfoGetter;
  AInstallBootstrap: TResourceRepoBootstrapInstaller;
  ALog: TResourceRepoBootstrapLogProc
): Boolean;

implementation

uses
  fpdev.resource.repo.bootstrap,
  fpdev.utils.process;

function ExtractSHA256Value(const AStdOut: string): string;
var
  SeparatorPos: SizeInt;
begin
  Result := Trim(AStdOut);
  SeparatorPos := Pos(' ', Result);
  if SeparatorPos > 0 then
    Result := Trim(Copy(Result, 1, SeparatorPos - 1));
end;

function ExecuteResourceRepoFindBestBootstrapVersionCore(
  const AFPCVersion, APlatform: string;
  AGetRequiredBootstrapVersion: TResourceRepoBootstrapRequiredVersionGetter;
  AListBootstrapVersions: TResourceRepoBootstrapVersionsGetter;
  AHasBootstrapCompiler: TResourceRepoBootstrapAvailabilityChecker;
  ALog: TResourceRepoBootstrapLogProc
): string;
var
  RequiredVersion: string;
  AvailableVersions: SysUtils.TStringArray;
  LogLines: SysUtils.TStringArray;
  Index: Integer;
begin
  RequiredVersion := '';
  AvailableVersions := nil;
  LogLines := nil;

  if Assigned(AGetRequiredBootstrapVersion) then
    RequiredVersion := AGetRequiredBootstrapVersion(AFPCVersion);
  if Assigned(AListBootstrapVersions) then
    AvailableVersions := AListBootstrapVersions();

  Result := SelectBestBootstrapVersionCore(
    RequiredVersion,
    APlatform,
    AvailableVersions,
    AHasBootstrapCompiler,
    LogLines
  );

  if Assigned(ALog) then
    for Index := 0 to High(LogLines) do
      ALog(LogLines[Index]);
end;

function ExecuteResourceRepoVerifyChecksumCore(
  const AFile, AExpectedSHA256: string;
  ALog: TResourceRepoBootstrapLogProc;
  ALogFmt: TResourceRepoBootstrapLogFmtProc
): Boolean;
var
  ProcessResult: TProcessResult;
  ActualSHA256: string;
begin
  Result := False;

  if AExpectedSHA256 = '' then
  begin
    if Assigned(ALog) then
      ALog('Warning: No checksum provided, skipping verification');
    Exit(True);
  end;

  ProcessResult := TProcessExecutor.Execute('sha256sum', [AFile], '');
  if ProcessResult.Success then
  begin
    ActualSHA256 := ExtractSHA256Value(ProcessResult.StdOut);
    Result := SameText(ActualSHA256, AExpectedSHA256);

    if Result then
    begin
      if Assigned(ALogFmt) then
        ALogFmt('Checksum verified: %s', [AFile]);
    end
    else if Assigned(ALogFmt) then
    begin
      ALogFmt('Checksum mismatch for: %s', [AFile]);
      ALogFmt('  Expected: %s', [AExpectedSHA256]);
      ALogFmt('  Got:      %s', [ActualSHA256]);
    end;
  end
  else if (ProcessResult.ErrorMessage <> '') and Assigned(ALogFmt) then
    ALogFmt('Error verifying checksum: %s', [ProcessResult.ErrorMessage]);
end;

function ExecuteResourceRepoInstallBootstrapCore(
  const AVersion, APlatform, ADestDir: string;
  AGetBootstrapInfo: TResourceRepoBootstrapInfoGetter;
  AInstallBootstrap: TResourceRepoBootstrapInstaller;
  ALog: TResourceRepoBootstrapLogProc
): Boolean;
var
  Info: TPlatformInfo;
begin
  Result := False;
  if (not Assigned(AGetBootstrapInfo)) or
     (not Assigned(AInstallBootstrap)) then
    Exit(False);

  if not AGetBootstrapInfo(AVersion, APlatform, Info) then
  begin
    if Assigned(ALog) then
      ALog('Error: Bootstrap compiler info not found');
    Exit(False);
  end;

  Result := AInstallBootstrap(Info, AVersion, APlatform, ADestDir);
end;

end.
