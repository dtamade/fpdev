unit fpdev.build.cache.jsonpath;

{$mode objfpc}{$H+}

interface

function BuildCacheGetJSONMetaPath(const ACacheDirWithDelim,
  AArtifactKey: string): string;

implementation

function BuildCacheGetJSONMetaPath(const ACacheDirWithDelim,
  AArtifactKey: string): string;
begin
  Result := ACacheDirWithDelim + AArtifactKey + '.json';
end;

end.
