unit fpdev.build.cache.jsonsave;

{$mode objfpc}{$H+}

interface

uses
  fpdev.build.cache.types,
  fpdev.build.cache.metajson;

function BuildCacheCreateMetaJSONArtifactInfo(
  const AInfo: TArtifactInfo): TMetaJSONArtifactInfo;

implementation

function BuildCacheCreateMetaJSONArtifactInfo(
  const AInfo: TArtifactInfo): TMetaJSONArtifactInfo;
begin
  Initialize(Result);
  Result.Version := AInfo.Version;
  Result.CPU := AInfo.CPU;
  Result.OS := AInfo.OS;
  Result.ArchivePath := AInfo.ArchivePath;
  Result.ArchiveSize := AInfo.ArchiveSize;
  Result.CreatedAt := AInfo.CreatedAt;
  Result.SourceType := AInfo.SourceType;
  Result.SHA256 := AInfo.SHA256;
  Result.DownloadURL := AInfo.DownloadURL;
  Result.SourcePath := AInfo.SourcePath;
  Result.AccessCount := AInfo.AccessCount;
  Result.LastAccessed := AInfo.LastAccessed;
end;

end.
