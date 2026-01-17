unit fpdev.source;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpdev.toolchain.extract, fpdev.hash, fpdev.paths, fpdev.utils.fs, fpdev.utils;

function EnsureSourceLocalDir(const AName, AVersion, ALocalPath: string; AStrict: Boolean; out ADestPath, AErr: string): boolean;
function EnsureSourceLocalZip(const AName, AVersion, AZipPath, ASha256: string; out ADestPath, AErr: string): boolean;
function WriteLockfile(const AName, AVersion, ASource, ADest: string; const ASha256: string): boolean;
function ImportBundle(const ABundlePathOrDir: string; out AErr: string): boolean;

implementation

procedure CollectZipFiles(const ADir: string; AList: TStrings);
var
  LSR: TSearchRec;
  LPath: string;
begin
  if not DirectoryExists(ADir) then Exit;
  if FindFirst(IncludeTrailingPathDelimiter(ADir) + '*', faAnyFile, LSR) = 0 then
  begin
    repeat
      if (LSR.Name='.') or (LSR.Name='..') then Continue;
      LPath := IncludeTrailingPathDelimiter(ADir) + LSR.Name;
      if (LSR.Attr and faDirectory) <> 0 then
        CollectZipFiles(LPath, AList)
      else if LowerCase(ExtractFileExt(LPath)) = '.zip' then
        AList.Add(LPath);
    until FindNext(LSR) <> 0;
    FindClose(LSR);
  end;
end;

function FindAllZipFiles(const ABaseDir: string): TStringList;
begin
  Result := TStringList.Create;
  if DirectoryExists(ABaseDir) then
    CollectZipFiles(ABaseDir, Result);
end;

function DirExistsAll(const ABase: string; const Subdirs: array of string): boolean;
var i: Integer;
begin
  Result := True;
  for i := Low(Subdirs) to High(Subdirs) do
  begin
    if not DirectoryExists(IncludeTrailingPathDelimiter(ABase) + Subdirs[i]) then
      Exit(False);
  end;
end;

function BasicSourceCheck(const AName, APath: string; AStrict: Boolean; out AErr: string): boolean;
begin
  AErr := '';
  if not DirectoryExists(APath) then
  begin AErr := 'source dir not found'; Exit(False); end;
  if AName = 'fpc-src' then
  begin
    if not DirExistsAll(APath, ['compiler','rtl','packages']) then
    begin AErr := 'fpc-src structure invalid (need compiler/rtl/packages)'; Exit(False); end;
  end
  else if AName = 'lazarus-src' then
  begin
    if not DirExistsAll(APath, ['ide','lcl','packager']) then
    begin AErr := 'lazarus-src structure invalid (need ide/lcl/packager)'; if AStrict then Exit(False); end;
  end;
  Result := True;
end;

function EnsureSourceLocalDir(const AName, AVersion, ALocalPath: string; AStrict: Boolean; out ADestPath, AErr: string): boolean;
var
  Dest: string;
begin
  AErr := '';
  Result := False;
  if (ALocalPath='') then begin AErr := 'local path is empty'; Exit(False); end;
  if not BasicSourceCheck(AName, ALocalPath, AStrict, AErr) then Exit(False);
  // 标准沙箱路径
  Dest := IncludeTrailingPathDelimiter(GetSandboxDir)+'sources' + PathDelim + AName + PathDelim + AVersion;
  EnsureDir(Dest);
  // 将本地目录复制到标准沙箱，避免直接引用外部路径（更可控）
  // DeleteDirRecursive already handles errors gracefully
  if DirectoryExists(Dest) then
    DeleteDirRecursive(Dest);
  if not CopyDirRecursive(ALocalPath, Dest) then
  begin AErr := 'copy local dir to sandbox failed'; Exit(False); end;
  ADestPath := Dest;
  // 写入锁文件（来源为本地目录，sha256 为空）
  WriteLockfile(AName, AVersion, ALocalPath, ADestPath, '');
  Result := True;
end;

function EnsureSourceLocalZip(const AName, AVersion, AZipPath, ASha256: string; out ADestPath, AErr: string): boolean;
var
  Dest, TmpErr, Hex: string;
