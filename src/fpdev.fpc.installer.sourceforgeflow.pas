unit fpdev.fpc.installer.sourceforgeflow;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.output.intf;

type
  TFPCSourceForgeDownloadHandler = function(const AVersion: string;
    out ATempFile: string): Boolean of object;
  TFPCSourceForgeLinuxExtractHandler = function(const ATempFile,
    ATempDir, AInstallPath: string): Boolean of object;

function ExecuteFPCSourceForgeInstallFlow(const AVersion,
  AInstallPath: string; const AOut, AErr: IOutput;
  ADownloadBinary: TFPCSourceForgeDownloadHandler;
  AExtractLinuxTarball: TFPCSourceForgeLinuxExtractHandler): Boolean;

implementation

uses
  fpdev.i18n, fpdev.i18n.strings, fpdev.utils.fs;

procedure WriteLine(const AOut: IOutput; const AText: string = '');
begin
  if AOut <> nil then
    AOut.WriteLn(AText);
end;

function ExecuteFPCSourceForgeInstallFlow(const AVersion,
  AInstallPath: string; const AOut, AErr: IOutput;
  ADownloadBinary: TFPCSourceForgeDownloadHandler;
  AExtractLinuxTarball: TFPCSourceForgeLinuxExtractHandler): Boolean;
var
  TempFile: string;
  TempDir: string;
begin
  Result := False;
  TempFile := '';
  TempDir := '';

  try
    WriteLine(AOut, '  Downloading from SourceForge...');
    if (not Assigned(ADownloadBinary)) or
       (not ADownloadBinary(AVersion, TempFile)) then
    begin
      WriteLine(AErr, _(MSG_ERROR) + ': Failed to download FPC binary');
      Exit;
    end;

    WriteLine(AOut, '  Download completed: ' + TempFile);

    if not DirectoryExists(AInstallPath) then
      EnsureDir(AInstallPath);

    {$IFDEF LINUX}
    TempDir := IncludeTrailingPathDelimiter(GetTempDir(False))
      + 'fpdev_fpc_' + IntToStr(GetTickCount64);
    EnsureDir(TempDir);
    try
      if (not Assigned(AExtractLinuxTarball)) or
         (not AExtractLinuxTarball(TempFile, TempDir, AInstallPath)) then
        Exit;
    finally
      if (TempDir <> '') and DirectoryExists(TempDir) then
        DeleteDirRecursive(TempDir);
    end;
    {$ENDIF}

    {$IFDEF MSWINDOWS}
    WriteLine(AOut);
    WriteLine(AOut, 'Windows FPC installer downloaded: ' + TempFile);
    WriteLine(AOut);
    WriteLine(AOut, 'Please run the installer manually and select:');
    WriteLine(AOut, '  ' + AInstallPath);
    WriteLine(AOut, 'as the installation directory.');
    WriteLine(AOut);
    WriteLine(AOut, 'After installation, run:');
    WriteLine(AOut, '  fpdev fpc use ' + AVersion);
    Result := True;
    Exit;
    {$ENDIF}

    {$IFDEF DARWIN}
    WriteLine(AOut);
    WriteLine(AOut, 'macOS FPC disk image downloaded: ' + TempFile);
    WriteLine(AOut);
    WriteLine(AOut, 'Please mount the disk image and run the installer.');
    WriteLine(AOut);
    WriteLine(AOut, 'After installation, run:');
    WriteLine(AOut, '  fpdev fpc use ' + AVersion);
    Result := True;
    Exit;
    {$ENDIF}

    if FileExists(TempFile) then
      DeleteFile(TempFile);

    if DirectoryExists(AInstallPath + PathDelim + 'bin') or
       DirectoryExists(AInstallPath + PathDelim + 'lib') then
    begin
      WriteLine(AOut, '  Installation verified');
      Result := True;
    end
    else
    begin
      WriteLine(AErr);
      WriteLine(AErr, '===========================================');
      WriteLine(AErr, 'Binary Installation Failed');
      WriteLine(AErr, '===========================================');
      WriteLine(AErr);
      WriteLine(AErr, 'No binary packages are currently available for automatic download.');
      WriteLine(AErr);
      WriteLine(AErr, 'Options:');
      WriteLine(AErr, '  1. Install from source (requires bootstrap compiler):');
      WriteLine(AErr, '     fpdev fpc install ' + AVersion + ' --from-source');
      WriteLine(AErr);
      WriteLine(AErr, '  2. Use existing FPC installation:');
      WriteLine(AErr, '     fpdev fpc use <version>');
      WriteLine(AErr);
      WriteLine(AErr, '  3. Download manually from:');
      WriteLine(AErr, '     https://www.freepascal.org/download.html');
      WriteLine(AErr);
      WriteLine(AErr, 'Note: Binary downloads are not yet available in this version.');
      WriteLine(AErr, '      Source installation is the recommended method.');
      Exit(False);
    end;

  except
    on E: Exception do
    begin
      WriteLine(AErr, _(MSG_ERROR) + ': InstallFromSourceForge failed - ' + E.Message);
      Result := False;
    end;
  end;
end;

end.
