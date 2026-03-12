unit fpdev.build.cache.deletefiles;

{$mode objfpc}{$H+}

interface

function BuildCacheDeleteArtifactFiles(const AArchivePath,
  AMetaPath: string): Boolean;

implementation

uses
  SysUtils;

function BuildCacheDeleteArtifactFiles(const AArchivePath,
  AMetaPath: string): Boolean;
begin
  Result := True;

  if FileExists(AArchivePath) then
    Result := DeleteFile(AArchivePath);

  if FileExists(AMetaPath) then
    Result := Result and DeleteFile(AMetaPath);
end;

end.
