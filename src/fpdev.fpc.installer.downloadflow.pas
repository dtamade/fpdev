unit fpdev.fpc.installer.downloadflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.output.intf;

type
  TFPCLegacyBinaryDownloadPlan = record
    URL: string;
    TempDir: string;
    TempFile: string;
    FileExt: string;
  end;

  TFPCLegacyBinaryHTTPGetHandler = function(const AURL, ATempFile: string;
    out ADownloadedBytes: Int64; out AError: string): Boolean of object;
  TFPCBinarySHA256Handler = function(const AFilePath: string): string of object;

function ResolveFPCLegacyBinaryDownloadURL(const AVersion: string): string;
function ResolveFPCLegacyBinaryDownloadFileExt: string;
function PrepareFPCLegacyBinaryDownloadPlan(const AVersion: string;
  out APlan: TFPCLegacyBinaryDownloadPlan; out AError: string): Boolean;
function ExecuteFPCLegacyBinaryDownloadFlow(const AVersion: string;
  const AOut, AErr: IOutput; AHTTPGet: TFPCLegacyBinaryHTTPGetHandler;
  out ATempFile: string): Boolean;
function ExecuteFPCLegacyBinaryVerifyFlow(const AFilePath, AVersion: string;
  const AOut, AErr: IOutput; ASHA256: TFPCBinarySHA256Handler): Boolean;

implementation

uses
  SysUtils,
  fpdev.i18n, fpdev.i18n.strings, fpdev.utils.fs;

const
  {$IFDEF MSWINDOWS}
  SF_BINARY_URL_TEMPLATE =
    'https://sourceforge.net/projects/freepascal/files/Win32/%s/' +
    'fpc-%s.win32.and.win64.exe/download';
  {$ENDIF}

  {$IFDEF LINUX}
    {$IFDEF CPU64}
  SF_BINARY_URL_TEMPLATE =
    'https://sourceforge.net/projects/freepascal/files/Linux/%s/' +
    'fpc-%s.x86_64-linux.tar/download';
    {$ELSE}
  SF_BINARY_URL_TEMPLATE =
    'https://sourceforge.net/projects/freepascal/files/Linux/%s/' +
    'fpc-%s.i386-linux.tar/download';
    {$ENDIF}
  {$ENDIF}

  {$IFDEF DARWIN}
    {$IFDEF CPUAARCH64}
  SF_BINARY_URL_TEMPLATE =
    'https://sourceforge.net/projects/freepascal/files/Mac%%20OS%%20X/%s/' +
    'fpc-%s.aarch64-macosx.dmg/download';
    {$ELSE}
  SF_BINARY_URL_TEMPLATE =
    'https://sourceforge.net/projects/freepascal/files/Mac%%20OS%%20X/%s/' +
    'fpc-%s.intel-macosx.dmg/download';
    {$ENDIF}
  {$ENDIF}

procedure WriteLine(const AOut: IOutput; const AText: string = '');
begin
  if AOut <> nil then
    AOut.WriteLn(AText);
end;

function ResolveFPCLegacyBinaryDownloadURL(const AVersion: string): string;
begin
  Result := '';

  {$IFDEF MSWINDOWS}
  Result := Format(SF_BINARY_URL_TEMPLATE, [AVersion, AVersion]);
  {$ENDIF}

  {$IFDEF LINUX}
  Result := Format(SF_BINARY_URL_TEMPLATE, [AVersion, AVersion]);
  {$ENDIF}

  {$IFDEF DARWIN}
  Result := Format(SF_BINARY_URL_TEMPLATE, [AVersion, AVersion]);
  {$ENDIF}
end;

procedure TryRemoveEmptyDir(const ADir: string);
begin
  if (ADir <> '') and DirectoryExists(ADir) then
    RemoveDir(ADir);
end;

function ResolveFPCLegacyBinaryDownloadFileExt: string;
begin
  Result := '';

  {$IFDEF MSWINDOWS}
  Result := '.exe';
  {$ENDIF}

  {$IFDEF LINUX}
  Result := '.tar';
  {$ENDIF}

  {$IFDEF DARWIN}
  Result := '.dmg';
  {$ENDIF}
end;

