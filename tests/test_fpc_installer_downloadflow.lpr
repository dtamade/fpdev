program test_fpc_installer_downloadflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf,
  fpdev.fpc.installer.downloadflow,
  test_temp_paths;

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
  TDownloadFlowProbe = class
  public
    DownloadSuccess: Boolean;
    RaiseOnDownload: Boolean;
    DownloadError: string;
    HashValue: string;
    DownloadCalls: Integer;
    HashCalls: Integer;
    LastURL: string;
    LastTempFile: string;
    LastHashPath: string;
    CreatePartialOnFailure: Boolean;
    function HTTPGet(const AURL, ATempFile: string; out ADownloadedBytes: Int64;
      out AError: string): Boolean;
    function SHA256(const AFilePath: string): string;
  end;

function TDownloadFlowProbe.HTTPGet(const AURL, ATempFile: string;
  out ADownloadedBytes: Int64; out AError: string): Boolean;
begin
  Inc(DownloadCalls);
  LastURL := AURL;
  LastTempFile := ATempFile;

  if CreatePartialOnFailure then
    with TStringList.Create do
    try
      Add('partial');
      SaveToFile(ATempFile);
    finally
      Free;
    end;

  if RaiseOnDownload then
    raise Exception.Create('download boom');

  ADownloadedBytes := 0;
  AError := DownloadError;
  Result := DownloadSuccess;
  if Result then
  begin
    with TStringList.Create do
    try
      Add('downloaded');
      SaveToFile(ATempFile);
    finally
      Free;
    end;
    ADownloadedBytes := 11;
  end;
end;

function TDownloadFlowProbe.SHA256(const AFilePath: string): string;
begin
  Inc(HashCalls);
  LastHashPath := AFilePath;
  Result := HashValue;
end;

procedure CreateDummyFile(const APath, AContent: string);
begin
  with TStringList.Create do
  try
    Add(AContent);
    SaveToFile(APath);
  finally
    Free;
  end;
end;

procedure TestResolveLegacyURLAndPlan;
var
  URL: string;
  FileExt: string;
  Plan: TFPCLegacyBinaryDownloadPlan;
  Err: string;
begin
  URL := ResolveFPCLegacyBinaryDownloadURL('3.2.2');
  FileExt := ResolveFPCLegacyBinaryDownloadFileExt;

  Check('legacy url not empty', URL <> '', 'url should not be empty');
  Check('legacy url contains sourceforge', Pos('sourceforge.net', URL) > 0,
    'url=' + URL);
  Check('legacy url contains version', Pos('3.2.2', URL) > 0,
    'url=' + URL);
  Check('legacy file ext not empty', FileExt <> '', 'file ext should not be empty');
  {$IFDEF LINUX}
  Check('legacy linux file ext is tar', FileExt = '.tar', 'ext=' + FileExt);
  Check('legacy linux url mentions Linux', Pos('Linux', URL) > 0, 'url=' + URL);
  {$ENDIF}
  {$IFDEF MSWINDOWS}
  Check('legacy windows file ext is exe', FileExt = '.exe', 'ext=' + FileExt);
  {$ENDIF}
  {$IFDEF DARWIN}
  Check('legacy macOS file ext is dmg', FileExt = '.dmg', 'ext=' + FileExt);
  {$ENDIF}

  Err := '';
  Check('prepare legacy download plan succeeds',
    PrepareFPCLegacyBinaryDownloadPlan('3.2.2', Plan, Err),
    'err=' + Err);
  Check('prepare legacy download plan temp dir contains fpdev_downloads',
    Pos('fpdev_downloads', Plan.TempDir) > 0, 'temp dir=' + Plan.TempDir);
  Check('prepare legacy download plan temp file contains version',
    Pos('3.2.2', Plan.TempFile) > 0, 'temp file=' + Plan.TempFile);
  Check('prepare legacy download plan temp file has ext',
    ExtractFileExt(Plan.TempFile) = FileExt, 'temp file=' + Plan.TempFile);
end;

procedure TestExecuteLegacyDownloadSuccess;
var
  Probe: TDownloadFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  TempFile: string;
begin
  Probe := TDownloadFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  try
    Probe.DownloadSuccess := True;

    Check('legacy download success returns true',
      ExecuteFPCLegacyBinaryDownloadFlow('3.2.2', OutBuf, ErrBuf,
        @Probe.HTTPGet, TempFile),
      'expected success');
    Check('legacy download calls http once', Probe.DownloadCalls = 1,
      'calls=' + IntToStr(Probe.DownloadCalls));
    Check('legacy download output file exists', FileExists(TempFile),
      'temp file=' + TempFile);
    Check('legacy download output mentions download completed',
      OutBuf.Contains('Download completed:'), 'completion missing');
    Check('legacy download url forwarded to callback', Pos('3.2.2', Probe.LastURL) > 0,
      'url=' + Probe.LastURL);
    Check('legacy download temp file under system temp',
      PathUsesSystemTempRoot(Probe.LastTempFile), 'temp file=' + Probe.LastTempFile);
  finally
    if (TempFile <> '') and FileExists(TempFile) then
      DeleteFile(TempFile);
    Probe.Free;
  end;
end;

procedure TestExecuteLegacyDownloadFailureCleansPartial;
var
  Probe: TDownloadFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  TempFile: string;
