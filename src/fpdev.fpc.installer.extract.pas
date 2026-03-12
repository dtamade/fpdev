unit fpdev.fpc.installer.extract;

{$mode objfpc}{$H+}

{
  FPC Binary Extraction Helper

  Handles the multi-layer extraction of SourceForge FPC tarballs:
    1. Outer tar: fpc-X.Y.Z.x86_64-linux.tar
    2. Binary tar: binary.x86_64-linux.tar
    3. Base tar.gz: base.x86_64-linux.tar.gz (contains bin/ and lib/)
}

interface

uses
  SysUtils, Classes,
  fpdev.output.intf, fpdev.utils.process, fpdev.utils.fs;

type
  { TFPCExtractResult }
  TFPCExtractResult = record
    Success: Boolean;
    ErrorMsg: string;
    ExtractedDir: string;
  end;

  { TFPCArchiveExtractor - Static helper for FPC archive extraction }
  TFPCArchiveExtractor = class
  public
    { Extract outer tar archive to temp directory }
    class function ExtractOuterTar(const ATarFile, ATempDir: string;
      const AOut: IOutput): TFPCExtractResult; static;

    { Find binary archive in extracted directory (binary.*.tar) }
    class function FindBinaryArchive(const AExtractDir: string): string; static;

    { Find base archive in inner directory (base.*.tar.gz) }
    class function FindBaseArchive(const AInnerDir: string): string; static;

    { Extract binary.*.tar to get inner archives }
    class function ExtractBinaryArchive(const ABinaryTar, AInnerDir: string;
      const AOut: IOutput): TFPCExtractResult; static;

    { Extract base.*.tar.gz to installation directory }
    class function ExtractBaseArchive(const ABaseTarGz, AInstallPath: string;
      const AOut: IOutput): TFPCExtractResult; static;

    { Full extraction pipeline: outer tar -> binary tar -> base tar.gz }
    class function ExtractLinuxFPCTarball(const ATarFile, ATempDir, AInstallPath: string;
      const AOut, AErr: IOutput): TFPCExtractResult; static;
  end;

implementation

class function TFPCArchiveExtractor.ExtractOuterTar(const ATarFile, ATempDir: string;
  const AOut: IOutput): TFPCExtractResult;
var
  LResult: fpdev.utils.process.TProcessResult;
  LSList: TStringList;
begin
  Result.Success := False;
  Result.ErrorMsg := '';
  Result.ExtractedDir := '';

  AOut.WriteLn('  Extracting archive...');
  LResult := TProcessExecutor.Execute('tar', ['-xf', ATarFile, '-C', ATempDir], '');
  if not LResult.Success then
  begin
    Result.ErrorMsg := 'Failed to extract archive';
    Exit;
  end;

  // Find the extracted directory (usually fpc-<version>.x86_64-linux or similar)
  LResult := TProcessExecutor.Execute('ls', [ATempDir], '');
  if LResult.Success then
  begin
    LSList := TStringList.Create;
    try
      LSList.Text := LResult.StdOut;
      if LSList.Count > 0 then
        Result.ExtractedDir := ATempDir + PathDelim + Trim(LSList[0]);
    finally
      LSList.Free;
    end;
  end;

  if (Result.ExtractedDir = '') or not DirectoryExists(Result.ExtractedDir) then
  begin
    Result.ErrorMsg := 'Could not find extracted FPC directory';
    Exit;
  end;

  Result.Success := True;
end;

class function TFPCArchiveExtractor.FindBinaryArchive(const AExtractDir: string): string;
var
  LResult: fpdev.utils.process.TProcessResult;
  LSList: TStringList;
  I: Integer;
begin
  Result := '';
  LResult := TProcessExecutor.Execute('ls', [AExtractDir], '');
  if LResult.Success then
  begin
    LSList := TStringList.Create;
    try
      LSList.Text := LResult.StdOut;
      for I := 0 to LSList.Count - 1 do
      begin
        if Pos('binary.', Trim(LSList[I])) = 1 then
        begin
          Result := AExtractDir + PathDelim + Trim(LSList[I]);
          Break;
        end;
      end;
    finally
      LSList.Free;
    end;
  end;
end;

class function TFPCArchiveExtractor.FindBaseArchive(const AInnerDir: string): string;
var
  LResult: fpdev.utils.process.TProcessResult;
  LSList: TStringList;
  I: Integer;
