unit fpdev.toolchain.fetcher;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  SysUtils, Classes, fphttpclient, openssl, fpdev.hash, fpdev.paths, fpdev.utils.fs,
  fpdev.manifest; // HTTPS + SHA256/SHA512 + manifest integration

type
  TMirrorResult = (mrOK, mrFail);

  THashAlgorithm = (haUnknown, haSHA256, haSHA512);

  TFetchOptions = record
    DestDir: string;        // 下载目录（缓存）
    Hash: string;           // 期望的 hash（格式："sha256:..." 或 "sha512:..."）
    HashAlgorithm: THashAlgorithm;  // Hash 算法类型
    HashDigest: string;     // Hash 摘要（十六进制）
    TimeoutMS: Integer;     // 超时（毫秒）
    ExpectedSize: Int64;    // 期望的文件大小（字节，0表示不检查）
  end;

const
  { Default timeout for HTTP downloads (30 seconds) }
  DEFAULT_DOWNLOAD_TIMEOUT_MS = 30000;

// Parse hash string (format: "sha256:..." or "sha512:...") into algorithm and digest
function ParseHashString(const AHash: string; out AAlgorithm: THashAlgorithm; out ADigest: string): Boolean;

// Verify file hash using specified algorithm
function VerifyFileHash(const AFile: string; AAlgorithm: THashAlgorithm; const AExpectedDigest: string): Boolean;

// 从多个镜像依次尝试下载，成功返回 True，文件保存到 DestFile。
function FetchWithMirrors(const AURLs: array of string; const DestFile: string; const Opt: TFetchOptions; out AErr: string): boolean;

// 若 DestFile 已存在且 hash 校验通过，直接复用；否则调用 FetchWithMirrors。
function EnsureDownloadedCached(const AURLs: array of string; const DestFile: string; const Opt: TFetchOptions; out AErr: string): boolean;

// Download from manifest target (with multi-mirror fallback and hash verification)
function FetchFromManifest(const ATarget: TManifestTarget; const DestFile: string; ATimeoutMS: Integer; out AErr: string): boolean;

implementation

uses
  md5; // 提供 MD5；缺省无 sha256 单元可用时采用长度判定机制

{ Helper functions for hash parsing and verification }

function ParseHashString(const AHash: string; out AAlgorithm: THashAlgorithm; out ADigest: string): Boolean;
var
  ColonPos: Integer;
  AlgStr: string;
begin
  Result := False;
  AAlgorithm := haUnknown;
  ADigest := '';

  ColonPos := Pos(':', AHash);
  if ColonPos <= 0 then
    Exit;

  AlgStr := LowerCase(Copy(AHash, 1, ColonPos - 1));
  ADigest := Copy(AHash, ColonPos + 1, Length(AHash));

  if AlgStr = 'sha256' then
    AAlgorithm := haSHA256
  else if AlgStr = 'sha512' then
    AAlgorithm := haSHA512
  else
    Exit;

  // Validate digest is not empty
  if Length(ADigest) = 0 then
    Exit;

  Result := True;
end;

function VerifyFileHash(const AFile: string; AAlgorithm: THashAlgorithm; const AExpectedDigest: string): Boolean;
var
  ActualHash: string;
begin
  Result := False;

  if not FileExists(AFile) then
    Exit;

  case AAlgorithm of
    haSHA256:
      ActualHash := LowerCase(SHA256FileHex(AFile));
    haSHA512:
      ActualHash := LowerCase(SHA512FileHex(AFile));
    else
      Exit;
  end;

  Result := (ActualHash = LowerCase(AExpectedDigest));
end;

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
  FileSize: Int64;
  F: TFileStream;
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
      Cli.AllowRedirect := True;  // Enable HTTP redirect following
      if Opt.TimeoutMS>0 then
      begin
        Cli.ConnectTimeout := Opt.TimeoutMS;
        Cli.IOTimeout := Opt.TimeoutMS;
      end;
      try
        Cli.Get(URL, Tmp);

        // Verify file size if expected size is provided
        if Opt.ExpectedSize > 0 then
        begin
          F := TFileStream.Create(Tmp, fmOpenRead);
          try
            FileSize := F.Size;
          finally
            F.Free;
          end;

          if FileSize <> Opt.ExpectedSize then
          begin
            AErr := Format('Size mismatch for %s: expected %d bytes, got %d bytes', [URL, Opt.ExpectedSize, FileSize]);
            DeleteFile(Tmp);
            Continue;
          end;
        end;

        // Verify hash if provided
        if (Opt.HashAlgorithm <> haUnknown) and (Opt.HashDigest <> '') then
        begin
          if not VerifyFileHash(Tmp, Opt.HashAlgorithm, Opt.HashDigest) then
          begin
            case Opt.HashAlgorithm of
              haSHA256: AErr := 'SHA256 hash mismatch for ' + URL;
              haSHA512: AErr := 'SHA512 hash mismatch for ' + URL;
              haUnknown: AErr := 'Hash mismatch for ' + URL;
            end;
            DeleteFile(Tmp);
            Continue;
          end;
        end;

        // Atomic replacement
        if FileExists(DestFile) then DeleteFile(DestFile);
        if not RenameFile(Tmp, DestFile) then
        begin
          // Fallback to copy
          if not CopyFileSimple(Tmp, DestFile) then
          begin
            AErr := 'Cannot move downloaded file to destination';
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
          // Try next mirror
        end;
      end;
    finally
      Cli.Free;
    end;
  end;
end;

function EnsureDownloadedCached(const AURLs: array of string; const DestFile: string; const Opt: TFetchOptions; out AErr: string): boolean;
begin
  AErr := '';
  // Ensure data root is initialized
  GetDataRoot;

  // Check if file exists and verify hash if provided
  if (DestFile <> '') and FileExists(DestFile) then
  begin
    if (Opt.HashAlgorithm <> haUnknown) and (Opt.HashDigest <> '') then
    begin
      if VerifyFileHash(DestFile, Opt.HashAlgorithm, Opt.HashDigest) then
        Exit(True);
      // Hash verification failed: delete and re-download
      DeleteFile(DestFile);
    end;
  end;

  Result := FetchWithMirrors(AURLs, DestFile, Opt, AErr);
end;

function FetchFromManifest(const ATarget: TManifestTarget; const DestFile: string; ATimeoutMS: Integer; out AErr: string): boolean;
var
  Opt: TFetchOptions;
  URLs: array of string;
  I: Integer;
  Algorithm: string;
  Digest: string;
begin
  Result := False;
  AErr := '';

  // Validate target has URLs
  if Length(ATarget.URLs) = 0 then
  begin
    AErr := 'No URLs provided in manifest target';
    Exit;
  end;

  // Copy URLs to dynamic array
  SetLength(URLs, Length(ATarget.URLs));
  for I := 0 to High(ATarget.URLs) do
    URLs[I] := ATarget.URLs[I];

  // Parse hash from manifest
  if not ParseHashString(ATarget.Hash, Opt.HashAlgorithm, Opt.HashDigest) then
  begin
    AErr := 'Invalid hash format in manifest: ' + ATarget.Hash;
    Exit;
  end;

  // Set up fetch options
  Opt.DestDir := ExtractFileDir(DestFile);
  Opt.Hash := ATarget.Hash;
  Opt.TimeoutMS := ATimeoutMS;
  Opt.ExpectedSize := ATarget.Size;

  // Download with multi-mirror fallback and verification
  Result := EnsureDownloadedCached(URLs, DestFile, Opt, AErr);
end;

end.

