program test_toolchain_fetcher;

{$mode objfpc}{$H+}

uses
  SysUtils, fpdev.toolchain.fetcher, fpdev.manifest;

var
  TestsPassed, TestsFailed: Integer;
  Algorithm: THashAlgorithm;
  Digest: string;
  Target: TManifestTarget;
  Opt: TFetchOptions;

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

  WriteLn('=== Toolchain Fetcher Tests ===');
  WriteLn;

  // Test 1: ParseHashString with SHA256
  Assert(ParseHashString('sha256:abc123def456', Algorithm, Digest), 'ParseHashString parses SHA256');
  Assert(Algorithm = haSHA256, 'Algorithm is SHA256');
  Assert(Digest = 'abc123def456', 'Digest is correct for SHA256');

  // Test 2: ParseHashString with SHA512
  Assert(ParseHashString('sha512:fedcba987654', Algorithm, Digest), 'ParseHashString parses SHA512');
  Assert(Algorithm = haSHA512, 'Algorithm is SHA512');
  Assert(Digest = 'fedcba987654', 'Digest is correct for SHA512');

  // Test 3: ParseHashString with invalid format (no colon)
  Assert(not ParseHashString('sha256abc123', Algorithm, Digest), 'ParseHashString rejects no colon');

  // Test 4: ParseHashString with unsupported algorithm
  Assert(not ParseHashString('md5:abc123', Algorithm, Digest), 'ParseHashString rejects MD5');

  // Test 5: ParseHashString with empty digest
  Assert(not ParseHashString('sha256:', Algorithm, Digest), 'ParseHashString rejects empty digest');

  // Test 6: TFetchOptions initialization
  Opt.DestDir := '/tmp';
  Opt.Hash := 'sha256:test123';
  Opt.HashAlgorithm := haSHA256;
  Opt.HashDigest := 'test123';
  Opt.TimeoutMS := 30000;
  Opt.ExpectedSize := 1024;
  Assert(Opt.HashAlgorithm = haSHA256, 'TFetchOptions HashAlgorithm set correctly');
  Assert(Opt.ExpectedSize = 1024, 'TFetchOptions ExpectedSize set correctly');

  // Test 7: TManifestTarget structure
  SetLength(Target.URLs, 2);
  Target.URLs[0] := 'https://mirror1.com/file.tar.gz';
  Target.URLs[1] := 'https://mirror2.com/file.tar.gz';
  Target.Hash := 'sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
  Target.Size := 123456789;
  Assert(Length(Target.URLs) = 2, 'Target has 2 URLs');
  Assert(Pos('mirror1', Target.URLs[0]) > 0, 'First URL is correct');
  Assert(Pos('sha256', Target.Hash) > 0, 'Hash format is correct');
  Assert(Target.Size = 123456789, 'Size is correct');

  WriteLn;
  WriteLn('=== Test Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
