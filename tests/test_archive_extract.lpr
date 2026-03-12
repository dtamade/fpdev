program test_archive_extract;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, Process, fpdev.archive.extract, test_temp_paths;

var
  Extractor: TArchiveExtractor;
  TestsPassed, TestsFailed: Integer;
  TempDir, TestArchive: string;

procedure Assert(Condition: Boolean; const TestName: string);
begin
  if Condition then
  begin
    WriteLn('[PASS] ', TestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', TestName);
    Inc(TestsFailed);
  end;
end;

procedure Cleanup;
begin
  if (TempDir <> '') and PathUsesSystemTempRoot(TempDir) then
    CleanupTempDir(TempDir);
end;

begin
  TestsPassed := 0;
  TestsFailed := 0;

  WriteLn('=== Archive Extraction Tests ===');
  WriteLn;

  TempDir := CreateUniqueTempDir('fpdev_test_archive_extract');

  try
    Extractor := TArchiveExtractor.Create;
    try
      // Test 1: Extractor initializes
      Assert(Extractor <> nil, 'Extractor initializes');

      // Test 2: Can detect tar.gz format
      Assert(Extractor.DetectFormat('test.tar.gz') = afTarGz, 'Detects tar.gz format');

      // Test 3: Can detect tar.bz2 format
      Assert(Extractor.DetectFormat('test.tar.bz2') = afTarBz2, 'Detects tar.bz2 format');

      // Test 4: Can detect zip format
      Assert(Extractor.DetectFormat('test.zip') = afZip, 'Detects zip format');

      // Test 5: Unknown format returns afUnknown
      Assert(Extractor.DetectFormat('test.txt') = afUnknown, 'Unknown format returns afUnknown');

    finally
      Extractor.Free;
    end;

  finally
    Cleanup;
  end;

  WriteLn;
  WriteLn('=== Test Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
