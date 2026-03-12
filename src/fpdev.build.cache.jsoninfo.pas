unit fpdev.build.cache.jsoninfo;

{$mode objfpc}{$H+}

interface

uses
  fpdev.build.cache.types,
  fpdev.build.cache.metajson;

function BuildCacheCreateJSONArtifactInfo(
  const AHelperInfo: TMetaJSONArtifactInfo): TArtifactInfo;

implementation

function BuildCacheCreateJSONArtifactInfo(
  const AHelperInfo: TMetaJSONArtifactInfo): TArtifactInfo;
begin
  Initialize(Result);
  Result.Version := AHelperInfo.Version;
  Result.CPU := AHelperInfo.CPU;
  Result.OS := AHelperInfo.OS;
  Result.ArchivePath := AHelperInfo.ArchivePath;
  Result.ArchiveSize := AHelperInfo.ArchiveSize;
  Result.CreatedAt := AHelperInfo.CreatedAt;
  Result.SourceType := AHelperInfo.SourceType;
  Result.SHA256 := AHelperInfo.SHA256;
  Result.DownloadURL := AHelperInfo.DownloadURL;
  Result.SourcePath := AHelperInfo.SourcePath;
  Result.AccessCount := AHelperInfo.AccessCount;
  Result.LastAccessed := AHelperInfo.LastAccessed;
end;

end.
