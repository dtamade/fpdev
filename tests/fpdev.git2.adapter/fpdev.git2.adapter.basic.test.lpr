program fpdev_git2_adapter_basic_test;

{$CODEPAGE UTF8}
{$mode objfpc}{$H+}

uses
  consoletestrunner, testregistry,
  fpdev.git2.adapter.basic.testcase;

var
  Runner: TTestRunner;
begin
  Runner := TTestRunner.Create(nil);
  try
    Runner.Initialize;
    Runner.Run;
  finally
    Runner.Free;
  end;
end.

