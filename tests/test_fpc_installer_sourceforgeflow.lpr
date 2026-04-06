program test_fpc_installer_sourceforgeflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf,
  fpdev.fpc.installer.downloadflow,
  fpdev.fpc.installer.sourceforgeflow,
  test_temp_paths;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;
  GTempRoot: string;

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

type
  TStringOutput = class(TInterfacedObject, IOutput)
  private
    FBuffer: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Write(const S: string);
    procedure WriteLn; overload;
    procedure WriteLn(const S: string); overload;
    procedure WriteFmt(const Fmt: string; const Args: array of const);
    procedure WriteLnFmt(const Fmt: string; const Args: array of const);
    procedure WriteColored(const S: string; const AColor: TConsoleColor);
    procedure WriteLnColored(const S: string; const AColor: TConsoleColor);
    procedure WriteStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
    procedure WriteLnStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
    procedure WriteSuccess(const S: string);
    procedure WriteError(const S: string);
    procedure WriteWarning(const S: string);
    procedure WriteInfo(const S: string);
    function SupportsColor: Boolean;
    function Contains(const S: string): Boolean;
  end;

constructor TStringOutput.Create;
begin
  inherited Create;
  FBuffer := TStringList.Create;
end;

destructor TStringOutput.Destroy;
begin
  FBuffer.Free;
  inherited Destroy;
end;

procedure TStringOutput.Write(const S: string);
begin
  if FBuffer.Count = 0 then
    FBuffer.Add(S)
  else
    FBuffer[FBuffer.Count - 1] := FBuffer[FBuffer.Count - 1] + S;
end;

procedure TStringOutput.WriteLn;
begin
  FBuffer.Add('');
end;

procedure TStringOutput.WriteLn(const S: string);
begin
  FBuffer.Add(S);
end;

procedure TStringOutput.WriteFmt(const Fmt: string; const Args: array of const);
begin
  Write(Format(Fmt, Args));
end;

procedure TStringOutput.WriteLnFmt(const Fmt: string; const Args: array of const);
begin
  WriteLn(Format(Fmt, Args));
end;

procedure TStringOutput.WriteColored(const S: string; const AColor: TConsoleColor);
begin
  Write(S);
  if AColor = ccDefault then;
end;

procedure TStringOutput.WriteLnColored(const S: string; const AColor: TConsoleColor);
begin
  WriteLn(S);
  if AColor = ccDefault then;
end;

procedure TStringOutput.WriteStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
begin
  Write(S);
  if AColor = ccDefault then;
  if AStyle = csNone then;
end;

procedure TStringOutput.WriteLnStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
begin
  WriteLn(S);
  if AColor = ccDefault then;
  if AStyle = csNone then;
end;

procedure TStringOutput.WriteSuccess(const S: string); begin WriteLn(S); end;
procedure TStringOutput.WriteError(const S: string); begin WriteLn(S); end;
procedure TStringOutput.WriteWarning(const S: string); begin WriteLn(S); end;
procedure TStringOutput.WriteInfo(const S: string); begin WriteLn(S); end;
function TStringOutput.SupportsColor: Boolean; begin Result := False; end;

function TStringOutput.Contains(const S: string): Boolean;
begin
  Result := Pos(S, FBuffer.Text) > 0;
end;

type
  TSourceForgeProbe = class
  public
    DownloadShouldSucceed: Boolean;
    ExtractShouldSucceed: Boolean;
    CreateInstallBin: Boolean;
    DownloadCalls: Integer;
    ExtractCalls: Integer;
    LastVersion: string;
    LastTempFile: string;
    LastTempDir: string;
    LastInstallPath: string;
    UseLegacyDownloadPlan: Boolean;
    LegacyDownloadPlan: TFPCLegacyBinaryDownloadPlan;
    function DownloadBinary(const AVersion: string; out ATempFile: string): Boolean;
    function ExtractLinux(const ATempFile, ATempDir, AInstallPath: string): Boolean;
  end;

function TSourceForgeProbe.DownloadBinary(const AVersion: string; out ATempFile: string): Boolean;
var
  Err: string;
