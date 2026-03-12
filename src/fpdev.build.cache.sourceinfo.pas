unit fpdev.build.cache.sourceinfo;

{$mode objfpc}{$H+}

interface

uses
  fpdev.build.cache.types,
  fpdev.build.cache.oldmeta;

function BuildCacheCreateSourceArtifactInfo(const AArchivePath: string;
  const AOldInfo: TOldMetaArtifactInfo): TArtifactInfo;

implementation

function BuildCacheCreateSourceArtifactInfo(const AArchivePath: string;
  const AOldInfo: TOldMetaArtifactInfo): TArtifactInfo;
begin
  Initialize(Result);
  Result.Version := AOldInfo.Version;
  Result.CPU := AOldInfo.CPU;
  Result.OS := AOldInfo.OS;
  Result.SourcePath := AOldInfo.SourcePath;
  Result.ArchiveSize := AOldInfo.ArchiveSize;
  Result.CreatedAt := AOldInfo.CreatedAt;
  Result.ArchivePath := AArchivePath;
end;

end.
