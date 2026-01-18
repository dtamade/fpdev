program test_sha512;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpdev.hash;

var
  TestsPassed, TestsFailed: Integer;
  TestFile: string;
  F: TFileStream;
  Hash: string;

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

begin
  TestsPassed := 0;
  TestsFailed := 0;

  WriteLn('=== SHA512 Hash Tests ===');
  WriteLn;

  // Test 1: SHA512 of empty string
  TestFile := GetTempDir + 'test_empty.txt';
  F := TFileStream.Create(TestFile, fmCreate);
  try
    // Empty file
  finally
    F.Free;
  end;

  Hash := SHA512FileHex(TestFile);
  Assert(Length(Hash) = 128, 'SHA512 hash length is 128 characters (512 bits / 4)');
  Assert(Hash = 'cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e',
         'SHA512 of empty file matches expected hash');
  DeleteFile(TestFile);

  // Test 2: SHA512 of "abc"
  TestFile := GetTempDir + 'test_abc.txt';
  F := TFileStream.Create(TestFile, fmCreate);
  try
    F.Write('abc'[1], 3);
  finally
    F.Free;
  end;

  Hash := SHA512FileHex(TestFile);
  Assert(Hash = 'ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f',
         'SHA512 of "abc" matches expected hash');
  DeleteFile(TestFile);

  // Test 3: SHA512 of longer text
  TestFile := GetTempDir + 'test_long.txt';
  F := TFileStream.Create(TestFile, fmCreate);
  try
    F.Write('The quick brown fox jumps over the lazy dog'[1], 43);
  finally
    F.Free;
  end;

  Hash := SHA512FileHex(TestFile);
  Assert(Length(Hash) = 128, 'SHA512 hash of longer text has correct length');
  Assert(Hash = '07e547d9586f6a73f73fbac0435ed76951218fb7d0c8d788a309d785436bbb642e93a252a954f23912547d1e8a3b5ed6e1bfd7097821233fa0538f3db854fee6',
         'SHA512 of "The quick brown fox..." matches expected hash');
  DeleteFile(TestFile);

  // Test 4: SHA256 still works (regression test)
  TestFile := GetTempDir + 'test_sha256.txt';
  F := TFileStream.Create(TestFile, fmCreate);
  try
    F.Write('test'[1], 4);
  finally
    F.Free;
  end;

  Hash := SHA256FileHex(TestFile);
  Assert(Length(Hash) = 64, 'SHA256 hash length is 64 characters (256 bits / 4)');
  Assert(Hash = '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08',
         'SHA256 of "test" matches expected hash');
  DeleteFile(TestFile);

  WriteLn;
  WriteLn('=== Test Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
