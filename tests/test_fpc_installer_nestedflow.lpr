program test_fpc_installer_nestedflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf,
  fpdev.fpc.installer.nestedflow,
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
  TNestedFlowProbe = class
  public
    FailOnBinary: Boolean;
    FailOnBase: Boolean;
    FailOnDirect: Boolean;
    CreateBaseArchiveOnBinary: Boolean;
    CreateBinOnBase: Boolean;
    CreateLibOnBase: Boolean;
    CreateLibOnDirect: Boolean;
    Calls: Integer;
    BinaryCalls: Integer;
    BaseCalls: Integer;
    DirectCalls: Integer;
    LastArchive: string;
    LastDest: string;
    function ExtractArchive(const AArchivePath, ADestPath: string): Boolean;
  end;

function TNestedFlowProbe.ExtractArchive(const AArchivePath, ADestPath: string): Boolean;
var
  FileName: string;
begin
  Inc(Calls);
  LastArchive := AArchivePath;
  LastDest := ADestPath;
  FileName := ExtractFileName(AArchivePath);

  if Pos('binary.', FileName) = 1 then
  begin
    Inc(BinaryCalls);
    if CreateBaseArchiveOnBinary then
      with TStringList.Create do
      try
        Add('base archive');
        SaveToFile(ADestPath + PathDelim + 'base.x86_64-linux.tar.gz');
      finally
        Free;
      end;
    Result := not FailOnBinary;
    Exit;
  end;

  if Pos('base.', FileName) = 1 then
  begin
    Inc(BaseCalls);
    if CreateBinOnBase then
      ForceDirectories(ADestPath + PathDelim + 'bin');
    if CreateLibOnBase then
      ForceDirectories(ADestPath + PathDelim + 'lib');
    Result := not FailOnBase;
    Exit;
  end;

  Inc(DirectCalls);
  if CreateLibOnDirect then
    ForceDirectories(ADestPath + PathDelim + 'lib');
  Result := not FailOnDirect;
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

procedure TestNestedArchiveSuccess;
var
  Probe: TNestedFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  TempDir, InstallDir, OuterFile, ExtractedDir, BinaryTar, BaseArchive: string;
begin
  Probe := TNestedFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  TempDir := CreateUniqueTempDir('test_nested_success_temp');
  InstallDir := CreateUniqueTempDir('test_nested_success_install');
  OuterFile := TempDir + PathDelim + 'outer.tar';
  ExtractedDir := TempDir + PathDelim + 'fpc-3.2.2.x86_64-linux';
  BinaryTar := ExtractedDir + PathDelim + 'binary.x86_64-linux.tar';
  try
    CreateDummyFile(OuterFile);
    ForceDirectories(ExtractedDir);
    CreateDummyFile(BinaryTar);
    Probe.CreateBaseArchiveOnBinary := True;
    Probe.CreateBinOnBase := True;

    Check('nested archive flow returns true',
      ExecuteFPCNestedPackageInstallFlow(TempDir, InstallDir, OuterFile,
        OutBuf, ErrBuf, @Probe.ExtractArchive),
      'expected success');
    Check('nested archive extracted binary once', Probe.BinaryCalls = 1,
      'binary calls=' + IntToStr(Probe.BinaryCalls));
    Check('nested archive extracted base once', Probe.BaseCalls = 1,
      'base calls=' + IntToStr(Probe.BaseCalls));
    Check('nested archive skips direct fallback', Probe.DirectCalls = 0,
      'direct calls=' + IntToStr(Probe.DirectCalls));
    Check('nested archive output mentions nested tar',
      OutBuf.Contains('Extracting nested binary TAR'), 'nested message missing');
    Check('nested archive output mentions base package',
      OutBuf.Contains('Extracting base package'), 'base message missing');
    Check('nested archive creates install bin',
      DirectoryExists(InstallDir + PathDelim + 'bin'), 'bin missing');
    BaseArchive := InstallDir + PathDelim + 'base.x86_64-linux.tar.gz';
    Check('nested archive deletes base archive after extraction',
      not FileExists(BaseArchive), 'base archive should be deleted');
    Check('nested archive prints completion message',
      OutBuf.Contains('Extraction completed'), 'completion missing');
  finally
    CleanupTempDir(InstallDir);
    CleanupTempDir(TempDir);
    Probe.Free;
  end;
end;

procedure TestDirectExtractionFallback;
var
  Probe: TNestedFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  TempDir, InstallDir, OuterFile: string;
