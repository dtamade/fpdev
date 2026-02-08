unit fpdev.build.cache.ttl;

{$mode objfpc}{$H+}

{
  B072: TTL expiration helpers for TBuildCache

  Extracts time-to-live and expiration detection logic from build.cache.
  Pure functions for checking artifact expiration.
}

interface

uses
  SysUtils, DateUtils;

{ Check if an artifact is expired based on TTL days
  @param ACreatedAt - Creation timestamp of the artifact
  @param ATTLDays - Time-to-live in days (0 = never expire)
  @return True if artifact is expired }
function BuildCacheIsExpired(ACreatedAt: TDateTime; ATTLDays: Integer): Boolean;

{ Calculate expiry date based on creation date and TTL
  @param ACreatedAt - Creation timestamp
  @param ATTLDays - Time-to-live in days
  @return Expiry date (0 if TTL is 0/unlimited) }
function BuildCacheGetExpiryDate(ACreatedAt: TDateTime; ATTLDays: Integer): TDateTime;

{ Calculate days until expiration
  @param ACreatedAt - Creation timestamp
  @param ATTLDays - Time-to-live in days
  @return Days remaining (negative if expired, MaxInt if unlimited) }
function BuildCacheGetDaysUntilExpiry(ACreatedAt: TDateTime; ATTLDays: Integer): Integer;

{ Extract version from cache filename
  @param AFileName - Filename like "fpc-3.2.0-x86_64-linux.meta"
  @return Version string like "3.2.0" or empty if invalid }
function BuildCacheExtractVersionFromFilename(const AFileName: string): string;

implementation

function BuildCacheIsExpired(ACreatedAt: TDateTime; ATTLDays: Integer): Boolean;
var
  ExpiryDate: TDateTime;
begin
  // TTL=0 means never expire
  if ATTLDays = 0 then
    Exit(False);

  ExpiryDate := ACreatedAt + ATTLDays;
  Result := Now >= ExpiryDate;  // Include boundary (exactly at TTL)
end;

function BuildCacheGetExpiryDate(ACreatedAt: TDateTime; ATTLDays: Integer): TDateTime;
begin
  if ATTLDays = 0 then
    Result := 0  // No expiry
  else
    Result := ACreatedAt + ATTLDays;
end;

function BuildCacheGetDaysUntilExpiry(ACreatedAt: TDateTime; ATTLDays: Integer): Integer;
var
  ExpiryDate: TDateTime;
begin
  if ATTLDays = 0 then
    Exit(MaxInt);  // Unlimited

  ExpiryDate := ACreatedAt + ATTLDays;
  Result := Trunc(ExpiryDate - Now);
end;

function BuildCacheExtractVersionFromFilename(const AFileName: string): string;
var
  DashPos: Integer;
begin
  Result := '';

  // Expected format: fpc-X.Y.Z-cpu-os.ext or fpc-X.Y.Z-cpu-os-binary.ext
  if Pos('fpc-', AFileName) <> 1 then
    Exit;

  // Remove 'fpc-' prefix (4 chars)
  Result := Copy(AFileName, 5, Length(AFileName) - 4);

  // Remove extension (.meta, .json, .tar.gz, etc.)
  if Pos('.tar.gz', Result) > 0 then
    Result := Copy(Result, 1, Pos('.tar.gz', Result) - 1)
  else if Pos('.meta', Result) > 0 then
    Result := Copy(Result, 1, Pos('.meta', Result) - 1)
  else if Pos('.json', Result) > 0 then
    Result := Copy(Result, 1, Pos('.json', Result) - 1);

  // Handle -binary suffix
  if Pos('-binary', Result) > 0 then
    Result := Copy(Result, 1, Pos('-binary', Result) - 1);

  // Extract just the version number (before platform suffix)
  // For "3.2.0-x86_64-linux", extract "3.2.0"
  DashPos := Pos('-', Result);
  if DashPos > 0 then
    Result := Copy(Result, 1, DashPos - 1);
end;

end.
