program test_build_cache_key;

{$mode objfpc}{$H+}

uses
  SysUtils, fpdev.build.cache.key;

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

procedure TestGetCurrentCPU;
var
  CPU: string;
begin
  CPU := BuildCacheGetCurrentCPU;

  // Should return a non-empty string
  Check(CPU <> '', 'GetCurrentCPU returns non-empty string');

  // Should be one of known CPU architectures
  Check((CPU = 'x86_64') or (CPU = 'i386') or (CPU = 'arm') or
        (CPU = 'aarch64') or (CPU = 'unknown'),
        'GetCurrentCPU returns valid CPU architecture');

  // On this platform, should be x86_64
  {$IFDEF CPUX86_64}
  Check(CPU = 'x86_64', 'GetCurrentCPU returns x86_64 on x86_64 platform');
  {$ENDIF}
end;

procedure TestGetCurrentOS;
var
  OS: string;
begin
  OS := BuildCacheGetCurrentOS;

  // Should return a non-empty string
  Check(OS <> '', 'GetCurrentOS returns non-empty string');

  // Should be one of known OS names
  Check((OS = 'linux') or (OS = 'win64') or (OS = 'darwin') or (OS = 'unknown'),
        'GetCurrentOS returns valid OS name');

  // On this platform, should be linux
  {$IFDEF LINUX}
  Check(OS = 'linux', 'GetCurrentOS returns linux on Linux platform');
  {$ENDIF}
end;

procedure TestGetArtifactKey;
var
  Key: string;
begin
  Key := BuildCacheGetArtifactKey('3.2.2');

  // Should contain version
  Check(Pos('3.2.2', Key) > 0, 'GetArtifactKey contains version');

  // Should start with fpc-
  Check(Pos('fpc-', Key) = 1, 'GetArtifactKey starts with fpc-');

  // Should contain CPU and OS
  Check(Pos(BuildCacheGetCurrentCPU, Key) > 0, 'GetArtifactKey contains CPU');
  Check(Pos(BuildCacheGetCurrentOS, Key) > 0, 'GetArtifactKey contains OS');

  // Format: fpc-<version>-<cpu>-<os>
  Check(Key = 'fpc-3.2.2-' + BuildCacheGetCurrentCPU + '-' + BuildCacheGetCurrentOS,
        'GetArtifactKey has correct format');
end;

procedure TestGetArtifactKeyDifferentVersions;
var
  Key1, Key2, Key3: string;
begin
  Key1 := BuildCacheGetArtifactKey('3.2.2');
  Key2 := BuildCacheGetArtifactKey('3.2.0');
  Key3 := BuildCacheGetArtifactKey('main');

  // Different versions should produce different keys
  Check(Key1 <> Key2, 'Different versions produce different keys (3.2.2 vs 3.2.0)');
  Check(Key1 <> Key3, 'Different versions produce different keys (3.2.2 vs main)');
  Check(Key2 <> Key3, 'Different versions produce different keys (3.2.0 vs main)');
end;

procedure TestGetArtifactKeyPathTraversal;
var
  ExceptionRaised: Boolean;
begin
  // Test path traversal prevention
  ExceptionRaised := False;
  try
    BuildCacheGetArtifactKey('../etc/passwd');
  except
    on E: Exception do
      ExceptionRaised := True;
  end;
  Check(ExceptionRaised, 'GetArtifactKey rejects .. path traversal');

  ExceptionRaised := False;
  try
    BuildCacheGetArtifactKey('3.2.2/../../etc');
  except
    on E: Exception do
      ExceptionRaised := True;
  end;
  Check(ExceptionRaised, 'GetArtifactKey rejects / path separator');

  ExceptionRaised := False;
  try
    BuildCacheGetArtifactKey('3.2.2\..\etc');
  except
    on E: Exception do
      ExceptionRaised := True;
  end;
  Check(ExceptionRaised, 'GetArtifactKey rejects \ path separator');
end;

procedure TestGetArtifactKeyEmptyVersion;
var
  Key: string;
begin
  // Empty version should still work (produce valid key format)
  Key := BuildCacheGetArtifactKey('');
  Check(Pos('fpc-', Key) = 1, 'GetArtifactKey with empty version starts with fpc-');
  Check(Key = 'fpc--' + BuildCacheGetCurrentCPU + '-' + BuildCacheGetCurrentOS,
        'GetArtifactKey with empty version has correct format');
end;

begin
  WriteLn('=== Build Cache Key Unit Tests ===');
  WriteLn;

  TestGetCurrentCPU;
  TestGetCurrentOS;
  TestGetArtifactKey;
  TestGetArtifactKeyDifferentVersions;
  TestGetArtifactKeyPathTraversal;
  TestGetArtifactKeyEmptyVersion;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
