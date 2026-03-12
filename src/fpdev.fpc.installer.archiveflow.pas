unit fpdev.fpc.installer.archiveflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.output.intf;

type
  TFPCZipExtractHandler = function(const AArchivePath,
    ADestPath: string; out AEntryCount: Integer): Boolean of object;
  TFPCTarExtractHandler = function(const AArchivePath,
    ADestPath: string; out AExitCode: Integer): Boolean of object;

function ExecuteFPCInstallerArchiveFlow(const AArchivePath,
  ADestPath: string; const AOut, AErr: IOutput;
  AZipExtract: TFPCZipExtractHandler;
  ATarExtract: TFPCTarExtractHandler;
  ATarGzExtract: TFPCTarExtractHandler): Boolean;

implementation

uses
  SysUtils,
  fpdev.i18n, fpdev.i18n.strings, fpdev.utils.fs;

procedure WriteLine(const AOut: IOutput; const AText: string = '');
begin
  if AOut <> nil then
    AOut.WriteLn(AText);
end;

function ExecuteFPCInstallerArchiveFlow(const AArchivePath,
  ADestPath: string; const AOut, AErr: IOutput;
  AZipExtract: TFPCZipExtractHandler;
  ATarExtract: TFPCTarExtractHandler;
  ATarGzExtract: TFPCTarExtractHandler): Boolean;
var
  FileExt: string;
  ExitCode: Integer;
  EntryCount: Integer;
begin
  Result := False;

  if not FileExists(AArchivePath) then
  begin
    WriteLine(AErr, _(MSG_ERROR) + ': ' +
      _Fmt(CMD_FPC_ARCHIVE_NOT_FOUND, [AArchivePath]));
    Exit;
  end;

  try
    if not DirectoryExists(ADestPath) then
      EnsureDir(ADestPath);

    FileExt := LowerCase(ExtractFileExt(AArchivePath));

    if FileExt = '.zip' then
    begin
      WriteLine(AOut, 'Extracting ZIP archive...');
      WriteLine(AOut, '  From: ' + AArchivePath);
      WriteLine(AOut, '  To: ' + ADestPath);
      EntryCount := 0;
      Result := Assigned(AZipExtract) and AZipExtract(AArchivePath, ADestPath, EntryCount);
      if Result then
      begin
        WriteLine(AOut, '  Files in archive: ' + IntToStr(EntryCount));
        WriteLine(AOut, 'Extraction completed successfully');
      end;
    end
    else if FileExt = '.tar' then
    begin
      WriteLine(AOut, 'Extracting TAR archive...');
      WriteLine(AOut, '  From: ' + AArchivePath);
      WriteLine(AOut, '  To: ' + ADestPath);
      WriteLine(AOut, '  Running: tar -xf ' + AArchivePath + ' -C ' + ADestPath);
      ExitCode := 0;
      Result := Assigned(ATarExtract) and ATarExtract(AArchivePath, ADestPath, ExitCode);
      if Result then
        WriteLine(AOut, 'TAR extraction completed successfully')
      else
        WriteLine(AErr, _(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_TAR_FAILED, [ExitCode]));
    end
    else if (FileExt = '.gz') or (Pos('.tar.gz', LowerCase(AArchivePath)) > 0) then
    begin
      WriteLine(AOut, 'Extracting TAR.GZ archive...');
      WriteLine(AOut, '  From: ' + AArchivePath);
      WriteLine(AOut, '  To: ' + ADestPath);
      WriteLine(AOut, '  Running: tar -xzf ' + AArchivePath + ' -C ' + ADestPath);
      ExitCode := 0;
      Result := Assigned(ATarGzExtract) and ATarGzExtract(AArchivePath, ADestPath, ExitCode);
      if Result then
        WriteLine(AOut, 'TAR.GZ extraction completed successfully')
      else
        WriteLine(AErr, _(MSG_ERROR) + ': ' + _Fmt(CMD_FPC_TAR_FAILED, [ExitCode]));
    end
    else if FileExt = '.exe' then
    begin
      WriteLine(AOut, 'Windows installer detected: ' + AArchivePath);
      WriteLine(AOut, '  Target directory: ' + ADestPath);
      WriteLine(AOut);
      WriteLine(AOut, 'Note: Windows FPC installers are interactive.');
      WriteLine(AOut, 'Please run the installer manually and select:');
      WriteLine(AOut, '  ' + ADestPath);
      WriteLine(AOut, 'as the installation directory.');
      WriteLine(AOut);
      WriteLine(AOut, 'After installation, run:');
      WriteLine(AOut, '  fpdev fpc use <version>');
      WriteLine(AOut, 'to configure the environment.');
      Result := True;
    end
    else if FileExt = '.dmg' then
    begin
      WriteLine(AOut, 'macOS disk image detected: ' + AArchivePath);
      WriteLine(AOut, '  Target directory: ' + ADestPath);
      WriteLine(AOut);
      WriteLine(AOut, 'Note: macOS .dmg files require manual installation.');
      WriteLine(AOut, 'Please mount the disk image and run the installer.');
      WriteLine(AOut);
      WriteLine(AOut, 'After installation, run:');
      WriteLine(AOut, '  fpdev fpc use <version>');
      WriteLine(AOut, 'to configure the environment.');
      Result := True;
    end
    else
      WriteLine(AErr, _(MSG_ERROR) + ': ' +
        _Fmt(CMD_FPC_ARCHIVE_FORMAT_UNSUPPORTED, [FileExt]));

  except
    on E: Exception do
    begin
      WriteLine(AErr, _(MSG_ERROR) + ': ExtractArchive failed - ' + E.Message);
      Result := False;
    end;
  end;
end;

end.
