unit fpdev.fpc.installer.nestedflow;

{$mode objfpc}{$H+}

interface

uses
  fpdev.output.intf;

type
  TFPCNestedArchiveExtractHandler = function(const AArchivePath,
    ADestPath: string): Boolean of object;

function ExecuteFPCNestedPackageInstallFlow(const ATempDir,
  AInstallPath, ATempFile: string; const AOut, AErr: IOutput;
  AExtractArchive: TFPCNestedArchiveExtractHandler): Boolean;

implementation

uses
  SysUtils,
  fpdev.fpc.installer.extract;

procedure WriteLine(const AOut: IOutput; const AText: string = '');
begin
  if AOut <> nil then
    AOut.WriteLn(AText);
end;

function FindExtractedSubDir(const ATempDir: string): string;
var
  SR: TSearchRec;
begin
  Result := '';
  if FindFirst(ATempDir + PathDelim + '*', faDirectory, SR) = 0 then
  begin
    repeat
      if (SR.Name <> '.') and (SR.Name <> '..') and ((SR.Attr and faDirectory) <> 0) then
      begin
        Result := ATempDir + PathDelim + SR.Name;
        Break;
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

function HasInstalledArtifacts(const AInstallPath: string): Boolean;
begin
  Result := DirectoryExists(AInstallPath + PathDelim + 'bin') or
    DirectoryExists(AInstallPath + PathDelim + 'lib');
end;

function ExecuteFPCNestedPackageInstallFlow(const ATempDir,
  AInstallPath, ATempFile: string; const AOut, AErr: IOutput;
  AExtractArchive: TFPCNestedArchiveExtractHandler): Boolean;
var
  ExtractedSubDir: string;
  BinaryTar: string;
  BaseArchive: string;
begin
  Result := False;

  ExtractedSubDir := FindExtractedSubDir(ATempDir);
  BinaryTar := '';
  if ExtractedSubDir <> '' then
    BinaryTar := TFPCArchiveExtractor.FindBinaryArchive(ExtractedSubDir);

  if (BinaryTar <> '') and FileExists(BinaryTar) then
  begin
    WriteLine(AOut, '[Manifest] Extracting nested binary TAR...');
    if (not Assigned(AExtractArchive)) or
       (not AExtractArchive(BinaryTar, AInstallPath)) then
    begin
      WriteLine(AErr, '[Manifest] Nested extraction failed');
      Exit;
    end;

    BaseArchive := TFPCArchiveExtractor.FindBaseArchive(AInstallPath);
    if (BaseArchive <> '') and FileExists(BaseArchive) then
    begin
      WriteLine(AOut, '[Manifest] Extracting base package...');
      if (not Assigned(AExtractArchive)) or
         (not AExtractArchive(BaseArchive, AInstallPath)) then
      begin
        WriteLine(AErr, '[Manifest] Base package extraction failed');
        Exit;
      end;
      DeleteFile(BaseArchive);
    end
    else
      WriteLine(AOut, '[Manifest] No base archive found, checking if binaries are directly available...');
  end
  else
  begin
    WriteLine(AOut, '[Manifest] No nested TAR found, using direct extraction');
    if (not Assigned(AExtractArchive)) or
       (not AExtractArchive(ATempFile, AInstallPath)) then
    begin
      WriteLine(AErr, '[Manifest] Extraction failed');
      Exit;
    end;
  end;

  if not HasInstalledArtifacts(AInstallPath) then
  begin
    WriteLine(AErr, '[Manifest] Post-extraction validation failed: no bin/ or lib/ directory found');
    WriteLine(AErr, '[Manifest] Installation directory may be incomplete');
    Exit;
  end;

  WriteLine(AOut, '[Manifest] Extraction completed');
  Result := True;
end;

end.
