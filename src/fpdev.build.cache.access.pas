unit fpdev.build.cache.access;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.build.cache.types;

function BuildCacheRecordAccessInfo(const AInfo: TArtifactInfo;
  AAccessedAt: TDateTime): TArtifactInfo;

implementation

function BuildCacheRecordAccessInfo(const AInfo: TArtifactInfo;
  AAccessedAt: TDateTime): TArtifactInfo;
begin
  Result := AInfo;
  Inc(Result.AccessCount);
  Result.LastAccessed := AAccessedAt;
end;

end.