begin
  AErr := '';
  Result := False;
  if (AZipPath='') or (not FileExists(AZipPath)) then begin AErr := 'zip file not found'; Exit(False); end;
  if (ASha256='') or (Length(ASha256)<>64) then begin AErr := 'need sha256 (64-hex) for zip'; Exit(False); end;
  Hex := SHA256FileHex(AZipPath);
  if LowerCase(Hex) <> LowerCase(ASha256) then begin AErr := 'sha256 mismatch'; Exit(False); end;
  Dest := IncludeTrailingPathDelimiter(GetSandboxDir)+'sources' + PathDelim + AName + PathDelim + AVersion;
  EnsureDir(Dest);
  if not ZipExtract(AZipPath, Dest, TmpErr) then begin AErr := 'extract failed: ' + TmpErr; Exit(False); end;
  if not BasicSourceCheck(AName, Dest, True{严格结构校验}, TmpErr) then
  begin AErr := 'structure check failed: ' + TmpErr; Exit(False); end;
  ADestPath := Dest;
  // 写入锁文件（来源为 zip）
  WriteLockfile(AName, AVersion, AZipPath, ADestPath, ASha256);
  Result := True;
end;

function WriteLockfile(const AName, AVersion, ASource, ADest: string; const ASha256: string): boolean;
var
  SL: TStringList;
  F: string;
begin
  Result := False;
  EnsureDir(GetLocksDir);
  SL := TStringList.Create;
  try
    SL.Add('{');
    SL.Add('  "name": "'+JsonEscape(AName)+'",');
    SL.Add('  "version": "'+JsonEscape(AVersion)+'",');
    SL.Add('  "source": "'+JsonEscape(ASource)+'",');
    SL.Add('  "dest": "'+JsonEscape(ADest)+'",');
    SL.Add('  "sha256": "'+JsonEscape(ASha256)+'",');
    SL.Add('  "time": "'+FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now)+'"');
    SL.Add('}');
    F := IncludeTrailingPathDelimiter(GetLocksDir) + 'ensure-source-'+AName+'-'+AVersion+'.json';
    SL.SaveToFile(F);
    Result := True;
  finally
    SL.Free;
  end;
end;

function ImportBundle(const ABundlePathOrDir: string; out AErr: string): boolean;
var
  BaseDir: string;
  SL: TStringList;
  Files: TStringList;
  i: Integer;
  F, ShaFile, Sha: string;
  Dest: string;
  LTmpDir, LTmpErr: string;
  LIsTemp: Boolean;
begin
  AErr := '';
  Result := False;
  if ABundlePathOrDir='' then begin AErr := 'bundle path is empty'; Exit(False); end;
  BaseDir := ABundlePathOrDir;
  LIsTemp := False;
  if DirectoryExists(BaseDir) then
  begin
    // ok
  end
  else if FileExists(BaseDir) then
  begin
    // 如果是 zip 文件，直接解压到临时目录再处理
    if LowerCase(ExtractFileExt(BaseDir)) = '.zip' then
    begin
      LTmpDir := IncludeTrailingPathDelimiter(GetSandboxDir) + 'tmp' + PathDelim + 'bundle-unzip-' + FormatDateTime('yyyymmddhhnnss', Now);
      EnsureDir(LTmpDir);
      if not ZipExtract(BaseDir, LTmpDir, LTmpErr) then
      begin
        AErr := 'bundle unzip failed: ' + LTmpErr;
        Exit(False);
      end;
      BaseDir := LTmpDir;
      LIsTemp := True;
    end
    else
    begin
      AErr := 'bundle file is not a zip: ' + BaseDir;
      Exit(False);
    end;
  end
  else begin AErr := 'bundle not found'; Exit(False); end;

  Files := FindAllZipFiles(BaseDir);
  try
    for i := 0 to Files.Count-1 do
    begin
      F := Files[i];
      ShaFile := ChangeFileExt(F, '.sha256');
      if not FileExists(ShaFile) then Continue;
      SL := TStringList.Create;
      try
        SL.LoadFromFile(ShaFile);
        if SL.Count>0 then Sha := Trim(SL[0]) else Sha := '';
      finally
        SL.Free;
      end;
      if (Sha='') or (Length(Sha)<>64) then Continue;
      // 校验并导入缓存
      if LowerCase(SHA256FileHex(F)) <> LowerCase(Sha) then Continue;
      Dest := IncludeTrailingPathDelimiter(GetCacheDir)+'toolchain'+PathDelim+ExtractFileName(F);
      EnsureDir(ExtractFileDir(Dest));
      if FileExists(Dest) then DeleteFile(Dest);
      if not CopyFileSafe(F, Dest) then begin AErr := 'copy to cache failed: ' + Dest; Exit(False); end;
    end;
  finally
    Files.Free;
  end;
  // 清理临时目录（如果有）
  if LIsTemp and DirectoryExists(BaseDir) then
  begin
    try
      DeleteDirRecursive(BaseDir);
    except
      // ignore cleanup errors
    end;
  end;
  Result := True;
end;

end.