begin
  Inc(DownloadCalls);
  LastVersion := AVersion;
  if not DownloadShouldSucceed then
  begin
    ATempFile := '';
    Exit(False);
  end;

  if UseLegacyDownloadPlan then
  begin
    Err := '';
    if not PrepareFPCLegacyBinaryDownloadPlan(AVersion, LegacyDownloadPlan, Err) then
    begin
      ATempFile := '';
      Exit(False);
    end;
    ATempFile := LegacyDownloadPlan.TempFile;
  end
  else
    ATempFile := GTempRoot + PathDelim + 'fpc-' + AVersion + '.tar';

  with TStringList.Create do
  try
    Add('fake archive');
    SaveToFile(ATempFile);
  finally
    Free;
  end;
  LastTempFile := ATempFile;
  Result := True;
end;

function TSourceForgeProbe.ExtractLinux(const ATempFile, ATempDir, AInstallPath: string): Boolean;
begin
  Inc(ExtractCalls);
  LastTempFile := ATempFile;
  LastTempDir := ATempDir;
  LastInstallPath := AInstallPath;

  if CreateInstallBin then
  begin
    ForceDirectories(AInstallPath + PathDelim + 'bin');
    with TStringList.Create do
    try
      Add('#!/bin/sh');
      SaveToFile(AInstallPath + PathDelim + 'bin' + PathDelim + 'fpc');
    finally
      Free;
    end;
  end;

  Result := ExtractShouldSucceed;
end;

procedure TestSourceForgeFlowSuccess;
var
  Probe: TSourceForgeProbe;
  OutBuf, ErrBuf: TStringOutput;
  InstallDir: string;
  OK: Boolean;
begin
  Probe := TSourceForgeProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  InstallDir := CreateUniqueTempDir('test_sf_success_install');
  try
    Probe.DownloadShouldSucceed := True;
    Probe.ExtractShouldSucceed := True;
    Probe.CreateInstallBin := True;

    OK := ExecuteFPCSourceForgeInstallFlow('3.2.2', InstallDir, OutBuf, ErrBuf,
      @Probe.DownloadBinary, @Probe.ExtractLinux);

    Check('sourceforge success returns true', OK, 'expected success');
    Check('download called once', Probe.DownloadCalls = 1,
      'download calls=' + IntToStr(Probe.DownloadCalls));
    Check('extract called once', Probe.ExtractCalls = 1,
      'extract calls=' + IntToStr(Probe.ExtractCalls));
    Check('passes version to download', Probe.LastVersion = '3.2.2',
      'version=' + Probe.LastVersion);
    Check('extract temp dir uses system temp root', PathUsesSystemTempRoot(Probe.LastTempDir),
      'temp dir=' + Probe.LastTempDir);
    Check('downloaded archive removed after success', not FileExists(Probe.LastTempFile),
      'temp file should be deleted');
    Check('extract temp dir removed after success', not DirectoryExists(Probe.LastTempDir),
      'temp dir should be deleted');
    Check('success output verifies installation', OutBuf.Contains('Installation verified'),
      'verification output missing');
    Check('success keeps stderr quiet', not ErrBuf.Contains('Failed'),
      'unexpected stderr failure');
  finally
    CleanupTempDir(InstallDir);
    Probe.Free;
  end;
end;

procedure TestSourceForgeFlowSuccessRemovesEmptyLegacyDownloadDir;
var
  Probe: TSourceForgeProbe;
  OutBuf, ErrBuf: TStringOutput;
  InstallDir: string;
  OK: Boolean;
begin
  Probe := TSourceForgeProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  InstallDir := CreateUniqueTempDir('test_sf_success_legacy_install');
  try
    Probe.DownloadShouldSucceed := True;
    Probe.ExtractShouldSucceed := True;
    Probe.CreateInstallBin := True;
    Probe.UseLegacyDownloadPlan := True;

    OK := ExecuteFPCSourceForgeInstallFlow('3.2.2', InstallDir, OutBuf, ErrBuf,
      @Probe.DownloadBinary, @Probe.ExtractLinux);

    Check('legacy success returns true', OK, 'expected success');
    Check('legacy success removes empty download dir',
      not DirectoryExists(Probe.LegacyDownloadPlan.TempDir),
      'download dir should be deleted');
  finally
    CleanupTempDir(InstallDir);
    if DirectoryExists(Probe.LegacyDownloadPlan.TempDir) then
      CleanupTempDir(Probe.LegacyDownloadPlan.TempDir);
    Probe.Free;
  end;
end;

procedure TestSourceForgeFlowDownloadFailure;
var
  Probe: TSourceForgeProbe;
  OutBuf, ErrBuf: TStringOutput;
  InstallDir: string;
  OK: Boolean;