begin
  Result := '';
  LResult := TProcessExecutor.Execute('ls', [AInnerDir], '');
  if LResult.Success then
  begin
    LSList := TStringList.Create;
    try
      LSList.Text := LResult.StdOut;
      for I := 0 to LSList.Count - 1 do
      begin
        if Pos('base.', Trim(LSList[I])) = 1 then
        begin
          Result := AInnerDir + PathDelim + Trim(LSList[I]);
          Break;
        end;
      end;
    finally
      LSList.Free;
    end;
  end;
end;

class function TFPCArchiveExtractor.ExtractBinaryArchive(const ABinaryTar, AInnerDir: string;
  const AOut: IOutput): TFPCExtractResult;
var
  LResult: fpdev.utils.process.TProcessResult;
begin
  Result.Success := False;
  Result.ErrorMsg := '';
  Result.ExtractedDir := '';

  AOut.WriteLn('  Found binary archive: ' + ExtractFileName(ABinaryTar));

  LResult := TProcessExecutor.Execute('tar', ['-xf', ABinaryTar, '-C', AInnerDir], '');
  if not LResult.Success then
  begin
    Result.ErrorMsg := 'Failed to extract binary archive';
    Exit;
  end;

  Result.Success := True;
  Result.ExtractedDir := AInnerDir;
end;

class function TFPCArchiveExtractor.ExtractBaseArchive(const ABaseTarGz, AInstallPath: string;
  const AOut: IOutput): TFPCExtractResult;
var
  LResult: fpdev.utils.process.TProcessResult;
begin
  Result.Success := False;
  Result.ErrorMsg := '';
  Result.ExtractedDir := '';

  AOut.WriteLn('  Extracting base package: ' + ExtractFileName(ABaseTarGz));

  LResult := TProcessExecutor.Execute('tar', ['-xzf', ABaseTarGz, '-C', AInstallPath], '');
  if not LResult.Success then
  begin
    Result.ErrorMsg := 'Failed to extract base archive';
    Exit;
  end;

  AOut.WriteLn('  Base package extracted successfully');
  Result.Success := True;
  Result.ExtractedDir := AInstallPath;
end;

class function TFPCArchiveExtractor.ExtractLinuxFPCTarball(const ATarFile, ATempDir, AInstallPath: string;
  const AOut, AErr: IOutput): TFPCExtractResult;
var
  ExtractDir, BinaryArchive, BaseArchive, InnerDir: string;
  ExtractResult: TFPCExtractResult;
begin
  Result.Success := False;
  Result.ErrorMsg := '';
  Result.ExtractedDir := '';

  // Step 1: Extract outer tar
  ExtractResult := ExtractOuterTar(ATarFile, ATempDir, AOut);
  if not ExtractResult.Success then
  begin
    AErr.WriteLn('Error: ' + ExtractResult.ErrorMsg);
    Result.ErrorMsg := ExtractResult.ErrorMsg;
    Exit;
  end;
  ExtractDir := ExtractResult.ExtractedDir;

  // Step 2: Find and extract binary archive
  AOut.WriteLn('  Extracting binary packages directly (skipping interactive installer)...');
  BinaryArchive := FindBinaryArchive(ExtractDir);
  if (BinaryArchive = '') or not FileExists(BinaryArchive) then
  begin
    Result.ErrorMsg := 'Could not find binary archive in extracted directory';
    AErr.WriteLn('Error: ' + Result.ErrorMsg);
    Exit;
  end;

  InnerDir := ATempDir + PathDelim + 'inner';
  ForceDirectories(InnerDir);

  ExtractResult := ExtractBinaryArchive(BinaryArchive, InnerDir, AOut);
  if not ExtractResult.Success then
  begin
    AErr.WriteLn('Error: ' + ExtractResult.ErrorMsg);
    Result.ErrorMsg := ExtractResult.ErrorMsg;
    Exit;
  end;

  // Step 3: Find and extract base archive
  BaseArchive := FindBaseArchive(InnerDir);
  if (BaseArchive = '') or not FileExists(BaseArchive) then
  begin
    Result.ErrorMsg := 'Could not find base archive in binary package';
    AErr.WriteLn('Error: ' + Result.ErrorMsg);
    Exit;
  end;

  ExtractResult := ExtractBaseArchive(BaseArchive, AInstallPath, AOut);
  if not ExtractResult.Success then
  begin
    AErr.WriteLn('Error: ' + ExtractResult.ErrorMsg);
    Result.ErrorMsg := ExtractResult.ErrorMsg;
    Exit;
  end;

  // Cleanup inner temp dir
  DeleteDirRecursive(InnerDir);

  Result.Success := True;
  Result.ExtractedDir := AInstallPath;
end;

end.
