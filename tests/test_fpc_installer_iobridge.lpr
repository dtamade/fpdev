program test_fpc_installer_iobridge;

{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils, Classes, Process, Sockets, zipper,
  fpdev.fpc.installer.iobridge,
  fpdev.utils.process, test_temp_paths;

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
  TLocalHTTPServer = class
  private
    FProcess: TProcess;
    FPort: Integer;
    FRootDir: string;
    function ReadReadyPort(out APort: Integer): Boolean;
    function StartServer(const APythonScript: string;
      const AExtraArgs: array of string): Boolean;
  public
    constructor Create(const ARootDir: string);
    destructor Destroy; override;
    function Start: Boolean;
    function StartWithInitial503Responses(AFailureCount: Integer;
      const ATargetPath: string): Boolean;
    procedure Stop;
    property Port: Integer read FPort;
  end;

function AllocateUnusedLocalPort: Integer;
var
  Sock: LongInt;
  Addr: TInetSockAddr;
  AddrLen: TSockLen;
begin
  Result := 0;
  Sock := fpSocket(AF_INET, SOCK_STREAM, 0);
  if Sock < 0 then
    Exit;

  try
    FillChar(Addr, SizeOf(Addr), 0);
    Addr.sin_family := AF_INET;
    Addr.sin_port := htons(0);
    Addr.sin_addr := StrToNetAddr('127.0.0.1');

    if fpBind(Sock, @Addr, SizeOf(Addr)) <> 0 then
      Exit;

    AddrLen := SizeOf(Addr);
    if fpGetSockName(Sock, @Addr, @AddrLen) <> 0 then
      Exit;

    Result := ntohs(Addr.sin_port);
  finally
    CloseSocket(Sock);
  end;
end;

constructor TLocalHTTPServer.Create(const ARootDir: string);
begin
  inherited Create;
  FRootDir := ARootDir;
  FProcess := nil;
  FPort := 0;
end;

destructor TLocalHTTPServer.Destroy;
begin
  Stop;
  inherited Destroy;
end;

function TLocalHTTPServer.ReadReadyPort(out APort: Integer): Boolean;
var
  Deadline: QWord;
  NextChar: Char;
  BytesRead: LongInt;
  PortLine: string;
begin
  Result := False;
  APort := 0;
  PortLine := '';
  Deadline := GetTickCount64 + 3000;

  while GetTickCount64 < Deadline do
  begin
    if Assigned(FProcess) and Assigned(FProcess.Output) and
       (FProcess.Output.NumBytesAvailable > 0) then
    begin
      BytesRead := FProcess.Output.Read(NextChar, 1);
      if BytesRead = 1 then
      begin
        if NextChar = #10 then
        begin
          APort := StrToIntDef(Trim(PortLine), 0);
          Exit(APort > 0);
        end;

        if NextChar <> #13 then
          PortLine := PortLine + NextChar;
      end;
      Continue;
    end;

    if (not Assigned(FProcess)) or (not FProcess.Running) then
      Break;

    Sleep(10);
  end;

  if PortLine <> '' then
  begin
    APort := StrToIntDef(Trim(PortLine), 0);
    Result := APort > 0;
  end;
end;

function TLocalHTTPServer.StartServer(const APythonScript: string;
  const AExtraArgs: array of string): Boolean;
var
  ArgIndex: Integer;
  ReadyPort: Integer;
begin
  Result := False;
  Stop;
  FPort := 0;
  FProcess := TProcess.Create(nil);
  try
    FProcess.Executable := 'python3';
    FProcess.Parameters.Add('-u');
    FProcess.Parameters.Add('-c');
    FProcess.Parameters.Add(APythonScript);
    FProcess.Parameters.Add(FRootDir);
    for ArgIndex := 0 to High(AExtraArgs) do
      FProcess.Parameters.Add(AExtraArgs[ArgIndex]);
    FProcess.CurrentDirectory := FRootDir;
    FProcess.Options := [poUsePipes, poNoConsole];
    FProcess.Execute;
    if not ReadReadyPort(ReadyPort) then
      Exit(False);
    FPort := ReadyPort;
    Result := FPort > 0;
  except
    Stop;
  end;

  if not Result then
    Stop;
end;

function TLocalHTTPServer.Start: Boolean;
const
  PYTHON_HTTP_SERVER =
    'import http.server, os, socketserver, sys' + LineEnding +
    'os.chdir(sys.argv[1])' + LineEnding +
    'socketserver.TCPServer.allow_reuse_address = True' + LineEnding +
    'handler = http.server.SimpleHTTPRequestHandler' + LineEnding +
    'httpd = socketserver.TCPServer(("127.0.0.1", 0), handler)' + LineEnding +
    'print(httpd.server_address[1], flush=True)' + LineEnding +
    'httpd.serve_forever()';
begin
  Result := StartServer(PYTHON_HTTP_SERVER, []);
end;

function TLocalHTTPServer.StartWithInitial503Responses(AFailureCount: Integer;
  const ATargetPath: string): Boolean;
const
  PYTHON_HTTP_503_SERVER =
    'import http.server, os, socketserver, sys' + LineEnding +
    'os.chdir(sys.argv[1])' + LineEnding +
    'FAILURES = int(sys.argv[2])' + LineEnding +
    'TARGET = sys.argv[3]' + LineEnding +
    'class Handler(http.server.SimpleHTTPRequestHandler):' + LineEnding +
    '    def do_GET(self):' + LineEnding +
    '        global FAILURES' + LineEnding +
    '        if self.path == TARGET and FAILURES > 0:' + LineEnding +
    '            FAILURES -= 1' + LineEnding +
    '            self.send_response(503)' + LineEnding +
    '            self.send_header("Content-Type", "text/plain")' + LineEnding +
    '            self.end_headers()' + LineEnding +
    '            self.wfile.write(b"retry later")' + LineEnding +
    '            return' + LineEnding +
    '        return super().do_GET()' + LineEnding +
    'socketserver.TCPServer.allow_reuse_address = True' + LineEnding +
    'httpd = socketserver.TCPServer(("127.0.0.1", 0), Handler)' + LineEnding +
    'print(httpd.server_address[1], flush=True)' + LineEnding +
    'httpd.serve_forever()';
begin
  Result := StartServer(PYTHON_HTTP_503_SERVER,
    [IntToStr(AFailureCount), ATargetPath]);
end;

procedure TLocalHTTPServer.Stop;
begin
  if Assigned(FProcess) then
  begin
    if FProcess.Running then
    begin
      try
        FProcess.Terminate(0);
      except
      end;
      Sleep(100);
    end;
    FreeAndNil(FProcess);
  end;
end;

procedure CreateTextFile(const APath, AContent: string);
begin
  ForceDirectories(ExtractFileDir(APath));
  with TStringList.Create do
  try
    Add(AContent);
    SaveToFile(APath);
  finally
    Free;
  end;
end;

procedure CreateZipArchive(const AArchivePath, ASourceFile, AArchiveName: string);
var
  Zipper: TZipper;
begin
  Zipper := TZipper.Create;
  try
    Zipper.FileName := AArchivePath;
    Zipper.Entries.AddFileEntry(ASourceFile, AArchiveName);
    Zipper.ZipAllFiles;
  finally
    Zipper.Free;
  end;
end;

procedure TestLegacyHTTPDownloadBridgeSuccess;
var
  RootDir: string;
  SourceFile: string;
  TempFile: string;
  Server: TLocalHTTPServer;
  Bytes: Int64;
  Err: string;
begin
  RootDir := CreateUniqueTempDir('test_iobridge_http_root');
  TempFile := RootDir + PathDelim + 'downloaded.txt';
  SourceFile := RootDir + PathDelim + 'payload.txt';
  Server := TLocalHTTPServer.Create(RootDir);
  try
    CreateTextFile(SourceFile, 'hello bridge');
    Check('http server starts', Server.Start, 'failed to start local python http server');
    Err := '';
    Bytes := 0;
    Check('legacy http bridge returns true',
      ExecuteFPCLegacyBinaryHTTPGetBridge(
        'http://127.0.0.1:' + IntToStr(Server.Port) + '/payload.txt',
        TempFile, Bytes, Err),
      'err=' + Err);
    Check('legacy http bridge writes temp file', FileExists(TempFile),
      'missing temp file');
    Check('legacy http bridge records bytes', Bytes > 0,
      'bytes=' + IntToStr(Bytes));
  finally
    Server.Free;
    if FileExists(TempFile) then
      DeleteFile(TempFile);
    CleanupTempDir(RootDir);
  end;
end;

procedure TestLegacyHTTPDownloadBridgeRetriesHTTP503UntilSuccess;
var
  RootDir: string;
  SourceFile: string;
  TempFile: string;
  Server: TLocalHTTPServer;
  Bytes: Int64;
  Err: string;
begin
  RootDir := CreateUniqueTempDir('test_iobridge_http_retry_root');
  TempFile := RootDir + PathDelim + 'downloaded.txt';
  SourceFile := RootDir + PathDelim + 'payload.txt';
  Server := TLocalHTTPServer.Create(RootDir);
  try
    CreateTextFile(SourceFile, 'hello delayed bridge');
    Check('retrying http server starts',
      Server.StartWithInitial503Responses(2, '/payload.txt'),
      'failed to launch retrying local python http server');
    Err := '';
    Bytes := 0;
    Check('legacy http bridge retries after http 503',
      ExecuteFPCLegacyBinaryHTTPGetBridge(
        'http://127.0.0.1:' + IntToStr(Server.Port) + '/payload.txt',
        TempFile, Bytes, Err),
      'err=' + Err);
    Check('legacy http bridge retry writes temp file', FileExists(TempFile),
      'missing temp file');
    Check('legacy http bridge retry records bytes', Bytes > 0,
      'bytes=' + IntToStr(Bytes));
  finally
    Server.Free;
    if FileExists(TempFile) then
      DeleteFile(TempFile);
    CleanupTempDir(RootDir);
  end;
end;

procedure TestLegacyHTTPDownloadBridgeFailure;
var
  RootDir: string;
  TempFile: string;
  UnusedPort: Integer;
  Bytes: Int64;
  Err: string;
begin
  RootDir := CreateUniqueTempDir('test_iobridge_http_fail_root');
  TempFile := RootDir + PathDelim + 'downloaded.txt';
  try
    UnusedPort := AllocateUnusedLocalPort;
    Check('unused local port is allocated', UnusedPort > 0, 'expected an ephemeral port');
    Err := '';
    Bytes := 0;
    Check('legacy http bridge failure returns false',
      not ExecuteFPCLegacyBinaryHTTPGetBridge(
        'http://127.0.0.1:' + IntToStr(UnusedPort) + '/never-there.txt',
        TempFile, Bytes, Err),
      'expected failure');
    Check('legacy http bridge failure sets error', Err <> '', 'error should not be empty');
    Check('legacy http bridge failure cleans temp file', not FileExists(TempFile),
      'partial temp file should be removed');
  finally
    CleanupTempDir(RootDir);
  end;
end;

procedure TestZipExtractBridge;
var
  SourceDir, DestDir: string;
  SourceFile, ArchivePath: string;
  EntryCount: Integer;
begin
  SourceDir := CreateUniqueTempDir('test_iobridge_zip_src');
  DestDir := CreateUniqueTempDir('test_iobridge_zip_dest');
  SourceFile := SourceDir + PathDelim + 'hello.txt';
  ArchivePath := SourceDir + PathDelim + 'payload.zip';
  try
    CreateTextFile(SourceFile, 'zip hello');
    CreateZipArchive(ArchivePath, SourceFile, 'hello.txt');
    EntryCount := 0;
    Check('zip bridge returns true',
      ExecuteFPCZipExtractBridge(ArchivePath, DestDir, EntryCount),
      'zip extraction failed');
    Check('zip bridge reports entries', EntryCount = 1,
      'entry count=' + IntToStr(EntryCount));
    Check('zip bridge extracts file', FileExists(DestDir + PathDelim + 'hello.txt'),
      'extracted file missing');
  finally
    CleanupTempDir(DestDir);
    CleanupTempDir(SourceDir);
  end;
end;

procedure TestTarExtractBridge;
var
  SourceDir, DestDir: string;
  SourceFile, ArchivePath: string;
  ExitCode: Integer;
  ProcRes: fpdev.utils.process.TProcessResult;
begin
  SourceDir := CreateUniqueTempDir('test_iobridge_tar_src');
  DestDir := CreateUniqueTempDir('test_iobridge_tar_dest');
  SourceFile := SourceDir + PathDelim + 'hello.txt';
  ArchivePath := SourceDir + PathDelim + 'payload.tar';
  try
    CreateTextFile(SourceFile, 'tar hello');
    ProcRes := TProcessExecutor.Execute('tar', ['-cf', ArchivePath, '-C', SourceDir, 'hello.txt'], '');
    Check('create tar archive succeeds', ProcRes.Success, 'tar create failed');
    ExitCode := -1;
    Check('tar bridge returns true',
      ExecuteFPCTarExtractBridge(ArchivePath, DestDir, ExitCode),
      'tar extraction failed');
    Check('tar bridge exit code is zero', ExitCode = 0,
      'exit code=' + IntToStr(ExitCode));
    Check('tar bridge extracts file', FileExists(DestDir + PathDelim + 'hello.txt'),
      'extracted file missing');
  finally
    CleanupTempDir(DestDir);
    CleanupTempDir(SourceDir);
  end;
end;

procedure TestTarGzExtractBridge;
var
  SourceDir, DestDir: string;
  SourceFile, ArchivePath: string;
  ExitCode: Integer;
  ProcRes: fpdev.utils.process.TProcessResult;
begin
  SourceDir := CreateUniqueTempDir('test_iobridge_targz_src');
  DestDir := CreateUniqueTempDir('test_iobridge_targz_dest');
  SourceFile := SourceDir + PathDelim + 'hello.txt';
  ArchivePath := SourceDir + PathDelim + 'payload.tar.gz';
  try
    CreateTextFile(SourceFile, 'tar gz hello');
    ProcRes := TProcessExecutor.Execute('tar', ['-czf', ArchivePath, '-C', SourceDir, 'hello.txt'], '');
    Check('create tar.gz archive succeeds', ProcRes.Success, 'tar.gz create failed');
    ExitCode := -1;
    Check('tar.gz bridge returns true',
      ExecuteFPCTarGzExtractBridge(ArchivePath, DestDir, ExitCode),
      'tar.gz extraction failed');
    Check('tar.gz bridge exit code is zero', ExitCode = 0,
      'exit code=' + IntToStr(ExitCode));
    Check('tar.gz bridge extracts file', FileExists(DestDir + PathDelim + 'hello.txt'),
      'extracted file missing');
  finally
    CleanupTempDir(DestDir);
    CleanupTempDir(SourceDir);
  end;
end;

begin
  WriteLn('=== FPC Installer IO Bridge Tests ===');
  GTempRoot := CreateUniqueTempDir('test_iobridge_root');
  try
    TestLegacyHTTPDownloadBridgeSuccess;
    TestLegacyHTTPDownloadBridgeRetriesHTTP503UntilSuccess;
    TestLegacyHTTPDownloadBridgeFailure;
    TestZipExtractBridge;
    TestTarExtractBridge;
    TestTarGzExtractBridge;
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
