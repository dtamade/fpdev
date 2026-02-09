program test_build_cache_ttl;

{$mode objfpc}{$H+}

uses
  SysUtils, DateUtils, fpdev.build.cache.ttl;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure Check(const ACondition: Boolean; const ATestName: string);
begin
  if ACondition then
  begin
    WriteLn('[PASS] ', ATestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', ATestName);
    Inc(TestsFailed);
  end;
end;

procedure TestIsExpired;
var
  OldDate, RecentDate, FutureDate: TDateTime;
begin
  OldDate := Now - 100;  // 100 days ago
  RecentDate := Now - 10; // 10 days ago
  FutureDate := Now + 10; // 10 days in future (invalid but test edge case)

  // Test with TTL=30 days
  Check(BuildCacheIsExpired(OldDate, 30) = True,
        'IsExpired: 100 days old with 30-day TTL is expired');
  Check(BuildCacheIsExpired(RecentDate, 30) = False,
        'IsExpired: 10 days old with 30-day TTL is not expired');

  // Test with TTL=0 (unlimited)
  Check(BuildCacheIsExpired(OldDate, 0) = False,
        'IsExpired: Old artifact with TTL=0 never expires');
  Check(BuildCacheIsExpired(RecentDate, 0) = False,
        'IsExpired: Recent artifact with TTL=0 never expires');

  // Test boundary condition
  Check(BuildCacheIsExpired(Now - 30, 30) = True,
        'IsExpired: Exactly at TTL boundary is expired');
  Check(BuildCacheIsExpired(Now - 29, 30) = False,
        'IsExpired: 1 day before TTL boundary is not expired');
end;

procedure TestGetExpiryDate;
var
  CreatedAt, ExpiryDate: TDateTime;
begin
  CreatedAt := EncodeDate(2026, 1, 1);

  // Test with 30-day TTL
  ExpiryDate := BuildCacheGetExpiryDate(CreatedAt, 30);
  Check(Abs(ExpiryDate - (CreatedAt + 30)) < 0.001,
        'GetExpiryDate: 30-day TTL adds 30 days');

  // Test with 0 TTL (unlimited)
  ExpiryDate := BuildCacheGetExpiryDate(CreatedAt, 0);
  Check(ExpiryDate = 0,
        'GetExpiryDate: TTL=0 returns 0 (no expiry)');

  // Test with 365-day TTL
  ExpiryDate := BuildCacheGetExpiryDate(CreatedAt, 365);
  Check(Abs(ExpiryDate - (CreatedAt + 365)) < 0.001,
        'GetExpiryDate: 365-day TTL adds 365 days');
end;

procedure TestGetDaysUntilExpiry;
var
  Days: Integer;
  CreatedAt: TDateTime;
begin
  // Test unlimited TTL
  Days := BuildCacheGetDaysUntilExpiry(Now - 1000, 0);
  Check(Days = MaxInt, 'GetDaysUntilExpiry: TTL=0 returns MaxInt');

  // Test not expired
  CreatedAt := Now - 10;  // Created 10 days ago
  Days := BuildCacheGetDaysUntilExpiry(CreatedAt, 30);
  Check((Days >= 19) and (Days <= 21),
        'GetDaysUntilExpiry: 10 days old with 30-day TTL has ~20 days left');

  // Test expired
  CreatedAt := Now - 100;  // Created 100 days ago
  Days := BuildCacheGetDaysUntilExpiry(CreatedAt, 30);
  Check(Days < 0, 'GetDaysUntilExpiry: Expired artifact returns negative days');
end;

procedure TestExtractVersionFromFilename;
var
  Version: string;
begin
  // Standard .meta format
  Version := BuildCacheExtractVersionFromFilename('fpc-3.2.2-x86_64-linux.meta');
  Check(Version = '3.2.2', 'ExtractVersion: fpc-3.2.2-x86_64-linux.meta -> 3.2.2');

  // .json format
  Version := BuildCacheExtractVersionFromFilename('fpc-3.2.0-x86_64-linux.json');
  Check(Version = '3.2.0', 'ExtractVersion: fpc-3.2.0-x86_64-linux.json -> 3.2.0');

  // .tar.gz format
  Version := BuildCacheExtractVersionFromFilename('fpc-3.0.4-i386-win32.tar.gz');
  Check(Version = '3.0.4', 'ExtractVersion: fpc-3.0.4-i386-win32.tar.gz -> 3.0.4');

  // Binary suffix format
  Version := BuildCacheExtractVersionFromFilename('fpc-3.2.2-x86_64-linux-binary.meta');
  Check(Version = '3.2.2', 'ExtractVersion: fpc-3.2.2-x86_64-linux-binary.meta -> 3.2.2');

  // Invalid format - no fpc- prefix
  Version := BuildCacheExtractVersionFromFilename('lazarus-3.0.meta');
  Check(Version = '', 'ExtractVersion: Invalid prefix returns empty string');

  // Development version (main/trunk)
  Version := BuildCacheExtractVersionFromFilename('fpc-main-x86_64-linux.meta');
  Check(Version = 'main', 'ExtractVersion: fpc-main-x86_64-linux.meta -> main');
end;

procedure TestExtractVersionEdgeCases;
var
  Version: string;
begin
  // Empty filename
  Version := BuildCacheExtractVersionFromFilename('');
  Check(Version = '', 'ExtractVersion: Empty filename returns empty');

  // Just fpc-
  Version := BuildCacheExtractVersionFromFilename('fpc-');
  Check(Version = '', 'ExtractVersion: Just fpc- returns empty');

  // Different architectures
  Version := BuildCacheExtractVersionFromFilename('fpc-3.2.2-aarch64-darwin.meta');
  Check(Version = '3.2.2', 'ExtractVersion: aarch64-darwin platform works');

  Version := BuildCacheExtractVersionFromFilename('fpc-3.2.2-arm-linux.tar.gz');
  Check(Version = '3.2.2', 'ExtractVersion: arm-linux platform works');
end;

begin
  WriteLn('=== Build Cache TTL Unit Tests ===');
  WriteLn;

  TestIsExpired;
  TestGetExpiryDate;
  TestGetDaysUntilExpiry;
  TestExtractVersionFromFilename;
  TestExtractVersionEdgeCases;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