begin
  Probe := TNestedFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  TempDir := CreateUniqueTempDir('test_nested_direct_temp');
  InstallDir := CreateUniqueTempDir('test_nested_direct_install');
  OuterFile := TempDir + PathDelim + 'outer.tar';
  try
    CreateDummyFile(OuterFile);
    Probe.CreateLibOnDirect := True;

    Check('direct extraction fallback returns true',
      ExecuteFPCNestedPackageInstallFlow(TempDir, InstallDir, OuterFile,
        OutBuf, ErrBuf, @Probe.ExtractArchive),
      'expected direct extraction success');
    Check('direct extraction fallback calls direct once', Probe.DirectCalls = 1,
      'direct calls=' + IntToStr(Probe.DirectCalls));
    Check('direct extraction fallback skips binary extraction', Probe.BinaryCalls = 0,
      'binary calls=' + IntToStr(Probe.BinaryCalls));
    Check('direct extraction fallback prints fallback message',
      OutBuf.Contains('No nested TAR found, using direct extraction'), 'fallback message missing');
    Check('direct extraction fallback validates lib dir',
      DirectoryExists(InstallDir + PathDelim + 'lib'), 'lib missing');
  finally
    CleanupTempDir(InstallDir);
    CleanupTempDir(TempDir);
    Probe.Free;
  end;
end;

procedure TestNestedBinaryFailure;
var
  Probe: TNestedFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  TempDir, InstallDir, OuterFile, ExtractedDir, BinaryTar: string;
begin
  Probe := TNestedFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  TempDir := CreateUniqueTempDir('test_nested_fail_temp');
  InstallDir := CreateUniqueTempDir('test_nested_fail_install');
  OuterFile := TempDir + PathDelim + 'outer.tar';
  ExtractedDir := TempDir + PathDelim + 'fpc-3.2.2.x86_64-linux';
  BinaryTar := ExtractedDir + PathDelim + 'binary.x86_64-linux.tar';
  try
    CreateDummyFile(OuterFile);
    ForceDirectories(ExtractedDir);
    CreateDummyFile(BinaryTar);
    Probe.FailOnBinary := True;

    Check('nested binary failure returns false',
      not ExecuteFPCNestedPackageInstallFlow(TempDir, InstallDir, OuterFile,
        OutBuf, ErrBuf, @Probe.ExtractArchive),
      'expected failure');
    Check('nested binary failure reports stderr',
      ErrBuf.Contains('Nested extraction failed'), 'nested failure missing');
  finally
    CleanupTempDir(InstallDir);
    CleanupTempDir(TempDir);
    Probe.Free;
  end;
end;

procedure TestBaseArchiveFailure;
var
  Probe: TNestedFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  TempDir, InstallDir, OuterFile, ExtractedDir, BinaryTar: string;
begin
  Probe := TNestedFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  TempDir := CreateUniqueTempDir('test_base_fail_temp');
  InstallDir := CreateUniqueTempDir('test_base_fail_install');
  OuterFile := TempDir + PathDelim + 'outer.tar';
  ExtractedDir := TempDir + PathDelim + 'fpc-3.2.2.x86_64-linux';
  BinaryTar := ExtractedDir + PathDelim + 'binary.x86_64-linux.tar';
  try
    CreateDummyFile(OuterFile);
    ForceDirectories(ExtractedDir);
    CreateDummyFile(BinaryTar);
    Probe.CreateBaseArchiveOnBinary := True;
    Probe.FailOnBase := True;

    Check('base archive failure returns false',
      not ExecuteFPCNestedPackageInstallFlow(TempDir, InstallDir, OuterFile,
        OutBuf, ErrBuf, @Probe.ExtractArchive),
      'expected failure');
    Check('base archive failure reports stderr',
      ErrBuf.Contains('Base package extraction failed'), 'base failure missing');
  finally
    CleanupTempDir(InstallDir);
    CleanupTempDir(TempDir);
    Probe.Free;
  end;
end;

procedure TestPostValidationFailure;
var
  Probe: TNestedFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  TempDir, InstallDir, OuterFile: string;
begin
  Probe := TNestedFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  TempDir := CreateUniqueTempDir('test_nested_validate_temp');
  InstallDir := CreateUniqueTempDir('test_nested_validate_install');
  OuterFile := TempDir + PathDelim + 'outer.tar';
  try
    CreateDummyFile(OuterFile);

    Check('post validation failure returns false',
      not ExecuteFPCNestedPackageInstallFlow(TempDir, InstallDir, OuterFile,
        OutBuf, ErrBuf, @Probe.ExtractArchive),
      'expected validation failure');
    Check('post validation failure message present',
      ErrBuf.Contains('Post-extraction validation failed'), 'validation message missing');
    Check('post validation failure explains incomplete install',
      ErrBuf.Contains('Installation directory may be incomplete'), 'incomplete message missing');
  finally
    CleanupTempDir(InstallDir);
    CleanupTempDir(TempDir);
    Probe.Free;
  end;
end;

begin
  WriteLn('=== FPC Installer Nested Flow Tests ===');
  GTempRoot := CreateUniqueTempDir('test_nestedflow_root');
  try
    TestNestedArchiveSuccess;
    TestDirectExtractionFallback;
    TestNestedBinaryFailure;
    TestBaseArchiveFailure;
    TestPostValidationFailure;
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