begin
  Probe := TDownloadFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  TempFile := '';
  try
    Probe.DownloadSuccess := False;
    Probe.DownloadError := 'network down';
    Probe.CreatePartialOnFailure := True;

    Check('legacy download failure returns false',
      not ExecuteFPCLegacyBinaryDownloadFlow('3.2.3', OutBuf, ErrBuf,
        @Probe.HTTPGet, TempFile),
      'expected failure');
    Check('legacy download failure keeps output temp file empty', TempFile = '',
      'temp file=' + TempFile);
    Check('legacy download failure reports error',
      ErrBuf.Contains('DownloadBinary failed - network down'), 'download error missing');
    Check('legacy download failure cleans partial file',
      (Probe.LastTempFile <> '') and (not FileExists(Probe.LastTempFile)),
      'partial file should be removed: ' + Probe.LastTempFile);
  finally
    Probe.Free;
  end;
end;

procedure TestExecuteLegacyDownloadExceptionCleansPartial;
var
  Probe: TDownloadFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  TempFile: string;
begin
  Probe := TDownloadFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  TempFile := '';
  try
    Probe.RaiseOnDownload := True;
    Probe.CreatePartialOnFailure := True;

    Check('legacy download exception returns false',
      not ExecuteFPCLegacyBinaryDownloadFlow('3.2.4', OutBuf, ErrBuf,
        @Probe.HTTPGet, TempFile),
      'expected failure');
    Check('legacy download exception reports error',
      ErrBuf.Contains('DownloadBinary failed - download boom'), 'exception missing');
    Check('legacy download exception cleans partial file',
      (Probe.LastTempFile <> '') and (not FileExists(Probe.LastTempFile)),
      'partial file should be removed: ' + Probe.LastTempFile);
  finally
    Probe.Free;
  end;
end;

procedure TestExecuteVerifySuccess;
var
  Probe: TDownloadFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  FilePath: string;
begin
  Probe := TDownloadFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  FilePath := CreateUniqueTempDir('test_downloadflow_verify_ok') + PathDelim + 'archive.tar';
  try
    CreateDummyFile(FilePath, 'hello');
    Probe.HashValue := 'abc123hash';

    Check('verify success returns true',
      ExecuteFPCLegacyBinaryVerifyFlow(FilePath, '3.2.2', OutBuf, ErrBuf,
        @Probe.SHA256),
      'expected verify success');
    Check('verify success calls hash once', Probe.HashCalls = 1,
      'hash calls=' + IntToStr(Probe.HashCalls));
    Check('verify success forwards file path', Probe.LastHashPath = FilePath,
      'hash path=' + Probe.LastHashPath);
    Check('verify success prints checksum line',
      OutBuf.Contains('SHA256: abc123hash'), 'checksum line missing');
    Check('verify success prints verified line',
      OutBuf.Contains('File integrity verified'), 'verified line missing');
  finally
    if FileExists(FilePath) then
      DeleteFile(FilePath);
    CleanupTempDir(ExtractFileDir(FilePath));
    Probe.Free;
  end;
end;

procedure TestExecuteVerifyMissingFile;
var
  Probe: TDownloadFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
begin
  Probe := TDownloadFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  try
    Check('verify missing file returns false',
      not ExecuteFPCLegacyBinaryVerifyFlow('/tmp/definitely-missing-file.tar', '3.2.2',
        OutBuf, ErrBuf, @Probe.SHA256),
      'expected missing file failure');
    Check('verify missing file skips hash callback', Probe.HashCalls = 0,
      'hash calls=' + IntToStr(Probe.HashCalls));
    Check('verify missing file reports file not found',
      ErrBuf.Contains('File not found'), 'missing file message absent');
  finally
    Probe.Free;
  end;
end;

procedure TestExecuteVerifyEmptyHashFails;
var
  Probe: TDownloadFlowProbe;
  OutBuf, ErrBuf: TStringOutput;
  FilePath: string;
begin
  Probe := TDownloadFlowProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  FilePath := CreateUniqueTempDir('test_downloadflow_verify_bad') + PathDelim + 'archive.tar';
  try
    CreateDummyFile(FilePath, 'hello');
    Probe.HashValue := '';

    Check('verify empty hash returns false',
      not ExecuteFPCLegacyBinaryVerifyFlow(FilePath, '3.2.2', OutBuf, ErrBuf,
        @Probe.SHA256),
      'expected checksum failure');
    Check('verify empty hash reports checksum failure',
      ErrBuf.Contains('Failed to calculate checksum'), 'checksum error missing');
  finally
    if FileExists(FilePath) then
      DeleteFile(FilePath);
    CleanupTempDir(ExtractFileDir(FilePath));
    Probe.Free;
  end;
end;

begin
  WriteLn('=== FPC Installer Download Flow Tests ===');

  TestResolveLegacyURLAndPlan;
  TestExecuteLegacyDownloadSuccess;
  TestExecuteLegacyDownloadFailureCleansPartial;
  TestExecuteLegacyDownloadExceptionCleansPartial;
  TestExecuteVerifySuccess;
  TestExecuteVerifyMissingFile;
  TestExecuteVerifyEmptyHashFails;

  WriteLn;
  WriteLn('Total: ', PassCount + FailCount);
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
