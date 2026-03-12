unit fpdev.build.cache.binaryinfo;

{$mode objfpc}{$H+}

interface

uses
  fpdev.build.cache.types,
  fpdev.build.cache.oldmeta;

function BuildCacheGetBinaryMetaPath(const ACacheDirWithDelim,
  AArtifactKey: string): string;
function BuildCacheCreateBinaryArtifactInfo(const ACacheDirWithDelim,
  AArtifactKey: string; const ABinaryInfo: TBinaryMetaArtifactInfo): TArtifactInfo;

implementation

function BuildCacheGetBinaryMetaPath(const ACacheDirWithDelim,
  AArtifactKey: string): string;
begin
  Result := ACacheDirWithDelim + AArtifactKey + '-binary.meta';
end;

function BuildCacheCreateBinaryArtifactInfo(const ACacheDirWithDelim,
  AArtifactKey: string; const ABinaryInfo: TBinaryMetaArtifactInfo): TArtifactInfo;
begin
  Initialize(Result);
  Result.Version := ABinaryInfo.Version;
  Result.CPU := ABinaryInfo.CPU;
  Result.OS := ABinaryInfo.OS;
  Result.SourceType := ABinaryInfo.SourceType;
  Result.SHA256 := ABinaryInfo.SHA256;
  Result.FileExt := ABinaryInfo.FileExt;
  Result.ArchiveSize := ABinaryInfo.ArchiveSize;
  Result.CreatedAt := ABinaryInfo.CreatedAt;
  Result.ArchivePath := ACacheDirWithDelim +
    AArtifactKey + '-binary' + ABinaryInfo.FileExt;
end;

end.
