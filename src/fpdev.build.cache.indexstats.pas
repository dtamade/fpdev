unit fpdev.build.cache.indexstats;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, DateUtils;

procedure BuildCacheIndexStatsInit(out ATotalSize: Int64; out AOldestDate, ANewestDate: TDateTime;
  out AOldestVersion, ANewestVersion: string);
procedure BuildCacheIndexStatsAccumulate(const AVersion: string; AArchiveSize: Int64; ACreatedAt: TDateTime;
  var ATotalSize: Int64; var AOldestDate, ANewestDate: TDateTime;
  var AOldestVersion, ANewestVersion: string);
procedure BuildCacheIndexStatsFinalize(ATotalEntries: Integer; var AOldestDate, ANewestDate: TDateTime);

implementation

procedure BuildCacheIndexStatsInit(out ATotalSize: Int64; out AOldestDate, ANewestDate: TDateTime;
  out AOldestVersion, ANewestVersion: string);
begin
  ATotalSize := 0;
  AOldestDate := MaxDateTime;
  ANewestDate := 0;
  AOldestVersion := '';
  ANewestVersion := '';
end;

procedure BuildCacheIndexStatsAccumulate(const AVersion: string; AArchiveSize: Int64; ACreatedAt: TDateTime;
  var ATotalSize: Int64; var AOldestDate, ANewestDate: TDateTime;
  var AOldestVersion, ANewestVersion: string);
begin
  ATotalSize := ATotalSize + AArchiveSize;

  if ACreatedAt < AOldestDate then
  begin
    AOldestDate := ACreatedAt;
    AOldestVersion := AVersion;
  end;

  if ACreatedAt > ANewestDate then
  begin
    ANewestDate := ACreatedAt;
    ANewestVersion := AVersion;
  end;
end;

procedure BuildCacheIndexStatsFinalize(ATotalEntries: Integer; var AOldestDate, ANewestDate: TDateTime);
begin
  if ATotalEntries = 0 then
  begin
    AOldestDate := 0;
    ANewestDate := 0;
  end;
end;

end.