begin
  Probe := TSourceForgeProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  InstallDir := CreateUniqueTempDir('test_sf_download_fail');
  try
    Probe.DownloadShouldSucceed := False;
    Probe.ExtractShouldSucceed := True;

    OK := ExecuteFPCSourceForgeInstallFlow('3.2.2', InstallDir, OutBuf, ErrBuf,
      @Probe.DownloadBinary, @Probe.ExtractLinux);

    Check('download failure returns false', not OK, 'expected failure');
    Check('download failure skips extract', Probe.ExtractCalls = 0,
      'extract calls=' + IntToStr(Probe.ExtractCalls));
    Check('download failure reports error', ErrBuf.Contains('Failed to download FPC binary'),
      'missing download failure message');
  finally
    CleanupTempDir(InstallDir);
    Probe.Free;
  end;
end;

procedure TestSourceForgeFlowExtractFailureKeepsArchive;
var
  Probe: TSourceForgeProbe;
  OutBuf, ErrBuf: TStringOutput;
  InstallDir: string;
  OK: Boolean;
begin
  Probe := TSourceForgeProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  InstallDir := CreateUniqueTempDir('test_sf_extract_fail');
  try
    Probe.DownloadShouldSucceed := True;
    Probe.ExtractShouldSucceed := False;
    Probe.CreateInstallBin := False;
    Probe.UseLegacyDownloadPlan := True;

    OK := ExecuteFPCSourceForgeInstallFlow('3.2.2', InstallDir, OutBuf, ErrBuf,
      @Probe.DownloadBinary, @Probe.ExtractLinux);

    Check('extract failure returns false', not OK, 'expected failure');
    Check('extract temp dir removed after failure', not DirectoryExists(Probe.LastTempDir),
      'temp dir should be deleted');
    Check('extract failure keeps downloaded archive', FileExists(Probe.LastTempFile),
      'archive should remain for inspection');
  finally
    if FileExists(Probe.LastTempFile) then
      DeleteFile(Probe.LastTempFile);
    CleanupTempDir(InstallDir);
    if DirectoryExists(Probe.LegacyDownloadPlan.TempDir) then
      CleanupTempDir(Probe.LegacyDownloadPlan.TempDir);
    Probe.Free;
  end;
end;

procedure TestSourceForgeFlowVerifyFailureShowsGuidance;
var
  Probe: TSourceForgeProbe;
  OutBuf, ErrBuf: TStringOutput;
  InstallDir: string;
  OK: Boolean;
begin
  Probe := TSourceForgeProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  InstallDir := CreateUniqueTempDir('test_sf_verify_fail');
  try
    Probe.DownloadShouldSucceed := True;
    Probe.ExtractShouldSucceed := True;
    Probe.CreateInstallBin := False;
    Probe.UseLegacyDownloadPlan := True;

    OK := ExecuteFPCSourceForgeInstallFlow('3.2.2', InstallDir, OutBuf, ErrBuf,
      @Probe.DownloadBinary, @Probe.ExtractLinux);

    Check('verify failure returns false', not OK, 'expected failure');
    Check('verify failure removes downloaded archive', not FileExists(Probe.LastTempFile),
      'archive should be deleted after verification step');
    Check('verify failure removes empty download dir',
      not DirectoryExists(Probe.LegacyDownloadPlan.TempDir),
      'download dir should be deleted after archive cleanup');
    Check('verify failure prints guidance block', ErrBuf.Contains('Binary Installation Failed'),
      'guidance header missing');
    Check('verify failure suggests from-source', ErrBuf.Contains('--from-source'),
      'from-source guidance missing');
  finally
    CleanupTempDir(InstallDir);
    if DirectoryExists(Probe.LegacyDownloadPlan.TempDir) then
      CleanupTempDir(Probe.LegacyDownloadPlan.TempDir);
    Probe.Free;
  end;
end;

begin
  WriteLn('=== FPC Installer SourceForge Flow Tests ===');
  GTempRoot := CreateUniqueTempDir('test_sf_flow_root');
  try
    TestSourceForgeFlowSuccess;
    TestSourceForgeFlowSuccessRemovesEmptyLegacyDownloadDir;
    TestSourceForgeFlowDownloadFailure;
    TestSourceForgeFlowExtractFailureKeepsArchive;
    TestSourceForgeFlowVerifyFailureShowsGuidance;
  finally
    CleanupTempDir(GTempRoot);
  end;

  WriteLn;
  WriteLn('Total: ', PassCount + FailCount);
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
