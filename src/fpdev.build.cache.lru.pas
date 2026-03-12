unit fpdev.build.cache.lru;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  fpdev.build.cache.types;

function BuildCacheSelectLeastRecentlyUsed(const AInfos: array of TArtifactInfo): string;

implementation

function BuildCacheSelectLeastRecentlyUsed(const AInfos: array of TArtifactInfo): string;
var
  Index: Integer;
  OldestTime: TDateTime;
  LRUVersion: string;
  HasNeverAccessed: Boolean;
begin
  Result := '';
  OldestTime := MaxDateTime;
  LRUVersion := '';
  HasNeverAccessed := False;

  for Index := Low(AInfos) to High(AInfos) do
  begin
    if AInfos[Index].LastAccessed = 0 then
    begin
      if (not HasNeverAccessed) or (AInfos[Index].CreatedAt < OldestTime) then
      begin
        OldestTime := AInfos[Index].CreatedAt;
        LRUVersion := AInfos[Index].Version;
        HasNeverAccessed := True;
      end;
    end;
  end;

  if HasNeverAccessed then
    Exit(LRUVersion);

  OldestTime := MaxDateTime;
  for Index := Low(AInfos) to High(AInfos) do
  begin
    if AInfos[Index].LastAccessed < OldestTime then
    begin
      OldestTime := AInfos[Index].LastAccessed;
      LRUVersion := AInfos[Index].Version;
    end;
  end;

  Result := LRUVersion;
end;

end.
