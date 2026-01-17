program test_mirror_manager;

{$mode objfpc}{$H+}

uses
  SysUtils, fpdev.fpc.mirrors, fpdev.platform;

var
  Manager: TMirrorManager;
  Mirrors: TStringArray;
  URL: string;
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

  WriteLn('=== Mirror Manager Tests ===');
  WriteLn;

  Manager := TMirrorManager.Create;
  try
    // Test 1: Manager initializes with default mirrors
    Mirrors := Manager.GetMirrors;
    Assert(Length(Mirrors) > 0, 'Manager has default mirrors');

    // Test 2: Can add custom mirror
    Manager.AddMirror('https://custom.mirror.com/fpc');
    Mirrors := Manager.GetMirrors;
    Assert(Length(Mirrors) > 1, 'Can add custom mirror');

    // Test 3: GetDownloadURL returns valid URL
    URL := Manager.GetDownloadURL('3.2.2', 'linux-x86_64');
    Assert(Length(URL) > 0, 'GetDownloadURL returns non-empty URL');
    Assert(Pos('http', URL) = 1, 'URL starts with http');

    // Test 4: URL contains version
    Assert(Pos('3.2.2', URL) > 0, 'URL contains version');

    // Test 5: URL contains platform
    Assert((Pos('linux', URL) > 0) or (Pos('x86_64', URL) > 0), 'URL contains platform info');

    // Test 6: Different platforms generate different URLs
    URL := Manager.GetDownloadURL('3.2.2', 'windows-x86_64');
    Assert(Pos('windows', URL) > 0, 'Windows URL contains windows');

    // Test 7: Can clear mirrors
    Manager.ClearMirrors;
    Mirrors := Manager.GetMirrors;
    Assert(Length(Mirrors) = 0, 'Can clear all mirrors');

    // Test 8: Can restore default mirrors
    Manager.LoadDefaultMirrors;
    Mirrors := Manager.GetMirrors;
    Assert(Length(Mirrors) > 0, 'Can restore default mirrors');

  finally
    Manager.Free;
  end;

  WriteLn;
  WriteLn('=== Test Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
