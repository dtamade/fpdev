unit fpdev.fpc.sourcebootstrapflow;

{$mode objfpc}{$H+}

interface

type
  TFPCSourceBootstrapLogProc = procedure(const AText: string) of object;
  TFPCSourceBootstrapStringFunc = function(const AValue: string): string of object;
  TFPCSourceBootstrapFindSystemFunc = function: string of object;
  TFPCSourceBootstrapCompatibilityFunc = function(
    const ACompilerPath, ARequiredVersion: string
  ): Boolean of object;
  TFPCSourceBootstrapDownloadFunc = function(const AVersion: string): Boolean of object;
  TFPCSourceBootstrapDownloadArchiveFunc = function(
    const AURL, ADestFile: string
  ): Boolean of object;
  TFPCSourceBootstrapExtractArchiveFunc = function(
    const AArchive, ADestDir: string;
    out AEntryCount: Integer
  ): Boolean of object;

  TFPCSourceBootstrapEnsureCallbacks = record
    GetRequiredVersion: TFPCSourceBootstrapStringFunc;
    FindSystemCompiler: TFPCSourceBootstrapFindSystemFunc;
    IsCompatibleCompiler: TFPCSourceBootstrapCompatibilityFunc;
    GetBootstrapPath: TFPCSourceBootstrapStringFunc;
    DownloadBootstrap: TFPCSourceBootstrapDownloadFunc;
  end;

  TFPCSourceBootstrapDownloadCallbacks = record
    Log: TFPCSourceBootstrapLogProc;
    GetDownloadURL: TFPCSourceBootstrapStringFunc;
    GetBootstrapPath: TFPCSourceBootstrapStringFunc;
    DownloadArchive: TFPCSourceBootstrapDownloadArchiveFunc;
    ExtractArchive: TFPCSourceBootstrapExtractArchiveFunc;
  end;

function ExecuteFPCSourceEnsureBootstrapCore(
  const ATargetVersion: string;
  var ABootstrapCompiler: string;
  const ACallbacks: TFPCSourceBootstrapEnsureCallbacks
): Boolean;

function ExecuteFPCSourceBootstrapDownloadCore(
  const AVersion, ASourceRoot: string;
  const ACallbacks: TFPCSourceBootstrapDownloadCallbacks
): Boolean;

implementation

uses
  SysUtils, Classes, fphttpclient, opensslsockets, zipper, fpdev.utils.fs;

procedure LogMessage(const ALog: TFPCSourceBootstrapLogProc; const AText: string);
begin
  if Assigned(ALog) then
    ALog(AText);
end;

function DefaultDownloadArchive(const AURL, ADestFile: string): Boolean;
var
  HTTPClient: TFPHTTPClient;
  FileStream: TFileStream;
begin
  HTTPClient := TFPHTTPClient.Create(nil);
  try
    HTTPClient.AllowRedirect := True;
    FileStream := TFileStream.Create(ADestFile, fmCreate);
    try
      HTTPClient.Get(AURL, FileStream);
      Result := True;
    finally
      FileStream.Free;
    end;
  finally
    HTTPClient.Free;
  end;
end;

function DefaultExtractArchive(
  const AArchive, ADestDir: string;
  out AEntryCount: Integer
): Boolean;
var
  Unzipper: TUnZipper;
begin
  Unzipper := TUnZipper.Create;
  try
    Unzipper.FileName := AArchive;
    Unzipper.OutputPath := ADestDir;
    Unzipper.Examine;
    AEntryCount := Unzipper.Entries.Count;
    Unzipper.UnZipAllFiles;
    Result := True;
  finally
    Unzipper.Free;
  end;
end;

function ExecuteFPCSourceEnsureBootstrapCore(
  const ATargetVersion: string;
  var ABootstrapCompiler: string;
  const ACallbacks: TFPCSourceBootstrapEnsureCallbacks
): Boolean;
var
  RequiredVersion: string;
  SystemCompiler: string;
  BootstrapPath: string;