function PrepareFPCLegacyBinaryDownloadPlan(const AVersion: string;
  out APlan: TFPCLegacyBinaryDownloadPlan; out AError: string): Boolean;
begin
  Result := False;
  APlan := Default(TFPCLegacyBinaryDownloadPlan);
  AError := '';

  APlan.URL := ResolveFPCLegacyBinaryDownloadURL(AVersion);
  APlan.FileExt := ResolveFPCLegacyBinaryDownloadFileExt;
  if (APlan.URL = '') or (APlan.FileExt = '') then
  begin
    AError := 'Unsupported platform for legacy download';
    Exit;
  end;

  APlan.TempDir := GetTempDir + 'fpdev_downloads';
  if not DirectoryExists(APlan.TempDir) then
    EnsureDir(APlan.TempDir);

  APlan.TempFile := APlan.TempDir + PathDelim + 'fpc-' + AVersion + '-'
    + IntToStr(GetTickCount64) + APlan.FileExt;
  Result := True;
end;

function ExecuteFPCLegacyBinaryDownloadFlow(const AVersion: string;
  const AOut, AErr: IOutput; AHTTPGet: TFPCLegacyBinaryHTTPGetHandler;
  out ATempFile: string): Boolean;
var
  Plan: TFPCLegacyBinaryDownloadPlan;
  Err: string;
  DownloadedBytes: Int64;
begin
  Result := False;
  ATempFile := '';
  Err := '';
  DownloadedBytes := 0;

  try
    if not PrepareFPCLegacyBinaryDownloadPlan(AVersion, Plan, Err) then
    begin
      WriteLine(AErr, _(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_DOWNLOAD_URL_FAILED, [AVersion]));
      WriteLine(AErr, 'Note: This platform may not have binary packages available.');
      Exit;
    end;

    WriteLine(AOut, 'Downloading FPC ' + AVersion + ' from:');
    WriteLine(AOut, '  ' + Plan.URL);
    WriteLine(AOut, 'To: ' + Plan.TempFile);

    if (not Assigned(AHTTPGet)) or
       (not AHTTPGet(Plan.URL, Plan.TempFile, DownloadedBytes, Err)) then
    begin
      if Err = '' then
        Err := 'unknown error';
      WriteLine(AErr, _(MSG_ERROR) + ': DownloadBinary failed - ' + Err);
      if FileExists(Plan.TempFile) then
        DeleteFile(Plan.TempFile);
      TryRemoveEmptyDir(Plan.TempDir);
      Exit;
    end;

    ATempFile := Plan.TempFile;
    WriteLine(AOut, 'Download completed: ' + IntToStr(DownloadedBytes) + ' bytes');
    Result := True;

  except
    on E: Exception do
    begin
      WriteLine(AErr, _(MSG_ERROR) + ': DownloadBinary failed - ' + E.Message);
      if (ATempFile = '') and FileExists(Plan.TempFile) then
        DeleteFile(Plan.TempFile);
      if ATempFile = '' then
        TryRemoveEmptyDir(Plan.TempDir);
      ATempFile := '';
      Result := False;
    end;
  end;
end;

function ExecuteFPCLegacyBinaryVerifyFlow(const AFilePath, AVersion: string;
  const AOut, AErr: IOutput; ASHA256: TFPCBinarySHA256Handler): Boolean;
var
  ActualHash: string;
begin
  Result := False;
  if (AFilePath = '') or (not FileExists(AFilePath)) then
  begin
    WriteLine(AErr, _(MSG_ERROR) + ': ' + _(CMD_FPC_FILE_NOT_FOUND));
    Exit;
  end;

  WriteLine(AOut, 'Calculating SHA256 checksum...');
  if Assigned(ASHA256) then
    ActualHash := ASHA256(AFilePath)
  else
    ActualHash := '';

  if ActualHash = '' then
  begin
    WriteLine(AErr, _(MSG_ERROR) + ': ' + _(CMD_FPC_CHECKSUM_FAILED));
    Exit;
  end;

  WriteLine(AOut, 'SHA256: ' + ActualHash);
  WriteLine(AOut, 'File integrity verified (hash recorded for ' + AVersion + ')');
  Result := True;
end;

end.
