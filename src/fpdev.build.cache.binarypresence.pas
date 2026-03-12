unit fpdev.build.cache.binarypresence;

{$mode objfpc}{$H+}

interface

function BuildCacheHasArtifactFiles(const ASourceArchivePath,
  ABinaryMetaPath: string): Boolean;

implementation

uses
  SysUtils;

function BuildCacheHasArtifactFiles(const ASourceArchivePath,
  ABinaryMetaPath: string): Boolean;
begin
  Result := FileExists(ASourceArchivePath) or FileExists(ABinaryMetaPath);
end;

end.
