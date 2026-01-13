unit fpdev.toolchain.fetcher;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fphttpclient, openssl, fpdev.hash, fpdev.paths, fpdev.utils.fs; // HTTPS + SHA256 + paths

type
  TMirrorResult = (mrOK, mrFail);

  TFetchOptions = record
    DestDir: string;     // 下载目录（缓存）
    SHA256: string;      // 期望的 sha256（可空）
    TimeoutMS: Integer;  // 超时（毫秒）
  end;

const
  { Default timeout for HTTP downloads (30 seconds) }
  DEFAULT_DOWNLOAD_TIMEOUT_MS = 30000;

// 从多个镜像依次尝试下载，成功返回 True，文件保存到 DestFile。
function FetchWithMirrors(const AURLs: array of string; const DestFile: string; const Opt: TFetchOptions; out AErr: string): boolean;
// 若 DestFile 已存在且 SHA256 校验通过，直接复用；否则调用 FetchWithMirrors。
function EnsureDownloadedCached(const AURLs: array of string; const DestFile, ASha256: string; ATimeoutMS: Integer; out AErr: string): boolean;

implementation

uses
  md5; // 提供 MD5；缺省无 sha256 单元可用时采用长度判定机制

function CalcFileMD5(const AFile: string): string;
var
  Ctx: TMD5Context;
  Dig: TMD5Digest;
  S: string;
  F: TFileStream;
  Buf: array of byte;
  R: Integer;
begin
  Result := '';
  if (AFile='') or (not FileExists(AFile)) then Exit;
  Buf := nil;
  SetLength(Buf, 8192);
  MD5Init(Ctx);
  F := TFileStream.Create(AFile, fmOpenRead or fmShareDenyWrite);
  try
    repeat
      R := F.Read(Buf[0], Length(Buf));
      if R > 0 then MD5Update(Ctx, Buf[0], R);
    until R = 0;
  finally
    F.Free;
  end;
  MD5Final(Ctx, Dig);
  S := MD5Print(Dig);
  Result := LowerCase(S);
end;


function CopyFileSimple(const ASrc, ADest: string): boolean;
var
  LIn, LOut: TFileStream;
begin
  Result := False;
  if (ASrc='') or (ADest='') then Exit(False);
  try
    EnsureDir(ExtractFileDir(ADest));
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

function FetchWithMirrors(const AURLs: array of string; const DestFile: string; const Opt: TFetchOptions; out AErr: string): boolean;
var
  i: Integer;
  URL: string;
  Cli: TFPHTTPClient;
  Tmp: string;
begin
  Result := False;
  AErr := '';
  if Length(AURLs)=0 then Exit(False);
  EnsureDir(ExtractFileDir(DestFile));
  Tmp := DestFile + '.part';

  for i := Low(AURLs) to High(AURLs) do
  begin
    URL := AURLs[i];
    Cli := TFPHTTPClient.Create(nil);
    try
      if Opt.TimeoutMS>0 then
      begin
        Cli.ConnectTimeout := Opt.TimeoutMS;
        Cli.IOTimeout := Opt.TimeoutMS;
      end;
      try
        Cli.Get(URL, Tmp);
        // 校验（若要求）：64位 hex = sha256
        if Opt.SHA256<>'' then
        begin
          if (Length(Opt.SHA256)=64) then
          begin
            if LowerCase(SHA256FileHex(Tmp)) <> LowerCase(Opt.SHA256) then
            begin
              AErr := 'sha256 mismatch for '+URL;
              DeleteFile(Tmp);
              Continue;
            end;
          end
          else
          begin
            // 非 64位 hex（例如 md5）一律不接受为强校验，保守失败
            AErr := 'unsupported checksum format (expect sha256 hex)';
            DeleteFile(Tmp);
            Continue;
          end;
        end;
        // 原子替换
        if FileExists(DestFile) then DeleteFile(DestFile);
        if not RenameFile(Tmp, DestFile) then
        begin
          // 回退到复制
          if not CopyFileSimple(Tmp, DestFile) then
          begin
            AErr := 'cannot move downloaded file to dest';
            DeleteFile(Tmp);
            Continue;
          end;
          DeleteFile(Tmp);
        end;
        Exit(True);
      except on E: Exception do
        begin
          AErr := E.Message;
          if FileExists(Tmp) then DeleteFile(Tmp);
          // 尝试下一个镜像
        end;
      end;
    finally
      Cli.Free;
    end;
  end;
end;

function EnsureDownloadedCached(const AURLs: array of string; const DestFile, ASha256: string; ATimeoutMS: Integer; out AErr: string): boolean;
var
  Opt: TFetchOptions;
begin
  AErr := '';
  // Ensure data root is initialized
  GetDataRoot;
  if (DestFile<>'') and FileExists(DestFile) then
  begin
    if (ASha256<>'') and (Length(ASha256)=64) then
    begin
      if LowerCase(SHA256FileHex(DestFile)) = LowerCase(ASha256) then Exit(True);
      // 校验失败：删除并重新下载
      DeleteFile(DestFile);
    end;
  end;
  Opt.DestDir := ExtractFileDir(DestFile);
  Opt.SHA256 := ASha256;
  Opt.TimeoutMS := ATimeoutMS;
  Result := FetchWithMirrors(AURLs, DestFile, Opt, AErr);
end;

end.

