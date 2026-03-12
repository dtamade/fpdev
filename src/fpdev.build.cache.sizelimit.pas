unit fpdev.build.cache.sizelimit;

{$mode objfpc}{$H+}

interface

function BuildCacheSizeGBToBytes(ASizeGB: Integer): Int64;
function BuildCacheSizeMBToBytes(ASizeMB: Integer): Int64;
function BuildCacheBytesToSizeGB(AMaxCacheSizeBytes: Int64): Integer;

implementation

function BuildCacheSizeGBToBytes(ASizeGB: Integer): Int64;
begin
  if ASizeGB = 0 then
    Result := 0
  else
    Result := Int64(ASizeGB) * 1024 * 1024 * 1024;
end;

function BuildCacheSizeMBToBytes(ASizeMB: Integer): Int64;
begin
  if ASizeMB = 0 then
    Result := 0
  else
    Result := Int64(ASizeMB) * 1024 * 1024;
end;

function BuildCacheBytesToSizeGB(AMaxCacheSizeBytes: Int64): Integer;
begin
  if AMaxCacheSizeBytes = 0 then
    Result := 0
  else
    Result := AMaxCacheSizeBytes div (1024 * 1024 * 1024);
end;

end.
