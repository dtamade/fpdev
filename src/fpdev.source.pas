unit fpdev.source;
{$CODEPAGE UTF8}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpdev.toolchain.extract, fpdev.hash, fpdev.paths;

function EnsureSourceLocalDir(const AName, AVersion, ALocalPath: string; AStrict: Boolean; out ADestPath, AErr: string): boolean;
function EnsureSourceLocalZip(const AName, AVersion, AZipPath, ASha256: string; out ADestPath, AErr: string): boolean;
function WriteLockfile(const AName, AVersion, ASource, ADest: string; const ASha256: string): boolean;
function ImportBundle(const ABundlePathOrDir: string; out AErr: string): boolean;

implementation

function CopyFileSimple(const ASrc, ADest: string): boolean;
var
  LIn, LOut: TFileStream;
begin
  Result := False;
  if (ASrc='') or (ADest='') then Exit(False);
  try
    ForceDirectories(ExtractFileDir(ADest));
    LIn := TFileStream.Create(ASrc, fmOpenRead or fmShareDenyNone);
    try
      LOut := TFileStream.Create(ADest, fmCreate);
      try
        LOut.CopyFrom(LIn, 0);
        Result := True;
      finally
        LOut.Free;
      end;
    finally
      LIn.Free;
    end;
  except
    Result := False;
  end;
end;

function DeleteDirTree(const ADir: string): boolean;
var
  LSR: TSearchRec;
  LPath: string;
begin
  Result := True;
  if not DirectoryExists(ADir) then Exit(True);
  if FindFirst(IncludeTrailingPathDelimiter(ADir) + '*', faAnyFile, LSR) = 0 then
  begin
    repeat
      if (LSR.Name='.') or (LSR.Name='..') then Continue;
      LPath := IncludeTrailingPathDelimiter(ADir) + LSR.Name;
      if (LSR.Attr and faDirectory) <> 0 then
      begin
        if not DeleteDirTree(LPath) then Result := False;
      end
      else
      begin
        if FileExists(LPath) then
          if not DeleteFile(LPath) then Result := False;
      end;
    until FindNext(LSR) <> 0;
    FindClose(LSR);
  end;
  if not RemoveDir(ADir) then Result := False;
end;

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

function CopyDirTreeSimple(const ASrc, ADest: string): boolean;
var
  LSR: TSearchRec;
  LSrcPath, LDestPath: string;
begin
  Result := True;
  if not DirectoryExists(ASrc) then Exit(False);
  ForceDirectories(ADest);
  if FindFirst(IncludeTrailingPathDelimiter(ASrc) + '*', faAnyFile, LSR) = 0 then
  begin
    repeat
      if (LSR.Name='.') or (LSR.Name='..') then Continue;
      LSrcPath := IncludeTrailingPathDelimiter(ASrc) + LSR.Name;
      LDestPath := IncludeTrailingPathDelimiter(ADest) + LSR.Name;
      if (LSR.Attr and faDirectory) <> 0 then
      begin
        if not CopyDirTreeSimple(LSrcPath, LDestPath) then Result := False;
      end
      else
      begin
        if not CopyFileSimple(LSrcPath, LDestPath) then Result := False;
      end;
    until FindNext(LSR) <> 0;
    FindClose(LSR);
  end;
end;

function JsonEscape(const S: string): string;
var
  i: Integer;
  ch: Char;
  LRes: string;
begin
  LRes := '';
  for i := 1 to Length(S) do
  begin
    ch := S[i];
    case ch of
      '"': LRes := LRes + '\"';
      #92:  LRes := LRes + '\\';
      #8: LRes := LRes + '\b';
      #9: LRes := LRes + '\t';
      #10: LRes := LRes + '\n';
      #12: LRes := LRes + '\f';
      #13: LRes := LRes + '\r';
    else
      if Ord(ch) < 32 then
        LRes := LRes + '\u' + IntToHex(Ord(ch), 4)
      else
        LRes := LRes + ch;
    end;
  end;
  Result := LRes;
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
  ForceDirectories(Dest);
  // 将本地目录复制到标准沙箱，避免直接引用外部路径（更可控）
  try
    if DirectoryExists(Dest) then DeleteDirTree(Dest);
  except end;
  if not CopyDirTreeSimple(ALocalPath, Dest) then
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
  ForceDirectories(Dest);
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
  ForceDirectories(GetLocksDir);
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
      ForceDirectories(LTmpDir);
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
      ForceDirectories(ExtractFileDir(Dest));
      if FileExists(Dest) then DeleteFile(Dest);
      if not CopyFileSimple(F, Dest) then begin AErr := 'copy to cache failed: ' + Dest; Exit(False); end;
    end;
  finally
    Files.Free;
  end;
  // 清理临时目录（如果有）
  if LIsTemp and DirectoryExists(BaseDir) then
  begin
    try
      DeleteDirTree(BaseDir);
    except
      // ignore cleanup errors
    end;
  end;
  Result := True;
end;

end.

