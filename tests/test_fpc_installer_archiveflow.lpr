program test_fpc_installer_archiveflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf,
  fpdev.fpc.installer.archiveflow,
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
  TArchiveFlowProbe = class
  public
    ZipSuccess: Boolean;
    ZipEntries: Integer;
    TarSuccess: Boolean;
    TarExitCode: Integer;
    TarGzSuccess: Boolean;
    TarGzExitCode: Integer;
    ZipCalls: Integer;
    TarCalls: Integer;
    TarGzCalls: Integer;
    function ExtractZip(const AArchivePath, ADestPath: string; out AEntryCount: Integer): Boolean;
    function ExtractTar(const AArchivePath, ADestPath: string; out AExitCode: Integer): Boolean;
    function ExtractTarGz(const AArchivePath, ADestPath: string; out AExitCode: Integer): Boolean;
  end;

function TArchiveFlowProbe.ExtractZip(const AArchivePath, ADestPath: string; out AEntryCount: Integer): Boolean;
begin
  Inc(ZipCalls);
  AEntryCount := ZipEntries;
  Result := ZipSuccess;
end;

function TArchiveFlowProbe.ExtractTar(const AArchivePath, ADestPath: string; out AExitCode: Integer): Boolean;
begin
  Inc(TarCalls);
  AExitCode := TarExitCode;
  Result := TarSuccess;
end;

function TArchiveFlowProbe.ExtractTarGz(const AArchivePath, ADestPath: string; out AExitCode: Integer): Boolean;
begin
  Inc(TarGzCalls);
  AExitCode := TarGzExitCode;
  Result := TarGzSuccess;
end;

procedure CreateDummyFile(const APath: string);
begin
  with TStringList.Create do
  try
    Add('dummy');
    SaveToFile(APath);
  finally
    Free;
  end;
end;

procedure TestMissingArchiveFailsFast;
var
  Probe: TArchiveFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  DestDir: string;
begin
  Probe := TArchiveFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  DestDir := CreateUniqueTempDir('test_archive_missing_dest');
  try
    Check('missing archive returns false',
      not ExecuteFPCInstallerArchiveFlow(GTempRoot + PathDelim + 'missing.tar', DestDir,
        OutBuf, ErrBuf, @Probe.ExtractZip, @Probe.ExtractTar, @Probe.ExtractTarGz),
      'expected failure');
    Check('missing archive skips handlers', (Probe.ZipCalls = 0) and (Probe.TarCalls = 0) and (Probe.TarGzCalls = 0),
      'handlers should not run');
    Check('missing archive reports file not found', ErrBuf.Contains('Archive file not found'),
      'missing file error absent');
  finally
    CleanupTempDir(DestDir);
    Probe.Free;
  end;
end;

procedure TestZipDispatch;
var
  Probe: TArchiveFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  ArchivePath, DestDir: string;
begin
  Probe := TArchiveFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  ArchivePath := GTempRoot + PathDelim + 'archive.zip';
  DestDir := CreateUniqueTempDir('test_archive_zip_dest');
  CreateDummyFile(ArchivePath);
  try
    Probe.ZipSuccess := True;
    Probe.ZipEntries := 3;
    Check('zip dispatch succeeds',
      ExecuteFPCInstallerArchiveFlow(ArchivePath, DestDir, OutBuf, ErrBuf,
        @Probe.ExtractZip, @Probe.ExtractTar, @Probe.ExtractTarGz),
      'expected zip success');
    Check('zip handler called once', Probe.ZipCalls = 1,
      'zip calls=' + IntToStr(Probe.ZipCalls));
    Check('zip output includes entry count', OutBuf.Contains('Files in archive: 3'),
      'entry count missing');
    Check('zip output includes success message', OutBuf.Contains('Extraction completed successfully'),
      'success message missing');
  finally
    CleanupTempDir(DestDir);
    DeleteFile(ArchivePath);
    Probe.Free;
  end;
end;

procedure TestTarFailureReportsExitCode;
var
  Probe: TArchiveFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  ArchivePath, DestDir: string;
begin
  Probe := TArchiveFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  ArchivePath := GTempRoot + PathDelim + 'archive.tar';
  DestDir := CreateUniqueTempDir('test_archive_tar_dest');
  CreateDummyFile(ArchivePath);
  try
    Probe.TarSuccess := False;
    Probe.TarExitCode := 2;
    Check('tar failure returns false',
      not ExecuteFPCInstallerArchiveFlow(ArchivePath, DestDir, OutBuf, ErrBuf,
        @Probe.ExtractZip, @Probe.ExtractTar, @Probe.ExtractTarGz),
      'expected tar failure');
    Check('tar handler called once', Probe.TarCalls = 1,
      'tar calls=' + IntToStr(Probe.TarCalls));
    Check('tar failure reports exit code', ErrBuf.Contains('exit code: 2'),
      'exit code message missing');
  finally
    CleanupTempDir(DestDir);
    DeleteFile(ArchivePath);
    Probe.Free;
  end;
