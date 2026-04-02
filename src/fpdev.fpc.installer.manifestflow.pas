unit fpdev.fpc.installer.manifestflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.output.intf, fpdev.fpc.installer.manifestplan;

type
  TFPCManifestPreparePlanHandler = function(const AVersion: string;
    out APlan: TFPCManifestInstallPlan; out AError: string): Boolean of object;
  TFPCManifestFetchDownloadHandler = function(
    const APlan: TFPCManifestInstallPlan; out AError: string): Boolean of object;
  TFPCManifestArchiveExtractHandler = function(const AArchivePath,
    ADestPath: string): Boolean of object;
  TFPCManifestNestedInstallHandler = function(const ATempDir,
    AInstallPath, ATempFile: string): Boolean of object;

function ExecuteFPCManifestInstallFlow(const AVersion,
  AInstallPath: string; const AOut, AErr: IOutput;
  APreparePlan: TFPCManifestPreparePlanHandler;
  AFetchDownload: TFPCManifestFetchDownloadHandler;
  AExtractArchive: TFPCManifestArchiveExtractHandler;
  AExtractNestedPackage: TFPCManifestNestedInstallHandler): Boolean;

implementation

uses
  SysUtils,
  fpdev.utils.fs;

procedure WriteLine(const AOut: IOutput; const AText: string = '');
begin
  if AOut <> nil then
    AOut.WriteLn(AText);
end;

procedure TryRemoveEmptyDir(const ADir: string);
begin
  if (ADir <> '') and DirectoryExists(ADir) then
    RemoveDir(ADir);
end;

function ExecuteFPCManifestInstallFlow(const AVersion,
  AInstallPath: string; const AOut, AErr: IOutput;
  APreparePlan: TFPCManifestPreparePlanHandler;
  AFetchDownload: TFPCManifestFetchDownloadHandler;
  AExtractArchive: TFPCManifestArchiveExtractHandler;
  AExtractNestedPackage: TFPCManifestNestedInstallHandler): Boolean;
var
  Plan: TFPCManifestInstallPlan;
  Err: string;
begin
  Result := False;
  Plan := Default(TFPCManifestInstallPlan);
  Err := '';

  try
    WriteLine(AOut, '[Manifest] Attempting installation using manifest system...');
    WriteLine(AOut, '[Manifest] Loading manifest from cache...');

    if (not Assigned(APreparePlan)) or
       (not APreparePlan(AVersion, Plan, Err)) then
    begin
      if Err = 'Failed to load manifest' then
      begin
        WriteLine(AErr, '[Manifest] Failed to load manifest');
        WriteLine(AErr, '[Manifest] Try running: fpdev fpc update-manifest');
      end
      else
        WriteLine(AErr, '[Manifest] ' + Err);
      Exit;
    end;

    WriteLine(AOut, '[Manifest] Platform: ' + Plan.Platform);
    WriteLine(AOut, '[Manifest] Manifest loaded successfully');
    WriteLine(AOut, '[Manifest] Found target with ' + IntToStr(Length(Plan.Target.URLs)) + ' mirror(s)');
    WriteLine(AOut, '[Manifest] Hash: ' + Plan.Target.Hash);
    WriteLine(AOut, '[Manifest] Size: ' + IntToStr(Plan.Target.Size) + ' bytes');
    WriteLine(AOut, '[Manifest] Downloading with multi-mirror fallback...');

    if (not Assigned(AFetchDownload)) or
       (not AFetchDownload(Plan, Err)) then
    begin
      WriteLine(AErr, '[Manifest] Download failed: ' + Err);
      TryRemoveEmptyDir(Plan.DownloadDir);
      Exit;
    end;

    WriteLine(AOut, '[Manifest] Download completed and verified');
    WriteLine(AOut, '[Manifest] Extracting archive...');

    if not DirectoryExists(Plan.ExtractDir) then
      EnsureDir(Plan.ExtractDir);

    try
      if (not Assigned(AExtractArchive)) or
         (not AExtractArchive(Plan.DownloadFile, Plan.ExtractDir)) then
      begin
        WriteLine(AErr, '[Manifest] Extraction failed');
        Exit;
      end;

      Result := Assigned(AExtractNestedPackage) and
        AExtractNestedPackage(Plan.ExtractDir, AInstallPath, Plan.DownloadFile);
    finally
      if FileExists(Plan.DownloadFile) then
        DeleteFile(Plan.DownloadFile);
      TryRemoveEmptyDir(Plan.DownloadDir);
      if DirectoryExists(Plan.ExtractDir) then
        DeleteDirRecursive(Plan.ExtractDir);
    end;

  except
    on E: Exception do
    begin
      WriteLine(AErr, '[Manifest] InstallFromManifest failed: ' + E.Message);
      TryRemoveEmptyDir(Plan.DownloadDir);
      Result := False;
    end;
  end;
end;

end.
