unit fpdev.build.cache.binarysave;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  TBuildCacheBinaryArtifactPaths = record
    ArchivePath: string;
    MetaPath: string;
  end;

function BuildCacheResolveBinaryFileExt(const ADownloadedFile: string): string;
function BuildCacheBuildBinaryArtifactPaths(const ACacheDirWithDelim, AArtifactKey,
  AFileExt: string): TBuildCacheBinaryArtifactPaths;
function BuildCacheReadBinaryArchiveSize(const AArchivePath: string): Int64;
function BuildCacheResolveBinarySHA256(const AProvidedSHA256, AArchivePath: string): string;

implementation

uses
  fpdev.build.cache.verify;

function BuildCacheResolveBinaryFileExt(const ADownloadedFile: string): string;
begin
  Result := ExtractFileExt(ADownloadedFile);
  if (Result = '.gz') and
     (LowerCase(ExtractFileExt(ChangeFileExt(ADownloadedFile, ''))) = '.tar') then
    Result := '.tar.gz';
end;

function BuildCacheBuildBinaryArtifactPaths(const ACacheDirWithDelim, AArtifactKey,
  AFileExt: string): TBuildCacheBinaryArtifactPaths;
begin
  Result.ArchivePath := ACacheDirWithDelim + AArtifactKey + '-binary' + AFileExt;
  Result.MetaPath := ACacheDirWithDelim + AArtifactKey + '-binary.meta';
end;

function BuildCacheReadBinaryArchiveSize(const AArchivePath: string): Int64;
var
  SR: TSearchRec;
begin
  Result := 0;
  if FindFirst(AArchivePath, faAnyFile, SR) = 0 then
  begin
    try
      Result := SR.Size;
    finally
      FindClose(SR);
    end;
  end;
end;

function BuildCacheResolveBinarySHA256(const AProvidedSHA256, AArchivePath: string): string;
begin
  if AProvidedSHA256 <> '' then
    Result := AProvidedSHA256
  else
    Result := BuildCacheCalculateSHA256(AArchivePath);
end;

end.
