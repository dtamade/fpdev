unit fpdev.build.cache.entries;

{$mode objfpc}{$H+}

interface

uses
  Classes;

function BuildCacheGetCacheFilePath(const ACacheDirWithDelim: string): string;
function BuildCacheGetEntryCount(const AEntries: TStringList): Integer;
function BuildCacheFindEntry(const AEntries: TStringList; const AVersion: string): Integer;

implementation

function BuildCacheGetCacheFilePath(const ACacheDirWithDelim: string): string;
begin
  Result := ACacheDirWithDelim + 'build-cache.txt';
end;

function BuildCacheGetEntryCount(const AEntries: TStringList): Integer;
begin
  if Assigned(AEntries) then
    Result := AEntries.Count
  else
    Result := 0;
end;

function BuildCacheFindEntry(const AEntries: TStringList; const AVersion: string): Integer;
var
  i: Integer;
begin
  Result := -1;
  if not Assigned(AEntries) then
    Exit;

  for i := 0 to AEntries.Count - 1 do
    if Pos('version=' + AVersion + ';', AEntries[i]) = 1 then
      Exit(i);
end;

end.
