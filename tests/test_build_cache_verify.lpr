program test_build_cache_verify;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpdev.build.cache.verify;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;
  TempDir: string;

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

function CreateTempFile(const AContent: string): string;
var
  F: TextFile;
begin
  Result := TempDir + PathDelim + 'test_' + IntToStr(Random(100000)) + '.txt';
  AssignFile(F, Result);
  Rewrite(F);
  Write(F, AContent);
  CloseFile(F);
end;

procedure TestCalculateSHA256ValidFile;
var
  FilePath, Hash: string;
begin
  // Create a test file with known content
  // "hello" has SHA256: 2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824
  FilePath := CreateTempFile('hello');
  try
    Hash := BuildCacheCalculateSHA256(FilePath);
    Check(Hash <> '', 'CalculateSHA256: Returns non-empty hash for valid file');
    Check(Length(Hash) = 64, 'CalculateSHA256: Hash is 64 characters (SHA256)');
    Check(Hash = '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824',
          'CalculateSHA256: Hash matches expected value for "hello"');
  finally
    DeleteFile(FilePath);
  end;
end;

procedure TestCalculateSHA256NonExistent;
var
  Hash: string;
begin
  Hash := BuildCacheCalculateSHA256('/nonexistent/file/path.txt');
  Check(Hash = '', 'CalculateSHA256: Returns empty for non-existent file');
end;

procedure TestCalculateSHA256EmptyFile;
var
  FilePath, Hash: string;
begin
  // Empty file has SHA256: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
  FilePath := CreateTempFile('');
  try
    Hash := BuildCacheCalculateSHA256(FilePath);
    Check(Hash = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          'CalculateSHA256: Hash matches for empty file');
  finally
    DeleteFile(FilePath);
  end;
end;

procedure TestCalculateSHA256DifferentContent;
var
  FilePath1, FilePath2, Hash1, Hash2: string;
begin
  FilePath1 := CreateTempFile('content A');
  FilePath2 := CreateTempFile('content B');
  try
    Hash1 := BuildCacheCalculateSHA256(FilePath1);
    Hash2 := BuildCacheCalculateSHA256(FilePath2);
    Check(Hash1 <> Hash2, 'CalculateSHA256: Different content produces different hashes');
    Check(Hash1 <> '', 'CalculateSHA256: First file has valid hash');
    Check(Hash2 <> '', 'CalculateSHA256: Second file has valid hash');
  finally
    DeleteFile(FilePath1);
    DeleteFile(FilePath2);
  end;
end;

procedure TestVerifyFileHashValidHash;
var
  FilePath: string;
  ExpectedHash: string;
begin
  FilePath := CreateTempFile('hello');
  ExpectedHash := '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824';
  try
    Check(BuildCacheVerifyFileHash(FilePath, ExpectedHash) = True,
          'VerifyFileHash: Returns True for matching hash');
  finally
    DeleteFile(FilePath);
  end;
end;

procedure TestVerifyFileHashInvalidHash;
var
  FilePath: string;
begin
  FilePath := CreateTempFile('hello');
  try
    Check(BuildCacheVerifyFileHash(FilePath, 'wronghash123') = False,
          'VerifyFileHash: Returns False for non-matching hash');
  finally
    DeleteFile(FilePath);
  end;
end;

procedure TestVerifyFileHashEmptyExpected;
var
  FilePath: string;
begin
  FilePath := CreateTempFile('any content');
  try
    // Empty expected hash should skip verification and return True
    Check(BuildCacheVerifyFileHash(FilePath, '') = True,
          'VerifyFileHash: Returns True when expected hash is empty (skip verification)');
  finally
    DeleteFile(FilePath);
  end;
end;

procedure TestVerifyFileHashCaseInsensitive;
var
  FilePath: string;
  UpperHash, LowerHash: string;
begin
  FilePath := CreateTempFile('hello');
  LowerHash := '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824';
  UpperHash := UpperCase(LowerHash);
  try
    Check(BuildCacheVerifyFileHash(FilePath, LowerHash) = True,
          'VerifyFileHash: Accepts lowercase hash');
    Check(BuildCacheVerifyFileHash(FilePath, UpperHash) = True,
          'VerifyFileHash: Accepts uppercase hash (case insensitive)');
  finally
    DeleteFile(FilePath);
  end;
end;

procedure TestVerifyFileHashNonExistent;
var
  Result: Boolean;
begin
  // Non-existent file should fail verification (unless expected is empty)
  Result := BuildCacheVerifyFileHash('/nonexistent/file.txt',
            '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824');
  Check(Result = False, 'VerifyFileHash: Returns False for non-existent file');
end;

begin
  Randomize;
  TempDir := GetTempDir(True);

  WriteLn('=== Build Cache Verify Unit Tests ===');
  WriteLn('Using temp directory: ', TempDir);
  WriteLn;

  TestCalculateSHA256ValidFile;
  TestCalculateSHA256NonExistent;
  TestCalculateSHA256EmptyFile;
  TestCalculateSHA256DifferentContent;
  TestVerifyFileHashValidHash;
  TestVerifyFileHashInvalidHash;
  TestVerifyFileHashEmptyExpected;
  TestVerifyFileHashCaseInsensitive;
  TestVerifyFileHashNonExistent;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
