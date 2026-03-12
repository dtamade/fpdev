unit fpdev.build.cache.entryquery;

{$mode objfpc}{$H+}

interface

function BuildCacheNeedsRebuildFromEntryLine(const ALine: string;
  AStepOrdinal: Integer): Boolean;
function BuildCacheGetRevisionFromEntryLine(const ALine: string): string;

implementation

uses
  fpdev.build.cache.entryio;

function BuildCacheNeedsRebuildFromEntryLine(const ALine: string;
  AStepOrdinal: Integer): Boolean;
var
  CachedStatus: Integer;
begin
  if ALine = '' then
    Exit(True);

  CachedStatus := BuildCacheParseStatus(ALine);
  if CachedStatus >= 0 then
    Result := CachedStatus < AStepOrdinal
  else
    Result := True;
end;

function BuildCacheGetRevisionFromEntryLine(const ALine: string): string;
begin
  Result := BuildCacheParseRevision(ALine);
end;

end.