end;

procedure TestTarGzDispatch;
var
  Probe: TArchiveFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  ArchivePath, DestDir: string;
begin
  Probe := TArchiveFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  ArchivePath := GTempRoot + PathDelim + 'archive.tar.gz';
  DestDir := CreateUniqueTempDir('test_archive_targz_dest');
  CreateDummyFile(ArchivePath);
  try
    Probe.TarGzSuccess := True;
    Probe.TarGzExitCode := 0;
    Check('tar.gz dispatch succeeds',
      ExecuteFPCInstallerArchiveFlow(ArchivePath, DestDir, OutBuf, ErrBuf,
        @Probe.ExtractZip, @Probe.ExtractTar, @Probe.ExtractTarGz),
      'expected tar.gz success');
    Check('tar.gz handler called once', Probe.TarGzCalls = 1,
      'tar.gz calls=' + IntToStr(Probe.TarGzCalls));
    Check('tar.gz output includes success', OutBuf.Contains('TAR.GZ extraction completed successfully'),
      'tar.gz success missing');
  finally
    CleanupTempDir(DestDir);
    DeleteFile(ArchivePath);
    Probe.Free;
  end;
end;

procedure TestExeManualInstallMessage;
var
  Probe: TArchiveFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  ArchivePath, DestDir: string;
begin
  Probe := TArchiveFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  ArchivePath := GTempRoot + PathDelim + 'installer.exe';
  DestDir := CreateUniqueTempDir('test_archive_exe_dest');
  CreateDummyFile(ArchivePath);
  try
    Check('exe manual install returns true',
      ExecuteFPCInstallerArchiveFlow(ArchivePath, DestDir, OutBuf, ErrBuf,
        @Probe.ExtractZip, @Probe.ExtractTar, @Probe.ExtractTarGz),
      'expected manual-install success');
    Check('exe manual install does not call handlers',
      (Probe.ZipCalls = 0) and (Probe.TarCalls = 0) and (Probe.TarGzCalls = 0),
      'handlers should not run');
    Check('exe output mentions windows installer', OutBuf.Contains('Windows installer detected'),
      'windows message missing');
  finally
    CleanupTempDir(DestDir);
    DeleteFile(ArchivePath);
    Probe.Free;
  end;
end;

procedure TestDmgManualInstallMessage;
var
  Probe: TArchiveFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  ArchivePath, DestDir: string;
begin
  Probe := TArchiveFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  ArchivePath := GTempRoot + PathDelim + 'installer.dmg';
  DestDir := CreateUniqueTempDir('test_archive_dmg_dest');
  CreateDummyFile(ArchivePath);
  try
    Check('dmg manual install returns true',
      ExecuteFPCInstallerArchiveFlow(ArchivePath, DestDir, OutBuf, ErrBuf,
        @Probe.ExtractZip, @Probe.ExtractTar, @Probe.ExtractTarGz),
      'expected manual-install success');
    Check('dmg output mentions disk image', OutBuf.Contains('macOS disk image detected'),
      'dmg message missing');
  finally
    CleanupTempDir(DestDir);
    DeleteFile(ArchivePath);
    Probe.Free;
  end;
end;

procedure TestUnsupportedFormatFails;
var
  Probe: TArchiveFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  ArchivePath, DestDir: string;
begin
  Probe := TArchiveFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  ArchivePath := GTempRoot + PathDelim + 'installer.bin';
  DestDir := CreateUniqueTempDir('test_archive_bad_dest');
  CreateDummyFile(ArchivePath);
  try
    Check('unsupported format returns false',
      not ExecuteFPCInstallerArchiveFlow(ArchivePath, DestDir, OutBuf, ErrBuf,
        @Probe.ExtractZip, @Probe.ExtractTar, @Probe.ExtractTarGz),
      'expected unsupported failure');
    Check('unsupported format message present', ErrBuf.Contains('Unsupported archive format'),
      'unsupported message missing');
  finally
    CleanupTempDir(DestDir);
    DeleteFile(ArchivePath);
    Probe.Free;
  end;
end;

begin
  WriteLn('=== FPC Installer Archive Flow Tests ===');
  GTempRoot := CreateUniqueTempDir('test_archiveflow_root');
  try
    TestMissingArchiveFailsFast;
    TestZipDispatch;
    TestTarFailureReportsExitCode;
    TestTarGzDispatch;
    TestExeManualInstallMessage;
    TestDmgManualInstallMessage;
    TestUnsupportedFormatFails;
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
