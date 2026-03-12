program test_build_cache_sizelimit;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.build.cache.sizelimit;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure AssertTrue(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(TestsPassed);
    WriteLn('PASS: ', AMessage);
  end
  else
  begin
    Inc(TestsFailed);
    WriteLn('FAIL: ', AMessage);
  end;
end;

procedure TestGBToBytes;
begin
  AssertTrue(BuildCacheSizeGBToBytes(0) = 0,
    '0 GB means unlimited / 0 bytes');
  AssertTrue(BuildCacheSizeGBToBytes(2) = Int64(2) * 1024 * 1024 * 1024,
    'GB value converts to bytes');
end;

procedure TestMBToBytes;
begin
  AssertTrue(BuildCacheSizeMBToBytes(0) = 0,
    '0 MB means unlimited / 0 bytes');
  AssertTrue(BuildCacheSizeMBToBytes(512) = Int64(512) * 1024 * 1024,
    'MB value converts to bytes');
end;

procedure TestBytesToGB;
begin
  AssertTrue(BuildCacheBytesToSizeGB(0) = 0,
    '0 bytes means unlimited / 0 GB');
  AssertTrue(BuildCacheBytesToSizeGB(Int64(3) * 1024 * 1024 * 1024) = 3,
    'byte value converts back to GB');
end;

begin
  TestGBToBytes;
  TestMBToBytes;
  TestBytesToGB;

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
