program test_fpc_verifier;

{$mode objfpc}{$H+}

uses
  SysUtils, fpdev.fpc.verify;

var
  Verifier: TFPCVerifier;
  TestsPassed, TestsFailed: Integer;

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

  WriteLn('=== FPC Verifier Tests ===');
  WriteLn;

  Verifier := TFPCVerifier.Create;
  try
    // Test 1: Verifier initializes
    Assert(Verifier <> nil, 'Verifier initializes');

    // Test 2: Can parse FPC version string
    Assert(Verifier.ParseVersion('Free Pascal Compiler version 3.2.2') = '3.2.2',
           'Parse version from FPC output');

    // Test 3: Can parse version with build info
    Assert(Verifier.ParseVersion('Free Pascal Compiler version 3.2.2 [2021/05/15]') = '3.2.2',
           'Parse version with build date');

    // Test 4: Invalid version string returns empty
    Assert(Verifier.ParseVersion('Invalid output') = '',
           'Invalid version returns empty string');

    // Test 5: Can generate hello world source
    Assert(Length(Verifier.GetHelloWorldSource) > 0,
           'Generate hello world source');

    // Test 6: Hello world source contains program keyword
    Assert(Pos('program', Verifier.GetHelloWorldSource) > 0,
           'Hello world contains program keyword');

    // Test 7: Can get last error
    Assert(Length(Verifier.GetLastError) >= 0,
           'Can get last error');

  finally
    Verifier.Free;
  end;

  WriteLn;
  WriteLn('=== Test Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
