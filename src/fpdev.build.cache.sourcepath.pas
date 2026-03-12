unit fpdev.build.cache.sourcepath;

{$mode objfpc}{$H+}

interface

function BuildCacheGetSourceArchivePath(const ACacheDirWithDelim,
  AArtifactKey: string): string;
function BuildCacheGetSourceMetaPath(const ACacheDirWithDelim,
  AArtifactKey: string): string;

implementation

function BuildCacheGetSourceArchivePath(const ACacheDirWithDelim,
  AArtifactKey: string): string;
begin
  Result := ACacheDirWithDelim + AArtifactKey + '.tar.gz';
end;

function BuildCacheGetSourceMetaPath(const ACacheDirWithDelim,
  AArtifactKey: string): string;
begin
  Result := ACacheDirWithDelim + AArtifactKey + '.meta';
end;

end.