begin
  RequiredVersion := ATargetVersion;
  if Assigned(ACallbacks.GetRequiredVersion) then
    RequiredVersion := ACallbacks.GetRequiredVersion(ATargetVersion);

  SystemCompiler := '';
  if Assigned(ACallbacks.FindSystemCompiler) then
    SystemCompiler := ACallbacks.FindSystemCompiler();

  if Assigned(ACallbacks.IsCompatibleCompiler) and
     ACallbacks.IsCompatibleCompiler(SystemCompiler, RequiredVersion) then
  begin
    ABootstrapCompiler := SystemCompiler;
    Exit(True);
  end;

  BootstrapPath := '';
  if Assigned(ACallbacks.GetBootstrapPath) then
    BootstrapPath := ACallbacks.GetBootstrapPath(RequiredVersion);

  if (BootstrapPath <> '') and FileExists(BootstrapPath) then
  begin
    ABootstrapCompiler := BootstrapPath;
    Exit(True);
  end;

  Result := Assigned(ACallbacks.DownloadBootstrap) and
    ACallbacks.DownloadBootstrap(RequiredVersion);
  if Result and Assigned(ACallbacks.GetBootstrapPath) then
    ABootstrapCompiler := ACallbacks.GetBootstrapPath(RequiredVersion);
end;

function ExecuteFPCSourceBootstrapDownloadCore(
  const AVersion, ASourceRoot: string;
  const ACallbacks: TFPCSourceBootstrapDownloadCallbacks
): Boolean;
var
  URL: string;
  TempFile: string;
  TempDir: string;
  BootstrapRoot: string;
  BootstrapPath: string;
  EntryCount: Integer;
  DownloadOK: Boolean;
  ExtractOK: Boolean;
begin
  Result := False;
  TempDir := '';
  TempFile := '';

  try
    URL := '';
    if Assigned(ACallbacks.GetDownloadURL) then
      URL := ACallbacks.GetDownloadURL(AVersion);
    if URL = '' then
    begin
      LogMessage(ACallbacks.Log,
        'Error: Failed to construct download URL for version ' + AVersion);
      Exit(False);
    end;

    TempDir := GetTempDir + 'fpdev_bootstrap_' + IntToStr(GetTickCount64);
    if not DirectoryExists(TempDir) then
      EnsureDir(TempDir);

    TempFile := TempDir + PathDelim + 'fpc-bootstrap-' + AVersion + '.zip';

    LogMessage(ACallbacks.Log,
      'Downloading bootstrap compiler ' + AVersion + ' from:');
    LogMessage(ACallbacks.Log, '  ' + URL);
    LogMessage(ACallbacks.Log, 'To: ' + TempFile);
    LogMessage(ACallbacks.Log, '');

    if Assigned(ACallbacks.DownloadArchive) then
      DownloadOK := ACallbacks.DownloadArchive(URL, TempFile)
    else
      DownloadOK := DefaultDownloadArchive(URL, TempFile);
    if not DownloadOK then
      Exit(False);

    BootstrapRoot := IncludeTrailingPathDelimiter(ASourceRoot) + 'bootstrap' +
      PathDelim + 'fpc-' + AVersion;
    if not DirectoryExists(BootstrapRoot) then
      EnsureDir(BootstrapRoot);

    LogMessage(ACallbacks.Log, 'Extracting bootstrap compiler to: ' + BootstrapRoot);

    if Assigned(ACallbacks.ExtractArchive) then
      ExtractOK := ACallbacks.ExtractArchive(TempFile, BootstrapRoot, EntryCount)
    else
      ExtractOK := DefaultExtractArchive(TempFile, BootstrapRoot, EntryCount);
    if not ExtractOK then
      Exit(False);

    LogMessage(ACallbacks.Log, '  Files in archive: ' + IntToStr(EntryCount));
    LogMessage(ACallbacks.Log, 'Extraction completed successfully');

    BootstrapPath := '';
    if Assigned(ACallbacks.GetBootstrapPath) then
      BootstrapPath := ACallbacks.GetBootstrapPath(AVersion);

    if (BootstrapPath <> '') and FileExists(BootstrapPath) then
    begin
      LogMessage(ACallbacks.Log, 'Bootstrap compiler verified: ' + BootstrapPath);
      Result := True;
    end
    else
    begin
      LogMessage(ACallbacks.Log,
        'Warning: Bootstrap compiler executable not found at expected path: ' + BootstrapPath);
      Result := False;
    end;
  except
    on E: Exception do
    begin
      LogMessage(ACallbacks.Log, 'Error downloading bootstrap compiler: ' + E.Message);
      Result := False;
    end;
  end;

  if (TempFile <> '') and FileExists(TempFile) then
    DeleteFile(TempFile);
  if (TempDir <> '') and DirectoryExists(TempDir) then
    RemoveDir(TempDir);
end;

end.
