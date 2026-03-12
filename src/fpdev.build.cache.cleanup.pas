unit fpdev.build.cache.cleanup;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpdev.build.cache.types;

function BuildCacheSelectCleanupVictims(const AInfos: array of TArtifactInfo;
  AMaxSizeBytes: Int64): SysUtils.TStringArray;

implementation

uses
  fpdev.build.cache.lru;

function BuildCacheSelectCleanupVictims(const AInfos: array of TArtifactInfo;
  AMaxSizeBytes: Int64): SysUtils.TStringArray;
var
  Working: array of TArtifactInfo;
  VictimVersion: string;
  TotalSize: Int64;
  Index, Count, VictimIndex: Integer;
begin
  Result := nil;
  if AMaxSizeBytes = 0 then
    Exit;

  Working := nil;
  SetLength(Working, Length(AInfos));
  for Index := 0 to High(AInfos) do
    Working[Index] := AInfos[Index];
  Count := Length(Working);

  TotalSize := 0;
  for Index := 0 to Count - 1 do
    TotalSize := TotalSize + Working[Index].ArchiveSize;

  while (TotalSize > AMaxSizeBytes) and (Count > 0) do
  begin
    VictimVersion := BuildCacheSelectLeastRecentlyUsed(Working);
    VictimIndex := -1;
    for Index := 0 to Count - 1 do
      if Working[Index].Version = VictimVersion then
      begin
        VictimIndex := Index;
        Break;
      end;

    if VictimIndex < 0 then
      Break;

    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := Working[VictimIndex].ArchivePath;
    TotalSize := TotalSize - Working[VictimIndex].ArchiveSize;

    for Index := VictimIndex to Count - 2 do
      Working[Index] := Working[Index + 1];
    Dec(Count);
    SetLength(Working, Count);
  end;
end;

end.
