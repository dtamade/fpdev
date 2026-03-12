unit fpdev.build.cache.cleanupinfo;

{$mode objfpc}{$H+}

interface

uses
  fpdev.build.cache.types;

type
  TBuildCacheCleanupInfoLoader = function(const AVersion: string; out AInfo: TArtifactInfo): Boolean of object;

function BuildCacheLoadCleanupArtifactInfo(const AVersion: string;
  ASourceLoader, ABinaryLoader: TBuildCacheCleanupInfoLoader;
  out AInfo: TArtifactInfo): Boolean;

implementation

function BuildCacheLoadCleanupArtifactInfo(const AVersion: string;
  ASourceLoader, ABinaryLoader: TBuildCacheCleanupInfoLoader;
  out AInfo: TArtifactInfo): Boolean;
begin
  if Assigned(ASourceLoader) and ASourceLoader(AVersion, AInfo) then
    Exit(True);
  if Assigned(ABinaryLoader) and ABinaryLoader(AVersion, AInfo) then
    Exit(True);
  Initialize(AInfo);
  Result := False;
end;

end.
