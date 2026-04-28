program test_resource_repo_bootstrapflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.resource.repo.bootstrapflow,
  fpdev.resource.repo.types,
  test_temp_paths;

type
  TBootstrapFlowProbe = class
  public
    RequiredVersion: string;
    RequiredCalls: Integer;
    ListCalls: Integer;
    HasCalls: Integer;
    InfoCalls: Integer;
    InstallCalls: Integer;
    LastInfoVersion: string;
    LastInfoPlatform: string;
    LastInstallVersion: string;
    LastInstallPlatform: string;
    LastInstallDestDir: string;
    LogCalls: Integer;
    LogFmtCalls: Integer;
    LastLog: string;
    AvailableVersions: TStringArray;
    InstallResult: Boolean;
    InfoResult: Boolean;
    function GetRequiredBootstrapVersion(const AFPCVersion: string): string;
    function ListBootstrapVersions: SysUtils.TStringArray;
    function HasBootstrapCompiler(const AVersion, APlatform: string): Boolean;
    function GetBootstrapInfo(const AVersion, APlatform: string;
      out AInfo: TPlatformInfo): Boolean;
    function InstallBootstrap(const AInfo: TPlatformInfo;
      const AVersion, APlatform, ADestDir: string): Boolean;
    procedure Log(const AMsg: string);
    procedure LogFmt(const AFormat: string; const AArgs: array of const);
  end;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

procedure Pass(const AName: string);
begin
  WriteLn('[PASS] ', AName);
  Inc(PassCount);
end;

procedure Fail(const AName, AReason: string);
begin
  WriteLn('[FAIL] ', AName, ': ', AReason);
  Inc(FailCount);
end;

procedure Check(const AName: string; ACondition: Boolean; const AReason: string = '');
begin
  if ACondition then
    Pass(AName)
  else
    Fail(AName, AReason);
end;

function TBootstrapFlowProbe.GetRequiredBootstrapVersion(const AFPCVersion: string): string;
begin
  if AFPCVersion = '' then;
  Inc(RequiredCalls);
  Result := RequiredVersion;
end;

function TBootstrapFlowProbe.ListBootstrapVersions: SysUtils.TStringArray;
begin
  Inc(ListCalls);
  Result := AvailableVersions;
end;

function TBootstrapFlowProbe.HasBootstrapCompiler(const AVersion, APlatform: string): Boolean;
begin
  if APlatform = '' then;
  Inc(HasCalls);
  Result := AVersion = '3.2.0';
end;

function TBootstrapFlowProbe.GetBootstrapInfo(const AVersion, APlatform: string;
  out AInfo: TPlatformInfo): Boolean;
begin
  Inc(InfoCalls);
  LastInfoVersion := AVersion;
  LastInfoPlatform := APlatform;
  AInfo := EmptyPlatformInfo;
  if InfoResult then
  begin
    AInfo.Path := 'bootstrap/' + AVersion;
    AInfo.Executable := 'bin/ppcx64';
  end;
  Result := InfoResult;
end;

function TBootstrapFlowProbe.InstallBootstrap(const AInfo: TPlatformInfo;
  const AVersion, APlatform, ADestDir: string): Boolean;
begin
  if AInfo.Executable = '' then;
  Inc(InstallCalls);
  LastInstallVersion := AVersion;
  LastInstallPlatform := APlatform;
  LastInstallDestDir := ADestDir;
  Result := InstallResult;
end;

procedure TBootstrapFlowProbe.Log(const AMsg: string);
begin
  Inc(LogCalls);
  LastLog := AMsg;
end;

procedure TBootstrapFlowProbe.LogFmt(const AFormat: string; const AArgs: array of const);
begin
  Inc(LogFmtCalls);
  LastLog := Format(AFormat, AArgs);
end;

procedure TestFindBestBootstrapVersionFallsBackAndLogs;
var
  Probe: TBootstrapFlowProbe;
  ResultVersion: string;
begin
  Probe := TBootstrapFlowProbe.Create;
  try
    Probe.RequiredVersion := '3.2.2';
    SetLength(Probe.AvailableVersions, 2);
    Probe.AvailableVersions[0] := '3.2.2';
    Probe.AvailableVersions[1] := '3.2.0';

    ResultVersion := ExecuteResourceRepoFindBestBootstrapVersionCore(
      '3.3.1', 'linux-x86_64',
      @Probe.GetRequiredBootstrapVersion,
      @Probe.ListBootstrapVersions,
      @Probe.HasBootstrapCompiler,
      @Probe.Log
    );

    Check('bootstrap flow falls back to available compiler version',
      ResultVersion = '3.2.0',
      ResultVersion);
    Check('bootstrap flow queries required version once',
      Probe.RequiredCalls = 1,
      'calls=' + IntToStr(Probe.RequiredCalls));
    Check('bootstrap flow queries version list once',
      Probe.ListCalls = 1,
      'calls=' + IntToStr(Probe.ListCalls));
    Check('bootstrap flow logs fallback note',
      Pos('fallback', LowerCase(Probe.LastLog)) > 0,
      Probe.LastLog);
  finally
    Probe.Free;
  end;
