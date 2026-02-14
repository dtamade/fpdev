unit fpdev.cross.cache;
{$CODEPAGE UTF8}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpdev.hash;

type
  { TCacheMode - Cache operation mode }
  TCacheMode = (
    cmUse,      // Use cache if valid, download if not
    cmRefresh,  // Re-download even if cache exists
    cmOnly      // Only use cache, fail if not available
  );

  { TCrossToolchainCache - Manages cached toolchain archives }
  TCrossToolchainCache = class
  private
    FCacheDir: string;

    function GetCachePath(const ATarget, AComponentType: string): string;
    function EnsureCacheDir: Boolean;

  public
    constructor Create(const ACacheDir: string);
    destructor Destroy; override;

    { Check if a valid cached archive exists with matching SHA256 }
    function HasValidCache(const ATarget, AComponentType, ASHA256: string): Boolean;

    { Get the path to a cached archive (empty if not exists) }
    function GetCachedArchive(const ATarget, AComponentType: string): string;

    { Store an archive in the cache }
    function StoreArchive(const ASourcePath, ATarget, AComponentType: string): Boolean;

    { Invalidate (delete) a cached archive }
    procedure InvalidateCache(const ATarget, AComponentType: string);

    { Get the SHA256 of a cached archive (empty if not exists) }
    function GetCachedSHA256(const ATarget, AComponentType: string): string;

    { Get cache directory }
    property CacheDir: string read FCacheDir;
  end;

implementation

{ TCrossToolchainCache }

constructor TCrossToolchainCache.Create(const ACacheDir: string);
begin
  inherited Create;
  FCacheDir := ACacheDir;
end;

destructor TCrossToolchainCache.Destroy;
begin
  inherited Destroy;
end;

function TCrossToolchainCache.GetCachePath(const ATarget, AComponentType: string): string;
begin
  // Format: <cache_dir>/<target>-<componentType>.archive
  Result := IncludeTrailingPathDelimiter(FCacheDir) +
            LowerCase(ATarget) + '-' + LowerCase(AComponentType) + '.archive';
end;

function TCrossToolchainCache.EnsureCacheDir: Boolean;
begin
  Result := True;
  if not DirectoryExists(FCacheDir) then
  begin
    try
      ForceDirectories(FCacheDir);
      Result := DirectoryExists(FCacheDir);
    except
      Result := False;
    end;
  end;
end;

function TCrossToolchainCache.HasValidCache(const ATarget, AComponentType, ASHA256: string): Boolean;
var
  CachePath, CachedHash: string;
begin
  Result := False;

  // Validate input checksum length
  if Length(ASHA256) <> 64 then
    Exit;

  CachePath := GetCachePath(ATarget, AComponentType);
  if not FileExists(CachePath) then
    Exit;

  // Verify SHA256 checksum
  CachedHash := SHA256FileHex(CachePath);
  if Length(CachedHash) <> 64 then
    Exit;

  Result := SameText(CachedHash, ASHA256);
end;

function TCrossToolchainCache.GetCachedArchive(const ATarget, AComponentType: string): string;
var
  CachePath: string;
begin
  CachePath := GetCachePath(ATarget, AComponentType);
  if FileExists(CachePath) then
    Result := CachePath
  else
    Result := '';
end;

function TCrossToolchainCache.StoreArchive(const ASourcePath, ATarget, AComponentType: string): Boolean;
var
  CachePath: string;
  SrcStream, DstStream: TFileStream;
begin
  Result := False;

  if not FileExists(ASourcePath) then
    Exit;

  if not EnsureCacheDir then
    Exit;

  CachePath := GetCachePath(ATarget, AComponentType);

  try
    // Copy file to cache
    SrcStream := TFileStream.Create(ASourcePath, fmOpenRead or fmShareDenyWrite);
    try
      DstStream := TFileStream.Create(CachePath, fmCreate);
      try
        DstStream.CopyFrom(SrcStream, 0);
        Result := True;
      finally
        DstStream.Free;
      end;
    finally
      SrcStream.Free;
    end;
  except
    // Delete partial file on error
    if FileExists(CachePath) then
      DeleteFile(CachePath);
    Result := False;
  end;
end;

procedure TCrossToolchainCache.InvalidateCache(const ATarget, AComponentType: string);
var
  CachePath: string;
begin
  CachePath := GetCachePath(ATarget, AComponentType);
  if FileExists(CachePath) then
    DeleteFile(CachePath);
end;

function TCrossToolchainCache.GetCachedSHA256(const ATarget, AComponentType: string): string;
var
  CachePath: string;
begin
  CachePath := GetCachePath(ATarget, AComponentType);
  if FileExists(CachePath) then
    Result := SHA256FileHex(CachePath)
  else
    Result := '';
end;

end.
