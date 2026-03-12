program test_fpc_installer_iobridge;

{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils, Classes, Process, zipper,
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
  public
    constructor Create(const ARootDir: string);
    destructor Destroy; override;
    function Start: Boolean;
    function StartDelayed(ADelayMs: Integer): Boolean;
    function WaitUntilReady(ATimeoutMs: Integer): Boolean;
    procedure Stop;
    property Port: Integer read FPort;
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

function TLocalHTTPServer.WaitUntilReady(ATimeoutMs: Integer): Boolean;
var
  Deadline: QWord;
  Probe: fpdev.utils.process.TProcessResult;
begin
  Result := False;
  Deadline := GetTickCount64 + QWord(ATimeoutMs);

  repeat
    if (not Assigned(FProcess)) or (not FProcess.Running) then
      Exit(False);

    Probe := TProcessExecutor.ExecuteWithTimeout(
      'python3',
      ['-c',
       'import socket, sys; s = socket.socket(); s.settimeout(0.2); s.connect(("127.0.0.1", int(sys.argv[1]))); s.close()',
       IntToStr(FPort)],
      '',
      1000);
    if Probe.Success then
      Exit(True);

    Sleep(50);
  until GetTickCount64 >= Deadline;
end;

function TLocalHTTPServer.Start: Boolean;
var
  Attempt: Integer;
begin
  Result := False;
  Randomize;

  for Attempt := 0 to 15 do
  begin
    Stop;

    FPort := 38000 + Random(2000);
    FProcess := TProcess.Create(nil);
    try
      FProcess.Executable := 'python3';
      FProcess.Parameters.Add('-m');
      FProcess.Parameters.Add('http.server');
      FProcess.Parameters.Add(IntToStr(FPort));
      FProcess.Parameters.Add('--bind');
      FProcess.Parameters.Add('127.0.0.1');
      FProcess.CurrentDirectory := FRootDir;
      FProcess.Options := [poNoConsole];
      FProcess.Execute;
      if WaitUntilReady(2000) then
        Exit(True);
    except
      Stop;
    end;
    Stop;
  end;
end;

function TLocalHTTPServer.StartDelayed(ADelayMs: Integer): Boolean;
begin
  Result := False;
  Randomize;

  Stop;

  FPort := 38000 + Random(2000);
  FProcess := TProcess.Create(nil);
  try
    FProcess.Executable := 'python3';
    FProcess.Parameters.Add('-c');
    FProcess.Parameters.Add(
      'import http.server, os, socketserver, sys, time; ' +
      'time.sleep(float(sys.argv[1])); ' +
      'os.chdir(sys.argv[2]); ' +
      'socketserver.TCPServer.allow_reuse_address = True; ' +
      'handler = http.server.SimpleHTTPRequestHandler; ' +
      'httpd = socketserver.TCPServer(("127.0.0.1", int(sys.argv[3])), handler); ' +
      'httpd.serve_forever()');
    FProcess.Parameters.Add(Format('%.3f', [ADelayMs / 1000.0]));
    FProcess.Parameters.Add(FRootDir);
    FProcess.Parameters.Add(IntToStr(FPort));
    FProcess.Options := [poNoConsole];
    FProcess.Execute;
    Sleep(100);
    Result := FProcess.Running;
  except
    Stop;
  end;
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

procedure TestLegacyHTTPDownloadBridgeRetryWhenServerBecomesReady;
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
    Check('delayed http server process starts', Server.StartDelayed(600),
      'failed to launch delayed http server');
    Err := '';
    Bytes := 0;
    Check('legacy http bridge retries until server ready',
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
  Bytes: Int64;
  Err: string;
begin
  RootDir := CreateUniqueTempDir('test_iobridge_http_fail_root');
  TempFile := RootDir + PathDelim + 'downloaded.txt';
  try
    Err := '';
    Bytes := 0;
    Check('legacy http bridge failure returns false',
      not ExecuteFPCLegacyBinaryHTTPGetBridge(
        'http://127.0.0.1:39999/never-there.txt', TempFile, Bytes, Err),
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
    TestLegacyHTTPDownloadBridgeRetryWhenServerBecomesReady;
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