end;

procedure TestVerifyChecksumSkipsEmptyExpectedHash;
var
  Probe: TBootstrapFlowProbe;
  TempRoot: string;
  FilePath: string;
begin
  TempRoot := CreateUniqueTempDir('test_resource_repo_bootstrapflow_skip');
  Probe := TBootstrapFlowProbe.Create;
  try
    FilePath := TempRoot + PathDelim + 'archive.tar.gz';
    with TStringList.Create do
    try
      Add('bootstrap data');
      SaveToFile(FilePath);
    finally
      Free;
    end;

    Check('bootstrap flow checksum helper skips empty checksum',
      ExecuteResourceRepoVerifyChecksumCore(FilePath, '', @Probe.Log, @Probe.LogFmt),
      'expected success');
    Check('bootstrap flow checksum helper logs warning for empty checksum',
      Pos('skipping verification', LowerCase(Probe.LastLog)) > 0,
      Probe.LastLog);
  finally
    Probe.Free;
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestVerifyChecksumReportsMismatch;
var
  Probe: TBootstrapFlowProbe;
  TempRoot: string;
  FilePath: string;
begin
  TempRoot := CreateUniqueTempDir('test_resource_repo_bootstrapflow_mismatch');
  Probe := TBootstrapFlowProbe.Create;
  try
    FilePath := TempRoot + PathDelim + 'archive.tar.gz';
    with TStringList.Create do
    try
      Add('bootstrap data mismatch');
      SaveToFile(FilePath);
    finally
      Free;
    end;

    Check('bootstrap flow checksum helper rejects mismatch',
      not ExecuteResourceRepoVerifyChecksumCore(
        FilePath,
        '0000000000000000000000000000000000000000000000000000000000000000',
        @Probe.Log,
        @Probe.LogFmt
      ),
      'expected mismatch');
    Check('bootstrap flow checksum helper emits detailed mismatch logs',
      Probe.LogFmtCalls >= 3,
      'log fmt calls=' + IntToStr(Probe.LogFmtCalls));
  finally
    Probe.Free;
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestInstallBootstrapSurfaceLogsMissingInfo;
var
  Probe: TBootstrapFlowProbe;
begin
  Probe := TBootstrapFlowProbe.Create;
  try
    Probe.InfoResult := False;
    Probe.InstallResult := True;

    Check('bootstrap flow install surface returns false when info missing',
      not ExecuteResourceRepoInstallBootstrapCore(
        '3.2.2', 'linux-x86_64', '/tmp/bootstrap',
        @Probe.GetBootstrapInfo, @Probe.InstallBootstrap, @Probe.Log
      ),
      'expected false');
    Check('bootstrap flow install surface logs missing info',
      Pos('not found', LowerCase(Probe.LastLog)) > 0,
      Probe.LastLog);
    Check('bootstrap flow install surface skips installer when info missing',
      Probe.InstallCalls = 0,
      'calls=' + IntToStr(Probe.InstallCalls));
  finally
    Probe.Free;
  end;
end;

procedure TestInstallBootstrapSurfacePassesResolvedInfoToInstaller;
var
  Probe: TBootstrapFlowProbe;
begin
  Probe := TBootstrapFlowProbe.Create;
  try
    Probe.InfoResult := True;
    Probe.InstallResult := True;

    Check('bootstrap flow install surface delegates to installer when info resolves',
      ExecuteResourceRepoInstallBootstrapCore(
        '3.2.2', 'linux-x86_64', '/tmp/bootstrap',
        @Probe.GetBootstrapInfo, @Probe.InstallBootstrap, @Probe.Log
      ),
      'expected success');
    Check('bootstrap flow install surface forwards version',
      Probe.LastInstallVersion = '3.2.2',
      Probe.LastInstallVersion);
    Check('bootstrap flow install surface forwards platform',
      Probe.LastInstallPlatform = 'linux-x86_64',
      Probe.LastInstallPlatform);
    Check('bootstrap flow install surface forwards destination',
      Probe.LastInstallDestDir = '/tmp/bootstrap',
      Probe.LastInstallDestDir);
  finally
    Probe.Free;
  end;
end;

begin
  TestFindBestBootstrapVersionFallsBackAndLogs;
  TestVerifyChecksumSkipsEmptyExpectedHash;
  TestVerifyChecksumReportsMismatch;
  TestInstallBootstrapSurfaceLogsMissingInfo;
  TestInstallBootstrapSurfacePassesResolvedInfoToInstaller;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
