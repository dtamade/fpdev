program test_build_cache_scan;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpdev.build.cache.scan;

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

procedure TestExtractVersion;
begin
  // Standard format
  Check(BuildCacheExtractVersion('fpc-3.2.2-x86_64-linux.tar.gz') = '3.2.2',
        'ExtractVersion: Standard format 3.2.2');
  Check(BuildCacheExtractVersion('fpc-3.0.4-i386-win32.tar.gz') = '3.0.4',
        'ExtractVersion: Standard format 3.0.4');

  // Binary suffix
  Check(BuildCacheExtractVersion('fpc-3.2.2-x86_64-linux-binary.tar.gz') = '3.2.2',
        'ExtractVersion: Binary suffix format');

  // Different architectures
  Check(BuildCacheExtractVersion('fpc-3.2.0-aarch64-darwin.tar.gz') = '3.2.0',
        'ExtractVersion: aarch64-darwin');

  // Invalid prefix
  Check(BuildCacheExtractVersion('lazarus-3.0.tar.gz') = '',
        'ExtractVersion: Invalid prefix returns empty');

  // Empty
  Check(BuildCacheExtractVersion('') = '',
        'ExtractVersion: Empty returns empty');
end;

procedure TestGetTotalSizeNonExistent;
begin
  Check(BuildCacheGetTotalSize('/nonexistent/cache/dir') = 0,
        'GetTotalSize: Non-existent directory returns 0');
end;

procedure TestGetTotalSizeWithFiles;
var
  Dir: string;
  F: TFileStream;
begin
  Dir := IncludeTrailingPathDelimiter(GetTempDir(True)) +
         'test_scan_' + IntToStr(Random(100000));
  ForceDirectories(Dir);
  try
    // Create fake archive files
    F := TFileStream.Create(Dir + PathDelim + 'fpc-3.2.2-x86_64-linux.tar.gz', fmCreate);
    F.Size := 1024;  // 1 KB
    F.Free;

    F := TFileStream.Create(Dir + PathDelim + 'fpc-3.2.0-x86_64-linux.tar.gz', fmCreate);
    F.Size := 2048;  // 2 KB
    F.Free;

    Check(BuildCacheGetTotalSize(Dir) = 3072,
          'GetTotalSize: Returns sum of archive sizes (3072)');
  finally
    DeleteFile(Dir + PathDelim + 'fpc-3.2.2-x86_64-linux.tar.gz');
    DeleteFile(Dir + PathDelim + 'fpc-3.2.0-x86_64-linux.tar.gz');
    RemoveDir(Dir);
  end;
end;

procedure TestListVersionsNonExistent;
var
  Versions: TStringArray;
begin
  Versions := BuildCacheListVersions('/nonexistent/cache/dir');
  Check((Versions = nil) or (Length(Versions) = 0),
        'ListVersions: Non-existent directory returns empty');
end;

procedure TestListVersionsWithFiles;
var
  Dir: string;
  F: TFileStream;
  Versions: TStringArray;
begin
  Dir := IncludeTrailingPathDelimiter(GetTempDir(True)) +
         'test_scan_' + IntToStr(Random(100000));
  ForceDirectories(Dir);
  try
    // Create fake archive files
    F := TFileStream.Create(Dir + PathDelim + 'fpc-3.2.2-x86_64-linux.tar.gz', fmCreate);
    F.Free;
    F := TFileStream.Create(Dir + PathDelim + 'fpc-3.2.0-x86_64-linux.tar.gz', fmCreate);
    F.Free;
    F := TFileStream.Create(Dir + PathDelim + 'fpc-3.2.2-i386-linux.tar.gz', fmCreate);
    F.Free;

    Versions := BuildCacheListVersions(Dir);
    // Should have 2 unique versions (3.2.0, 3.2.2), sorted
    Check(Length(Versions) = 2, 'ListVersions: Returns 2 unique versions');
    Check(Versions[0] = '3.2.0', 'ListVersions: First version is 3.2.0');
    Check(Versions[1] = '3.2.2', 'ListVersions: Second version is 3.2.2');
  finally
    DeleteFile(Dir + PathDelim + 'fpc-3.2.2-x86_64-linux.tar.gz');
    DeleteFile(Dir + PathDelim + 'fpc-3.2.0-x86_64-linux.tar.gz');
    DeleteFile(Dir + PathDelim + 'fpc-3.2.2-i386-linux.tar.gz');
    RemoveDir(Dir);
  end;
end;

begin
  Randomize;
  WriteLn('=== Build Cache Scan Unit Tests ===');
  WriteLn;

  TestExtractVersion;
  TestGetTotalSizeNonExistent;
  TestGetTotalSizeWithFiles;
  TestListVersionsNonExistent;
  TestListVersionsWithFiles;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
