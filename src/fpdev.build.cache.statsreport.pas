{
  fpdev.build.cache.statsreport.pas

  Helper unit for cache statistics report formatting.
  Extracted from fpdev.build.cache.pas (B046).

  Part of FPDev project - Phase 4 autonomous batch refactoring.
}
unit fpdev.build.cache.statsreport;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

{ Format file size to human-readable string (bytes/MB/GB) }
function BuildCacheFormatSize(ASize: Int64): string;

{ Format statistics report from detailed stats fields }
function BuildCacheFormatStatsReport(
  ATotalEntries: Integer;
  ATotalSize: Int64;
  ATotalAccesses: Integer;
  const AMostAccessedVersion: string;
  AMostAccessedCount: Integer;
  const ALeastAccessedVersion: string;
  ALeastAccessedCount: Integer): string;

implementation

function BuildCacheFormatSize(ASize: Int64): string;
begin
  if ASize >= 1024 * 1024 * 1024 then
    Result := Format('%.2f GB', [ASize / (1024 * 1024 * 1024)])
  else if ASize >= 1024 * 1024 then
    Result := Format('%.2f MB', [ASize / (1024 * 1024)])
  else
    Result := Format('%d bytes', [ASize]);
end;

function BuildCacheFormatStatsReport(
  ATotalEntries: Integer;
  ATotalSize: Int64;
  ATotalAccesses: Integer;
  const AMostAccessedVersion: string;
  AMostAccessedCount: Integer;
  const ALeastAccessedVersion: string;
  ALeastAccessedCount: Integer): string;
var
  SizeStr: string;
begin
  SizeStr := BuildCacheFormatSize(ATotalSize);

  Result := Format(
    'Cache Statistics Report' + LineEnding +
    '=======================' + LineEnding +
    'Total entries: %d' + LineEnding +
    'Total size: %s' + LineEnding +
    'Total accesses: %d' + LineEnding +
    'Most accessed: %s (%d accesses)' + LineEnding +
    'Least accessed: %s (%d accesses)',
    [ATotalEntries, SizeStr, ATotalAccesses,
     AMostAccessedVersion, AMostAccessedCount,
     ALeastAccessedVersion, ALeastAccessedCount]);
end;

end.
