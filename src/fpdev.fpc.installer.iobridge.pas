unit fpdev.fpc.installer.iobridge;

{$mode objfpc}{$H+}

interface

function ExecuteFPCLegacyBinaryHTTPGetBridge(const AURL, ATempFile: string;
  out ADownloadedBytes: Int64; out AError: string): Boolean;
function ExecuteFPCZipExtractBridge(const AArchivePath, ADestPath: string;
  out AEntryCount: Integer): Boolean;
function ExecuteFPCTarExtractBridge(const AArchivePath, ADestPath: string;
  out AExitCode: Integer): Boolean;
function ExecuteFPCTarGzExtractBridge(const AArchivePath, ADestPath: string;
  out AExitCode: Integer): Boolean;

implementation

uses
  Classes, SysUtils, fphttpclient, zipper,
  fpdev.utils.process;

const
  LEGACY_HTTP_GET_MAX_ATTEMPTS = 4;
  LEGACY_HTTP_GET_RETRY_DELAY_MS = 250;
  LEGACY_HTTP_GET_DEFAULT_ERROR = 'HTTP download failed';

procedure CleanupLegacyHTTPBridgeTempFile(const ATempFile: string);
begin
  if FileExists(ATempFile) then
    DeleteFile(ATempFile);
end;

function IsRetryableLegacyHTTPBridgeError(const AError: string): Boolean;
var
  NormalizedError: string;
begin
  NormalizedError := LowerCase(Trim(AError));
  if NormalizedError = '' then
    Exit(True);

  if (Pos(' 400 ', ' ' + NormalizedError + ' ') > 0) or
     (Pos(' 401 ', ' ' + NormalizedError + ' ') > 0) or
     (Pos(' 403 ', ' ' + NormalizedError + ' ') > 0) or
     (Pos(' 404 ', ' ' + NormalizedError + ' ') > 0) or
     (Pos('not found', NormalizedError) > 0) then
    Exit(False);

  Result :=
    (Pos('connect', NormalizedError) > 0) or
    (Pos('connection', NormalizedError) > 0) or
    (Pos('timeout', NormalizedError) > 0) or
    (Pos('timed out', NormalizedError) > 0) or
    (Pos('socket', NormalizedError) > 0) or
    (Pos('temporarily unavailable', NormalizedError) > 0) or
    (Pos('refused', NormalizedError) > 0) or
    (Pos('reset by peer', NormalizedError) > 0);
end;

function ExecuteFPCLegacyBinaryHTTPGetAttempt(const AURL, ATempFile: string;
  out ADownloadedBytes: Int64; out AError: string): Boolean;
var
  HTTPClient: TFPHTTPClient;
  FileStream: TFileStream;
  TempDir: string;
begin
  Result := False;
  ADownloadedBytes := 0;
  AError := '';

  HTTPClient := TFPHTTPClient.Create(nil);
  try
    HTTPClient.AllowRedirect := True;
    HTTPClient.ConnectTimeout := 30000;
    HTTPClient.IOTimeout := 30000;

    TempDir := ExtractFileDir(ATempFile);
    if TempDir <> '' then
      ForceDirectories(TempDir);

    FileStream := TFileStream.Create(ATempFile, fmCreate);
    try
      HTTPClient.Get(AURL, FileStream);
      ADownloadedBytes := FileStream.Size;
      Result := True;
    finally
      FileStream.Free;
    end;
  except
    on E: Exception do
    begin
      AError := Trim(E.Message);
      CleanupLegacyHTTPBridgeTempFile(ATempFile);
      if AError = '' then
        AError := LEGACY_HTTP_GET_DEFAULT_ERROR;
      Result := False;
    end;
  end;
  HTTPClient.Free;
end;

function ExecuteFPCLegacyBinaryHTTPGetBridge(const AURL, ATempFile: string;
  out ADownloadedBytes: Int64; out AError: string): Boolean;
var
  Attempt: Integer;
  LastError: string;
begin
  Result := False;
  ADownloadedBytes := 0;
  AError := '';
  LastError := '';

  for Attempt := 1 to LEGACY_HTTP_GET_MAX_ATTEMPTS do
  begin
    if ExecuteFPCLegacyBinaryHTTPGetAttempt(AURL, ATempFile,
      ADownloadedBytes, AError) then
      Exit(True);

    LastError := AError;
    if (Attempt >= LEGACY_HTTP_GET_MAX_ATTEMPTS) or
       (not IsRetryableLegacyHTTPBridgeError(AError)) then
      Break;

    Sleep(LEGACY_HTTP_GET_RETRY_DELAY_MS);
  end;

  ADownloadedBytes := 0;
  if LastError <> '' then
    AError := LastError
  else
    AError := LEGACY_HTTP_GET_DEFAULT_ERROR;
end;

function ExecuteFPCZipExtractBridge(const AArchivePath, ADestPath: string;
  out AEntryCount: Integer): Boolean;
var
  Unzipper: TUnZipper;
begin
  Result := False;
  AEntryCount := 0;

  Unzipper := TUnZipper.Create;
  try
    Unzipper.FileName := AArchivePath;
    Unzipper.OutputPath := ADestPath;
    Unzipper.Examine;
    AEntryCount := Unzipper.Entries.Count;
    Unzipper.UnZipAllFiles;
    Result := True;
  finally
    Unzipper.Free;
  end;
end;

function ExecuteFPCTarExtractBridge(const AArchivePath, ADestPath: string;
  out AExitCode: Integer): Boolean;
var
  LResult: fpdev.utils.process.TProcessResult;
begin
  LResult := TProcessExecutor.Execute('tar', ['-xf', AArchivePath, '-C', ADestPath], '');
  AExitCode := LResult.ExitCode;
  Result := LResult.Success;
end;

function ExecuteFPCTarGzExtractBridge(const AArchivePath, ADestPath: string;
  out AExitCode: Integer): Boolean;
var
  LResult: fpdev.utils.process.TProcessResult;
begin
  LResult := TProcessExecutor.Execute('tar', ['-xzf', AArchivePath, '-C', ADestPath], '');
  AExitCode := LResult.ExitCode;
  Result := LResult.Success;
end;

end.
